import Foundation

extension AIEngineGemmaModelClient {
private func runtimeUnavailableMessage() -> String {
    let installed = fileSize(at: modelFileURL()) == modelSizeBytes
    if !installed {
      return "Gemma 4 모델을 먼저 다운로드해주세요."
    }

    let status = runtime.status(withModelInstalled: installed, localPath: modelFileURL().path)
    return stringValue(status["error"])
      ?? "Gemma 4 모델 파일은 설치되어 있지만, iOS Gemma 4 추론 런타임이 아직 앱에 연결되지 않았습니다."
  }

  func prepareRuntimeForGeneration() -> String? {
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

  func setActiveTask(_ task: Task<Void, Never>) {
    lock.lock()
    activeTask = task
    lock.unlock()
  }

  func clearActiveTask() {
    lock.lock()
    activeTask = nil
    lock.unlock()
  }

  func modelsDirectoryURL() -> URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("models", isDirectory: true)
  }

  func runtimeCacheDirectoryURL() -> URL {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    return caches.appendingPathComponent("litert-lm", isDirectory: true)
  }

  func warmRuntimeIfPossible(modelPath: String) {
    let cacheDirectory = runtimeCacheDirectoryURL().path
    DispatchQueue.global(qos: .userInitiated).async { [runtime] in
      _ = runtime.loadModel(atPath: modelPath, cacheDirectory: cacheDirectory)
    }
  }

  func modelFileURL() -> URL {
    modelsDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
  }

  func fileSize(at url: URL) -> Int64 {
    guard
      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber
    else {
      return 0
    }

    return size.int64Value
  }

  func boolValue(_ value: Any?) -> Bool {
    if let value = value as? Bool {
      return value
    }
    if let value = value as? NSNumber {
      return value.boolValue
    }
    return false
  }

  func stringValue(_ value: Any?) -> String? {
    if value is NSNull {
      return nil
    }
    return value as? String
  }
}
