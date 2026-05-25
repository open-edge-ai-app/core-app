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
  var completedOccurrenceDayKeys: Set<String>
  var deletedOccurrenceDayKeys: Set<String>
  var labelIds: [String]

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
    calendarEventIdentifier: String? = nil,
    completedOccurrenceDayKeys: Set<String> = [],
    deletedOccurrenceDayKeys: Set<String> = [],
    labelIds: [String] = []
  ) {
    self.id = id
    self.title = title
    self.note = note
    self.dueDate = dueDate
    self.isStarred = isStarred
    self.isCompleted = repeatRule.isRepeating ? false : isCompleted
    self.subtasks = subtasks
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.startHour = startHour
    self.durationHours = durationHours
    self.repeatRule = repeatRule.isRepeating ? repeatRule : nil
    self.calendarEventIdentifier = calendarEventIdentifier
    self.completedOccurrenceDayKeys = completedOccurrenceDayKeys
    self.deletedOccurrenceDayKeys = deletedOccurrenceDayKeys
    self.labelIds = Self.uniqueLabelIds(labelIds)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case note
    case dueDate
    case isStarred
    case isCompleted
    case subtasks
    case createdAt
    case updatedAt
    case startHour
    case durationHours
    case repeatRule
    case calendarEventIdentifier
    case completedOccurrenceDayKeys
    case deletedOccurrenceDayKeys
    case labelIds
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    dueDate = try container.decode(Date.self, forKey: .dueDate)
    isStarred = try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
    let decodedIsCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    subtasks = try container.decodeIfPresent([NativeTodoSubtask].self, forKey: .subtasks) ?? []
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? dueDate
    updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    startHour = try container.decodeIfPresent(Double.self, forKey: .startHour) ?? 13
    durationHours = try container.decodeIfPresent(Double.self, forKey: .durationHours) ?? 2
    let decodedRepeatRule = try container.decodeIfPresent(NativeTodoRepeatRule.self, forKey: .repeatRule) ?? .none
    repeatRule = decodedRepeatRule.isRepeating ? decodedRepeatRule : nil
    isCompleted = decodedRepeatRule.isRepeating ? false : decodedIsCompleted
    calendarEventIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarEventIdentifier)
    completedOccurrenceDayKeys = try container.decodeIfPresent(Set<String>.self, forKey: .completedOccurrenceDayKeys) ?? []
    deletedOccurrenceDayKeys = try container.decodeIfPresent(Set<String>.self, forKey: .deletedOccurrenceDayKeys) ?? []
    labelIds = Self.uniqueLabelIds(try container.decodeIfPresent([String].self, forKey: .labelIds) ?? [])
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
    guard !isDeleted(on: date, calendar: calendar) else {
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

  func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
    guard recurrenceRule.isRepeating else {
      return isCompleted
    }
    return completedOccurrenceDayKeys.contains(Self.occurrenceDayKey(for: date, calendar: calendar))
  }

  func isVisible(on date: Date, calendar: Calendar = .current) -> Bool {
    occurs(on: date, calendar: calendar) && !isDeleted(on: date, calendar: calendar) && !isCompleted(on: date, calendar: calendar)
  }

  func isDeleted(on date: Date, calendar: Calendar = .current) -> Bool {
    guard recurrenceRule.isRepeating else {
      return false
    }
    return deletedOccurrenceDayKeys.contains(Self.occurrenceDayKey(for: date, calendar: calendar))
  }

  mutating func toggleCompletion(on date: Date, calendar: Calendar = .current) {
    guard recurrenceRule.isRepeating else {
      isCompleted.toggle()
      return
    }

    let key = Self.occurrenceDayKey(for: date, calendar: calendar)
    if completedOccurrenceDayKeys.contains(key) {
      completedOccurrenceDayKeys.remove(key)
    } else {
      completedOccurrenceDayKeys.insert(key)
    }
  }

  mutating func deleteOccurrence(on date: Date, calendar: Calendar = .current) {
    guard recurrenceRule.isRepeating else {
      isCompleted = true
      return
    }

    let key = Self.occurrenceDayKey(for: date, calendar: calendar)
    deletedOccurrenceDayKeys.insert(key)
    completedOccurrenceDayKeys.remove(key)
  }

  static func occurrenceDayKey(for date: Date, calendar: Calendar = .current) -> String {
    let day = calendar.startOfDay(for: date)
    let components = calendar.dateComponents([.year, .month, .day], from: day)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }

  mutating func setLabelIds(_ ids: [String]) {
    labelIds = Self.uniqueLabelIds(ids)
  }

  mutating func toggleLabel(_ label: NativeTodoLabel) {
    if labelIds.first == label.id {
      labelIds.removeAll()
    } else {
      labelIds = [label.id]
    }
  }

  private static func uniqueLabelIds(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    let uniqueIds = ids.filter { id in
      guard !id.isEmpty, !seen.contains(id) else {
        return false
      }
      seen.insert(id)
      return true
    }
    return Array(uniqueIds.prefix(1))
  }
}
