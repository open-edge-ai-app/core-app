import AsyncStorage from '@react-native-async-storage/async-storage';

export const TODO_STORAGE_KEY = 'open-edge-ai.todo-list.v1';
export const TODO_LABELS_STORAGE_KEY = 'open-edge-ai.todo-labels.v1';
export const TODO_SETTINGS_STORAGE_KEY = 'open-edge-ai.todo-settings.v1';

export type TodoRepeatRule =
  | 'none'
  | 'daily'
  | 'weekdays'
  | 'weekly'
  | 'monthly';

export type TodoSubtask = {
  id: string;
  isComplete: boolean;
  title: string;
};

export type TodoLabel = {
  id: string;
  title: string;
  colorHex: string;
  createdAtISO: string;
};

export type TodoTask = {
  id: string;
  title: string;
  note: string;
  dueDateISO?: string;
  dueLabel: string;
  startHour?: number;
  durationHours?: number;
  isCompleted?: boolean;
  isOverdue?: boolean;
  isStarred?: boolean;
  repeatRule?: TodoRepeatRule;
  subtasks?: TodoSubtask[];
  labelIds?: string[];
  completedOccurrenceDayKeys?: string[];
  deletedOccurrenceDayKeys?: string[];
  calendarEventId?: string;
  createdAtISO?: string;
  updatedAtISO?: string;
};

export type TodoSettings = {
  hideCompleted: boolean;
  showTags: boolean;
  calendarSync: boolean;
};

export const TODO_LABEL_COLORS = [
  '#111111',
  '#FF3B30',
  '#007AFF',
  '#34C759',
  '#FF9500',
  '#AF52DE',
] as const;

export const DEFAULT_TODO_SETTINGS: TodoSettings = {
  hideCompleted: true,
  showTags: false,
  calendarSync: false,
};

let idCounter = 0;
export function createId(prefix: string): string {
  idCounter += 1;
  return `${prefix}-${Date.now().toString(36)}-${idCounter.toString(36)}`;
}

// --- date / recurrence helpers (ported from iOS NativeTodoItem) ---

export function startOfDay(date: Date): Date {
  const value = new Date(date);
  value.setHours(0, 0, 0, 0);
  return value;
}

export function isSameDay(left: Date, right: Date): boolean {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  );
}

export function occurrenceDayKey(date: Date): string {
  const day = startOfDay(date);
  const year = String(day.getFullYear()).padStart(4, '0');
  const month = String(day.getMonth() + 1).padStart(2, '0');
  const dayOfMonth = String(day.getDate()).padStart(2, '0');
  return `${year}-${month}-${dayOfMonth}`;
}

export function taskAnchorDate(task: TodoTask): Date {
  if (task.dueDateISO) {
    return new Date(task.dueDateISO);
  }
  const date = new Date();
  if (task.dueLabel === 'Yesterday') {
    date.setDate(date.getDate() - 1);
  } else if (task.dueLabel === 'Tomorrow') {
    date.setDate(date.getDate() + 1);
  }
  return date;
}

export function taskRepeatRule(task: TodoTask): TodoRepeatRule {
  return task.repeatRule ?? 'none';
}

export function isRepeating(rule: TodoRepeatRule | undefined): boolean {
  return rule !== undefined && rule !== 'none';
}

export function taskIsDeletedOn(task: TodoTask, date: Date): boolean {
  if (!isRepeating(taskRepeatRule(task))) {
    return false;
  }
  return (task.deletedOccurrenceDayKeys ?? []).includes(occurrenceDayKey(date));
}

export function taskIsCompletedOn(task: TodoTask, date: Date): boolean {
  if (!isRepeating(taskRepeatRule(task))) {
    return Boolean(task.isCompleted);
  }
  return (task.completedOccurrenceDayKeys ?? []).includes(
    occurrenceDayKey(date),
  );
}

export function taskOccursOn(task: TodoTask, date: Date): boolean {
  const targetDay = startOfDay(date);
  const anchorDay = startOfDay(taskAnchorDate(task));
  if (targetDay.getTime() < anchorDay.getTime()) {
    return false;
  }
  if (taskIsDeletedOn(task, date)) {
    return false;
  }

  switch (taskRepeatRule(task)) {
    case 'daily':
      return true;
    case 'weekdays': {
      const weekday = targetDay.getDay();
      return weekday >= 1 && weekday <= 5;
    }
    case 'weekly':
      return targetDay.getDay() === anchorDay.getDay();
    case 'monthly':
      return targetDay.getDate() === anchorDay.getDate();
    case 'none':
    default:
      return isSameDay(anchorDay, targetDay);
  }
}

export function taskIsVisibleOn(task: TodoTask, date: Date): boolean {
  return (
    taskOccursOn(task, date) &&
    !taskIsDeletedOn(task, date) &&
    !taskIsCompletedOn(task, date)
  );
}

export function taskIsOverdue(task: TodoTask, now: Date = new Date()): boolean {
  if (isRepeating(taskRepeatRule(task))) {
    return false;
  }
  if (task.isCompleted) {
    return false;
  }
  return startOfDay(taskAnchorDate(task)).getTime() < startOfDay(now).getTime();
}

export function toggleTaskCompletionOn(task: TodoTask, date: Date): TodoTask {
  if (!isRepeating(taskRepeatRule(task))) {
    return {
      ...task,
      isCompleted: !task.isCompleted,
      updatedAtISO: new Date().toISOString(),
    };
  }
  const key = occurrenceDayKey(date);
  const keys = new Set(task.completedOccurrenceDayKeys ?? []);
  if (keys.has(key)) {
    keys.delete(key);
  } else {
    keys.add(key);
  }
  return {
    ...task,
    completedOccurrenceDayKeys: Array.from(keys),
    updatedAtISO: new Date().toISOString(),
  };
}

export function setTaskCompletionOn(
  task: TodoTask,
  date: Date,
  completed: boolean,
): TodoTask {
  if (!isRepeating(taskRepeatRule(task))) {
    return {
      ...task,
      isCompleted: completed,
      updatedAtISO: new Date().toISOString(),
    };
  }
  const key = occurrenceDayKey(date);
  const keys = new Set(task.completedOccurrenceDayKeys ?? []);
  if (completed) {
    keys.add(key);
  } else {
    keys.delete(key);
  }
  return {
    ...task,
    completedOccurrenceDayKeys: Array.from(keys),
    updatedAtISO: new Date().toISOString(),
  };
}

export function deleteTaskOccurrenceOn(
  task: TodoTask,
  date: Date,
): TodoTask | null {
  if (!isRepeating(taskRepeatRule(task))) {
    return null;
  }
  const key = occurrenceDayKey(date);
  const deletedKeys = new Set(task.deletedOccurrenceDayKeys ?? []);
  deletedKeys.add(key);
  const completedKeys = new Set(task.completedOccurrenceDayKeys ?? []);
  completedKeys.delete(key);
  return {
    ...task,
    completedOccurrenceDayKeys: Array.from(completedKeys),
    deletedOccurrenceDayKeys: Array.from(deletedKeys),
    updatedAtISO: new Date().toISOString(),
  };
}

// Each task carries at most one label, matching the iOS behavior.
export function uniqueLabelIds(ids: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const id of ids) {
    if (!id || seen.has(id)) {
      continue;
    }
    seen.add(id);
    result.push(id);
  }
  return result.slice(0, 1);
}

function normalizeTask(raw: TodoTask): TodoTask {
  const rule = raw.repeatRule ?? 'none';
  return {
    ...raw,
    note: raw.note ?? '',
    repeatRule: rule,
    labelIds: uniqueLabelIds(raw.labelIds ?? []),
    subtasks: raw.subtasks ?? [],
    completedOccurrenceDayKeys: raw.completedOccurrenceDayKeys ?? [],
    deletedOccurrenceDayKeys: raw.deletedOccurrenceDayKeys ?? [],
    createdAtISO:
      raw.createdAtISO ?? raw.dueDateISO ?? new Date().toISOString(),
    updatedAtISO:
      raw.updatedAtISO ?? raw.createdAtISO ?? new Date().toISOString(),
  };
}

function isSeedTask(task: TodoTask): boolean {
  return task.id.startsWith('seed-');
}

function normalizeTasks(rawTasks: TodoTask[]): TodoTask[] {
  return rawTasks.filter(task => !isSeedTask(task)).map(normalizeTask);
}

// --- shared in-memory store with persistence + subscriptions ---

type TodoState = {
  tasks: TodoTask[];
  labels: TodoLabel[];
  settings: TodoSettings;
};

type Listener = (state: TodoState) => void;

const state: TodoState = {
  tasks: [],
  labels: [],
  settings: { ...DEFAULT_TODO_SETTINGS },
};

const listeners = new Set<Listener>();
let loadPromise: Promise<void> | null = null;

function notify(): void {
  const snapshot: TodoState = {
    tasks: state.tasks,
    labels: state.labels,
    settings: state.settings,
  };
  listeners.forEach(listener => listener(snapshot));
}

async function readJson<T>(key: string, fallback: T): Promise<T> {
  try {
    const value = await AsyncStorage.getItem(key);
    if (!value) {
      return fallback;
    }
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
}

export function ensureTodoStoreLoaded(): Promise<void> {
  if (!loadPromise) {
    loadPromise = (async () => {
      const [tasks, labels, settings] = await Promise.all([
        readJson<TodoTask[]>(TODO_STORAGE_KEY, []),
        readJson<TodoLabel[]>(TODO_LABELS_STORAGE_KEY, []),
        readJson<Partial<TodoSettings>>(TODO_SETTINGS_STORAGE_KEY, {}),
      ]);
      state.tasks = normalizeTasks(tasks);
      state.labels = labels;
      state.settings = { ...DEFAULT_TODO_SETTINGS, ...settings };
      if (state.tasks.length !== tasks.length) {
        persistTasks();
      }
      notify();
    })();
  }
  return loadPromise;
}

export function getTodoState(): TodoState {
  return { tasks: state.tasks, labels: state.labels, settings: state.settings };
}

export function getTasks(): TodoTask[] {
  return state.tasks;
}

export function getLabels(): TodoLabel[] {
  return state.labels;
}

export function getSettings(): TodoSettings {
  return state.settings;
}

export function subscribeTodoStore(listener: Listener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

function persistTasks(): void {
  AsyncStorage.setItem(TODO_STORAGE_KEY, JSON.stringify(state.tasks)).catch(
    () => {},
  );
}

function persistLabels(): void {
  AsyncStorage.setItem(
    TODO_LABELS_STORAGE_KEY,
    JSON.stringify(state.labels),
  ).catch(() => {});
}

function persistSettings(): void {
  AsyncStorage.setItem(
    TODO_SETTINGS_STORAGE_KEY,
    JSON.stringify(state.settings),
  ).catch(() => {});
}

export function setTasks(next: TodoTask[]): void {
  state.tasks = normalizeTasks(next);
  persistTasks();
  notify();
}

export function setLabels(next: TodoLabel[]): void {
  state.labels = next;
  persistLabels();
  notify();
}

export function setSettings(next: TodoSettings): void {
  state.settings = next;
  persistSettings();
  notify();
}

export function upsertTask(task: TodoTask): void {
  const normalized = normalizeTask(task);
  const index = state.tasks.findIndex(item => item.id === normalized.id);
  if (index >= 0) {
    const next = state.tasks.slice();
    next[index] = normalized;
    setTasks(next);
  } else {
    setTasks([normalized, ...state.tasks]);
  }
}

// Writes back the system-calendar event id without re-triggering calendar sync.
export function setTaskCalendarEventId(
  taskId: string,
  calendarEventId: string | undefined,
): void {
  const index = state.tasks.findIndex(task => task.id === taskId);
  if (index < 0 || state.tasks[index].calendarEventId === calendarEventId) {
    return;
  }
  const next = state.tasks.slice();
  next[index] = { ...next[index], calendarEventId };
  state.tasks = next;
  persistTasks();
  notify();
}

export function removeTask(taskId: string): boolean {
  const next = state.tasks.filter(task => task.id !== taskId);
  if (next.length === state.tasks.length) {
    return false;
  }
  setTasks(next);
  return true;
}

export function removeTaskOccurrence(
  taskId: string,
  date: Date,
): TodoTask | null {
  const task = state.tasks.find(item => item.id === taskId);
  if (!task) {
    return null;
  }
  const nextTask = deleteTaskOccurrenceOn(task, date);
  if (!nextTask) {
    removeTask(taskId);
    return null;
  }
  upsertTask(nextTask);
  return nextTask;
}
