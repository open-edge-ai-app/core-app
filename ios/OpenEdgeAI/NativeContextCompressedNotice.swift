import SwiftUI

struct NativeContextCompressedNotice: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "arrow.down.right.and.arrow.up.left")
        .font(.system(size: 10, weight: .bold))

      Text(store.i18n.t(.chatContextCompressed))
        .font(.system(size: 12, weight: .semibold))
    }
    .foregroundColor(store.accentColor.color)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(store.accentColor.color.opacity(0.08))
    .clipShape(Capsule())
    .accessibilityLabel(store.i18n.t(.chatContextCompressed))
  }
}
