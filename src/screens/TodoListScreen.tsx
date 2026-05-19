import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import AppIcon from '../components/AppIcon';
import { ScaledText as Text } from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors, typography } from '../theme/tokens';

type TodoTab = 'all' | 'calendar';

const tasks = [
  {
    dueLabel: 'Yesterday',
    isOverdue: true,
    note: '',
    title: 'Call Jason',
  },
  {
    dueLabel: 'Today',
    isStarred: true,
    note:
      'Email Mrs. James for the new intern we have next week from Alex Carter, a marketing student from Brookfield University. Confirm their start date, schedule, and onboarding needs.',
    title: 'Email Back Mrs James',
  },
  {
    dueLabel: 'Today',
    note: '',
    subtasks: [
      ['Update the UI system with a modern, cohesive design.', true],
      ['Focus on consistency, scalability, and accessibility.', false],
      ['Use clean aesthetics with reusable, responsive components.', false],
      ['Enhance usability for a seamless user experience.', false],
      ['Streamline development with clear design guidelines.', false],
    ] as const,
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
  const dateTitle = useMemo(
    () =>
      new Intl.DateTimeFormat('en-US', {
        day: '2-digit',
        month: 'long',
        weekday: 'short',
      }).format(new Date()),
    [],
  );
  const monthTitle = useMemo(
    () => new Intl.DateTimeFormat('en-US', { month: 'long' }).format(new Date()),
    [],
  );

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <Text style={styles.title}>{tab === 'calendar' ? 'Calendar' : 'All'}</Text>
          <AppIcon color="#111111" icon={appIcons.modelManage} size={24} />
        </View>
        <Text style={styles.dateTitle}>{dateTitle}</Text>
      </View>

      {tab === 'all' ? (
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <TabSwitcher selected={tab} onSelect={setTab} />
          <SectionHeader title="Overdue" />
          <TodoCard task={tasks[0]} />
          <SectionHeader title="Today" />
          <TodoCard task={tasks[1]} />
          <TodoCard task={tasks[2]} />
        </ScrollView>
      ) : (
        <View style={styles.calendarContent}>
          <View style={styles.calendarControls}>
            <Text style={styles.activeMode}>Week</Text>
            <Text style={styles.inactiveMode}>Day</Text>
            <View style={styles.flexSpacer} />
            <AppIcon color="#111111" icon={appIcons.search} size={25} />
          </View>
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
            {['11 AM', '12 PM', '01 PM', '02 PM', '03 PM', '04 PM', '05 PM', '06 PM', '07 PM', '08 PM'].map(
              hour => (
                <View key={hour} style={styles.hourRow}>
                  <Text style={styles.hourText}>{hour}</Text>
                  <View style={styles.hourLine} />
                </View>
              ),
            )}
            <CalendarBlock left={120} top={162} />
            <CalendarBlock left={176} top={162} />
            <CalendarBlock left={232} top={162} />
            <CalendarBlock left={288} top={82} compact />
          </ScrollView>
        </View>
      )}

      <View style={styles.bottomBar}>
        <View style={styles.bottomButton}>
          <Text style={styles.backArrow}>←</Text>
        </View>
        <View style={styles.monthPill}>
          <Text style={styles.monthArrow}>‹</Text>
          <Text style={styles.monthText}>{monthTitle}</Text>
          <Text style={styles.monthArrow}>›</Text>
        </View>
        <View style={styles.bottomButton}>
          <Text style={styles.plusText}>+</Text>
        </View>
      </View>
    </View>
  );
}

function TabSwitcher({
  onSelect,
  selected,
}: {
  onSelect: (tab: TodoTab) => void;
  selected: TodoTab;
}) {
  return (
    <View style={styles.tabRow}>
      {(['all', 'calendar'] as const).map(tab => (
        <Pressable
          key={tab}
          onPress={() => onSelect(tab)}
          style={[
            styles.tabButton,
            selected === tab && styles.tabButtonActive,
          ]}
        >
          <Text
            style={[
              styles.tabText,
              selected === tab && styles.tabTextActive,
            ]}
          >
            {tab === 'all' ? 'All' : 'Calendar'}
          </Text>
        </Pressable>
      ))}
      <View style={styles.flexSpacer} />
      <AppIcon color="#111111" icon={appIcons.search} size={25} />
    </View>
  );
}

function SectionHeader({ title }: { title: string }) {
  return (
    <View style={styles.sectionHeader}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <Text style={styles.sectionChevron}>⌄</Text>
    </View>
  );
}

function TodoCard({ task }: { task: (typeof tasks)[number] }) {
  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={styles.checkCircle} />
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
            <Text
              style={[
                styles.starText,
                task.isStarred && styles.starTextActive,
              ]}
            >
              {task.isStarred ? '★' : '☆'}
            </Text>
          </View>
        </View>
      </View>

      {'subtasks' in task && task.subtasks ? (
        <View style={styles.subtaskList}>
          {task.subtasks.map(([title, complete]) => (
            <View key={title} style={styles.subtaskRow}>
              <Text style={styles.subtaskCheck}>{complete ? '◉' : '○'}</Text>
              <Text style={styles.subtaskText}>{title}</Text>
            </View>
          ))}
        </View>
      ) : null}
    </View>
  );
}

function CalendarBlock({
  compact = false,
  left,
  top,
}: {
  compact?: boolean;
  left: number;
  top: number;
}) {
  return (
    <View
      style={[
        styles.calendarBlock,
        compact && styles.calendarBlockCompact,
        { left, top },
      ]}
    >
      <Text style={styles.calendarBlockTitle}>New{'\n'}Design{'\n'}System</Text>
      <Text style={styles.calendarBlockAccent}>New-{'\n'}Design</Text>
      <View style={styles.flexSpacer} />
      <Text style={styles.calendarBlockTime}>01PM -{'\n'}05PM</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  activeMode: {
    backgroundColor: '#F0F1F3',
    borderRadius: 11,
    color: '#2563EB',
    fontSize: 16,
    fontWeight: '800',
    lineHeight: 42,
    paddingHorizontal: 14,
  },
  backArrow: {
    color: '#111111',
    fontSize: 30,
    fontWeight: '300',
  },
  bottomBar: {
    alignItems: 'center',
    bottom: 24,
    flexDirection: 'row',
    gap: 14,
    left: 24,
    position: 'absolute',
    right: 24,
  },
  bottomButton: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    height: 56,
    justifyContent: 'center',
    shadowColor: '#000000',
    shadowOffset: { height: 8, width: 0 },
    shadowOpacity: 0.1,
    shadowRadius: 18,
    width: 56,
  },
  calendarBlock: {
    backgroundColor: '#2E3133',
    borderRadius: 9,
    height: 328,
    paddingHorizontal: 8,
    paddingVertical: 11,
    position: 'absolute',
    width: 54,
  },
  calendarBlockAccent: {
    color: '#2FD479',
    fontSize: 11,
    fontWeight: '800',
    lineHeight: 14,
    marginTop: 10,
  },
  calendarBlockCompact: {
    height: 164,
    width: 55,
  },
  calendarBlockTime: {
    color: 'rgba(255,255,255,0.84)',
    fontSize: 11,
    fontWeight: '800',
    lineHeight: 14,
  },
  calendarBlockTitle: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '800',
    lineHeight: 14,
  },
  calendarContent: {
    flex: 1,
  },
  calendarControls: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
    paddingHorizontal: 24,
    paddingTop: 20,
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
  dateTitle: {
    color: '#111111',
    fontSize: 31,
    fontWeight: '800',
    lineHeight: 38,
    marginTop: 18,
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
    paddingBottom: 26,
    paddingHorizontal: 24,
    paddingTop: 28,
  },
  headerRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  hourLine: {
    backgroundColor: 'rgba(17,17,17,0.12)',
    flex: 1,
    height: 1,
    marginTop: 9,
  },
  hourRow: {
    flexDirection: 'row',
    gap: 16,
    height: 82,
  },
  hourText: {
    color: 'rgba(17,17,17,0.36)',
    fontSize: 11,
    fontWeight: '800',
    width: 44,
  },
  inactiveMode: {
    color: 'rgba(17,17,17,0.62)',
    fontSize: 16,
    fontWeight: '800',
    lineHeight: 42,
    paddingHorizontal: 14,
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
  monthArrow: {
    color: '#111111',
    fontSize: 24,
    fontWeight: '600',
  },
  monthPill: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    flex: 1,
    flexDirection: 'row',
    height: 56,
    justifyContent: 'center',
    shadowColor: '#000000',
    shadowOffset: { height: 10, width: 0 },
    shadowOpacity: 0.1,
    shadowRadius: 20,
  },
  monthText: {
    color: '#111111',
    fontSize: 16,
    fontWeight: '800',
    marginHorizontal: 22,
  },
  overdueText: {
    color: '#D4413B',
  },
  plusText: {
    color: '#2563EB',
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
  tabButton: {
    borderRadius: 11,
    height: 42,
    justifyContent: 'center',
    paddingHorizontal: 14,
  },
  tabButtonActive: {
    backgroundColor: '#F0F1F3',
  },
  tabRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  tabText: {
    color: 'rgba(17,17,17,0.52)',
    fontSize: 16,
    fontWeight: '800',
  },
  tabTextActive: {
    color: '#111111',
  },
  timeline: {
    minHeight: 820,
    paddingBottom: 132,
    paddingHorizontal: 24,
    paddingTop: 20,
  },
  title: {
    ...typography.title,
    color: '#111111',
    fontSize: 36,
    fontWeight: '800',
    lineHeight: 43,
  },
  weekArrow: {
    color: 'rgba(17,17,17,0.58)',
    fontSize: 30,
    fontWeight: '300',
  },
  weekDay: {
    alignItems: 'center',
    borderRadius: 10,
    height: 52,
    justifyContent: 'center',
    width: 34,
  },
  weekDayActive: {
    backgroundColor: '#F0F1F3',
  },
  weekDayText: {
    color: 'rgba(17,17,17,0.60)',
    fontSize: 13,
    fontWeight: '800',
  },
  weekDayTextActive: {
    color: '#2563EB',
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
    gap: 13,
    justifyContent: 'center',
    paddingBottom: 10,
    paddingHorizontal: 28,
    paddingTop: 22,
  },
});
