import SwiftUI

struct NativeEmptyChatView: View {
  @EnvironmentObject private var store: NativeChatStore

  private var subtitles: [String] {
    [
      store.i18n.t(.chatSubtitlePrimary),
      store.i18n.t(.chatSubtitleSecondary)
    ]
  }

  private var suggestedPrompts: [String] {
    [
      store.i18n.t(.chatSuggestionPriority),
      store.i18n.t(.chatSuggestionDevelopIdea),
      store.i18n.t(.chatSuggestionSummarize),
      store.i18n.t(.chatSuggestionDebugCode)
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      VStack(alignment: .leading, spacing: 8) {
        Text(store.i18n.t(.chatGreeting))
          .font(.system(size: store.fontSizeSetting.bodySize + 5, weight: .semibold))
          .foregroundColor(.oeText)

        ForEach(subtitles, id: \.self) { subtitle in
          Text(subtitle)
            .font(.system(size: store.fontSizeSetting.bodySize - 1))
            .foregroundColor(.oeSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text(store.i18n.t(.chatSuggestionsTitle))
          .font(.system(size: store.fontSizeSetting.bodySize - 2, weight: .semibold))
          .foregroundColor(.oeSecondaryText)

        VStack(spacing: 8) {
          ForEach(suggestedPrompts, id: \.self) { prompt in
            Button {
              store.inputText = prompt
            } label: {
              HStack(spacing: 10) {
                Text(prompt)
                  .font(.system(size: store.fontSizeSetting.bodySize - 1, weight: .medium))
                  .foregroundColor(.oeText)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundColor(.oeSecondaryText)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .nativeLiquidGlass(cornerRadius: 12, interactive: true)
              .nativeGlassStroke(cornerRadius: 12, color: Color.oeBorder.opacity(0.28))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
