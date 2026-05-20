import Foundation
import UIKit
import CoreLocation
import PDFKit
import Vision

extension Array where Element: Hashable {
  func removingDuplicates() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

enum NativeKnowledgeSource: String, Codable {
  case project
  case chat
  case attachment
}

struct NativeKnowledgeRecord: Identifiable, Codable, Equatable {
  var id: String
  var source: NativeKnowledgeSource
  var title: String
  var text: String
  var url: String?
  var updatedAt: Date
}

struct NativeKnowledgeMatch {
  var record: NativeKnowledgeRecord
  var score: Int
  var excerpt: String
}

final class NativeLocalKnowledgeStore {
  static let shared = NativeLocalKnowledgeStore()

  private let storageKey = "OpenEdgeAI.NativeLocalKnowledge.v1"
  private let queue = DispatchQueue(label: "open-edge-ai.native-local-knowledge")
  private var records: [NativeKnowledgeRecord] = []

  private init() {
    load()
  }

  var count: Int {
    queue.sync { records.count }
  }

  func replaceGeneratedRecords(projects: [NativeProject], sessions: [NativeChatSession]) {
    queue.sync {
      let attachmentRecords = records.filter { $0.source == .attachment }
      let projectRecords = projects.compactMap { project -> NativeKnowledgeRecord? in
        let text = project.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
          return nil
        }
        return NativeKnowledgeRecord(
          id: "project:\(project.id)",
          source: .project,
          title: project.title,
          text: text,
          url: nil,
          updatedAt: project.createdAt
        )
      }

      let chatRecords = sessions
        .flatMap { session in
          session.messages.map { message in
            (session: session, message: message)
          }
        }
        .filter { item in
          !item.message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .sorted { $0.message.createdAt > $1.message.createdAt }
        .prefix(240)
        .map { item in
          NativeKnowledgeRecord(
            id: "chat:\(item.session.id):\(item.message.id)",
            source: .chat,
            title: item.session.title,
            text: item.message.text,
            url: nil,
            updatedAt: item.message.createdAt
          )
        }

      records = dedupe(attachmentRecords + projectRecords + chatRecords)
      saveLocked()
    }
  }

  func upsert(_ newRecords: [NativeKnowledgeRecord]) {
    guard !newRecords.isEmpty else {
      return
    }

    queue.sync {
      var next = records.filter { existing in
        !newRecords.contains { $0.id == existing.id }
      }
      next.append(contentsOf: newRecords)
      records = dedupe(next)
      saveLocked()
    }
  }

  func search(query: String, limit: Int = 5) -> [NativeKnowledgeMatch] {
    let terms = NativeLocalKnowledgeStore.searchTerms(query)
    guard !terms.isEmpty else {
      return []
    }

    return queue.sync {
      records
        .compactMap { record -> NativeKnowledgeMatch? in
          let searchable = "\(record.title) \(record.text)".lowercased()
          let score = terms.reduce(0) { partial, term in
            partial + (searchable.contains(term) ? 1 : 0)
          }
          guard score > 0 else {
            return nil
          }
          return NativeKnowledgeMatch(
            record: record,
            score: score,
            excerpt: NativeLocalKnowledgeStore.excerpt(from: record.text, terms: terms)
          )
        }
        .sorted {
          if $0.score != $1.score {
            return $0.score > $1.score
          }
          return $0.record.updatedAt > $1.record.updatedAt
        }
        .prefix(limit)
        .map { $0 }
    }
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([NativeKnowledgeRecord].self, from: data)
    else {
      records = []
      return
    }
    records = decoded
  }

  private func saveLocked() {
    guard let data = try? JSONEncoder().encode(records) else {
      return
    }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func dedupe(_ input: [NativeKnowledgeRecord]) -> [NativeKnowledgeRecord] {
    var seen = Set<String>()
    return input
      .sorted { $0.updatedAt > $1.updatedAt }
      .filter { seen.insert($0.id).inserted }
      .prefix(400)
      .map { $0 }
  }

  static func searchTerms(_ query: String) -> [String] {
    query
      .lowercased()
      .split { character in
        !character.isLetter && !character.isNumber
      }
      .map(String.init)
      .filter { $0.count >= 2 }
      .filter { !stopWords.contains($0) }
      .removingDuplicates()
      .prefix(16)
      .map { $0 }
  }

  private static func excerpt(from text: String, terms: [String]) -> String {
    let paragraphs = text
      .components(separatedBy: CharacterSet.newlines)
      .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    let ranked = paragraphs
      .map { paragraph -> (score: Int, text: String) in
        let lower = paragraph.lowercased()
        return (terms.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }, paragraph)
      }
      .filter { $0.score > 0 }
      .sorted { $0.score > $1.score }
      .map(\.text)

    let selected = ranked.first ?? paragraphs.first ?? text
    return NativePromptCompressor.clipped(selected, maxEstimatedTokens: 170)
  }

  private static let stopWords: Set<String> = [
    "the", "and", "for", "with", "from", "this", "that", "what", "when", "where",
    "how", "about", "검색", "정리", "알려", "내용", "관련", "있는", "없는", "에서", "으로",
    "그리고", "하지만", "그러면"
  ]
}

enum NativeDocumentTextExtractor {
  static func knowledgeRecords(from attachments: [NativeAttachment]) -> [NativeKnowledgeRecord] {
    attachments.compactMap { attachment in
      guard let text = extractedText(from: attachment), !text.isEmpty else {
        return nil
      }
      return NativeKnowledgeRecord(
        id: "attachment:\(attachment.id)",
        source: .attachment,
        title: attachment.name,
        text: text,
        url: attachment.url,
        updatedAt: Date()
      )
    }
  }

  static func promptText(from attachments: [NativeAttachment], maxTokens: Int) -> String? {
    let records = knowledgeRecords(from: attachments)
    guard !records.isEmpty else {
      return nil
    }

    let text = records
      .map { record in
        """
        File: \(record.title)
        Content excerpt:
        \(NativePromptCompressor.clipped(record.text, maxEstimatedTokens: max(120, maxTokens / max(1, records.count))))
        """
      }
      .joined(separator: "\n\n")
    return NativePromptCompressor.clipped(text, maxEstimatedTokens: maxTokens)
  }

  private static func extractedText(from attachment: NativeAttachment) -> String? {
    guard let url = URL(string: attachment.url), url.isFileURL else {
      return nil
    }

    let hasAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    if attachment.mimeType == "application/pdf" || url.pathExtension.lowercased() == "pdf" {
      return pdfText(from: url)
    }

    if attachment.type == "image" {
      return recognizedText(from: url)
    }

    if isTextLike(attachment: attachment, url: url) {
      return textFileContents(from: url)
    }

    return nil
  }

  private static func isTextLike(attachment: NativeAttachment, url: URL) -> Bool {
    let mime = attachment.mimeType.lowercased()
    let ext = url.pathExtension.lowercased()
    return mime.hasPrefix("text/") ||
      mime.contains("json") ||
      mime.contains("xml") ||
      ["txt", "md", "markdown", "json", "csv", "tsv", "xml", "html", "css", "js", "ts", "tsx", "jsx", "swift", "kt", "java", "py", "go", "rs", "c", "cpp", "h"].contains(ext)
  }

  private static func textFileContents(from url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else {
      return nil
    }
    defer {
      try? handle.close()
    }

    let data = handle.readData(ofLength: 700_000)
    return String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .utf16)
      ?? String(data: data, encoding: .isoLatin1)
  }

  private static func pdfText(from url: URL) -> String? {
    guard let document = PDFDocument(url: url) else {
      return nil
    }

    var parts: [String] = []
    let pageLimit = min(document.pageCount, 24)
    for index in 0..<pageLimit {
      if let pageText = document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
         !pageText.isEmpty {
        parts.append(pageText)
      }
    }
    return parts.joined(separator: "\n\n")
  }

  private static func recognizedText(from url: URL) -> String? {
    guard let image = UIImage(contentsOfFile: url.path)?.cgImage else {
      return nil
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["ko-KR", "en-US"]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return nil
    }

    return request.results?
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

final class NativeDeviceContextProvider: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var lastLocation: CLLocation?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = 500
  }

  func refreshLocationIfAuthorized() {
    guard CLLocationManager.locationServicesEnabled() else {
      return
    }

    switch locationManager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      locationManager.requestLocation()
    case .denied, .restricted, .notDetermined:
      break
    @unknown default:
      break
    }
  }

  func locationContextLines(now: Date) -> [String] {
    guard CLLocationManager.locationServicesEnabled() else {
      return ["Location services: disabled"]
    }

    switch locationManager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      guard let location = lastLocation else {
        return ["Location: permission granted, waiting for device location"]
      }

      let age = max(0, now.timeIntervalSince(location.timestamp))
      var parts = [
        String(format: "latitude %.5f", location.coordinate.latitude),
        String(format: "longitude %.5f", location.coordinate.longitude),
        String(format: "accuracy %.0fm", location.horizontalAccuracy),
        String(format: "updated %.0fs ago", age)
      ]

      if location.verticalAccuracy >= 0 {
        parts.append(String(format: "altitude %.0fm", location.altitude))
        parts.append(String(format: "vertical accuracy %.0fm", location.verticalAccuracy))
      }

      return ["Location: \(parts.joined(separator: ", "))"]
    case .denied:
      return ["Location: permission denied"]
    case .restricted:
      return ["Location: restricted by system"]
    case .notDetermined:
      return ["Location: permission not requested"]
    @unknown default:
      return ["Location: authorization unknown"]
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    lastLocation = locations.last
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
