import SwiftUI

struct NativeAttachmentOptionsMenu: View {
  @EnvironmentObject private var store: NativeChatStore
  var onPickPhotoOrVideo: () -> Void
  var onPickFile: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      menuButton(
        title: store.i18n.t(.attachmentPhotoOrVideo),
        systemImage: "photo.on.rectangle",
        action: onPickPhotoOrVideo
      )

      Divider()
        .overlay(Color.oeBorder.opacity(0.18))
        .padding(.leading, 42)

      menuButton(
        title: store.i18n.t(.attachmentFile),
        systemImage: "doc",
        action: onPickFile
      )
    }
    .padding(.vertical, 6)
    .frame(width: 190, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.white.opacity(0.12))
        .allowsHitTesting(false)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.oeBorder.opacity(0.24), lineWidth: 1)
        .allowsHitTesting(false)
    }
    .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 8)
  }

  private func menuButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 18)

        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(1)
      }
      .foregroundColor(.oeText)
      .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
      .padding(.horizontal, 14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct NativeComposerSubmitIcon: View {
  @EnvironmentObject private var store: NativeChatStore
  var systemName: String
  var isActive: Bool

  var body: some View {
    NativeComposerCircleSurface(
      isActive: isActive,
      accentColor: store.accentColor.color
    ) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(isActive ? store.accentColor.foregroundColor : .oeText)
        .frame(width: nativeComposerSubmitControlSize, height: nativeComposerSubmitControlSize)
    }
  }
}

struct NativePendingAttachmentStrip: View {
  @EnvironmentObject private var store: NativeChatStore
  var showsSearchMode: Bool = false

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        if showsSearchMode {
          NativeSearchModeChip()
            .environmentObject(store)
        }

        ForEach(store.pendingAttachments) { attachment in
          NativePendingAttachmentChip(attachment: attachment) {
            store.removePendingAttachment(attachment)
          }
        }
      }
      .padding(.horizontal, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct NativePendingAttachmentChip: View {
  var attachment: NativeAttachment
  var onRemove: () -> Void

  var body: some View {
    NativeComposerChipSurface {
      HStack(spacing: 6) {
        Image(systemName: iconName)
          .font(.system(size: 11, weight: .semibold))

        Text(verbatim: attachment.compactDisplayName)
          .lineLimit(1)

        Button(action: onRemove) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
      }
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(Color.oeText)
      .padding(.leading, 9)
      .padding(.trailing, 6)
      .frame(height: 29)
    }
    .accessibilityLabel(Text(verbatim: attachment.name))
  }

  private var iconName: String {
    switch attachment.type {
    case "image":
      return "photo"
    case "audio":
      return "waveform"
    case "video":
      return "film"
    default:
      return "doc"
    }
  }
}
