import Foundation
import EventKit
import UIKit

@MainActor
extension NativeChatStore {
  func syncTodoItemsToCalendarIfNeeded() {
    guard todoCalendarSyncEnabled else {
      return
    }
    syncTodoItemsToCalendar()
  }

  func deleteTodoCalendarEventIfNeeded(identifier: String?) {
    guard todoCalendarSyncEnabled,
          todoCalendarAuthorizationState.canSync,
          let identifier,
          let event = todoEventStore.event(withIdentifier: identifier)
    else {
      return
    }

    do {
      try todoEventStore.remove(event, span: .futureEvents, commit: true)
    } catch {
      todoCalendarSyncMessage = error.localizedDescription
    }
  }

  func calendarEvent(for item: NativeTodoItem) -> EKEvent {
    if let identifier = item.calendarEventIdentifier,
       let existingEvent = todoEventStore.event(withIdentifier: identifier) {
      return existingEvent
    }
    return EKEvent(eventStore: todoEventStore)
  }

  func openEdgeTodoCalendar() throws -> EKCalendar {
    if let identifier = UserDefaults.standard.string(forKey: todoCalendarIdentifierKey),
       let calendar = todoEventStore.calendar(withIdentifier: identifier) {
      return calendar
    }

    let calendar = EKCalendar(for: .event, eventStore: todoEventStore)
    calendar.title = "Kepler Todo"
    calendar.cgColor = UIColor.label.cgColor

    if let source = todoEventStore.defaultCalendarForNewEvents?.source
      ?? todoEventStore.sources.first(where: { $0.sourceType == .local })
      ?? todoEventStore.sources.first {
      calendar.source = source
    } else {
      throw NativeTodoCalendarSyncError.noCalendarSource
    }

    try todoEventStore.saveCalendar(calendar, commit: true)
    UserDefaults.standard.set(calendar.calendarIdentifier, forKey: todoCalendarIdentifierKey)
    return calendar
  }

  func todoStartDate(for item: NativeTodoItem) -> Date {
    todoDate(on: item.dueDate, timelineHour: item.startHour)
  }

  func todoEndDate(for item: NativeTodoItem) -> Date {
    let startDate = todoStartDate(for: item)
    let durationMinutes = Int((max(0.5, item.durationHours) * 60).rounded())
    return Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate)
      ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
      ?? startDate
  }

  func todoDate(on baseDate: Date, timelineHour: Double) -> Date {
    let boundedHour = min(max(timelineHour, 1), 23.5)
    var hour = Int(floor(boundedHour))
    var minute = Int(round((boundedHour - Double(hour)) * 60))
    if minute == 60 {
      hour += 1
      minute = 0
    }
    return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
  }

  func recurrenceRules(for item: NativeTodoItem) -> [EKRecurrenceRule]? {
    switch item.recurrenceRule {
    case .none:
      return nil
    case .daily:
      return [EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)]
    case .weekdays:
      let weekdays = [
        EKRecurrenceDayOfWeek(.monday),
        EKRecurrenceDayOfWeek(.tuesday),
        EKRecurrenceDayOfWeek(.wednesday),
        EKRecurrenceDayOfWeek(.thursday),
        EKRecurrenceDayOfWeek(.friday)
      ]
      return [
        EKRecurrenceRule(
          recurrenceWith: .weekly,
          interval: 1,
          daysOfTheWeek: weekdays,
          daysOfTheMonth: nil,
          monthsOfTheYear: nil,
          weeksOfTheYear: nil,
          daysOfTheYear: nil,
          setPositions: nil,
          end: nil
        )
      ]
    case .weekly:
      return [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)]
    case .monthly:
      return [EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)]
    }
  }

}
