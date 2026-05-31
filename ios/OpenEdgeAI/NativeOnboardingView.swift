import SwiftUI

struct NativeOnboardingView: View {
  @EnvironmentObject private var store: NativeChatStore
  var onStart: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let i18n = store.i18n

      VStack(spacing: 0) {
        Spacer()
          .frame(height: max(proxy.safeAreaInsets.top + 112, proxy.size.height * 0.23))

        NativeOnboardingWelcomeTitle(i18n: i18n)

        VStack(spacing: 30) {
          NativeOnboardingFeatureRow(
            icon: "sparkles",
            title: i18n.t(.onboardingFeatureOfflineTitle),
            bodyText: i18n.t(.onboardingFeatureOfflineBody)
          )

          NativeOnboardingFeatureRow(
            icon: "lock.fill",
            title: i18n.t(.onboardingFeaturePrivateTitle),
            bodyText: i18n.t(.onboardingFeaturePrivateBody)
          )

          NativeOnboardingFeatureRow(
            icon: "memorychip.fill",
            title: i18n.t(.onboardingFeatureSiliconTitle),
            bodyText: i18n.t(.onboardingFeatureSiliconBody)
          )
        }
        .padding(.top, 78)
        .padding(.horizontal, 50)

        Spacer(minLength: 34)

        Button(action: onStart) {
          Text(i18n.t(.onboardingContinue))
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color.oeBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.oeText, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 50)
        .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .background(Color.oeBackground.ignoresSafeArea())
    }
  }
}

private struct NativeOnboardingWelcomeTitle: View {
  var i18n: NativeI18n

  var body: some View {
    VStack(spacing: 6) {
      Text(i18n.t(.onboardingWelcomePrefix))
        .font(.system(size: 39, weight: .heavy))
        .foregroundColor(.oeText)

      Text(i18n.t(.onboardingWelcomeProduct))
        .font(.system(size: 39, weight: .heavy))
        .foregroundStyle(
          LinearGradient(
            colors: [
              Color(red: 0.43, green: 0.82, blue: 0.88),
              Color(red: 0.02, green: 0.45, blue: 0.98)
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
    }
    .multilineTextAlignment(.center)
    .minimumScaleFactor(0.84)
    .padding(.horizontal, 24)
  }
}

private struct NativeOnboardingFeatureRow: View {
  var icon: String
  var title: String
  var bodyText: String

  var body: some View {
    HStack(alignment: .top, spacing: 22) {
      Image(systemName: icon)
        .font(.system(size: 30, weight: .bold))
        .foregroundColor(.oeText)
        .frame(width: 44, height: 36, alignment: .center)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(.oeText)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        Text(bodyText)
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.oeSecondaryText)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
