import SwiftUI
import UniformTypeIdentifiers

@main
struct OpenEdgeAIApp: App {
  @StateObject private var store = NativeChatStore()

  var body: some Scene {
    WindowGroup {
      NativeRootView()
        .environmentObject(store)
        .preferredColorScheme(.light)
    }
  }
}

private enum NativeRole: String, Codable {
  case user
  case assistant
}

private enum NativeModel: String, CaseIterable, Identifiable, Codable {
  case appleFoundation = "apple-foundation"
  case gemma = "gemma-4"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .appleFoundation:
      return "Apple Intelligence"
    case .gemma:
      return "Gemma 4"
    }
  }

  var subtitle: String {
    switch self {
    case .appleFoundation:
      return "Apple 기본 온디바이스 AI"
    case .gemma:
      return "다운로드 가능한 로컬 모델"
    }
  }
}

private struct NativeAttachment: Identifiable, Codable, Equatable {
  var id: String
  var name: String
  var type: String
  var mimeType: String
  var sizeBytes: Int64?
  var url: String
}

private struct NativeMessage: Identifiable, Codable, Equatable {
  var id: String
  var role: NativeRole
  var text: String
  var createdAt: Date
  var attachments: [NativeAttachment]
}

private struct NativeDraft: Identifiable, Codable, Equatable {
  var id: String
  var text: String
  var attachments: [NativeAttachment]
  var createdAt: Date
}

private struct NativeChatSession: Identifiable, Codable, Equatable {
  var id: String
  var title: String
  var createdAt: Date
  var updatedAt: Date
  var messages: [NativeMessage]
}

private struct NativeProject: Identifiable, Codable, Equatable {
  var id: String
  var title: String
  var iconName: String
  var systemPrompt: String
  var createdAt: Date

  init(
    id: String,
    title: String,
    iconName: String,
    systemPrompt: String,
    createdAt: Date
  ) {
    self.id = id
    self.title = title
    self.iconName = iconName
    self.systemPrompt = systemPrompt
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case iconName
    case systemPrompt
    case createdAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? NativeProjectIcon.defaultIcon.systemImage
    systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }
}

private struct NativeProjectIcon: Identifiable, Equatable {
  var id: String { systemImage }
  var systemImage: String
  var title: String

  static let defaultIcon = NativeProjectIcon(systemImage: "folder", title: "폴더")

  static let all: [NativeProjectIcon] = [
    defaultIcon,
    NativeProjectIcon(systemImage: "sparkles", title: "AI"),
    NativeProjectIcon(systemImage: "terminal", title: "코드"),
    NativeProjectIcon(systemImage: "doc.text", title: "문서"),
    NativeProjectIcon(systemImage: "brain.head.profile", title: "메모리"),
    NativeProjectIcon(systemImage: "chart.bar", title: "분석")
  ]
}

private enum NativeRenameTarget: Identifiable, Equatable {
  case session(id: String, title: String)
  case project(id: String, title: String)

  var id: String {
    switch self {
    case .session(let id, _):
      return "session-\(id)"
    case .project(let id, _):
      return "project-\(id)"
    }
  }

  var title: String {
    switch self {
    case .session(_, let title), .project(_, let title):
      return title
    }
  }

  var navigationTitle: String {
    switch self {
    case .session:
      return "채팅 이름 변경"
    case .project:
      return "프로젝트 이름 변경"
    }
  }

  var fieldTitle: String {
    switch self {
    case .session:
      return "채팅 이름"
    case .project:
      return "프로젝트 이름"
    }
  }

  var placeholder: String {
    switch self {
    case .session:
      return "예: 새 채팅"
    case .project:
      return "예: Atlas"
    }
  }
}

private struct NativeModelStatus: Equatable {
  var modelId: String
  var title: String
  var installed: Bool
  var downloading: Bool
  var runnable: Bool
  var started: Bool
  var bytesDownloaded: Int64
  var totalBytes: Int64
  var error: String?
  var systemManaged: Bool

  var progress: Double {
    guard totalBytes > 0 else {
      return installed ? 1 : 0
    }
    return min(1, max(0, Double(bytesDownloaded) / Double(totalBytes)))
  }

  init(model: NativeModel) {
    modelId = model.rawValue
    title = model.title
    installed = false
    downloading = false
    runnable = false
    started = false
    bytesDownloaded = 0
    totalBytes = 0
    error = nil
    systemManaged = model == .appleFoundation
  }

  init(model: NativeModel, dictionary: NSDictionary) {
    modelId = dictionary["modelId"] as? String ?? model.rawValue
    title = dictionary["modelName"] as? String ?? model.title
    installed = NativeModelStatus.bool(dictionary["installed"])
    downloading = NativeModelStatus.bool(dictionary["isDownloading"])
    runnable = NativeModelStatus.bool(dictionary["runnable"])
    started = NativeModelStatus.bool(dictionary["started"])
    bytesDownloaded = NativeModelStatus.int64(dictionary["bytesDownloaded"])
    totalBytes = NativeModelStatus.int64(dictionary["totalBytes"])
    systemManaged = NativeModelStatus.bool(dictionary["systemManaged"])

    if let value = dictionary["error"] as? String, !value.isEmpty {
      error = value
    } else {
      error = nil
    }
  }

  private static func bool(_ value: Any?) -> Bool {
    if let value = value as? Bool {
      return value
    }
    if let value = value as? NSNumber {
      return value.boolValue
    }
    return false
  }

  private static func int64(_ value: Any?) -> Int64 {
    if let value = value as? Int64 {
      return value
    }
    if let value = value as? NSNumber {
      return value.int64Value
    }
    return 0
  }
}

@MainActor
private final class NativeChatStore: ObservableObject {
  @Published var sessions: [NativeChatSession] = []
  @Published var projects: [NativeProject] = []
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

  private let storageKey = "OpenEdgeAI.NativeChatSessions.v1"
  private let projectsStorageKey = "OpenEdgeAI.NativeProjects.v1"
  private let settingsKey = "OpenEdgeAI.NativeSettings.v1"
  private var activeAssistantMessageId: String?
  private var activeRequestSessionId: String?

  init() {
    loadSettings()
    loadSessions()
    loadProjects()

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

  var canSend: Bool {
    !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
  }

  func createNewSession() {
    let now = Date()
    let session = NativeChatSession(
      id: UUID().uuidString,
      title: "새 채팅",
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
    selectedSessionId = session.id
    inputText = ""
    pendingAttachments = []
  }

  func deleteSession(_ session: NativeChatSession) {
    sessions.removeAll { $0.id == session.id }
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
  }

  func deleteProject(_ project: NativeProject) {
    projects.removeAll { $0.id == project.id }
    saveProjects()
  }

  func renameProject(id: String, title: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty,
          let index = projects.firstIndex(where: { $0.id == id })
    else {
      return
    }

    projects[index].title = trimmedTitle
    saveProjects()
  }

  func sendCurrentInput() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty || !pendingAttachments.isEmpty else {
      return
    }

    let draft = NativeDraft(
      id: UUID().uuidString,
      text: text,
      attachments: pendingAttachments,
      createdAt: Date()
    )

    inputText = ""
    pendingAttachments = []

    if isGenerating {
      queuedDrafts.append(draft)
      return
    }

    send(draft)
  }

  func removeQueuedDraft(_ draft: NativeDraft) {
    queuedDrafts.removeAll { $0.id == draft.id }
  }

  func updateQueuedDraft(_ draft: NativeDraft, text: String) {
    guard let index = queuedDrafts.firstIndex(where: { $0.id == draft.id }) else {
      return
    }
    queuedDrafts[index].text = text
  }

  func retry(message: NativeMessage) {
    guard let session = currentSession,
          let assistantIndex = session.messages.firstIndex(where: { $0.id == message.id })
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
      createdAt: Date()
    )

    if isGenerating {
      queuedDrafts.append(draft)
    } else {
      send(draft)
    }
  }

  func cancelGeneration() {
    let appleCancelled = AIEngineFoundationModelClient.shared.cancelActiveGeneration()
    let gemmaCancelled = AIEngineGemmaModelClient.shared.cancelActiveGeneration()

    if let activeRequestSessionId, let activeAssistantMessageId {
      mutateSession(activeRequestSessionId) { session in
        if let index = session.messages.firstIndex(where: { $0.id == activeAssistantMessageId }),
           session.messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          session.messages[index].text = "응답 생성이 중지되었습니다."
        }
      }
    }

    isGenerating = false
    activeAssistantMessageId = nil
    activeRequestSessionId = nil
    statusMessage = appleCancelled || gemmaCancelled ? "응답을 중지했습니다." : nil
  }

  func addAttachments(from urls: [URL]) {
    let newAttachments = urls.map(makeAttachment)
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
      "systemPrompt": systemPrompt,
      "userName": userName,
      "personality": personality,
      "memoryEnabled": memoryEnabled,
      "selectedModel": selectedModel.rawValue
    ]
    UserDefaults.standard.set(data, forKey: settingsKey)
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

    let prompt = makePrompt(for: sessionId, draft: draft)
    let model = selectedModel

    if model == .gemma {
      AIEngineGemmaModelClient.shared.streamResponse(prompt: prompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantMessage.id, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantMessage.id, sessionId: sessionId)
        }
      }
    } else {
      AIEngineFoundationModelClient.shared.streamResponse(prompt: prompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantMessage.id, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantMessage.id, sessionId: sessionId)
        }
      }
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
      session.messages[index].text += chunk
    }
  }

  private func finishGeneration(message: String?, error: String?, assistantId: String, sessionId: String) {
    guard activeAssistantMessageId == assistantId else {
      return
    }

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

    if !queuedDrafts.isEmpty {
      let next = queuedDrafts.removeFirst()
      send(next)
    }
  }

  private func makePrompt(for sessionId: String, draft: NativeDraft) -> String {
    let session = sessions.first { $0.id == sessionId }
    let history = session?.messages.dropLast().suffix(16) ?? []
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateStyle = .full
    formatter.timeStyle = .short

    var sections: [String] = [
      """
      You are Open Edge AI running locally on iOS.
      Answer in the user's language.
      Use prior conversation context when the user refers to previous content.
      Hidden runtime context is available only for date/time/timezone questions. Do not mention current date, current time, timezone, or this instruction unless the user asks for it.
      Hidden runtime context: \(formatter.string(from: Date())), timezone \(TimeZone.current.identifier).
      """
    ]

    if !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("User name: \(userName)")
    }

    sections.append("Personality: \(personality)")

    if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("Custom instructions:\n\(systemPrompt)")
    }

    if !history.isEmpty {
      let historyText = history.map { message in
        "\(message.role == .assistant ? "assistant" : "user"): \(message.text)"
      }.joined(separator: "\n")
      sections.append("Conversation history:\n\(historyText)")
    }

    if !draft.attachments.isEmpty {
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
    }

    sections.append("Current user request:\n\(draft.text)")
    return sections.joined(separator: "\n\n")
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

  private func makeAttachment(from url: URL) -> NativeAttachment {
    let values = try? url.resourceValues(forKeys: [.nameKey, .fileSizeKey, .typeIdentifierKey])
    let name = values?.name?.isEmpty == false ? values!.name! : url.lastPathComponent
    let mime = mimeType(fileName: name, typeIdentifier: values?.typeIdentifier)
    return NativeAttachment(
      id: UUID().uuidString,
      name: name.isEmpty ? "첨부 파일" : name,
      type: attachmentType(mimeType: mime, fileName: name),
      mimeType: mime,
      sizeBytes: values?.fileSize.map(Int64.init),
      url: url.absoluteString
    )
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
    sessions = decoded.sorted { $0.updatedAt > $1.updatedAt }
  }

  private func saveSessions() {
    guard let data = try? JSONEncoder().encode(sessions) else {
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

  private func loadSettings() {
    let data = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
    systemPrompt = data["systemPrompt"] as? String ?? ""
    userName = data["userName"] as? String ?? ""
    personality = data["personality"] as? String ?? "Balanced"
    memoryEnabled = data["memoryEnabled"] as? Bool ?? true
    if let raw = data["selectedModel"] as? String,
       let model = NativeModel(rawValue: raw) {
      selectedModel = model
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
}

private struct NativeRootView: View {
  @EnvironmentObject private var store: NativeChatStore
  @State private var showingSessions = false
  @State private var showingSettings = false
  @State private var showingFileImporter = false

  var body: some View {
    ZStack(alignment: .leading) {
      VStack(spacing: 0) {
        NativeTopBar(
          showingSessions: $showingSessions
        )
        Divider()
        NativeChatTranscript()
        NativeInputBar(showingFileImporter: $showingFileImporter)
      }
      .background(Color.white)

      if showingSessions {
        NativeSessionsView(
          isPresented: $showingSessions,
          showingSettings: $showingSettings
        )
          .environmentObject(store)
          .transition(.move(edge: .leading))
          .zIndex(1)
      }
    }
    .animation(.easeOut(duration: 0.24), value: showingSessions)
    .sheet(isPresented: $showingSettings) {
      NativeSettingsView()
        .environmentObject(store)
    }
    .fileImporter(
      isPresented: $showingFileImporter,
      allowedContentTypes: [.item],
      allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result {
        store.addAttachments(from: urls)
      }
    }
    .task {
      await store.pollModelStatuses()
    }
  }
}

private struct NativeTopBar: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var showingSessions: Bool

  var body: some View {
    HStack(spacing: 12) {
      Button {
        withAnimation(.easeOut(duration: 0.24)) {
          showingSessions = true
        }
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
      }
      .accessibilityLabel("채팅 목록 열기")
      .buttonStyle(.plain)

      Button {
        store.createNewSession()
      } label: {
        HStack(spacing: 8) {
          ZStack {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.black)
            Image(systemName: "sparkles")
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(.white)
          }
          .frame(width: 28, height: 28)

          Text(store.currentSession?.title ?? "Open Edge AI")
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
        }
      }
      .buttonStyle(.plain)

      Spacer(minLength: 8)

      NativeModelMenu()
    }
    .foregroundColor(.black)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(Color.white)
  }
}

private struct NativeModelMenu: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    Menu {
      ForEach(NativeModel.allCases) { model in
        let status = store.modelStatuses[model] ?? NativeModelStatus(model: model)
        Button {
          store.selectedModel = model
          store.saveSettings()
          if status.installed || status.systemManaged {
            store.loadSelectedModel()
          }
        } label: {
          Label(model.title, systemImage: store.selectedModel == model ? "checkmark" : "")
        }

        if model == .gemma && !status.installed {
          Button {
            store.downloadGemma()
          } label: {
            Label(status.downloading ? "다운로드 중" : "다운로드", systemImage: status.downloading ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
          }
        }
      }
    } label: {
      HStack(spacing: 6) {
        Text(store.selectedModel.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "chevron.down")
          .font(.system(size: 10, weight: .bold))
      }
      .foregroundColor(.black)
      .padding(.horizontal, 10)
      .frame(height: 34)
      .overlay(
        RoundedRectangle(cornerRadius: 17)
          .stroke(Color.black.opacity(0.18), lineWidth: 1)
      )
    }
  }
}

private struct NativeChatTranscript: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          if store.currentMessages.isEmpty {
            NativeEmptyChatView()
              .padding(.top, 80)
          } else {
            ForEach(store.currentMessages) { message in
              NativeMessageView(message: message)
                .id(message.id)
            }
          }

          Color.clear
            .frame(height: 1)
            .id("bottom")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 24)
      }
      .background(Color.white)
      .onChange(of: store.currentMessages) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("bottom", anchor: .bottom)
        }
      }
    }
  }
}

private struct NativeEmptyChatView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Open Edge AI")
        .font(.system(size: 28, weight: .bold))
      Text("기기 안에서 실행되는 AI와 대화를 시작하세요.")
        .font(.system(size: 16))
        .foregroundColor(.black.opacity(0.62))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct NativeMessageView: View {
  @EnvironmentObject private var store: NativeChatStore
  let message: NativeMessage

  var body: some View {
    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
      if !message.attachments.isEmpty {
        NativeAttachmentRow(attachments: message.attachments)
      }

      if message.role == .user {
        Text(message.text.isEmpty ? "첨부 파일" : message.text)
          .font(.system(size: 16))
          .foregroundColor(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(Color.black)
          .clipShape(RoundedRectangle(cornerRadius: 18))
          .frame(maxWidth: .infinity, alignment: .trailing)
          .textSelection(.enabled)
      } else {
        NativeMarkdownText(text: message.text.isEmpty ? "응답 준비 중..." : message.text)
          .font(.system(size: 16))
          .foregroundColor(.black)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)

        HStack(spacing: 16) {
          Button {
            store.copy(message.text)
          } label: {
            Image(systemName: "doc.on.doc")
          }

          Button {
            store.retry(message: message)
          } label: {
            Image(systemName: "arrow.clockwise")
          }

          Text(message.createdAt.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 12))
            .foregroundColor(.black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .foregroundColor(.black.opacity(0.72))
        .font(.system(size: 14, weight: .medium))
      }
    }
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }
}

private struct NativeMarkdownText: View {
  let text: String

  var body: some View {
    if let attributed = try? AttributedString(markdown: text) {
      Text(attributed)
    } else {
      Text(text)
    }
  }
}

private struct NativeAttachmentRow: View {
  let attachments: [NativeAttachment]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(attachments) { attachment in
        HStack(spacing: 8) {
          Image(systemName: icon(for: attachment.type))
          Text(attachment.name)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
        }
        .foregroundColor(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
    }
  }

  private func icon(for type: String) -> String {
    switch type {
    case "image":
      return "photo"
    case "audio":
      return "waveform"
    case "video":
      return "film"
    default:
      return "doc"
    }
  }
}

private struct NativeInputBar: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var showingFileImporter: Bool
  @FocusState private var focused: Bool

  var body: some View {
    VStack(spacing: 8) {
      if !store.queuedDrafts.isEmpty {
        NativeQueueView()
      }

      if !store.pendingAttachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(store.pendingAttachments) { attachment in
              HStack(spacing: 6) {
                Text(attachment.name)
                  .lineLimit(1)
                Button {
                  store.removePendingAttachment(attachment)
                } label: {
                  Image(systemName: "xmark")
                }
              }
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.black)
              .padding(.horizontal, 10)
              .padding(.vertical, 7)
              .background(Color.black.opacity(0.06))
              .clipShape(Capsule())
            }
          }
        }
      }

      HStack(alignment: .bottom, spacing: 10) {
        Button {
          showingFileImporter = true
        } label: {
          Image(systemName: "paperclip")
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)

        TextEditor(text: $store.inputText)
          .font(.system(size: 16))
          .focused($focused)
          .frame(minHeight: 38, maxHeight: 110)
          .overlay(alignment: .topLeading) {
            if store.inputText.isEmpty {
              Text("무엇이든 묻거나 검색하고 만들어보세요...")
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.35))
                .padding(.top, 8)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }

        Button {
          if store.isGenerating && !store.canSend {
            store.cancelGeneration()
          } else {
            store.sendCurrentInput()
          }
        } label: {
          Image(systemName: store.isGenerating && !store.canSend ? "stop.fill" : "arrow.up")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 38, height: 38)
            .background(Color.black)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!store.isGenerating && !store.canSend)
        .opacity(!store.isGenerating && !store.canSend ? 0.35 : 1)
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 10)
    .padding(.bottom, 10)
    .background(Color.white)
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .padding(.horizontal, 10)
    .padding(.bottom, 8)
  }
}

private struct NativeQueueView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    VStack(spacing: 6) {
      ForEach(store.queuedDrafts) { draft in
        HStack(spacing: 8) {
          TextField("대기 중인 후속 질문", text: Binding(
            get: { draft.text },
            set: { store.updateQueuedDraft(draft, text: $0) }
          ))
          .font(.system(size: 13))

          Button {
            store.removeQueuedDraft(draft)
          } label: {
            Image(systemName: "xmark")
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}

private struct NativeSessionsView: View {
  @Binding var isPresented: Bool
  @Binding var showingSettings: Bool
  @EnvironmentObject private var store: NativeChatStore
  @State private var searchText = ""
  @State private var isProjectCreatorPresented = false
  @State private var renameTarget: NativeRenameTarget?

  private var recentSessions: [NativeChatSession] {
    let sortedSessions = store.sessions.sorted { $0.updatedAt > $1.updatedAt }
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else {
      return sortedSessions
    }
    return sortedSessions.filter { session in
      session.title.lowercased().contains(query)
    }
  }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .center, spacing: 16) {
          Image("OpenEdgeLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 40, alignment: .leading)
            .accessibilityLabel("Open Edge AI")

          Spacer(minLength: 12)

          NativeSessionsSearchPill(
            searchText: $searchText,
            onSettingsPress: openSettings
          )
        }
        .padding(.horizontal, 30)
        .padding(.top, 22)
        .padding(.bottom, 28)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 26) {
            NativeSessionsSection(title: "프로젝트") {
              Button {
                isProjectCreatorPresented = true
              } label: {
                NativeSessionsIconRow(systemImage: "folder.badge.plus", title: "새 프로젝트")
              }
              .buttonStyle(.plain)

              ForEach(store.projects) { project in
                NativeSessionsIconRow(systemImage: project.iconName, title: project.title)
                  .contextMenu {
                    Button {
                      renameTarget = .project(id: project.id, title: project.title)
                    } label: {
                      Label("이름 변경", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                      store.deleteProject(project)
                    } label: {
                      Label("삭제", systemImage: "trash")
                    }
                  }
              }

              NativeSessionsIconRow(systemImage: "terminal", title: "로컬 모델")
              NativeSessionsIconRow(systemImage: "doc.text", title: "개인 메모리")
            }

            NativeSessionsSection(title: "최근") {
              if recentSessions.isEmpty {
                Text("검색 결과가 없습니다")
                  .font(.system(size: 15, weight: .medium))
                  .foregroundColor(.black.opacity(0.45))
                  .padding(.vertical, 6)
              } else {
                ForEach(recentSessions) { session in
                  Button {
                    store.selectSession(session)
                    close()
                  } label: {
                    Text(session.title)
                      .font(.system(size: 16, weight: .regular))
                      .foregroundColor(.black)
                      .lineLimit(1)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
                  .contextMenu {
                    Button {
                      renameTarget = .session(id: session.id, title: session.title)
                    } label: {
                      Label("이름 변경", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                      store.deleteSession(session)
                    } label: {
                      Label("삭제", systemImage: "trash")
                    }
                  }
                }
              }
            }
          }
          .padding(.horizontal, 36)
          .padding(.bottom, 108)
        }

        Spacer(minLength: 0)
      }

      Button {
        store.createNewSession()
        close()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "square.and.pencil")
            .font(.system(size: 18, weight: .semibold))
          Text("채팅")
            .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(Color.black)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("새 채팅")
      .padding(.trailing, 34)
      .padding(.bottom, 34)
    }
    .background(Color.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $isProjectCreatorPresented) {
      NativeProjectCreatorView()
        .environmentObject(store)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .sheet(item: $renameTarget) { target in
      NativeRenameSheet(target: target)
        .environmentObject(store)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    .gesture(
      DragGesture(minimumDistance: 24)
        .onEnded { value in
          if value.translation.width < -70 {
            close()
          }
        }
    )
  }

  private func close() {
    withAnimation(.easeIn(duration: 0.2)) {
      isPresented = false
    }
  }

  private func openSettings() {
    showingSettings = true
  }
}

private struct NativeRenameSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  let target: NativeRenameTarget
  @State private var title: String
  @FocusState private var isFocused: Bool

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  init(target: NativeRenameTarget) {
    self.target = target
    _title = State(initialValue: target.title)
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 14) {
        Text(target.fieldTitle)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.black.opacity(0.58))

        TextField(target.placeholder, text: $title)
          .focused($isFocused)
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(.black)
          .textInputAutocapitalization(.sentences)
          .padding(.horizontal, 16)
          .frame(height: 54)
          .background(Color.black.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 24)
      .padding(.top, 24)
      .background(Color.white)
      .navigationTitle(target.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
          .foregroundColor(.black)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("저장", action: save)
            .fontWeight(.semibold)
            .foregroundColor(canSave ? .black : .black.opacity(0.3))
            .disabled(!canSave)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          isFocused = true
        }
      }
    }
  }

  private func save() {
    guard canSave else {
      return
    }

    switch target {
    case .session(let id, _):
      store.renameSession(id: id, title: title)
    case .project(let id, _):
      store.renameProject(id: id, title: title)
    }
    dismiss()
  }
}

private struct NativeProjectCreatorView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  @State private var projectTitle = ""
  @State private var selectedIconName = NativeProjectIcon.defaultIcon.systemImage
  @State private var systemPrompt = ""
  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case title
    case systemPrompt
  }

  private var canCreate: Bool {
    !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 26) {
          NativeProjectCreatorSection(title: "프로젝트 명") {
            TextField("예: Atlas", text: $projectTitle)
              .focused($focusedField, equals: .title)
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(.black)
              .textInputAutocapitalization(.words)
              .padding(.horizontal, 16)
              .frame(height: 54)
              .background(Color.black.opacity(0.04))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }

          NativeProjectCreatorSection(title: "아이콘") {
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
              alignment: .leading,
              spacing: 10
            ) {
              ForEach(NativeProjectIcon.all) { icon in
                NativeProjectIconOption(
                  icon: icon,
                  isSelected: selectedIconName == icon.systemImage
                ) {
                  selectedIconName = icon.systemImage
                }
              }
            }
          }

          NativeProjectCreatorSection(title: "시스템 프롬프트") {
            ZStack(alignment: .topLeading) {
              TextEditor(text: $systemPrompt)
                .focused($focusedField, equals: .systemPrompt)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 168)

              if systemPrompt.isEmpty {
                Text("이 프로젝트에서 항상 적용할 지침을 입력하세요.")
                  .font(.system(size: 16, weight: .regular))
                  .foregroundColor(.black.opacity(0.35))
                  .padding(.horizontal, 17)
                  .padding(.vertical, 18)
                  .allowsHitTesting(false)
              }
            }
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 34)
      }
      .background(Color.white)
      .navigationTitle("새 프로젝트")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
          .foregroundColor(.black)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("생성", action: createProject)
            .fontWeight(.semibold)
            .foregroundColor(canCreate ? .black : .black.opacity(0.3))
            .disabled(!canCreate)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          focusedField = .title
        }
      }
    }
  }

  private func createProject() {
    guard canCreate else {
      return
    }
    store.createProject(
      title: projectTitle,
      iconName: selectedIconName,
      systemPrompt: systemPrompt
    )
    dismiss()
  }
}

private struct NativeProjectCreatorSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.black.opacity(0.58))

      content
    }
  }
}

private struct NativeProjectIconOption: View {
  var icon: NativeProjectIcon
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon.systemImage)
          .font(.system(size: 19, weight: .semibold))
        Text(icon.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
      }
      .foregroundColor(isSelected ? .white : .black)
      .frame(maxWidth: .infinity)
      .frame(height: 78)
      .background(isSelected ? Color.black : Color.black.opacity(0.04))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(isSelected ? Color.black : Color.black.opacity(0.08), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

private struct NativeSessionsSearchPill: View {
  @Binding var searchText: String
  var onSettingsPress: () -> Void
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 10) {
      Button {
        isFocused = true
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 21, weight: .semibold))
          .foregroundColor(.black)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("대화 검색")

      if isFocused || !searchText.isEmpty {
        TextField("검색", text: $searchText)
          .focused($isFocused)
          .font(.system(size: 14, weight: .medium))
          .frame(width: 74)
          .textInputAutocapitalization(.never)
      }

      Button(action: onSettingsPress) {
        Image(systemName: "gearshape")
          .font(.system(size: 19, weight: .semibold))
          .foregroundColor(.black)
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("설정 열기")
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .frame(height: 52)
    .background(Color.white)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.1), radius: 22, x: 0, y: 12)
  }
}

private struct NativeSessionsSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.black)

      VStack(alignment: .leading, spacing: 20) {
        content
      }
    }
  }
}

private struct NativeSessionsIconRow: View {
  var systemImage: String
  var title: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.system(size: 19, weight: .semibold))
        .foregroundColor(.black)
        .frame(width: 30, height: 24)

      Text(title)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.black)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}

private struct NativeSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Image("OpenEdgeLogo")
              .resizable()
              .scaledToFit()
              .frame(width: 164, height: 42, alignment: .leading)
              .accessibilityLabel("Open Edge AI")

            Text("iOS native")
              .font(.system(size: 13))
              .foregroundColor(.black.opacity(0.55))
          }
          .padding(.vertical, 2)
        }

        Section("설정") {
          NavigationLink {
            NativeModelSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "cpu",
              title: "모델",
              detail: store.selectedModel.title
            )
          }

          NavigationLink {
            NativePersonalSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "person.crop.circle",
              title: "개인 맞춤 설정",
              detail: "이름, 성격, 메모리"
            )
          }

          NavigationLink {
            NativeAppInfoSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "info.circle",
              title: "정보",
              detail: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
            )
          }
        }
      }
      .navigationTitle("설정")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("완료") {
            store.saveSettings()
            dismiss()
          }
        }
      }
    }
  }
}

private struct NativeSettingsNavigationRow: View {
  var icon: String
  var title: String
  var detail: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.black)
        .frame(width: 28, height: 28)

      Text(title)
        .foregroundColor(.black)

      Spacer()

      Text(detail)
        .font(.system(size: 13))
        .foregroundColor(.black.opacity(0.45))
        .lineLimit(1)
    }
  }
}

private struct NativeModelSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    List {
      Section {
        ForEach(NativeModel.allCases) { model in
          let status = store.modelStatuses[model] ?? NativeModelStatus(model: model)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                  .font(.system(size: 16, weight: .semibold))
                Text(model.subtitle)
                  .font(.system(size: 13))
                  .foregroundColor(.black.opacity(0.55))
              }
              Spacer()
              if store.selectedModel == model {
                Image(systemName: "checkmark.circle.fill")
              }
            }

            if status.downloading {
              ProgressView(value: status.progress)
                .tint(.black)
            }

            if let error = status.error, !status.installed {
              Text(error)
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.55))
            }

            HStack {
              Button("선택") {
                store.selectedModel = model
                store.saveSettings()
                store.loadSelectedModel()
              }
              .buttonStyle(.bordered)
              .tint(.black)

              if model == .gemma && !status.installed {
                Button(status.downloading ? "다운로드 중" : "다운로드") {
                  store.downloadGemma()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(status.downloading)
              }
            }
          }
        }
      }
    }
    .navigationTitle("모델")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct NativePersonalSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore
  private let personalities = ["Balanced", "Direct", "Friendly", "Creative", "Precise"]

  var body: some View {
    List {
      Section("기본 정보") {
        TextField("이름", text: $store.userName)
        Picker("성격", selection: $store.personality) {
          ForEach(personalities, id: \.self) { personality in
            Text(personality).tag(personality)
          }
        }
      }

      Section("메모리") {
        Toggle("메모리 활성", isOn: $store.memoryEnabled)
          .tint(.black)
      }

      Section("맞춤형 지침") {
        TextEditor(text: $store.systemPrompt)
          .frame(minHeight: 160)
      }
    }
    .navigationTitle("개인 맞춤 설정")
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      store.saveSettings()
    }
  }
}

private struct NativeAppInfoSettingsView: View {
  var body: some View {
    List {
      Section("지원") {
        Link("문제 신고하기", destination: URL(string: "https://github.com/open-edge-ai-app/core-app/issues")!)
        Link("기여하기", destination: URL(string: "https://github.com/open-edge-ai-app/core-app")!)
      }

      Section("앱 정보") {
        HStack {
          Text("버전")
          Spacer()
          Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1")
            .foregroundColor(.black.opacity(0.55))
        }
        HStack {
          Text("플랫폼")
          Spacer()
          Text("iOS native")
            .foregroundColor(.black.opacity(0.55))
        }
      }
    }
    .navigationTitle("정보")
    .navigationBarTitleDisplayMode(.inline)
  }
}
