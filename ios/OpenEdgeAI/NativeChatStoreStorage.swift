import Foundation

@MainActor
extension NativeChatStore {
  func mutateSession(
    _ id: String,
    persist: Bool = true,
    resort: Bool = true,
    _ mutation: (inout NativeChatSession) -> Void
  ) {
    guard let index = sessions.firstIndex(where: { $0.id == id }) else {
      return
    }

    objectWillChange.send()
    mutation(&sessions[index])
    sessions[index].updatedAt = Date()
    sessionMutationRevision &+= 1
    if resort {
      sessions.sort { $0.updatedAt > $1.updatedAt }
    }
    if persist {
      saveSessions()
    }
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
    todoHideCompletedTasks = boolSetting(data["todoHideCompletedTasks"], default: true)
    todoTagsVisibleOnTaskCards = boolSetting(data["todoTagsVisibleOnTaskCards"], default: false)
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
