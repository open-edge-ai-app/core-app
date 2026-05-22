import {
  ensureTodoStoreLoaded,
  getSettings,
  getTasks,
  occurrenceDayKey,
  removeTaskOccurrence,
  setLabels,
  setSettings,
  setTasks,
  taskIsDeletedOn,
  taskOccursOn,
  toggleTaskCompletionOn,
  type TodoTask,
} from '../src/state/todoStore';
import {
  applyTodoToolCalls,
  buildTodoConfirmationCarryOverSection,
  executeTodoToolCall,
  hasExplicitWebSearchTrigger,
  isTodoConfirmationReply,
  isTodoRegistrationQuestion,
  parseTodoToolCalls,
  shouldUseTodoTool,
} from '../src/native/todoTools';

beforeAll(async () => {
  await ensureTodoStoreLoaded();
});

beforeEach(() => {
  setTasks([]);
  setLabels([]);
  setSettings({ hideCompleted: true, showTags: false, calendarSync: false });
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
    const text = '```openedge_tool\n{"tool":"web_search","arguments":{}}\n```';
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
  it('uses Android parity defaults for Todo settings', () => {
    expect(getSettings()).toEqual({
      calendarSync: false,
      hideCompleted: true,
      showTags: false,
    });
  });

  it('removes bundled seed tasks from the shared Todo store', () => {
    setTasks([
      {
        dueLabel: 'Yesterday',
        id: 'seed-call-jason',
        note: '',
        title: 'Call Jason',
      },
      {
        dueLabel: 'Tasks',
        id: 'todo-real',
        note: '',
        title: 'Real task',
      },
    ]);

    expect(getTasks()).toHaveLength(1);
    expect(getTasks()[0].title).toBe('Real task');
  });

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

  it('deletes a single recurring occurrence without removing the series', () => {
    const anchor = new Date(2026, 4, 20);
    const task: TodoTask = {
      id: 't',
      title: 'Daily',
      note: '',
      dueLabel: 'Tasks',
      dueDateISO: anchor.toISOString(),
      repeatRule: 'daily',
    };
    setTasks([task]);

    const deletedDay = new Date(2026, 4, 22);
    const updated = removeTaskOccurrence(task.id, deletedDay);

    expect(updated).not.toBeNull();
    expect(getTasks()).toHaveLength(1);
    expect(taskIsDeletedOn(getTasks()[0], deletedDay)).toBe(true);
    expect(taskOccursOn(getTasks()[0], new Date(2026, 4, 23))).toBe(true);
  });

  it('todo_delete can remove one recurring occurrence when date is provided', () => {
    const anchor = new Date(2026, 4, 20);
    const task: TodoTask = {
      id: 'recurring-delete',
      title: 'Daily',
      note: '',
      dueLabel: 'Tasks',
      dueDateISO: anchor.toISOString(),
      repeatRule: 'daily',
    };
    setTasks([task]);

    executeTodoToolCall({
      name: 'todo_delete',
      arguments: { id: task.id, date: '2026-05-22' },
    });

    expect(getTasks()).toHaveLength(1);
    expect(taskIsDeletedOn(getTasks()[0], new Date(2026, 4, 22))).toBe(true);
  });
});

describe('shouldUseTodoTool', () => {
  it('detects todo and schedule intents but not generic questions', () => {
    expect(shouldUseTodoTool('내일 오후 3시 회의 일정 잡아줘')).toBe(true);
    expect(shouldUseTodoTool('add a task to call mom')).toBe(true);
    expect(shouldUseTodoTool('what is the capital of France?')).toBe(false);
  });

  it('matches iOS declarative Korean schedule handling', () => {
    expect(
      shouldUseTodoTool('오늘 오후 4시부터 5시까지 대한상공회의소 미팅 가신데'),
    ).toBe(true);
  });

  it('detects short confirmations after a schedule prompt', () => {
    expect(isTodoConfirmationReply('네')).toBe(true);
    expect(isTodoConfirmationReply('네 해줘')).toBe(true);
    expect(isTodoConfirmationReply('okay')).toBe(true);
    expect(isTodoConfirmationReply('tell me a joke')).toBe(false);
    expect(isTodoConfirmationReply('why?')).toBe(false);
    expect(isTodoConfirmationReply('예약하지마')).toBe(false);
    expect(isTodoConfirmationReply('아니요')).toBe(false);
  });

  it('matches iOS todo registration question carry-over helpers', () => {
    expect(isTodoRegistrationQuestion('일정으로 등록해 드릴까요?')).toBe(true);
    expect(
      buildTodoConfirmationCarryOverSection('오늘 오후 4시 미팅 가신데'),
    ).toContain('오늘 오후 4시 미팅 가신데');
  });

  it('matches iOS explicit web search trigger handling', () => {
    expect(hasExplicitWebSearchTrigger('내일 축구 일정 검색해줘')).toBe(true);
    expect(hasExplicitWebSearchTrigger('find sources for this')).toBe(true);
    expect(hasExplicitWebSearchTrigger('오늘 오후 4시 미팅 등록해줘')).toBe(
      false,
    );
  });

});
