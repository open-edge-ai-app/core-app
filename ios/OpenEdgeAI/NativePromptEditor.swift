import SwiftUI
import UIKit

struct NativePromptEditor: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var text: String
  var placeholder: String
  var focused: FocusState<Bool>.Binding

  private var fontSize: CGFloat {
    store.fontSizeSetting.inputSize
  }

  private var lineHeight: CGFloat {
    UIFont.systemFont(ofSize: fontSize).lineHeight
  }

  private var visibleLineCount: Int {
    min(max(1, estimatedLineCount), 3)
  }

  private var editorHeight: CGFloat {
    max(36, CGFloat(visibleLineCount) * lineHeight + 8)
  }

  private var estimatedLineCount: Int {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard !lines.isEmpty else {
      return 1
    }

    return lines.reduce(0) { count, line in
      count + max(1, Int(ceil(Double(line.count) / 24.0)))
    }
  }

  var body: some View {
    ZStack(alignment: .leading) {
      TextEditor(text: $text)
        .font(.system(size: fontSize))
        .foregroundColor(.oeText)
        .tint(store.accentColor.color)
        .focused(focused)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .frame(height: editorHeight)
        .fixedSize(horizontal: false, vertical: false)
        .accessibilityIdentifier("chatPromptInput")
        .accessibilityLabel(Text(placeholder))

      if text.isEmpty {
        Text(placeholder)
          .font(.system(size: fontSize))
          .foregroundColor(.oeSecondaryText.opacity(0.72))
          .lineLimit(1)
          .frame(height: editorHeight, alignment: .center)
          .padding(.leading, 5)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .frame(minHeight: 36)
    .contentShape(Rectangle())
    .onTapGesture {
      focused.wrappedValue = true
    }
  }
}
