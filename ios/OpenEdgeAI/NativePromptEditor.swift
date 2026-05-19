import SwiftUI

struct NativePromptEditor: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var text: String
  var placeholder: String
  var focused: FocusState<Bool>.Binding

  private var visibleLineCount: Int {
    min(max(1, text.components(separatedBy: .newlines).count), 3)
  }

  private var editorHeight: CGFloat {
    let lineHeight = max(20, store.fontSizeSetting.inputSize + 5)
    return CGFloat(visibleLineCount) * lineHeight + 16
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .font(.system(size: store.fontSizeSetting.inputSize))
        .foregroundColor(.oeText)
        .tint(store.accentColor.color)
        .focused(focused)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(height: editorHeight)
        .fixedSize(horizontal: false, vertical: false)

      if text.isEmpty {
        Text(placeholder)
          .font(.system(size: store.fontSizeSetting.inputSize))
          .foregroundColor(.oeText.opacity(0.35))
          .padding(.top, 8)
          .padding(.leading, 5)
          .allowsHitTesting(false)
      }
    }
  }
}
