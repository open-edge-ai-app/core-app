import Foundation

struct NativeMarkdownBlock: Identifiable {
  enum Kind {
    case paragraph(String)
    case heading(level: Int, text: String)
    case unorderedList([String])
    case orderedList([String])
    case quote(String)
    case table(headers: [String], rows: [[String]])
    case code(language: String?, text: String)
    case divider
  }

  let id: Int
  let kind: Kind
}
