import Foundation
import UIKit

extension NativeWebSearchClient {
  func fetchSearchResults(queries: [String], plan: SearchPlan) async -> [SearchResult] {
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

  func fetchSearchResults(query: String, queryIndex: Int) async -> [SearchResult] {
    do {
      return try await fetchDuckDuckGoResults(query: query, queryIndex: queryIndex)
    } catch {
      return (try? await fetchBingRSSResults(query: query, queryIndex: queryIndex)) ?? []
    }
  }

  func fetchDuckDuckGoResults(query: String, queryIndex: Int) async throws -> [SearchResult] {
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

  func directURLSearchResults(from query: String) -> [SearchResult] {
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

  func fetchBingRSSResults(query: String, queryIndex: Int) async throws -> [SearchResult] {
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

  func visitPages(query: String, results: [SearchResult], plan: SearchPlan) async -> [NativeWebSearchSource] {
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

  func fetchString(from url: URL, accept: String = "text/html,application/xhtml+xml") async throws -> String {
    var request = URLRequest(url: url)
    request.setValue(accept, forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    try validate(response: response)
    return String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .isoLatin1)
      ?? ""
  }

  func fetchPageText(from url: URL, query: String) async throws -> String {
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

  func validate(response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      return
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }
  }
}
