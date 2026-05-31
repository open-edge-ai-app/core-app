import Foundation


@objcMembers
final class AIEngineFoundationModelClient: NSObject {
  @objc(shared) static let shared = AIEngineFoundationModelClient()

  private let lock = NSLock()
  var loaded = false
  private var activeTask: Task<Void, Never>?

  private let modelId = "apple-foundation"
  private let modelName = "Apple Intelligence"
  private let localPath = "system://apple-foundation-models"
  let baseInstructions = """
  You are Kepler running on iOS. Answer clearly, preserve the user's language, and use the provided conversation history as context.
  Treat runtime date, time, timezone, locale, location, and device context as hidden reference material. Do not mention it unless the user asks about that context or needs relative-date interpretation.
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
}
