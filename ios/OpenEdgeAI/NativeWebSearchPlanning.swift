import Foundation
import UIKit

extension NativeWebSearchClient {
  func searchPlan(for query: String) -> SearchPlan {
    let normalized = query.lowercased()
    let deepSignals = [
      "비교", "비교해", "여러", "다양한", "종합", "리서치", "연구", "논문", "근거",
      "출처", "sources", "compare", "research", "papers", "evidence"
    ]
    let expandedSignals = [
      "최신", "최근", "오늘", "현재", "뉴스", "가격", "주가", "일정", "법", "규정",
      "latest", "recent", "today", "current", "news", "price", "stock", "schedule"
    ]

    if deepSignals.contains(where: { normalized.contains($0) }) {
      return SearchPlan(queryLimit: 3, sourceLimit: deepSourceLimit, candidateLimit: deepCandidateLimit)
    }

    if expandedSignals.contains(where: { normalized.contains($0) }) {
      return SearchPlan(queryLimit: 2, sourceLimit: expandedSourceLimit, candidateLimit: expandedCandidateLimit)
    }

    return SearchPlan(queryLimit: 1, sourceLimit: defaultSourceLimit, candidateLimit: defaultCandidateLimit)
  }

  func searchQueries(for query: String, plan: SearchPlan) -> [String] {
    let base = cleanSearchQuery(query)
    guard !base.isEmpty else {
      return [query]
    }

    var queries = [base]
    let normalized = base.lowercased()
    let hasRecentSignal = ["최신", "최근", "오늘", "현재", "latest", "recent", "today", "current"].contains {
      normalized.contains($0)
    }
    let hasResearchSignal = ["연구", "논문", "리서치", "research", "paper", "papers"].contains {
      normalized.contains($0)
    }

    if plan.queryLimit >= 2, hasRecentSignal {
      queries.append("\(base) 2025 2026")
    }

    if plan.queryLimit >= 3, hasResearchSignal {
      queries.append("\(base) research review")
    }

    return Array(queries.prefix(plan.queryLimit))
  }

  func cleanSearchQuery(_ query: String) -> String {
    query
      .replacingOccurrences(of: #"\B/search\b"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"(?i)\b(?:please|search|find|look up|tell me|show me)\b"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"(검색\s*(?:해\s*줘|해줘|해|해서\s*알려줘|해서\s*정리해줘)?)|(찾아\s*(?:봐|줘|서\s*알려줘)?)|(알려\s*줘)|(정리\s*해\s*줘)"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'.,:;?!")))
  }

  func selectPageCandidates(from results: [SearchResult], query: String, plan: SearchPlan) -> [SearchResult] {
    let terms = searchTerms(query)
    return results
      .map { result in
        (score: relevanceScore(result, terms: terms), result: result)
      }
      .sorted {
        if $0.score != $1.score {
          return $0.score > $1.score
        }
        if $0.result.queryIndex != $1.result.queryIndex {
          return $0.result.queryIndex < $1.result.queryIndex
        }
        return $0.result.rank < $1.result.rank
      }
      .prefix(plan.candidateLimit)
      .map(\.result)
  }

  func relevanceScore(_ result: SearchResult, terms: [String]) -> Int {
    let searchable = "\(result.title) \(result.snippet) \(result.url.host ?? "") \(result.url.path)"
      .lowercased()
    let termScore = terms.reduce(0) { score, term in
      score + (searchable.contains(term) ? 8 : 0)
    }
    let host = result.url.host?.lowercased() ?? ""
    let authorityScore = authoritativeHostScore(host)
    let pathPenalty = result.url.path.count <= 1 ? 4 : 0
    let rankPenalty = min(result.rank, 6)
    return termScore + authorityScore - pathPenalty - rankPenalty
  }

  func authoritativeHostScore(_ host: String) -> Int {
    if host.hasSuffix(".gov") || host.hasSuffix(".edu") {
      return 8
    }

    let signals = [
      "docs.", "developer.", "support.", "github.com", "arxiv.org", "nature.com",
      "science.org", "who.int", "oecd.org", "apple.com", "google", "microsoft.com"
    ]
    return signals.contains(where: { host.contains($0) }) ? 5 : 0
  }

  func searchTerms(_ query: String) -> [String] {
    query
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .flatMap { token in
        token.components(separatedBy: CharacterSet(charactersIn: " \n\t"))
      }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.count >= 3 }
      .filter { !searchStopWords.contains($0) }
      .removingDuplicates()
  }

  func resolvedSearchURL(_ href: String) -> URL? {
    var raw = decodeHTMLEntities(href)

    if raw.hasPrefix("//") {
      raw = "https:\(raw)"
    } else if raw.hasPrefix("/") {
      raw = "https://duckduckgo.com\(raw)"
    }

    guard let url = URL(string: raw) else {
      return nil
    }

    if url.host?.contains("duckduckgo.com") == true,
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let encodedURL = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
       let destination = URL(string: encodedURL) {
      return destination
    }

    return url
  }
}
