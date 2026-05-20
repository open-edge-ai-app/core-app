import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Modal,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  TextInput,
  useWindowDimensions,
  View,
} from 'react-native';

import {
  useI18n,
} from '../i18n';
import type {
  I18nKey,
  LocaleCode,
} from '../i18n';
import { ScaledText as Text } from '../theme/display';
import { colors } from '../theme/tokens';
import {
  DEFAULT_TODO_SETTINGS,
  TODO_LABEL_COLORS,
  createId,
  ensureTodoStoreLoaded,
  getLabels as getStoreLabels,
  getTasks as getStoreTasks,
  removeTask,
  setLabels as setStoreLabels,
  setSettings as setStoreSettings,
  setTasks as setStoreTasks,
  subscribeTodoStore,
  toggleTaskCompletionOn,
  upsertTask,
  type TodoLabel,
  type TodoRepeatRule,
  type TodoSettings,
  type TodoTask,
} from '../state/todoStore';
import { removeTaskFromCalendar, syncTaskToCalendar } from '../native/calendarSync';

const REPEAT_RULES: TodoRepeatRule[] = [
  'none',
  'daily',
  'weekdays',
  'weekly',
  'monthly',
];

type TodoTab = 'all' | 'calendar';

type Translate = (
  key: I18nKey,
  values?: Record<string, string | number>,
) => string;

const CALENDAR_START_HOUR = 1;
const HOUR_ROW_HEIGHT = 58;
const HOUR_LINE_OFFSET = 9;
const CALENDAR_LANE_START = 60;
const CALENDAR_LANE_GAP = 8;
const CALENDAR_LANE_COUNT = 4;
const CALENDAR_HOURS = Array.from({ length: 24 }, (_, index) => index + 1);
const DATE_CELL_WIDTH = 44;
const DATE_CELL_GAP = 8;
const CENTER_DATE_INDEX = 14;
const CURRENT_TIME_COLOR = '#FF3B30';

function dateAtHour(dayOffset: number, hour: number) {
  const date = new Date();
  date.setDate(date.getDate() + dayOffset);
  date.setHours(hour, 0, 0, 0);
  return date.toISOString();
}

function dateOnSelectedDay(selectedDate: Date, hour: number) {
  const date = new Date(selectedDate);
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

export default function TodoListScreen() {
  const { locale, t } = useI18n();
  const { width: screenWidth } = useWindowDimensions();
  const weekStripRef = useRef<ScrollView>(null);
  const calendarScrollRef = useRef<ScrollView>(null);
  const lastAutoScrolledCalendarDayRef = useRef<string | null>(null);
  const [tab, setTab] = useState<TodoTab>('all');
  const [tasks, setTasks] = useState<TodoTask[]>(initialTasks);
  const [labels, setLabels] = useState<TodoLabel[]>([]);
  const [settings, setSettings] = useState<TodoSettings>(DEFAULT_TODO_SETTINGS);
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);
  const [showSettings, setShowSettings] = useState(false);
  const [isOverdueExpanded, setOverdueExpanded] = useState(true);
  const [isTodayExpanded, setTodayExpanded] = useState(true);
  const [selectedDate, setSelectedDate] = useState(() => new Date());
  const [currentDate, setCurrentDate] = useState(() => new Date());
  const dateTitle = useMemo(
    () =>
      new Intl.DateTimeFormat(locale, {
        day: '2-digit',
        month: 'long',
        weekday: 'short',
      }).format(selectedDate),
    [locale, selectedDate],
  );
  const selectedSectionTitle = useMemo(
    () =>
      isSameCalendarDay(selectedDate, new Date())
        ? t('todo.today')
        : new Intl.DateTimeFormat(locale, {
            day: 'numeric',
            month: 'short',
          }).format(selectedDate),
    [locale, selectedDate, t],
  );
  const weekDays = useMemo(
    () => buildWeekDays(selectedDate, locale),
    [locale, selectedDate],
  );
  const calendarEventWidth = useMemo(
    () => getCalendarEventWidth(screenWidth),
    [screenWidth],
  );
  const visibleTasks = useMemo(
    () => (settings.hideCompleted ? tasks.filter(task => !task.isCompleted) : tasks),
    [settings.hideCompleted, tasks],
  );
  const editingTask = useMemo(
    () => tasks.find(task => task.id === editingTaskId) ?? null,
    [editingTaskId, tasks],
  );
  const overdueTasks = useMemo(
    () => visibleTasks.filter(task => task.isOverdue && taskRepeatRule(task) === 'none'),
    [visibleTasks],
  );
  const selectedDateTasks = useMemo(
    () =>
      visibleTasks.filter(
        task => !task.isOverdue && taskOccursOnDate(task, selectedDate),
      ),
    [selectedDate, visibleTasks],
  );
  const calendarTasks = useMemo(
    () => selectedDateTasks.filter(task => task.dueLabel !== 'Yesterday'),
    [selectedDateTasks],
  );
  const currentTimeHour = useMemo(() => {
    if (!isSameCalendarDay(selectedDate, currentDate)) {
      return null;
    }

    const hour = currentDate.getHours() + currentDate.getMinutes() / 60;
    return hour >= 1 && hour <= 24 ? hour : null;
  }, [currentDate, selectedDate]);

  useEffect(() => {
    let isMounted = true;
    const unsubscribe = subscribeTodoStore(state => {
      if (isMounted) {
        setTasks(state.tasks);
        setLabels(state.labels);
        setSettings(state.settings);
      }
    });
    ensureTodoStoreLoaded().then(() => {
      if (!isMounted) {
        return;
      }
      if (getStoreTasks().length === 0) {
        setStoreTasks(initialTasks);
      }
    });
    return () => {
      isMounted = false;
      unsubscribe();
    };
  }, []);

  useEffect(() => {
    const intervalId = setInterval(() => {
      setCurrentDate(new Date());
    }, 60000);

    return () => clearInterval(intervalId);
  }, []);

  useEffect(() => {
    if (tab !== 'calendar') {
      lastAutoScrolledCalendarDayRef.current = null;
      return;
    }

    if (currentTimeHour === null) {
      return;
    }

    const selectedDateKey = dateKey(selectedDate);
    if (lastAutoScrolledCalendarDayRef.current === selectedDateKey) {
      return;
    }

    lastAutoScrolledCalendarDayRef.current = selectedDateKey;
    const timeoutId = setTimeout(() => {
      calendarScrollRef.current?.scrollTo({
        animated: true,
        x: 0,
        y: Math.max(0, getCurrentTimeLineTop(currentTimeHour) - 180),
      });
    }, 0);

    return () => clearTimeout(timeoutId);
  }, [currentTimeHour, selectedDate, tab]);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      weekStripRef.current?.scrollTo({
        animated: false,
        x: CENTER_DATE_INDEX * (DATE_CELL_WIDTH + DATE_CELL_GAP),
        y: 0,
      });
    }, 0);
    return () => clearTimeout(timeoutId);
  }, [selectedDate]);

  const addTask = () => {
    const startHour = 13 + (selectedDateTasks.length % 5);
      const nextTask: TodoTask = {
      dueDateISO: dateOnSelectedDay(selectedDate, startHour),
      dueLabel: isSameCalendarDay(selectedDate, new Date()) ? 'Today' : 'Tasks',
      durationHours: 1,
      id: `todo-${Date.now()}`,
      note: '',
      repeatRule: 'none',
      startHour,
      title: t('todo.newTodo'),
    };
    upsertTask(nextTask);
    syncTaskToCalendar(nextTask).catch(() => undefined);
  };

  const moveSelectedDate = (days: number) => {
    setSelectedDate(current => {
      const next = new Date(current);
      next.setDate(next.getDate() + days);
      return next;
    });
  };

  const handleWeekStripScrollEnd = (
    event: NativeSyntheticEvent<NativeScrollEvent>,
  ) => {
    const itemStride = DATE_CELL_WIDTH + DATE_CELL_GAP;
    const selectedIndex = Math.min(
      Math.max(Math.round(event.nativeEvent.contentOffset.x / itemStride), 0),
      weekDays.length - 1,
    );
    const nextDate = weekDays[selectedIndex]?.date;

    if (nextDate && !isSameCalendarDay(nextDate, selectedDate)) {
      setSelectedDate(nextDate);
    }
  };

  const toggleTaskComplete = (taskId: string) => {
    const task = getStoreTasks().find(item => item.id === taskId);
    if (task) {
      upsertTask(toggleTaskCompletionOn(task, selectedDate));
    }
  };

  const toggleTaskStar = (taskId: string) => {
    const task = getStoreTasks().find(item => item.id === taskId);
    if (task) {
      upsertTask({ ...task, isStarred: !task.isStarred });
    }
  };

  const toggleSubtask = (taskId: string, subtaskId: string) => {
    const task = getStoreTasks().find(item => item.id === taskId);
    if (!task || !task.subtasks) {
      return;
    }
    upsertTask({
      ...task,
      subtasks: task.subtasks.map(subtask =>
        subtask.id === subtaskId
          ? { ...subtask, isComplete: !subtask.isComplete }
          : subtask,
      ),
    });
  };

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <Text style={styles.dateTitle}>{dateTitle}</Text>
          <View style={styles.flexSpacer} />
          <Pressable
            onPress={() => setShowSettings(true)}
            style={styles.settingsButton}
          >
            <Text style={styles.settingsIcon}>⚙</Text>
          </Pressable>
        </View>
        <View style={styles.weekStripContainer}>
          <Pressable onPress={() => moveSelectedDate(-7)}>
            <Text style={styles.weekArrow}>‹</Text>
          </Pressable>
          <ScrollView
            ref={weekStripRef}
            contentContainerStyle={styles.weekStrip}
            decelerationRate="fast"
            horizontal
            onMomentumScrollEnd={handleWeekStripScrollEnd}
            onScrollEndDrag={handleWeekStripScrollEnd}
            showsHorizontalScrollIndicator={false}
            snapToAlignment="start"
            snapToInterval={DATE_CELL_WIDTH + DATE_CELL_GAP}
            style={styles.weekStripScroll}
          >
            {weekDays.map(day => (
              <Pressable
                key={day.id}
                onPress={() => setSelectedDate(day.date)}
                style={[
                  styles.weekDay,
                  day.isSelected && styles.weekDayActive,
                ]}
              >
                <Text
                  style={[
                    styles.weekDayText,
                    day.isSelected && styles.weekDayTextActive,
                  ]}
                >
                  {day.dayLabel}
                </Text>
                <Text
                  style={[
                    styles.weekNumberText,
                    day.isSelected && styles.weekDayTextActive,
                  ]}
                >
                  {day.numberLabel}
                </Text>
              </Pressable>
            ))}
          </ScrollView>
          <Pressable onPress={() => moveSelectedDate(7)}>
            <Text style={styles.weekArrow}>›</Text>
          </Pressable>
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
              {t('todo.list')}
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
              {t('todo.calendar')}
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
            title={t('todo.overdue')}
          />
          {isOverdueExpanded
            ? overdueTasks.map(task => (
                <TodoCard
                  key={task.id}
                  onToggleComplete={() => toggleTaskComplete(task.id)}
                  onToggleStar={() => toggleTaskStar(task.id)}
                  onToggleSubtask={subtaskId => toggleSubtask(task.id, subtaskId)}
                  onEdit={() => setEditingTaskId(task.id)}
                  cardLabels={resolveTaskLabels(task, labels)}
                  showTags={settings.showTags}
                  dueLabel={formatTaskDueLabel(task, locale, t)}
                  repeatText={repeatLabel(task.repeatRule, t)}
                  task={task}
                />
              ))
            : null}
          <SectionHeader
            expanded={isTodayExpanded}
            onPress={() => setTodayExpanded(current => !current)}
            title={selectedSectionTitle}
          />
          {isTodayExpanded
            ? selectedDateTasks.map(task => (
                <TodoCard
                  key={task.id}
                  onToggleComplete={() => toggleTaskComplete(task.id)}
                  onToggleStar={() => toggleTaskStar(task.id)}
                  onToggleSubtask={subtaskId => toggleSubtask(task.id, subtaskId)}
                  onEdit={() => setEditingTaskId(task.id)}
                  cardLabels={resolveTaskLabels(task, labels)}
                  showTags={settings.showTags}
                  dueLabel={formatTaskDueLabel(task, locale, t)}
                  repeatText={repeatLabel(task.repeatRule, t)}
                  task={task}
                />
              ))
            : null}
        </ScrollView>
      ) : (
        <View style={styles.calendarContent}>
          <ScrollView
            ref={calendarScrollRef}
            contentContainerStyle={styles.timeline}
            showsVerticalScrollIndicator={false}
          >
            {CALENDAR_HOURS.map(hour => (
                <View key={hour} style={styles.hourRow}>
                  <Text style={styles.hourText}>{formatTimelineHour(hour, locale)}</Text>
                  <View style={styles.hourGuide}>
                    <View style={styles.hourLine} />
                    {hour < 24 ? <View style={styles.halfHourTick} /> : null}
                  </View>
                </View>
              ))}
            {calendarTasks.length > 0 ? (
              calendarTasks.slice(0, 4).map((task, index) => (
                <CalendarBlock
                  eventWidth={calendarEventWidth}
                  key={task.id}
                  lane={index}
                  locale={locale}
                  task={task}
                />
              ))
            ) : null}
            {currentTimeHour !== null ? (
              <View
                style={[
                  styles.currentTimeLine,
                  { top: getCurrentTimeLineTop(currentTimeHour) },
                ]}
              >
                <Text style={styles.currentTimeLabel}>
                  {formatCurrentTimeLabel(currentTimeHour)}
                </Text>
                <View style={styles.currentTimeDot} />
                <View style={styles.currentTimeRule} />
              </View>
            ) : null}
          </ScrollView>
        </View>
      )}

      <View style={styles.bottomBar}>
        <Pressable onPress={addTask} style={styles.bottomButton}>
          <Text style={styles.plusText}>+</Text>
        </Pressable>
      </View>

      <TodoSettingsModal
        onChange={setStoreSettings}
        onClose={() => setShowSettings(false)}
        settings={settings}
        t={t}
        visible={showSettings}
      />
      <TodoEditorModal
        labels={labels}
        onClose={() => setEditingTaskId(null)}
        onDelete={taskId => {
          const target = getStoreTasks().find(item => item.id === taskId);
          if (target) {
            removeTaskFromCalendar(target).catch(() => undefined);
          }
          removeTask(taskId);
          setEditingTaskId(null);
        }}
        onSave={task => {
          upsertTask(task);
          syncTaskToCalendar(task).catch(() => undefined);
        }}
        t={t}
        task={editingTask}
      />
    </View>
  );
}

function resolveTaskLabels(task: TodoTask, labels: TodoLabel[]): TodoLabel[] {
  return (task.labelIds ?? [])
    .map(id => labels.find(label => label.id === id))
    .filter((label): label is TodoLabel => label !== undefined);
}

function TodoSettingsModal({
  onChange,
  onClose,
  settings,
  t,
  visible,
}: {
  onChange: (next: TodoSettings) => void;
  onClose: () => void;
  settings: TodoSettings;
  t: Translate;
  visible: boolean;
}) {
  const rows: { key: keyof TodoSettings; label: string }[] = [
    { key: 'hideCompleted', label: t('todo.settings.hideCompleted') },
    { key: 'showTags', label: t('todo.settings.showTags') },
    { key: 'calendarSync', label: t('todo.settings.calendarSync') },
  ];

  return (
    <Modal
      animationType="slide"
      onRequestClose={onClose}
      transparent
      visible={visible}
    >
      <Pressable onPress={onClose} style={styles.modalBackdrop}>
        <Pressable onPress={() => {}} style={styles.sheet}>
          <View style={styles.sheetHeader}>
            <Text style={styles.sheetTitle}>{t('todo.settings')}</Text>
            <Pressable onPress={onClose}>
              <Text style={styles.sheetClose}>✕</Text>
            </Pressable>
          </View>
          {rows.map(row => (
            <View key={row.key} style={styles.settingsRow}>
              <Text style={styles.settingsLabel}>{row.label}</Text>
              <Switch
                onValueChange={value => onChange({ ...settings, [row.key]: value })}
                value={settings[row.key]}
              />
            </View>
          ))}
        </Pressable>
      </Pressable>
    </Modal>
  );
}

function TodoEditorModal({
  labels,
  onClose,
  onDelete,
  onSave,
  t,
  task,
}: {
  labels: TodoLabel[];
  onClose: () => void;
  onDelete: (taskId: string) => void;
  onSave: (task: TodoTask) => void;
  t: Translate;
  task: TodoTask | null;
}) {
  const [draft, setDraft] = useState<TodoTask | null>(task);
  const [newLabel, setNewLabel] = useState('');
  const [newSubtask, setNewSubtask] = useState('');

  useEffect(() => {
    setDraft(task);
    setNewLabel('');
    setNewSubtask('');
  }, [task]);

  if (!draft) {
    return null;
  }

  const update = (patch: Partial<TodoTask>) => {
    setDraft(current =>
      current ? { ...current, ...patch, updatedAtISO: new Date().toISOString() } : current,
    );
  };

  const commit = (next: TodoTask) => {
    onSave(next);
  };

  const toggleLabel = (labelId: string) => {
    const current = draft.labelIds ?? [];
    update({ labelIds: current.includes(labelId) ? [] : [labelId] });
  };

  const addLabel = () => {
    const title = newLabel.trim();
    if (!title) {
      return;
    }
    const label: TodoLabel = {
      id: createId('label'),
      title,
      colorHex: TODO_LABEL_COLORS[labels.length % TODO_LABEL_COLORS.length],
      createdAtISO: new Date().toISOString(),
    };
    setStoreLabels([...getStoreLabels(), label]);
    update({ labelIds: [label.id] });
    setNewLabel('');
  };

  const addSubtask = () => {
    const title = newSubtask.trim();
    if (!title) {
      return;
    }
    update({
      subtasks: [
        ...(draft.subtasks ?? []),
        { id: createId('subtask'), title, isComplete: false },
      ],
    });
    setNewSubtask('');
  };

  const toggleSubtask = (subtaskId: string) => {
    update({
      subtasks: (draft.subtasks ?? []).map(item =>
        item.id === subtaskId ? { ...item, isComplete: !item.isComplete } : item,
      ),
    });
  };

  const deleteSubtask = (subtaskId: string) => {
    update({
      subtasks: (draft.subtasks ?? []).filter(item => item.id !== subtaskId),
    });
  };

  return (
    <Modal
      animationType="slide"
      onRequestClose={onClose}
      transparent
      visible={task !== null}
    >
      <Pressable onPress={onClose} style={styles.modalBackdrop}>
        <Pressable onPress={() => {}} style={styles.sheet}>
          <View style={styles.sheetHeader}>
            <Text style={styles.sheetTitle}>{t('todo.edit')}</Text>
            <Pressable
              onPress={() => {
                commit(draft);
                onClose();
              }}
            >
              <Text style={styles.sheetDone}>{t('common.save')}</Text>
            </Pressable>
          </View>
          <ScrollView style={styles.editorScroll}>
            <Text style={styles.fieldLabel}>{t('todo.field.title')}</Text>
            <TextInput
              onChangeText={value => update({ title: value })}
              style={styles.input}
              value={draft.title}
            />

            <Text style={styles.fieldLabel}>{t('todo.field.note')}</Text>
            <TextInput
              multiline
              onChangeText={value => update({ note: value })}
              style={[styles.input, styles.inputMultiline]}
              value={draft.note}
            />

            <Text style={styles.fieldLabel}>{t('todo.field.repeat')}</Text>
            <View style={styles.optionRow}>
              {REPEAT_RULES.map(rule => {
                const active = (draft.repeatRule ?? 'none') === rule;
                return (
                  <Pressable
                    key={rule}
                    onPress={() => update({ repeatRule: rule })}
                    style={[styles.option, active && styles.optionActive]}
                  >
                    <Text
                      style={[
                        styles.optionText,
                        active && styles.optionTextActive,
                      ]}
                    >
                      {repeatLabel(rule, t)}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>{t('todo.field.label')}</Text>
            <View style={styles.optionRow}>
              {labels.map(label => {
                const active = (draft.labelIds ?? []).includes(label.id);
                return (
                  <Pressable
                    key={label.id}
                    onPress={() => toggleLabel(label.id)}
                    style={[
                      styles.chip,
                      { backgroundColor: active ? label.colorHex : colors.muted },
                    ]}
                  >
                    <Text
                      style={active ? styles.chipText : styles.chipTextInactive}
                    >
                      {label.title}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
            <View style={styles.inlineAddRow}>
              <TextInput
                onChangeText={setNewLabel}
                onSubmitEditing={addLabel}
                placeholder={t('todo.newLabel')}
                style={[styles.input, styles.inlineInput]}
                value={newLabel}
              />
              <Pressable onPress={addLabel} style={styles.inlineAddButton}>
                <Text style={styles.inlineAddText}>＋</Text>
              </Pressable>
            </View>

            <Text style={styles.fieldLabel}>{t('todo.field.subtasks')}</Text>
            {(draft.subtasks ?? []).map(subtask => (
              <View key={subtask.id} style={styles.subtaskEditRow}>
                <Pressable onPress={() => toggleSubtask(subtask.id)}>
                  <Text style={styles.subtaskCheck}>
                    {subtask.isComplete ? '◉' : '○'}
                  </Text>
                </Pressable>
                <Text style={styles.subtaskEditText}>{subtask.title}</Text>
                <Pressable onPress={() => deleteSubtask(subtask.id)}>
                  <Text style={styles.subtaskDelete}>✕</Text>
                </Pressable>
              </View>
            ))}
            <View style={styles.inlineAddRow}>
              <TextInput
                onChangeText={setNewSubtask}
                onSubmitEditing={addSubtask}
                placeholder={t('todo.addSubtask')}
                style={[styles.input, styles.inlineInput]}
                value={newSubtask}
              />
              <Pressable onPress={addSubtask} style={styles.inlineAddButton}>
                <Text style={styles.inlineAddText}>＋</Text>
              </Pressable>
            </View>

            <View style={styles.editorActions}>
              <Pressable
                onPress={() => update({ isStarred: !draft.isStarred })}
                style={styles.editorActionButton}
              >
                <Text style={styles.editorActionText}>
                  {draft.isStarred ? '★' : '☆'} {t('todo.important')}
                </Text>
              </Pressable>
              <Pressable
                onPress={() => onDelete(draft.id)}
                style={[styles.editorActionButton, styles.editorDeleteButton]}
              >
                <Text style={styles.editorDeleteText}>{t('todo.delete')}</Text>
              </Pressable>
            </View>
          </ScrollView>
        </Pressable>
      </Pressable>
    </Modal>
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
  cardLabels,
  dueLabel,
  onEdit,
  onToggleComplete,
  onToggleStar,
  onToggleSubtask,
  repeatText,
  showTags,
  task,
}: {
  cardLabels: TodoLabel[];
  dueLabel: string;
  onEdit: () => void;
  onToggleComplete: () => void;
  onToggleStar: () => void;
  onToggleSubtask: (subtaskId: string) => void;
  repeatText: string;
  showTags: boolean;
  task: TodoTask;
}) {
  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Pressable
          onPress={onToggleComplete}
          style={[styles.checkCircle, task.isCompleted && styles.checkCircleActive]}
        />
        <Pressable style={styles.cardBody} onPress={onEdit}>
          <View style={styles.cardTitleRow}>
            <Text
              style={[styles.cardTitle, task.isCompleted && styles.cardTitleDone]}
            >
              {task.title}
            </Text>
            <Text style={styles.cardChevron}>⌃</Text>
          </View>
          {showTags && cardLabels.length > 0 ? (
            <View style={styles.chipRow}>
              {cardLabels.map(label => (
                <View
                  key={label.id}
                  style={[styles.chip, { backgroundColor: label.colorHex }]}
                >
                  <Text style={styles.chipText}>{label.title}</Text>
                </View>
              ))}
            </View>
          ) : null}
          {task.note ? <Text style={styles.cardNote}>{task.note}</Text> : null}
          <View style={styles.cardMetaRow}>
            <Text
              style={[
                styles.dueText,
                task.isOverdue && styles.overdueText,
              ]}
            >
              {dueLabel}
            </Text>
            <Text style={styles.metaDot}>•</Text>
            <Text style={styles.metaText}>{repeatText}</Text>
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
        </Pressable>
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
  eventWidth,
  lane,
  locale,
  task,
}: {
  eventWidth: number;
  lane: number;
  locale: LocaleCode;
  task: TodoTask;
}) {
  const startHour = task.startHour ?? 13;
  const durationHours = task.durationHours ?? 1;
  const top =
    HOUR_LINE_OFFSET +
    Math.max(0, (Math.min(Math.max(startHour, 1), 23.5) - CALENDAR_START_HOUR) * HOUR_ROW_HEIGHT);
  const left = CALENDAR_LANE_START + lane * (eventWidth + CALENDAR_LANE_GAP);
  const height = Math.max(0.5, durationHours) * HOUR_ROW_HEIGHT;
  const endHour = Math.min(24, startHour + durationHours);
  const isCompact = durationHours <= 0.5;

  return (
    <View
      style={[
        styles.calendarBlock,
        isCompact && styles.calendarBlockCompact,
        { height, left, top, width: eventWidth },
      ]}
    >
      <Text style={styles.calendarBlockTitle}>{formatCalendarTitle(task.title)}</Text>
      {isCompact ? null : (
        <>
          <Text style={styles.calendarBlockAccent}>{formatCalendarAccent(task.title)}</Text>
          <View style={styles.flexSpacer} />
          <Text style={styles.calendarBlockTime}>
            {formatHour(startHour, locale)} -{'\n'}{formatHour(endHour, locale)}
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

function formatHour(hour: number, locale: LocaleCode) {
  const boundedHour = Math.min(Math.max(hour, 1), 24);
  const wholeHour = Math.floor(boundedHour);
  const minute = Math.round((boundedHour - wholeHour) * 60);
  if (minute === 0) {
    return formatTimelineHour(wholeHour, locale);
  }
  return `${String(wholeHour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function formatTimelineHour(hour: number, locale: LocaleCode = 'ko') {
  const hourText = String(hour).padStart(2, '0');
  return locale === 'ko' ? `${hourText}시` : `${hourText}:00`;
}

function formatCurrentTimeLabel(hour: number) {
  const boundedHour = Math.min(Math.max(hour, CALENDAR_START_HOUR), 24);
  let wholeHour = Math.floor(boundedHour);
  let minute = Math.round((boundedHour - wholeHour) * 60);
  if (minute === 60) {
    wholeHour += 1;
    minute = 0;
  }
  return `${String(Math.min(wholeHour, 24)).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function getCurrentTimeLineTop(hour: number) {
  return HOUR_LINE_OFFSET + (hour - CALENDAR_START_HOUR) * HOUR_ROW_HEIGHT - 9;
}

function dateKey(date: Date) {
  return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
}

function buildWeekDays(selectedDate: Date, locale: LocaleCode) {
  const startDate = new Date(selectedDate);
  startDate.setDate(selectedDate.getDate() - CENTER_DATE_INDEX);
  startDate.setHours(0, 0, 0, 0);

  return Array.from({ length: 29 }, (_, index) => {
    const date = new Date(startDate);
    date.setDate(startDate.getDate() + index);
    return {
      date,
      dayLabel: new Intl.DateTimeFormat(locale, { weekday: 'narrow' }).format(date),
      id: date.toISOString(),
      isSelected: isSameCalendarDay(date, selectedDate),
      numberLabel: String(date.getDate()).padStart(2, '0'),
    };
  });
}

function isSameCalendarDay(left: Date, right: Date) {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  );
}

function taskDate(task: TodoTask) {
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

function taskRepeatRule(task: TodoTask): TodoRepeatRule {
  return task.repeatRule ?? 'none';
}

function taskOccursOnDate(task: TodoTask, selectedDate: Date) {
  const anchorDate = taskDate(task);
  const selectedDay = startOfCalendarDay(selectedDate);
  const anchorDay = startOfCalendarDay(anchorDate);
  if (selectedDay.getTime() < anchorDay.getTime()) {
    return false;
  }

  switch (taskRepeatRule(task)) {
    case 'daily':
      return true;
    case 'weekdays': {
      const weekday = selectedDay.getDay();
      return weekday >= 1 && weekday <= 5;
    }
    case 'weekly':
      return selectedDay.getDay() === anchorDay.getDay();
    case 'monthly':
      return selectedDay.getDate() === anchorDay.getDate();
    case 'none':
    default:
      return isSameCalendarDay(anchorDay, selectedDay);
  }
}

function startOfCalendarDay(date: Date) {
  const value = new Date(date);
  value.setHours(0, 0, 0, 0);
  return value;
}

function repeatLabel(repeatRule: TodoRepeatRule | undefined, t: Translate) {
  switch (repeatRule) {
    case 'daily':
      return t('todo.repeat.daily');
    case 'weekdays':
      return t('todo.repeat.weekdays');
    case 'weekly':
      return t('todo.repeat.weekly');
    case 'monthly':
      return t('todo.repeat.monthly');
    case 'none':
    default:
      return t('todo.repeat.none');
  }
}

function formatTaskDueLabel(
  task: TodoTask,
  locale: LocaleCode,
  t: Translate,
) {
  const dueDate = taskDate(task);
  const today = new Date();

  if (isSameCalendarDay(dueDate, today)) {
    return t('todo.today');
  }

  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (isSameCalendarDay(dueDate, yesterday)) {
    return t('todo.yesterday');
  }

  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  if (isSameCalendarDay(dueDate, tomorrow)) {
    return t('todo.tomorrow');
  }

  return new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'short',
    year: dueDate.getFullYear() === today.getFullYear() ? undefined : 'numeric',
  }).format(dueDate);
}

function getCalendarEventWidth(screenWidth: number) {
  const contentWidth = Math.max(0, screenWidth - 48);
  const availableWidth =
    contentWidth - CALENDAR_LANE_START - CALENDAR_LANE_GAP * (CALENDAR_LANE_COUNT - 1);
  return Math.max(44, Math.floor(availableWidth / CALENDAR_LANE_COUNT));
}

const styles = StyleSheet.create({
  settingsButton: {
    padding: 8,
  },
  settingsIcon: {
    color: colors.mutedForeground,
    fontSize: 20,
  },
  cardTitleDone: {
    color: colors.mutedForeground,
    textDecorationLine: 'line-through',
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginTop: 6,
  },
  chip: {
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  chipText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  chipTextInactive: {
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '600',
  },
  modalBackdrop: {
    backgroundColor: 'rgba(0, 0, 0, 0.35)',
    flex: 1,
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: colors.card,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '85%',
    padding: 20,
  },
  sheetHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  sheetTitle: {
    color: colors.foreground,
    fontSize: 18,
    fontWeight: '700',
  },
  sheetClose: {
    color: colors.mutedForeground,
    fontSize: 18,
  },
  sheetDone: {
    color: colors.primary,
    fontSize: 16,
    fontWeight: '700',
  },
  settingsRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 12,
  },
  settingsLabel: {
    color: colors.foreground,
    fontSize: 16,
  },
  editorScroll: {
    marginTop: 4,
  },
  fieldLabel: {
    color: colors.mutedForeground,
    fontSize: 13,
    fontWeight: '600',
    marginBottom: 6,
    marginTop: 14,
  },
  input: {
    backgroundColor: colors.muted,
    borderRadius: 10,
    color: colors.foreground,
    fontSize: 15,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  inputMultiline: {
    minHeight: 64,
    textAlignVertical: 'top',
  },
  optionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 4,
  },
  option: {
    backgroundColor: colors.muted,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  optionActive: {
    backgroundColor: colors.primary,
  },
  optionText: {
    color: colors.foreground,
    fontSize: 13,
    fontWeight: '600',
  },
  optionTextActive: {
    color: colors.primaryForeground,
  },
  inlineAddRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
    marginTop: 8,
  },
  inlineInput: {
    flex: 1,
  },
  inlineAddButton: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: 10,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  inlineAddText: {
    color: colors.foreground,
    fontSize: 18,
  },
  subtaskEditRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
    paddingVertical: 6,
  },
  subtaskEditText: {
    color: colors.foreground,
    flex: 1,
    fontSize: 14,
  },
  subtaskDelete: {
    color: colors.mutedForeground,
    fontSize: 14,
  },
  editorActions: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 20,
  },
  editorActionButton: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: 12,
    flex: 1,
    paddingVertical: 12,
  },
  editorActionText: {
    color: colors.foreground,
    fontSize: 14,
    fontWeight: '600',
  },
  editorDeleteButton: {
    backgroundColor: '#FCE8E8',
  },
  editorDeleteText: {
    color: colors.destructive,
    fontSize: 14,
    fontWeight: '600',
  },
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
  currentTimeDot: {
    backgroundColor: CURRENT_TIME_COLOR,
    borderColor: '#FFFFFF',
    borderRadius: 4.5,
    borderWidth: 1.5,
    height: 9,
    width: 9,
  },
  currentTimeLabel: {
    backgroundColor: CURRENT_TIME_COLOR,
    borderColor: '#FFFFFF',
    borderRadius: 9,
    borderWidth: 1.5,
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '800',
    height: 18,
    lineHeight: 15,
    overflow: 'hidden',
    textAlign: 'center',
    width: 48,
  },
  currentTimeLine: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 5,
    left: 0,
    position: 'absolute',
    right: 0,
    zIndex: 10,
  },
  currentTimeRule: {
    backgroundColor: CURRENT_TIME_COLOR,
    borderTopColor: '#FFFFFF',
    borderTopWidth: 1,
    flex: 1,
    height: 3,
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
    position: 'relative',
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
    width: DATE_CELL_WIDTH,
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
    gap: DATE_CELL_GAP,
    paddingHorizontal: DATE_CELL_GAP,
  },
  weekStripContainer: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 0,
    paddingTop: 18,
  },
  weekStripScroll: {
    flex: 1,
  },
});
