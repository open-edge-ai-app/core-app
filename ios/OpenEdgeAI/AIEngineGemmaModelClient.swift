import Foundation

@objcMembers
final class AIEngineGemmaModelClient: NSObject, URLSessionDownloadDelegate {
  @objc(shared) static let shared = AIEngineGemmaModelClient()

  let lock = NSLock()
  var downloadTask: URLSessionDownloadTask?
  var activeTask: Task<Void, Never>?
  let runtime = AIEngineLiteRtLmRuntime.shared()

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60 * 60 * 3
    configuration.waitsForConnectivity = true
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()

  let modelId = "gemma-4"
  let modelName = "Gemma 4"
  let fileName = "gemma-4-E2B-it.litertlm"
  let modelSizeBytes: Int64 = 2_588_147_712
  let downloadUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true"

  var isDownloading = false
  var bytesDownloaded: Int64 = 0
  var lastError: String?

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
}
