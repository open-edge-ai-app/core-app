import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
extension NativeChatStore {
  func mutateSession(_ id: String, _ mutation: (inout NativeChatSession) -> Void) {
    guard let index = sessions.firstIndex(where: { $0.id == id }) else {
      return
    }

    objectWillChange.send()
    mutation(&sessions[index])
    sessions[index].updatedAt = Date()
    sessions.sort { $0.updatedAt > $1.updatedAt }
    saveSessions()
  }

  func mutateTodoItem(_ id: String, _ mutation: (inout NativeTodoItem) -> Void) {
    guard let index = todoItems.firstIndex(where: { $0.id == id }) else {
      return
    }

    objectWillChange.send()
    mutation(&todoItems[index])
    todoItems[index].updatedAt = Date()
    sortTodoItems()
    saveTodoItems()
  }

  func sortTodoItems() {
    todoItems.sort { left, right in
      if left.isCompleted != right.isCompleted {
        return !left.isCompleted
      }
      if left.dueDate != right.dueDate {
        return left.dueDate < right.dueDate
      }
      return left.updatedAt > right.updatedAt
    }
  }

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
    calendar.title = "Open Edge AI Todo"
    calendar.cgColor = UIColor.black.cgColor

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

  func pruneEmptyDraftSessions(keeping keptSessionId: String? = nil) {
    sessions.removeAll { session in
      session.id != keptSessionId && !sessionHasContent(session)
    }

    if let selectedSessionId,
       sessions.contains(where: { $0.id == selectedSessionId }) == false {
      self.selectedSessionId = sessions.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }
  }

  func sessionHasContent(_ session: NativeChatSession) -> Bool {
    session.messages.contains { message in
      let hasText = !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return hasText || !message.attachments.isEmpty
    }
  }

  func makeAttachment(from url: URL) -> NativeAttachment? {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let values = try? url.resourceValues(forKeys: [.nameKey, .fileSizeKey, .typeIdentifierKey])
    let name = values?.name?.isEmpty == false ? values!.name! : url.lastPathComponent
    let mime = mimeType(fileName: name, typeIdentifier: values?.typeIdentifier)
    let storedURL = persistAttachmentFile(from: url, suggestedName: name) ?? url
    let storedValues = try? storedURL.resourceValues(forKeys: [.fileSizeKey])
    return makeAttachment(
      displayName: name.isEmpty ? "첨부 파일" : name,
      mimeType: mime,
      sizeBytes: storedValues?.fileSize.map(Int64.init) ?? values?.fileSize.map(Int64.init),
      url: storedURL
    )
  }

  func makeAttachment(displayName: String, mimeType: String, sizeBytes: Int64?, url: URL) -> NativeAttachment {
    return NativeAttachment(
      id: UUID().uuidString,
      name: displayName.isEmpty ? "첨부 파일" : displayName,
      type: attachmentType(mimeType: mimeType, fileName: displayName),
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      url: url.absoluteString
    )
  }

  func persistAttachmentData(_ data: Data, fileName: String) -> URL? {
    guard let destination = uniqueAttachmentURL(for: fileName) else {
      return nil
    }

    do {
      try data.write(to: destination, options: [.atomic])
      return destination
    } catch {
      return nil
    }
  }

  func persistAttachmentFile(from sourceURL: URL, suggestedName: String) -> URL? {
    guard sourceURL.isFileURL,
          let destination = uniqueAttachmentURL(for: suggestedName.isEmpty ? sourceURL.lastPathComponent : suggestedName)
    else {
      return nil
    }

    do {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
      return destination
    } catch {
      return nil
    }
  }

  func uniqueAttachmentURL(for fileName: String) -> URL? {
    guard let directory = attachmentStorageDirectory() else {
      return nil
    }

    let sanitizedName = Self.sanitizedAttachmentFileName(fileName)
    return directory.appendingPathComponent("\(UUID().uuidString)-\(sanitizedName)", isDirectory: false)
  }

  func attachmentStorageDirectory() -> URL? {
    guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }

    let directory = baseURL.appendingPathComponent("Attachments", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
    } catch {
      return nil
    }
  }

  private static func sanitizedAttachmentFileName(_ fileName: String) -> String {
    let fallbackName = "attachment"
    let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate = trimmed.isEmpty ? fallbackName : trimmed
    let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
      .union(.newlines)
      .union(.controlCharacters)
    let parts = candidate.components(separatedBy: invalidCharacters).filter { !$0.isEmpty }
    let sanitized = parts.joined(separator: "-")
    return sanitized.isEmpty ? fallbackName : sanitized
  }

  static func attachmentTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return formatter.string(from: Date())
  }

  func attachmentType(mimeType: String, fileName: String) -> String {
    let lower = fileName.lowercased()
    if mimeType.hasPrefix("image/") || lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
      return "image"
    }
    if mimeType.hasPrefix("audio/") {
      return "audio"
    }
    if mimeType.hasPrefix("video/") {
      return "video"
    }
    return "document"
  }

  func mimeType(fileName: String, typeIdentifier: String?) -> String {
    if let typeIdentifier,
       let type = UTType(typeIdentifier),
       let mime = type.preferredMIMEType {
      return mime
    }

    let lower = fileName.lowercased()
    if lower.hasSuffix(".pdf") { return "application/pdf" }
    if lower.hasSuffix(".json") { return "application/json" }
    if lower.hasSuffix(".png") { return "image/png" }
    if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return "image/jpeg" }
    if lower.hasSuffix(".heic") { return "image/heic" }
    if lower.hasSuffix(".mp3") { return "audio/mpeg" }
    if lower.hasSuffix(".wav") { return "audio/wav" }
    if lower.hasSuffix(".mp4") { return "video/mp4" }
    return "application/octet-stream"
  }

  func loadSessions() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([NativeChatSession].self, from: data)
    else {
      sessions = []
      return
    }
    sessions = decoded
      .filter(sessionHasContent)
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  func saveSessions() {
    let persistableSessions = sessions.filter(sessionHasContent)
    guard let data = try? JSONEncoder().encode(persistableSessions) else {
      return
    }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  func loadProjects() {
    guard let data = UserDefaults.standard.data(forKey: projectsStorageKey),
          let decoded = try? JSONDecoder().decode([NativeProject].self, from: data)
    else {
      projects = []
      return
    }
    projects = decoded.sorted { $0.createdAt > $1.createdAt }
  }

  func saveProjects() {
    guard let data = try? JSONEncoder().encode(projects) else {
      return
    }
    UserDefaults.standard.set(data, forKey: projectsStorageKey)
  }

  func loadTodoItems() {
    guard UserDefaults.standard.object(forKey: todoStorageKey) != nil else {
      todoItems = NativeTodoItem.seedItems()
      saveTodoItems()
      return
    }

    guard let data = UserDefaults.standard.data(forKey: todoStorageKey),
          let decoded = try? JSONDecoder().decode([NativeTodoItem].self, from: data)
    else {
      todoItems = []
      return
    }

    todoItems = decoded
    sortTodoItems()
  }

  func saveTodoItems() {
    guard let data = try? JSONEncoder().encode(todoItems) else {
      return
    }
    UserDefaults.standard.set(data, forKey: todoStorageKey)
  }

  func loadTodoLabels() {
    guard let data = UserDefaults.standard.data(forKey: todoLabelsStorageKey),
          let decoded = try? JSONDecoder().decode([NativeTodoLabel].self, from: data)
    else {
      todoLabels = []
      return
    }

    todoLabels = decoded.sorted { $0.createdAt > $1.createdAt }
  }

  func saveTodoLabels() {
    guard let data = try? JSONEncoder().encode(todoLabels) else {
      return
    }
    UserDefaults.standard.set(data, forKey: todoLabelsStorageKey)
  }

  func loadSettings() {
    let data = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
    let storedSettingsSchemaVersion = data["settingsSchemaVersion"] as? Int ?? 0
    systemPrompt = data["systemPrompt"] as? String ?? ""
    userName = data["userName"] as? String ?? ""
    personality = data["personality"] as? String ?? "Balanced"
    memoryEnabled = boolSetting(data["memoryEnabled"], default: true)
    if let raw = data["fontSize"] as? String,
       let setting = NativeFontSizeSetting(rawValue: raw) {
      fontSizeSetting = setting
    }
    if let raw = data["appearanceMode"] as? String,
       let mode = NativeAppearanceMode(rawValue: raw) {
      appearanceMode = mode
    }
    if let raw = data["accentColor"] as? String,
       let color = NativeAccentColor(rawValue: raw) {
      accentColor = color
    }
    if let raw = data["selectedLanguage"] as? String,
       let language = NativeLanguage(rawValue: raw) {
      selectedLanguage = language
    }
    backgroundExecutionEnabled = boolSetting(data["backgroundExecutionEnabled"], default: false)
    backgroundDynamicIslandEnabled = boolSetting(data["backgroundDynamicIslandEnabled"], default: true)
    todoCalendarSyncEnabled = boolSetting(data["todoCalendarSyncEnabled"], default: false)
    if storedSettingsSchemaVersion < currentSettingsSchemaVersion {
      backgroundDynamicIslandEnabled = true
    }
    dynamicIslandPetEnabled = boolSetting(data["dynamicIslandPetEnabled"], default: false)
    if !backgroundExecutionEnabled {
      backgroundDynamicIslandEnabled = false
      dynamicIslandPetEnabled = false
    } else if !backgroundDynamicIslandEnabled {
      dynamicIslandPetEnabled = false
    }
    if let raw = data["selectedDynamicIslandPet"] as? String,
       let pet = NativeDynamicIslandPet(rawValue: raw) {
      selectedDynamicIslandPet = pet
    } else if data["selectedDynamicIslandPet"] as? String == "codex" {
      selectedDynamicIslandPet = .orbit
    }
    if let raw = data["selectedModel"] as? String,
       let model = NativeModel(rawValue: raw) {
      selectedModel = model
    }
    if storedSettingsSchemaVersion < currentSettingsSchemaVersion {
      saveSettings()
    }
  }

  func makeLocalTitle(from text: String) -> String {
    let cleaned = text
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return "새 채팅"
    }
    return cleaned.count > 24 ? "\(cleaned.prefix(24))..." : cleaned
  }

  func scheduleNextQueuedDraft() {
    guard !queuedDrafts.isEmpty else {
      return
    }

    showDynamicIslandWork()

    if canRunBackgroundDynamicIsland {
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 450_000_000)
        self.runQueuedDraftIfReady()
      }
    } else {
      runQueuedDraftIfReady()
    }
  }

  func boolSetting(_ value: Any?, default defaultValue: Bool) -> Bool {
    if let value = value as? Bool {
      return value
    }
    if let value = value as? NSNumber {
      return value.boolValue
    }
    return defaultValue
  }
}
