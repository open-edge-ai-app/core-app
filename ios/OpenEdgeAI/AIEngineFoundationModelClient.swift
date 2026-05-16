import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

private enum AIEngineFoundationModelError: LocalizedError {
  case unavailable(String)

  var errorDescription: String? {
    switch self {
    case .unavailable(let message):
      return message
    }
  }
}

@objcMembers
final class AIEngineFoundationModelClient: NSObject {
  @objc(shared) static let shared = AIEngineFoundationModelClient()

  private let lock = NSLock()
  private var loaded = false
  private var activeTask: Task<Void, Never>?

  private let modelId = "apple-foundation"
  private let modelName = "Apple Intelligence"
  private let localPath = "system://apple-foundation-models"
  private let baseInstructions = """
  You are Open Edge AI running on iOS. Answer clearly, preserve the user's language, and use the provided conversation history as context.
  Treat runtime date, time, and timezone context as hidden reference material. Do not mention it unless the user asks about date/time/timezone or needs relative-date interpretation.
  """

  func modelStatus() -> NSDictionary {
    let isAvailable = foundationModelIsAvailable()
    return [
      "modelId": modelId,
      "modelName": modelName,
      "installed": isAvailable,
      "isDownloading": false,
      "bytesDownloaded": 0,
      "totalBytes": 0,
      "localPath": localPath,
      "downloadUrl": localPath,
      "error": isAvailable ? NSNull() : foundationModelAvailabilityDescription(),
      "provider": "apple",
      "runnable": isAvailable,
      "started": false,
      "systemManaged": true
    ] as NSDictionary
  }

  func startupState() -> NSDictionary {
    let isAvailable = foundationModelIsAvailable()
    return [
      "ready": isAvailable,
      "nextAction": isAvailable ? "continue" : "show_model_download",
      "message": isAvailable
        ? "Apple Foundation Models are ready."
        : foundationModelAvailabilityDescription(),
      "modelStatus": modelStatus()
    ] as NSDictionary
  }

  func runtimeStatus() -> NSDictionary {
    let isAvailable = foundationModelIsAvailable()
    let isLoaded = loaded && isAvailable
    return [
      "modelInstalled": isAvailable,
      "loaded": isLoaded,
      "loading": false,
      "canGenerate": isLoaded,
      "localPath": localPath,
      "error": isAvailable ? NSNull() : foundationModelAvailabilityDescription()
    ] as NSDictionary
  }

  func loadModel() -> NSDictionary {
    loaded = foundationModelIsAvailable()
    return runtimeStatus()
  }

  func unloadModel() -> NSDictionary {
    cancelActiveGeneration()
    loaded = false
    return runtimeStatus()
  }

  @discardableResult
  func cancelActiveGeneration() -> Bool {
    lock.lock()
    let task = activeTask
    activeTask = nil
    lock.unlock()

    task?.cancel()
    return task != nil
  }

  @objc(generateResponseWithPrompt:completion:)
  func generateResponse(prompt: String, completion: @escaping (NSString?, NSString?) -> Void) {
    let task = Task { [weak self] in
      guard let self else {
        completion(nil, "iOS AI backend is no longer available.")
        return
      }

      do {
        let text = try await self.generateText(for: prompt)
        try Task.checkCancellation()
        completion(text as NSString, nil)
      } catch is CancellationError {
        completion(nil, "응답 생성이 중지되었습니다.")
      } catch {
        completion(nil, error.localizedDescription as NSString)
      }

      self.clearActiveTask()
    }

    replaceActiveTask(with: task)
  }

  @objc(streamResponseWithPrompt:onChunk:completion:)
  func streamResponse(
    prompt: String,
    onChunk: @escaping (NSString) -> Void,
    completion: @escaping (NSString?, NSString?) -> Void
  ) {
    let task = Task { [weak self] in
      guard let self else {
        completion(nil, "iOS AI backend is no longer available.")
        return
      }

      do {
        let text = try await self.streamText(for: prompt, onChunk: onChunk)
        try Task.checkCancellation()
        completion(text as NSString, nil)
      } catch is CancellationError {
        completion(nil, "응답 생성이 중지되었습니다.")
      } catch {
        completion(nil, error.localizedDescription as NSString)
      }

      self.clearActiveTask()
    }

    replaceActiveTask(with: task)
  }

  @objc(generateTitleWithUserMessage:assistantMessage:completion:)
  func generateTitle(
    userMessage: String,
    assistantMessage: String,
    completion: @escaping (NSString?, NSString?) -> Void
  ) {
    let fallback = makeTitle(from: userMessage, assistantMessage: assistantMessage)

    guard foundationModelIsAvailable() else {
      completion(fallback as NSString, nil)
      return
    }

    Task { [weak self] in
      guard let self else {
        completion(fallback as NSString, nil)
        return
      }

      do {
        let prompt = """
        Create one short Korean chat title, under 24 characters. Return only the title.

        User:
        \(userMessage)

        Assistant:
        \(assistantMessage)
        """
        let generated = try await self.generateText(for: prompt)
        completion(self.cleanTitle(generated, fallback: fallback) as NSString, nil)
      } catch {
        completion(fallback as NSString, nil)
      }
    }
  }

  private func replaceActiveTask(with task: Task<Void, Never>) {
    lock.lock()
    let previousTask = activeTask
    activeTask = task
    lock.unlock()

    previousTask?.cancel()
  }

  private func clearActiveTask() {
    lock.lock()
    activeTask = nil
    lock.unlock()
  }

  private func generateText(for prompt: String) async throws -> String {
    try Task.checkCancellation()

    #if canImport(FoundationModels)
    if #available(iOS 26.0, *), foundationModelIsAvailable() {
      loaded = true
      return try await generateWithFoundationModels(prompt: prompt)
    }
    #endif

    loaded = false
    throw AIEngineFoundationModelError.unavailable(foundationModelAvailabilityDescription())
  }

  private func streamText(for prompt: String, onChunk: @escaping (NSString) -> Void) async throws -> String {
    try Task.checkCancellation()

    #if canImport(FoundationModels)
    if #available(iOS 26.0, *), foundationModelIsAvailable() {
      loaded = true
      return try await streamWithFoundationModels(prompt: prompt, onChunk: onChunk)
    }
    #endif

    loaded = false
    throw AIEngineFoundationModelError.unavailable(foundationModelAvailabilityDescription())
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private func generateWithFoundationModels(prompt: String) async throws -> String {
    let session = LanguageModelSession(model: .default, instructions: baseInstructions)
    let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 900)
    let response = try await session.respond(to: prompt, options: options)
    return cleanResponse(response.content)
  }

  @available(iOS 26.0, *)
  private func streamWithFoundationModels(
    prompt: String,
    onChunk: @escaping (NSString) -> Void
  ) async throws -> String {
    let session = LanguageModelSession(model: .default, instructions: baseInstructions)
    let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 900)
    let stream = session.streamResponse(to: prompt, options: options)
    var previous = ""

    for try await snapshot in stream {
      try Task.checkCancellation()
      let current = snapshot.content

      if current.count > previous.count {
        let delta = String(current.dropFirst(previous.count))
        if !delta.isEmpty {
          onChunk(delta as NSString)
        }
      }

      previous = current
    }

    return cleanResponse(previous)
  }
  #endif

  private func splitForStreaming(_ text: String) -> [String] {
    let chunks = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)

    if chunks.isEmpty {
      return text.isEmpty ? [] : [text]
    }

    var result: [String] = []
    var searchStart = text.startIndex

    for chunk in chunks {
      guard let range = text[searchStart...].range(of: chunk) else {
        result.append(chunk)
        continue
      }

      if range.lowerBound > searchStart {
        result.append(String(text[searchStart..<range.lowerBound]))
      }
      result.append(String(text[range]))
      searchStart = range.upperBound
    }

    if searchStart < text.endIndex {
      result.append(String(text[searchStart..<text.endIndex]))
    }

    return result
  }

  private func cleanResponse(_ text: String) -> String {
    text
      .replacingOccurrences(of: "<turn>", with: "")
      .replacingOccurrences(of: "</turn>", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func makeTitle(from userMessage: String, assistantMessage: String) -> String {
    let source = [userMessage, assistantMessage]
      .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty } ?? "새 채팅"

    return cleanTitle(source, fallback: "새 채팅")
  }

  private func cleanTitle(_ title: String, fallback: String) -> String {
    let cleaned = title
      .replacingOccurrences(of: "\"", with: "")
      .replacingOccurrences(of: "'", with: "")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "#", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleaned.isEmpty else {
      return fallback
    }

    return cleaned.count <= 24 ? cleaned : "\(cleaned.prefix(24))..."
  }

  private func foundationModelIsAvailable() -> Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return SystemLanguageModel.default.isAvailable
    }
    #endif

    return false
  }

  private func foundationModelAvailabilityDescription() -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return "Apple Foundation Models 사용 가능"
      case .unavailable(.deviceNotEligible):
        return "현재 기기는 Apple Intelligence 시스템 모델을 지원하지 않습니다."
      case .unavailable(.appleIntelligenceNotEnabled):
        return "Apple Intelligence가 꺼져 있습니다."
      case .unavailable(.modelNotReady):
        return "Apple Intelligence 모델이 아직 준비되지 않았습니다."
      @unknown default:
        return "Apple Foundation Models 상태를 확인할 수 없습니다."
      }
    }
    #endif

    return "Foundation Models는 iOS 26 이상에서 사용할 수 있습니다."
  }
}
