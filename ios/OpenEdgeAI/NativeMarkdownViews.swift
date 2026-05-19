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
