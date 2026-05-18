import Foundation
import SwiftUI

extension Color {
  static var oeBackground: Color { Color(.systemBackground) }
  static var oeGroupedBackground: Color { Color(.systemGroupedBackground) }
  static var oeSurface: Color { Color(.secondarySystemBackground) }
  static var oeElevatedSurface: Color { Color(.tertiarySystemBackground) }
  static var oeText: Color { .primary }
  static var oeSecondaryText: Color { .primary.opacity(0.62) }
  static var oeMutedText: Color { .primary.opacity(0.45) }
  static var oeSubtleFill: Color { .primary.opacity(0.055) }
  static var oeBorder: Color { .primary.opacity(0.10) }
  static var oeControlFill: Color { .primary }
  static var oeControlText: Color { Color(.systemBackground) }
}

enum NativeRole: String, Codable {
  case user
  case assistant
}

enum NativeModel: String, CaseIterable, Identifiable, Codable {
  case appleFoundation = "apple-foundation"
  case gemma = "gemma-4"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .appleFoundation:
      return "Apple Intelligence"
    case .gemma:
      return "Gemma 4"
    }
  }

  var subtitle: String {
    switch self {
    case .appleFoundation:
      return "Apple 기본 온디바이스 AI"
    case .gemma:
      return "다운로드 가능한 로컬 모델"
    }
  }
}

enum NativeFontSizeSetting: String, CaseIterable, Identifiable {
  case small
  case standard
  case large

  var id: String { rawValue }

  var title: String {
    switch self {
    case .small:
      return "작게"
    case .standard:
      return "기본"
    case .large:
      return "크게"
    }
  }

  var bodySize: CGFloat {
    switch self {
    case .small:
      return 15
    case .standard:
      return 16
    case .large:
      return 18
    }
  }

  var inputSize: CGFloat {
    switch self {
    case .small:
      return 15
    case .standard:
      return 16
    case .large:
      return 17
    }
  }

  var sliderValue: Double {
    switch self {
    case .small:
      return 0
    case .standard:
      return 1
    case .large:
      return 2
    }
  }

  init(sliderValue: Double) {
    switch Int(sliderValue.rounded()) {
    case 0:
      self = .small
    case 2:
      self = .large
    default:
      self = .standard
    }
  }
}

enum NativeAppearanceMode: String, CaseIterable, Identifiable {
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .light:
      return "화이트 모드"
    case .dark:
      return "다크 모드"
    }
  }

  var colorScheme: ColorScheme {
    switch self {
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}

enum NativeAccentColor: String, CaseIterable, Identifiable {
  case black
  case blue
  case green
  case purple
  case orange

  var id: String { rawValue }

  var title: String {
    switch self {
    case .black:
      return "검정"
    case .blue:
      return "파랑"
    case .green:
      return "초록"
    case .purple:
      return "보라"
    case .orange:
      return "주황"
    }
  }

  var color: Color {
    switch self {
    case .black:
      return .primary
    case .blue:
      return .blue
    case .green:
      return .green
    case .purple:
      return .purple
    case .orange:
      return .orange
    }
  }

  var foregroundColor: Color {
    switch self {
    case .black:
      return .oeControlText
    case .green, .orange:
      return .black
    case .blue, .purple:
      return .white
    }
  }

  var subtleColor: Color {
    color.opacity(0.12)
  }
}

enum NativeLanguage: String, CaseIterable, Identifiable {
  case korean = "ko"
  case english = "en"
  case simplifiedChinese = "zh-Hans"
  case hindi = "hi"
  case spanish = "es"
  case french = "fr"
  case arabic = "ar"
  case bengali = "bn"
  case russian = "ru"
  case portuguese = "pt"
  case urdu = "ur"
  case indonesian = "id"
  case german = "de"
  case japanese = "ja"
  case turkish = "tr"

  var id: String { rawValue }

  var nativeName: String {
    switch self {
    case .korean:
      return "한국어"
    case .english:
      return "English"
    case .simplifiedChinese:
      return "简体中文"
    case .hindi:
      return "हिन्दी"
    case .spanish:
      return "Español"
    case .french:
      return "Français"
    case .arabic:
      return "العربية"
    case .bengali:
      return "বাংলা"
    case .russian:
      return "Русский"
    case .portuguese:
      return "Português"
    case .urdu:
      return "اردو"
    case .indonesian:
      return "Bahasa Indonesia"
    case .german:
      return "Deutsch"
    case .japanese:
      return "日本語"
    case .turkish:
      return "Türkçe"
    }
  }

  var englishName: String {
    switch self {
    case .korean:
      return "Korean"
    case .english:
      return "English"
    case .simplifiedChinese:
      return "Chinese (Simplified)"
    case .hindi:
      return "Hindi"
    case .spanish:
      return "Spanish"
    case .french:
      return "French"
    case .arabic:
      return "Arabic"
    case .bengali:
      return "Bengali"
    case .russian:
      return "Russian"
    case .portuguese:
      return "Portuguese"
    case .urdu:
      return "Urdu"
    case .indonesian:
      return "Indonesian"
    case .german:
      return "German"
    case .japanese:
      return "Japanese"
    case .turkish:
      return "Turkish"
    }
  }

  var localeIdentifier: String {
    switch self {
    case .korean:
      return "ko_KR"
    case .english:
      return "en_US"
    case .simplifiedChinese:
      return "zh_Hans_CN"
    case .hindi:
      return "hi_IN"
    case .spanish:
      return "es_ES"
    case .french:
      return "fr_FR"
    case .arabic:
      return "ar_SA"
    case .bengali:
      return "bn_BD"
    case .russian:
      return "ru_RU"
    case .portuguese:
      return "pt_BR"
    case .urdu:
      return "ur_PK"
    case .indonesian:
      return "id_ID"
    case .german:
      return "de_DE"
    case .japanese:
      return "ja_JP"
    case .turkish:
      return "tr_TR"
    }
  }
}

enum NativeDynamicIslandPet: String, CaseIterable, Identifiable {
  case orbit
  case stacky
  case nullSignal
  case luma
  case flux

  var id: String { rawValue }

  var title: String {
    switch self {
    case .orbit:
      return "Orbit"
    case .stacky:
      return "Stacky"
    case .nullSignal:
      return "Signal"
    case .luma:
      return "Luma"
    case .flux:
      return "Flux"
    }
  }

  var subtitle: String {
    switch self {
    case .orbit:
      return "푸른 궤도로 작업을 따라가는 기본 펫"
    case .stacky:
      return "노란 블록으로 차분하게 쌓아 올리는 펫"
    case .nullSignal:
      return "보라색 신호를 조용히 기다리는 펫"
    case .luma:
      return "민트빛으로 가볍게 반응하는 펫"
    case .flux:
      return "코랄 톤으로 빠르게 뛰는 펫"
    }
  }

  var primaryColor: Color {
    switch self {
    case .orbit:
      return Color(red: 0.18, green: 0.58, blue: 1)
    case .stacky:
      return Color(red: 1, green: 0.68, blue: 0.20)
    case .nullSignal:
      return Color(red: 0.62, green: 0.36, blue: 1)
    case .luma:
      return Color(red: 0.22, green: 0.86, blue: 0.68)
    case .flux:
      return Color(red: 1, green: 0.38, blue: 0.34)
    }
  }

  var secondaryColor: Color {
    switch self {
    case .orbit:
      return Color(red: 0.55, green: 0.92, blue: 1)
    case .stacky:
      return Color(red: 1, green: 0.93, blue: 0.48)
    case .nullSignal:
      return Color(red: 0.90, green: 0.78, blue: 1)
    case .luma:
      return Color(red: 0.78, green: 1, blue: 0.42)
    case .flux:
      return Color(red: 1, green: 0.78, blue: 0.22)
    }
  }

  var outlineColor: Color {
    switch self {
    case .orbit:
      return Color(red: 0.04, green: 0.12, blue: 0.24)
    case .stacky:
      return Color(red: 0.28, green: 0.17, blue: 0.04)
    case .nullSignal:
      return Color(red: 0.20, green: 0.08, blue: 0.36)
    case .luma:
      return Color(red: 0.04, green: 0.24, blue: 0.22)
    case .flux:
      return Color(red: 0.36, green: 0.08, blue: 0.05)
    }
  }

  var eyeColor: Color {
    switch self {
    case .nullSignal:
      return Color.white
    case .flux:
      return Color.white
    default:
      return Color(red: 0.03, green: 0.05, blue: 0.07)
    }
  }
}

enum NativeDynamicIslandPetMotion: String {
  case running
  case resting
  case sleeping
}

enum NativeDynamicIslandPhase {
  case hidden
  case generating
  case queued
}

struct NativeDynamicIslandState {
  var phase: NativeDynamicIslandPhase
  var title: String
  var subtitle: String
  var detail: String
  var progress: Double
  var motion: NativeDynamicIslandPetMotion
  var pet: NativeDynamicIslandPet
  var isPetEnabled: Bool
  var queuedCount: Int
  var isGenerating: Bool

  var isVisible: Bool {
    phase != .hidden
  }

  static let hidden = NativeDynamicIslandState(
    phase: .hidden,
    title: "",
    subtitle: "",
    detail: "",
    progress: 0,
    motion: .resting,
    pet: .orbit,
    isPetEnabled: false,
    queuedCount: 0,
    isGenerating: false
  )
}

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

struct NativeWebSearchSource: Identifiable, Equatable {
  let id: String
  let title: String
  let snippet: String
  let url: String
  let pageText: String

  init(title: String, snippet: String, url: String, pageText: String) {
    self.id = url
    self.title = title
    self.snippet = snippet
    self.url = url
    self.pageText = pageText
  }

  var reference: NativeSearchSourceReference {
    NativeSearchSourceReference(id: id, title: title, url: url, snippet: snippet)
  }
}

struct NativeWebSearchContext: Equatable {
  let query: String
  let sources: [NativeWebSearchSource]
  let errorMessage: String?

  var sourceReferences: [NativeSearchSourceReference] {
    sources.map(\.reference)
  }

  func promptSection(maxEstimatedTokens: Int) -> String {
    var lines = ["Search query: \(query)"]

    if let errorMessage {
      lines.append("Search status: \(errorMessage)")
    }

    if sources.isEmpty {
      lines.append("Search results: none")
    } else {
      lines.append("Citation format: cite visited pages inline as [1], [2], matching the page numbers below. Compare multiple sources when possible.")
      lines.append("Visited web pages:")
      let headerBudget = NativePromptCompressor.estimatedTokens(lines.joined(separator: "\n"))
      let perSourceBudget = max(160, (maxEstimatedTokens - headerBudget) / max(1, sources.count))
      for (index, source) in sources.enumerated() {
        let clippedSnippet = NativePromptCompressor.clipped(source.snippet, maxEstimatedTokens: 90)
        let fixedSourceText = """
        \(index + 1). \(source.title)
        URL: \(source.url)
        Snippet: \(clippedSnippet)
        Page content:
        """
        let pageBudget = max(80, perSourceBudget - NativePromptCompressor.estimatedTokens(fixedSourceText))
        let pageText = NativePromptCompressor.clipped(source.pageText, maxEstimatedTokens: pageBudget)
        lines.append("""
        \(fixedSourceText)
        \(pageText)
        """)
      }
    }

    return lines.joined(separator: "\n")
  }
}

struct NativePrivacyMaskingResult {
  var text: String
  var changed: Bool
  var findings: [String]
}

enum NativePrivacyMasker {
  static func maskForExternalSearch(_ text: String) -> NativePrivacyMaskingResult {
    var masked = text
    var findings: [String] = []

    let patterns: [(String, String, String)] = [
      (#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "[email]", "email"),
      (#"(?:\+?\d[\d\s().-]{7,}\d)"#, "[phone-or-id]", "phone_or_id"),
      (#"(?:file|/Users|/private|/var|~/)[^\s]+"#, "[local-file]", "local_file"),
      (#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, "[ip-address]", "ip_address"),
      (#"\b(?:lat(?:itude)?|위도)\s*[:=]?\s*-?\d+(?:\.\d+)?\b"#, "[latitude]", "latitude"),
      (#"\b(?:lon(?:gitude)?|경도)\s*[:=]?\s*-?\d+(?:\.\d+)?\b"#, "[longitude]", "longitude")
    ]

    for (pattern, replacement, finding) in patterns {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        continue
      }
      let range = NSRange(masked.startIndex..<masked.endIndex, in: masked)
      if regex.firstMatch(in: masked, range: range) != nil {
        masked = regex.stringByReplacingMatches(in: masked, range: range, withTemplate: replacement)
        findings.append(finding)
      }
    }

    return NativePrivacyMaskingResult(
      text: masked.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines),
      changed: masked != text,
      findings: Array(Set(findings)).sorted()
    )
  }
}
