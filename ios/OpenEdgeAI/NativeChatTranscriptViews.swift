import SwiftUI

struct NativeChatTranscript: View {
  @EnvironmentObject private var store: NativeChatStore
  var topPadding: CGFloat = 18
  var bottomPadding: CGFloat = 24

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
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
      }
      .background(Color.oeBackground)
      .overlay(alignment: .top) {
        NativeChatTranscriptEdgeFade(edge: .top, height: 128)
          .ignoresSafeArea(edges: .top)
      }
      .overlay(alignment: .bottom) {
        NativeChatTranscriptEdgeFade(edge: .bottom, height: 178)
          .ignoresSafeArea(edges: .bottom)
      }
      .onChange(of: store.currentMessages) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("bottom", anchor: .bottom)
        }
      }
    }
  }
}

private enum NativeChatTranscriptFadeEdge {
  case top
  case bottom
}

private struct NativeChatTranscriptEdgeFade: View {
  let edge: NativeChatTranscriptFadeEdge
  let height: CGFloat

  var body: some View {
    LinearGradient(
      stops: gradientStops,
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: height)
    .allowsHitTesting(false)
  }

  private var gradientStops: [Gradient.Stop] {
    switch edge {
    case .top:
      return [
        .init(color: Color.oeBackground, location: 0),
        .init(color: Color.oeBackground.opacity(0.86), location: 0.28),
        .init(color: Color.oeBackground.opacity(0), location: 1)
      ]
    case .bottom:
      return [
        .init(color: Color.oeBackground.opacity(0), location: 0),
        .init(color: Color.oeBackground.opacity(0.86), location: 0.72),
        .init(color: Color.oeBackground, location: 1)
      ]
    }
  }
}
