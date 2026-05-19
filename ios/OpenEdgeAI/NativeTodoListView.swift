import SwiftUI

private enum NativeTodoTab {
  case all
  case calendar
}

private struct NativeTodoTask: Identifiable {
  let id = UUID()
  var title: String
  var note: String?
  var dueLabel: String
  var isOverdue: Bool = false
  var isStarred: Bool = false
  var subtasks: [NativeTodoSubtask] = []
}

private struct NativeTodoSubtask: Identifiable {
  let id = UUID()
  var title: String
  var isComplete: Bool
}

private struct NativeCalendarEvent: Identifiable {
  let id = UUID()
  var title: String
  var accent: String
  var startHour: CGFloat
  var duration: CGFloat
  var lane: Int
}

struct NativeTodoListView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedTab: NativeTodoTab = .all
  @State private var isOverdueExpanded = true
  @State private var isTodayExpanded = true

  private let tasks = [
    NativeTodoTask(
      title: "Call Jason",
      note: nil,
      dueLabel: "Yesterday",
      isOverdue: true
    ),
    NativeTodoTask(
      title: "Email Back Mrs James",
      note: "Email Mrs. James for the new intern we have next week from Alex Carter, a marketing student from Brookfield University. Confirm their start date, schedule, and onboarding needs.",
      dueLabel: "Today",
      isStarred: true
    ),
    NativeTodoTask(
      title: "New Design System",
      note: nil,
      dueLabel: "Today",
      subtasks: [
        NativeTodoSubtask(title: "Update the UI system with a modern, cohesive design.", isComplete: true),
        NativeTodoSubtask(title: "Focus on consistency, scalability, and accessibility.", isComplete: false),
        NativeTodoSubtask(title: "Use clean aesthetics with reusable, responsive components.", isComplete: false),
        NativeTodoSubtask(title: "Enhance usability for a seamless user experience.", isComplete: false),
        NativeTodoSubtask(title: "Streamline development with clear design guidelines.", isComplete: false)
      ]
    )
  ]

  private let events = [
    NativeCalendarEvent(title: "New\nDesign\nSystem", accent: "New-\nDesign", startHour: 13.0, duration: 4.0, lane: 0),
    NativeCalendarEvent(title: "New\nDesign\nSystem", accent: "New-\nDesign", startHour: 13.0, duration: 4.0, lane: 1),
    NativeCalendarEvent(title: "New\nDesign\nSystem", accent: "New-\nDesign", startHour: 13.0, duration: 4.0, lane: 2),
    NativeCalendarEvent(title: "New\nDesign\nSystem", accent: "New-\nDesign", startHour: 12.0, duration: 2.0, lane: 3)
  ]

  private var dateTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE dd, MMMM"
    return formatter.string(from: Date())
  }

  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMMM"
    return formatter.string(from: Date())
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
        } label: {
          Image(systemName: "slider.vertical.3")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.black)
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Todo 필터")
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 24)
    .padding(.bottom, 24)
  }

  private var tabSwitcher: some View {
    HStack(spacing: 12) {
      Button {
        selectedTab = .all
      } label: {
        Text("All")
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(selectedTab == .all ? .black : Color.black.opacity(0.52))
          .padding(.horizontal, 14)
          .frame(height: 42)
          .background(selectedTab == .all ? Color.black.opacity(0.06) : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      }
      .buttonStyle(.plain)

      Button {
        selectedTab = .calendar
      } label: {
        Text("Calendar")
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(selectedTab == .calendar ? .black : Color.black.opacity(0.52))
          .padding(.horizontal, 14)
          .frame(height: 42)
          .background(selectedTab == .calendar ? Color.black.opacity(0.06) : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      }
      .buttonStyle(.plain)

      Spacer()

      Image(systemName: "magnifyingglass")
        .font(.system(size: 25, weight: .regular))
        .foregroundColor(.black)
        .frame(width: 44, height: 42)
    }
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
          NativeTodoTaskCard(task: tasks[0])
        }

        NativeTodoSectionHeader(
          title: "Today",
          isExpanded: $isTodayExpanded
        )

        if isTodayExpanded {
          NativeTodoTaskCard(task: tasks[1])
          NativeTodoTaskCard(task: tasks[2])
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 22)
      .padding(.bottom, 120)
    }
  }

  private var calendarContent: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Button {
        } label: {
          Text("Week")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.blue.opacity(0.72))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)

        Button {
        } label: {
          Text("Day")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Color.black.opacity(0.62))
            .padding(.horizontal, 14)
            .frame(height: 42)
        }
        .buttonStyle(.plain)

        Spacer()

        Image(systemName: "magnifyingglass")
          .font(.system(size: 25, weight: .regular))
          .foregroundColor(.black)
          .frame(width: 44, height: 42)
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)

      NativeTodoWeekStrip()
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 10)

      ScrollView(showsIndicators: false) {
        NativeTodoTimeline(events: events)
          .frame(height: 720)
          .padding(.horizontal, 24)
          .padding(.bottom, 132)
      }
    }
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
        Image(systemName: "chevron.left")
          .font(.system(size: 19, weight: .semibold))
        Text(monthTitle)
          .font(.system(size: 16, weight: .bold))
        Image(systemName: "chevron.right")
          .font(.system(size: 19, weight: .semibold))
      }
      .foregroundColor(.black)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.white.opacity(0.96))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 10)

      Button {
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
    .padding(.horizontal, 24)
    .padding(.bottom, 24)
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
  var task: NativeTodoTask

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 14) {
        Circle()
          .stroke(Color.black.opacity(0.56), lineWidth: 2)
          .frame(width: 23, height: 23)
          .padding(.top, 2)

        VStack(alignment: .leading, spacing: 11) {
          HStack(alignment: .top) {
            Text(task.title)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.black)
              .lineLimit(2)

            Spacer()

            Image(systemName: task.subtasks.isEmpty ? "chevron.up" : "chevron.up")
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.52))
          }

          if let note = task.note {
            Text(note)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.52))
              .lineSpacing(4)
              .lineLimit(4)
          }

          HStack(spacing: 8) {
            Text(task.dueLabel)
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(task.isOverdue ? .red.opacity(0.78) : .red.opacity(0.64))

            Text("•")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(Color.black.opacity(0.28))

            Text("Tasks")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.42))

            Spacer()

            Image(systemName: task.isStarred ? "star.fill" : "star")
              .font(.system(size: 18, weight: .regular))
              .foregroundColor(task.isStarred ? .red.opacity(0.74) : Color.black.opacity(0.48))

            Image(systemName: task.isOverdue ? "calendar" : "alarm")
              .font(.system(size: 17, weight: .regular))
              .foregroundColor(Color.black.opacity(0.48))
          }
        }
      }

      if !task.subtasks.isEmpty {
        VStack(spacing: 0) {
          ForEach(task.subtasks) { subtask in
            HStack(alignment: .top, spacing: 14) {
              Image(systemName: subtask.isComplete ? "checkmark.circle" : "circle")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(Color.black.opacity(0.58))
                .padding(.top, 1)

              Text(subtask.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.black.opacity(0.68))
                .lineLimit(2)

              Spacer()
            }
            .padding(.leading, 46)
            .padding(.vertical, 12)

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
  }
}

private struct NativeTodoWeekStrip: View {
  private let days = [
    ("S", "17"),
    ("M", "18"),
    ("T", "19"),
    ("W", "20"),
    ("T", "21"),
    ("F", "22"),
    ("S", "23")
  ]

  var body: some View {
    HStack(spacing: 15) {
      Image(systemName: "chevron.left")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(Color.black.opacity(0.58))

      ForEach(days, id: \.1) { day in
        VStack(spacing: 3) {
          Text(day.0)
            .font(.system(size: 13, weight: .bold))
          Text(day.1)
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(day.1 == "19" ? .blue.opacity(0.76) : Color.black.opacity(0.60))
        .frame(width: 34, height: 52)
        .background(day.1 == "19" ? Color.black.opacity(0.07) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }

      Image(systemName: "chevron.right")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(Color.black.opacity(0.58))
    }
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

      ForEach(events) { event in
        NativeTodoCalendarEventCard(event: event)
          .frame(width: event.lane == 3 ? 55 : 54, height: max(78, event.duration * hourHeight))
          .offset(
            x: 58 + CGFloat(event.lane) * 56,
            y: (event.startHour - timelineStart) * hourHeight + 8
          )
      }

      HStack(spacing: 9) {
        Text("Continue Coding")
        Text("Email Back Mrs James")
      }
      .font(.system(size: 15, weight: .bold))
      .foregroundColor(.white)
      .padding(.leading, 58)
      .offset(y: (19 - timelineStart) * hourHeight - 20)
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

      Text("01PM -\n05PM")
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
