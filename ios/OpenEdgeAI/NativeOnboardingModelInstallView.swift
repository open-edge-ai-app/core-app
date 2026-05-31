import SwiftUI

struct NativeOnboardingModelInstallPage: View {
  private let fallbackGemmaSizeBytes: Int64 = 2_588_147_712

  var i18n: NativeI18n
  var status: NativeModelStatus
  var accentColor: Color
  var safeAreaInsets: EdgeInsets
  var height: CGFloat
  var onDownload: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: max(safeAreaInsets.top + 112, height * 0.18))

      VStack(spacing: 20) {
        NativeOnboardingDownloadMark(accentColor: accentColor)

        VStack(spacing: 10) {
          Text(i18n.t(.onboardingModelTitle))
            .font(.system(size: 30, weight: .heavy))
            .foregroundColor(.oeText)

          Text(i18n.t(.onboardingModelSubtitle))
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.oeSecondaryText)
            .multilineTextAlignment(.center)
        }
      }

      NativeOnboardingModelCard(
        i18n: i18n,
        status: status,
        accentColor: accentColor
      )
      .padding(.horizontal, 28)
      .padding(.top, 38)

      Spacer(minLength: 24)

      VStack(spacing: 16) {
        Text(i18n.t(.onboardingModelKeepOpen))
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.oeMutedText)

        NativeOnboardingPrimaryButton(
          title: buttonTitle,
          systemImage: status.downloading ? nil : "arrow.down.circle.fill",
          disabled: status.downloading,
          action: onDownload
        )
      }
      .padding(.horizontal, 28)
      .padding(.bottom, safeAreaInsets.bottom + 26)
    }
  }

  private var buttonTitle: String {
    if status.downloading {
      return i18n.t(
        .onboardingModelDownloadProgress,
        ["progress": "\(Int((status.progress * 100).rounded()))"]
      )
    }
    if status.installed {
      return i18n.t(.onboardingContinue)
    }
    return "\(i18n.t(.commonDownload)) (\(byteCountString(modelSizeBytes)))"
  }

  private var modelSizeBytes: Int64 {
    status.totalBytes > 0 ? status.totalBytes : fallbackGemmaSizeBytes
  }

  private func byteCountString(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB]
    formatter.countStyle = .decimal
    formatter.includesUnit = true
    formatter.includesCount = true
    return formatter.string(fromByteCount: bytes)
  }
}

private struct NativeOnboardingDownloadMark: View {
  var accentColor: Color

  var body: some View {
    Image(systemName: "arrow.down")
      .font(.system(size: 44, weight: .heavy))
      .foregroundColor(.oeText)
      .frame(width: 96, height: 96)
      .overlay {
        Circle()
          .stroke(
            Color.oeText,
            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 12])
          )
      }
      .background(accentColor.opacity(0.08), in: Circle())
      .accessibilityHidden(true)
  }
}

private struct NativeOnboardingModelCard: View {
  var i18n: NativeI18n
  var status: NativeModelStatus
  var accentColor: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 16) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(accentColor.opacity(0.14))
          .frame(width: 48, height: 48)
          .overlay {
            Text("G")
              .font(.system(size: 24, weight: .heavy, design: .rounded))
              .foregroundColor(accentColor)
          }
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text("Google Gemma 4")
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(.oeText)

          Text(i18n.t(.onboardingModelGemmaBody))
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.oeSecondaryText)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 26, weight: .semibold))
          .foregroundColor(.oeText)
          .accessibilityLabel(i18n.t(.commonSelect))
      }

      if status.downloading {
        ProgressView(value: status.progress)
          .progressViewStyle(.linear)
          .tint(.oeText)
          .accessibilityLabel(i18n.t(.commonDownloading))
      }

      if let error = status.error, !status.installed, !status.downloading {
        Text(error.isEmpty ? i18n.t(.onboardingModelDownloadFailed) : error)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.oeDestructive)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(20)
    .background(Color.oeSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.oeText, lineWidth: 2)
    }
  }
}

struct NativeOnboardingPrimaryButton: View {
  var title: String
  var systemImage: String?
  var disabled: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 17, weight: .bold))
        }

        Text(title)
          .font(.system(size: 18, weight: .semibold))
      }
      .foregroundColor(Color.oeBackground)
      .frame(maxWidth: .infinity)
      .frame(height: 58)
      .background(Color.oeText.opacity(disabled ? 0.48 : 1), in: Capsule(style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }
}
