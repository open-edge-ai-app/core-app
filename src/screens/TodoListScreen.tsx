import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { ScaledText as Text } from '../theme/display';
import { colors } from '../theme/tokens';

type TodoTab = 'all' | 'calendar';

type TodoSubtask = {
  id: string;
  isComplete: boolean;
  title: string;
};

type TodoTask = {
  dueDateISO?: string;
  dueLabel: string;
  id: string;
  durationHours?: number;
  isCompleted?: boolean;
  isOverdue?: boolean;
  isStarred?: boolean;
  note: string;
  startHour?: number;
  subtasks?: TodoSubtask[];
  title: string;
};

const TODO_STORAGE_KEY = 'open-edge-ai.todo-list.v1';
const CALENDAR_START_HOUR = 1;
const HOUR_ROW_HEIGHT = 58;
const HOUR_LINE_OFFSET = 9;
const CALENDAR_LANE_START = 60;
const CALENDAR_LANE_WIDTH = 68;
const CALENDAR_EVENT_WIDTH = 58;
const CALENDAR_HOURS = Array.from({ length: 24 }, (_, index) => index + 1);

function dateAtHour(dayOffset: number, hour: number) {
  const date = new Date();
  date.setDate(date.getDate() + dayOffset);
  date.setHours(hour, 0, 0, 0);
  return date.toISOString();
}

const initialTasks: TodoTask[] = [
  {
    dueDateISO: dateAtHour(-1, 11),
    dueLabel: 'Yesterday',
    durationHours: 1,
    id: 'seed-call-jason',
    isOverdue: true,
    note: '',
    startHour: 11,
    title: 'Call Jason',
  },
  {
    dueDateISO: dateAtHour(0, 19),
    dueLabel: 'Today',
    durationHours: 1,
    id: 'seed-email-james',
    isStarred: true,
    note:
      'Email Mrs. James for the new intern we have next week from Alex Carter, a marketing student from Brookfield University. Confirm their start date, schedule, and onboarding needs.',
    startHour: 19,
    title: 'Email Back Mrs James',
  },
  {
    dueDateISO: dateAtHour(0, 13),
    dueLabel: 'Today',
    durationHours: 4,
    id: 'seed-design-system',
    note: '',
    startHour: 13,
    subtasks: [
      {
        id: 'seed-design-system-1',
        isComplete: true,
        title: 'Update the UI system with a modern, cohesive design.',
      },
      {
        id: 'seed-design-system-2',
        isComplete: false,
        title: 'Focus on consistency, scalability, and accessibility.',
      },
      {
        id: 'seed-design-system-3',
        isComplete: false,
        title: 'Use clean aesthetics with reusable, responsive components.',
      },
      {
        id: 'seed-design-system-4',
        isComplete: false,
        title: 'Enhance usability for a seamless user experience.',
      },
      {
        id: 'seed-design-system-5',
        isComplete: false,
        title: 'Streamline development with clear design guidelines.',
      },
    ],
    title: 'New Design System',
  },
];

const weekDays = [
  ['S', '17'],
  ['M', '18'],
  ['T', '19'],
  ['W', '20'],
  ['T', '21'],
  ['F', '22'],
  ['S', '23'],
];

export default function TodoListScreen() {
  const [tab, setTab] = useState<TodoTab>('all');
  const [tasks, setTasks] = useState<TodoTask[]>(initialTasks);
  const [hasLoadedTasks, setHasLoadedTasks] = useState(false);
  const [isOverdueExpanded, setOverdueExpanded] = useState(true);
  const [isTodayExpanded, setTodayExpanded] = useState(true);
  const dateTitle = useMemo(
    () =>
      new Intl.DateTimeFormat('en-US', {
        day: '2-digit',
        month: 'long',
        weekday: 'short',
      }).format(new Date()),
    [],
  );
  const visibleTasks = useMemo(
    () => tasks.filter(task => !task.isCompleted),
    [tasks],
  );
  const overdueTasks = useMemo(
    () => visibleTasks.filter(task => task.isOverdue),
    [visibleTasks],
  );
  const todayTasks = useMemo(
    () => visibleTasks.filter(task => !task.isOverdue),
    [visibleTasks],
  );
  const calendarTasks = useMemo(
    () => todayTasks.filter(task => task.dueLabel !== 'Yesterday'),
    [todayTasks],
  );

  useEffect(() => {
    let isMounted = true;
    AsyncStorage.getItem(TODO_STORAGE_KEY)
      .then(value => {
        if (!isMounted) {
          return;
        }
        if (value) {
          setTasks(JSON.parse(value) as TodoTask[]);
        }
      })
      .finally(() => {
        if (isMounted) {
          setHasLoadedTasks(true);
        }
      });
    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    if (!hasLoadedTasks) {
      return;
    }
    AsyncStorage.setItem(TODO_STORAGE_KEY, JSON.stringify(tasks)).catch(() => {});
  }, [hasLoadedTasks, tasks]);

  const addTask = () => {
    const startHour = 13 + (todayTasks.length % 5);
    const nextTask: TodoTask = {
      dueDateISO: dateAtHour(0, startHour),
      dueLabel: 'Today',
      durationHours: 1,
      id: `todo-${Date.now()}`,
      note: '',
      startHour,
      title: 'New Todo',
    };
    setTasks(current => [nextTask, ...current]);
  };

  const toggleTaskComplete = (taskId: string) => {
    setTasks(current =>
      current.map(task =>
        task.id === taskId ? { ...task, isCompleted: !task.isCompleted } : task,
      ),
    );
  };

  const toggleTaskStar = (taskId: string) => {
    setTasks(current =>
      current.map(task =>
        task.id === taskId ? { ...task, isStarred: !task.isStarred } : task,
      ),
    );
  };

  const toggleSubtask = (taskId: string, subtaskId: string) => {
    setTasks(current =>
      current.map(task => {
        if (task.id !== taskId || !task.subtasks) {
          return task;
        }
        return {
          ...task,
          subtasks: task.subtasks.map(subtask =>
            subtask.id === subtaskId
              ? { ...subtask, isComplete: !subtask.isComplete }
              : subtask,
          ),
        };
      }),
    );
  };

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <Text style={styles.dateTitle}>{dateTitle}</Text>
        </View>
        <View style={styles.segmentedControl}>
          <Pressable
            onPress={() => setTab('all')}
            style={[
              styles.segmentedButton,
              tab === 'all' && styles.segmentedButtonActive,
            ]}
          >
            <Text
              style={[
                styles.segmentedText,
                tab === 'all' && styles.segmentedTextActive,
              ]}
            >
              리스트
            </Text>
          </Pressable>
          <Pressable
            onPress={() => setTab('calendar')}
            style={[
              styles.segmentedButton,
              tab === 'calendar' && styles.segmentedButtonActive,
            ]}
          >
            <Text
              style={[
                styles.segmentedText,
                tab === 'calendar' && styles.segmentedTextActive,
              ]}
            >
              캘린더
            </Text>
          </Pressable>
        </View>
      </View>

      {tab === 'all' ? (
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <SectionHeader
            expanded={isOverdueExpanded}
            onPress={() => setOverdueExpanded(current => !current)}
            title="Overdue"
          />
          {isOverdueExpanded
            ? overdueTasks.map(task => (
                <TodoCard
                  key={task.id}
                  onToggleComplete={() => toggleTaskComplete(task.id)}
                  onToggleStar={() => toggleTaskStar(task.id)}
                  onToggleSubtask={subtaskId => toggleSubtask(task.id, subtaskId)}
                  task={task}
                />
              ))
            : null}
          <SectionHeader
            expanded={isTodayExpanded}
            onPress={() => setTodayExpanded(current => !current)}
            title="Today"
          />
          {isTodayExpanded
            ? todayTasks.map(task => (
                <TodoCard
                  key={task.id}
                  onToggleComplete={() => toggleTaskComplete(task.id)}
                  onToggleStar={() => toggleTaskStar(task.id)}
                  onToggleSubtask={subtaskId => toggleSubtask(task.id, subtaskId)}
                  task={task}
                />
              ))
            : null}
        </ScrollView>
      ) : (
        <View style={styles.calendarContent}>
          <View style={styles.weekStrip}>
            <Text style={styles.weekArrow}>‹</Text>
            {weekDays.map(([day, number]) => (
              <View
                key={number}
                style={[
                  styles.weekDay,
                  number === '19' && styles.weekDayActive,
                ]}
              >
                <Text
                  style={[
                    styles.weekDayText,
                    number === '19' && styles.weekDayTextActive,
                  ]}
                >
                  {day}
                </Text>
                <Text
                  style={[
                    styles.weekNumberText,
                    number === '19' && styles.weekDayTextActive,
                  ]}
                >
                  {number}
                </Text>
              </View>
            ))}
            <Text style={styles.weekArrow}>›</Text>
          </View>
          <ScrollView
            contentContainerStyle={styles.timeline}
            showsVerticalScrollIndicator={false}
          >
            {CALENDAR_HOURS.map(hour => (
                <View key={hour} style={styles.hourRow}>
                  <Text style={styles.hourText}>{formatTimelineHour(hour)}</Text>
                  <View style={styles.hourGuide}>
                    <View style={styles.hourLine} />
                    {hour < 24 ? <View style={styles.halfHourTick} /> : null}
                  </View>
                </View>
              ))}
            {calendarTasks.length > 0 ? (
              calendarTasks.slice(0, 4).map((task, index) => (
                <CalendarBlock
                  key={task.id}
                  lane={index}
                  task={task}
                />
              ))
            ) : (
              <Text style={styles.calendarEmptyText}>No scheduled tasks</Text>
            )}
          </ScrollView>
        </View>
      )}

      <View style={styles.bottomBar}>
        <Pressable onPress={addTask} style={styles.bottomButton}>
          <Text style={styles.plusText}>+</Text>
        </Pressable>
      </View>
    </View>
  );
}

function SectionHeader({
  expanded,
  onPress,
  title,
}: {
  expanded: boolean;
  onPress: () => void;
  title: string;
}) {
  return (
    <Pressable onPress={onPress} style={styles.sectionHeader}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <Text style={styles.sectionChevron}>{expanded ? '⌄' : '›'}</Text>
    </Pressable>
  );
}

function TodoCard({
  onToggleComplete,
  onToggleStar,
  onToggleSubtask,
  task,
}: {
  onToggleComplete: () => void;
  onToggleStar: () => void;
  onToggleSubtask: (subtaskId: string) => void;
  task: TodoTask;
}) {
  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Pressable
          onPress={onToggleComplete}
          style={[styles.checkCircle, task.isCompleted && styles.checkCircleActive]}
        />
        <View style={styles.cardBody}>
          <View style={styles.cardTitleRow}>
            <Text style={styles.cardTitle}>{task.title}</Text>
            <Text style={styles.cardChevron}>⌃</Text>
          </View>
          {task.note ? <Text style={styles.cardNote}>{task.note}</Text> : null}
          <View style={styles.cardMetaRow}>
            <Text
              style={[
                styles.dueText,
                task.isOverdue && styles.overdueText,
              ]}
            >
              {task.dueLabel}
            </Text>
            <Text style={styles.metaDot}>•</Text>
            <Text style={styles.metaText}>Tasks</Text>
            <View style={styles.flexSpacer} />
            <Pressable onPress={onToggleStar}>
              <Text
                style={[
                  styles.starText,
                  task.isStarred && styles.starTextActive,
                ]}
              >
                {task.isStarred ? '★' : '☆'}
              </Text>
            </Pressable>
          </View>
        </View>
      </View>

      {task.subtasks ? (
        <View style={styles.subtaskList}>
          {task.subtasks.map(subtask => (
            <Pressable
              key={subtask.id}
              onPress={() => onToggleSubtask(subtask.id)}
              style={[
                styles.subtaskRow,
              ]}
            >
              <Text style={styles.subtaskCheck}>{subtask.isComplete ? '◉' : '○'}</Text>
              <Text style={styles.subtaskText}>{subtask.title}</Text>
            </Pressable>
          ))}
        </View>
      ) : null}
    </View>
  );
}

function CalendarBlock({
  lane,
  task,
}: {
  lane: number;
  task: TodoTask;
}) {
  const startHour = task.startHour ?? 13;
  const durationHours = task.durationHours ?? 1;
  const top =
    HOUR_LINE_OFFSET +
    Math.max(0, (Math.min(Math.max(startHour, 1), 23.5) - CALENDAR_START_HOUR) * HOUR_ROW_HEIGHT);
  const left = CALENDAR_LANE_START + lane * CALENDAR_LANE_WIDTH;
  const height = Math.max(0.5, durationHours) * HOUR_ROW_HEIGHT;
  const endHour = Math.min(24, startHour + durationHours);
  const isCompact = durationHours <= 0.5;

  return (
    <View
      style={[
        styles.calendarBlock,
        isCompact && styles.calendarBlockCompact,
        { height, left, top, width: CALENDAR_EVENT_WIDTH },
      ]}
    >
      <Text style={styles.calendarBlockTitle}>{formatCalendarTitle(task.title)}</Text>
      {isCompact ? null : (
        <>
          <Text style={styles.calendarBlockAccent}>{formatCalendarAccent(task.title)}</Text>
          <View style={styles.flexSpacer} />
          <Text style={styles.calendarBlockTime}>
            {formatHour(startHour)} -{'\n'}{formatHour(endHour)}
          </Text>
        </>
      )}
    </View>
  );
}

function formatCalendarTitle(title: string) {
  return title.split(/\s+/).filter(Boolean).slice(0, 3).join('\n') || 'New\nTodo';
}

function formatCalendarAccent(title: string) {
  return title.split(/\s+/).filter(Boolean).slice(0, 2).join('-\n') || 'Todo';
}

function formatHour(hour: number) {
  const boundedHour = Math.min(Math.max(hour, 1), 24);
  const wholeHour = Math.floor(boundedHour);
  const minute = Math.round((boundedHour - wholeHour) * 60);
  if (minute === 0) {
    return formatTimelineHour(wholeHour);
  }
  return `${String(wholeHour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function formatTimelineHour(hour: number) {
  return `${String(hour).padStart(2, '0')}시`;
}

const styles = StyleSheet.create({
  bottomBar: {
    alignItems: 'center',
    bottom: 24,
    flexDirection: 'row',
    justifyContent: 'flex-end',
    left: 24,
    position: 'absolute',
    right: 24,
  },
  bottomButton: {
    alignItems: 'center',
    backgroundColor: '#111111',
    borderRadius: 28,
    height: 56,
    justifyContent: 'center',
    shadowColor: '#000000',
    shadowOffset: { height: 8, width: 0 },
    shadowOpacity: 0.1,
    shadowRadius: 18,
    width: 56,
  },
  calendarBlock: {
    backgroundColor: colors.primary,
    borderRadius: 9,
    paddingHorizontal: 8,
    paddingVertical: 11,
    position: 'absolute',
  },
  calendarBlockCompact: {
    paddingVertical: 5,
  },
  calendarBlockAccent: {
    color: colors.primaryForeground,
    fontSize: 11,
    fontWeight: '800',
    lineHeight: 14,
    marginTop: 10,
  },
  calendarBlockTime: {
    color: colors.primaryForeground,
    fontSize: 11,
    fontWeight: '800',
    lineHeight: 14,
  },
  calendarBlockTitle: {
    color: colors.primaryForeground,
    fontSize: 11,
    fontWeight: '800',
    lineHeight: 14,
  },
  calendarContent: {
    flex: 1,
  },
  calendarEmptyText: {
    color: 'rgba(17,17,17,0.38)',
    fontSize: 13,
    fontWeight: '700',
    left: 84,
    position: 'absolute',
    top: 98,
  },
  card: {
    backgroundColor: '#F0F1F3',
    borderRadius: 16,
    marginTop: -8,
    padding: 22,
  },
  cardBody: {
    flex: 1,
  },
  cardChevron: {
    color: 'rgba(17,17,17,0.52)',
    fontSize: 17,
    fontWeight: '700',
  },
  cardHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 14,
  },
  cardMetaRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
    marginTop: 18,
  },
  cardNote: {
    color: 'rgba(17,17,17,0.52)',
    fontSize: 15,
    fontWeight: '600',
    lineHeight: 23,
    marginTop: 10,
  },
  cardTitle: {
    color: '#111111',
    flex: 1,
    fontSize: 20,
    fontWeight: '800',
    lineHeight: 25,
  },
  cardTitleRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
  },
  checkCircle: {
    borderColor: 'rgba(17,17,17,0.56)',
    borderRadius: 12,
    borderWidth: 2,
    height: 23,
    marginTop: 2,
    width: 23,
  },
  checkCircleActive: {
    backgroundColor: '#111111',
  },
  dateTitle: {
    color: '#111111',
    fontSize: 31,
    fontWeight: '800',
    lineHeight: 38,
  },
  dueText: {
    color: '#C55047',
    fontSize: 14,
    fontWeight: '800',
  },
  flexSpacer: {
    flex: 1,
  },
  header: {
    borderBottomColor: 'rgba(17,17,17,0.08)',
    borderBottomWidth: StyleSheet.hairlineWidth,
    paddingBottom: 22,
    paddingHorizontal: 24,
    paddingTop: 28,
  },
  headerRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  halfHourTick: {
    backgroundColor: 'rgba(17,17,17,0.16)',
    height: 1,
    left: 0,
    position: 'absolute',
    top: HOUR_LINE_OFFSET + HOUR_ROW_HEIGHT / 2,
    width: 18,
  },
  hourGuide: {
    flex: 1,
    height: HOUR_ROW_HEIGHT,
    position: 'relative',
  },
  hourLine: {
    backgroundColor: 'rgba(17,17,17,0.12)',
    height: 1,
    left: 0,
    position: 'absolute',
    right: 0,
    top: HOUR_LINE_OFFSET,
  },
  hourRow: {
    flexDirection: 'row',
    gap: 16,
    height: HOUR_ROW_HEIGHT,
  },
  hourText: {
    color: 'rgba(17,17,17,0.36)',
    fontSize: 11,
    fontWeight: '800',
    width: 44,
  },
  metaDot: {
    color: 'rgba(17,17,17,0.28)',
    fontSize: 14,
    fontWeight: '800',
  },
  metaText: {
    color: 'rgba(17,17,17,0.42)',
    fontSize: 14,
    fontWeight: '700',
  },
  overdueText: {
    color: '#D4413B',
  },
  plusText: {
    color: '#FFFFFF',
    fontSize: 34,
    fontWeight: '200',
  },
  screen: {
    backgroundColor: '#FFFFFF',
    flex: 1,
  },
  scrollContent: {
    gap: 24,
    paddingBottom: 120,
    paddingHorizontal: 24,
    paddingTop: 22,
  },
  sectionChevron: {
    color: 'rgba(17,17,17,0.68)',
    fontSize: 24,
    fontWeight: '500',
  },
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  sectionTitle: {
    color: '#111111',
    fontSize: 25,
    fontWeight: '800',
  },
  segmentedButton: {
    alignItems: 'center',
    borderRadius: 8,
    flex: 1,
    height: 31,
    justifyContent: 'center',
  },
  segmentedButtonActive: {
    backgroundColor: '#FFFFFF',
    shadowColor: '#000000',
    shadowOffset: { height: 1, width: 0 },
    shadowOpacity: 0.08,
    shadowRadius: 2,
  },
  segmentedControl: {
    backgroundColor: '#ECEDEF',
    borderRadius: 10,
    flexDirection: 'row',
    marginTop: 18,
    padding: 2,
  },
  segmentedText: {
    color: 'rgba(17,17,17,0.54)',
    fontSize: 13,
    fontWeight: '700',
  },
  segmentedTextActive: {
    color: '#111111',
  },
  starText: {
    color: 'rgba(17,17,17,0.48)',
    fontSize: 21,
  },
  starTextActive: {
    color: '#F06358',
  },
  subtaskCheck: {
    color: 'rgba(17,17,17,0.58)',
    fontSize: 18,
    lineHeight: 22,
  },
  subtaskList: {
    marginTop: 15,
    paddingLeft: 46,
  },
  subtaskRow: {
    borderBottomColor: 'rgba(17,17,17,0.07)',
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 14,
    paddingVertical: 12,
  },
  subtaskText: {
    color: 'rgba(17,17,17,0.68)',
    flex: 1,
    fontSize: 13,
    fontWeight: '800',
    lineHeight: 17,
  },
  timeline: {
    minHeight: CALENDAR_HOURS.length * HOUR_ROW_HEIGHT + 28,
    paddingBottom: 132,
    paddingHorizontal: 24,
    paddingTop: 20,
  },
  weekArrow: {
    color: 'rgba(17,17,17,0.58)',
    fontSize: 30,
    fontWeight: '300',
    textAlign: 'center',
    width: 24,
  },
  weekDay: {
    alignItems: 'center',
    borderRadius: 10,
    height: 52,
    justifyContent: 'center',
    width: 34,
  },
  weekDayActive: {
    backgroundColor: colors.accent,
  },
  weekDayText: {
    color: 'rgba(17,17,17,0.60)',
    fontSize: 13,
    fontWeight: '800',
  },
  weekDayTextActive: {
    color: colors.primary,
  },
  weekNumberText: {
    color: 'rgba(17,17,17,0.60)',
    fontSize: 12,
    fontWeight: '700',
    marginTop: 2,
  },
  weekStrip: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 0,
    justifyContent: 'space-between',
    paddingBottom: 10,
    paddingHorizontal: 24,
    paddingTop: 22,
  },
});
