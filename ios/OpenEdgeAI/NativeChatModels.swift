import Foundation
import SwiftUI

struct NativeAttachment: Identifiable, Codable, Equatable {
  var id: String
  var name: String
  var type: String
  var mimeType: String
  var sizeBytes: Int64?
  var url: String
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

  var displayName: String {
    switch self {
    case .webSearch:
      return "웹 검색"
    }
  }
}

enum NativeToolRegistry {
  static func selectedTools(for draft: NativeDraft) -> [NativeToolName] {
    if draft.mode == .search {
      return [.webSearch]
    }

    return shouldUseWebSearch(draft.text) ? [.webSearch] : []
  }

  static func promptSection(searchExecuted: Bool) -> String {
    if searchExecuted {
      return """
      App tool result:
      - web_search was executed before this response.
      - Answer directly using the visited web pages and conversation context.
      - If visited web pages are present, do not apologize for lacking realtime access or say you cannot provide current information.
      - Never write phrases like "제가 현재 시점의 실시간 정보를 직접 제공해 드릴 수는 없지만" when search sources are available.
      - Do not describe the search context as information "provided by the user"; it was gathered by the app.
      - Cite search-backed claims inline with source numbers such as [1] or [2].
      """
    }

    return """
    Available app tools:
    - web_search(query): searches public web pages, opens relevant pages, extracts readable snippets, and returns citeable sources.
    Tool policy:
    - The app executes web_search automatically before the model response when the request needs current, public, source-backed, or external web information.
    - The /search slash command is only a shortcut that forces web_search; users do not need to type it for search to work.
    """
  }

  private static func shouldUseWebSearch(_ text: String) -> Bool {
    let normalized = text.lowercased()
    guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }

    let explicitTriggers = [
      "검색", "찾아", "구글", "웹", "인터넷", "출처", "근거", "링크",
      "search", "web", "internet", "source", "sources", "lookup", "look up"
    ]
    if explicitTriggers.contains(where: { normalized.contains($0) }) {
      return true
    }

    let volatileTriggers = [
      "최신", "최근", "오늘", "현재", "뉴스", "가격", "주가", "일정", "법", "규정",
      "latest", "recent", "today", "current", "news", "price", "stock", "schedule", "law", "regulation"
    ]
    return volatileTriggers.contains { normalized.contains($0) }
  }
}

struct NativeDraft: Identifiable, Codable, Equatable {
  var id: String
  var text: String
  var attachments: [NativeAttachment]
  var createdAt: Date
  var mode: NativeDraftMode

  init(
    id: String,
    text: String,
    attachments: [NativeAttachment],
    createdAt: Date,
    mode: NativeDraftMode = .standard
  ) {
    self.id = id
    self.text = text
    self.attachments = attachments
    self.createdAt = createdAt
    self.mode = mode
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case text
    case attachments
    case createdAt
    case mode
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    text = try container.decode(String.self, forKey: .text)
    attachments = try container.decode([NativeAttachment].self, forKey: .attachments)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    mode = try container.decodeIfPresent(NativeDraftMode.self, forKey: .mode) ?? .standard
  }
}
