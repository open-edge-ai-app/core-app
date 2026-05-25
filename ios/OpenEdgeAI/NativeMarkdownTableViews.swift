import SwiftUI

struct NativeMarkdownTableView: View {
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
