final class NativeWebSearchClient {
  static let shared = NativeWebSearchClient()

  let defaultSourceLimit = 4
  let expandedSourceLimit = 6
  let deepSourceLimit = 8
  let maxSearchResultCandidates = 14
  let defaultCandidateLimit = 6
  let expandedCandidateLimit = 9
  let deepCandidateLimit = 12
  let pageFetchBatchSize = 3
  let session: URLSession

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

  struct SearchResult {
    let rank: Int
    let queryIndex: Int
    let title: String
    let snippet: String
    let url: URL
  }

  struct SearchPlan {
    let queryLimit: Int
    let sourceLimit: Int
    let candidateLimit: Int
  }
}
