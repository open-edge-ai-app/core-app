import SwiftUI

struct NativeOnboardingView: View {
  @EnvironmentObject private var store: NativeChatStore
  @State private var step: NativeOnboardingStep = .welcome
  @State private var requestedGemmaDownload = false
  var onStart: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let i18n = store.i18n

      ZStack {
        NativeOnboardingBackground(accentColor: store.accentColor.color)
          .ignoresSafeArea()

        switch step {
        case .welcome:
          NativeOnboardingWelcomePage(
            i18n: i18n,
            accentColor: store.accentColor.color,
            safeAreaInsets: proxy.safeAreaInsets,
            height: proxy.size.height
          ) {
            withAnimation(.easeInOut(duration: 0.24)) {
              step = .modelInstall
            }
          }
        case .modelInstall:
          NativeOnboardingModelInstallPage(
            i18n: i18n,
            status: gemmaStatus,
            accentColor: store.accentColor.color,
            safeAreaInsets: proxy.safeAreaInsets,
            height: proxy.size.height,
            onDownload: startGemmaDownload
          )
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .task {
      await store.refreshModelStatuses()
    }
    .onChange(of: gemmaStatus.installed) { _, installed in
      guard installed, requestedGemmaDownload, step == .modelInstall else {
        return
      }
      finishGemmaSetup()
    }
  }

  private var gemmaStatus: NativeModelStatus {
    store.modelStatuses[.gemma] ?? NativeModelStatus(model: .gemma)
  }

  private func startGemmaDownload() {
    store.selectedModel = .gemma
    store.saveSettings()

    if gemmaStatus.installed {
      finishGemmaSetup()
      return
    }

    requestedGemmaDownload = true
    store.downloadGemma()
  }

  private func finishGemmaSetup() {
    store.selectedModel = .gemma
    store.loadSelectedModel()
    onStart()
  }
}

private enum NativeOnboardingStep: Equatable {
  case welcome
  case modelInstall
}

private struct NativeOnboardingWelcomePage: View {
  var i18n: NativeI18n
  var accentColor: Color
  var safeAreaInsets: EdgeInsets
  var height: CGFloat
  var onContinue: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: max(safeAreaInsets.top + 82, height * 0.16))

      NativeOnboardingTitle(i18n: i18n, accentColor: accentColor)

      VStack(spacing: 12) {
        NativeOnboardingFeatureCard(
          icon: "sparkles",
          title: i18n.t(.onboardingFeatureOfflineTitle),
          subtitle: i18n.t(.onboardingFeatureOfflineBody),
          accentColor: accentColor
        )

        NativeOnboardingFeatureCard(
          icon: "lock.shield.fill",
          title: i18n.t(.onboardingFeaturePrivateTitle),
          subtitle: i18n.t(.onboardingFeaturePrivateBody),
          accentColor: accentColor
        )

        NativeOnboardingFeatureCard(
          icon: "checklist",
          title: i18n.t(.onboardingTodoTitle),
          subtitle: i18n.t(.onboardingTodoSubtitle),
          accentColor: accentColor
        )

        NativeOnboardingFeatureCard(
          icon: "folder.fill",
          title: i18n.t(.onboardingProjectTitle),
          subtitle: i18n.t(.onboardingProjectSubtitle),
          accentColor: accentColor
        )
      }
      .padding(.horizontal, 24)
      .padding(.top, 58)

      Spacer(minLength: 24)

      NativeOnboardingPrimaryButton(
        title: i18n.t(.onboardingContinue),
        systemImage: nil,
        disabled: false,
        action: onContinue
      )
      .padding(.horizontal, 28)
      .padding(.bottom, safeAreaInsets.bottom + 26)
    }
  }
}

private struct NativeOnboardingBackground: View {
  var accentColor: Color

  var body: some View {
    ZStack {
      Color.oeBackground

      Circle()
        .fill(accentColor.opacity(0.10))
        .frame(width: 240, height: 240)
        .blur(radius: 66)
        .offset(x: 118, y: -268)

      Circle()
        .fill(Color.oeText.opacity(0.035))
        .frame(width: 280, height: 280)
        .blur(radius: 78)
        .offset(x: -150, y: 286)
    }
  }
}

private struct NativeOnboardingTitle: View {
  var i18n: NativeI18n
  var accentColor: Color

  var body: some View {
    Image("KeplerLogo")
      .resizable()
      .scaledToFit()
      .frame(width: 292, height: 112)
      .accessibilityLabel(i18n.t(.onboardingWelcomeProduct))
    .padding(.horizontal, 24)
  }
}

private struct NativeOnboardingFeatureCard: View {
  var icon: String
  var title: String
  var subtitle: String
  var accentColor: Color

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      RoundedRectangle(cornerRadius: 15, style: .continuous)
        .fill(accentColor.opacity(0.12))
        .frame(width: 44, height: 44)
        .overlay {
          Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(accentColor)
        }
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.oeText)
          .lineLimit(1)
          .minimumScaleFactor(0.86)

        Text(subtitle)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.oeSecondaryText)
          .lineSpacing(2)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(Color.oeSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.oeBorder.opacity(0.22), lineWidth: 1)
    }
  }
}
