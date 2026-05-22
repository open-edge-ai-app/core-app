import {
  TODO_LABEL_COLORS,
  TodoSettings,
  TodoSubtask,
  TodoTask,
  TodoRepeatRule,
  createId,
  getLabels,
  getSettings,
  getTasks,
  occurrenceDayKey,
  removeTaskOccurrence,
  removeTask,
  setLabels,
  setSettings,
  setTaskCompletionOn,
  startOfDay,
  taskAnchorDate,
  taskIsCompletedOn,
  taskOccursOn,
  uniqueLabelIds,
  upsertTask,
} from '../state/todoStore';
import { removeTaskFromCalendar, syncTaskToCalendar } from './calendarSync';

export type TodoToolCall = {
  name: string;
  arguments: Record<string, unknown>;
};

export type TodoToolApplyResult = {
  cleanedText: string;
  results: string[];
  didMutate: boolean;
  listText: string | null;
};

type TodoDateParts = { day: Date; matchedText: string };

type TodoTimeParts = {
  endHour?: number;
  endMinute?: number;
  matchedText: string;
  startHour: number;
  startMinute: number;
};

const TOOL_FENCE_PATTERN =
  /```(?:openedge_tool|openedge-tool|openedge_tool_call|todo_tool)\s*([\s\S]*?)\s*```/g;

// --- parsing (mirrors NativeTodoToolParser) ---

export function parseTodoToolCalls(text: string): {
  cleanedText: string;
  calls: TodoToolCall[];
} {
  const calls: TodoToolCall[] = [];
  const cleanedText = text.replace(
    TOOL_FENCE_PATTERN,
    (_match, payload: string) => {
      calls.push(...parsePayload(payload));
      return '';
    },
  );
  return { cleanedText: cleanedText.trim(), calls };
}

function parsePayload(payload: string): TodoToolCall[] {
  const trimmed = payload.trim();
  let json: unknown;
  try {
    json = JSON.parse(trimmed);
  } catch {
    return [];
  }

  if (Array.isArray(json)) {
    return json
      .map(makeCall)
      .filter((call): call is TodoToolCall => call !== null);
  }

  if (json && typeof json === 'object') {
    const record = json as Record<string, unknown>;
    const nested = record.calls ?? record.tool_calls;
    if (Array.isArray(nested)) {
      return nested
        .map(makeCall)
        .filter((call): call is TodoToolCall => call !== null);
    }
    const single = makeCall(record);
    return single ? [single] : [];
  }

  return [];
}

function makeCall(value: unknown): TodoToolCall | null {
  if (!value || typeof value !== 'object') {
    return null;
  }
  const record = value as Record<string, unknown>;
  const rawName =
    asString(record.tool) ??
    asString(record.name) ??
    asString(record.tool_name);
  const name = rawName?.trim();
  if (!name || !name.startsWith('todo_')) {
    return null;
  }

  let args = record.arguments ?? record.args;
  if (!args || typeof args !== 'object') {
    args = Object.fromEntries(
      Object.entries(record).filter(
        ([key]) => key !== 'tool' && key !== 'name' && key !== 'tool_name',
      ),
    );
  }
  return { name, arguments: args as Record<string, unknown> };
}

// --- argument coercion helpers (mirror NativeTodoToolParser extensions) ---

function asString(value: unknown): string | undefined {
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number') {
    return String(value);
  }
  return undefined;
}

function argString(
  args: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  for (const key of keys) {
    const value = args[key];
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed) {
        return trimmed;
      }
    } else if (typeof value === 'number') {
      return String(value);
    }
  }
  return undefined;
}

function argBool(
  args: Record<string, unknown>,
  ...keys: string[]
): boolean | undefined {
  for (const key of keys) {
    const value = args[key];
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'number') {
      return value !== 0;
    }
    if (typeof value === 'string') {
      switch (value.toLowerCase().trim()) {
        case 'true':
        case 'yes':
        case 'on':
        case '1':
        case '완료':
        case '켜기':
        case '활성':
          return true;
        case 'false':
        case 'no':
        case 'off':
        case '0':
        case '미완료':
        case '끄기':
        case '비활성':
          return false;
        default:
          break;
      }
    }
  }
  return undefined;
}

function argStringArray(
  args: Record<string, unknown>,
  ...keys: string[]
): string[] | undefined {
  for (const key of keys) {
    const value = args[key];
    if (Array.isArray(value)) {
      return value
        .map(item => asString(item)?.trim() ?? '')
        .filter(item => item.length > 0);
    }
    if (typeof value === 'string') {
      return value
        .split(/[,\n]/)
        .map(item => item.trim())
        .filter(item => item.length > 0);
    }
  }
  return undefined;
}

// --- date / repeat parsing ---

function parseRepeatRule(
  value: string | undefined,
): TodoRepeatRule | undefined {
  if (!value) {
    return undefined;
  }
  switch (value.toLowerCase().trim()) {
    case 'daily':
    case '매일':
      return 'daily';
    case 'weekdays':
    case 'weekday':
    case '평일':
      return 'weekdays';
    case 'weekly':
    case '매주':
      return 'weekly';
    case 'monthly':
    case '매월':
      return 'monthly';
    case 'none':
    case 'never':
    case '반복 없음':
    case '없음':
      return 'none';
    default:
      return undefined;
  }
}

type ParsedDate = { date: Date; hasTime: boolean };

export function parseTodoDate(value: string | undefined): ParsedDate | null {
  if (!value) {
    return null;
  }
  const trimmed = value.trim();
  const lower = trimmed.toLowerCase();

  const relativeBase = new Date();
  if (lower === 'today' || lower === '오늘') {
    return { date: startOfDay(relativeBase), hasTime: false };
  }
  if (lower === 'tomorrow' || lower === '내일') {
    relativeBase.setDate(relativeBase.getDate() + 1);
    return { date: startOfDay(relativeBase), hasTime: false };
  }
  if (lower === 'yesterday' || lower === '어제') {
    relativeBase.setDate(relativeBase.getDate() - 1);
    return { date: startOfDay(relativeBase), hasTime: false };
  }

  const naturalDate = resolveNaturalLanguageDate(trimmed, relativeBase);
  if (naturalDate) {
    const naturalTime = resolveNaturalLanguageTime(trimmed);
    const date = new Date(naturalDate.day);
    if (naturalTime) {
      date.setHours(
        naturalTime.startHour,
        naturalTime.startMinute,
        0,
        0,
      );
    }
    return { date, hasTime: Boolean(naturalTime) };
  }

  const match = trimmed.match(
    /(\d{4})[-./](\d{1,2})[-./](\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?/,
  );
  if (match) {
    const [, year, month, day, hour, minute] = match;
    const date = new Date(
      Number(year),
      Number(month) - 1,
      Number(day),
      hour ? Number(hour) : 0,
      minute ? Number(minute) : 0,
      0,
      0,
    );
    if (!Number.isNaN(date.getTime())) {
      return { date, hasTime: Boolean(hour) };
    }
  }

  const fallback = new Date(trimmed);
  if (!Number.isNaN(fallback.getTime())) {
    return { date: fallback, hasTime: /\d{1,2}:\d{2}/.test(trimmed) };
  }
  return null;
}

function hourFraction(date: Date): number {
  return date.getHours() + date.getMinutes() / 60;
}

function formatTodoDisplayDateTime(date: Date, hasTime: boolean): string {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  if (!hasTime) {
    return `${month}월 ${day}일`;
  }
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  return `${month}월 ${day}일 ${hour}:${minute}`;
}

// --- task / label lookup ---

function findTask(args: Record<string, unknown>): TodoTask | undefined {
  const tasks = getTasks();
  const id = argString(args, 'id', 'task_id', 'todo_id');
  if (id) {
    const byId = tasks.find(task => task.id === id);
    if (byId) {
      return byId;
    }
  }
  const query = argString(args, 'query', 'title', 'name', 'task');
  if (query) {
    const lower = query.toLowerCase();
    return (
      tasks.find(task => task.title.toLowerCase() === lower) ??
      tasks.find(task => task.title.toLowerCase().includes(lower))
    );
  }
  return undefined;
}

function resolveLabelIds(names: string[]): string[] {
  if (names.length === 0) {
    return [];
  }
  const labels = getLabels();
  const next = labels.slice();
  const ids: string[] = [];
  let changed = false;
  for (const name of names) {
    const lower = name.toLowerCase();
    let label = next.find(item => item.title.toLowerCase() === lower);
    if (!label) {
      label = {
        id: createId('label'),
        title: name,
        colorHex: TODO_LABEL_COLORS[next.length % TODO_LABEL_COLORS.length],
        createdAtISO: new Date().toISOString(),
      };
      next.push(label);
      changed = true;
    }
    ids.push(label.id);
  }
  if (changed) {
    setLabels(next);
  }
  return uniqueLabelIds(ids);
}

function labelTitle(labelId: string): string {
  return getLabels().find(label => label.id === labelId)?.title ?? labelId;
}

function findSubtask(
  task: TodoTask,
  args: Record<string, unknown>,
): TodoSubtask | undefined {
  const subtasks = task.subtasks ?? [];
  const id = argString(args, 'subtask_id');
  if (id) {
    const byId = subtasks.find(item => item.id === id);
    if (byId) {
      return byId;
    }
  }
  const query = argString(args, 'subtask', 'subtask_title', 'title');
  if (query) {
    const lower = query.toLowerCase();
    return (
      subtasks.find(item => item.title.toLowerCase() === lower) ??
      subtasks.find(item => item.title.toLowerCase().includes(lower))
    );
  }
  return undefined;
}

// --- executor (mirrors NativeTodoChatTools) ---

export function executeTodoToolCall(call: TodoToolCall): {
  message: string;
  mutated: boolean;
  isList: boolean;
} {
  const args = call.arguments ?? {};
  switch (call.name) {
    case 'todo_list':
      return { message: executeTodoList(args), mutated: false, isList: true };
    case 'todo_create': {
      const message = executeTodoCreate(args);
      return {
        message,
        mutated: message.startsWith('Todo를 추가했습니다:'),
        isList: false,
      };
    }
    case 'todo_update':
      return { message: executeTodoUpdate(args), mutated: true, isList: false };
    case 'todo_complete':
      return {
        message: executeTodoComplete(args),
        mutated: true,
        isList: false,
      };
    case 'todo_delete':
      return { message: executeTodoDelete(args), mutated: true, isList: false };
    case 'todo_star':
      return { message: executeTodoStar(args), mutated: true, isList: false };
    case 'todo_label_create':
      return {
        message: executeLabelCreate(args),
        mutated: true,
        isList: false,
      };
    case 'todo_label_delete':
      return {
        message: executeLabelDelete(args),
        mutated: true,
        isList: false,
      };
    case 'todo_label_assign':
      return {
        message: executeLabelAssign(args),
        mutated: true,
        isList: false,
      };
    case 'todo_subtask_add':
      return { message: executeSubtaskAdd(args), mutated: true, isList: false };
    case 'todo_subtask_toggle':
      return {
        message: executeSubtaskToggle(args),
        mutated: true,
        isList: false,
      };
    case 'todo_subtask_delete':
      return {
        message: executeSubtaskDelete(args),
        mutated: true,
        isList: false,
      };
    case 'todo_settings_update':
      return {
        message: executeSettingsUpdate(args),
        mutated: true,
        isList: false,
      };
    default:
      return {
        message: `Unknown tool: ${call.name}`,
        mutated: false,
        isList: false,
      };
  }
}

function executeTodoList(args: Record<string, unknown>): string {
  const filter = (argString(args, 'filter') ?? 'all').toLowerCase();
  const includeCompleted =
    argBool(args, 'include_completed') ?? !getSettings().hideCompleted;
  const targetDate = parseTodoDate(argString(args, 'date'))?.date ?? new Date();
  const now = new Date();
  const tasks = getTasks();

  let matched: TodoTask[];
  switch (filter) {
    case 'today':
      matched = tasks.filter(task => taskOccursOn(task, now));
      break;
    case 'tomorrow': {
      const tomorrow = new Date(now);
      tomorrow.setDate(now.getDate() + 1);
      matched = tasks.filter(task => taskOccursOn(task, tomorrow));
      break;
    }
    case 'overdue':
      matched = tasks.filter(
        task =>
          taskRepeatRuleIsNone(task) &&
          !task.isCompleted &&
          startOfDay(taskAnchorDate(task)).getTime() <
            startOfDay(now).getTime(),
      );
      break;
    case 'date':
      matched = tasks.filter(task => taskOccursOn(task, targetDate));
      break;
    case 'all':
    default:
      matched = tasks.slice();
      break;
  }

  if (!includeCompleted) {
    const reference = filter === 'date' ? targetDate : now;
    matched = matched.filter(task => !taskIsCompletedOn(task, reference));
  }

  if (matched.length === 0) {
    return '할 일이 없습니다.';
  }

  const lines = matched.slice(0, 50).map(task => {
    const star = task.isStarred ? '⭐ ' : '';
    const labels = (task.labelIds ?? []).map(labelTitle).join(', ');
    const labelText = labels ? ` #${labels}` : '';
    const due = task.dueDateISO
      ? new Date(task.dueDateISO).toLocaleString()
      : task.dueLabel;
    return `- ${star}${task.title}${labelText} (${due})`;
  });
  return lines.join('\n');
}

function taskRepeatRuleIsNone(task: TodoTask): boolean {
  return (task.repeatRule ?? 'none') === 'none';
}

function executeTodoCreate(args: Record<string, unknown>): string {
  const title = argString(args, 'title', 'name');
  if (!title) {
    return 'Todo를 만들려면 제목이 필요합니다.';
  }
  const rawStart = argString(args, 'start_at', 'start', 'due_at', 'date');
  const rawEnd = argString(args, 'end_at', 'end');
  const start = parseTodoDate(rawStart);
  if (rawStart && !start) {
    return `Todo 날짜/시간을 이해하지 못했습니다: ${rawStart}`;
  }
  const end = parseTodoDate(rawEnd);
  if (rawEnd && !end) {
    return `Todo 종료 시간을 이해하지 못했습니다: ${rawEnd}`;
  }
  const repeat =
    parseRepeatRule(argString(args, 'repeat', 'repeat_rule')) ?? 'none';
  const labelIds = resolveLabelIds(
    argStringArray(args, 'labels', 'label_names', 'tags') ?? [],
  );
  const starred = argBool(args, 'starred', 'important') ?? false;

  const startDate = start?.date ?? new Date();
  const startHour = start?.hasTime ? hourFraction(start.date) : 13;
  const durationHours =
    end && end.date.getTime() > startDate.getTime()
      ? Math.max(0.5, (end.date.getTime() - startDate.getTime()) / 3_600_000)
      : 1;

  const nowISO = new Date().toISOString();
  const task: TodoTask = {
    id: createId('todo'),
    title,
    note: argString(args, 'note', 'memo') ?? '',
    dueDateISO: startDate.toISOString(),
    dueLabel: 'Tasks',
    startHour,
    durationHours,
    isStarred: starred,
    repeatRule: repeat,
    labelIds,
    subtasks: [],
    completedOccurrenceDayKeys: [],
    deletedOccurrenceDayKeys: [],
    createdAtISO: nowISO,
    updatedAtISO: nowISO,
  };
  upsertTask(task);
  syncTaskToCalendar(task).catch(() => undefined);
  return `Todo를 추가했습니다: ${title} (${formatTodoDisplayDateTime(
    startDate,
    start?.hasTime ?? false,
  )})`;
}

function executeTodoUpdate(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '수정할 Todo를 찾지 못했습니다.';
  }
  const next: TodoTask = { ...task };
  next.title = argString(args, 'title', 'name') ?? task.title;
  const note = argString(args, 'note', 'memo');
  if (note !== undefined) {
    next.note = note;
  }
  const start = parseTodoDate(
    argString(args, 'start_at', 'start', 'due_at', 'date'),
  );
  if (start) {
    next.dueDateISO = start.date.toISOString();
    if (start.hasTime) {
      next.startHour = hourFraction(start.date);
    }
  }
  const end = parseTodoDate(argString(args, 'end_at', 'end'));
  if (end && next.dueDateISO) {
    const startMs = new Date(next.dueDateISO).getTime();
    if (end.date.getTime() > startMs) {
      next.durationHours = Math.max(
        0.5,
        (end.date.getTime() - startMs) / 3_600_000,
      );
    }
  }
  const repeat = parseRepeatRule(argString(args, 'repeat', 'repeat_rule'));
  if (repeat) {
    next.repeatRule = repeat;
  }
  const labelNames = argStringArray(args, 'labels', 'label_names', 'tags');
  if (labelNames) {
    next.labelIds = resolveLabelIds(labelNames);
  }
  const starred = argBool(args, 'starred', 'important');
  if (starred !== undefined) {
    next.isStarred = starred;
  }
  next.updatedAtISO = new Date().toISOString();
  upsertTask(next);
  syncTaskToCalendar(next).catch(() => undefined);
  return `Todo를 수정했습니다: ${next.title}`;
}

function executeTodoComplete(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '완료 처리할 Todo를 찾지 못했습니다.';
  }
  const date = parseTodoDate(argString(args, 'date'))?.date ?? new Date();
  const completed = argBool(args, 'completed') ?? true;
  upsertTask(setTaskCompletionOn(task, date, completed));
  return `${task.title} 항목을 ${
    completed ? '완료' : '미완료'
  }로 표시했습니다.`;
}

function executeTodoDelete(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '삭제할 Todo를 찾지 못했습니다.';
  }
  const occurrenceDate = parseTodoDate(argString(args, 'date'))?.date;
  if (!taskRepeatRuleIsNone(task) && occurrenceDate) {
    removeTaskOccurrence(task.id, occurrenceDate);
    return `반복 Todo의 해당 날짜 항목을 삭제했습니다: ${task.title}`;
  }
  removeTaskFromCalendar(task).catch(() => undefined);
  removeTask(task.id);
  return `Todo를 삭제했습니다: ${task.title}`;
}

function executeTodoStar(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '중요 표시할 Todo를 찾지 못했습니다.';
  }
  const starred = argBool(args, 'starred', 'important') ?? !task.isStarred;
  upsertTask({
    ...task,
    isStarred: starred,
    updatedAtISO: new Date().toISOString(),
  });
  return `${task.title} 항목의 중요 표시를 ${
    starred ? '켰습니다' : '껐습니다'
  }.`;
}

function executeLabelCreate(args: Record<string, unknown>): string {
  const name = argString(args, 'name', 'title', 'label');
  if (!name) {
    return '태그 이름이 필요합니다.';
  }
  resolveLabelIds([name]);
  return `태그를 만들었습니다: ${name}`;
}

function executeLabelDelete(args: Record<string, unknown>): string {
  const name = argString(args, 'name', 'title', 'label');
  if (!name) {
    return '삭제할 태그 이름이 필요합니다.';
  }
  const lower = name.toLowerCase();
  const labels = getLabels();
  const target = labels.find(label => label.title.toLowerCase() === lower);
  if (!target) {
    return '태그를 찾지 못했습니다.';
  }
  setLabels(labels.filter(label => label.id !== target.id));
  getTasks().forEach(task => {
    if ((task.labelIds ?? []).includes(target.id)) {
      upsertTask({
        ...task,
        labelIds: (task.labelIds ?? []).filter(id => id !== target.id),
      });
    }
  });
  return `태그를 삭제했습니다: ${name}`;
}

function executeLabelAssign(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '태그를 적용할 Todo를 찾지 못했습니다.';
  }
  const mode = (argString(args, 'mode') ?? 'replace').toLowerCase();
  const names = argStringArray(args, 'labels', 'label_names', 'tags') ?? [];
  if (mode === 'remove') {
    upsertTask({ ...task, labelIds: [] });
    return `${task.title} 항목의 태그를 제거했습니다.`;
  }
  const ids = resolveLabelIds(names);
  upsertTask({ ...task, labelIds: ids });
  return `${task.title} 항목에 태그를 적용했습니다.`;
}

function executeSubtaskAdd(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '하위 작업을 추가할 Todo를 찾지 못했습니다.';
  }
  const title = argString(args, 'title', 'subtask', 'subtask_title');
  if (!title) {
    return '하위 작업 제목이 필요합니다.';
  }
  const subtask: TodoSubtask = {
    id: createId('subtask'),
    title,
    isComplete: false,
  };
  upsertTask({ ...task, subtasks: [...(task.subtasks ?? []), subtask] });
  return `하위 작업을 추가했습니다: ${title}`;
}

function executeSubtaskToggle(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '하위 작업이 있는 Todo를 찾지 못했습니다.';
  }
  const subtask = findSubtask(task, args);
  if (!subtask) {
    return '하위 작업을 찾지 못했습니다.';
  }
  const completed = argBool(args, 'completed') ?? !subtask.isComplete;
  upsertTask({
    ...task,
    subtasks: (task.subtasks ?? []).map(item =>
      item.id === subtask.id ? { ...item, isComplete: completed } : item,
    ),
  });
  return `하위 작업을 ${completed ? '완료' : '미완료'}로 표시했습니다: ${
    subtask.title
  }`;
}

function executeSubtaskDelete(args: Record<string, unknown>): string {
  const task = findTask(args);
  if (!task) {
    return '하위 작업이 있는 Todo를 찾지 못했습니다.';
  }
  const subtask = findSubtask(task, args);
  if (!subtask) {
    return '하위 작업을 찾지 못했습니다.';
  }
  upsertTask({
    ...task,
    subtasks: (task.subtasks ?? []).filter(item => item.id !== subtask.id),
  });
  return `하위 작업을 삭제했습니다: ${subtask.title}`;
}

function executeSettingsUpdate(args: Record<string, unknown>): string {
  const current = getSettings();
  const next: TodoSettings = {
    hideCompleted: argBool(args, 'hide_completed') ?? current.hideCompleted,
    showTags: argBool(args, 'show_tags') ?? current.showTags,
    calendarSync: argBool(args, 'calendar_sync') ?? current.calendarSync,
  };
  setSettings(next);
  return 'Todo 설정을 업데이트했습니다.';
}

// --- prompt sections (mirror NativeChatModels / NativeTodoChatTools) ---

export function hasExplicitWebSearchTrigger(text: string): boolean {
  const normalized = text.toLowerCase();
  const explicitTriggers = [
    '검색',
    '찾아',
    '구글',
    '웹',
    '인터넷',
    '출처',
    '근거',
    '링크',
    'search',
    'web',
    'internet',
    'source',
    'sources',
    'lookup',
    'look up',
  ];
  return explicitTriggers.some(term => normalized.includes(term));
}

export function shouldUseTodoTool(text: string): boolean {
  const normalized = text.toLowerCase().trim();
  if (!normalized) {
    return false;
  }

  const directTerms = [
    'todo',
    'to-do',
    'task',
    '할 일',
    '할일',
    '태스크',
    '리마인드',
    '리마인더',
    '알림',
    'remind',
    'reminder',
  ];
  if (directTerms.some(term => normalized.includes(term))) {
    return true;
  }

  const eventTerms = [
    '일정',
    '스케줄',
    '캘린더',
    '회의',
    '미팅',
    '약속',
    '예약',
    '면담',
    '방문',
    '통화',
    '콜',
    'schedule',
    'calendar',
    'meeting',
    'appointment',
    'reservation',
    'call',
  ];
  const scheduleVerbs = [
    '추가',
    '등록',
    '넣어',
    '만들',
    '생성',
    '저장',
    '기록',
    '잡아',
    '정리',
    '가신데',
    '간데',
    '가신다고',
    '간다고',
    '있대',
    '있어',
    '예정',
    '잡혀',
    '잡혔',
    '해야',
    '하래',
    'add',
    'create',
    'save',
    'schedule',
    'book',
  ];
  const timePatterns = [
    /오전|오후|아침|점심|저녁|밤/,
    /\d{1,2}\s*시/,
    /\d{1,2}\s*:\s*\d{2}/,
    /오늘|내일|모레|이번\s*주|다음\s*주|다음\s*달/,
    /\d{1,2}\s*월\s*\d{1,2}\s*일/,
    /\d{4}[-./]\d{1,2}[-./]\d{1,2}/,
  ];
  const hasEvent = eventTerms.some(term => normalized.includes(term));
  const hasVerb = scheduleVerbs.some(term => normalized.includes(term));
  const hasTime = timePatterns.some(pattern => pattern.test(normalized));

  if (hasEvent && (hasTime || hasVerb)) {
    return true;
  }
  return hasVerb && hasTime;
}

function resolveNaturalLanguageDate(
  text: string,
  now: Date,
): TodoDateParts | null {
  const normalized = text.replace(/\s+/g, ' ').trim();
  const base = new Date(now);

  const relativeMatches: Array<[RegExp, number]> = [
    [/(오늘)/, 0],
    [/(내일)/, 1],
    [/(모레)/, 2],
    [/\b(today)\b/i, 0],
    [/\b(tomorrow)\b/i, 1],
  ];
  for (const [pattern, offset] of relativeMatches) {
    const match = normalized.match(pattern);
    if (match) {
      const day = new Date(base);
      day.setDate(base.getDate() + offset);
      return { day: startOfDay(day), matchedText: match[0] };
    }
  }

  const absoluteMatch = normalized.match(
    /(?:(\d{4})\s*년\s*)?(\d{1,2})\s*월\s*(\d{1,2})\s*일/,
  );
  if (absoluteMatch) {
    const [, rawYear, rawMonth, rawDay] = absoluteMatch;
    const day = new Date(
      rawYear ? Number(rawYear) : base.getFullYear(),
      Number(rawMonth) - 1,
      Number(rawDay),
    );
    if (!rawYear && startOfDay(day).getTime() < startOfDay(base).getTime()) {
      day.setFullYear(day.getFullYear() + 1);
    }
    return { day: startOfDay(day), matchedText: absoluteMatch[0] };
  }

  const isoMatch = normalized.match(
    /(\d{4})[-./](\d{1,2})[-./](\d{1,2})/,
  );
  if (isoMatch) {
    const [, rawYear, rawMonth, rawDay] = isoMatch;
    return {
      day: startOfDay(
        new Date(Number(rawYear), Number(rawMonth) - 1, Number(rawDay)),
      ),
      matchedText: isoMatch[0],
    };
  }

  const weekdayMatch = normalized.match(
    /(이번\s*주|다음\s*주|이번주|다음주)?\s*(월|화|수|목|금|토|일)(?:요일)?/,
  );
  if (weekdayMatch) {
    const weekPrefix = (weekdayMatch[1] ?? '').replace(/\s+/g, '');
    const weekday = ['일', '월', '화', '수', '목', '금', '토'].indexOf(
      weekdayMatch[2],
    );
    if (weekday >= 0) {
      const day = new Date(base);
      let offset = weekday - base.getDay();
      if (weekPrefix === '다음주') {
        offset += offset <= 0 ? 7 : 0;
      } else if (weekPrefix !== '이번주' && offset < 0) {
        offset += 7;
      }
      day.setDate(base.getDate() + offset);
      return { day: startOfDay(day), matchedText: weekdayMatch[0] };
    }
  }

  return null;
}

function toClockHour(period: string | undefined, rawHour: number): number {
  if (period === '오후' && rawHour < 12) {
    return rawHour + 12;
  }
  if (period === '오전' && rawHour === 12) {
    return 0;
  }
  return rawHour;
}

function resolveNaturalLanguageTime(text: string): TodoTimeParts | null {
  const normalized = text.replace(/\s+/g, ' ').trim();
  const rangeMatch = normalized.match(
    /(?:(오전|오후)\s*)?(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*(?:부터|에서|~|-|–|—)\s*(?:(오전|오후)\s*)?(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*(?:까지)?/,
  );
  if (rangeMatch) {
    const [, startPeriod, rawStartHour, rawStartMinute, rawEndPeriod, rawEndHour, rawEndMinute] =
      rangeMatch;
    const startHour = toClockHour(startPeriod, Number(rawStartHour));
    const endPeriod = rawEndPeriod ?? startPeriod;
    const endHour = toClockHour(endPeriod, Number(rawEndHour));
    return {
      endHour,
      endMinute: rawEndMinute ? Number(rawEndMinute) : 0,
      matchedText: rangeMatch[0],
      startHour,
      startMinute: rawStartMinute ? Number(rawStartMinute) : 0,
    };
  }

  const colonMatch = normalized.match(/(?:(오전|오후)\s*)?(\d{1,2}):(\d{2})/);
  if (colonMatch) {
    const [, period, rawHour, rawMinute] = colonMatch;
    return {
      matchedText: colonMatch[0],
      startHour: toClockHour(period, Number(rawHour)),
      startMinute: Number(rawMinute),
    };
  }

  const singlePattern =
    /(?:(오전|오후)\s*)?(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?/g;
  const eventIndex = normalized.search(
    /미팅|회의|약속|예약|면담|방문|통화|콜|meeting|appointment|reservation|call/i,
  );
  const candidates: Array<RegExpExecArray> = [];
  let singleMatch: RegExpExecArray | null;
  while ((singleMatch = singlePattern.exec(normalized)) !== null) {
    candidates.push(singleMatch);
  }
  if (candidates.length > 0) {
    const selected =
      eventIndex >= 0
        ? candidates
            .filter(match => match.index <= eventIndex)
            .sort((left, right) => right.index - left.index)[0] ??
          candidates[0]
        : candidates[0];
    const [, period, rawHour, rawMinute] = selected;
    return {
      matchedText: selected[0],
      startHour: toClockHour(period, Number(rawHour)),
      startMinute: rawMinute ? Number(rawMinute) : 0,
    };
  }

  return null;
}

export function isTodoConfirmationReply(text: string): boolean {
  const compact = text
    .toLowerCase()
    .replace(/[.!?。！？\s]/g, '')
    .trim();
  if (!compact || compact.length > 40) {
    return false;
  }

  const exactTerms = ['doit', '네', '예', '응', '웅', 'ㅇㅋ'];
  if (exactTerms.includes(compact)) {
    return true;
  }

  const englishTokens = text
    .toLowerCase()
    .replace(/[.!?。！？]/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  const englishTerms = ['yes', 'ok', 'okay', 'yep', 'sure', 'please'];
  if (englishTokens.some(token => englishTerms.includes(token))) {
    return true;
  }

  const koreanTerms = [
    '알겠어',
    '좋아',
    '그래',
    '맞아',
    '부탁',
    '해줘',
    '해주세요',
    '등록해줘',
    '추가해줘',
  ];
  return koreanTerms.some(term => compact.includes(term));
}

export function isTodoRegistrationQuestion(text: string): boolean {
  const normalized = text.toLowerCase().replace(/\s+/g, '');
  return [
    '등록해드릴까요',
    '등록할까요',
    '일정으로등록',
    'todo로등록',
    '할일로등록',
    '추가해드릴까요',
    '추가할까요',
    '저장해드릴까요',
    'wouldyoulikemetoadd',
    'shouldiadd',
    'addthisto',
  ].some(term => normalized.includes(term));
}

export function buildTodoConfirmationCarryOverSection(
  previousScheduleText: string,
): string {
  const scheduleText = previousScheduleText
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 500);
  return [
    'Todo confirmation carry-over:',
    '- The current user message is an affirmative response to the assistant asking whether to register a Todo/schedule.',
    `- Create the Todo now by using this previous user schedule statement as the source: ${scheduleText}`,
    '- Do not ask for confirmation again.',
    '- Emit a todo_create openedge_tool block and keep the visible answer brief.',
  ].join('\n');
}

export function buildTodoToolStateSection(): string | null {
  const tasks = getTasks();
  if (tasks.length === 0) {
    return null;
  }
  const lines = tasks.slice(0, 40).map(task => {
    const status = task.isCompleted ? 'completed' : 'open';
    const labels = (task.labelIds ?? []).map(labelTitle).join(', ') || 'none';
    const due = task.dueDateISO ?? task.dueLabel;
    return `- id=${task.id} | "${
      task.title
    }" | ${status} | due=${due} | repeat=${
      task.repeatRule ?? 'none'
    } | tags=${labels}`;
  });
  return `Current Todo items (use the id when updating/deleting):\n${lines.join(
    '\n',
  )}`;
}

export function buildTodoToolPromptSection(now: Date = new Date()): string {
  const today = occurrenceDayKey(now);
  return [
    'Todo app tools:',
    '- IMPORTANT: This todo system manages in-app local tasks and schedules. It does NOT use or need any external calendar, device calendar, or calendar API permissions. Never say you cannot access a calendar or that you lack calendar integration. For ANY schedule/meeting/appointment/reminder request, immediately emit an openedge_tool block — do not explain limitations.',
    '- todo_list(filter, date, include_completed): reads Todo tasks. filter is all, today, tomorrow, overdue, or date.',
    '- todo_create(title, note, start_at, end_at, repeat, labels, starred): creates a Todo. Use at most one label.',
    '- todo_update(id or query, title, note, start_at, end_at, repeat, labels, starred): edits a Todo. Use at most one label.',
    '- todo_complete(id or query, date, completed): marks a Todo or one recurring occurrence complete/incomplete.',
    '- todo_delete(id or query, date): deletes a Todo. For a recurring Todo, include date to delete only that occurrence.',
    '- todo_star(id or query, starred): changes important/starred state.',
    '- todo_label_create(name), todo_label_delete(name), todo_label_assign(id or query, labels, mode): manages tags. Each Todo can have only one tag; mode is replace or remove.',
    '- todo_subtask_add(id or query, title), todo_subtask_toggle(id or query, subtask, completed), todo_subtask_delete(id or query, subtask): manages subtasks.',
    '- todo_settings_update(hide_completed, show_tags, calendar_sync): updates Todo display/calendar settings.',
    'Todo tool call format:',
    '- When the user asks to change, create, delete, list, tag, schedule, or configure Todo items, include one fenced block exactly like:',
    '```openedge_tool',
    '{"tool":"todo_create","arguments":{"title":"...","start_at":"' +
      today +
      ' 13:00","end_at":"' +
      today +
      ' 14:00","repeat":"none","labels":["..."]}}',
    '```',
    '- Todo, schedule, reminder, meeting, and appointment requests have priority over web search unless the user explicitly asks to search the web.',
    '- Named people, companies, venues, or places inside a Todo sentence are usually Todo title/note content, not a reason to search.',
    '- Korean declarative schedule statements such as "오늘 오후 4시부터 5시까지 대한상공회의소 미팅 가신데" mean create a Todo/schedule item unless the sentence is clearly a question.',
    '- If the date/time and event content are sufficient, do not ask for confirmation; emit todo_create immediately.',
    '- If the assistant previously asked whether to register a Todo/schedule and the user replies yes/okay/알겠어/네/응, use the previous user schedule statement and emit todo_create immediately.',
    '- When the user asks about today\'s tasks or "오늘 할 일", call todo_list with filter="today".',
    '- For todo_list, do not include internal ids in visible prose; the app formats the list for the user.',
    '- You may include an array of calls in one block.',
    `- The user's local date is ${today}. Use yyyy-MM-dd HH:mm format for dates.`,
    '- Keep any normal answer concise; the app executes the tool and hides the JSON block from the user.',
  ].join('\n');
}

// --- top-level entry used by the chat screen ---

export function applyTodoToolCalls(text: string): TodoToolApplyResult {
  const { cleanedText, calls } = parseTodoToolCalls(text);
  if (calls.length === 0) {
    return { cleanedText: text, results: [], didMutate: false, listText: null };
  }

  const results: string[] = [];
  let didMutate = false;
  let listText: string | null = null;

  for (const call of calls) {
    const outcome = executeTodoToolCall(call);
    results.push(outcome.message);
    if (outcome.mutated) {
      didMutate = true;
    }
    if (outcome.isList) {
      listText = outcome.message;
    }
  }

  return { cleanedText, results, didMutate, listText };
}
