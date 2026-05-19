import Foundation

struct NativeTodoSubtask: Identifiable, Codable, Equatable, Hashable {
  var id: String
  var title: String
  var isComplete: Bool

  init(id: String = UUID().uuidString, title: String, isComplete: Bool = false) {
    self.id = id
    self.title = title
    self.isComplete = isComplete
  }
}

enum NativeTodoRepeatRule: String, CaseIterable, Codable, Identifiable, Hashable {
  case none
  case daily
  case weekdays
  case weekly
  case monthly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .none:
      return "반복 없음"
    case .daily:
      return "매일"
    case .weekdays:
      return "평일"
    case .weekly:
      return "매주"
    case .monthly:
      return "매월"
    }
  }

  var isRepeating: Bool {
    self != .none
  }
}

struct NativeTodoLabel: Identifiable, Codable, Equatable, Hashable {
  var id: String
  var title: String
  var colorHex: String
  var createdAt: Date

  init(
    id: String = UUID().uuidString,
    title: String,
    colorHex: String = NativeTodoLabel.defaultColors[0],
    createdAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.colorHex = colorHex
    self.createdAt = createdAt
  }

  static let defaultColors = [
    "#111111",
    "#FF3B30",
    "#007AFF",
    "#34C759",
    "#FF9500",
    "#AF52DE"
  ]
}

enum NativeTodoCalendarAuthorizationState: String, Equatable {
  case notDetermined
  case denied
  case restricted
  case writeOnly
  case fullAccess
  case unknown

  var title: String {
    switch self {
    case .notDetermined:
      return "권한 필요"
    case .denied:
      return "권한 거부됨"
    case .restricted:
      return "제한됨"
    case .writeOnly:
      return "쓰기 권한"
    case .fullAccess:
      return "연동됨"
    case .unknown:
      return "확인 필요"
    }
  }

  var canSync: Bool {
    self == .fullAccess || self == .writeOnly
  }
}

struct NativeTodoItem: Identifiable, Codable, Equatable, Hashable {
  var id: String
  var title: String
  var note: String
  var dueDate: Date
  var isStarred: Bool
  var isCompleted: Bool
  var subtasks: [NativeTodoSubtask]
  var createdAt: Date
  var updatedAt: Date
  var startHour: Double
  var durationHours: Double
  var repeatRule: NativeTodoRepeatRule?
  var calendarEventIdentifier: String?

  init(
    id: String = UUID().uuidString,
    title: String,
    note: String = "",
    dueDate: Date,
    isStarred: Bool = false,
    isCompleted: Bool = false,
    subtasks: [NativeTodoSubtask] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    startHour: Double = 13,
    durationHours: Double = 2,
    repeatRule: NativeTodoRepeatRule = .none,
    calendarEventIdentifier: String? = nil
  ) {
    self.id = id
    self.title = title
    self.note = note
    self.dueDate = dueDate
    self.isStarred = isStarred
    self.isCompleted = isCompleted
    self.subtasks = subtasks
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.startHour = startHour
    self.durationHours = durationHours
    self.repeatRule = repeatRule.isRepeating ? repeatRule : nil
    self.calendarEventIdentifier = calendarEventIdentifier
  }

  var recurrenceRule: NativeTodoRepeatRule {
    repeatRule ?? .none
  }

  func isOverdue(relativeTo date: Date = Date(), calendar: Calendar = .current) -> Bool {
    guard recurrenceRule == .none else {
      return false
    }
    return !isCompleted && calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: date)
  }

  func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
    let targetDay = calendar.startOfDay(for: date)
    let anchorDay = calendar.startOfDay(for: dueDate)
    guard targetDay >= anchorDay else {
      return false
    }

    switch recurrenceRule {
    case .none:
      return calendar.isDate(dueDate, inSameDayAs: date)
    case .daily:
      return true
    case .weekdays:
      let weekday = calendar.component(.weekday, from: targetDay)
      return weekday >= 2 && weekday <= 6
    case .weekly:
      return calendar.component(.weekday, from: targetDay) == calendar.component(.weekday, from: anchorDay)
    case .monthly:
      return calendar.component(.day, from: targetDay) == calendar.component(.day, from: anchorDay)
    }
  }

  func dueLabel(relativeTo date: Date = Date(), calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(dueDate) {
      return "Today"
    }
    if calendar.isDateInYesterday(dueDate) {
      return "Yesterday"
    }
    if calendar.isDateInTomorrow(dueDate) {
      return "Tomorrow"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = calendar.component(.year, from: dueDate) == calendar.component(.year, from: date)
      ? "MMM d"
      : "MMM d, yyyy"
    return formatter.string(from: dueDate)
  }

  static func seedItems(now: Date = Date(), calendar: Calendar = .current) -> [NativeTodoItem] {
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today) ?? today
    let afternoon = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today

    return [
      NativeTodoItem(
        title: "Call Jason",
        dueDate: yesterday,
        startHour: 11,
        durationHours: 1
      ),
      NativeTodoItem(
        title: "Email Back Mrs James",
        note: "Email Mrs. James for the new intern we have next week from Alex Carter, a marketing student from Brookfield University. Confirm their start date, schedule, and onboarding needs.",
        dueDate: evening,
        isStarred: true,
        startHour: 19,
        durationHours: 1
      ),
      NativeTodoItem(
        title: "New Design System",
        dueDate: afternoon,
        subtasks: [
          NativeTodoSubtask(title: "Update the UI system with a modern, cohesive design.", isComplete: true),
          NativeTodoSubtask(title: "Focus on consistency, scalability, and accessibility."),
          NativeTodoSubtask(title: "Use clean aesthetics with reusable, responsive components."),
          NativeTodoSubtask(title: "Enhance usability for a seamless user experience."),
          NativeTodoSubtask(title: "Streamline development with clear design guidelines.")
        ],
        startHour: 13,
        durationHours: 4
      )
    ]
  }
}
