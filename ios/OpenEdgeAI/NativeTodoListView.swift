import SwiftUI

private enum NativeTodoTab: String {
  case all
  case calendar
}

private let nativeTodoHorizontalPadding: CGFloat = 24
private let nativeTodoCurrentTimeLineID = "native-todo-current-time-line"

private struct NativeCalendarEvent: Identifiable {
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
  @State private var editingTodo: NativeTodoItem?

  private var calendar: Calendar {
    Calendar.current
  }

  private var visibleTodos: [NativeTodoItem] {
    store.todoItems.filter { !$0.isCompleted }
  }

  private var overdueTodos: [NativeTodoItem] {
    visibleTodos.filter { $0.isOverdue() }
  }

  private var selectedDateTodos: [NativeTodoItem] {
    visibleTodos.filter { item in
      !item.isOverdue() && item.occurs(on: selectedDate, calendar: calendar)
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
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE dd, MMMM"
    return formatter.string(from: selectedDate)
  }

  private var selectedTodoSectionTitle: String {
    if calendar.isDateInToday(selectedDate) {
      return "Today"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMM d"
    return formatter.string(from: selectedDate)
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
        .presentationDragIndicator(.visible)
    }
    .sheet(item: $editingTodo) { item in
      NativeTodoEditorSheet(todoItem: item)
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
    HStack(spacing: 12) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("메뉴로 돌아가기")

      Text("Todo List")
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)

      Spacer(minLength: 8)
    }
    .foregroundColor(.black)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(Color.white)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .center) {
        Text(dateTitle)
          .font(.system(size: 31, weight: .bold))
          .foregroundColor(.black)
          .lineLimit(1)

        Spacer()
      }

      NativeTodoWeekStrip(
        accentColor: store.accentColor,
        selectedDate: selectedDate,
        onPreviousWeek: { moveSelectedDate(byDays: -7) },
        onNextWeek: { moveSelectedDate(byDays: 7) },
        onSelectDate: { date in selectedDate = date }
      )

      Picker("Todo 보기", selection: $selectedTab) {
        Text("리스트").tag(NativeTodoTab.all)
        Text("캘린더").tag(NativeTodoTab.calendar)
      }
      .pickerStyle(.segmented)
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
    .padding(.top, 24)
    .padding(.bottom, 18)
  }

  private var allTasksContent: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        NativeTodoSectionHeader(
          title: "Overdue",
          isExpanded: $isOverdueExpanded
        )

        if isOverdueExpanded {
          if overdueTodos.isEmpty {
            NativeTodoEmptyRow(title: "No overdue tasks")
          } else {
            ForEach(overdueTodos) { task in
              todoCard(for: task)
            }
          }
        }

        NativeTodoSectionHeader(
          title: selectedTodoSectionTitle,
          isExpanded: $isTodayExpanded
        )

        if isTodayExpanded {
          if selectedDateTodos.isEmpty {
            NativeTodoEmptyRow(title: "No tasks for this date")
          } else {
            ForEach(selectedDateTodos) { task in
              todoCard(for: task)
            }
          }
        }
      }
      .padding(.horizontal, nativeTodoHorizontalPadding)
      .padding(.top, 22)
      .padding(.bottom, 120)
    }
  }

  private func todoCard(for task: NativeTodoItem) -> some View {
    NativeTodoTaskCard(
      task: task,
      onToggleComplete: {
        withAnimation(.easeInOut(duration: 0.18)) {
          store.toggleTodoCompletion(task)
        }
      },
      onToggleStar: {
        store.toggleTodoStar(task)
      },
      onToggleSubtask: { subtask in
        store.toggleTodoSubtask(todoId: task.id, subtaskId: subtask.id)
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

  private var calendarContent: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          NativeTodoTimeline(
            accentColor: store.accentColor,
            events: calendarEvents,
            currentTimeHour: currentTimeHour
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
    HStack {
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
      .accessibilityLabel("Todo 추가")
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
      return String(format: "%02d시", wholeHour)
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

private struct NativeTodoSectionHeader: View {
  var title: String
  @Binding var isExpanded: Bool

  var body: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.18)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: 12) {
        Text(title)
          .font(.system(size: 25, weight: .bold))
          .foregroundColor(.black)

        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(Color.black.opacity(0.68))
      }
    }
    .buttonStyle(.plain)
    .padding(.top, 2)
  }
}

private struct NativeTodoTaskCard: View {
  var task: NativeTodoItem
  var onToggleComplete: () -> Void
  var onToggleStar: () -> Void
  var onToggleSubtask: (NativeTodoSubtask) -> Void
  var onEdit: () -> Void
  var onDelete: () -> Void

  private var isOverdue: Bool {
    task.isOverdue()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 14) {
        Button(action: onToggleComplete) {
          Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 23, weight: .medium))
            .foregroundColor(task.isCompleted ? .black : Color.black.opacity(0.56))
            .frame(width: 25, height: 25)
            .padding(.top, 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted ? "Todo 완료 해제" : "Todo 완료")

        VStack(alignment: .leading, spacing: 11) {
          HStack(alignment: .top) {
            Text(task.title)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.black)
              .lineLimit(2)

            Spacer()

            Image(systemName: "chevron.up")
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.52))
          }

          if !task.note.isEmpty {
            Text(task.note)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.52))
              .lineSpacing(4)
              .lineLimit(4)
          }

          HStack(spacing: 8) {
            Text(task.dueLabel())
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(isOverdue ? .red.opacity(0.78) : .red.opacity(0.64))

            Text("•")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(Color.black.opacity(0.28))

            Text(task.recurrenceRule.isRepeating ? task.recurrenceRule.title : "Tasks")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.42))

            Spacer()

            Button(action: onToggleStar) {
              Image(systemName: task.isStarred ? "star.fill" : "star")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(task.isStarred ? .red.opacity(0.74) : Color.black.opacity(0.48))
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isStarred ? "중요 해제" : "중요 표시")

            Image(systemName: isOverdue ? "calendar" : "alarm")
              .font(.system(size: 17, weight: .regular))
              .foregroundColor(Color.black.opacity(0.48))
          }
        }
      }

      if !task.subtasks.isEmpty {
        VStack(spacing: 0) {
          ForEach(task.subtasks) { subtask in
            Button {
              onToggleSubtask(subtask)
            } label: {
              HStack(alignment: .top, spacing: 14) {
                Image(systemName: subtask.isComplete ? "checkmark.circle" : "circle")
                  .font(.system(size: 19, weight: .medium))
                  .foregroundColor(Color.black.opacity(0.58))
                  .padding(.top, 1)

                Text(subtask.title)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundColor(Color.black.opacity(0.68))
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)

                Spacer()
              }
              .padding(.leading, 46)
              .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if subtask.id != task.subtasks.last?.id {
              Divider()
                .padding(.leading, 46)
                .background(Color.black.opacity(0.07))
            }
          }
        }
      }
    }
    .padding(22)
    .background(Color(red: 0.94, green: 0.945, blue: 0.95))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .contextMenu {
      Button(action: onEdit) {
        Label("수정", systemImage: "pencil")
      }

      Button(role: .destructive, action: onDelete) {
        Label("삭제", systemImage: "trash")
      }
    }
  }
}

private struct NativeTodoEmptyRow: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(Color.black.opacity(0.42))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .background(Color.black.opacity(0.035))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private struct NativeTodoWeekStrip: View {
  var accentColor: NativeAccentColor
  var selectedDate: Date
  var onPreviousWeek: () -> Void
  var onNextWeek: () -> Void
  var onSelectDate: (Date) -> Void

  private let dayCellWidth: CGFloat = 44
  private let dayCellSpacing: CGFloat = 8
  private let initialLeadingDays = 21
  private let initialDayCount = 43
  private let edgeExtensionDays = 14

  @State private var dayRangeStart = Calendar.current.startOfDay(for: Date())
  @State private var dayRangeCount = 43
  @State private var hasInitializedRange = false
  @State private var scrollPositionID: String?
  @State private var isApplyingScrollSelection = false

  private var days: [Date] {
    let calendar = Calendar.current
    return (0..<dayRangeCount).compactMap {
      calendar.date(byAdding: .day, value: $0, to: dayRangeStart)
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onPreviousWeek) {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(Color.black.opacity(0.58))
          .frame(width: 24, height: 52)
      }
      .buttonStyle(.plain)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: dayCellSpacing) {
          ForEach(days, id: \.self) { day in
            let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)

            Button {
              let id = dayID(for: day)
              ensureRangeContains(day)
              withAnimation(.easeInOut(duration: 0.18)) {
                scrollPositionID = id
              }
              onSelectDate(day)
            } label: {
              VStack(spacing: 3) {
                Text(dayLetter(for: day))
                  .font(.system(size: 13, weight: .bold))
                Text(dayNumber(for: day))
                  .font(.system(size: 12, weight: .semibold))
              }
              .foregroundColor(isSelected ? accentColor.color : Color.black.opacity(0.60))
              .frame(width: dayCellWidth, height: 52)
              .background(isSelected ? accentColor.subtleColor : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .id(dayID(for: day))
            .onAppear {
              extendRangeIfNeeded(for: day)
            }
          }
        }
        .padding(.horizontal, dayCellSpacing)
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $scrollPositionID, anchor: .center)
      .frame(height: 52)
      .onAppear {
        initializeRangeIfNeeded(around: selectedDate)
        scrollPositionID = dayID(for: selectedDate)
      }
      .onChange(of: scrollPositionID) { _, newValue in
        guard let newValue,
              let date = dateFromDayID(newValue),
              !Calendar.current.isDate(date, inSameDayAs: selectedDate) else {
          return
        }
        isApplyingScrollSelection = true
        onSelectDate(date)
      }
      .onChange(of: selectedDate) { _, newValue in
        initializeRangeIfNeeded(around: newValue)
        ensureRangeContains(newValue)
        let id = dayID(for: newValue)

        guard scrollPositionID != id else {
          isApplyingScrollSelection = false
          return
        }

        if isApplyingScrollSelection {
          isApplyingScrollSelection = false
          return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
          scrollPositionID = id
        }
      }

      Button(action: onNextWeek) {
        Image(systemName: "chevron.right")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(Color.black.opacity(0.58))
          .frame(width: 24, height: 52)
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  private func initializeRangeIfNeeded(around date: Date) {
    guard !hasInitializedRange else {
      return
    }

    resetRange(around: date)
    hasInitializedRange = true
  }

  private func resetRange(around date: Date) {
    let calendar = Calendar.current
    let selectedDay = calendar.startOfDay(for: date)
    dayRangeStart = calendar.date(byAdding: .day, value: -initialLeadingDays, to: selectedDay) ?? selectedDay
    dayRangeCount = initialDayCount
  }

  private func ensureRangeContains(_ date: Date) {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: date)
    let rangeEnd = calendar.date(byAdding: .day, value: max(0, dayRangeCount - 1), to: dayRangeStart) ?? dayRangeStart

    if day < dayRangeStart {
      let missingDays = calendar.dateComponents([.day], from: day, to: dayRangeStart).day ?? 0
      let prependDays = missingDays + edgeExtensionDays
      dayRangeStart = calendar.date(byAdding: .day, value: -prependDays, to: dayRangeStart) ?? dayRangeStart
      dayRangeCount += prependDays
    } else if day > rangeEnd {
      let missingDays = calendar.dateComponents([.day], from: rangeEnd, to: day).day ?? 0
      dayRangeCount += missingDays + edgeExtensionDays
    }
  }

  private func extendRangeIfNeeded(for day: Date) {
    guard let firstDay = days.first, let lastDay = days.last else {
      return
    }

    let calendar = Calendar.current
    if calendar.isDate(day, inSameDayAs: firstDay) {
      prependRange()
    } else if calendar.isDate(day, inSameDayAs: lastDay) {
      dayRangeCount += edgeExtensionDays
    }
  }

  private func prependRange() {
    let currentScrollID = scrollPositionID
    dayRangeStart = Calendar.current.date(
      byAdding: .day,
      value: -edgeExtensionDays,
      to: dayRangeStart
    ) ?? dayRangeStart
    dayRangeCount += edgeExtensionDays

    guard let currentScrollID else {
      return
    }

    DispatchQueue.main.async {
      scrollPositionID = currentScrollID
    }
  }

  private func dayLetter(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "E"
    return String(formatter.string(from: date).prefix(1))
  }

  private func dayNumber(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "dd"
    return formatter.string(from: date)
  }

  private func dayID(for date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  private func dateFromDayID(_ id: String) -> Date? {
    let values = id.split(separator: "-").compactMap { Int($0) }
    guard values.count == 3 else {
      return nil
    }

    return Calendar.current.date(from: DateComponents(
      year: values[0],
      month: values[1],
      day: values[2]
    ))
  }
}

private struct NativeTodoTimeline: View {
  var accentColor: NativeAccentColor
  var events: [NativeCalendarEvent]
  var currentTimeHour: CGFloat?

  private let timelineStart: CGFloat = 1
  private let timelineEnd: CGFloat = 24
  private let hourHeight: CGFloat = 58
  private let hourLineOffset: CGFloat = 9
  private let eventLaneStart: CGFloat = 60
  private let eventLaneCount: CGFloat = 4
  private let eventLaneGap: CGFloat = 8
  private let hours = Array(1...24)

  private var timelineHeight: CGFloat {
    hourLineOffset + CGFloat(hours.count - 1) * hourHeight + 80
  }

  var body: some View {
    GeometryReader { proxy in
      let laneWidth = eventWidth(containerWidth: proxy.size.width)

      ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
          ForEach(hours, id: \.self) { hour in
            NativeTodoTimelineHourRow(hour: hour, height: hourHeight)
          }
        }

        ForEach(events) { event in
          NativeTodoCalendarEventCard(accentColor: accentColor, event: event)
            .frame(width: laneWidth, height: eventHeight(for: event))
            .offset(
              x: eventXOffset(for: event, laneWidth: laneWidth),
              y: eventOffset(for: event)
            )
        }

        if let currentTimeHour {
          NativeTodoCurrentTimeLine(timeText: currentTimeText(for: currentTimeHour))
            .id(nativeTodoCurrentTimeLineID)
            .frame(width: proxy.size.width, alignment: .leading)
            .offset(x: 0, y: currentTimeOffset(for: currentTimeHour))
            .zIndex(10)
        }
      }
    }
    .frame(height: timelineHeight, alignment: .topLeading)
  }

  private func eventWidth(containerWidth: CGFloat) -> CGFloat {
    let availableWidth = max(0, containerWidth - eventLaneStart - eventLaneGap * (eventLaneCount - 1))
    return max(44, floor(availableWidth / eventLaneCount))
  }

  private func eventXOffset(for event: NativeCalendarEvent, laneWidth: CGFloat) -> CGFloat {
    eventLaneStart + CGFloat(event.lane) * (laneWidth + eventLaneGap)
  }

  private func eventOffset(for event: NativeCalendarEvent) -> CGFloat {
    let startHour = min(max(event.startHour, timelineStart), timelineEnd - 0.5)
    return hourLineOffset + (startHour - timelineStart) * hourHeight
  }

  private func eventHeight(for event: NativeCalendarEvent) -> CGFloat {
    let startHour = min(max(event.startHour, timelineStart), timelineEnd - 0.5)
    let availableHours = max(0.5, timelineEnd - startHour)
    return min(max(0.5, event.duration), availableHours) * hourHeight
  }

  private func currentTimeOffset(for hour: CGFloat) -> CGFloat {
    let boundedHour = min(max(hour, timelineStart), timelineEnd)
    return hourLineOffset + (boundedHour - timelineStart) * hourHeight
  }

  private func currentTimeText(for hour: CGFloat) -> String {
    let boundedHour = min(max(hour, timelineStart), timelineEnd)
    var wholeHour = Int(floor(boundedHour))
    var minute = Int(round((boundedHour - CGFloat(wholeHour)) * 60))
    if minute == 60 {
      wholeHour += 1
      minute = 0
    }

    return String(format: "%02d:%02d", min(wholeHour, 24), minute)
  }
}

private struct NativeTodoCurrentTimeLine: View {
  var timeText: String

  private let indicatorColor = Color(red: 1, green: 0.23, blue: 0.18)

  var body: some View {
    HStack(spacing: 5) {
      Text(timeText)
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.white)
        .lineLimit(1)
        .frame(width: 48, height: 18)
        .background(indicatorColor)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(Color.white, lineWidth: 1.5)
        )

      Circle()
        .fill(indicatorColor)
        .frame(width: 9, height: 9)
        .overlay(
          Circle()
            .stroke(Color.white, lineWidth: 1.5)
        )

      ZStack {
        Rectangle()
          .fill(Color.white)
          .frame(height: 4)

        Rectangle()
          .fill(indicatorColor)
          .frame(height: 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .offset(y: -9)
  }
}

private struct NativeTodoTimelineHourRow: View {
  var hour: Int
  var height: CGFloat

  private let hourLineOffset: CGFloat = 9

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Text(String(format: "%02d시", hour))
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(Color.black.opacity(0.36))
        .frame(width: 44, alignment: .leading)
        .padding(.top, 2)

      ZStack(alignment: .topLeading) {
        Rectangle()
          .fill(Color.black.opacity(0.13))
          .frame(height: 1)
          .offset(y: hourLineOffset)

        if hour < 24 {
          Rectangle()
            .fill(Color.black.opacity(0.16))
            .frame(width: 18, height: 1)
            .offset(y: hourLineOffset + height / 2)
        }
      }
      .frame(height: height, alignment: .top)
    }
    .frame(height: height, alignment: .top)
  }
}

private struct NativeTodoCalendarEventCard: View {
  var accentColor: NativeAccentColor
  var event: NativeCalendarEvent

  private var isCompact: Bool {
    event.duration <= 0.5
  }

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 2 : 10) {
      Text(event.title)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(accentColor.foregroundColor)
        .lineLimit(isCompact ? 1 : 3)

      if !isCompact {
        Text(event.accent)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(accentColor.foregroundColor.opacity(0.72))
          .lineLimit(2)

        Spacer()

        Text(event.timeText)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(accentColor.foregroundColor.opacity(0.82))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, isCompact ? 5 : 11)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(accentColor.color)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}

private struct NativeTodoEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  var todoItem: NativeTodoItem?
  var selectedDate: Date

  @State private var title = ""
  @State private var note = ""
  @State private var startDate: Date
  @State private var endDate: Date
  @State private var repeatRule: NativeTodoRepeatRule

  init(selectedDate: Date) {
    self.todoItem = nil
    self.selectedDate = selectedDate
    let defaultStartDate = NativeTodoEditorSheet.defaultStartDate(for: selectedDate)
    _startDate = State(initialValue: defaultStartDate)
    _endDate = State(initialValue: NativeTodoEditorSheet.defaultEndDate(for: defaultStartDate))
    _repeatRule = State(initialValue: .none)
  }

  init(todoItem: NativeTodoItem) {
    self.todoItem = todoItem
    self.selectedDate = todoItem.dueDate
    let startDate = NativeTodoEditorSheet.startDate(for: todoItem)
    _title = State(initialValue: todoItem.title)
    _note = State(initialValue: todoItem.note)
    _startDate = State(initialValue: startDate)
    _endDate = State(initialValue: NativeTodoEditorSheet.endDate(for: todoItem, startDate: startDate))
    _repeatRule = State(initialValue: todoItem.recurrenceRule)
  }

  private var isEditing: Bool {
    todoItem != nil
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Title")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.black.opacity(0.48))
          TextField("New task", text: $title)
            .font(.system(size: 18, weight: .semibold))
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.black.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Note")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.black.opacity(0.48))
          TextField("Optional details", text: $note, axis: .vertical)
            .font(.system(size: 16, weight: .medium))
            .lineLimit(2...5)
            .padding(14)
            .background(Color.black.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        VStack(spacing: 0) {
          DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
            .font(.system(size: 16, weight: .semibold))
            .tint(store.accentColor.color)
            .padding(.vertical, 12)

          Divider()
            .background(Color.black.opacity(0.07))

          DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
            .font(.system(size: 16, weight: .semibold))
            .tint(store.accentColor.color)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 14)
        .background(Color.black.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        HStack(spacing: 12) {
          Text("Repeat")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.black.opacity(0.48))

          Spacer()

          Picker("Repeat", selection: $repeatRule) {
            ForEach(NativeTodoRepeatRule.allCases) { rule in
              Text(rule.title).tag(rule)
            }
          }
          .pickerStyle(.menu)
          .tint(store.accentColor.color)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.black.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        Spacer()
      }
      .padding(22)
      .background(Color.white)
      .navigationTitle(isEditing ? "Edit Todo" : "Add Todo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            if let todoItem {
              store.updateTodo(
                todoItem,
                title: title,
                note: note,
                startDate: startDate,
                endDate: endDate,
                repeatRule: repeatRule
              )
            } else {
              store.createTodo(
                title: title,
                note: note,
                startDate: startDate,
                endDate: endDate,
                repeatRule: repeatRule
              )
            }
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onChange(of: startDate) { _, newValue in
        let minimumEndDate = Calendar.current.date(byAdding: .minute, value: 30, to: newValue) ?? newValue
        if endDate < minimumEndDate {
          endDate = NativeTodoEditorSheet.defaultEndDate(for: newValue)
        }
      }
      .onChange(of: endDate) { _, newValue in
        let minimumEndDate = Calendar.current.date(byAdding: .minute, value: 30, to: startDate) ?? startDate
        if newValue < minimumEndDate {
          endDate = minimumEndDate
        }
      }
    }
  }

  private static func defaultStartDate(for selectedDate: Date) -> Date {
    Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: selectedDate) ?? selectedDate
  }

  private static func defaultEndDate(for startDate: Date) -> Date {
    Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
  }

  private static func startDate(for item: NativeTodoItem) -> Date {
    date(on: item.dueDate, timelineHour: item.startHour)
  }

  private static func endDate(for item: NativeTodoItem, startDate: Date) -> Date {
    let durationMinutes = Int((max(0.5, item.durationHours) * 60).rounded())
    return Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? defaultEndDate(for: startDate)
  }

  private static func date(on baseDate: Date, timelineHour: Double) -> Date {
    let boundedHour = min(max(timelineHour, 1), 23.5)
    let hour = Int(floor(boundedHour))
    let minute = Int(round((boundedHour - Double(hour)) * 60))
    return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
  }
}
