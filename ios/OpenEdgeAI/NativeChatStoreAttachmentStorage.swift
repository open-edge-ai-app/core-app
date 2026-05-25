import Foundation
import UniformTypeIdentifiers

@MainActor
extension NativeChatStore {
  func makeAttachment(from url: URL) -> NativeAttachment? {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let values = try? url.resourceValues(forKeys: [.nameKey, .fileSizeKey, .typeIdentifierKey])
    let name = values?.name?.isEmpty == false ? values!.name! : url.lastPathComponent
    let mime = mimeType(fileName: name, typeIdentifier: values?.typeIdentifier)
    let storedURL = persistAttachmentFile(from: url, suggestedName: name) ?? url
    let storedValues = try? storedURL.resourceValues(forKeys: [.fileSizeKey])
    return makeAttachment(
      displayName: name.isEmpty ? "첨부 파일" : name,
      mimeType: mime,
      sizeBytes: storedValues?.fileSize.map(Int64.init) ?? values?.fileSize.map(Int64.init),
      url: storedURL
    )
  }

  func makeAttachment(displayName: String, mimeType: String, sizeBytes: Int64?, url: URL) -> NativeAttachment {
    return NativeAttachment(
      id: UUID().uuidString,
      name: displayName.isEmpty ? "첨부 파일" : displayName,
      type: attachmentType(mimeType: mimeType, fileName: displayName),
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      url: url.absoluteString
    )
  }

  func persistAttachmentData(_ data: Data, fileName: String) -> URL? {
    guard let destination = uniqueAttachmentURL(for: fileName) else {
      return nil
    }

    do {
      try data.write(to: destination, options: [.atomic])
      return destination
    } catch {
      return nil
    }
  }

  func persistAttachmentFile(from sourceURL: URL, suggestedName: String) -> URL? {
    guard sourceURL.isFileURL,
          let destination = uniqueAttachmentURL(for: suggestedName.isEmpty ? sourceURL.lastPathComponent : suggestedName)
    else {
      return nil
    }

    do {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
      return destination
    } catch {
      return nil
    }
  }

  func uniqueAttachmentURL(for fileName: String) -> URL? {
    guard let directory = attachmentStorageDirectory() else {
      return nil
    }

    let sanitizedName = Self.sanitizedAttachmentFileName(fileName)
    return directory.appendingPathComponent("\(UUID().uuidString)-\(sanitizedName)", isDirectory: false)
  }

  func attachmentStorageDirectory() -> URL? {
    guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }

    let directory = baseURL.appendingPathComponent("Attachments", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
    } catch {
      return nil
    }
  }

  private static func sanitizedAttachmentFileName(_ fileName: String) -> String {
    let fallbackName = "attachment"
    let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate = trimmed.isEmpty ? fallbackName : trimmed
    let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
      .union(.newlines)
      .union(.controlCharacters)
    let parts = candidate.components(separatedBy: invalidCharacters).filter { !$0.isEmpty }
    let sanitized = parts.joined(separator: "-")
    return sanitized.isEmpty ? fallbackName : sanitized
  }

  static func attachmentTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return formatter.string(from: Date())
  }

  func attachmentType(mimeType: String, fileName: String) -> String {
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

  func mimeType(fileName: String, typeIdentifier: String?) -> String {
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

}
