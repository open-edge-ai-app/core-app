import Foundation

@objcMembers
final class AIEngineGemmaModelClient: NSObject, URLSessionDownloadDelegate {
  @objc(shared) static let shared = AIEngineGemmaModelClient()

  private let lock = NSLock()
  private var downloadTask: URLSessionDownloadTask?
  private var activeTask: Task<Void, Never>?
  private let runtime = AIEngineLiteRtLmRuntime.shared()

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60 * 60 * 3
    configuration.waitsForConnectivity = true
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()

  private let modelId = "gemma-4"
  private let modelName = "Gemma 4"
  private let fileName = "gemma-4-E2B-it.litertlm"
  private let modelSizeBytes: Int64 = 2_588_147_712
  private let downloadUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true"

  private var isDownloading = false
  private var bytesDownloaded: Int64 = 0
  private var lastError: String?

  func modelStatus(started: Bool = false) -> NSDictionary {
    let file = modelFileURL()
    let fileBytes = fileSize(at: file)
    let installed = fileBytes == modelSizeBytes
    let currentBytes = isDownloading ? bytesDownloaded : fileBytes
    let runtimeStatus = runtime.status(withModelInstalled: installed, localPath: file.path)
    let runtimeAvailable = boolValue(runtimeStatus["runtimeAvailable"])
    let runtimeError = installed ? stringValue(runtimeStatus["error"]) : nil
    let errorValue: Any
    if let lastError {
      errorValue = lastError
    } else if let runtimeError {
      errorValue = runtimeError
    } else {
      errorValue = NSNull()
    }

    return [
      "modelId": modelId,
      "modelName": modelName,
      "installed": installed,
      "isDownloading": isDownloading,
      "bytesDownloaded": max(0, min(currentBytes, modelSizeBytes)),
      "totalBytes": modelSizeBytes,
      "localPath": file.path,
      "downloadUrl": downloadUrl,
      "error": errorValue,
      "provider": "google",
      "runnable": runtimeAvailable,
      "started": started,
      "systemManaged": false
    ] as NSDictionary
  }

  func runtimeStatus() -> NSDictionary {
    let file = modelFileURL()
    let installed = fileSize(at: file) == modelSizeBytes
    let status = NSMutableDictionary(dictionary: runtime.status(withModelInstalled: installed, localPath: file.path))

    if !installed {
      status["modelInstalled"] = false
      status["loaded"] = false
      status["loading"] = false
      status["canGenerate"] = false
      status["localPath"] = file.path
      status["error"] = "Gemma 4 모델 파일이 아직 설치되지 않았습니다."
    }

    return status
  }

  func loadModel() -> NSDictionary {
    let file = modelFileURL()
    guard fileSize(at: file) == modelSizeBytes else {
      runtime.unload()
      return runtimeStatus()
    }

    return NSDictionary(dictionary: runtime.loadModel(atPath: file.path, cacheDirectory: runtimeCacheDirectoryURL().path))
  }

  func unloadModel() -> NSDictionary {
    cancelActiveGeneration()
    runtime.unload()
    return runtimeStatus()
  }

  @discardableResult
  func cancelActiveGeneration() -> Bool {
    lock.lock()
    let task = activeTask
    activeTask = nil
    lock.unlock()

    task?.cancel()
    let runtimeCancelled = runtime.cancelActiveGeneration()
    return task != nil || runtimeCancelled
  }

  func downloadModel() -> NSDictionary {
    lock.lock()
    defer { lock.unlock() }

    if isDownloading {
      return modelStatus(started: false)
    }

    let modelFile = modelFileURL()
    if fileSize(at: modelFile) == modelSizeBytes {
      lastError = nil
      bytesDownloaded = modelSizeBytes
      warmRuntimeIfPossible(modelPath: modelFile.path)
      return modelStatus(started: false)
    }

    try? FileManager.default.createDirectory(
      at: modelsDirectoryURL(),
      withIntermediateDirectories: true
    )
    try? FileManager.default.removeItem(at: modelFile)

    isDownloading = true
    bytesDownloaded = 0
    lastError = nil

    guard let url = URL(string: downloadUrl) else {
      isDownloading = false
      lastError = "Gemma 4 다운로드 URL이 올바르지 않습니다."
      return modelStatus(started: false)
    }

    let task = session.downloadTask(with: url)
    downloadTask = task
    task.resume()

    return modelStatus(started: true)
  }

  func cancelDownload() -> NSDictionary {
    lock.lock()
    let task = downloadTask
    downloadTask = nil
    isDownloading = false
    lastError = nil
    lock.unlock()

    task?.cancel()
    return modelStatus(started: false)
  }

  func generateResponse(prompt: String, completion: @escaping (NSString?, NSString?) -> Void) {
    if let errorMessage = prepareRuntimeForGeneration() {
      completion(nil, errorMessage as NSString)
      return
    }

    let task = Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else {
        completion(nil, "Gemma 4 런타임이 해제되었습니다." as NSString)
        return
      }

      let result = self.runtime.generatePrompt(prompt)
      self.clearActiveTask()

      if let error = self.stringValue(result["error"]) {
        completion(nil, error as NSString)
        return
      }

      completion((self.stringValue(result["message"]) ?? "") as NSString, nil)
    }

    setActiveTask(task)
  }

  func streamResponse(
    prompt: String,
    onChunk: @escaping (NSString) -> Void,
    completion: @escaping (NSString?, NSString?) -> Void
  ) {
    if let errorMessage = prepareRuntimeForGeneration() {
      completion(nil, errorMessage as NSString)
      return
    }

    let task = Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else {
        completion(nil, "Gemma 4 런타임이 해제되었습니다." as NSString)
        return
      }

      let result = self.runtime.streamPrompt(prompt) { chunk in
        onChunk(chunk as NSString)
      }
      self.clearActiveTask()

      if let error = self.stringValue(result["error"]) {
        completion(nil, error as NSString)
        return
      }

      completion((self.stringValue(result["message"]) ?? "") as NSString, nil)
    }

    setActiveTask(task)
  }

  func generateTitle(
    userMessage: String,
    assistantMessage: String,
    completion: @escaping (NSString?, NSString?) -> Void
  ) {
    let titlePrompt = [
      "Create a short chat title from this first exchange.",
      "Rules:",
      "- Match the user's language.",
      "- Use 3 to 8 words when possible.",
      "- Do not return the full user message.",
      "- Return only the title.",
      "",
      "User:",
      userMessage,
      "",
      "Assistant:",
      assistantMessage
    ].joined(separator: "\n")

    generateResponse(prompt: titlePrompt, completion: completion)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    lock.lock()
    bytesDownloaded = totalBytesWritten
    lock.unlock()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    let destination = modelFileURL()

    do {
      try FileManager.default.createDirectory(
        at: modelsDirectoryURL(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.moveItem(at: location, to: destination)

      let finalSize = fileSize(at: destination)
      if finalSize != modelSizeBytes {
        try? FileManager.default.removeItem(at: destination)
        throw NSError(
          domain: "OpenEdgeAI.GemmaDownload",
          code: 1,
          userInfo: [
            NSLocalizedDescriptionKey: "Gemma 4 모델 크기가 올바르지 않습니다. \(finalSize) / \(modelSizeBytes)"
          ]
        )
      }

      lock.lock()
      bytesDownloaded = finalSize
      lastError = nil
      lock.unlock()
      warmRuntimeIfPossible(modelPath: destination.path)
    } catch {
      lock.lock()
      lastError = error.localizedDescription
      lock.unlock()
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    lock.lock()
    if let error = error as NSError?, error.code != NSURLErrorCancelled {
      lastError = error.localizedDescription
    }
    isDownloading = false
    downloadTask = nil
    lock.unlock()
  }

  private func runtimeUnavailableMessage() -> String {
    let installed = fileSize(at: modelFileURL()) == modelSizeBytes
    if !installed {
      return "Gemma 4 모델을 먼저 다운로드해주세요."
    }

    let status = runtime.status(withModelInstalled: installed, localPath: modelFileURL().path)
    return stringValue(status["error"])
      ?? "Gemma 4 모델 파일은 설치되어 있지만, iOS Gemma 4 추론 런타임이 아직 앱에 연결되지 않았습니다."
  }

  private func prepareRuntimeForGeneration() -> String? {
    let file = modelFileURL()
    guard fileSize(at: file) == modelSizeBytes else {
      return "Gemma 4 모델을 먼저 다운로드해주세요."
    }

    let status = runtime.loadModel(atPath: file.path, cacheDirectory: runtimeCacheDirectoryURL().path)
    if boolValue(status["canGenerate"]) {
      return nil
    }

    return stringValue(status["error"])
      ?? "Gemma 4 iOS 런타임을 켜지 못했습니다."
  }

  private func setActiveTask(_ task: Task<Void, Never>) {
    lock.lock()
    activeTask = task
    lock.unlock()
  }

  private func clearActiveTask() {
    lock.lock()
    activeTask = nil
    lock.unlock()
  }

  private func modelsDirectoryURL() -> URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("models", isDirectory: true)
  }

  private func runtimeCacheDirectoryURL() -> URL {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    return caches.appendingPathComponent("litert-lm", isDirectory: true)
  }

  private func warmRuntimeIfPossible(modelPath: String) {
    let cacheDirectory = runtimeCacheDirectoryURL().path
    DispatchQueue.global(qos: .userInitiated).async { [runtime] in
      _ = runtime.loadModel(atPath: modelPath, cacheDirectory: cacheDirectory)
    }
  }

  private func modelFileURL() -> URL {
    modelsDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
  }

  private func fileSize(at url: URL) -> Int64 {
    guard
      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber
    else {
      return 0
    }

    return size.int64Value
  }

  private func boolValue(_ value: Any?) -> Bool {
    if let value = value as? Bool {
      return value
    }
    if let value = value as? NSNumber {
      return value.boolValue
    }
    return false
  }

  private func stringValue(_ value: Any?) -> String? {
    if value is NSNull {
      return nil
    }
    return value as? String
  }
}
