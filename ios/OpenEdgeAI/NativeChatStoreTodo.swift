import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
extension NativeChatStore {
  func createTodo(
    title: String,
    note: String,
    startDate: Date,
    endDate: Date,
    repeatRule: NativeTodoRepeatRule,
    labelIds: [String] = []
  ) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }

    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let schedule = todoSchedule(startDate: startDate, endDate: endDate)
    let item = NativeTodoItem(
      title: trimmedTitle,
      note: trimmedNote,
      dueDate: startDate,
      startHour: schedule.startHour,
      durationHours: schedule.durationHours,
      repeatRule: repeatRule,
      labelIds: labelIds
    )

    todoItems.insert(item, at: 0)
    sortTodoItems()
    saveTodoItems()
    syncTodoItemsToCalendarIfNeeded()
  }

  func updateTodo(
    _ item: NativeTodoItem,
    title: String,
    note: String,
    startDate: Date,
    endDate: Date,
    repeatRule: NativeTodoRepeatRule,
    labelIds: [String] = []
  ) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }

    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let schedule = todoSchedule(startDate: startDate, endDate: endDate)

    mutateTodoItem(item.id) { todo in
      todo.title = trimmedTitle
      todo.note = trimmedNote
      todo.dueDate = startDate
      todo.startHour = schedule.startHour
      todo.durationHours = schedule.durationHours
      todo.repeatRule = repeatRule.isRepeating ? repeatRule : nil
      todo.setLabelIds(labelIds)
    }
    syncTodoItemsToCalendarIfNeeded()
  }

  func todoSchedule(startDate: Date, endDate: Date) -> (startHour: Double, durationHours: Double) {
    let startHour = snappedTimelineHour(from: startDate, relativeTo: startDate, upperBound: 23.5)
    let endHour = snappedTimelineHour(from: endDate, relativeTo: startDate, upperBound: 24)
    let duration = min(max(0.5, endHour - startHour), max(0.5, 24 - startHour))
    return (startHour, duration)
  }

  func snappedTimelineHour(from date: Date, relativeTo startDate: Date, upperBound: Double) -> Double {
    let calendar = Calendar.current
    if date > startDate && !calendar.isDate(date, inSameDayAs: startDate) {
      return upperBound
    }

    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let roundedMinute: Double
    if minute < 15 {
      roundedMinute = 0
    } else if minute < 45 {
      roundedMinute = 0.5
    } else {
      roundedMinute = 1
    }

    return min(max(Double(hour) + roundedMinute, 1), upperBound)
  }

  func toggleTodoCompletion(_ item: NativeTodoItem, occurrenceDate: Date? = nil) {
    mutateTodoItem(item.id) { todo in
      todo.toggleCompletion(on: occurrenceDate ?? item.dueDate)
    }
  }

  func toggleTodoStar(_ item: NativeTodoItem) {
    mutateTodoItem(item.id) { todo in
      todo.isStarred.toggle()
    }
  }

  func toggleTodoLabel(_ item: NativeTodoItem, label: NativeTodoLabel) {
    mutateTodoItem(item.id) { todo in
      todo.toggleLabel(label)
    }
  }

  func setTodoHideCompletedTasks(_ hidden: Bool) {
    todoHideCompletedTasks = hidden
    saveSettings()
  }

  func setTodoTagsVisibleOnTaskCards(_ visible: Bool) {
    todoTagsVisibleOnTaskCards = visible
    saveSettings()
  }

  func toggleTodoSubtask(todoId: String, subtaskId: String) {
    mutateTodoItem(todoId) { todo in
      guard let index = todo.subtasks.firstIndex(where: { $0.id == subtaskId }) else {
        return
      }
      todo.subtasks[index].isComplete.toggle()
    }
  }

  func deleteTodo(_ item: NativeTodoItem) {
    todoItems.removeAll { $0.id == item.id }
    saveTodoItems()
    deleteTodoCalendarEventIfNeeded(identifier: item.calendarEventIdentifier)
  }

  func createTodoLabel(title: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }

    let color = NativeTodoLabel.defaultColors[todoLabels.count % NativeTodoLabel.defaultColors.count]
    let label = NativeTodoLabel(title: trimmedTitle, colorHex: color)
    todoLabels.insert(label, at: 0)
    saveTodoLabels()
  }

  func deleteTodoLabel(_ label: NativeTodoLabel) {
    todoLabels.removeAll { $0.id == label.id }
    for index in todoItems.indices {
      todoItems[index].labelIds.removeAll { $0 == label.id }
    }
    saveTodoLabels()
    saveTodoItems()
  }

  func refreshTodoCalendarAuthorizationState() {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .notDetermined:
      todoCalendarAuthorizationState = .notDetermined
    case .restricted:
      todoCalendarAuthorizationState = .restricted
    case .denied:
      todoCalendarAuthorizationState = .denied
    case .authorized, .fullAccess:
      todoCalendarAuthorizationState = .fullAccess
    case .writeOnly:
      todoCalendarAuthorizationState = .writeOnly
    @unknown default:
      todoCalendarAuthorizationState = .unknown
    }
  }

  func setTodoCalendarSyncEnabled(_ enabled: Bool) {
    if enabled && !todoCalendarAuthorizationState.canSync {
      requestTodoCalendarAccess()
      return
    }

    todoCalendarSyncEnabled = enabled
    saveSettings()
    if enabled {
      syncTodoItemsToCalendar()
    }
  }

  func requestTodoCalendarAccess() {
    todoCalendarSyncMessage = nil
    todoEventStore.requestFullAccessToEvents { [weak self] granted, error in
      Task { @MainActor in
        guard let self else {
          return
        }

        self.refreshTodoCalendarAuthorizationState()

        if granted {
          self.todoCalendarSyncEnabled = true
          self.saveSettings()
          self.syncTodoItemsToCalendar()
        } else {
          self.todoCalendarSyncEnabled = false
          self.saveSettings()
          self.todoCalendarSyncMessage = error?.localizedDescription ?? self.i18n.t(.todoNoCalendarPermission)
        }
      }
    }
  }

  func syncTodoItemsToCalendar() {
    refreshTodoCalendarAuthorizationState()
    guard todoCalendarAuthorizationState.canSync else {
      todoCalendarSyncMessage = i18n.t(.todoAllowCalendarFirst)
      return
    }

    do {
      let calendar = try openEdgeTodoCalendar()
      var syncedCount = 0

      for index in todoItems.indices where !todoItems[index].isCompleted {
        let item = todoItems[index]
        let event = calendarEvent(for: item)
        event.calendar = calendar
        event.title = item.title
        event.notes = item.note.isEmpty ? nil : item.note
        event.startDate = todoStartDate(for: item)
        event.endDate = todoEndDate(for: item)
        event.recurrenceRules = recurrenceRules(for: item)
        try todoEventStore.save(event, span: .futureEvents, commit: true)
        todoItems[index].calendarEventIdentifier = event.eventIdentifier
        syncedCount += 1
      }

      saveTodoItems()
      todoCalendarSyncMessage = syncedCount == 0
        ? i18n.t(.todoNothingToSync)
        : i18n.t(.todoSyncedCount, ["count": String(syncedCount)])
    } catch {
      todoCalendarSyncMessage = error.localizedDescription
    }
  }
}
