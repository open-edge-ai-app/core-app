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

enum NativeToolRegistry {
  static func selectedTools(for draft: NativeDraft) -> [NativeToolName] {
    if draft.mode == .search {
      return [.webSearch]
    }

    if shouldUseTodoTool(draft.text) && !hasExplicitWebSearchTrigger(draft.text) {
      return [.todo]
    }

    return shouldUseWebSearch(draft.text) ? [.webSearch] : []
  }

  static func promptSection(searchExecuted: Bool) -> String {
    let todoToolSection = """
    Todo app tools:
    - todo_list(filter, date, include_completed): reads Todo tasks. filter is all, today, tomorrow, overdue, or date.
    - todo_create(title, note, start_at, end_at, repeat, labels, starred): creates a Todo. Use at most one label.
    - todo_update(id or query, title, note, start_at, end_at, repeat, labels, starred): edits a Todo. Use at most one label.
    - todo_complete(id or query, date, completed): marks a Todo or one recurring occurrence complete/incomplete.
    - todo_delete(id or query): deletes a Todo.
    - todo_star(id or query, starred): changes important/starred state.
    - todo_label_create(name), todo_label_delete(name), todo_label_assign(id or query, labels, mode): manages tags. Each Todo can have only one tag; mode is replace or remove.
    - todo_subtask_add(id or query, title), todo_subtask_toggle(id or query, subtask, completed), todo_subtask_delete(id or query, subtask): manages subtasks.
    - todo_settings_update(hide_completed, show_tags, calendar_sync): updates Todo display/calendar settings.
    Todo tool call format:
    - When the user asks to change, create, delete, list, tag, schedule, or configure Todo items, include one fenced block exactly like:
    ```openedge_tool
    {"tool":"todo_create","arguments":{"title":"...","start_at":"2026-05-20 13:00","end_at":"2026-05-20 14:00","repeat":"none","labels":["..."]}}
    ```
    - Todo, schedule, reminder, meeting, and appointment requests have priority over web_search unless the user explicitly asks to search the web.
    - Named people, companies, venues, or places inside a Todo sentence are usually Todo title/note content, not a reason to search.
    - Korean declarative schedule statements such as "오늘 오후 4시부터 5시까지 대한상공회의소 미팅 가신데" mean create a Todo/schedule item unless the sentence is clearly a question.
    - You may include an array of calls in one block.
    - Dates must use the user's local timezone in yyyy-MM-dd HH:mm format when possible.
    - Keep any normal answer concise; the app will execute the tool and hide the JSON block from the user.
    """

    if searchExecuted {
      return """
      App tool result:
      - web_search was executed before this response.
      - Answer directly using the visited web pages and conversation context.
      - If visited web pages are present, do not apologize for lacking realtime access or say you cannot provide current information.
      - Never write phrases like "제가 현재 시점의 실시간 정보를 직접 제공해 드릴 수는 없지만" when search sources are available.
      - Do not describe the search context as information "provided by the user"; it was gathered by the app.
      - Cite search-backed claims inline with source numbers such as [1] or [2].

      \(todoToolSection)
      """
    }

    return """
    Available app tools:
    - web_search(query): searches public web pages, opens relevant pages, extracts readable snippets, and returns citeable sources.
    Tool policy:
    - The app executes web_search automatically before the model response when the request needs current, public, source-backed, or external web information.
    - The /search slash command is only a shortcut that forces web_search; users do not need to type it for search to work.

    \(todoToolSection)
    """
  }

  private static func shouldUseWebSearch(_ text: String) -> Bool {
    let normalized = text.lowercased()
    guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }

    if hasExplicitWebSearchTrigger(normalized) {
      return true
    }

    let volatileTriggers = [
      "최신", "최근", "오늘", "현재", "뉴스", "가격", "주가", "일정", "법", "규정",
      "latest", "recent", "today", "current", "news", "price", "stock", "schedule", "law", "regulation"
    ]
    return volatileTriggers.contains { normalized.contains($0) }
  }

  private static func hasExplicitWebSearchTrigger(_ text: String) -> Bool {
    let normalized = text.lowercased()
    let explicitTriggers = [
      "검색", "찾아", "구글", "웹", "인터넷", "출처", "근거", "링크",
      "search", "web", "internet", "source", "sources", "lookup", "look up"
    ]
    return explicitTriggers.contains { normalized.contains($0) }
  }

  private static func shouldUseTodoTool(_ text: String) -> Bool {
    let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      return false
    }

    let directTodoTerms = [
      "todo", "to-do", "task", "할 일", "할일", "태스크",
      "리마인드", "리마인더", "알림", "remind", "reminder"
    ]
    if containsAny(directTodoTerms, in: normalized) {
      return true
    }

    let eventTerms = [
      "일정", "스케줄", "캘린더", "회의", "미팅", "약속", "예약", "면담", "방문", "통화", "콜",
      "schedule", "calendar", "meeting", "appointment", "reservation", "call"
    ]
    let scheduleVerbs = [
      "추가", "등록", "넣어", "만들", "생성", "저장", "기록", "잡아", "정리",
      "가신데", "간데", "가신다고", "간다고", "있대", "있어", "예정", "잡혀", "잡혔", "해야", "하래",
      "add", "create", "save", "schedule", "book"
    ]
    let hasEventTerm = containsAny(eventTerms, in: normalized)
    let hasScheduleVerb = containsAny(scheduleVerbs, in: normalized)
    let hasTimeExpression = matchesAny(
      [
        #"오전|오후|아침|점심|저녁|밤"#,
        #"\d{1,2}\s*시"#,
        #"\d{1,2}\s*:\s*\d{2}"#,
        #"오늘|내일|모레|이번\s*주|다음\s*주|다음\s*달"#,
        #"\d{1,2}\s*월\s*\d{1,2}\s*일"#,
        #"\d{4}[-./]\d{1,2}[-./]\d{1,2}"#
      ],
      in: normalized
    )

    if hasEventTerm && (hasTimeExpression || hasScheduleVerb) {
      return true
    }

    return hasScheduleVerb && hasTimeExpression
  }

  private static func containsAny(_ needles: [String], in text: String) -> Bool {
    needles.contains { text.contains($0) }
  }

  private static func matchesAny(_ patterns: [String], in text: String) -> Bool {
    patterns.contains { pattern in
      text.range(of: pattern, options: .regularExpression) != nil
    }
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
