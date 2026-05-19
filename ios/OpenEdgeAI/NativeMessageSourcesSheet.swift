import SwiftUI

struct NativeMessageSourcesSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  let sources: [NativeSearchSourceReference]

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
            NativeMessageSourceRow(index: index + 1, source: source)
          }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 28)
      }
      .background(Color.oeGroupedBackground)
      .navigationTitle(store.i18n.t(.chatSources))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(store.i18n.t(.commonClose))
        }
      }
    }
  }
}

struct NativeMessageSourceRow: View {
  @EnvironmentObject private var store: NativeChatStore
  let index: Int
  let source: NativeSearchSourceReference

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      NativeSourceFavicon(source: source, size: 24)

      VStack(alignment: .leading, spacing: 3) {
        Text("[\(index)] \(source.host)")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(store.accentColor.color)
          .lineLimit(1)

        Text(source.title.isEmpty ? source.host : source.title)
          .font(.system(size: max(12, store.fontSizeSetting.bodySize - 3), weight: .semibold))
          .foregroundColor(.oeText)
          .lineLimit(2)

        if !source.snippet.isEmpty {
          Text(source.snippet)
            .font(.system(size: 11))
            .foregroundColor(.oeSecondaryText)
            .lineLimit(2)
        }

        Text(source.url)
          .font(.system(size: 11))
          .foregroundColor(.oeMutedText)
          .lineLimit(1)
      }

      Spacer(minLength: 6)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 10)
    .background(Color.oeBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
