import Foundation

@objcMembers
final class AIEngineGemmaModelClient: NSObject, URLSessionDownloadDelegate {
  @objc(shared) static let shared = AIEngineGemmaModelClient()

  private let lock = NSLock()
  private var downloadTask: URLSessionDownloadTask?
  private var activeTask: Task<Void, Never>?

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

    return [
      "modelId": modelId,
      "modelName": modelName,
      "installed": installed,
      "isDownloading": isDownloading,
      "bytesDownloaded": max(0, min(currentBytes, modelSizeBytes)),
      "totalBytes": modelSizeBytes,
      "localPath": file.path,
      "downloadUrl": downloadUrl,
      "error": lastError ?? NSNull(),
      "provider": "google",
      "runnable": false,
      "started": started,
      "systemManaged": false
    ] as NSDictionary
  }

  func runtimeStatus() -> NSDictionary {
    let installed = fileSize(at: modelFileURL()) == modelSizeBytes
    return [
      "modelInstalled": installed,
      "loaded": false,
      "loading": false,
      "canGenerate": false,
      "localPath": modelFileURL().path,
      "error": installed
        ? "Gemma 4 iOS 추론 런타임이 아직 앱에 연결되지 않았습니다."
        : "Gemma 4 모델 파일이 아직 설치되지 않았습니다."
    ] as NSDictionary
  }

  func loadModel() -> NSDictionary {
    return runtimeStatus()
  }

  func unloadModel() -> NSDictionary {
    cancelActiveGeneration()
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
    completion(nil, runtimeUnavailableMessage() as NSString)
  }

  func streamResponse(
    prompt: String,
    onChunk: @escaping (NSString) -> Void,
    completion: @escaping (NSString?, NSString?) -> Void
  ) {
    completion(nil, runtimeUnavailableMessage() as NSString)
  }

  func generateTitle(
    userMessage: String,
    assistantMessage: String,
    completion: @escaping (NSString?, NSString?) -> Void
  ) {
    completion(nil, runtimeUnavailableMessage() as NSString)
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

    return "Gemma 4 모델 파일은 설치되어 있지만, iOS Gemma 4 추론 런타임이 아직 앱에 연결되지 않았습니다. 현재 iOS에서는 Apple Intelligence 모델을 사용해주세요."
  }

  private func modelsDirectoryURL() -> URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("models", isDirectory: true)
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
}
