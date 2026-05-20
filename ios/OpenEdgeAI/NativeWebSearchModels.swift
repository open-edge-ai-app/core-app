import Foundation
import SwiftUI

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
