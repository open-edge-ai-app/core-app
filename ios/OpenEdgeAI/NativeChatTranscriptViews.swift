import SwiftUI

struct NativeChatTranscript: View {
  @EnvironmentObject private var store: NativeChatStore
  var topPadding: CGFloat = 18
  var bottomPadding: CGFloat = 24

  var body: some View {
    let messages = store.currentMessages

    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          if messages.isEmpty {
            NativeEmptyChatView()
              .padding(.top, 80)
          } else {
            ForEach(messages) { message in
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
      .onChange(of: store.sessionMutationRevision) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("bottom", anchor: .bottom)
        }
      }
    }
  }
}

enum NativeChatTranscriptFadeEdge {
  case top
  case bottom
}

struct NativeChatTranscriptEdgeFade: View {
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
