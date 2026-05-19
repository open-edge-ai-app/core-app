import SwiftUI

private enum NativeTodoTab {
  case all
  case calendar
}

private enum NativeTodoCalendarMode {
  case week
  case day
}

private let nativeTodoHorizontalPadding: CGFloat = 24

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
  @State private var calendarMode: NativeTodoCalendarMode = .week
  @State private var isOverdueExpanded = true
  @State private var isTodayExpanded = true
  @State private var selectedDate = Date()
  @State private var showingComposer = false
  @State private var showingStarredOnly = false

  private var calendar: Calendar {
    Calendar.current
  }

  private var visibleTodos: [NativeTodoItem] {
    store.todoItems.filter { item in
      !item.isCompleted && (!showingStarredOnly || item.isStarred)
    }
  }

  private var overdueTodos: [NativeTodoItem] {
    visibleTodos.filter { $0.isOverdue() }
  }

  private var selectedDateTodos: [NativeTodoItem] {
    visibleTodos.filter { item in
      !item.isOverdue() && calendar.isDate(item.dueDate, inSameDayAs: selectedDate)
    }
  }

  private var calendarEvents: [NativeCalendarEvent] {
    selectedDateTodos.enumerated().map { index, item in
      NativeCalendarEvent(
        id: item.id,
        title: eventTitle(for: item.title),
        accent: eventAccent(for: item.title),
        startHour: CGFloat(item.startHour),
        duration: CGFloat(max(1, item.durationHours)),
        lane: index % 4,
        timeText: eventTimeText(for: item)
      )
    }
  }

  private var dateTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE dd, MMMM"
    return formatter.string(from: selectedDate)
  }

  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMMM"
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

        Button {
          withAnimation(.easeInOut(duration: 0.16)) {
            showingStarredOnly.toggle()
          }
        } label: {
          Image(systemName: showingStarredOnly ? "star.fill" : "slider.vertical.3")
            .font(.system(size: showingStarredOnly ? 22 : 24, weight: .medium))
            .foregroundColor(showingStarredOnly ? .red.opacity(0.74) : .black)
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showingStarredOnly ? "중요 Todo만 보기 해제" : "중요 Todo만 보기")
      }
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
    .padding(.top, 24)
    .padding(.bottom, 24)
  }

  private var tabSwitcher: some View {
    HStack(spacing: 12) {
      tabButton(title: "All", tab: .all)
      tabButton(title: "Calendar", tab: .calendar)

      Spacer()

      Button {
        withAnimation(.easeInOut(duration: 0.16)) {
          showingStarredOnly.toggle()
        }
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 25, weight: .regular))
          .foregroundColor(.black)
          .frame(width: 44, height: 42)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Todo 검색")
    }
  }

  private func tabButton(title: String, tab: NativeTodoTab) -> some View {
    Button {
      selectedTab = tab
    } label: {
      Text(title)
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(selectedTab == tab ? .black : Color.black.opacity(0.52))
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(selectedTab == tab ? Color.black.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var allTasksContent: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        tabSwitcher

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
          title: "Today",
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
      onDelete: {
        withAnimation(.easeInOut(duration: 0.18)) {
          store.deleteTodo(task)
        }
      }
    )
  }

  private var calendarContent: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Button {
          calendarMode = .week
        } label: {
          Text("Week")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(calendarMode == .week ? .blue.opacity(0.72) : Color.black.opacity(0.62))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(calendarMode == .week ? Color.black.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)

        Button {
          calendarMode = .day
        } label: {
          Text("Day")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(calendarMode == .day ? .blue.opacity(0.72) : Color.black.opacity(0.62))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(calendarMode == .day ? Color.black.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)

        Spacer()

        Button {
          showingStarredOnly.toggle()
        } label: {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 25, weight: .regular))
            .foregroundColor(.black)
            .frame(width: 44, height: 42)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 20)

      NativeTodoWeekStrip(
        selectedDate: selectedDate,
        onPreviousWeek: { moveSelectedDate(byDays: -7) },
        onNextWeek: { moveSelectedDate(byDays: 7) },
        onSelectDate: { date in selectedDate = date }
      )
      .padding(.top, 22)
      .padding(.bottom, 10)

      ScrollView(showsIndicators: false) {
        NativeTodoTimeline(events: calendarEvents)
          .frame(height: 720)
          .padding(.bottom, 132)
      }
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
  }

  private var bottomControls: some View {
    HStack(alignment: .center, spacing: 14) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "arrow.left")
          .font(.system(size: 28, weight: .regular))
          .foregroundColor(.black)
          .frame(width: 56, height: 56)
          .background(Color.white.opacity(0.94))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Todo List 닫기")

      HStack(spacing: 22) {
        Button {
          moveSelectedDate(byMonths: -1)
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 19, weight: .semibold))
            .frame(width: 34, height: 44)
        }
        .buttonStyle(.plain)

        Text(monthTitle)
          .font(.system(size: 16, weight: .bold))
          .frame(minWidth: 92)

        Button {
          moveSelectedDate(byMonths: 1)
        } label: {
          Image(systemName: "chevron.right")
            .font(.system(size: 19, weight: .semibold))
            .frame(width: 34, height: 44)
        }
        .buttonStyle(.plain)
      }
      .foregroundColor(.black)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.white.opacity(0.96))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 10)

      Button {
        showingComposer = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 31, weight: .light))
          .foregroundColor(.blue.opacity(0.72))
          .frame(width: 56, height: 56)
          .background(Color.white.opacity(0.96))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 10)
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

  private func moveSelectedDate(byMonths months: Int) {
    selectedDate = calendar.date(byAdding: .month, value: months, to: selectedDate) ?? selectedDate
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
    let start = Int(item.startHour)
    let end = Int(min(23, item.startHour + item.durationHours))
    return "\(hourText(start)) -\n\(hourText(end))"
  }

  private func hourText(_ hour: Int) -> String {
    let value = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    let suffix = hour >= 12 ? "PM" : "AM"
    return String(format: "%02d%@", value, suffix)
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

            Text("Tasks")
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
  var selectedDate: Date
  var onPreviousWeek: () -> Void
  var onNextWeek: () -> Void
  var onSelectDate: (Date) -> Void

  private var days: [Date] {
    let calendar = Calendar.current
    let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
      ?? calendar.startOfDay(for: selectedDate)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
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

      ForEach(days, id: \.timeIntervalSince1970) { day in
        Button {
          onSelectDate(day)
        } label: {
          VStack(spacing: 3) {
            Text(dayLetter(for: day))
              .font(.system(size: 13, weight: .bold))
            Text(dayNumber(for: day))
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundColor(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? .blue.opacity(0.76) : Color.black.opacity(0.60))
          .frame(width: 34, height: 52)
          .background(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? Color.black.opacity(0.07) : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
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
}

private struct NativeTodoTimeline: View {
  var events: [NativeCalendarEvent]

  private let timelineStart: CGFloat = 11
  private let hourHeight: CGFloat = 82
  private let times = ["11 AM", "12 PM", "01 PM", "02 PM", "03 PM", "04 PM", "05 PM", "06 PM", "07 PM", "08 PM"]

  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(spacing: 0) {
        ForEach(Array(times.enumerated()), id: \.offset) { _, time in
          HStack(alignment: .top, spacing: 16) {
            Text(time)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(Color.black.opacity(0.36))
              .frame(width: 44, alignment: .leading)

            Rectangle()
              .fill(Color.black.opacity(0.12))
              .frame(height: 1)
              .padding(.top, 9)
          }
          .frame(height: hourHeight, alignment: .top)
        }
      }

      if events.isEmpty {
        Text("No scheduled tasks")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(Color.black.opacity(0.38))
          .offset(x: 60, y: 88)
      }

      ForEach(events) { event in
        NativeTodoCalendarEventCard(event: event)
          .frame(width: event.lane == 3 ? 55 : 54, height: max(78, event.duration * hourHeight))
          .offset(
            x: 58 + CGFloat(event.lane) * 56,
            y: (event.startHour - timelineStart) * hourHeight + 8
          )
      }

      if !events.isEmpty {
        HStack(spacing: 9) {
          ForEach(events.prefix(2)) { event in
            Text(event.title.replacingOccurrences(of: "\n", with: " "))
          }
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.white)
        .padding(.leading, 58)
        .offset(y: (19 - timelineStart) * hourHeight - 20)
      }
    }
  }
}

private struct NativeTodoCalendarEventCard: View {
  var event: NativeCalendarEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(event.title)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(.white)
        .lineLimit(3)

      Text(event.accent)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(.green)
        .lineLimit(2)

      Spacer()

      Text(event.timeText)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(.white.opacity(0.82))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 11)
    .background(
      LinearGradient(
        colors: [
          Color(red: 0.23, green: 0.24, blue: 0.25),
          Color(red: 0.16, green: 0.17, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 14)
  }
}

private struct NativeTodoEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  var selectedDate: Date

  @State private var title = ""
  @State private var note = ""
  @State private var dueDate: Date

  init(selectedDate: Date) {
    self.selectedDate = selectedDate
    _dueDate = State(initialValue: NativeTodoEditorSheet.defaultDueDate(for: selectedDate))
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

        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
          .font(.system(size: 16, weight: .semibold))
          .tint(.black)

        Spacer()
      }
      .padding(22)
      .background(Color.white)
      .navigationTitle("Add Todo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.createTodo(title: title, note: note, dueDate: dueDate)
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private static func defaultDueDate(for selectedDate: Date) -> Date {
    Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: selectedDate) ?? selectedDate
  }
}
