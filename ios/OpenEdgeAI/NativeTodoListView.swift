import SwiftUI

private enum NativeTodoTab: String {
  case all
  case calendar
}

private let nativeTodoHorizontalPadding: CGFloat = 24
let nativeTodoCurrentTimeLineID = "native-todo-current-time-line"

struct NativeCalendarEvent: Identifiable {
  var id: String
  var title: String
  var accent: String
  var startHour: CGFloat
  var duration: CGFloat
  var lane: Int
  var timeText: String
}

struct NativeTodoListView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  @State private var selectedTab: NativeTodoTab = .all
  @State private var isOverdueExpanded = true
  @State private var isTodayExpanded = true
  @State private var selectedDate = Date()
  @State private var currentDate = Date()
  @State private var showingComposer = false
  @State private var showingSettings = false
  @State private var editingTodo: NativeTodoItem?

  private var calendar: Calendar {
    Calendar.current
  }

  private var visibleTodos: [NativeTodoItem] {
    store.todoItems.filter { $0.recurrenceRule.isRepeating || !$0.isCompleted }
  }

  private var overdueTodos: [NativeTodoItem] {
    visibleTodos.filter { $0.isOverdue() }
  }

  private var selectedDateTodos: [NativeTodoItem] {
    visibleTodos.filter { item in
      !item.isOverdue() && item.isVisible(on: selectedDate, calendar: calendar)
    }
  }

  private var calendarEvents: [NativeCalendarEvent] {
    selectedDateTodos.enumerated().map { index, item in
      NativeCalendarEvent(
        id: item.id,
        title: eventTitle(for: item.title),
        accent: eventAccent(for: item.title),
        startHour: CGFloat(item.startHour),
        duration: CGFloat(max(0.5, item.durationHours)),
        lane: index % 4,
        timeText: eventTimeText(for: item)
      )
    }
  }

  private var currentTimeHour: CGFloat? {
    guard calendar.isDateInToday(selectedDate) else {
      return nil
    }

    let components = calendar.dateComponents([.hour, .minute], from: currentDate)
    let hour = CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0) / 60
    guard hour >= 1 && hour <= 24 else {
      return nil
    }

    return hour
  }

  private var dateTitle: String {
    store.i18n.dateTitle(for: selectedDate)
  }

  private var selectedTodoSectionTitle: String {
    store.i18n.t(.todoTasks)
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      VStack(spacing: 0) {
        topBar

        Divider()
          .background(Color.black.opacity(0.08))

        header

        Divider()
          .background(Color.black.opacity(0.08))

        if selectedTab == .all {
          allTasksContent
        } else {
          calendarContent
        }
      }
      .background(Color.white)

      bottomControls
    }
    .background(Color.white.ignoresSafeArea())
    .sheet(isPresented: $showingComposer) {
      NativeTodoEditorSheet(selectedDate: selectedDate)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
    }
    .sheet(item: $editingTodo) { item in
      NativeTodoEditorSheet(todoItem: item)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingSettings) {
      NativeTodoSettingsSheet()
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
      currentDate = date
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  private var topBar: some View {
    let i18n = store.i18n

    return HStack(spacing: 12) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoBackToMenu))

      Text(i18n.t(.todoListTitle))
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)

      Spacer(minLength: 8)

      Button {
        showingSettings = true
      } label: {
        Image(systemName: "gearshape")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoSettings))
    }
    .foregroundColor(.black)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(Color.white)
  }

  private var header: some View {
    let i18n = store.i18n

    return VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .center) {
        Text(dateTitle)
          .font(.system(size: 31, weight: .bold))
          .foregroundColor(.black)
          .lineLimit(1)

        Spacer()
      }

      NativeTodoWeekStrip(
        accentColor: store.accentColor,
        i18n: i18n,
        selectedDate: selectedDate,
        onPreviousWeek: { moveSelectedDate(byDays: -7) },
        onNextWeek: { moveSelectedDate(byDays: 7) },
        onSelectDate: { date in selectedDate = date }
      )

      Picker(i18n.t(.todoViewPicker), selection: $selectedTab) {
        Text(i18n.t(.todoTabList)).tag(NativeTodoTab.all)
        Text(i18n.t(.todoTabCalendar)).tag(NativeTodoTab.calendar)
      }
      .pickerStyle(.segmented)
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
    .padding(.top, 24)
    .padding(.bottom, 18)
  }

  private var allTasksContent: some View {
    let i18n = store.i18n

    return ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        NativeTodoSectionHeader(
          title: i18n.t(.todoOverdue),
          isExpanded: $isOverdueExpanded
        )

        if isOverdueExpanded {
          if overdueTodos.isEmpty {
            NativeTodoEmptyRow(title: i18n.t(.todoNoOverdue))
          } else {
            ForEach(overdueTodos) { task in
              todoCard(for: task, occurrenceDate: task.dueDate)
            }
          }
        }

        NativeTodoSectionHeader(
          title: selectedTodoSectionTitle,
          isExpanded: $isTodayExpanded
        )

        if isTodayExpanded {
          if selectedDateTodos.isEmpty {
            NativeTodoEmptyRow(title: i18n.t(.todoNoTasksForDate))
          } else {
            ForEach(selectedDateTodos) { task in
              todoCard(for: task, occurrenceDate: selectedDate)
            }
          }
        }
      }
      .padding(.horizontal, nativeTodoHorizontalPadding)
      .padding(.top, 22)
      .padding(.bottom, 120)
    }
  }

  private func todoCard(for task: NativeTodoItem, occurrenceDate: Date) -> some View {
    NativeTodoTaskCard(
      i18n: store.i18n,
      task: task,
      occurrenceDate: occurrenceDate,
      labels: labels(for: task),
      availableLabels: store.todoLabels,
      onToggleComplete: {
        withAnimation(.easeInOut(duration: 0.18)) {
          store.toggleTodoCompletion(task, occurrenceDate: occurrenceDate)
        }
      },
      onToggleStar: {
        store.toggleTodoStar(task)
      },
      onToggleSubtask: { subtask in
        store.toggleTodoSubtask(todoId: task.id, subtaskId: subtask.id)
      },
      onToggleLabel: { label in
        store.toggleTodoLabel(task, label: label)
      },
      onEdit: {
        editingTodo = task
      },
      onDelete: {
        withAnimation(.easeInOut(duration: 0.18)) {
          store.deleteTodo(task)
        }
      }
    )
  }

  private func labels(for task: NativeTodoItem) -> [NativeTodoLabel] {
    store.todoLabels.filter { task.labelIds.contains($0.id) }
  }

  private var calendarContent: some View {
    let i18n = store.i18n

    return VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          NativeTodoTimeline(
            accentColor: store.accentColor,
            events: calendarEvents,
            currentTimeHour: currentTimeHour,
            i18n: i18n
          )
            .padding(.bottom, 132)
        }
        .onAppear {
          scrollCalendarToCurrentTime(proxy)
        }
        .onChange(of: selectedDate) { _, _ in
          scrollCalendarToCurrentTime(proxy)
        }
      }
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
  }

  private var bottomControls: some View {
    let i18n = store.i18n

    return HStack {
      Spacer()
      Button {
        showingComposer = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 31, weight: .light))
          .foregroundColor(.white)
          .frame(width: 56, height: 56)
          .background(Color.black)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoAdd))
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
    .padding(.bottom, 24)
  }

  private func moveSelectedDate(byDays days: Int) {
    selectedDate = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
  }

  private func eventTitle(for title: String) -> String {
    title
      .split(separator: " ")
      .prefix(3)
      .map(String.init)
      .joined(separator: "\n")
  }

  private func eventAccent(for title: String) -> String {
    title
      .split(separator: " ")
      .prefix(2)
      .map(String.init)
      .joined(separator: "-\n")
  }

  private func eventTimeText(for item: NativeTodoItem) -> String {
    let start = item.startHour
    let end = min(24, item.startHour + item.durationHours)
    return "\(hourText(start)) -\n\(hourText(end))"
  }

  private func hourText(_ hour: Double) -> String {
    let boundedHour = min(max(hour, 1), 24)
    var wholeHour = Int(floor(boundedHour))
    var minute = Int(round((boundedHour - Double(wholeHour)) * 60))
    if minute == 60 {
      wholeHour += 1
      minute = 0
    }

    if minute == 0 {
      return store.i18n.timelineHour(wholeHour)
    }
    return String(format: "%02d:%02d", wholeHour, minute)
  }

  private func scrollCalendarToCurrentTime(_ proxy: ScrollViewProxy) {
    guard currentTimeHour != nil else {
      return
    }

    DispatchQueue.main.async {
      withAnimation(.easeInOut(duration: 0.2)) {
        proxy.scrollTo(nativeTodoCurrentTimeLineID, anchor: .center)
      }
    }
  }
}
