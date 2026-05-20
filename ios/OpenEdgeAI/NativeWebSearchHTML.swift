import Foundation
import UIKit

extension NativeWebSearchClient {
  func resultSnippet(in html: String, after utf16Location: Int) -> String {
    let length = min(2_200, max(0, html.utf16.count - utf16Location))
    guard length > 0 else {
      return ""
    }

    let searchRange = NSRange(location: utf16Location, length: length)
    let pattern = #"(?is)<(?:a|div|td)[^>]+class="[^"]*(?:result__snippet|result-snippet)[^"]*"[^>]*>(.*?)</(?:a|div|td)>"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: html, range: searchRange),
          match.numberOfRanges >= 2,
          let range = Range(match.range(at: 1), in: html)
    else {
      return ""
    }

    return cleanHTML(String(html[range]))
  }

  func cleanHTML(_ html: String) -> String {
    var text = html
    let removalPatterns = [
      #"(?is)<script\b[^>]*>.*?</script>"#,
      #"(?is)<style\b[^>]*>.*?</style>"#,
      #"(?is)<noscript\b[^>]*>.*?</noscript>"#,
      #"(?is)<svg\b[^>]*>.*?</svg>"#,
      #"(?is)<!--.*?-->"#
    ]

    for pattern in removalPatterns {
      text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    }

    text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    text = decodeHTMLEntities(text)
    return text
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func cleanPageText(_ html: String) -> String {
    var text = html
    let removalPatterns = [
      #"(?is)<script\b[^>]*>.*?</script>"#,
      #"(?is)<style\b[^>]*>.*?</style>"#,
      #"(?is)<noscript\b[^>]*>.*?</noscript>"#,
      #"(?is)<svg\b[^>]*>.*?</svg>"#,
      #"(?is)<!--.*?-->"#
    ]

    for pattern in removalPatterns {
      text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    }

    text = text.replacingOccurrences(
      of: #"(?i)</?(?:p|div|section|article|br|li|h[1-6]|tr)\b[^>]*>"#,
      with: "\n",
      options: .regularExpression
    )
    text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    text = decodeHTMLEntities(text)
    return text
      .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func extractRelevantPageText(_ text: String, query: String) -> String {
    let normalized = text
      .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      return ""
    }

    let terms = searchTerms(query)
    guard !terms.isEmpty else {
      return clipped(normalized, maxLength: 2_000)
    }

    let paragraphs = normalized
      .components(separatedBy: CharacterSet.newlines)
      .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.count >= 80 }

    let ranked = paragraphs
      .map { paragraph -> (score: Int, paragraph: String) in
        let lower = paragraph.lowercased()
        let score = terms.reduce(0) { partial, term in
          partial + (lower.contains(term) ? 1 : 0)
        }
        return (score, paragraph)
      }
      .filter { $0.score > 0 }
      .sorted {
        if $0.score != $1.score {
          return $0.score > $1.score
        }
        return $0.paragraph.count > $1.paragraph.count
      }
      .map(\.paragraph)

    let selected = ranked.isEmpty ? Array(paragraphs.prefix(3)) : Array(ranked.prefix(4))
    return clipped(selected.joined(separator: "\n\n"), maxLength: 2_000)
  }

  func decodeHTMLEntities(_ text: String) -> String {
    guard let data = text.data(using: .utf8),
          let attributed = try? NSAttributedString(
            data: data,
            options: [
              .documentType: NSAttributedString.DocumentType.html,
              .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
          )
    else {
      return text
    }

    return attributed.string
  }

  func clipped(_ text: String, maxLength: Int) -> String {
    let cleaned = text
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count > maxLength else {
      return cleaned
    }

    return "\(cleaned.prefix(maxLength))..."
  }

  func normalizedURL(_ url: URL) -> String {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.fragment = nil
    let filteredQueryItems = components?.queryItems?
      .filter { item in
        let name = item.name.lowercased()
        return !name.hasPrefix("utm_") && name != "fbclid" && name != "gclid"
      }
      .sorted { $0.name < $1.name }
    components?.queryItems = filteredQueryItems
    return (components?.url?.absoluteString ?? url.absoluteString)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      .lowercased()
  }

  var searchStopWords: Set<String> {
    [
      "the", "and", "for", "with", "from", "about", "this", "that", "what", "when", "where",
      "검색", "정리", "알려", "최신", "최근", "현재", "오늘", "관련", "내용"
    ]
  }
}
