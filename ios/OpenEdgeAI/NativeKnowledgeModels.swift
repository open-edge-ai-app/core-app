import Foundation

extension Array where Element: Hashable {
  func removingDuplicates() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

enum NativeKnowledgeSource: String, Codable {
  case project
  case chat
  case attachment
}

struct NativeKnowledgeRecord: Identifiable, Codable, Equatable {
  var id: String
  var source: NativeKnowledgeSource
  var title: String
  var text: String
  var url: String?
  var updatedAt: Date
}

struct NativeKnowledgeMatch {
  var record: NativeKnowledgeRecord
  var score: Int
  var excerpt: String
}
