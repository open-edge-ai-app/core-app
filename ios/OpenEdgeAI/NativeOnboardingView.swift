import SwiftUI

struct NativeOnboardingView: View {
  @EnvironmentObject private var store: NativeChatStore
  @State private var selectedPage = 0
  var onStart: () -> Void

  private var pages: [NativeOnboardingPage] {
    [
      NativeOnboardingPage(title: .onboardingChatTitle, subtitle: .onboardingChatSubtitle, scene: .chat),
      NativeOnboardingPage(title: .onboardingTodoTitle, subtitle: .onboardingTodoSubtitle, scene: .todo),
      NativeOnboardingPage(title: .onboardingProjectTitle, subtitle: .onboardingProjectSubtitle, scene: .project),
      NativeOnboardingPage(title: .onboardingIslandTitle, subtitle: .onboardingIslandSubtitle, scene: .island)
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
          NativeOnboardingHeader(eyebrow: i18n.t(.onboardingBrandEyebrow))
            .padding(.top, proxy.safeAreaInsets.top + 12)
            .padding(.horizontal, 24)

          TabView(selection: $selectedPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
              NativeOnboardingPageView(
                page: page,
                i18n: i18n,
                accentColor: store.accentColor
              )
              .frame(width: proxy.size.width)
              .clipped()
              .tag(index)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .frame(width: proxy.size.width)
          .clipped()

          VStack(spacing: 16) {
            NativeOnboardingPageDots(count: pages.count, selectedPage: selectedPage)

            Button {
              if isLastPage {
                onStart()
              } else {
                withAnimation(.easeInOut(duration: 0.22)) {
                  selectedPage = min(selectedPage + 1, pages.count - 1)
                }
              }
            } label: {
              Text(i18n.t(isLastPage ? .onboardingStart : .onboardingNext))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(store.accentColor.foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(store.accentColor.color, in: Capsule(style: .continuous))
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
  var scene: NativeOnboardingScene
}

private enum NativeOnboardingScene {
  case chat
  case todo
  case project
  case island
}

private struct NativeOnboardingHeader: View {
  var eyebrow: String

  var body: some View {
    HStack {
      Image("OpenEdgeLogo")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundStyle(Color.oeText)
        .frame(width: 138, height: 34)
        .accessibilityLabel("Open Edge AI")

      Spacer()

      Text(eyebrow)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.oeSecondaryText)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .nativeLiquidGlassCapsule()
    }
  }
}

private struct NativeOnboardingPageView: View {
  var page: NativeOnboardingPage
  var i18n: NativeI18n
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(spacing: 28) {
      Spacer(minLength: 10)

      NativeOnboardingIllustration(scene: page.scene, accentColor: accentColor)
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .padding(.horizontal, 20)

      VStack(spacing: 12) {
        Text(i18n.t(page.title))
          .font(.system(size: 30, weight: .bold))
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
      .padding(.horizontal, 30)

      Spacer(minLength: 6)
    }
  }
}

private struct NativeOnboardingIllustration: View {
  var scene: NativeOnboardingScene
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(Color.oeSurface.opacity(0.78))
        .nativeLiquidGlass(cornerRadius: 34)
        .nativeGlassStroke(cornerRadius: 34, color: Color.oeBorder.opacity(0.2))

      switch scene {
      case .chat:
        NativeOnboardingChatScene(accentColor: accentColor)
      case .todo:
        NativeOnboardingTodoScene(accentColor: accentColor)
      case .project:
        NativeOnboardingProjectScene(accentColor: accentColor)
      case .island:
        NativeOnboardingIslandScene(accentColor: accentColor)
      }
    }
    .padding(.horizontal, 2)
  }
}

private struct NativeOnboardingChatScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 14) {
        NativeOnboardingMiniBar(title: "Open Edge AI", accentColor: accentColor)

        NativeOnboardingChatBubble(text: "오늘 회의 내용 정리해줘", isUser: true, accentColor: accentColor)
          .padding(.leading, 70)

        NativeOnboardingChatBubble(text: "핵심 결정, Todo, 다음 질문까지 정리했어요.", isUser: false, accentColor: accentColor)
          .padding(.trailing, 50)

        HStack(spacing: 8) {
          NativeOnboardingChip(text: "요약")
          NativeOnboardingChip(text: "다음 작업")
          NativeOnboardingChip(text: "검색")
        }
      }
      .padding(24)

      NativeDynamicIslandPetView(pet: .orbit, motion: .running, size: 78)
        .frame(width: 92, height: 86)
        .offset(x: -104, y: 106)
    }
  }
}

private struct NativeOnboardingTodoScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 12) {
        NativeOnboardingMiniBar(title: "Today", accentColor: accentColor)

        NativeOnboardingTodoCard(title: "부사장님 미팅", time: "16:00 - 17:00", isDone: false, accentColor: accentColor)
        NativeOnboardingTodoCard(title: "자료 요약 보내기", time: "18:30", isDone: true, accentColor: accentColor)
        NativeOnboardingTodoCard(title: "내일 일정 정리", time: "매일", isDone: false, accentColor: accentColor)
      }
      .padding(24)

      NativeDynamicIslandPetView(pet: .stacky, motion: .running, size: 76)
        .frame(width: 90, height: 84)
        .offset(x: 106, y: 106)
    }
  }
}

private struct NativeOnboardingProjectScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 13) {
        NativeOnboardingMiniBar(title: "Project", accentColor: accentColor)

        HStack(spacing: 10) {
          NativeOnboardingProjectTile(icon: "doc.text", title: "기획")
          NativeOnboardingProjectTile(icon: "sparkles", title: "메모리")
        }

        VStack(alignment: .leading, spacing: 9) {
          NativeOnboardingContextRow(width: 210, accentColor: accentColor)
          NativeOnboardingContextRow(width: 166, accentColor: accentColor)
          NativeOnboardingContextRow(width: 238, accentColor: accentColor)
        }
        .padding(16)
        .background(Color.oeBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
      }
      .padding(24)

      NativeDynamicIslandPetView(pet: .nullSignal, motion: .resting, size: 70)
        .frame(width: 84, height: 80)
        .offset(x: -104, y: 104)

      NativeDynamicIslandPetView(pet: .luma, motion: .running, size: 68)
        .frame(width: 82, height: 78)
        .offset(x: 116, y: -112)
    }
  }
}

private struct NativeOnboardingIslandScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      VStack(spacing: 18) {
        Capsule(style: .continuous)
          .fill(Color.oeText)
          .frame(width: 128, height: 38)
          .overlay(alignment: .leading) {
            NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 32)
              .frame(width: 38, height: 34)
              .padding(.leading, 10)
          }
          .overlay(alignment: .trailing) {
            NativeOnboardingSpinner(accentColor: accentColor)
              .frame(width: 26, height: 26)
              .padding(.trailing, 11)
          }

        VStack(alignment: .leading, spacing: 12) {
          HStack {
            NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 52)
              .frame(width: 62, height: 58)

            VStack(alignment: .leading, spacing: 6) {
              Text("응답 생성 중")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.oeText)
              Text("후속 질문 2개가 대기 중입니다.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.oeSecondaryText)
            }

            Spacer()
          }

          ProgressView(value: 0.68)
            .tint(accentColor.color)
        }
        .padding(18)
        .background(Color.oeBackground.opacity(0.74), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 18)
      }
      .padding(24)
    }
  }
}

private struct NativeOnboardingMiniBar: View {
  var title: String
  var accentColor: NativeAccentColor

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.oeText)

      Spacer()

      Circle()
        .fill(accentColor.color.opacity(0.9))
        .frame(width: 10, height: 10)
    }
    .padding(.horizontal, 16)
    .frame(height: 44)
    .background(Color.oeBackground.opacity(0.78), in: Capsule(style: .continuous))
  }
}

private struct NativeOnboardingChatBubble: View {
  var text: String
  var isUser: Bool
  var accentColor: NativeAccentColor

  var body: some View {
    Text(text)
      .font(.system(size: 13, weight: .semibold))
      .foregroundColor(isUser ? accentColor.foregroundColor : .oeText)
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
      .background(
        isUser ? accentColor.color : Color.oeBackground.opacity(0.78),
        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
      )
  }
}

private struct NativeOnboardingTodoCard: View {
  var title: String
  var time: String
  var isDone: Bool
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 20, weight: .semibold))
        .foregroundColor(isDone ? accentColor.color : .oeSecondaryText)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.oeText)
        Text(time)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.oeSecondaryText)
      }

      Spacer()
    }
    .padding(14)
    .background(Color.oeBackground.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct NativeOnboardingProjectTile: View {
  var icon: String
  var title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.oeText)

      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(.oeText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.oeBackground.opacity(0.74), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

private struct NativeOnboardingContextRow: View {
  var width: CGFloat
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(accentColor.color.opacity(0.85))
        .frame(width: 7, height: 7)

      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(Color.oeSecondaryText.opacity(0.2))
        .frame(width: width, height: 8)
    }
  }
}

private struct NativeOnboardingChip: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .bold))
      .foregroundColor(.oeText)
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(Color.oeBackground.opacity(0.72), in: Capsule(style: .continuous))
  }
}

private struct NativeOnboardingSpinner: View {
  var accentColor: NativeAccentColor

  var body: some View {
    Circle()
      .trim(from: 0.08, to: 0.72)
      .stroke(
        accentColor.foregroundColor.opacity(0.92),
        style: StrokeStyle(lineWidth: 3, lineCap: .round)
      )
      .rotationEffect(.degrees(32))
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
          accentColor.color.opacity(0.10),
          Color.oeGroupedBackground.opacity(0.9),
          Color.oeBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}
