import Foundation
import UIKit

extension NativeWebSearchClient {
  func parseSearchResults(from html: String, queryIndex: Int) -> [SearchResult] {
    let pattern = #"<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>(.*?)</a>"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    let range = NSRange(html.startIndex..<html.endIndex, in: html)
    let matches = regex?.matches(in: html, range: range) ?? []
    var seen = Set<String>()
    var results: [SearchResult] = []

    for match in matches {
      guard match.numberOfRanges >= 3,
            let hrefRange = Range(match.range(at: 1), in: html),
            let titleRange = Range(match.range(at: 2), in: html),
            let url = resolvedSearchURL(String(html[hrefRange]))
      else {
        continue
      }

      let urlString = normalizedURL(url)
      guard seen.insert(urlString).inserted else {
        continue
      }

      let title = cleanHTML(String(html[titleRange]))
      guard !title.isEmpty else {
        continue
      }

      let snippet = resultSnippet(in: html, after: match.range.location + match.range.length)
      results.append(SearchResult(rank: results.count, queryIndex: queryIndex, title: title, snippet: snippet, url: url))
      if results.count >= maxSearchResultCandidates {
        break
      }
    }

    return results
  }

  func parseRSSResults(from xml: String, queryIndex: Int) -> [SearchResult] {
    let itemPattern = #"(?is)<item\b[^>]*>(.*?)</item>"#
    let regex = try? NSRegularExpression(pattern: itemPattern)
    let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
    let matches = regex?.matches(in: xml, range: range) ?? []
    var seen = Set<String>()
    var results: [SearchResult] = []

    for match in matches {
      guard let itemRange = Range(match.range(at: 1), in: xml) else {
        continue
      }
      let item = String(xml[itemRange])
      let title = rssField("title", in: item)
      let link = rssField("link", in: item)
      let snippet = rssField("description", in: item)
      guard !title.isEmpty,
            let url = URL(string: link),
            seen.insert(normalizedURL(url)).inserted
      else {
        continue
      }

      results.append(SearchResult(rank: results.count, queryIndex: queryIndex, title: title, snippet: snippet, url: url))
      if results.count >= maxSearchResultCandidates {
        break
      }
    }

    return results
  }

  func rssField(_ name: String, in item: String) -> String {
    let pattern = #"(?is)<\#(name)\b[^>]*>(.*?)</\#(name)>"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: item, range: NSRange(item.startIndex..<item.endIndex, in: item)),
          match.numberOfRanges >= 2,
          let range = Range(match.range(at: 1), in: item)
    else {
      return ""
    }
    return cleanHTML(String(item[range]))
  }
}
