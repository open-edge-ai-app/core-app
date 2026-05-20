import Foundation

struct NativeModelStatus: Equatable {
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
