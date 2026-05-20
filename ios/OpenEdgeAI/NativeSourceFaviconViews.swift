import SwiftUI

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
