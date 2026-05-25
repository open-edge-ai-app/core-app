import Foundation



struct NativeI18n {
  var language: NativeLanguage

  func t(_ key: NativeI18nKey, _ values: [String: String] = [:]) -> String {
    let message =
      Self.localizedMessages[language]?[key] ??
      Self.localizedMessages[.english]?[key] ??
      Self.localizedMessages[.korean]?[key] ??
      key.rawValue

    return values.reduce(message) { result, entry in
      result.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
    }
  }

  func locale() -> Locale {
    Locale(identifier: language.localeIdentifier)
  }

  func dateTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate("EEE dd MMMM")
    return formatter.string(from: date)
  }

  func shortDateTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate("MMM d")
    return formatter.string(from: date)
  }

  func weekdayLetter(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate("EEEEE")
    return formatter.string(from: date)
  }

  func dayNumber(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.dateFormat = "dd"
    return formatter.string(from: date)
  }

  func timelineHour(_ hour: Int) -> String {
    let hourText = String(format: "%02d", hour)
    return language == .korean ? "\(hourText)시" : "\(hourText):00"
  }

  func dueLabel(for date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(date) {
      return t(.todoToday)
    }
    if calendar.isDateInYesterday(date) {
      return t(.todoYesterday)
    }
    if calendar.isDateInTomorrow(date) {
      return t(.todoTomorrow)
    }

    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate(
      calendar.component(.year, from: date) == calendar.component(.year, from: referenceDate)
        ? "MMM d"
        : "MMM d yyyy"
    )
    return formatter.string(from: date)
  }
}

extension NativeChatStore {
  var i18n: NativeI18n {
    NativeI18n(language: selectedLanguage)
  }
}
