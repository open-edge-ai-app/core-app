import SwiftUI

struct NativeChatTranscript: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          if store.currentMessages.isEmpty {
            NativeEmptyChatView()
              .padding(.top, 80)
          } else {
            ForEach(store.currentMessages) { message in
              NativeMessageView(message: message)
                .id(message.id)
            }
          }

          Color.clear
            .frame(height: 1)
            .id("bottom")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 24)
      }
      .background(Color.oeBackground)
      .onChange(of: store.currentMessages) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("bottom", anchor: .bottom)
        }
      }
    }
  }
}

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
              .background(Color.oeSubtleFill)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct NativeMessageView: View {
  @EnvironmentObject private var store: NativeChatStore
  @State private var showingSources = false
  let message: NativeMessage

  var body: some View {
    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
      if !message.attachments.isEmpty {
        NativeAttachmentRow(attachments: message.attachments)
      }

      if message.role == .user {
        Text(message.text.isEmpty ? store.i18n.t(.chatAttachmentFallback) : message.text)
          .font(.system(size: store.fontSizeSetting.bodySize))
          .foregroundColor(store.accentColor.foregroundColor)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(store.accentColor.color)
          .clipShape(RoundedRectangle(cornerRadius: 18))
          .frame(maxWidth: .infinity, alignment: .trailing)
          .textSelection(.enabled)
      } else {
        if message.contextCompressed {
          NativeContextCompressedNotice()
        }

        NativeMarkdownText(
          text: message.text.isEmpty ? store.i18n.t(.chatResponsePreparing) : message.text,
          sources: message.sourceReferences,
          onOpenSource: { _ in
            showingSources = true
          }
        )
          .font(.system(size: store.fontSizeSetting.bodySize))
          .foregroundColor(.oeText)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 16) {
          Button {
            store.copy(message.text)
          } label: {
            Image(systemName: "doc.on.doc")
          }

          Button {
            store.retry(message: message)
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(store.isGenerating)

          if !message.sourceReferences.isEmpty {
            Button {
              showingSources = true
            } label: {
              NativeMessageSourcesButton(sources: message.sourceReferences)
            }
            .accessibilityLabel(store.i18n.t(.chatSourcesCount, ["count": String(message.sourceReferences.count)]))
          }

          Text(message.createdAt.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 12))
            .foregroundColor(.oeMutedText)
        }
        .buttonStyle(.plain)
        .foregroundColor(store.accentColor.color)
        .font(.system(size: 14, weight: .medium))
      }
    }
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    .sheet(isPresented: $showingSources) {
      NativeMessageSourcesSheet(sources: message.sourceReferences)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }
}

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

struct NativeMessageSourcesButton: View {
  @EnvironmentObject private var store: NativeChatStore
  let sources: [NativeSearchSourceReference]

  var body: some View {
    HStack(spacing: 6) {
      NativeSourceFaviconStack(sources: sources)
      Text(store.i18n.t(.chatSources))
        .font(.system(size: 13, weight: .semibold))
    }
    .foregroundColor(store.accentColor.color)
  }
}

struct NativeSourceFaviconStack: View {
  let sources: [NativeSearchSourceReference]

  private var visibleSources: [NativeSearchSourceReference] {
    Array(sources.prefix(3))
  }

  private var width: CGFloat {
    guard !visibleSources.isEmpty else {
      return 0
    }
    return CGFloat(visibleSources.count - 1) * 11 + 18
  }

  var body: some View {
    ZStack(alignment: .leading) {
      ForEach(Array(visibleSources.enumerated()), id: \.element.id) { index, source in
        NativeSourceFavicon(source: source, size: 18)
          .offset(x: CGFloat(index) * 11)
          .zIndex(Double(visibleSources.count - index))
      }
    }
    .frame(width: width, height: 18, alignment: .leading)
  }
}

struct NativeSourceFavicon: View {
  let source: NativeSearchSourceReference
  let size: CGFloat

  var body: some View {
    AsyncImage(url: source.faviconURL) { phase in
      if let image = phase.image {
        image
          .resizable()
          .scaledToFit()
      } else {
        fallback
      }
    }
    .frame(width: size, height: size)
    .background(Color.oeBackground)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(Color.oeBackground, lineWidth: 1.5)
    )
  }

  private var fallback: some View {
    Circle()
      .fill(Color.oeSubtleFill)
      .overlay(
        Text(String(source.host.prefix(1)).uppercased())
          .font(.system(size: max(8, size * 0.44), weight: .bold))
          .foregroundColor(.oeSecondaryText)
      )
  }
}

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
