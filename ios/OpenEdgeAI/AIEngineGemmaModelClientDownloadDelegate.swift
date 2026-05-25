import Foundation

extension AIEngineGemmaModelClient {
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

}
