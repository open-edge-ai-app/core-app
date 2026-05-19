import Foundation

@MainActor
extension NativeChatStore {
  func todoToolDate(from raw: String?) -> Date? {
    guard let raw else {
      return nil
    }
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      return nil
    }

    let lowered = text.lowercased()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    if lowered == "today" || lowered == "오늘" {
      return defaultTodoToolStartDate(on: today)
    }
    if lowered == "tomorrow" || lowered == "내일" {
      let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
      return defaultTodoToolStartDate(on: tomorrow)
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: text) {
      return date
    }
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: text) {
      return date
    }

    let formats = [
      "yyyy-MM-dd HH:mm",
      "yyyy-MM-dd'T'HH:mm",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy/MM/dd HH:mm",
      "yyyy.MM.dd HH:mm",
      "yyyy-MM-dd",
      "yyyy/MM/dd",
      "yyyy.MM.dd"
    ]
    for format in formats {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = .current
      formatter.dateFormat = format
      if let date = formatter.date(from: text) {
        if format.hasSuffix("dd") {
          return defaultTodoToolStartDate(on: date)
        }
        return date
      }
    }
    return nil
  }

  func defaultTodoToolStartDate(on date: Date = Date()) -> Date {
    let calendar = Calendar.current
    let base = calendar.startOfDay(for: date)
    let now = Date()
    if calendar.isDate(base, inSameDayAs: now) {
      let rounded = calendar.date(
        byAdding: .minute,
        value: 30,
        to: now
      ) ?? now
      let components = calendar.dateComponents([.hour, .minute], from: rounded)
      let minute = (components.minute ?? 0) < 30 ? 30 : 0
      let hour = (components.minute ?? 0) < 30 ? (components.hour ?? 13) : min(23, (components.hour ?? 13) + 1)
      return calendar.date(bySettingHour: max(1, hour), minute: minute, second: 0, of: base) ?? rounded
    }
    return calendar.date(bySettingHour: 13, minute: 0, second: 0, of: base) ?? date
  }

  func todoToolRepeatRule(from raw: String?) -> NativeTodoRepeatRule? {
    guard let raw else {
      return nil
    }
    switch raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
    case "none", "no", "no repeat", "없음", "반복 없음":
      return NativeTodoRepeatRule.none
    case "daily", "day", "매일":
      return .daily
    case "weekdays", "weekday", "평일":
      return .weekdays
    case "weekly", "week", "매주":
      return .weekly
    case "monthly", "month", "매월":
      return .monthly
    default:
      return nil
    }
  }

  func todoToolDateTimeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: selectedLanguage == .korean ? "ko_KR" : "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
  }

  func todoToolSummary(_ item: NativeTodoItem) -> String {
    let status = item.isCompleted ? "완료" : "미완료"
    let labels = todoLabels
      .filter { item.labelIds.contains($0.id) }
      .map(\.title)
      .joined(separator: ", ")
    let labelText = labels.isEmpty ? "" : ", 태그: \(labels)"
    return "- \(item.title) (\(status), \(todoToolDateTimeText(todoStartDate(for: item)))\(labelText), id: \(item.id))"
  }
}
