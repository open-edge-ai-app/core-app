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