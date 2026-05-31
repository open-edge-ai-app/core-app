import SwiftUI

struct NativeOnboardingView: View {
  @EnvironmentObject private var store: NativeChatStore
  var onStart: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let i18n = store.i18n

      VStack(spacing: 0) {
        Spacer()
          .frame(height: max(proxy.safeAreaInsets.top + 82, proxy.size.height * 0.16))

        NativeOnboardingTitle(i18n: i18n, accentColor: store.accentColor.color)

        VStack(spacing: 12) {
          NativeOnboardingFeatureCard(
            icon: "sparkles",
            title: i18n.t(.onboardingFeatureOfflineTitle),
            subtitle: i18n.t(.onboardingFeatureOfflineBody),
            accentColor: store.accentColor.color
          )

          NativeOnboardingFeatureCard(
            icon: "lock.shield.fill",
            title: i18n.t(.onboardingFeaturePrivateTitle),
            subtitle: i18n.t(.onboardingFeaturePrivateBody),
            accentColor: store.accentColor.color
          )

          NativeOnboardingFeatureCard(
            icon: "checklist",
            title: i18n.t(.onboardingTodoTitle),
            subtitle: i18n.t(.onboardingTodoSubtitle),
            accentColor: store.accentColor.color
          )

          NativeOnboardingFeatureCard(
            icon: "folder.fill",
            title: i18n.t(.onboardingProjectTitle),
            subtitle: i18n.t(.onboardingProjectSubtitle),
            accentColor: store.accentColor.color
          )
        }
        .padding(.horizontal, 24)
        .padding(.top, 58)

        Spacer(minLength: 24)

        Button(action: onStart) {
          Text(i18n.t(.onboardingContinue))
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Color.oeBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.oeText, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .padding(.bottom, proxy.safeAreaInsets.bottom + 26)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .background {
        NativeOnboardingBackground(accentColor: store.accentColor.color)
          .ignoresSafeArea()
      }
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
    VStack(spacing: 16) {
      Text(i18n.t(.onboardingWelcomePrefix))
        .font(.system(size: 30, weight: .heavy))
        .foregroundColor(.oeText)

      Image("KeplerLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 274, height: 106)
        .accessibilityLabel(i18n.t(.onboardingWelcomeProduct))
    }
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
