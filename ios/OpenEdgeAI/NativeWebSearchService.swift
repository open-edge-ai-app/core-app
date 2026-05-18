import Foundation
import UIKit

enum NativePromptCompressor {
  static let maxModelTokens = 4_096
  static let responseReserveTokens = 820
  static let maxInputTokens = maxModelTokens - responseReserveTokens
  static let historyTokens = 920
  static let searchTokens = 1_180
  static let instructionTokens = 240
  static let currentRequestTokens = 1_180

  static func estimatedTokens(_ text: String) -> Int {
    var tokens = 0
    var asciiRun = 0

    func flushAsciiRun() {
      if asciiRun > 0 {
        tokens += max(1, (asciiRun + 3) / 4)
        asciiRun = 0
      }
    }

    for scalar in text.unicodeScalars {
      if CharacterSet.whitespacesAndNewlines.contains(scalar) {
        flushAsciiRun()
        continue
      }

      if scalar.value < 128, CharacterSet.alphanumerics.contains(scalar) {
        asciiRun += 1
        continue
      }

      flushAsciiRun()
      tokens += 1
    }

    flushAsciiRun()
    return tokens
  }

  static func clipped(_ text: String, maxEstimatedTokens: Int, keepTail: Bool = false) -> String {
    guard maxEstimatedTokens > 0,
          estimatedTokens(text) > maxEstimatedTokens
    else {
      return text
    }

    let marker = keepTail ? "... [앞부분 압축]\n" : "\n... [이후 내용 압축]"
    let markerTokens = estimatedTokens(marker)
    let targetTokens = max(1, maxEstimatedTokens - markerTokens)
    var selected = ""
    var usedTokens = 0
    let characters = keepTail ? Array(text.reversed()) : Array(text)

    for character in characters {
      let cost = max(0, estimatedTokens(String(character)))
      if usedTokens + cost > targetTokens {
        break
      }

      if keepTail {
        selected.insert(character, at: selected.startIndex)
      } else {
        selected.append(character)
      }
      usedTokens += cost
    }

    let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
    return keepTail ? marker + trimmed : trimmed + marker
  }

  static func clippedPreservingEdges(_ text: String, maxEstimatedTokens: Int) -> String {
    guard estimatedTokens(text) > maxEstimatedTokens else {
      return text
    }

    let marker = "\n\n[중간 컨텍스트 압축]\n\n"
    let markerTokens = estimatedTokens(marker)
    let edgeBudget = max(1, (maxEstimatedTokens - markerTokens) / 2)
    return clipped(text, maxEstimatedTokens: edgeBudget)
      + marker
      + clipped(text, maxEstimatedTokens: edgeBudget, keepTail: true)
  }

  static func containsCompressionMarker(_ text: String) -> Bool {
    text.contains("[중간 컨텍스트 압축]")
      || text.contains("[앞부분 압축]")
      || text.contains("[이후 내용 압축]")
      || (
        text.contains("Earlier ")
          && text.contains(" messages were omitted.")
      )
  }

  static func clippedCurrentRequest(_ text: String, maxEstimatedTokens: Int) -> String {
    if shouldPreserveStructure(text) {
      return clippedPreservingEdges(text, maxEstimatedTokens: maxEstimatedTokens)
    }
    return clipped(text, maxEstimatedTokens: maxEstimatedTokens, keepTail: true)
  }

  static func clippedMessageBody(_ text: String, maxEstimatedTokens: Int) -> String {
    if shouldPreserveStructure(text) {
      return clippedPreservingEdges(text, maxEstimatedTokens: maxEstimatedTokens)
    }
    return clipped(text, maxEstimatedTokens: maxEstimatedTokens, keepTail: true)
  }

  static func shouldPreserveStructure(_ text: String) -> Bool {
    let lower = text.lowercased()
    let lineCount = text.filter { $0 == "\n" }.count
    return lineCount >= 8
      || text.contains("```")
      || lower.contains("func ")
      || lower.contains("class ")
      || lower.contains("struct ")
      || lower.contains("import ")
      || lower.contains("const ")
      || lower.contains("let ")
      || lower.contains("var ")
      || lower.contains("return ")
      || lower.contains("error:")
      || lower.contains("exception")
      || lower.contains("stack trace")
  }
}

final class NativeWebSearchClient {
  static let shared = NativeWebSearchClient()

  private let defaultSourceLimit = 4
  private let expandedSourceLimit = 6
  private let deepSourceLimit = 8
  private let maxSearchResultCandidates = 14
  private let defaultCandidateLimit = 6
  private let expandedCandidateLimit = 9
  private let deepCandidateLimit = 12
  private let pageFetchBatchSize = 3
  private let session: URLSession

  private init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 12
    configuration.timeoutIntervalForResource = 24
    configuration.httpAdditionalHeaders = [
      "User-Agent": "OpenEdgeAI/1.0 iOS WebSearch"
    ]
    session = URLSession(configuration: configuration)
  }

  func search(query: String) async -> NativeWebSearchContext {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      return NativeWebSearchContext(
        query: query,
        sources: [],
        errorMessage: "검색할 내용이 충분하지 않습니다."
      )
    }

    let maskedQuery = NativePrivacyMasker.maskForExternalSearch(trimmedQuery)
    let publicQuery = cleanSearchQuery(maskedQuery.text)
    guard !publicQuery.isEmpty else {
      return NativeWebSearchContext(
        query: "[privacy-masked]",
        sources: [],
        errorMessage: "검색어가 개인 정보 또는 로컬 데이터만 포함되어 외부 검색을 실행하지 않았습니다."
      )
    }

    let plan = searchPlan(for: publicQuery)
    let directURLResults = directURLSearchResults(from: publicQuery)
    let queries = searchQueries(for: publicQuery, plan: plan)
    let results = await fetchSearchResults(queries: queries, plan: plan)
    let candidates = selectPageCandidates(from: directURLResults + results, query: publicQuery, plan: plan)
    let sources = await visitPages(query: publicQuery, results: candidates, plan: plan)

    return NativeWebSearchContext(
      query: queries.joined(separator: " / "),
      sources: sources,
      errorMessage: sources.isEmpty ? "검색 결과 페이지를 읽지 못했습니다." : nil
    )
  }

  private struct SearchResult {
    let rank: Int
    let queryIndex: Int
    let title: String
    let snippet: String
    let url: URL
  }

  private struct SearchPlan {
    let queryLimit: Int
    let sourceLimit: Int
    let candidateLimit: Int
  }

  private func fetchSearchResults(queries: [String], plan: SearchPlan) async -> [SearchResult] {
    await withTaskGroup(of: [SearchResult].self) { group in
      for (queryIndex, query) in queries.prefix(plan.queryLimit).enumerated() {
        group.addTask { [weak self] in
          guard let self else {
            return []
          }
          return await self.fetchSearchResults(query: query, queryIndex: queryIndex)
        }
      }

      var seen = Set<String>()
      var merged: [SearchResult] = []
      for await results in group {
        for result in results {
          guard seen.insert(normalizedURL(result.url)).inserted else {
            continue
          }
          merged.append(result)
        }
      }

      return merged
        .sorted {
          if $0.queryIndex != $1.queryIndex {
            return $0.queryIndex < $1.queryIndex
          }
          return $0.rank < $1.rank
        }
        .prefix(maxSearchResultCandidates)
        .map { $0 }
    }
  }

  private func fetchSearchResults(query: String, queryIndex: Int) async -> [SearchResult] {
    do {
      return try await fetchDuckDuckGoResults(query: query, queryIndex: queryIndex)
    } catch {
      return (try? await fetchBingRSSResults(query: query, queryIndex: queryIndex)) ?? []
    }
  }

  private func fetchDuckDuckGoResults(query: String, queryIndex: Int) async throws -> [SearchResult] {
    var components = URLComponents(string: "https://duckduckgo.com/html/")
    components?.queryItems = [
      URLQueryItem(name: "q", value: query)
    ]

    guard let url = components?.url else {
      return []
    }

    let searchHTML = try await fetchString(from: url)
    return parseSearchResults(from: searchHTML, queryIndex: queryIndex)
  }

  private func directURLSearchResults(from query: String) -> [SearchResult] {
    let pattern = #"https?://[^\s\])>\"']+"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return []
    }
    let range = NSRange(query.startIndex..<query.endIndex, in: query)
    return regex.matches(in: query, range: range)
      .compactMap { match -> URL? in
        guard let urlRange = Range(match.range, in: query) else {
          return nil
        }
        return URL(string: String(query[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:")))
      }
      .removingDuplicates()
      .enumerated()
      .map { index, url in
        SearchResult(
          rank: index,
          queryIndex: -1,
          title: url.host ?? url.absoluteString,
          snippet: "",
          url: url
        )
      }
  }

  private func fetchBingRSSResults(query: String, queryIndex: Int) async throws -> [SearchResult] {
    var components = URLComponents(string: "https://www.bing.com/search")
    components?.queryItems = [
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "format", value: "rss"),
      URLQueryItem(name: "mkt", value: "ko-KR"),
      URLQueryItem(name: "setlang", value: "ko-KR")
    ]

    guard let url = components?.url else {
      return []
    }

    let xml = try await fetchString(from: url, accept: "application/rss+xml,application/xml,text/xml")
    return parseRSSResults(from: xml, queryIndex: queryIndex)
  }

  private func visitPages(query: String, results: [SearchResult], plan: SearchPlan) async -> [NativeWebSearchSource] {
    var sources: [NativeWebSearchSource] = []
    var batchStart = 0

    while batchStart < results.count && sources.count < plan.sourceLimit {
      let batchEnd = min(batchStart + pageFetchBatchSize, results.count)
      let batch = Array(results[batchStart..<batchEnd])
      batchStart = batchEnd

      let batchSources = await withTaskGroup(of: (rank: Int, source: NativeWebSearchSource)?.self) { group in
        for result in batch {
          group.addTask { [weak self] in
            guard let self,
                  let pageText = try? await self.fetchPageText(from: result.url, query: query),
                  !pageText.isEmpty
            else {
              return nil
            }

            let snippet = result.snippet.isEmpty ? self.clipped(pageText, maxLength: 360) : result.snippet
            return (
              rank: result.rank,
              source: NativeWebSearchSource(
                title: result.title,
                snippet: snippet,
                url: result.url.absoluteString,
                pageText: self.clipped(pageText, maxLength: 2_000)
              )
            )
          }
        }

        var rankedSources: [(rank: Int, source: NativeWebSearchSource)] = []
        for await result in group {
          guard let result else {
            continue
          }
          rankedSources.append(result)
        }

        return rankedSources
          .sorted { $0.rank < $1.rank }
          .map(\.source)
      }

      sources.append(contentsOf: batchSources)
    }

    if sources.isEmpty {
      sources = results
        .filter { !$0.snippet.isEmpty }
        .prefix(min(plan.sourceLimit, 3))
        .map { result in
          NativeWebSearchSource(
            title: result.title,
            snippet: result.snippet,
            url: result.url.absoluteString,
            pageText: result.snippet
          )
        }
    }

    return Array(sources.prefix(plan.sourceLimit))
  }

  private func fetchString(from url: URL, accept: String = "text/html,application/xhtml+xml") async throws -> String {
    var request = URLRequest(url: url)
    request.setValue(accept, forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    try validate(response: response)
    return String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .isoLatin1)
      ?? ""
  }

  private func fetchPageText(from url: URL, query: String) async throws -> String {
    var request = URLRequest(url: url)
    request.setValue("text/html,application/xhtml+xml,text/plain", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    try validate(response: response)

    if let httpResponse = response as? HTTPURLResponse,
       let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
       !contentType.contains("text/html"),
       !contentType.contains("text/plain") {
      return ""
    }

    let limitedData = Data(data.prefix(900_000))
    let raw = String(data: limitedData, encoding: .utf8)
      ?? String(data: limitedData, encoding: .isoLatin1)
      ?? ""
    let text = cleanPageText(raw)
    return extractRelevantPageText(text, query: query)
  }

  private func validate(response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      return
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }
  }

  private func parseSearchResults(from html: String, queryIndex: Int) -> [SearchResult] {
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

  private func parseRSSResults(from xml: String, queryIndex: Int) -> [SearchResult] {
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

  private func rssField(_ name: String, in item: String) -> String {
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

  private func searchPlan(for query: String) -> SearchPlan {
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

  private func searchQueries(for query: String, plan: SearchPlan) -> [String] {
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

  private func cleanSearchQuery(_ query: String) -> String {
    query
      .replacingOccurrences(of: #"\B/search\b"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"(?i)\b(?:please|search|find|look up|tell me|show me)\b"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"(검색\s*(?:해\s*줘|해줘|해|해서\s*알려줘|해서\s*정리해줘)?)|(찾아\s*(?:봐|줘|서\s*알려줘)?)|(알려\s*줘)|(정리\s*해\s*줘)"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'.,:;?!")))
  }

  private func selectPageCandidates(from results: [SearchResult], query: String, plan: SearchPlan) -> [SearchResult] {
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

  private func relevanceScore(_ result: SearchResult, terms: [String]) -> Int {
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

  private func authoritativeHostScore(_ host: String) -> Int {
    if host.hasSuffix(".gov") || host.hasSuffix(".edu") {
      return 8
    }

    let signals = [
      "docs.", "developer.", "support.", "github.com", "arxiv.org", "nature.com",
      "science.org", "who.int", "oecd.org", "apple.com", "google", "microsoft.com"
    ]
    return signals.contains(where: { host.contains($0) }) ? 5 : 0
  }

  private func searchTerms(_ query: String) -> [String] {
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

  private func resolvedSearchURL(_ href: String) -> URL? {
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

  private func resultSnippet(in html: String, after utf16Location: Int) -> String {
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

  private func cleanHTML(_ html: String) -> String {
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

  private func cleanPageText(_ html: String) -> String {
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

  private func extractRelevantPageText(_ text: String, query: String) -> String {
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

  private func decodeHTMLEntities(_ text: String) -> String {
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

  private func clipped(_ text: String, maxLength: Int) -> String {
    let cleaned = text
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count > maxLength else {
      return cleaned
    }

    return "\(cleaned.prefix(maxLength))..."
  }

  private func normalizedURL(_ url: URL) -> String {
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

  private var searchStopWords: Set<String> {
    [
      "the", "and", "for", "with", "from", "about", "this", "that", "what", "when", "where",
      "검색", "정리", "알려", "최신", "최근", "현재", "오늘", "관련", "내용"
    ]
  }
}
