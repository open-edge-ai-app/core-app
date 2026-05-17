import SwiftUI
import UIKit
import UniformTypeIdentifiers

private extension Color {
  static var oeBackground: Color { Color(.systemBackground) }
  static var oeGroupedBackground: Color { Color(.systemGroupedBackground) }
  static var oeSurface: Color { Color(.secondarySystemBackground) }
  static var oeElevatedSurface: Color { Color(.tertiarySystemBackground) }
  static var oeText: Color { .primary }
  static var oeSecondaryText: Color { .primary.opacity(0.62) }
  static var oeMutedText: Color { .primary.opacity(0.45) }
  static var oeSubtleFill: Color { .primary.opacity(0.055) }
  static var oeBorder: Color { .primary.opacity(0.10) }
  static var oeControlFill: Color { .primary }
  static var oeControlText: Color { Color(.systemBackground) }
}

@main
struct OpenEdgeAIApp: App {
  @StateObject private var store = NativeChatStore()

  var body: some Scene {
    WindowGroup {
      NativeRootView()
        .environmentObject(store)
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .tint(store.accentColor.color)
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

private enum NativeFontSizeSetting: String, CaseIterable, Identifiable {
  case small
  case standard
  case large

  var id: String { rawValue }

  var title: String {
    switch self {
    case .small:
      return "작게"
    case .standard:
      return "기본"
    case .large:
      return "크게"
    }
  }

  var bodySize: CGFloat {
    switch self {
    case .small:
      return 15
    case .standard:
      return 16
    case .large:
      return 18
    }
  }

  var inputSize: CGFloat {
    switch self {
    case .small:
      return 15
    case .standard:
      return 16
    case .large:
      return 17
    }
  }

  var sliderValue: Double {
    switch self {
    case .small:
      return 0
    case .standard:
      return 1
    case .large:
      return 2
    }
  }

  init(sliderValue: Double) {
    switch Int(sliderValue.rounded()) {
    case 0:
      self = .small
    case 2:
      self = .large
    default:
      self = .standard
    }
  }
}

private enum NativeAppearanceMode: String, CaseIterable, Identifiable {
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .light:
      return "화이트 모드"
    case .dark:
      return "다크 모드"
    }
  }

  var colorScheme: ColorScheme {
    switch self {
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}

private enum NativeAccentColor: String, CaseIterable, Identifiable {
  case black
  case blue
  case green
  case purple
  case orange

  var id: String { rawValue }

  var title: String {
    switch self {
    case .black:
      return "검정"
    case .blue:
      return "파랑"
    case .green:
      return "초록"
    case .purple:
      return "보라"
    case .orange:
      return "주황"
    }
  }

  var color: Color {
    switch self {
    case .black:
      return .primary
    case .blue:
      return .blue
    case .green:
      return .green
    case .purple:
      return .purple
    case .orange:
      return .orange
    }
  }

  var foregroundColor: Color {
    switch self {
    case .black:
      return .oeControlText
    case .green, .orange:
      return .black
    case .blue, .purple:
      return .white
    }
  }

  var subtleColor: Color {
    color.opacity(0.12)
  }
}

private enum NativeLanguage: String, CaseIterable, Identifiable {
  case korean = "ko"
  case english = "en"
  case simplifiedChinese = "zh-Hans"
  case hindi = "hi"
  case spanish = "es"
  case french = "fr"
  case arabic = "ar"
  case bengali = "bn"
  case russian = "ru"
  case portuguese = "pt"
  case urdu = "ur"
  case indonesian = "id"
  case german = "de"
  case japanese = "ja"
  case turkish = "tr"

  var id: String { rawValue }

  var nativeName: String {
    switch self {
    case .korean:
      return "한국어"
    case .english:
      return "English"
    case .simplifiedChinese:
      return "简体中文"
    case .hindi:
      return "हिन्दी"
    case .spanish:
      return "Español"
    case .french:
      return "Français"
    case .arabic:
      return "العربية"
    case .bengali:
      return "বাংলা"
    case .russian:
      return "Русский"
    case .portuguese:
      return "Português"
    case .urdu:
      return "اردو"
    case .indonesian:
      return "Bahasa Indonesia"
    case .german:
      return "Deutsch"
    case .japanese:
      return "日本語"
    case .turkish:
      return "Türkçe"
    }
  }

  var englishName: String {
    switch self {
    case .korean:
      return "Korean"
    case .english:
      return "English"
    case .simplifiedChinese:
      return "Chinese (Simplified)"
    case .hindi:
      return "Hindi"
    case .spanish:
      return "Spanish"
    case .french:
      return "French"
    case .arabic:
      return "Arabic"
    case .bengali:
      return "Bengali"
    case .russian:
      return "Russian"
    case .portuguese:
      return "Portuguese"
    case .urdu:
      return "Urdu"
    case .indonesian:
      return "Indonesian"
    case .german:
      return "German"
    case .japanese:
      return "Japanese"
    case .turkish:
      return "Turkish"
    }
  }

  var localeIdentifier: String {
    switch self {
    case .korean:
      return "ko_KR"
    case .english:
      return "en_US"
    case .simplifiedChinese:
      return "zh_Hans_CN"
    case .hindi:
      return "hi_IN"
    case .spanish:
      return "es_ES"
    case .french:
      return "fr_FR"
    case .arabic:
      return "ar_SA"
    case .bengali:
      return "bn_BD"
    case .russian:
      return "ru_RU"
    case .portuguese:
      return "pt_BR"
    case .urdu:
      return "ur_PK"
    case .indonesian:
      return "id_ID"
    case .german:
      return "de_DE"
    case .japanese:
      return "ja_JP"
    case .turkish:
      return "tr_TR"
    }
  }
}

private enum NativeDynamicIslandPet: String, CaseIterable, Identifiable {
  case codex
  case stacky
  case nullSignal

  var id: String { rawValue }

  var title: String {
    switch self {
    case .codex:
      return "Codex"
    case .stacky:
      return "Stacky"
    case .nullSignal:
      return "Null Signal"
    }
  }

  var subtitle: String {
    switch self {
    case .codex:
      return "작업을 따라 뛰는 기본 픽셀 펫"
    case .stacky:
      return "차분하게 쌓아 올리는 스택 펫"
    case .nullSignal:
      return "조용히 신호를 기다리는 모노 펫"
    }
  }

  var primaryColor: Color {
    switch self {
    case .codex:
      return Color.white
    case .stacky:
      return Color(white: 0.78)
    case .nullSignal:
      return Color(white: 0.18)
    }
  }

  var secondaryColor: Color {
    switch self {
    case .codex:
      return Color(white: 0.52)
    case .stacky:
      return Color.white
    case .nullSignal:
      return Color(white: 0.72)
    }
  }

  var eyeColor: Color {
    switch self {
    case .nullSignal:
      return Color.white
    default:
      return Color.black
    }
  }
}

private enum NativeDynamicIslandPetMotion: String {
  case running
  case resting
  case sleeping
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
  @Published var fontSizeSetting: NativeFontSizeSetting = .standard
  @Published var appearanceMode: NativeAppearanceMode = .light
  @Published var accentColor: NativeAccentColor = .black
  @Published var selectedLanguage: NativeLanguage = .korean
  @Published var backgroundExecutionEnabled = false
  @Published var backgroundDynamicIslandEnabled = true
  @Published var dynamicIslandPetEnabled = false
  @Published var selectedDynamicIslandPet: NativeDynamicIslandPet = .codex
  @Published var dynamicIslandActivityHold = false

  private let storageKey = "OpenEdgeAI.NativeChatSessions.v1"
  private let projectsStorageKey = "OpenEdgeAI.NativeProjects.v1"
  private let settingsKey = "OpenEdgeAI.NativeSettings.v1"
  private let currentSettingsSchemaVersion = 2
  private var activeAssistantMessageId: String?
  private var activeRequestSessionId: String?
  private var generationBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

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

  var showsDynamicIslandActivity: Bool {
    backgroundDynamicIslandEnabled && (isGenerating || !queuedDrafts.isEmpty || dynamicIslandActivityHold)
  }

  var dynamicIslandTitle: String {
    if isGenerating && !queuedDrafts.isEmpty {
      return "후속 질문 자동 실행 중"
    }
    if isGenerating {
      return "\(selectedModel.title) 응답 중"
    }
    if dynamicIslandActivityHold {
      return "응답 완료"
    }
    return "후속 질문 실행 준비"
  }

  var dynamicIslandSubtitle: String {
    if let nextDraft = queuedDrafts.first {
      return "다음: \(clippedDynamicIslandText(nextDraft.text))"
    }
    return currentSession?.title ?? "Open Edge AI"
  }

  var dynamicIslandDetail: String {
    if isGenerating {
      if queuedDrafts.isEmpty {
        return "현재 대화에서 \(selectedModel.title) 응답을 생성하고 있습니다."
      }
      return "현재 응답 생성 후 후속 질문 \(queuedDrafts.count)개를 이어서 실행합니다."
    }
    if !queuedDrafts.isEmpty {
      return "후속 질문 \(queuedDrafts.count)개가 대기열에 있습니다."
    }
    if dynamicIslandActivityHold {
      return "마지막 응답이 완료되었습니다."
    }
    return "Open Edge AI가 다음 작업을 기다리는 중입니다."
  }

  var dynamicIslandProgress: Double {
    if isGenerating {
      return queuedDrafts.isEmpty ? 0.64 : 0.72
    }
    if !queuedDrafts.isEmpty {
      return 0.28
    }
    if dynamicIslandActivityHold {
      return 1
    }
    return 0.12
  }

  var dynamicIslandPetMotion: NativeDynamicIslandPetMotion {
    if isGenerating {
      return .running
    }
    if dynamicIslandActivityHold {
      return .sleeping
    }
    return .resting
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
      presentDynamicIslandActivity()
      return
    }

    send(draft)
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
      createdAt: Date()
    )
    let historyMessages = Array(session.messages[..<assistantIndex])

    rewrite(draft, replacingAssistantId: message.id, in: session.id, historyMessages: historyMessages)
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
    endGenerationBackgroundTaskIfNeeded()
    presentDynamicIslandActivity()
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
    presentDynamicIslandActivity()

    let prompt = makePrompt(for: sessionId, draft: draft)
    streamResponse(prompt: prompt, assistantId: assistantMessage.id, sessionId: sessionId)
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
    presentDynamicIslandActivity()

    let prompt = makePrompt(for: sessionId, draft: draft, historyMessages: historyMessages)
    streamResponse(prompt: prompt, assistantId: assistantId, sessionId: sessionId)
  }

  private func streamResponse(prompt: String, assistantId: String, sessionId: String) {
    let model = selectedModel

    if model == .gemma {
      AIEngineGemmaModelClient.shared.streamResponse(prompt: prompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantId, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantId, sessionId: sessionId)
        }
      }
    } else {
      AIEngineFoundationModelClient.shared.streamResponse(prompt: prompt) { [weak self] chunk in
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
    endGenerationBackgroundTaskIfNeeded()

    scheduleNextQueuedDraft()
    presentDynamicIslandActivity()
  }

  private func makePrompt(for sessionId: String, draft: NativeDraft, historyMessages: [NativeMessage]? = nil) -> String {
    let session = sessions.first { $0.id == sessionId }
    let sourceHistory: [NativeMessage]
    if let historyMessages {
      sourceHistory = historyMessages
    } else if let session {
      sourceHistory = Array(session.messages.dropLast())
    } else {
      sourceHistory = []
    }
    let history = sourceHistory.suffix(16)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: selectedLanguage.localeIdentifier)
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
    if let raw = data["selectedDynamicIslandPet"] as? String,
       let pet = NativeDynamicIslandPet(rawValue: raw) {
      selectedDynamicIslandPet = pet
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

    if backgroundDynamicIslandEnabled {
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 450_000_000)
        self.runQueuedDraftIfReady()
      }
    } else {
      runQueuedDraftIfReady()
    }
  }

  private func clippedDynamicIslandText(_ text: String) -> String {
    let cleaned = text
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return "첨부 파일"
    }
    return cleaned.count > 24 ? "\(cleaned.prefix(24))..." : cleaned
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

  func dismissDynamicIslandActivity() {
    dynamicIslandActivityHold = false
    syncDynamicIslandLiveActivity()
  }

  func refreshDynamicIslandActivity() {
    if showsDynamicIslandActivity {
      presentDynamicIslandActivity()
    } else {
      syncDynamicIslandLiveActivity()
    }
  }

  func refreshBackgroundExecutionState() {
    if backgroundExecutionEnabled, isGenerating {
      beginGenerationBackgroundTaskIfNeeded()
    } else {
      endGenerationBackgroundTaskIfNeeded()
    }
  }

  private func presentDynamicIslandActivity() {
    guard backgroundDynamicIslandEnabled else {
      dynamicIslandActivityHold = false
      syncDynamicIslandLiveActivity()
      return
    }

    dynamicIslandActivityHold = true
    syncDynamicIslandLiveActivity()
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 12_000_000_000)
      if !self.isGenerating && self.queuedDrafts.isEmpty {
        self.dynamicIslandActivityHold = false
        self.syncDynamicIslandLiveActivity()
      }
    }
  }

  private func syncDynamicIslandLiveActivity() {
    NativeDynamicIslandLiveActivityController.shared.sync(
      enabled: backgroundDynamicIslandEnabled,
      isVisible: showsDynamicIslandActivity,
      sessionId: selectedSessionId ?? "open-edge-ai",
      title: dynamicIslandTitle,
      subtitle: dynamicIslandSubtitle,
      pet: selectedDynamicIslandPet.rawValue,
      petEnabled: dynamicIslandPetEnabled,
      motion: dynamicIslandPetMotion.rawValue,
      queuedCount: queuedDrafts.count,
      progress: dynamicIslandProgress,
      detail: dynamicIslandDetail
    )
  }

  private func beginGenerationBackgroundTaskIfNeeded() {
    guard backgroundExecutionEnabled,
          generationBackgroundTaskIdentifier == .invalid
    else {
      return
    }

    generationBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
      withName: "OpenEdgeAI.Generation"
    ) { [weak self] in
      Task { @MainActor in
        self?.endGenerationBackgroundTaskIfNeeded()
      }
    }
  }

  private func endGenerationBackgroundTaskIfNeeded() {
    guard generationBackgroundTaskIdentifier != .invalid else {
      return
    }

    let identifier = generationBackgroundTaskIdentifier
    generationBackgroundTaskIdentifier = .invalid
    UIApplication.shared.endBackgroundTask(identifier)
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
        .zIndex(2)

        if store.showsDynamicIslandActivity {
          NativeDynamicIslandActivityView()
            .environmentObject(store)
            .padding(.bottom, 8)
            .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
            .zIndex(2)
        }

        Divider()
        NativeChatTranscript()
        NativeInputBar(showingFileImporter: $showingFileImporter)
      }
      .background(Color.oeBackground)

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
    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.showsDynamicIslandActivity)
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

private struct NativeDynamicIslandActivityView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    HStack(spacing: 10) {
      if store.dynamicIslandPetEnabled {
        NativeDynamicIslandPetView(
          pet: store.selectedDynamicIslandPet,
          motion: store.dynamicIslandPetMotion,
          size: 34
        )
      } else {
        NativeDynamicIslandLogoView(size: 30)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(store.dynamicIslandTitle)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(store.dynamicIslandSubtitle)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.white.opacity(0.66))
          .lineLimit(1)
      }

      Spacer(minLength: 6)

      NativeDynamicIslandProgressRing(
        progress: store.dynamicIslandProgress,
        isActive: store.isGenerating,
        size: 25,
        lineWidth: 3
      )
    }
    .padding(.horizontal, 13)
    .frame(width: store.dynamicIslandPetEnabled ? 286 : 262, height: 54)
    .background(Color.black)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 9)
    .accessibilityLabel("\(store.dynamicIslandTitle), \(store.dynamicIslandSubtitle)")
    .allowsHitTesting(false)
  }
}

private struct NativeDynamicIslandLogoView: View {
  var size: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        .stroke(Color.white.opacity(0.86), lineWidth: max(1.2, size * 0.07))
        .rotationEffect(.degrees(-14))

      Text("OE")
        .font(.system(size: size * 0.34, weight: .black, design: .rounded))
        .foregroundColor(.white)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct NativeDynamicIslandProgressRing: View {
  var progress: Double
  var isActive: Bool
  var size: CGFloat
  var lineWidth: CGFloat

  private var clampedProgress: Double {
    min(max(progress, 0.08), 1)
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.18), lineWidth: lineWidth)

      Circle()
        .trim(from: 0, to: clampedProgress)
        .stroke(
          Color.white.opacity(isActive ? 1 : 0.78),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct NativeDynamicIslandPetView: View {
  var pet: NativeDynamicIslandPet
  var motion: NativeDynamicIslandPetMotion
  var size: CGFloat
  @State private var phase = false

  private var rows: [[Int]] {
    switch pet {
    case .codex:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 1, 1, 1, 2, 0],
        [2, 1, 4, 1, 4, 1, 2],
        [2, 1, 1, 3, 1, 1, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 0, 2, 3, 2, 0, 0],
        [0, 2, 0, 0, 0, 2, 0]
      ]
    case .stacky:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 3, 3, 3, 2, 0],
        [2, 3, 4, 3, 4, 3, 2],
        [2, 1, 1, 1, 1, 1, 2],
        [2, 3, 3, 3, 3, 3, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 2, 0, 0, 0, 2, 0]
      ]
    case .nullSignal:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 1, 1, 1, 2, 0],
        [2, 1, 4, 1, 4, 1, 2],
        [2, 1, 1, 2, 1, 1, 2],
        [2, 1, 3, 3, 3, 1, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 0, 2, 0, 2, 0, 0]
      ]
    }
  }

  private var pixelSize: CGFloat {
    size / 7
  }

  private var bodyOffset: CGFloat {
    switch motion {
    case .running:
      return phase ? -3 : 2
    case .resting:
      return phase ? -1 : 1
    case .sleeping:
      return 1
    }
  }

  private var tilt: Double {
    switch motion {
    case .running:
      return phase ? -7 : 7
    case .resting:
      return phase ? -2 : 2
    case .sleeping:
      return -4
    }
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(spacing: 0) {
        ForEach(rows.indices, id: \.self) { rowIndex in
          HStack(spacing: 0) {
            ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
              Rectangle()
                .fill(color(for: rows[rowIndex][columnIndex]))
                .frame(width: pixelSize, height: pixelSize)
            }
          }
        }
      }
      .frame(width: size, height: size)
      .offset(y: bodyOffset)
      .rotationEffect(.degrees(tilt))
      .animation(.easeInOut(duration: motion == .running ? 0.28 : 0.9).repeatForever(autoreverses: true), value: phase)

      if motion == .sleeping {
        Text("Z")
          .font(.system(size: 9, weight: .black, design: .monospaced))
          .foregroundColor(.white.opacity(0.78))
          .offset(x: 7, y: -6)
      }
    }
    .frame(width: size + 8, height: size + 6)
    .onAppear {
      phase = true
    }
    .onChange(of: motion) { _, _ in
      phase.toggle()
    }
    .accessibilityHidden(true)
  }

  private func color(for value: Int) -> Color {
    switch value {
    case 1:
      return pet.primaryColor
    case 2:
      return pet.eyeColor.opacity(pet == .nullSignal ? 0.9 : 1)
    case 3:
      return pet.secondaryColor
    case 4:
      return pet.eyeColor
    default:
      return Color.clear
    }
  }
}

private struct NativeDynamicIslandPulseView: View {
  var isActive: Bool
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.18), lineWidth: 1)
        .frame(width: 24, height: 24)

      Circle()
        .fill(Color.white.opacity(isActive ? 0.28 : 0.18))
        .frame(width: 24, height: 24)
        .scaleEffect(isActive && isAnimating ? 1.18 : 0.76)
        .opacity(isActive && isAnimating ? 0.1 : 0.24)

      Circle()
        .fill(Color.white)
        .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
        .scaleEffect(isActive && isAnimating ? 0.72 : 1)
    }
    .frame(width: 28, height: 28)
    .onAppear {
      withAnimation(.easeInOut(duration: 0.92).repeatForever(autoreverses: true)) {
        isAnimating = true
      }
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
              .fill(store.accentColor.color)
            Image(systemName: "sparkles")
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(store.accentColor.foregroundColor)
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
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(Color.oeBackground)
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
      .foregroundColor(.oeText)
      .padding(.horizontal, 10)
      .frame(height: 34)
      .overlay(
        RoundedRectangle(cornerRadius: 17)
          .stroke(store.accentColor.color.opacity(0.28), lineWidth: 1)
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
      .background(Color.oeBackground)
      .onChange(of: store.currentMessages) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("bottom", anchor: .bottom)
        }
      }
    }
  }
}

private struct NativeEmptyChatView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Open Edge AI")
        .font(.system(size: store.fontSizeSetting.bodySize + 12, weight: .bold))
      Text("기기 안에서 실행되는 AI와 대화를 시작하세요.")
        .font(.system(size: store.fontSizeSetting.bodySize))
        .foregroundColor(.oeSecondaryText)
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
          .font(.system(size: store.fontSizeSetting.bodySize))
          .foregroundColor(store.accentColor.foregroundColor)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(store.accentColor.color)
          .clipShape(RoundedRectangle(cornerRadius: 18))
          .frame(maxWidth: .infinity, alignment: .trailing)
          .textSelection(.enabled)
      } else {
        NativeMarkdownText(text: message.text.isEmpty ? "응답 준비 중..." : message.text)
          .font(.system(size: store.fontSizeSetting.bodySize))
          .foregroundColor(.oeText)
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
          .disabled(store.isGenerating)

          Text(message.createdAt.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 12))
            .foregroundColor(.oeMutedText)
        }
        .buttonStyle(.plain)
        .foregroundColor(store.accentColor.color)
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
  @EnvironmentObject private var store: NativeChatStore
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
        .foregroundColor(store.accentColor.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(store.accentColor.subtleColor)
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
              .foregroundColor(store.accentColor.color)
              .padding(.horizontal, 10)
              .padding(.vertical, 7)
              .background(store.accentColor.subtleColor)
              .clipShape(Capsule())
            }
          }
        }
      }

      VStack(spacing: 6) {
        ZStack(alignment: .topLeading) {
          TextEditor(text: $store.inputText)
            .font(.system(size: store.fontSizeSetting.inputSize))
            .foregroundColor(.oeText)
            .tint(store.accentColor.color)
            .focused($focused)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 64, maxHeight: 122)

          if store.inputText.isEmpty {
            Text("무엇이든 묻거나 검색하고 만들어보세요...")
              .font(.system(size: store.fontSizeSetting.inputSize))
              .foregroundColor(.oeText.opacity(0.35))
              .padding(.top, 8)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }

        HStack(spacing: 8) {
          Button {
            showingFileImporter = true
          } label: {
            Image(systemName: "paperclip")
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(store.accentColor.color)
              .frame(width: 36, height: 34)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("파일 첨부")

          Spacer(minLength: 8)

          Button {
            if store.isGenerating && !store.canSend {
              store.cancelGeneration()
            } else {
              store.sendCurrentInput()
            }
          } label: {
            Image(systemName: store.isGenerating && !store.canSend ? "stop.fill" : "arrow.up")
              .font(.system(size: 15, weight: .bold))
              .foregroundColor(store.accentColor.foregroundColor)
              .frame(width: 36, height: 36)
              .background(store.accentColor.color)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .disabled(!store.isGenerating && !store.canSend)
          .opacity(!store.isGenerating && !store.canSend ? 0.35 : 1)
          .accessibilityLabel(store.isGenerating && !store.canSend ? "응답 중지" : "메시지 보내기")
        }
      }
      .padding(.horizontal, 10)
      .padding(.top, 8)
      .padding(.bottom, 8)
      .background(Color.oeSurface)
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(store.accentColor.color.opacity(focused ? 0.42 : 0.18), lineWidth: focused ? 1.4 : 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
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
        .background(store.accentColor.subtleColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}

private struct NativeSessionsView: View {
  @Binding var isPresented: Bool
  @Binding var showingSettings: Bool
  @EnvironmentObject private var store: NativeChatStore
  @State private var isSearchPresented = false
  @State private var isProjectCreatorPresented = false
  @State private var renameTarget: NativeRenameTarget?

  private var recentSessions: [NativeChatSession] {
    store.sessions.sorted { $0.updatedAt > $1.updatedAt }
  }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .center, spacing: 16) {
          Image("OpenEdgeLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.oeText)
            .frame(width: 160, height: 40, alignment: .leading)
            .accessibilityLabel("Open Edge AI")

          Spacer(minLength: 12)

          NativeSessionsSearchPill(
            onSearchPress: openSearch,
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
                  .foregroundColor(.oeMutedText)
                  .padding(.vertical, 6)
              } else {
                VStack(alignment: .leading, spacing: 2) {
                  ForEach(recentSessions) { session in
                    Button {
                      store.selectSession(session)
                      close()
                    } label: {
                      NativeSessionListRow(title: session.title)
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
        .foregroundColor(store.accentColor.foregroundColor)
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(store.accentColor.color)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("새 채팅")
      .padding(.trailing, 34)
      .padding(.bottom, 34)
    }
    .background(Color.oeBackground)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $isProjectCreatorPresented) {
      NativeProjectCreatorView()
        .environmentObject(store)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $isSearchPresented) {
      NativeSearchView { session in
        store.selectSession(session)
        close()
      }
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

  private func openSearch() {
    isSearchPresented = true
  }
}

private struct NativeSessionListRow: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.system(size: 16, weight: .regular))
      .foregroundColor(.oeText)
      .lineLimit(1)
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
  }
}

private struct NativeSearchResult: Identifiable {
  enum Kind {
    case session(NativeChatSession)
    case project(NativeProject)
  }

  var id: String
  var title: String
  var subtitle: String
  var systemImage: String
  var kind: Kind
}

private struct NativeSearchView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  var onSelectSession: (NativeChatSession) -> Void
  @State private var query = ""
  @FocusState private var isSearchFocused: Bool

  private var normalizedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var searchResults: [NativeSearchResult] {
    let query = normalizedQuery
    guard !query.isEmpty else {
      return []
    }

    let projectResults = store.projects
      .sorted { $0.createdAt > $1.createdAt }
      .filter { project in
        project.title.localizedCaseInsensitiveContains(query)
          || project.systemPrompt.localizedCaseInsensitiveContains(query)
      }
      .map { project in
        NativeSearchResult(
          id: "project-\(project.id)",
          title: project.title,
          subtitle: project.systemPrompt.isEmpty ? "프로젝트" : clipped(project.systemPrompt),
          systemImage: project.iconName,
          kind: .project(project)
        )
      }

    let sessionResults = store.sessions
      .sorted { $0.updatedAt > $1.updatedAt }
      .filter { session in
        session.title.localizedCaseInsensitiveContains(query)
          || session.messages.contains { message in
            message.text.localizedCaseInsensitiveContains(query)
              || message.attachments.contains { attachment in
                attachment.name.localizedCaseInsensitiveContains(query)
              }
          }
      }
      .map { session in
        let matchingMessage = session.messages.first { message in
          message.text.localizedCaseInsensitiveContains(query)
            || message.attachments.contains { attachment in
              attachment.name.localizedCaseInsensitiveContains(query)
            }
        }
        return NativeSearchResult(
          id: "session-\(session.id)",
          title: session.title,
          subtitle: clipped(matchingMessage?.text ?? session.updatedAt.formatted(date: .abbreviated, time: .shortened)),
          systemImage: "bubble.left.and.bubble.right",
          kind: .session(session)
        )
      }

    return projectResults + sessionResults
  }

  private var recentSessions: [NativeChatSession] {
    Array(store.sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(8))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.oeSecondaryText)

          TextField("검색", text: $query)
            .focused($isSearchFocused)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.oeText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.oeText.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("검색어 지우기")
          }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.oeSubtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 24) {
            if normalizedQuery.isEmpty {
              NativeSearchSection(title: "최근 대화") {
                if recentSessions.isEmpty {
                  NativeSearchEmptyState(text: "최근 대화가 없습니다")
                } else {
                  ForEach(recentSessions) { session in
                    NativeSearchSessionButton(session: session, subtitle: session.updatedAt.formatted(date: .abbreviated, time: .shortened)) {
                      select(session)
                    }
                  }
                }
              }
            } else if searchResults.isEmpty {
              NativeSearchEmptyState(text: "검색 결과가 없습니다")
                .padding(.top, 80)
            } else {
              NativeSearchSection(title: "검색 결과") {
                ForEach(searchResults) { result in
                  NativeSearchResultRow(result: result) {
                    if case .session(let session) = result.kind {
                      select(session)
                    }
                  }
                }
              }
            }
          }
          .padding(.horizontal, 22)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
      }
      .background(Color.oeBackground)
      .navigationTitle("검색")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기") {
            dismiss()
          }
          .foregroundColor(.oeText)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          isSearchFocused = true
        }
      }
    }
  }

  private func select(_ session: NativeChatSession) {
    dismiss()
    onSelectSession(session)
  }

  private func clipped(_ text: String) -> String {
    let cleaned = text
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return "대화"
    }
    return cleaned.count > 92 ? "\(cleaned.prefix(92))..." : cleaned
  }
}

private struct NativeSearchSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.oeSecondaryText)

      VStack(alignment: .leading, spacing: 12) {
        content
      }
    }
  }
}

private struct NativeSearchSessionButton: View {
  var session: NativeChatSession
  var subtitle: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      NativeSearchRowContent(
        systemImage: "bubble.left.and.bubble.right",
        title: session.title,
        subtitle: subtitle,
        showsChevron: true
      )
    }
    .buttonStyle(.plain)
  }
}

private struct NativeSearchResultRow: View {
  var result: NativeSearchResult
  var action: () -> Void

  var body: some View {
    switch result.kind {
    case .session:
      Button(action: action) {
        NativeSearchRowContent(
          systemImage: result.systemImage,
          title: result.title,
          subtitle: result.subtitle,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)
    case .project:
      NativeSearchRowContent(
        systemImage: result.systemImage,
        title: result.title,
        subtitle: result.subtitle,
        showsChevron: false
      )
    }
  }
}

private struct NativeSearchRowContent: View {
  var systemImage: String
  var title: String
  var subtitle: String
  var showsChevron: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeText)
          .lineLimit(1)

        Text(subtitle)
          .font(.system(size: 13, weight: .regular))
          .foregroundColor(.oeMutedText)
          .lineLimit(2)
      }

      Spacer(minLength: 8)

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.oeText.opacity(0.25))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.oeSubtleFill)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .contentShape(Rectangle())
  }
}

private struct NativeSearchEmptyState: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.system(size: 15, weight: .medium))
      .foregroundColor(.oeMutedText)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.vertical, 24)
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
          .foregroundColor(.oeSecondaryText)

        TextField(target.placeholder, text: $title)
          .focused($isFocused)
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(.oeText)
          .textInputAutocapitalization(.sentences)
          .padding(.horizontal, 16)
          .frame(height: 54)
          .background(Color.oeSubtleFill)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 24)
      .padding(.top, 24)
      .background(Color.oeBackground)
      .navigationTitle(target.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
          .foregroundColor(.oeText)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("저장", action: save)
            .fontWeight(.semibold)
            .foregroundColor(canSave ? store.accentColor.color : Color.oeText.opacity(0.3))
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
              .foregroundColor(.oeText)
              .textInputAutocapitalization(.words)
              .padding(.horizontal, 16)
              .frame(height: 54)
              .background(Color.oeSubtleFill)
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
                  isSelected: selectedIconName == icon.systemImage,
                  accentColor: store.accentColor
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
                .foregroundColor(.oeText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 168)

              if systemPrompt.isEmpty {
                Text("이 프로젝트에서 항상 적용할 지침을 입력하세요.")
                  .font(.system(size: 16, weight: .regular))
                  .foregroundColor(.oeText.opacity(0.35))
                  .padding(.horizontal, 17)
                  .padding(.vertical, 18)
                  .allowsHitTesting(false)
              }
            }
            .background(Color.oeSubtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 34)
      }
      .background(Color.oeBackground)
      .navigationTitle("새 프로젝트")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
          .foregroundColor(.oeText)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("생성", action: createProject)
            .fontWeight(.semibold)
            .foregroundColor(canCreate ? store.accentColor.color : Color.oeText.opacity(0.3))
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
        .foregroundColor(.oeSecondaryText)

      content
    }
  }
}

private struct NativeProjectIconOption: View {
  var icon: NativeProjectIcon
  var isSelected: Bool
  var accentColor: NativeAccentColor
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
      .foregroundColor(isSelected ? accentColor.foregroundColor : .oeText)
      .frame(maxWidth: .infinity)
      .frame(height: 78)
      .background(isSelected ? accentColor.color : Color.oeSubtleFill)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(isSelected ? accentColor.color : Color.oeBorder, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

private struct NativeSessionsSearchPill: View {
  @EnvironmentObject private var store: NativeChatStore
  var onSearchPress: () -> Void
  var onSettingsPress: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: onSearchPress) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 21, weight: .semibold))
          .foregroundColor(store.accentColor.color)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("대화 검색")

      Button(action: onSettingsPress) {
        Image(systemName: "gearshape")
          .font(.system(size: 19, weight: .semibold))
          .foregroundColor(store.accentColor.color)
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("설정 열기")
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .frame(height: 52)
    .background(Color.oeSurface)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 12)
  }
}

private struct NativeSessionsSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.oeText)

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
        .foregroundColor(.oeText)
        .frame(width: 30, height: 24)

      Text(title)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
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
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .foregroundStyle(Color.oeText)
              .frame(width: 164, height: 42, alignment: .leading)
              .accessibilityLabel("Open Edge AI")

            Text("iOS native")
              .font(.system(size: 13))
              .foregroundColor(.oeMutedText)
          }
          .padding(.vertical, 2)
        }

        Section("설정") {
          NavigationLink {
            NativeGeneralSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "gearshape",
              title: "일반",
              detail: store.selectedLanguage.nativeName
            )
          }

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
            NativeAppearanceSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "circle.lefthalf.filled",
              title: "모양",
              detail: "\(store.fontSizeSetting.title), \(store.appearanceMode.title)"
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
          .foregroundColor(store.accentColor.color)
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
        .foregroundColor(.oeText)
        .frame(width: 28, height: 28)

      Text(title)
        .foregroundColor(.oeText)

      Spacer()

      Text(detail)
        .font(.system(size: 13))
        .foregroundColor(.oeMutedText)
        .lineLimit(1)
    }
  }
}

private struct NativeGeneralSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    List {
      Section("백그라운드") {
        Toggle("백그라운드 실행", isOn: $store.backgroundExecutionEnabled)
          .tint(store.accentColor.color)

        Toggle("백그라운드 Dynamic Island 활성", isOn: $store.backgroundDynamicIslandEnabled)
          .tint(store.accentColor.color)
      }

      Section("Dynamic Island 펫") {
        Toggle("Dynamic Island 펫 활성", isOn: $store.dynamicIslandPetEnabled)
          .tint(store.accentColor.color)

        ForEach(NativeDynamicIslandPet.allCases) { pet in
          Button {
            store.selectedDynamicIslandPet = pet
            store.dynamicIslandPetEnabled = true
            store.saveSettings()
          } label: {
            NativeDynamicIslandPetOption(
              pet: pet,
              isSelected: store.selectedDynamicIslandPet == pet
            )
          }
          .buttonStyle(.plain)
        }
      }

      Section("언어") {
        Picker("언어", selection: $store.selectedLanguage) {
          ForEach(NativeLanguage.allCases) { language in
            Text("\(language.nativeName) · \(language.englishName)")
              .tag(language)
          }
        }
      }
    }
    .navigationTitle("일반")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: store.backgroundExecutionEnabled) { _, _ in
      store.saveSettings()
      store.refreshBackgroundExecutionState()
    }
    .onChange(of: store.backgroundDynamicIslandEnabled) { _, _ in
      store.saveSettings()
      if store.backgroundDynamicIslandEnabled {
        store.runQueuedDraftIfReady()
        store.refreshDynamicIslandActivity()
      } else {
        store.dismissDynamicIslandActivity()
      }
    }
    .onChange(of: store.dynamicIslandPetEnabled) { _, isEnabled in
      if isEnabled {
        store.backgroundDynamicIslandEnabled = true
      }
      store.saveSettings()
      store.refreshDynamicIslandActivity()
    }
    .onChange(of: store.selectedDynamicIslandPet) { _, _ in
      store.saveSettings()
      store.refreshDynamicIslandActivity()
    }
    .onChange(of: store.selectedLanguage) { _, _ in
      store.saveSettings()
    }
  }
}

private struct NativeDynamicIslandPetOption: View {
  var pet: NativeDynamicIslandPet
  var isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {
      NativeDynamicIslandPetView(
        pet: pet,
        motion: isSelected ? .running : .resting,
        size: 30
      )
      .frame(width: 42, height: 38)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(pet.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeText)

        Text(pet.subtitle)
          .font(.system(size: 12))
          .foregroundColor(.oeSecondaryText)
          .lineLimit(1)
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.oeText)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
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
                  .foregroundColor(.oeMutedText)
              }
              Spacer()
              if store.selectedModel == model {
                Image(systemName: "checkmark.circle.fill")
              }
            }

            if status.downloading {
              ProgressView(value: status.progress)
                .tint(store.accentColor.color)
            }

            if let error = status.error, !status.installed {
              Text(error)
                .font(.system(size: 12))
                .foregroundColor(.oeMutedText)
            }

            HStack {
              Button("선택") {
                store.selectedModel = model
                store.saveSettings()
                store.loadSelectedModel()
              }
              .buttonStyle(.bordered)
              .tint(store.accentColor.color)

              if model == .gemma && !status.installed {
                Button(status.downloading ? "다운로드 중" : "다운로드") {
                  store.downloadGemma()
                }
                .buttonStyle(.borderedProminent)
                .tint(store.accentColor.color)
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

private struct NativeAppearanceSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    List {
      Section("글씨 크기") {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("글씨 크기")
              .font(.system(size: 16, weight: .semibold))

            Spacer()

            Text(store.fontSizeSetting.title)
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(.oeMutedText)
          }

          Slider(
            value: Binding(
              get: { store.fontSizeSetting.sliderValue },
              set: { store.fontSizeSetting = NativeFontSizeSetting(sliderValue: $0) }
            ),
            in: 0...2,
            step: 1
          )
          .tint(store.accentColor.color)

          HStack {
            ForEach(NativeFontSizeSetting.allCases) { setting in
              Text(setting.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.oeText.opacity(store.fontSizeSetting == setting ? 0.82 : 0.36))
                .frame(maxWidth: .infinity, alignment: alignment(for: setting))
            }
          }
        }

        HStack {
          Text("미리보기")
            .font(.system(size: store.fontSizeSetting.bodySize))
          Spacer()
          Text(store.fontSizeSetting.title)
            .font(.system(size: 13))
            .foregroundColor(.oeMutedText)
        }
      }

      Section("화면 모드") {
        Picker("모드", selection: $store.appearanceMode) {
          ForEach(NativeAppearanceMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      }

      Section("강조 컬러") {
        ForEach(NativeAccentColor.allCases) { accentColor in
          Button {
            store.accentColor = accentColor
            store.saveSettings()
          } label: {
            HStack(spacing: 12) {
              Circle()
                .fill(accentColor.color)
                .frame(width: 22, height: 22)
                .overlay(
                  Circle()
                    .stroke(Color.oeBorder, lineWidth: 1)
                )

              Text(accentColor.title)
                .foregroundColor(.oeText)

              Spacer()

              if store.accentColor == accentColor {
                Image(systemName: "checkmark")
                  .font(.system(size: 14, weight: .bold))
                  .foregroundColor(store.accentColor.color)
              }
            }
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationTitle("모양")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: store.fontSizeSetting) { _, _ in
      store.saveSettings()
    }
    .onChange(of: store.appearanceMode) { _, _ in
      store.saveSettings()
    }
  }

  private func alignment(for setting: NativeFontSizeSetting) -> Alignment {
    switch setting {
    case .small:
      return .leading
    case .standard:
      return .center
    case .large:
      return .trailing
    }
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
          .tint(store.accentColor.color)
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
            .foregroundColor(.oeMutedText)
        }
        HStack {
          Text("플랫폼")
          Spacer()
          Text("iOS native")
            .foregroundColor(.oeMutedText)
        }
      }
    }
    .navigationTitle("정보")
    .navigationBarTitleDisplayMode(.inline)
  }
}
