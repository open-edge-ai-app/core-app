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

  func todoToolListReferenceDate(filter: String, targetDate: Date) -> Date {
    let calendar = Calendar.current
    switch filter {
    case "today":
      return Date()
    case "tomorrow":
      return calendar.date(byAdding: .day, value: 1, to: Date()) ?? targetDate
    default:
      return targetDate
    }
  }

  func todoToolListTitle(filter: String, targetDate: Date) -> String {
    switch filter {
    case "today":
      return "오늘 할 일"
    case "tomorrow":
      return "내일 할 일"
    case "overdue":
      return "기한 지난 할 일"
    case "date":
      return "\(todoToolReadableDate(targetDate)) 할 일"
    default:
      return "Todo 목록"
    }
  }

  func todoToolListSummary(filter: String, targetDate: Date, count: Int) -> String {
    switch filter {
    case "today":
      return "오늘은 할 일이 \(count)개 있어요."
    case "tomorrow":
      return "내일은 할 일이 \(count)개 있어요."
    case "overdue":
      return "기한 지난 할 일이 \(count)개 있어요."
    case "date":
      return "\(todoToolReadableDate(targetDate))에는 할 일이 \(count)개 있어요."
    default:
      return "Todo가 \(count)개 있어요."
    }
  }

  func todoToolSortKey(for item: NativeTodoItem, on occurrenceDate: Date) -> Double {
    let priorityOffset = item.isStarred ? -20_000_000_000 : 0
    let overdueOffset = item.isOverdue() ? -10_000_000_000 : 0
    return Double(priorityOffset + overdueOffset) + todoToolOccurrenceStartDate(for: item, on: occurrenceDate).timeIntervalSince1970
  }

  func todoToolReadableSummary(
    _ item: NativeTodoItem,
    index: Int,
    occurrenceDate: Date,
    showsDate: Bool
  ) -> String {
    let titlePrefix = item.isStarred ? "중요 · " : ""
    var lines = [
      "\(index). **\(titlePrefix)\(item.title)**"
    ]

    let metadata = todoToolReadableMetadata(for: item, on: occurrenceDate, showsDate: showsDate)
    if !metadata.isEmpty {
      lines.append("   \(metadata)")
    }

    let trimmedNote = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedNote.isEmpty {
      let note = NativePromptCompressor.clippedMessageBody(item.note, maxEstimatedTokens: 40)
      lines.append("   \(note)")
    }

    return lines.joined(separator: "\n")
  }

  func todoToolReadableMetadata(for item: NativeTodoItem, on occurrenceDate: Date, showsDate: Bool) -> String {
    var parts = [todoToolReadableTimeRange(for: item, on: occurrenceDate, showsDate: showsDate)]

    if item.isCompleted(on: occurrenceDate) {
      parts.append("완료")
    } else if item.isOverdue() {
      parts.append("기한 지남")
    }

    let labels = todoLabels
      .filter { item.labelIds.contains($0.id) }
      .map(\.title)
      .joined(separator: ", ")
    if !labels.isEmpty {
      parts.append(labels)
    }

    if item.recurrenceRule.isRepeating {
      parts.append(item.recurrenceRule.title)
    }

    return parts.joined(separator: " · ")
  }

  func todoToolReadableTimeRange(for item: NativeTodoItem, on occurrenceDate: Date, showsDate: Bool) -> String {
    let startDate = todoToolOccurrenceStartDate(for: item, on: occurrenceDate)
    let endDate = Calendar.current.date(
      byAdding: .minute,
      value: Int((item.durationHours * 60).rounded()),
      to: startDate
    ) ?? todoEndDate(for: item)

    let prefix = showsDate ? "\(todoToolReadableDate(startDate)) " : ""
    return "\(prefix)\(todoToolReadableTimeRangeText(startDate: startDate, endDate: endDate))"
  }

  func todoToolOccurrenceStartDate(for item: NativeTodoItem, on occurrenceDate: Date) -> Date {
    let calendar = Calendar.current
    let baseDate = item.occurs(on: occurrenceDate) ? occurrenceDate : item.dueDate
    let hour = Int(floor(item.startHour))
    let minute = Int(round((item.startHour - Double(hour)) * 60))
    return calendar.date(
      bySettingHour: min(max(hour, 0), 23),
      minute: min(max(minute, 0), 59),
      second: 0,
      of: baseDate
    ) ?? todoStartDate(for: item)
  }

  func todoToolReadableDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "오늘"
    }
    if calendar.isDateInTomorrow(date) {
      return "내일"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: selectedLanguage == .korean ? "ko_KR" : "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = selectedLanguage == .korean ? "M월 d일 EEEE" : "MMM d, EEEE"
    return formatter.string(from: date)
  }

  func todoToolReadableTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: selectedLanguage == .korean ? "ko_KR" : "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = selectedLanguage == .korean ? "a h:mm" : "h:mm a"
    return formatter.string(from: date)
  }

  func todoToolReadableTimeRangeText(startDate: Date, endDate: Date) -> String {
    guard Calendar.current.isDate(startDate, inSameDayAs: endDate) else {
      return "\(todoToolReadableTime(startDate))-\(todoToolReadableTime(endDate))"
    }

    if selectedLanguage == .korean {
      let periodFormatter = DateFormatter()
      periodFormatter.locale = Locale(identifier: "ko_KR")
      periodFormatter.timeZone = .current
      periodFormatter.dateFormat = "a"

      let startPeriod = periodFormatter.string(from: startDate)
      let endPeriod = periodFormatter.string(from: endDate)
      if startPeriod == endPeriod {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ko_KR")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "h:mm"
        return "\(startPeriod) \(timeFormatter.string(from: startDate))-\(timeFormatter.string(from: endDate))"
      }
    }

    return "\(todoToolReadableTime(startDate))-\(todoToolReadableTime(endDate))"
  }
}
