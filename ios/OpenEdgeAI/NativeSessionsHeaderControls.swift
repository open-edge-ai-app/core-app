import SwiftUI

struct NativeSessionsSearchPill: View {
  @EnvironmentObject private var store: NativeChatStore
  var onSearchPress: () -> Void
  var onSettingsPress: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: onSearchPress) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 21, weight: .semibold))
          .foregroundColor(.oeText)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.i18n.t(.searchTitle))

      Button(action: onSettingsPress) {
        Image(systemName: "gearshape")
          .font(.system(size: 19, weight: .semibold))
          .foregroundColor(.oeText)
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.i18n.t(.commonOpenSettings))
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .frame(height: 52)
    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    .overlay(
      Capsule(style: .continuous)
        .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
    )
  }
}

struct NativeSessionsSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.oeText)

      VStack(alignment: .leading, spacing: 20) {
        content
      }
    }
  }
}
