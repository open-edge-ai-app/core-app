import React
import UIKit
import UniformTypeIdentifiers

private let aiEngineStreamEventName = "AIEngineStreamChunk"
private let aiEngineStorageKey = "OpenEdgeAI.ChatSessions.v1"
private let aiEngineDefaultChatTitle = "새 채팅"
private let aiEngineAppleModelId = "apple-foundation"
private let aiEngineGemmaModelId = "gemma-4"

private func aiEngineNowMillis() -> NSNumber {
  NSNumber(value: Int64(Date().timeIntervalSince1970 * 1000))
}

private func safeString(_ value: Any?) -> String {
  value as? String ?? ""
}

private protocol AIEngineGenerativeClient {
  func generateResponse(prompt: String, completion: @escaping (NSString?, NSString?) -> Void)
  func streamResponse(
    prompt: String,
    onChunk: @escaping (NSString) -> Void,
    completion: @escaping (NSString?, NSString?) -> Void
  )
}

extension AIEngineFoundationModelClient: AIEngineGenerativeClient {}
extension AIEngineGemmaModelClient: AIEngineGenerativeClient {}

@objc(AIEngine)
final class AIEngine: RCTEventEmitter, UIDocumentPickerDelegate {
  private var filePickerResolve: RCTPromiseResolveBlock?
  private var filePickerReject: RCTPromiseRejectBlock?
  private var hasListeners = false

  override static func requiresMainQueueSetup() -> Bool {
    true
  }

  override func supportedEvents() -> [String]! {
    [aiEngineStreamEventName]
  }

  override func startObserving() {
    hasListeners = true
  }

  override func stopObserving() {
    hasListeners = false
  }

  @objc(copyTextToClipboard:resolver:rejecter:)
  func copyTextToClipboard(
    _ text: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    DispatchQueue.main.async {
      UIPasteboard.general.string = text ?? ""
      resolve(true)
    }
  }

  @objc(generateResponse:history:resolver:rejecter:)
  func generateResponse(
    _ prompt: String?,
    history: [Any]?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let preparedPrompt = promptFromText(prompt ?? "", history: history ?? [], attachments: [])
    AIEngineFoundationModelClient.shared.generateResponse(prompt: preparedPrompt) { message, errorMessage in
      if let errorMessage, errorMessage.length > 0 {
        reject("AI_ENGINE_GENERATE_FAILED", errorMessage as String, nil)
        return
      }

      resolve(message ?? "")
    }
  }

  @objc(sendMessage:resolver:rejecter:)
  func sendMessage(
    _ message: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    AIEngineFoundationModelClient.shared.generateResponse(prompt: message ?? "") { response, errorMessage in
      if let errorMessage, errorMessage.length > 0 {
        reject("AI_ENGINE_MESSAGE_FAILED", errorMessage as String, nil)
        return
      }

      resolve(response ?? "")
    }
  }

  @objc(sendMultimodalMessage:resolver:rejecter:)
  func sendMultimodalMessage(
    _ request: [String: Any]?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let preparedPrompt = promptFromRequest(request, fallbackText: "")
    let modalities = modalitiesFromRequest(request)
    let modelClient = client(for: modelIdFromRequest(request))

    modelClient.generateResponse(prompt: preparedPrompt) { [weak self] message, errorMessage in
      guard let self else {
        reject("AI_ENGINE_MULTIMODAL_FAILED", "iOS AI backend is no longer available.", nil)
        return
      }

      if let errorMessage, errorMessage.length > 0 {
        reject("AI_ENGINE_MULTIMODAL_FAILED", errorMessage as String, nil)
        return
      }

      resolve(self.responseMap(message: message.map { $0 as String } ?? "", reasoning: nil, modalities: modalities))
    }
  }

  @objc(sendMultimodalMessageStream:request:resolver:rejecter:)
  func sendMultimodalMessageStream(
    _ requestId: String?,
    request: [String: Any]?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let preparedPrompt = promptFromRequest(request, fallbackText: "")
    let safeRequestId = requestId ?? ""
    let modelClient = client(for: modelIdFromRequest(request))

    modelClient.streamResponse(prompt: preparedPrompt) { [weak self] chunk in
      self?.sendStreamBody([
        "requestId": safeRequestId,
        "chunk": chunk as String,
        "done": false
      ])
    } completion: { [weak self] message, errorMessage in
      if let errorMessage, errorMessage.length > 0 {
        self?.sendStreamBody([
          "requestId": safeRequestId,
          "error": errorMessage as String,
          "done": true
        ])
        return
      }

      self?.sendStreamBody([
        "requestId": safeRequestId,
        "message": message.map { $0 as String } ?? "",
        "done": true
      ])
    }

    resolve(["started": true])
  }

  @objc(cancelActiveGeneration:rejecter:)
  func cancelActiveGeneration(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(AIEngineFoundationModelClient.shared.cancelActiveGeneration())
  }

  @objc(getModelStatus:rejecter:)
  func getModelStatus(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(AIEngineFoundationModelClient.shared.modelStatus())
  }

  @objc(getModelStatusForModel:resolver:rejecter:)
  func getModelStatusForModel(
    _ modelId: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(status(for: modelId))
  }

  @objc(getModelStatuses:rejecter:)
  func getModelStatuses(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve([
      AIEngineFoundationModelClient.shared.modelStatus(),
      AIEngineGemmaModelClient.shared.modelStatus()
    ])
  }

  @objc(getStartupState:rejecter:)
  func getStartupState(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(AIEngineFoundationModelClient.shared.startupState())
  }

  @objc(getRuntimeStatus:rejecter:)
  func getRuntimeStatus(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(AIEngineFoundationModelClient.shared.runtimeStatus())
  }

  @objc(getRuntimeStatusForModel:resolver:rejecter:)
  func getRuntimeStatusForModel(
    _ modelId: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(runtimeStatus(for: modelId))
  }

  @objc(loadModel:rejecter:)
  func loadModel(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(AIEngineFoundationModelClient.shared.loadModel())
  }

  @objc(loadModelById:resolver:rejecter:)
  func loadModelById(
    _ modelId: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(loadModel(for: modelId))
  }

  @objc(unloadModel:rejecter:)
  func unloadModel(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(AIEngineFoundationModelClient.shared.unloadModel())
  }

  @objc(downloadModel:resolver:rejecter:)
  func downloadModel(
    _ modelId: String?,
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(downloadModel(for: modelId))
  }

  @objc(ensureModelDownloaded:resolver:rejecter:)
  func ensureModelDownloaded(
    _ modelId: String?,
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(downloadModel(for: modelId))
  }

  @objc(cancelModelDownload:resolver:rejecter:)
  func cancelModelDownload(
    _ modelId: String?,
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    if normalizedModelId(modelId) == aiEngineGemmaModelId {
      resolve(AIEngineGemmaModelClient.shared.cancelDownload())
      return
    }

    resolve(status(for: modelId))
  }

  @objc(getIndexingStatus:rejecter:)
  func getIndexingStatus(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(indexingStatus())
  }

  @objc(startIndexing:rejecter:)
  func startIndexing(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(indexingResult(deleted: 0, skipped: 0))
  }

  @objc(startIndexingSource:resolver:rejecter:)
  func startIndexingSource(
    _ source: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(indexingResult(deleted: 0, skipped: 0))
  }

  @objc(setIndexingSourceEnabled:enabled:resolver:rejecter:)
  func setIndexingSourceEnabled(
    _ source: String?,
    enabled: Bool,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(indexingResult(deleted: 0, skipped: 0))
  }

  @objc(deleteIndexingSource:resolver:rejecter:)
  func deleteIndexingSource(
    _ source: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(indexingResult(deleted: 0, skipped: 0))
  }

  @objc(saveChatSession:title:messages:resolver:rejecter:)
  func saveChatSession(
    _ sessionId: String?,
    title: String?,
    messages: [Any]?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let safeSessionId = sessionId?.isEmpty == false ? sessionId! : UUID().uuidString
    let now = aiEngineNowMillis()
    var sessions = storedChatSessions()
    let existingSession = sessions[safeSessionId] as? [String: Any]
    let existingChat = existingSession?["chat"] as? [String: Any]
    let createdAt = existingChat?["createdAt"] as? NSNumber ?? now
    let safeTitle = title?.isEmpty == false ? title! : aiEngineDefaultChatTitle

    let chat: [String: Any] = [
      "id": safeSessionId,
      "title": safeTitle,
      "createdAt": createdAt,
      "updatedAt": now
    ]

    sessions[safeSessionId] = [
      "chat": chat,
      "messages": messages ?? [],
      "history": existingSession?["history"] as? [Any] ?? []
    ]

    saveStoredChatSessions(sessions)
    resolve(true)
  }

  @objc(loadChatSession:resolver:rejecter:)
  func loadChatSession(
    _ sessionId: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let session = storedChatSessions()[sessionId ?? ""]
    resolve(session ?? NSNull())
  }

  @objc(listChatSessions:rejecter:)
  func listChatSessions(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let chats = storedChatSessions().values
      .compactMap { ($0 as? [String: Any])?["chat"] as? [String: Any] }
      .sorted { left, right in
        let leftUpdatedAt = left["updatedAt"] as? NSNumber ?? 0
        let rightUpdatedAt = right["updatedAt"] as? NSNumber ?? 0
        return rightUpdatedAt.int64Value < leftUpdatedAt.int64Value
      }

    resolve(chats)
  }

  @objc(deleteChatSession:resolver:rejecter:)
  func deleteChatSession(
    _ sessionId: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    var sessions = storedChatSessions()
    let existed = sessions.removeValue(forKey: sessionId ?? "") != nil
    saveStoredChatSessions(sessions)
    resolve(existed ? 1 : 0)
  }

  @objc(compactChatSession:trigger:resolver:rejecter:)
  func compactChatSession(
    _ sessionId: String?,
    trigger: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let session = storedChatSessions()[sessionId ?? ""] as? [String: Any]
    let messages = session?["messages"] as? [[String: Any]] ?? []
    let tokenEstimate = messages.reduce(0) { partialResult, message in
      let text = safeString(message["text"])
      return partialResult + max(1, text.count / 4)
    }

    resolve([
      "chatId": sessionId ?? "",
      "compacted": false,
      "trigger": trigger ?? "manual",
      "message": "iOS 세션은 현재 로컬 저장소에서 그대로 유지됩니다.",
      "beforeTokenEstimate": tokenEstimate,
      "afterTokenEstimate": tokenEstimate,
      "compactedUntilMessageId": NSNull(),
      "snapshotId": 0
    ])
  }

  @objc(generateChatTitle:assistantMessage:resolver:rejecter:)
  func generateChatTitle(
    _ userMessage: String?,
    assistantMessage: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    AIEngineFoundationModelClient.shared.generateTitle(
      userMessage: userMessage ?? "",
      assistantMessage: assistantMessage ?? ""
    ) { title, errorMessage in
      if let errorMessage, errorMessage.length > 0 {
        reject("AI_ENGINE_TITLE_FAILED", errorMessage as String, nil)
        return
      }

      let resolvedTitle = title.map { $0 as String } ?? ""
      resolve(resolvedTitle.isEmpty ? aiEngineDefaultChatTitle : resolvedTitle)
    }
  }

  @objc(pickAttachment:rejecter:)
  func pickAttachment(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    DispatchQueue.main.async {
      if self.filePickerResolve != nil {
        reject("FILE_PICKER_BUSY", "이미 파일 선택이 진행 중입니다.", nil)
        return
      }

      guard let presenter = RCTPresentedViewController() else {
        reject("FILE_PICKER_NO_VIEW_CONTROLLER", "현재 파일 선택 화면을 열 수 없습니다.", nil)
        return
      }

      self.filePickerResolve = resolve
      self.filePickerReject = reject

      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.image, .audio, .movie, .pdf, .text, .json, .data],
        asCopy: true
      )
      picker.allowsMultipleSelection = false
      picker.delegate = self
      presenter.present(picker, animated: true)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      resolvePickedAttachment(nil)
      return
    }

    resolvePickedAttachment(attachment(for: url))
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    resolvePickedAttachment(nil)
  }

  private func sendStreamBody(_ body: [String: Any]) {
    guard hasListeners else {
      return
    }

    DispatchQueue.main.async {
      self.sendEvent(withName: aiEngineStreamEventName, body: body)
    }
  }

  private func modelIdFromRequest(_ request: [String: Any]?) -> String? {
    let options = request?["options"] as? [String: Any]
    return options?["modelId"] as? String
  }

  private func normalizedModelId(_ modelId: String?) -> String {
    guard let modelId, !modelId.isEmpty else {
      return aiEngineAppleModelId
    }

    if modelId == aiEngineGemmaModelId || modelId.lowercased().contains("gemma") {
      return aiEngineGemmaModelId
    }

    return aiEngineAppleModelId
  }

  private func client(for modelId: String?) -> AIEngineGenerativeClient {
    normalizedModelId(modelId) == aiEngineGemmaModelId
      ? AIEngineGemmaModelClient.shared
      : AIEngineFoundationModelClient.shared
  }

  private func status(for modelId: String?) -> NSDictionary {
    normalizedModelId(modelId) == aiEngineGemmaModelId
      ? AIEngineGemmaModelClient.shared.modelStatus()
      : AIEngineFoundationModelClient.shared.modelStatus()
  }

  private func runtimeStatus(for modelId: String?) -> NSDictionary {
    normalizedModelId(modelId) == aiEngineGemmaModelId
      ? AIEngineGemmaModelClient.shared.runtimeStatus()
      : AIEngineFoundationModelClient.shared.runtimeStatus()
  }

  private func loadModel(for modelId: String?) -> NSDictionary {
    normalizedModelId(modelId) == aiEngineGemmaModelId
      ? AIEngineGemmaModelClient.shared.loadModel()
      : AIEngineFoundationModelClient.shared.loadModel()
  }

  private func downloadModel(for modelId: String?) -> NSDictionary {
    normalizedModelId(modelId) == aiEngineGemmaModelId
      ? AIEngineGemmaModelClient.shared.downloadModel()
      : AIEngineFoundationModelClient.shared.modelStatus()
  }

  private func responseMap(message: String, reasoning: String?, modalities: [String]) -> [String: Any] {
    [
      "type": "text",
      "message": message,
      "reasoning": reasoning ?? NSNull(),
      "route": "direct",
      "modalities": modalities
    ]
  }

  private func promptFromRequest(_ request: [String: Any]?, fallbackText: String) -> String {
    guard let request else {
      return fallbackText
    }

    let text = safeString(request["text"])
    let history = request["history"] as? [Any] ?? []
    let attachments = request["attachments"] as? [Any] ?? []

    return promptFromText(text.isEmpty ? fallbackText : text, history: history, attachments: attachments)
  }

  private func promptFromText(_ text: String, history: [Any], attachments: [Any]) -> String {
    var sections: [String] = []
    var systemMessages: [String] = []
    var conversationMessages: [String] = []

    for rawMessage in history {
      guard let message = rawMessage as? [String: Any] else {
        continue
      }

      let role = safeString(message["role"])
      let content = safeString(message["content"]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !content.isEmpty else {
        continue
      }

      if role == "system" {
        systemMessages.append(content)
      } else {
        let roleLabel = role == "assistant" ? "assistant" : "user"
        conversationMessages.append("\(roleLabel): \(content)")
      }
    }

    if !systemMessages.isEmpty {
      sections.append("다음 시스템 지침을 우선 적용하세요.\n\(systemMessages.joined(separator: "\n\n"))")
    }

    if !conversationMessages.isEmpty {
      sections.append("이전 대화 내용입니다. 사용자가 이전 내용, 방금 말한 것, 위 내용, 이어서 등의 표현을 쓰면 이 대화 맥락을 기준으로 답하세요.\n\(conversationMessages.joined(separator: "\n"))")
    }

    let attachmentLines = attachments.compactMap { rawAttachment -> String? in
      guard let attachment = rawAttachment as? [String: Any] else {
        return nil
      }

      var parts = [safeString(attachment["name"]).isEmpty ? "첨부 파일" : safeString(attachment["name"])]
      let type = safeString(attachment["type"])
      let mimeType = safeString(attachment["mimeType"])

      if !type.isEmpty {
        parts.append("type=\(type)")
      }
      if !mimeType.isEmpty {
        parts.append("mime=\(mimeType)")
      }
      if let sizeBytes = attachment["sizeBytes"] as? NSNumber {
        parts.append("bytes=\(sizeBytes)")
      }

      return parts.joined(separator: ", ")
    }

    if !attachmentLines.isEmpty {
      sections.append("첨부 파일 정보:\n\(attachmentLines.joined(separator: "\n"))")
    }

    sections.append("현재 사용자 요청:\n\(text)")
    return sections.joined(separator: "\n\n")
  }

  private func modalitiesFromRequest(_ request: [String: Any]?) -> [String] {
    let attachments = request?["attachments"] as? [[String: Any]] ?? []
    var modalities: [String] = []

    for attachment in attachments {
      let type = safeString(attachment["type"])
      if !type.isEmpty && !modalities.contains(type) {
        modalities.append(type)
      }
    }

    return modalities
  }

  private func indexingStatus() -> [String: Any] {
    [
      "isAvailable": false,
      "isIndexing": false,
      "indexedItems": 0,
      "lastIndexedAt": NSNull(),
      "lastError": NSNull(),
      "smsEnabled": false,
      "galleryEnabled": false,
      "documentEnabled": false,
      "smsIndexedItems": 0,
      "galleryIndexedItems": 0,
      "documentIndexedItems": 0
    ]
  }

  private func indexingResult(deleted: Int, skipped: Int) -> [String: Any] {
    [
      "smsIndexed": 0,
      "galleryIndexed": 0,
      "documentIndexed": 0,
      "deleted": deleted,
      "skipped": skipped,
      "status": indexingStatus()
    ]
  }

  private func storedChatSessions() -> [String: Any] {
    UserDefaults.standard.dictionary(forKey: aiEngineStorageKey) ?? [:]
  }

  private func saveStoredChatSessions(_ sessions: [String: Any]) {
    UserDefaults.standard.set(sessions, forKey: aiEngineStorageKey)
    UserDefaults.standard.synchronize()
  }

  private func attachment(for url: URL) -> [String: Any] {
    let resourceValues = try? url.resourceValues(forKeys: [.nameKey, .fileSizeKey, .typeIdentifierKey])
    let fileName = resourceValues?.name?.isEmpty == false ? resourceValues!.name! : url.lastPathComponent
    let mimeType = mimeType(forFileName: fileName, typeIdentifier: resourceValues?.typeIdentifier)
    let attachmentType = attachmentType(forMimeType: mimeType, fileName: fileName)
    var attachment: [String: Any] = [
      "id": "attachment-\(Int64(Date().timeIntervalSince1970 * 1000))",
      "type": attachmentType,
      "uri": url.absoluteString,
      "name": fileName.isEmpty ? "첨부 파일" : fileName
    ]

    if !mimeType.isEmpty {
      attachment["mimeType"] = mimeType
    }
    if let fileSize = resourceValues?.fileSize {
      attachment["sizeBytes"] = fileSize
    }

    return attachment
  }

  private func resolvePickedAttachment(_ attachment: [String: Any]?) {
    let resolve = filePickerResolve
    filePickerResolve = nil
    filePickerReject = nil
    resolve?(attachment ?? NSNull())
  }

  private func mimeType(forFileName fileName: String, typeIdentifier: String?) -> String {
    let lowercaseName = fileName.lowercased()

    if typeIdentifier == "com.adobe.pdf" || lowercaseName.hasSuffix(".pdf") {
      return "application/pdf"
    }
    if typeIdentifier?.contains("json") == true || lowercaseName.hasSuffix(".json") {
      return "application/json"
    }
    if lowercaseName.hasSuffix(".png") {
      return "image/png"
    }
    if lowercaseName.hasSuffix(".jpg") || lowercaseName.hasSuffix(".jpeg") {
      return "image/jpeg"
    }
    if lowercaseName.hasSuffix(".gif") {
      return "image/gif"
    }
    if lowercaseName.hasSuffix(".heic") {
      return "image/heic"
    }
    if lowercaseName.hasSuffix(".mp3") {
      return "audio/mpeg"
    }
    if lowercaseName.hasSuffix(".wav") {
      return "audio/wav"
    }
    if lowercaseName.hasSuffix(".m4a") {
      return "audio/mp4"
    }
    if lowercaseName.hasSuffix(".mp4") {
      return "video/mp4"
    }
    if lowercaseName.hasSuffix(".mov") {
      return "video/quicktime"
    }
    if typeIdentifier?.hasPrefix("public.text") == true || lowercaseName.hasSuffix(".txt") {
      return "text/plain"
    }

    return "application/octet-stream"
  }

  private func attachmentType(forMimeType mimeType: String, fileName: String) -> String {
    if mimeType.hasPrefix("image/") {
      return "image"
    }
    if mimeType.hasPrefix("audio/") {
      return "audio"
    }
    if mimeType.hasPrefix("video/") {
      return "video"
    }

    let lowercaseName = fileName.lowercased()
    if [".png", ".jpg", ".jpeg", ".gif", ".heic"].contains(where: lowercaseName.hasSuffix) {
      return "image"
    }
    if [".mp3", ".wav", ".m4a"].contains(where: lowercaseName.hasSuffix) {
      return "audio"
    }
    if [".mp4", ".mov"].contains(where: lowercaseName.hasSuffix) {
      return "video"
    }

    return "file"
  }
}
