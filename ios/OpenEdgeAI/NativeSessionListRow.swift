import SwiftUI

struct NativeSessionListRow: View {
  @EnvironmentObject private var store: NativeChatStore
  var title: String
  var isWriting = false

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
        .font(.system(size: 16, weight: .regular))
        .foregroundColor(.oeText)
        .lineLimit(1)

      Spacer(minLength: 10)

      if isWriting {
        ProgressView()
          .controlSize(.small)
          .tint(.oeMutedText)
          .frame(width: 18, height: 18)
          .accessibilityLabel(store.i18n.t(.chatGenerating))
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}
