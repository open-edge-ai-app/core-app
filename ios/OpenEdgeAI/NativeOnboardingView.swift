import SwiftUI

struct NativeOnboardingView: View {
  @EnvironmentObject private var store: NativeChatStore
  @State private var selectedPage = 0
  var onStart: () -> Void

  private var pages: [NativeOnboardingPage] {
    [
      NativeOnboardingPage(
        title: .onboardingChatTitle,
        subtitle: .onboardingChatSubtitle,
        artworkName: "onboarding-chat"
      ),
      NativeOnboardingPage(
        title: .onboardingTodoTitle,
        subtitle: .onboardingTodoSubtitle,
        artworkName: "onboarding-todo"
      ),
      NativeOnboardingPage(
        title: .onboardingProjectTitle,
        subtitle: .onboardingProjectSubtitle,
        artworkName: "onboarding-project"
      ),
      NativeOnboardingPage(
        title: .onboardingIslandTitle,
        subtitle: .onboardingIslandSubtitle,
        artworkName: "onboarding-island"
      )
    ]
  }

  private var isLastPage: Bool {
    selectedPage == pages.count - 1
  }

  var body: some View {
    let i18n = store.i18n

    GeometryReader { proxy in
      ZStack {
        NativeOnboardingBackground(accentColor: store.accentColor)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          Spacer()
            .frame(height: proxy.safeAreaInsets.top + 14)

          TabView(selection: $selectedPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
              NativeOnboardingPageView(
                page: page,
                i18n: i18n,
                accentColor: store.accentColor,
                availableHeight: proxy.size.height
              )
              .frame(width: proxy.size.width)
              .clipped()
              .tag(index)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .frame(width: proxy.size.width)
          .clipped()

          NativeOnboardingControls(
            count: pages.count,
            selectedPage: selectedPage,
            isLastPage: isLastPage,
            i18n: i18n,
            accentColor: store.accentColor
          ) {
            if isLastPage {
              onStart()
            } else {
              withAnimation(.easeInOut(duration: 0.22)) {
                selectedPage = min(selectedPage + 1, pages.count - 1)
              }
            }
          }
          .padding(.bottom, proxy.safeAreaInsets.bottom + 12)
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
      }
    }
  }
}

private struct NativeOnboardingPage {
  var title: NativeI18nKey
  var subtitle: NativeI18nKey
  var artworkName: String
}

private struct NativeOnboardingPageView: View {
  var page: NativeOnboardingPage
  var i18n: NativeI18n
  var accentColor: NativeAccentColor
  var availableHeight: CGFloat

  private var artworkHeight: CGFloat {
    min(360, max(286, availableHeight * 0.43))
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer(minLength: 4)

      NativeOnboardingArtwork(name: page.artworkName, accentColor: accentColor)
        .frame(height: artworkHeight)
        .padding(.horizontal, 14)

      VStack(spacing: 12) {
        Text(i18n.t(page.title))
          .font(.system(size: 29, weight: .bold))
          .multilineTextAlignment(.center)
          .foregroundColor(.oeText)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        Text(i18n.t(page.subtitle))
          .font(.system(size: 15, weight: .medium))
          .multilineTextAlignment(.center)
          .foregroundColor(.oeSecondaryText)
          .lineSpacing(3)
          .lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 32)

      Spacer(minLength: 2)
    }
  }
}

private struct NativeOnboardingArtwork: View {
  var name: String
  var accentColor: NativeAccentColor

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        NativeAnimatedGIFView(name: name)
          .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
          .nativeGlassStroke(cornerRadius: 30, color: Color.oeBorder.opacity(0.12))

        NativeOnboardingFallbackArtwork(accentColor: accentColor)
          .opacity(NativeAnimatedGIFCache.image(named: name) == nil ? 1 : 0)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

private struct NativeOnboardingFallbackArtwork: View {
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "sparkles")
        .font(.system(size: 40, weight: .semibold))
        .foregroundColor(accentColor.color)

      Text("Open Edge AI")
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.oeText)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct NativeOnboardingControls: View {
  var count: Int
  var selectedPage: Int
  var isLastPage: Bool
  var i18n: NativeI18n
  var accentColor: NativeAccentColor
  var action: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      NativeOnboardingPageDots(count: count, selectedPage: selectedPage)

      Button(action: action) {
        Text(i18n.t(isLastPage ? .onboardingStart : .onboardingNext))
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(accentColor.foregroundColor)
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(accentColor.color, in: Capsule(style: .continuous))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 24)

      Text(i18n.t(.onboardingLegal))
        .font(.system(size: 11, weight: .medium))
        .multilineTextAlignment(.center)
        .foregroundColor(isLastPage ? .oeMutedText : .clear)
        .frame(minHeight: 34)
        .padding(.horizontal, 34)
    }
  }
}

private struct NativeOnboardingPageDots: View {
  var count: Int
  var selectedPage: Int

  var body: some View {
    HStack(spacing: 7) {
      ForEach(0..<count, id: \.self) { index in
        Capsule(style: .continuous)
          .fill(index == selectedPage ? Color.oeText : Color.oeMutedText.opacity(0.28))
          .frame(width: index == selectedPage ? 22 : 7, height: 7)
      }
    }
    .animation(.easeInOut(duration: 0.22), value: selectedPage)
  }
}

private struct NativeOnboardingBackground: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      Color.oeBackground

      LinearGradient(
        colors: [
          accentColor.color.opacity(0.09),
          Color.oeGroupedBackground.opacity(0.86),
          Color.oeBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}
