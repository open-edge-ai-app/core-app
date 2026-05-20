import {
  ensureTodoStoreLoaded,
  getTasks,
  occurrenceDayKey,
  setLabels,
  setTasks,
  taskOccursOn,
  toggleTaskCompletionOn,
  type TodoTask,
} from '../src/state/todoStore';
import {
  applyTodoToolCalls,
  executeTodoToolCall,
  parseTodoToolCalls,
  shouldUseTodoTool,
} from '../src/native/todoTools';

beforeAll(async () => {
  await ensureTodoStoreLoaded();
});

beforeEach(() => {
  setTasks([]);
  setLabels([]);
});

describe('parseTodoToolCalls', () => {
  it('extracts a fenced openedge_tool block and strips it from the text', () => {
    const text =
      'Sure!\n```openedge_tool\n{"tool":"todo_create","arguments":{"title":"Buy milk"}}\n```\nDone.';
    const { cleanedText, calls } = parseTodoToolCalls(text);
    expect(calls).toHaveLength(1);
    expect(calls[0].name).toBe('todo_create');
    expect(cleanedText).not.toContain('openedge_tool');
    expect(cleanedText).toContain('Sure!');
  });

  it('supports an array of calls in one block', () => {
    const text =
      '```todo_tool\n[{"tool":"todo_create","arguments":{"title":"A"}},{"tool":"todo_create","arguments":{"title":"B"}}]\n```';
    const { calls } = parseTodoToolCalls(text);
    expect(calls).toHaveLength(2);
  });

  it('ignores non-todo tools', () => {
    const text =
      '```openedge_tool\n{"tool":"web_search","arguments":{}}\n```';
    const { calls } = parseTodoToolCalls(text);
    expect(calls).toHaveLength(0);
  });
});

describe('executeTodoToolCall', () => {
  it('creates a todo in the shared store', () => {
    executeTodoToolCall({
      name: 'todo_create',
      arguments: { title: 'Call Jason', start_at: '2026-05-20 13:00' },
    });
    const tasks = getTasks();
    expect(tasks).toHaveLength(1);
    expect(tasks[0].title).toBe('Call Jason');
  });

  it('updates and completes a todo by query', () => {
    executeTodoToolCall({
      name: 'todo_create',
      arguments: { title: 'Write report' },
    });
    executeTodoToolCall({
      name: 'todo_complete',
      arguments: { query: 'report', completed: true },
    });
    expect(getTasks()[0].isCompleted).toBe(true);
  });

  it('assigns at most one label', () => {
    executeTodoToolCall({
      name: 'todo_create',
      arguments: { title: 'Tagged', labels: ['work', 'home'] },
    });
    expect(getTasks()[0].labelIds).toHaveLength(1);
  });
});

describe('applyTodoToolCalls end to end', () => {
  it('creates then lists the created todo', () => {
    const create = applyTodoToolCalls(
      'ok ```openedge_tool\n{"tool":"todo_create","arguments":{"title":"Groceries"}}\n```',
    );
    expect(create.didMutate).toBe(true);

    const list = applyTodoToolCalls(
      '```openedge_tool\n{"tool":"todo_list","arguments":{"filter":"all"}}\n```',
    );
    expect(list.listText).toContain('Groceries');
  });
});

describe('recurrence helpers', () => {
  it('weekly task occurs only on the matching weekday', () => {
    const anchor = new Date(2026, 4, 20);
    const task: TodoTask = {
      id: 't',
      title: 'Standup',
      note: '',
      dueLabel: 'Tasks',
      dueDateISO: anchor.toISOString(),
      repeatRule: 'weekly',
    };
    expect(taskOccursOn(task, new Date(2026, 4, 27))).toBe(true);
    expect(taskOccursOn(task, new Date(2026, 4, 21))).toBe(false);
  });

  it('toggles per-occurrence completion for recurring tasks', () => {
    const anchor = new Date(2026, 4, 20);
    let task: TodoTask = {
      id: 't',
      title: 'Daily',
      note: '',
      dueLabel: 'Tasks',
      dueDateISO: anchor.toISOString(),
      repeatRule: 'daily',
    };
    const day = new Date(2026, 4, 22);
    task = toggleTaskCompletionOn(task, day);
    expect(task.completedOccurrenceDayKeys).toContain(occurrenceDayKey(day));
  });
});

describe('shouldUseTodoTool', () => {
  it('detects todo and schedule intents but not generic questions', () => {
    expect(shouldUseTodoTool('내일 오후 3시 회의 일정 잡아줘')).toBe(true);
    expect(shouldUseTodoTool('add a task to call mom')).toBe(true);
    expect(shouldUseTodoTool('what is the capital of France?')).toBe(false);
  });
});
