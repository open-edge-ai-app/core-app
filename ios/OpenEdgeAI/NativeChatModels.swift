import Foundation
import SwiftUI

struct NativeAttachment: Identifiable, Codable, Equatable {
  var id: String
  var name: String
  var type: String
  var mimeType: String
  var sizeBytes: Int64?
  var url: String

  var compactDisplayName: String {
    Self.compactFileName(name)
  }

  private static func compactFileName(_ fileName: String) -> String {
    let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 18 else {
      return trimmed.isEmpty ? fileName : trimmed
    }

    let nsName = trimmed as NSString
    let fileExtension = nsName.pathExtension
    let baseName = nsName.deletingPathExtension
    let prefix = String((baseName.isEmpty ? trimmed : baseName).prefix(9))
    guard !fileExtension.isEmpty else {
      return "\(prefix)..."
    }
    return "\(prefix)...\(fileExtension)"
  }
}

struct NativeSearchSourceReference: Identifiable, Codable, Equatable {
  var id: String
  var title: String
  var url: String
  var snippet: String

  var host: String {
    URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url
  }

  var faviconURL: URL? {
    guard !host.isEmpty else {
      return nil
    }
    return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
  }
}

struct NativeMessage: Identifiable, Codable, Equatable {
  var id: String
  var role: NativeRole
  var text: String
  var createdAt: Date
  var attachments: [NativeAttachment]
  var sourceReferences: [NativeSearchSourceReference]
  var contextCompressed: Bool

  init(
    id: String,
    role: NativeRole,
    text: String,
    createdAt: Date,
    attachments: [NativeAttachment],
    sourceReferences: [NativeSearchSourceReference] = [],
    contextCompressed: Bool = false
  ) {
    self.id = id
    self.role = role
    self.text = text
    self.createdAt = createdAt
    self.attachments = attachments
    self.sourceReferences = sourceReferences
    self.contextCompressed = contextCompressed
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case role
    case text
    case createdAt
    case attachments
    case sourceReferences
    case contextCompressed
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    role = try container.decode(NativeRole.self, forKey: .role)
    text = try container.decode(String.self, forKey: .text)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    attachments = try container.decodeIfPresent([NativeAttachment].self, forKey: .attachments) ?? []
    sourceReferences = try container.decodeIfPresent([NativeSearchSourceReference].self, forKey: .sourceReferences) ?? []
    contextCompressed = try container.decodeIfPresent(Bool.self, forKey: .contextCompressed) ?? false
  }
}

enum NativeDraftMode: String, Codable, Equatable {
  case standard
  case search
}

enum NativeToolName: String, CaseIterable, Equatable {
  case webSearch = "web_search"
  case todo = "todo"

  var displayName: String {
    switch self {
    case .webSearch:
      return "웹 검색"
    case .todo:
      return "Todo"
    }
  }
}