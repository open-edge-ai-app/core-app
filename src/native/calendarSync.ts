import { NativeModules } from 'react-native';

import {
  getSettings,
  setTaskCalendarEventId,
  type TodoTask,
} from '../state/todoStore';

type CalendarEventInput = {
  eventId?: string;
  title: string;
  startMs: number;
  endMs: number;
  notes?: string;
};

type CalendarNativeModule = {
  isAvailable?: () => Promise<boolean>;
  hasPermission?: () => Promise<boolean>;
  upsertEvent?: (event: CalendarEventInput) => Promise<string>;
  deleteEvent?: (eventId: string) => Promise<boolean>;
};

const nativeModule = NativeModules.CalendarSync as
  | CalendarNativeModule
  | undefined;

export const isCalendarSyncAvailable = (): boolean =>
  Boolean(nativeModule?.upsertEvent);

function taskEventWindow(task: TodoTask): { startMs: number; endMs: number } | null {
  if (!task.dueDateISO) {
    return null;
  }
  const base = new Date(task.dueDateISO);
  if (Number.isNaN(base.getTime())) {
    return null;
  }
  const startHour = task.startHour ?? 13;
  const start = new Date(base);
  start.setHours(
    Math.floor(startHour),
    Math.round((startHour - Math.floor(startHour)) * 60),
    0,
    0,
  );
  const durationHours = task.durationHours ?? 1;
  const endMs = start.getTime() + Math.max(0.5, durationHours) * 3_600_000;
  return { startMs: start.getTime(), endMs };
}

// Mirrors iOS EventKit sync: writes scheduled todos to the system calendar when
// the calendar-sync setting is enabled. No-op when the native module is absent
// (e.g. iOS, web preview, or tests) or sync is disabled.
export async function syncTaskToCalendar(task: TodoTask): Promise<void> {
  if (!isCalendarSyncAvailable() || !getSettings().calendarSync) {
    return;
  }
  const window = taskEventWindow(task);
  if (!window) {
    return;
  }

  try {
    const eventId = await nativeModule?.upsertEvent?.({
      eventId: task.calendarEventId,
      notes: task.note,
      startMs: window.startMs,
      endMs: window.endMs,
      title: task.title,
    });
    if (eventId && eventId !== task.calendarEventId) {
      setTaskCalendarEventId(task.id, eventId);
    }
  } catch {
    // Calendar sync is best-effort; ignore failures.
  }
}

export async function removeTaskFromCalendar(task: TodoTask): Promise<void> {
  if (!isCalendarSyncAvailable() || !task.calendarEventId) {
    return;
  }
  try {
    await nativeModule?.deleteEvent?.(task.calendarEventId);
  } catch {
    // ignore
  }
}
