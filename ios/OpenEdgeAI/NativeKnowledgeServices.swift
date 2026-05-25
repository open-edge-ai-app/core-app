import Foundation


final class NativeLocalKnowledgeStore {
  static let shared = NativeLocalKnowledgeStore()

  private let storageKey = "OpenEdgeAI.NativeLocalKnowledge.v1"
  private let queue = DispatchQueue(label: "open-edge-ai.native-local-knowledge")
  private var records: [NativeKnowledgeRecord] = []

  private init() {
    load()
  }

  var count: Int {
    queue.sync { records.count }
  }

  func replaceGeneratedRecords(projects: [NativeProject], sessions: [NativeChatSession]) {
    queue.sync {
      let attachmentRecords = records.filter { $0.source == .attachment }
      let projectRecords = projects.compactMap { project -> NativeKnowledgeRecord? in
        let text = project.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
          return nil
        }
        return NativeKnowledgeRecord(
          id: "project:\(project.id)",
          source: .project,
          title: project.title,
          text: text,
          url: nil,
          updatedAt: project.createdAt
        )
      }

      let chatRecords = sessions
        .flatMap { session in
          session.messages.map { message in
            (session: session, message: message)
          }
        }
        .filter { item in
          !item.message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .sorted { $0.message.createdAt > $1.message.createdAt }
        .prefix(240)
        .map { item in
          NativeKnowledgeRecord(
            id: "chat:\(item.session.id):\(item.message.id)",
            source: .chat,
            title: item.session.title,
            text: item.message.text,
            url: nil,
            updatedAt: item.message.createdAt
          )
        }

      records = dedupe(attachmentRecords + projectRecords + chatRecords)
      saveLocked()
    }
  }

  func upsert(_ newRecords: [NativeKnowledgeRecord]) {
    guard !newRecords.isEmpty else {
      return
    }

    queue.sync {
      let normalizedRecords = newRecords.map(normalizedRecord)
      var next = records.filter { existing in
        !normalizedRecords.contains { $0.id == existing.id }
      }
      next.append(contentsOf: normalizedRecords)
      records = dedupe(next)
      saveLocked()
    }
  }

  func search(query: String, limit: Int = 5) -> [NativeKnowledgeMatch] {
    let terms = NativeLocalKnowledgeStore.searchTerms(query)
    guard !terms.isEmpty else {
      return []
    }

    return queue.sync {
      records
        .compactMap { record -> NativeKnowledgeMatch? in
          let searchable = "\(record.title) \(record.text)".lowercased()
          let score = terms.reduce(0) { partial, term in
            partial + (searchable.contains(term) ? 1 : 0)
          }
          guard score > 0 else {
            return nil
          }
          return NativeKnowledgeMatch(
            record: record,
            score: score,
            excerpt: NativeLocalKnowledgeStore.excerpt(from: record.text, terms: terms)
          )
        }
        .sorted {
          if $0.score != $1.score {
            return $0.score > $1.score
          }
          return $0.record.updatedAt > $1.record.updatedAt
        }
        .prefix(limit)
        .map { $0 }
    }
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([NativeKnowledgeRecord].self, from: data)
    else {
      records = []
      return
    }
    records = decoded
  }

  private func saveLocked() {
    guard let data = try? JSONEncoder().encode(records) else {
      return
    }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func dedupe(_ input: [NativeKnowledgeRecord]) -> [NativeKnowledgeRecord] {
    var seen = Set<String>()
    return input
      .sorted { $0.updatedAt > $1.updatedAt }
      .filter { seen.insert($0.id).inserted }
      .prefix(400)
      .map(normalizedRecord)
  }

  private func normalizedRecord(_ record: NativeKnowledgeRecord) -> NativeKnowledgeRecord {
    NativeKnowledgeRecord(
      id: record.id,
      source: record.source,
      title: NativePromptCompressor.clipped(record.title, maxEstimatedTokens: 80),
      text: NativePromptCompressor.clipped(record.text, maxEstimatedTokens: 1_600),
      url: record.url,
      updatedAt: record.updatedAt
    )
  }

  static func searchTerms(_ query: String) -> [String] {
    query
      .lowercased()
      .split { character in
        !character.isLetter && !character.isNumber
      }
      .map(String.init)
      .filter { $0.count >= 2 }
      .filter { !stopWords.contains($0) }
      .removingDuplicates()
      .prefix(16)
      .map { $0 }
  }

  private static func excerpt(from text: String, terms: [String]) -> String {
    let paragraphs = text
      .components(separatedBy: CharacterSet.newlines)
      .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    let ranked = paragraphs
      .map { paragraph -> (score: Int, text: String) in
        let lower = paragraph.lowercased()
        return (terms.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }, paragraph)
      }
      .filter { $0.score > 0 }
      .sorted { $0.score > $1.score }
      .map(\.text)

    let selected = ranked.first ?? paragraphs.first ?? text
    return NativePromptCompressor.clipped(selected, maxEstimatedTokens: 170)
  }

  private static let stopWords: Set<String> = [
    "the", "and", "for", "with", "from", "this", "that", "what", "when", "where",
    "how", "about", "검색", "정리", "알려", "내용", "관련", "있는", "없는", "에서", "으로",
    "그리고", "하지만", "그러면"
  ]
}
