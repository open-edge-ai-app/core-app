import SwiftUI

struct NativeOnboardingView: View {
  @EnvironmentObject private var store: NativeChatStore
  var onStart: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let i18n = store.i18n
      let accentColor = store.accentColor.color

      VStack(spacing: 0) {
        NativeOnboardingCorePanel(accentColor: accentColor)
          .frame(height: min(470, max(410, proxy.size.height * 0.54)))
          .padding(.horizontal, 22)
          .padding(.top, proxy.safeAreaInsets.top + 18)

        VStack(alignment: .leading, spacing: 22) {
          NativeOnboardingHeroCopy(i18n: i18n)

          HStack(spacing: 10) {
            NativeOnboardingCapabilityChip(
              icon: "wifi.slash",
              text: i18n.t(.onboardingFeatureOfflineTitle),
              accentColor: accentColor
            )
            NativeOnboardingCapabilityChip(
              icon: "lock.shield.fill",
              text: i18n.t(.onboardingFeaturePrivateTitle),
              accentColor: accentColor
            )
          }

          NativeOnboardingSiliconStrip(
            title: i18n.t(.onboardingFeatureSiliconTitle),
            subtitle: i18n.t(.onboardingFeatureSiliconBody),
            accentColor: accentColor
          )
        }
        .padding(.horizontal, 30)
        .padding(.top, 28)

        Spacer(minLength: 22)

        Button(action: onStart) {
          HStack(spacing: 10) {
            Text(i18n.t(.onboardingContinue))
              .font(.system(size: 18, weight: .semibold))

            Image(systemName: "arrow.right")
              .font(.system(size: 17, weight: .bold))
          }
          .foregroundColor(Color.oeBackground)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.oeText, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.bottom, proxy.safeAreaInsets.bottom + 24)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .background {
        NativeOnboardingSoftBackground(accentColor: accentColor)
          .ignoresSafeArea()
      }
    }
  }
}

private struct NativeOnboardingSoftBackground: View {
  var accentColor: Color

  var body: some View {
    ZStack {
      Color.oeBackground

      Circle()
        .fill(accentColor.opacity(0.12))
        .frame(width: 250, height: 250)
        .blur(radius: 70)
        .offset(x: -150, y: -250)

      Circle()
        .fill(Color.oeText.opacity(0.045))
        .frame(width: 280, height: 280)
        .blur(radius: 75)
        .offset(x: 150, y: 250)
    }
  }
}

private struct NativeOnboardingCorePanel: View {
  var accentColor: Color

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 38, style: .continuous)
        .fill(Color.oeText)

      NativeOnboardingCoreGrid()
        .opacity(0.24)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))

      VStack(spacing: 24) {
        HStack {
          Label("LOCAL CORE", systemImage: "circle.hexagongrid.fill")
            .font(.system(size: 12, weight: .bold))
            .tracking(1.6)
            .foregroundColor(Color.oeBackground.opacity(0.72))

          Spacer()

          Circle()
            .fill(accentColor)
            .frame(width: 9, height: 9)
            .overlay {
              Circle()
                .stroke(accentColor.opacity(0.36), lineWidth: 7)
            }
        }

        Spacer()

        ZStack {
          Circle()
            .stroke(Color.oeBackground.opacity(0.12), lineWidth: 1)
            .frame(width: 230, height: 230)

          Circle()
            .stroke(Color.oeBackground.opacity(0.18), lineWidth: 1)
            .frame(width: 172, height: 172)

          NativeOnboardingOrbitDot(angle: -18, radius: 114, color: accentColor)
          NativeOnboardingOrbitDot(angle: 142, radius: 86, color: Color.oeBackground.opacity(0.76))
          NativeOnboardingOrbitDot(angle: 224, radius: 118, color: Color.oeBackground.opacity(0.34))

          RoundedRectangle(cornerRadius: 42, style: .continuous)
            .fill(Color.oeBackground)
            .frame(width: 128, height: 128)
            .overlay {
              Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(
                  LinearGradient(
                    colors: [accentColor, Color.oeText.opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            }
        }

        Spacer()

        VStack(alignment: .leading, spacing: 8) {
          Text("Private intelligence")
            .font(.system(size: 28, weight: .heavy))
            .foregroundColor(Color.oeBackground)

          Text("Runs locally. Keeps context close.")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Color.oeBackground.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(28)
    }
  }
}

private struct NativeOnboardingCoreGrid: View {
  var body: some View {
    Canvas { context, size in
      let step: CGFloat = 32
      let lineColor = Color.oeBackground.opacity(0.2)

      for x in stride(from: CGFloat(0), through: size.width, by: step) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(lineColor), lineWidth: 0.6)
      }

      for y in stride(from: CGFloat(0), through: size.height, by: step) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(path, with: .color(lineColor), lineWidth: 0.6)
      }
    }
  }
}

private struct NativeOnboardingOrbitDot: View {
  var angle: Double
  var radius: CGFloat
  var color: Color

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 12, height: 12)
      .offset(
        x: CGFloat(cos(angle * Double.pi / 180)) * radius,
        y: CGFloat(sin(angle * Double.pi / 180)) * radius
      )
  }
}

private struct NativeOnboardingHeroCopy: View {
  var i18n: NativeI18n

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(i18n.t(.onboardingWelcomePrefix))
        .font(.system(size: 36, weight: .heavy))
        .foregroundColor(.oeText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      Text(i18n.t(.onboardingFeatureOfflineBody))
        .font(.system(size: 17, weight: .medium))
        .foregroundColor(.oeSecondaryText)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct NativeOnboardingCapabilityChip: View {
  var icon: String
  var text: String
  var accentColor: Color

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(accentColor)

      Text(text)
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(.oeText)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .padding(.horizontal, 13)
    .frame(maxWidth: .infinity)
    .frame(height: 42)
    .background(Color.oeSurface.opacity(0.72), in: Capsule(style: .continuous))
    .overlay {
      Capsule(style: .continuous)
        .stroke(Color.oeBorder.opacity(0.28), lineWidth: 1)
    }
  }
}

private struct NativeOnboardingSiliconStrip: View {
  var title: String
  var subtitle: String
  var accentColor: Color

  var body: some View {
    HStack(spacing: 14) {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(accentColor.opacity(0.16))
        .frame(width: 48, height: 48)
        .overlay {
          Image(systemName: "cpu.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(accentColor)
        }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.oeText)

        Text(subtitle)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.oeSecondaryText)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .layoutPriority(1)
    }
    .padding(14)
    .frame(minHeight: 78)
    .background(Color.oeSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.oeBorder.opacity(0.24), lineWidth: 1)
    }
  }
}
