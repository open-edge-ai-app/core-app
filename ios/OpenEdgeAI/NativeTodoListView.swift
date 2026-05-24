import SwiftUI

private enum NativeTodoTab: String {
  case all
  case calendar
}

private let nativeTodoHorizontalPadding: CGFloat = 24
let nativeTodoCurrentTimeLineID = "native-todo-current-time-line"

struct NativeCalendarEvent: Identifiable {
  var id: String
  var task: NativeTodoItem
  var title: String
  var note: String
  var labels: [NativeTodoLabel]
  var startHour: CGFloat
  var duration: CGFloat
  var lane: Int
  var timeText: String
  var isCompleted: Bool
}

private struct NativeRecurringTodoDeleteRequest {
  var task: NativeTodoItem
  var occurrenceDate: Date
}

private struct NativeTodoTagTaskGroup: Identifiable {
  var id: String
  var title: String
  var colorHex: String?
  var tasks: [NativeTodoItem]
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
  @State private var expandedTaskIds: Set<String> = []
  @State private var recurringDeleteRequest: NativeRecurringTodoDeleteRequest?

  private var calendar: Calendar {
    Calendar.current
  }

  private var overdueTodos: [NativeTodoItem] {
    store.todoItems.filter { $0.isOverdue() }
  }

  private var selectedDateTodos: [NativeTodoItem] {
    store.todoItems.filter { item in
      guard !item.isOverdue(), item.occurs(on: selectedDate, calendar: calendar) else {
        return false
      }
      return !store.todoHideCompletedTasks || !item.isCompleted(on: selectedDate, calendar: calendar)
    }
  }

  private var calendarEvents: [NativeCalendarEvent] {
    selectedDateTodos.enumerated().map { index, item in
      NativeCalendarEvent(
        id: item.id,
        task: item,
        title: item.title,
        note: item.note.trimmingCharacters(in: .whitespacesAndNewlines),
        labels: store.todoTagsVisibleOnTaskCards ? labels(for: item) : [],
        startHour: CGFloat(item.startHour),
        duration: CGFloat(max(0.5, item.durationHours)),
        lane: index % 4,
        timeText: eventTimeText(for: item),
        isCompleted: item.isCompleted(on: selectedDate, calendar: calendar)
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

        header

        Divider()
          .background(Color.oeSeparator)

        if selectedTab == .all {
          allTasksContent
        } else {
          calendarContent
        }
      }
      .background(Color.oeBackground)

      bottomControls
    }
    .background(Color.oeBackground.ignoresSafeArea())
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
    .confirmationDialog(
      store.i18n.t(.todoDeleteRepeatTitle),
      isPresented: isShowingRecurringDeleteDialog,
      titleVisibility: .visible
    ) {
      if let recurringDeleteRequest {
        Button(store.i18n.t(.todoDeleteThisOccurrence)) {
          withAnimation(.easeInOut(duration: 0.18)) {
            store.deleteTodoOccurrence(
              recurringDeleteRequest.task,
              occurrenceDate: recurringDeleteRequest.occurrenceDate
            )
          }
          self.recurringDeleteRequest = nil
        }

        Button(store.i18n.t(.todoDeleteEntireSeries), role: .destructive) {
          withAnimation(.easeInOut(duration: 0.18)) {
            store.deleteTodo(recurringDeleteRequest.task)
          }
          self.recurringDeleteRequest = nil
        }
      }

      Button(store.i18n.t(.commonCancel), role: .cancel) {
        recurringDeleteRequest = nil
      }
    } message: {
      Text(store.i18n.t(.todoDeleteRepeatMessage))
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
          .background(.ultraThinMaterial, in: Circle())
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
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
          .background(.ultraThinMaterial, in: Circle())
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoSettings))
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
  }

  private var header: some View {
    let i18n = store.i18n

    return VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .center) {
        Text(dateTitle)
          .font(.system(size: 31, weight: .bold))
          .foregroundColor(.oeText)
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
      VStack(alignment: .leading, spacing: 26) {
        todoListSection(
          title: i18n.t(.todoOverdue),
          isExpanded: $isOverdueExpanded,
          tasks: overdueTodos,
          occurrenceDate: nil,
          emptyTitle: i18n.t(.todoNoOverdue)
        )

        todoListSection(
          title: selectedTodoSectionTitle,
          isExpanded: $isTodayExpanded,
          tasks: selectedDateTodos,
          occurrenceDate: selectedDate,
          emptyTitle: i18n.t(.todoNoTasksForDate),
          separatesTags: store.todoTagsVisibleOnTaskCards
        )
      }
      .padding(.horizontal, nativeTodoHorizontalPadding)
      .padding(.top, 22)
      .padding(.bottom, 120)
      .animation(.spring(response: 0.36, dampingFraction: 0.9), value: isOverdueExpanded)
      .animation(.spring(response: 0.36, dampingFraction: 0.9), value: isTodayExpanded)
    }
  }

  private var todoSectionTransition: AnyTransition {
    .opacity
  }

  @ViewBuilder
  private func todoListSection(
    title: String,
    isExpanded: Binding<Bool>,
    tasks: [NativeTodoItem],
    occurrenceDate: Date?,
    emptyTitle: String,
    separatesTags: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: isExpanded.wrappedValue ? 12 : 0) {
      NativeTodoSectionHeader(
        title: title,
        isExpanded: isExpanded
      )

      if isExpanded.wrappedValue {
        todoSectionContent(
          tasks: tasks,
          occurrenceDate: occurrenceDate,
          emptyTitle: emptyTitle,
          separatesTags: separatesTags
        )
        .transition(todoSectionTransition)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func todoSectionContent(
    tasks: [NativeTodoItem],
    occurrenceDate: Date?,
    emptyTitle: String,
    separatesTags: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      if tasks.isEmpty {
        NativeTodoEmptyRow(title: emptyTitle)
      } else if separatesTags {
        ForEach(todoTagGroups(for: tasks)) { group in
          NativeTodoTagTaskGroupView(
            title: group.title,
            colorHex: group.colorHex
          ) {
            ForEach(group.tasks) { task in
              todoCard(
                for: task,
                occurrenceDate: occurrenceDate ?? task.dueDate,
                showsLabels: false
              )
            }
          }
        }
      } else {
        ForEach(tasks) { task in
          todoCard(for: task, occurrenceDate: occurrenceDate ?? task.dueDate)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func todoCard(
    for task: NativeTodoItem,
    occurrenceDate: Date,
    showsLabels: Bool = true
  ) -> some View {
    NativeTodoTaskCard(
      i18n: store.i18n,
      task: task,
      occurrenceDate: occurrenceDate,
      labels: labels(for: task),
      availableLabels: store.todoLabels,
      showsLabels: showsLabels && store.todoTagsVisibleOnTaskCards,
      isExpanded: expandedTaskIds.contains(task.id),
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
      onSelectLabel: { label in
        store.setTodoLabel(task, label: label)
      },
      onToggleExpanded: {
        withAnimation(.easeInOut(duration: 0.18)) {
          toggleExpandedTask(task)
        }
      },
      onEdit: {
        editingTodo = task
      },
      onDelete: {
        requestDelete(task, occurrenceDate: occurrenceDate)
      }
    )
  }

  private var isShowingRecurringDeleteDialog: Binding<Bool> {
    Binding(
      get: { recurringDeleteRequest != nil },
      set: { isPresented in
        if !isPresented {
          recurringDeleteRequest = nil
        }
      }
    )
  }

  private func requestDelete(_ task: NativeTodoItem, occurrenceDate: Date) {
    if task.recurrenceRule.isRepeating {
      recurringDeleteRequest = NativeRecurringTodoDeleteRequest(
        task: task,
        occurrenceDate: occurrenceDate
      )
    } else {
      withAnimation(.easeInOut(duration: 0.18)) {
        store.deleteTodo(task)
      }
    }
  }

  private func toggleExpandedTask(_ task: NativeTodoItem) {
    if expandedTaskIds.contains(task.id) {
      expandedTaskIds.remove(task.id)
    } else {
      expandedTaskIds.insert(task.id)
    }
  }

  private func labels(for task: NativeTodoItem) -> [NativeTodoLabel] {
    Array(store.todoLabels.filter { task.labelIds.contains($0.id) }.prefix(1))
  }

  private func todoTagGroups(for tasks: [NativeTodoItem]) -> [NativeTodoTagTaskGroup] {
    var tasksByLabelId: [String: [NativeTodoItem]] = [:]
    var untaggedTasks: [NativeTodoItem] = []
    let labelIds = Set(store.todoLabels.map(\.id))

    for task in tasks {
      if let labelId = task.labelIds.first, labelIds.contains(labelId) {
        tasksByLabelId[labelId, default: []].append(task)
      } else {
        untaggedTasks.append(task)
      }
    }

    var groups = store.todoLabels.compactMap { label -> NativeTodoTagTaskGroup? in
      guard let tasks = tasksByLabelId[label.id], !tasks.isEmpty else {
        return nil
      }

      return NativeTodoTagTaskGroup(
        id: label.id,
        title: label.title,
        colorHex: label.colorHex,
        tasks: tasks
      )
    }

    if !untaggedTasks.isEmpty {
      groups.append(
        NativeTodoTagTaskGroup(
          id: "native-todo-untagged",
          title: store.i18n.t(.todoNoLabel),
          colorHex: nil,
          tasks: untaggedTasks
        )
      )
    }

    return groups
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
            i18n: i18n,
            onEditEvent: { task in
              editingTodo = task
            },
            onDeleteEvent: { task in
              requestDelete(task, occurrenceDate: selectedDate)
            }
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
          .foregroundColor(store.accentColor.foregroundColor)
          .frame(width: 56, height: 56)
          .background(
            store.accentColor.color.opacity(0.72),
            in: Circle()
          )
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
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

  private func eventTimeText(for item: NativeTodoItem) -> String {
    let start = item.startHour
    let end = min(24, item.startHour + item.durationHours)
    return "\(hourText(start)) - \(hourText(end))"
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
