import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
final class NativeChatStore: ObservableObject {
  @Published var sessions: [NativeChatSession] = []
  @Published var projects: [NativeProject] = []
  @Published var todoItems: [NativeTodoItem] = []
  @Published var selectedSessionId: String?
  @Published var inputText = ""
  @Published var pendingAttachments: [NativeAttachment] = []
  @Published var queuedDrafts: [NativeDraft] = []
  @Published var selectedModel: NativeModel = .appleFoundation
  @Published var modelStatuses: [NativeModel: NativeModelStatus] = [:]
  @Published var isGenerating = false
  @Published var statusMessage: String?
  @Published var systemPrompt = ""
  @Published var userName = ""
  @Published var personality = "Balanced"
  @Published var memoryEnabled = true
  @Published var fontSizeSetting: NativeFontSizeSetting = .standard
  @Published var appearanceMode: NativeAppearanceMode = .light
  @Published var accentColor: NativeAccentColor = .black
  @Published var selectedLanguage: NativeLanguage = .korean
  @Published var backgroundExecutionEnabled = false
  @Published var backgroundDynamicIslandEnabled = true
  @Published var dynamicIslandPetEnabled = false
  @Published var selectedDynamicIslandPet: NativeDynamicIslandPet = .orbit
  @Published var localMemoryIndexedItems = 0

  private let storageKey = "OpenEdgeAI.NativeChatSessions.v1"
  private let projectsStorageKey = "OpenEdgeAI.NativeProjects.v1"
  private let todoStorageKey = "OpenEdgeAI.NativeTodoItems.v1"
  private let settingsKey = "OpenEdgeAI.NativeSettings.v1"
  private let currentSettingsSchemaVersion = 2
  let dynamicIslandActivityId = "open-edge-ai.live-generation"
  private var activeAssistantMessageId: String?
  @Published private var activeRequestSessionId: String?
  var generationBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  private var searchProgressTasks: [String: Task<Void, Never>] = [:]
  private let deviceContextProvider = NativeDeviceContextProvider()
  private let localKnowledgeStore = NativeLocalKnowledgeStore.shared
  private let searchFallbackRequestText = "현재 대화 내용을 기반으로 검색해서 내용을 개선해줘."

  init() {
    loadSettings()
    loadSessions()
    loadProjects()
    loadTodoItems()
    rebuildLocalMemoryIndex()

    if sessions.isEmpty {
      createNewSession()
    } else {
      selectedSessionId = sessions.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }

    modelStatuses = Dictionary(
      uniqueKeysWithValues: NativeModel.allCases.map { ($0, NativeModelStatus(model: $0)) }
    )

    Task {
      await refreshModelStatuses()
    }

    syncDynamicIslandLiveActivity()
  }

  var currentSession: NativeChatSession? {
    guard let selectedSessionId else {
      return nil
    }
    return sessions.first { $0.id == selectedSessionId }
  }

  var currentMessages: [NativeMessage] {
    currentSession?.messages ?? []
  }

  var activeWritingSessionId: String? {
    isGenerating ? activeRequestSessionId : nil
  }


  var canSend: Bool {
    !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
  }

  func shouldShowSession(_ session: NativeChatSession) -> Bool {
    sessionHasContent(session)
  }

  func createNewSession(projectId: String? = nil) {
    pruneEmptyDraftSessions()

    let now = Date()
    let session = NativeChatSession(
      id: UUID().uuidString,
      title: "새 채팅",
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
      messages: []
    )
    sessions.insert(session, at: 0)
    selectedSessionId = session.id
    inputText = ""
    pendingAttachments = []
    saveSessions()
  }

  func selectSession(_ session: NativeChatSession) {
    pruneEmptyDraftSessions(keeping: session.id)
    selectedSessionId = session.id
    inputText = ""
    pendingAttachments = []
    saveSessions()
  }

  func deleteSession(_ session: NativeChatSession) {
    sessions.removeAll { $0.id == session.id }
    if activeRequestSessionId == session.id {
      activeRequestSessionId = nil
    }
    if selectedSessionId == session.id {
      selectedSessionId = sessions.first?.id
    }
    if sessions.isEmpty {
      createNewSession()
    } else {
      saveSessions()
    }
  }

  func renameSession(id: String, title: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty,
          let index = sessions.firstIndex(where: { $0.id == id })
    else {
      return
    }

    sessions[index].title = trimmedTitle
    saveSessions()
  }

  func addSession(_ session: NativeChatSession, to project: NativeProject) {
    guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
      return
    }

    sessions[index].projectId = project.id
    sessions[index].updatedAt = Date()
    sessions.sort { $0.updatedAt > $1.updatedAt }
    saveSessions()
  }

  func createProject(title: String, iconName: String, systemPrompt: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }
    let selectedIconName = iconName.isEmpty ? NativeProjectIcon.defaultIcon.systemImage : iconName
    let trimmedSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

    let project = NativeProject(
      id: UUID().uuidString,
      title: trimmedTitle,
      iconName: selectedIconName,
      systemPrompt: trimmedSystemPrompt,
      createdAt: Date()
    )
    projects.insert(project, at: 0)
    saveProjects()
    rebuildLocalMemoryIndex()
  }

  func deleteProject(_ project: NativeProject) {
    let deletedSessionIds = Set(sessions.filter { $0.projectId == project.id }.map(\.id))
    projects.removeAll { $0.id == project.id }
    sessions.removeAll { $0.projectId == project.id }
    if let activeRequestSessionId, deletedSessionIds.contains(activeRequestSessionId) {
      self.activeRequestSessionId = nil
    }
    if let selectedSessionId,
       sessions.contains(where: { $0.id == selectedSessionId }) == false {
      self.selectedSessionId = sessions.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }
    if sessions.isEmpty {
      createNewSession()
    } else {
      saveSessions()
    }
    saveProjects()
    rebuildLocalMemoryIndex()
  }

  func updateProject(id: String, title: String, iconName: String, systemPrompt: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty,
          let index = projects.firstIndex(where: { $0.id == id })
    else {
      return
    }

    projects[index].title = trimmedTitle
    projects[index].iconName = iconName.isEmpty ? NativeProjectIcon.defaultIcon.systemImage : iconName
    projects[index].systemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    saveProjects()
    rebuildLocalMemoryIndex()
  }

  func createTodo(title: String, note: String, dueDate: Date) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }

    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let hour = Calendar.current.component(.hour, from: dueDate)
    let item = NativeTodoItem(
      title: trimmedTitle,
      note: trimmedNote,
      dueDate: dueDate,
      startHour: Double(max(8, min(20, hour))),
      durationHours: 1
    )

    todoItems.insert(item, at: 0)
    sortTodoItems()
    saveTodoItems()
  }

  func toggleTodoCompletion(_ item: NativeTodoItem) {
    mutateTodoItem(item.id) { todo in
      todo.isCompleted.toggle()
    }
  }

  func toggleTodoStar(_ item: NativeTodoItem) {
    mutateTodoItem(item.id) { todo in
      todo.isStarred.toggle()
    }
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
  }

  func sendCurrentInput() {
    let draftInput = makeDraftInput(from: inputText)
    guard !draftInput.text.isEmpty || !pendingAttachments.isEmpty else {
      return
    }

    let draft = NativeDraft(
      id: UUID().uuidString,
      text: draftInput.text,
      attachments: pendingAttachments,
      createdAt: Date(),
      mode: draftInput.mode
    )

    inputText = ""
    pendingAttachments = []

    if isGenerating {
      queuedDrafts.append(draft)
      showDynamicIslandWork()
      return
    }

    send(draft)
  }

  func sendCurrentInput(projectId: String) {
    selectProjectSessionForInput(projectId: projectId)
    sendCurrentInput()
  }

  func removeQueuedDraft(_ draft: NativeDraft) {
    queuedDrafts.removeAll { $0.id == draft.id }
    syncDynamicIslandLiveActivity()
  }

  func updateQueuedDraft(_ draft: NativeDraft, text: String) {
    guard let index = queuedDrafts.firstIndex(where: { $0.id == draft.id }) else {
      return
    }
    queuedDrafts[index].text = text
    syncDynamicIslandLiveActivity()
  }

  func runQueuedDraftIfReady() {
    guard !isGenerating, !queuedDrafts.isEmpty else {
      return
    }
    let next = queuedDrafts.removeFirst()
    send(next)
  }

  private func selectProjectSessionForInput(projectId: String) {
    if let selectedSessionId,
       sessions.first(where: { $0.id == selectedSessionId })?.projectId == projectId {
      return
    }

    if let existingSession = sessions
      .filter({ $0.projectId == projectId && sessionHasContent($0) })
      .sorted(by: { $0.updatedAt > $1.updatedAt })
      .first {
      selectedSessionId = existingSession.id
      return
    }

    let currentInput = inputText
    let currentAttachments = pendingAttachments
    createNewSession(projectId: projectId)
    inputText = currentInput
    pendingAttachments = currentAttachments
  }

  func retry(message: NativeMessage) {
    guard !isGenerating,
          let session = currentSession,
          let assistantIndex = session.messages.firstIndex(where: { $0.id == message.id }),
          session.messages[assistantIndex].role == .assistant
    else {
      return
    }

    let previousUser = session.messages[..<assistantIndex]
      .last { $0.role == .user }

    guard let previousUser else {
      return
    }

    let draft = NativeDraft(
      id: UUID().uuidString,
      text: previousUser.text,
      attachments: previousUser.attachments,
      createdAt: Date(),
      mode: message.sourceReferences.isEmpty ? .standard : .search
    )
    let historyMessages = Array(session.messages[..<assistantIndex])

    rewrite(draft, replacingAssistantId: message.id, in: session.id, historyMessages: historyMessages)
  }

  func cancelGeneration() {
    let appleCancelled = AIEngineFoundationModelClient.shared.cancelActiveGeneration()
    let gemmaCancelled = AIEngineGemmaModelClient.shared.cancelActiveGeneration()

    if let activeRequestSessionId, let activeAssistantMessageId {
      stopSearchProgress(for: activeAssistantMessageId, in: activeRequestSessionId, clearMessage: false)
      mutateSession(activeRequestSessionId) { session in
        if let index = session.messages.firstIndex(where: { $0.id == activeAssistantMessageId }),
           session.messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          session.messages[index].text = "응답 생성이 중지되었습니다."
        } else if let index = session.messages.firstIndex(where: { $0.id == activeAssistantMessageId }),
                  isSearchProgressText(session.messages[index].text) {
          session.messages[index].text = "검색이 중지되었습니다."
        }
      }
    }

    isGenerating = false
    activeAssistantMessageId = nil
    activeRequestSessionId = nil
    endGenerationBackgroundTaskIfNeeded()
    if queuedDrafts.isEmpty {
      syncDynamicIslandLiveActivity()
    } else {
      showDynamicIslandWork()
    }
    statusMessage = appleCancelled || gemmaCancelled ? "응답을 중지했습니다." : nil
  }

  func addAttachments(from urls: [URL]) {
    let newAttachments = urls.compactMap(makeAttachment)
    pendingAttachments.append(contentsOf: newAttachments)
  }

  func addPhotoAttachments(from items: [PhotosPickerItem]) async {
    var newAttachments: [NativeAttachment] = []

    for item in items {
      guard let data = try? await item.loadTransferable(type: Data.self) else {
        continue
      }

      let contentType = item.supportedContentTypes.first ?? .image
      let fileExtension = contentType.preferredFilenameExtension
        ?? (contentType.conforms(to: .movie) ? "mov" : "jpg")
      let fileName = "Photo-\(Self.attachmentTimestamp()).\(fileExtension)"
      guard let url = persistAttachmentData(data, fileName: fileName) else {
        continue
      }

      newAttachments.append(
        makeAttachment(
          displayName: fileName,
          mimeType: contentType.preferredMIMEType ?? mimeType(fileName: fileName, typeIdentifier: contentType.identifier),
          sizeBytes: Int64(data.count),
          url: url
        )
      )
    }

    pendingAttachments.append(contentsOf: newAttachments)
  }

  func removePendingAttachment(_ attachment: NativeAttachment) {
    pendingAttachments.removeAll { $0.id == attachment.id }
  }

  func copy(_ text: String) {
    UIPasteboard.general.string = text
    statusMessage = "복사했습니다."
  }

  func refreshModelStatuses() async {
    let apple = NativeModelStatus(
      model: .appleFoundation,
      dictionary: AIEngineFoundationModelClient.shared.modelStatus()
    )
    let gemma = NativeModelStatus(
      model: .gemma,
      dictionary: AIEngineGemmaModelClient.shared.modelStatus()
    )
    modelStatuses[.appleFoundation] = apple
    modelStatuses[.gemma] = gemma
  }

  func pollModelStatuses() async {
    while !Task.isCancelled {
      await refreshModelStatuses()
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  func downloadGemma() {
    _ = AIEngineGemmaModelClient.shared.downloadModel()
    Task {
      await refreshModelStatuses()
    }
  }

  func loadSelectedModel() {
    switch selectedModel {
    case .appleFoundation:
      _ = AIEngineFoundationModelClient.shared.loadModel()
    case .gemma:
      _ = AIEngineGemmaModelClient.shared.loadModel()
    }
    Task {
      await refreshModelStatuses()
    }
  }

  func saveSettings() {
    let data: [String: Any] = [
      "settingsSchemaVersion": currentSettingsSchemaVersion,
      "systemPrompt": systemPrompt,
      "userName": userName,
      "personality": personality,
      "memoryEnabled": memoryEnabled,
      "selectedModel": selectedModel.rawValue,
      "fontSize": fontSizeSetting.rawValue,
      "appearanceMode": appearanceMode.rawValue,
      "accentColor": accentColor.rawValue,
      "selectedLanguage": selectedLanguage.rawValue,
      "backgroundExecutionEnabled": backgroundExecutionEnabled,
      "backgroundDynamicIslandEnabled": backgroundDynamicIslandEnabled,
      "dynamicIslandPetEnabled": dynamicIslandPetEnabled,
      "selectedDynamicIslandPet": selectedDynamicIslandPet.rawValue
    ]
    UserDefaults.standard.set(data, forKey: settingsKey)
  }

  func rebuildLocalMemoryIndex() {
    localKnowledgeStore.replaceGeneratedRecords(projects: projects, sessions: sessions)
    localMemoryIndexedItems = localKnowledgeStore.count
  }

  private func indexAttachments(_ attachments: [NativeAttachment]) {
    let records = NativeDocumentTextExtractor.knowledgeRecords(from: attachments)
    localKnowledgeStore.upsert(records)
    localMemoryIndexedItems = localKnowledgeStore.count
  }

  private func send(_ draft: NativeDraft) {
    guard let sessionId = selectedSessionId else {
      return
    }

    let now = Date()
    let userMessage = NativeMessage(
      id: UUID().uuidString,
      role: .user,
      text: draft.text,
      createdAt: now,
      attachments: draft.attachments
    )
    let assistantMessage = NativeMessage(
      id: UUID().uuidString,
      role: .assistant,
      text: "",
      createdAt: Date(),
      attachments: []
    )

    mutateSession(sessionId) { session in
      session.messages.append(userMessage)
      session.messages.append(assistantMessage)
      if session.title == "새 채팅" {
        session.title = makeLocalTitle(from: draft.text)
      }
    }

    isGenerating = true
    activeAssistantMessageId = assistantMessage.id
    activeRequestSessionId = sessionId
    statusMessage = nil
    beginGenerationBackgroundTaskIfNeeded()
    showDynamicIslandWork()

    let selectedTools = NativeToolRegistry.selectedTools(for: draft)
    if selectedTools.contains(.webSearch) {
      statusMessage = "검색 중..."
      startSearchProgress(assistantId: assistantMessage.id, sessionId: sessionId)
      let searchQuery = makeSearchQuery(for: sessionId, draft: draft)
      Task { [weak self] in
        let searchContext = await NativeWebSearchClient.shared.search(query: searchQuery)
        await MainActor.run { [weak self] in
          guard let self,
                self.activeAssistantMessageId == assistantMessage.id,
                self.activeRequestSessionId == sessionId
          else {
            return
          }

          self.statusMessage = nil
          self.stopSearchProgress(for: assistantMessage.id, in: sessionId, clearMessage: true)
          self.applySearchSources(searchContext.sourceReferences, to: assistantMessage.id, in: sessionId)
          let prompt = self.makePrompt(for: sessionId, draft: draft, searchContext: searchContext)
          self.streamResponse(prompt: prompt, assistantId: assistantMessage.id, sessionId: sessionId)
        }
      }
    } else {
      let prompt = makePrompt(for: sessionId, draft: draft)
      streamResponse(prompt: prompt, assistantId: assistantMessage.id, sessionId: sessionId)
    }
  }

  private func rewrite(
    _ draft: NativeDraft,
    replacingAssistantId assistantId: String,
    in sessionId: String,
    historyMessages: [NativeMessage]
  ) {
    let now = Date()
    var didResetMessage = false

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].text = ""
      session.messages[index].attachments = []
      session.messages[index].sourceReferences = []
      session.messages[index].contextCompressed = false
      session.messages[index].createdAt = now
      didResetMessage = true
    }

    guard didResetMessage else {
      return
    }

    isGenerating = true
    activeAssistantMessageId = assistantId
    activeRequestSessionId = sessionId
    statusMessage = nil
    beginGenerationBackgroundTaskIfNeeded()
    showDynamicIslandWork()

    let selectedTools = NativeToolRegistry.selectedTools(for: draft)
    if selectedTools.contains(.webSearch) {
      statusMessage = "검색 중..."
      startSearchProgress(assistantId: assistantId, sessionId: sessionId)
      let searchQuery = makeSearchQuery(for: sessionId, draft: draft, historyMessages: historyMessages)
      Task { [weak self] in
        let searchContext = await NativeWebSearchClient.shared.search(query: searchQuery)
        await MainActor.run { [weak self] in
          guard let self,
                self.activeAssistantMessageId == assistantId,
                self.activeRequestSessionId == sessionId
          else {
            return
          }

          self.statusMessage = nil
          self.stopSearchProgress(for: assistantId, in: sessionId, clearMessage: true)
          self.applySearchSources(searchContext.sourceReferences, to: assistantId, in: sessionId)
          let prompt = self.makePrompt(
            for: sessionId,
            draft: draft,
            historyMessages: historyMessages,
            searchContext: searchContext
          )
          self.streamResponse(prompt: prompt, assistantId: assistantId, sessionId: sessionId)
        }
      }
    } else {
      let prompt = makePrompt(for: sessionId, draft: draft, historyMessages: historyMessages)
      streamResponse(prompt: prompt, assistantId: assistantId, sessionId: sessionId)
    }
  }

  private func streamResponse(prompt: String, assistantId: String, sessionId: String) {
    let model = selectedModel
    let didCompressContext = NativePromptCompressor.estimatedTokens(prompt) > NativePromptCompressor.maxInputTokens
      || NativePromptCompressor.containsCompressionMarker(prompt)
    let compactedPrompt = NativePromptCompressor.clippedPreservingEdges(
      prompt,
      maxEstimatedTokens: NativePromptCompressor.maxInputTokens
    )
    setContextCompressionNotice(didCompressContext, to: assistantId, in: sessionId)

    if model == .gemma {
      AIEngineGemmaModelClient.shared.streamResponse(prompt: compactedPrompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantId, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantId, sessionId: sessionId)
        }
      }
    } else {
      AIEngineFoundationModelClient.shared.streamResponse(prompt: compactedPrompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantId, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantId, sessionId: sessionId)
        }
      }
    }
  }

  private func setContextCompressionNotice(_ isCompressed: Bool, to assistantId: String, in sessionId: String) {
    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].contextCompressed = isCompressed
    }
  }

  private func appendChunk(_ chunk: String, to assistantId: String, in sessionId: String) {
    guard isGenerating, activeAssistantMessageId == assistantId else {
      return
    }
    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }
      if isSearchProgressText(session.messages[index].text) {
        session.messages[index].text = ""
      }
      session.messages[index].text += chunk
    }
  }

  private func finishGeneration(message: String?, error: String?, assistantId: String, sessionId: String) {
    guard activeAssistantMessageId == assistantId else {
      return
    }

    stopSearchProgress(for: assistantId, in: sessionId, clearMessage: false)

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      if let error, !error.isEmpty {
        session.messages[index].text = "오류: \(error)"
      } else if session.messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        session.messages[index].text = message ?? ""
      }
    }

    isGenerating = false
    activeAssistantMessageId = nil
    activeRequestSessionId = nil
    endGenerationBackgroundTaskIfNeeded()
    rebuildLocalMemoryIndex()

    if queuedDrafts.isEmpty {
      syncDynamicIslandLiveActivity()
    } else {
      scheduleNextQueuedDraft()
    }
  }

  private func startSearchProgress(assistantId: String, sessionId: String) {
    stopSearchProgress(for: assistantId, in: sessionId, clearMessage: false)
    let startedAt = Date()
    updateSearchProgress(startedAt: startedAt, assistantId: assistantId, sessionId: sessionId)

    searchProgressTasks[assistantId] = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled else {
          break
        }
        await MainActor.run { [weak self] in
          self?.updateSearchProgress(startedAt: startedAt, assistantId: assistantId, sessionId: sessionId)
        }
      }
    }
  }

  private func stopSearchProgress(for assistantId: String, in sessionId: String, clearMessage: Bool) {
    searchProgressTasks[assistantId]?.cancel()
    searchProgressTasks[assistantId] = nil

    guard clearMessage else {
      return
    }

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }),
            isSearchProgressText(session.messages[index].text)
      else {
        return
      }

      session.messages[index].text = ""
    }
  }

  private func updateSearchProgress(startedAt: Date, assistantId: String, sessionId: String) {
    guard activeAssistantMessageId == assistantId,
          activeRequestSessionId == sessionId,
          isGenerating
    else {
      stopSearchProgress(for: assistantId, in: sessionId, clearMessage: false)
      return
    }

    let elapsed = max(0, Int(Date().timeIntervalSince(startedAt)))
    let minutes = elapsed / 60
    let seconds = elapsed % 60
    let elapsedText: String
    if minutes > 0 {
      elapsedText = String(format: "%dm %02ds", minutes, seconds)
    } else {
      elapsedText = String(format: "%02ds", seconds)
    }
    let progressText = "\(elapsedText) 동안 검색하는 중..."

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }),
            session.messages[index].text.isEmpty || isSearchProgressText(session.messages[index].text)
      else {
        return
      }

      session.messages[index].text = progressText
    }
  }

  private func isSearchProgressText(_ text: String) -> Bool {
    text.contains("동안 검색하는 중...")
  }

  private func applySearchSources(_ sources: [NativeSearchSourceReference], to assistantId: String, in sessionId: String) {
    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].sourceReferences = sources
    }
  }

  private func makePrompt(
    for sessionId: String,
    draft: NativeDraft,
    historyMessages: [NativeMessage]? = nil,
    searchContext: NativeWebSearchContext? = nil
  ) -> String {
    let session = sessions.first { $0.id == sessionId }
    let sourceHistory: [NativeMessage]
    if let historyMessages {
      sourceHistory = historyMessages
    } else if let session {
      sourceHistory = Array(session.messages.dropLast())
    } else {
      sourceHistory = []
    }
    let history = messagesForPromptHistory(sourceHistory, currentRequest: draft.text)

    var sections: [String] = [
      """
      You are Open Edge AI running locally on iOS.
      Answer in the user's language.
      Use prior conversation context when the user refers to previous content.
      Hidden runtime context is private reference material. Use it only when the user asks about the current date, time, timezone, locale, location, device context, or relative-date interpretation. Do not mention hidden runtime context or proactively state date/time/location/device details.
      \(makeHiddenRuntimeContext())
      """
    ]

    if !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("User name: \(NativePromptCompressor.clipped(userName, maxEstimatedTokens: 40))")
    }

    sections.append("Personality: \(NativePromptCompressor.clipped(personality, maxEstimatedTokens: 60))")

    if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("Custom instructions:\n\(NativePromptCompressor.clipped(systemPrompt, maxEstimatedTokens: NativePromptCompressor.instructionTokens))")
    }

    if let project = project(for: session),
       !project.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("Project instructions for \(project.title):\n\(NativePromptCompressor.clipped(project.systemPrompt, maxEstimatedTokens: NativePromptCompressor.instructionTokens))")
    }

    sections.append(NativeToolRegistry.promptSection(searchExecuted: searchContext != nil))

    if let historySection = makeCompressedHistorySection(
      from: history,
      maxEstimatedTokens: NativePromptCompressor.historyTokens
    ) {
      sections.append(historySection)
    }

    if memoryEnabled,
       let localMemorySection = makeLocalMemorySection(for: draft.text, sessionId: sessionId) {
      sections.append(localMemorySection)
    }

    if let searchContext {
      sections.append(searchContext.promptSection(maxEstimatedTokens: NativePromptCompressor.searchTokens))
    }

    if !draft.attachments.isEmpty {
      let attachmentRecords = NativeDocumentTextExtractor.knowledgeRecords(from: draft.attachments)
      localKnowledgeStore.upsert(attachmentRecords)
      localMemoryIndexedItems = localKnowledgeStore.count

      let files = draft.attachments.map { attachment in
        var parts = [attachment.name]
        if !attachment.type.isEmpty {
          parts.append("type=\(attachment.type)")
        }
        if !attachment.mimeType.isEmpty {
          parts.append("mime=\(attachment.mimeType)")
        }
        if let size = attachment.sizeBytes {
          parts.append("bytes=\(size)")
        }
        return parts.joined(separator: ", ")
      }.joined(separator: "\n")
      sections.append("Attached file metadata:\n\(files)")

      if !attachmentRecords.isEmpty {
        let attachmentText = attachmentRecords
          .map { record in
            """
            File: \(record.title)
            Content excerpt:
            \(NativePromptCompressor.clipped(record.text, maxEstimatedTokens: max(120, 620 / max(1, attachmentRecords.count))))
            """
          }
          .joined(separator: "\n\n")
        sections.append("Attached file content extracted on iOS:\n\(attachmentText)")
      }
    }

    sections.append("Current user request:\n\(NativePromptCompressor.clippedCurrentRequest(draft.text, maxEstimatedTokens: NativePromptCompressor.currentRequestTokens))")
    return NativePromptCompressor.clippedPreservingEdges(
      sections.joined(separator: "\n\n"),
      maxEstimatedTokens: NativePromptCompressor.maxInputTokens
    )
  }

  private func makeLocalMemorySection(for query: String, sessionId: String) -> String? {
    let matches = localKnowledgeStore.search(query: query, limit: 5)
      .filter { match in
        !match.excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }

    guard !matches.isEmpty else {
      return nil
    }

    let lines = matches.enumerated().map { index, match in
      let source: String
      switch match.record.source {
      case .project:
        source = "project memory"
      case .chat:
        source = "chat history"
      case .attachment:
        source = "indexed attachment"
      }

      return """
      [L\(index + 1)] \(source): \(match.record.title)
      \(match.excerpt)
      """
    }

    return """
    Local RAG context from iOS memory/index:
    Use this only when it is relevant to the current request. Do not reveal internal record ids.
    \(lines.joined(separator: "\n\n"))
    """
  }

  private func messagesForPromptHistory(_ messages: [NativeMessage], currentRequest: String) -> [NativeMessage] {
    var history = messages
    if let last = history.last,
       last.role == .user,
       normalizedPromptText(last.text) == normalizedPromptText(currentRequest) {
      history.removeLast()
    }
    return history
  }

  private func makeCompressedHistorySection(from messages: [NativeMessage], maxEstimatedTokens: Int) -> String? {
    let meaningfulMessages = messages.filter { message in
      !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !message.attachments.isEmpty
    }

    guard !meaningfulMessages.isEmpty else {
      return nil
    }

    var reversedEntries: [String] = []
    var usedTokens = NativePromptCompressor.estimatedTokens("Conversation history")

    for message in meaningfulMessages.reversed() {
      let role = message.role == .assistant ? "assistant" : "user"
      let perMessageLimit = message.role == .assistant ? 150 : 130
      let sourceText = NativePromptCompressor.shouldPreserveStructure(message.text)
        ? message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        : normalizedPromptText(message.text)
      var body = NativePromptCompressor.clippedMessageBody(
        sourceText,
        maxEstimatedTokens: perMessageLimit,
      )

      if body.isEmpty, !message.attachments.isEmpty {
        body = "첨부 파일: " + message.attachments.map(\.name).joined(separator: ", ")
      } else if !message.attachments.isEmpty {
        body += "\n첨부 파일: " + message.attachments.map(\.name).joined(separator: ", ")
      }

      let entry = "\(role): \(body)"
      let entryTokens = NativePromptCompressor.estimatedTokens(entry)
      if usedTokens + entryTokens > maxEstimatedTokens {
        break
      }

      reversedEntries.append(entry)
      usedTokens += entryTokens
    }

    guard !reversedEntries.isEmpty else {
      return nil
    }

    let omittedCount = max(0, meaningfulMessages.count - reversedEntries.count)
    var lines = ["Conversation history (compressed to fit the on-device model context):"]
    if omittedCount > 0 {
      lines.append("Earlier \(omittedCount) messages were omitted. Prioritize the recent turns below.")
    }
    lines.append(contentsOf: reversedEntries.reversed())
    return lines.joined(separator: "\n")
  }

  private func normalizedPromptText(_ text: String) -> String {
    text
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func makeDraftInput(from rawText: String) -> (text: String, mode: NativeDraftMode) {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

    if let searchPayload = NativeSlashCommand.searchPayload(in: trimmed) {
      let requestText = searchPayload.trimmingCharacters(in: .whitespacesAndNewlines)
      return (requestText.isEmpty ? searchFallbackRequestText : requestText, .search)
    }

    return (trimmed, .standard)
  }

  private func makeSearchQuery(
    for sessionId: String,
    draft: NativeDraft,
    historyMessages: [NativeMessage]? = nil
  ) -> String {
    let session = sessions.first { $0.id == sessionId }
    let sourceHistory: [NativeMessage]
    if let historyMessages {
      sourceHistory = historyMessages
    } else if let session {
      sourceHistory = Array(session.messages.dropLast(2))
    } else {
      sourceHistory = []
    }

    let promptHistory = messagesForPromptHistory(sourceHistory, currentRequest: draft.text)
    let explicitRequest = draft.text == searchFallbackRequestText ? "" : draft.text
    let historyText = promptHistory
      .suffix(8)
      .map(\.text)
      .map { $0.replacingOccurrences(of: "\n", with: " ") }
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: " ")

    let rawQuery = explicitRequest.isEmpty ? historyText : "\(historyText) \(explicitRequest)"
    let cleaned = NativePromptCompressor.clipped(rawQuery, maxEstimatedTokens: 120, keepTail: true)
      .replacingOccurrences(of: "... [앞부분 압축]\n", with: "")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if cleaned.isEmpty {
      return draft.text
    }

    return cleaned.count > 260 ? String(cleaned.prefix(260)) : cleaned
  }

  private func project(for session: NativeChatSession?) -> NativeProject? {
    guard let projectId = session?.projectId else {
      return nil
    }
    return projects.first { $0.id == projectId }
  }

  private func makeHiddenRuntimeContext() -> String {
    let now = Date()
    let locale = Locale.current
    let localeParts = locale.identifier
      .replacingOccurrences(of: "-", with: "_")
      .split(separator: "_")
      .map(String.init)
    let languageCode = localeParts.first ?? "unknown"
    let regionCode = localeParts.dropFirst().first { $0.count == 2 } ?? "unknown"
    let timeZone = TimeZone.current
    deviceContextProvider.refreshLocationIfAuthorized()

    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: selectedLanguage.localeIdentifier)
    displayFormatter.timeZone = timeZone
    displayFormatter.dateStyle = .full
    displayFormatter.timeStyle = .medium

    let localISOFormatter = ISO8601DateFormatter()
    localISOFormatter.timeZone = timeZone
    localISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let utcISOFormatter = ISO8601DateFormatter()
    utcISOFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    utcISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var lines = [
      "Local date/time: \(displayFormatter.string(from: now))",
      "Local ISO timestamp: \(localISOFormatter.string(from: now))",
      "UTC timestamp: \(utcISOFormatter.string(from: now))",
      "Timezone: \(timeZone.identifier), \(timeZone.abbreviation(for: now) ?? "unknown"), \(gmtOffset(seconds: timeZone.secondsFromGMT(for: now)))",
      "Device locale: \(locale.identifier)",
      "Device language: \(languageCode)",
      "Device region: \(regionCode)",
      "App response locale: \(selectedLanguage.localeIdentifier)",
      "Calendar: \(String(describing: Calendar.current.identifier))",
      "Device: \(UIDevice.current.model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    ]

    lines.append(contentsOf: deviceContextProvider.locationContextLines(now: now))
    return "Hidden runtime context:\n" + lines.map { "- \($0)" }.joined(separator: "\n")
  }

  private func gmtOffset(seconds: Int) -> String {
    let sign = seconds >= 0 ? "+" : "-"
    let absoluteSeconds = abs(seconds)
    let hours = absoluteSeconds / 3600
    let minutes = (absoluteSeconds % 3600) / 60
    return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
  }

  private func mutateSession(_ id: String, _ mutation: (inout NativeChatSession) -> Void) {
    guard let index = sessions.firstIndex(where: { $0.id == id }) else {
      return
    }

    objectWillChange.send()
    mutation(&sessions[index])
    sessions[index].updatedAt = Date()
    sessions.sort { $0.updatedAt > $1.updatedAt }
    saveSessions()
  }

  private func mutateTodoItem(_ id: String, _ mutation: (inout NativeTodoItem) -> Void) {
    guard let index = todoItems.firstIndex(where: { $0.id == id }) else {
      return
    }

    objectWillChange.send()
    mutation(&todoItems[index])
    todoItems[index].updatedAt = Date()
    sortTodoItems()
    saveTodoItems()
  }

  private func sortTodoItems() {
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

  private func pruneEmptyDraftSessions(keeping keptSessionId: String? = nil) {
    sessions.removeAll { session in
      session.id != keptSessionId && !sessionHasContent(session)
    }

    if let selectedSessionId,
       sessions.contains(where: { $0.id == selectedSessionId }) == false {
      self.selectedSessionId = sessions.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }
  }

  private func sessionHasContent(_ session: NativeChatSession) -> Bool {
    session.messages.contains { message in
      let hasText = !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return hasText || !message.attachments.isEmpty
    }
  }

  private func makeAttachment(from url: URL) -> NativeAttachment? {
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

  private func makeAttachment(displayName: String, mimeType: String, sizeBytes: Int64?, url: URL) -> NativeAttachment {
    return NativeAttachment(
      id: UUID().uuidString,
      name: displayName.isEmpty ? "첨부 파일" : displayName,
      type: attachmentType(mimeType: mimeType, fileName: displayName),
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      url: url.absoluteString
    )
  }

  private func persistAttachmentData(_ data: Data, fileName: String) -> URL? {
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

  private func persistAttachmentFile(from sourceURL: URL, suggestedName: String) -> URL? {
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

  private func uniqueAttachmentURL(for fileName: String) -> URL? {
    guard let directory = attachmentStorageDirectory() else {
      return nil
    }

    let sanitizedName = Self.sanitizedAttachmentFileName(fileName)
    return directory.appendingPathComponent("\(UUID().uuidString)-\(sanitizedName)", isDirectory: false)
  }

  private func attachmentStorageDirectory() -> URL? {
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

  private static func attachmentTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return formatter.string(from: Date())
  }

  private func attachmentType(mimeType: String, fileName: String) -> String {
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

  private func mimeType(fileName: String, typeIdentifier: String?) -> String {
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

  private func loadSessions() {
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

  private func saveSessions() {
    let persistableSessions = sessions.filter(sessionHasContent)
    guard let data = try? JSONEncoder().encode(persistableSessions) else {
      return
    }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func loadProjects() {
    guard let data = UserDefaults.standard.data(forKey: projectsStorageKey),
          let decoded = try? JSONDecoder().decode([NativeProject].self, from: data)
    else {
      projects = []
      return
    }
    projects = decoded.sorted { $0.createdAt > $1.createdAt }
  }

  private func saveProjects() {
    guard let data = try? JSONEncoder().encode(projects) else {
      return
    }
    UserDefaults.standard.set(data, forKey: projectsStorageKey)
  }

  private func loadTodoItems() {
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

  private func saveTodoItems() {
    guard let data = try? JSONEncoder().encode(todoItems) else {
      return
    }
    UserDefaults.standard.set(data, forKey: todoStorageKey)
  }

  private func loadSettings() {
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

  private func makeLocalTitle(from text: String) -> String {
    let cleaned = text
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return "새 채팅"
    }
    return cleaned.count > 24 ? "\(cleaned.prefix(24))..." : cleaned
  }

  private func scheduleNextQueuedDraft() {
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

  private func boolSetting(_ value: Any?, default defaultValue: Bool) -> Bool {
    if let value = value as? Bool {
      return value
    }
    if let value = value as? NSNumber {
      return value.boolValue
    }
    return defaultValue
  }

}
