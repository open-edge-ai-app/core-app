import Foundation

enum NativeMarkdownParser {
  static func parse(_ markdown: String) -> [NativeMarkdownBlock] {
    let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")
    var blocks: [NativeMarkdownBlock] = []
    var paragraphLines: [String] = []
    var index = 0
    var blockId = 0

    func appendBlock(_ kind: NativeMarkdownBlock.Kind) {
      blocks.append(.init(id: blockId, kind: kind))
      blockId += 1
    }

    func flushParagraph() {
      guard !paragraphLines.isEmpty else {
        return
      }
      appendBlock(.paragraph(paragraphLines.joined(separator: "\n")))
      paragraphLines.removeAll()
    }

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.isEmpty {
        flushParagraph()
        index += 1
        continue
      }

      if let fence = codeFence(in: trimmed) {
        flushParagraph()
        let language = fence.language
        var codeLines: [String] = []
        index += 1
        while index < lines.count {
          let candidate = lines[index].trimmingCharacters(in: .whitespaces)
          if candidate.hasPrefix(fence.marker) {
            index += 1
            break
          }
          codeLines.append(lines[index])
          index += 1
        }
        appendBlock(.code(language: language, text: codeLines.joined(separator: "\n")))
        continue
      }

      if let heading = heading(in: trimmed) {
        flushParagraph()
        appendBlock(.heading(level: heading.level, text: heading.text))
        index += 1
        continue
      }

      if let table = table(startingAt: index, in: lines) {
        flushParagraph()
        appendBlock(.table(headers: table.headers, rows: table.rows))
        index = table.nextIndex
        continue
      }

      if isDivider(trimmed) {
        flushParagraph()
        appendBlock(.divider)
        index += 1
        continue
      }

      if let firstItem = unorderedListItem(in: line) {
        flushParagraph()
        var items = [firstItem]
        index += 1
        while index < lines.count, let item = unorderedListItem(in: lines[index]) {
          items.append(item)
          index += 1
        }
        appendBlock(.unorderedList(items))
        continue
      }

      if let firstItem = orderedListItem(in: line) {
        flushParagraph()
        var items = [firstItem]
        index += 1
        while index < lines.count, let item = orderedListItem(in: lines[index]) {
          items.append(item)
          index += 1
        }
        appendBlock(.orderedList(items))
        continue
      }

      if let firstQuote = quoteLine(in: line) {
        flushParagraph()
        var quoteLines = [firstQuote]
        index += 1
        while index < lines.count, let quote = quoteLine(in: lines[index]) {
          quoteLines.append(quote)
          index += 1
        }
        appendBlock(.quote(quoteLines.joined(separator: "\n")))
        continue
      }

      paragraphLines.append(line)
      index += 1
    }

    flushParagraph()
    if blocks.isEmpty {
      appendBlock(.paragraph(markdown))
    }
    return blocks
  }

  private static func codeFence(in line: String) -> (marker: String, language: String?)? {
    let marker: String
    if line.hasPrefix("```") {
      marker = "```"
    } else if line.hasPrefix("~~~") {
      marker = "~~~"
    } else {
      return nil
    }

    let language = line
      .dropFirst(marker.count)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return (marker, language.isEmpty ? nil : language)
  }

  private static func heading(in line: String) -> (level: Int, text: String)? {
    let level = line.prefix { $0 == "#" }.count
    guard (1...6).contains(level),
          line.dropFirst(level).first?.isWhitespace == true
    else {
      return nil
    }

    let text = line.dropFirst(level)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : (level, text)
  }

  private static func isDivider(_ line: String) -> Bool {
    let compact = line.replacingOccurrences(of: " ", with: "")
    return compact.count >= 3 && Set(compact).isSubset(of: ["-"])
      || compact.count >= 3 && Set(compact).isSubset(of: ["*"])
      || compact.count >= 3 && Set(compact).isSubset(of: ["_"])
  }

  private static func unorderedListItem(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    for marker in ["- ", "* ", "+ ", "• "] {
      if trimmed.hasPrefix(marker) {
        let item = trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        return item.isEmpty ? nil : item
      }
    }
    return nil
  }

  private static func orderedListItem(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var digitCount = 0
    for character in trimmed {
      if character.wholeNumberValue == nil {
        break
      }
      digitCount += 1
    }

    guard digitCount > 0 else {
      return nil
    }

    let markerStart = trimmed.dropFirst(digitCount)
    guard markerStart.hasPrefix(". ") || markerStart.hasPrefix(") ") else {
      return nil
    }

    let item = markerStart.dropFirst(2).trimmingCharacters(in: .whitespaces)
    return item.isEmpty ? nil : item
  }

  private static func quoteLine(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix(">") else {
      return nil
    }

    return trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
  }

  private static func table(
    startingAt index: Int,
    in lines: [String]
  ) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
    guard index + 1 < lines.count else {
      return nil
    }

    let headerCells = tableCells(in: lines[index])
    let separatorCells = tableCells(in: lines[index + 1])
    guard headerCells.count >= 2,
          separatorCells.count == headerCells.count,
          separatorCells.allSatisfy(isTableSeparatorCell)
    else {
      return nil
    }

    var rows: [[String]] = []
    var cursor = index + 2
    while cursor < lines.count {
      let cells = tableCells(in: lines[cursor])
      guard cells.count >= 2 else {
        break
      }
      rows.append(normalizedTableRow(cells, columnCount: headerCells.count))
      cursor += 1
    }

    return (
      headers: normalizedTableRow(headerCells, columnCount: headerCells.count),
      rows: rows,
      nextIndex: cursor
    )
  }

  private static func tableCells(in line: String) -> [String] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.contains("|") else {
      return []
    }

    var content = trimmed
    if content.hasPrefix("|") {
      content.removeFirst()
    }
    if content.hasSuffix("|") {
      content.removeLast()
    }

    var cells: [String] = []
    var cell = ""
    var isEscaped = false

    for character in content {
      if isEscaped {
        cell.append(character)
        isEscaped = false
        continue
      }

      if character == "\\" {
        isEscaped = true
        continue
      }

      if character == "|" {
        cells.append(cell.trimmingCharacters(in: .whitespaces))
        cell.removeAll()
      } else {
        cell.append(character)
      }
    }

    cells.append(cell.trimmingCharacters(in: .whitespaces))
    return cells
  }

  private static func isTableSeparatorCell(_ cell: String) -> Bool {
    let trimmed = cell.trimmingCharacters(in: .whitespaces)
    guard trimmed.contains("-") else {
      return false
    }

    let stripped = trimmed.replacingOccurrences(of: ":", with: "")
    guard stripped.count >= 3 else {
      return false
    }
    return stripped.allSatisfy { $0 == "-" }
  }

  private static func normalizedTableRow(_ cells: [String], columnCount: Int) -> [String] {
    var normalized = Array(cells.prefix(columnCount))
    if normalized.count < columnCount {
      normalized.append(contentsOf: Array(repeating: "", count: columnCount - normalized.count))
    }
    return normalized
  }
}
