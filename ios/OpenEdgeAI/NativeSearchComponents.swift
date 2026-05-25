import SwiftUI

struct NativeSearchSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.oeSecondaryText)

      VStack(alignment: .leading, spacing: 12) {
        content
      }
    }
  }
}

struct NativeSearchSessionButton: View {
  var session: NativeChatSession
  var subtitle: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      NativeSearchRowContent(
        systemImage: "bubble.left.and.bubble.right",
        title: session.title,
        subtitle: subtitle,
        showsChevron: true
      )
    }
    .buttonStyle(.plain)
  }
}

struct NativeSearchResultRow: View {
  var result: NativeSearchResult
  var action: () -> Void

  var body: some View {
    switch result.kind {
    case .session:
      Button(action: action) {
        NativeSearchRowContent(
          systemImage: result.systemImage,
          title: result.title,
          subtitle: result.subtitle,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)
    case .project:
      Button(action: action) {
        NativeSearchRowContent(
          systemImage: result.systemImage,
          title: result.title,
          subtitle: result.subtitle,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)
    }
  }
}

struct NativeSearchRowContent: View {
  var systemImage: String
  var title: String
  var subtitle: String
  var showsChevron: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeText)
          .lineLimit(1)

        Text(subtitle)
          .font(.system(size: 13, weight: .regular))
          .foregroundColor(.oeMutedText)
          .lineLimit(2)
      }

      Spacer(minLength: 8)

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.oeText.opacity(0.25))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .nativeLiquidGlass(cornerRadius: 16, interactive: true)
    .nativeGlassStroke(cornerRadius: 16, color: Color.oeBorder.opacity(0.26))
    .contentShape(Rectangle())
  }
}

struct NativeSearchEmptyState: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.system(size: 15, weight: .medium))
      .foregroundColor(.oeMutedText)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.vertical, 24)
  }
}
