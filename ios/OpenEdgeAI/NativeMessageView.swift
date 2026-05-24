import SwiftUI

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
          .nativeLiquidGlass(
            cornerRadius: 18,
            tint: store.accentColor.color.opacity(0.52)
          )
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
        .padding(.horizontal, 10)
        .frame(height: 34)
        .nativeLiquidGlassCapsule()
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
