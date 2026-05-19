import SwiftUI

import SwiftUI

struct NativeAttachmentRow: View {
  @EnvironmentObject private var store: NativeChatStore
  let attachments: [NativeAttachment]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(attachments) { attachment in
        HStack(spacing: 8) {
          Image(systemName: icon(for: attachment.type))
          Text(attachment.name)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
        }
        .foregroundColor(store.accentColor.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(store.accentColor.subtleColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
    }
  }

  private func icon(for type: String) -> String {
    switch type {
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
