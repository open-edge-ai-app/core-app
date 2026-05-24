import Foundation
import SwiftUI
import UIKit

struct NativeMarkdownText: View {
  let text: String
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(markdownBlocks) { block in
        NativeMarkdownBlockView(block: block, sources: sources, onOpenSource: onOpenSource)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var markdownBlocks: [NativeMarkdownBlock] {
    NativeMarkdownParser.parse(text)
  }
}

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

  let id = UUID()
  let kind: Kind
}

enum NativeMarkdownParser {
  static func parse(_ markdown: String) -> [NativeMarkdownBlock] {
    let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")
    var blocks: [NativeMarkdownBlock] = []
    var paragraphLines: [String] = []
    var index = 0

    func flushParagraph() {
      guard !paragraphLines.isEmpty else {
        return
      }
      blocks.append(.init(kind: .paragraph(paragraphLines.joined(separator: "\n"))))
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
        blocks.append(.init(kind: .code(language: language, text: codeLines.joined(separator: "\n"))))
        continue
      }

      if let heading = heading(in: trimmed) {
        flushParagraph()
        blocks.append(.init(kind: .heading(level: heading.level, text: heading.text)))
        index += 1
        continue
      }

      if let table = table(startingAt: index, in: lines) {
        flushParagraph()
        blocks.append(.init(kind: .table(headers: table.headers, rows: table.rows)))
        index = table.nextIndex
        continue
      }

      if isDivider(trimmed) {
        flushParagraph()
        blocks.append(.init(kind: .divider))
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
        blocks.append(.init(kind: .unorderedList(items)))
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
        blocks.append(.init(kind: .orderedList(items)))
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
        blocks.append(.init(kind: .quote(quoteLines.joined(separator: "\n"))))
        continue
      }

      paragraphLines.append(line)
      index += 1
    }

    flushParagraph()
    return blocks.isEmpty ? [.init(kind: .paragraph(markdown))] : blocks
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

struct NativeMarkdownBlockView: View {
  @EnvironmentObject private var store: NativeChatStore
  let block: NativeMarkdownBlock
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  var body: some View {
    switch block.kind {
    case .paragraph(let text):
      NativeInlineMarkdownText(
        text: text,
        sources: sources,
        fontSize: store.fontSizeSetting.bodySize,
        fontWeight: .regular,
        textColor: .oeText,
        onOpenSource: onOpenSource
      )
        .fixedSize(horizontal: false, vertical: true)

    case .heading(let level, let text):
      NativeInlineMarkdownText(
        text: text,
        sources: sources,
        fontSize: headingFontSize(for: level),
        fontWeight: .semibold,
        textColor: .oeText,
        onOpenSource: onOpenSource
      )
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, level <= 2 ? 4 : 2)

    case .unorderedList(let items):
      VStack(alignment: .leading, spacing: 7) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          listRow(marker: "•", text: item)
        }
      }

    case .orderedList(let items):
      VStack(alignment: .leading, spacing: 7) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          listRow(marker: "\(index + 1).", text: item)
        }
      }

    case .quote(let text):
      HStack(alignment: .top, spacing: 10) {
        RoundedRectangle(cornerRadius: 1)
          .fill(Color.oeBorder)
          .frame(width: 3)

        NativeInlineMarkdownText(
          text: text,
          sources: sources,
          fontSize: store.fontSizeSetting.bodySize,
          fontWeight: .regular,
          textColor: .oeSecondaryText,
          onOpenSource: onOpenSource
        )
          .fixedSize(horizontal: false, vertical: true)
      }

    case .table(let headers, let rows):
      NativeMarkdownTableView(
        headers: headers,
        rows: rows,
        sources: sources,
        onOpenSource: onOpenSource
      )

    case .code(let language, let text):
      NativeMarkdownCodeBlock(language: language, code: text)

    case .divider:
      Divider()
        .padding(.vertical, 4)
    }
  }

  private func listRow(marker: String, text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 9) {
      Text(marker)
        .font(.system(size: store.fontSizeSetting.bodySize, weight: .semibold))
        .foregroundColor(.oeSecondaryText)
        .frame(width: 24, alignment: .trailing)

      NativeInlineMarkdownText(
        text: text,
        sources: sources,
        fontSize: store.fontSizeSetting.bodySize,
        fontWeight: .regular,
        textColor: .oeText,
        onOpenSource: onOpenSource
      )
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func headingFontSize(for level: Int) -> CGFloat {
    let base = store.fontSizeSetting.bodySize
    switch level {
    case 1:
      return base + 7
    case 2:
      return base + 5
    case 3:
      return base + 3
    default:
      return base + 1
    }
  }
}

private struct NativeMarkdownTableView: View {
  @EnvironmentObject private var store: NativeChatStore
  let headers: [String]
  let rows: [[String]]
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  private var columnWidth: CGFloat {
    max(116, min(168, store.fontSizeSetting.bodySize * 8.6))
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        NativeMarkdownTableRowView(
          cells: headers,
          isHeader: true,
          columnWidth: columnWidth,
          sources: sources,
          onOpenSource: onOpenSource
        )

        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          NativeMarkdownTableRowView(
            cells: row,
            isHeader: false,
            columnWidth: columnWidth,
            sources: sources,
            onOpenSource: onOpenSource
          )
          .background(index.isMultiple(of: 2) ? Color.clear : Color.oeSubtleFill.opacity(0.45))
        }
      }
      .nativeLiquidGlass(cornerRadius: 12)
      .nativeGlassStroke(cornerRadius: 12)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct NativeMarkdownTableRowView: View {
  @EnvironmentObject private var store: NativeChatStore
  let cells: [String]
  let isHeader: Bool
  let columnWidth: CGFloat
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
        NativeMarkdownTableCellView(
          text: cell,
          isHeader: isHeader,
          width: columnWidth,
          sources: sources,
          onOpenSource: onOpenSource
        )
        .overlay(alignment: .trailing) {
          if index < cells.count - 1 {
            Rectangle()
              .fill(Color.oeBorder)
              .frame(width: 1)
          }
        }
      }
    }
    .background(isHeader ? Color.oeSubtleFill : Color.oeElevatedSurface)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.oeBorder)
        .frame(height: 1)
    }
  }
}

private struct NativeMarkdownTableCellView: View {
  @EnvironmentObject private var store: NativeChatStore
  let text: String
  let isHeader: Bool
  let width: CGFloat
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  var body: some View {
    NativeInlineMarkdownText(
      text: text,
      sources: sources,
      fontSize: max(12, store.fontSizeSetting.bodySize - 1),
      fontWeight: isHeader ? .semibold : .regular,
      textColor: isHeader ? .oeText : .oeSecondaryText,
      onOpenSource: onOpenSource
    )
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, 10)
    .padding(.vertical, 9)
    .frame(width: width, alignment: .leading)
  }
}
