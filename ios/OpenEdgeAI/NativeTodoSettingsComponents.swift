import SwiftUI

struct NativeTodoSettingsHeader: View {
  var i18n: NativeI18n

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(i18n.t(.todoSettings))
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(.oeText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 4)
  }
}

struct NativeTodoSettingsGroup<Content: View>: View {
  var title: String
  var trailingText: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text(title)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.oeMutedText)
          .textCase(.uppercase)

        Spacer()

        if let trailingText {
          Text(trailingText)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.oeMutedText)
        }
      }
      .padding(.horizontal, 4)

      VStack(spacing: 0) {
        content
      }
      .nativeLiquidGlass(cornerRadius: 20)
      .nativeGlassStroke(cornerRadius: 20)
    }
  }
}

struct NativeTodoSettingsToggleRow: View {
  var icon: String
  var title: String
  @Binding var isOn: Bool
  var accentColor: Color

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      NativeTodoSettingsIcon(systemName: icon)

      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.oeText)

      Spacer(minLength: 12)

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(accentColor)
    }
    .padding(.horizontal, 14)
    .frame(height: 60)
  }
}

struct NativeTodoSettingsIcon: View {
  var systemName: String

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 15, weight: .semibold))
      .foregroundColor(.oeText)
      .frame(width: 34, height: 34)
      .nativeLiquidGlass(cornerRadius: 10)
  }
}

struct NativeTodoSettingsDivider: View {
  var body: some View {
    Divider()
      .background(Color.oeSeparator)
      .padding(.leading, 60)
  }
}

struct NativeTodoSettingsEmptyRow: View {
  var icon: String
  var title: String

  var body: some View {
    HStack(spacing: 12) {
      NativeTodoSettingsIcon(systemName: icon)

      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.oeMutedText)

      Spacer()
    }
    .padding(.horizontal, 14)
    .frame(height: 54)
  }
}

struct NativeTodoSettingsStatusPill: View {
  var title: String
  var isActive: Bool

  var body: some View {
    Text(title)
      .font(.system(size: 10, weight: .bold))
      .foregroundColor(isActive ? .oeControlText : .oeSecondaryText)
      .padding(.horizontal, 8)
      .frame(height: 20)
      .nativeLiquidGlassCapsule(
        tint: isActive ? Color.oeControlFill.opacity(0.38) : nil
      )
  }
}

struct NativeTodoLabelRow: View {
  var i18n: NativeI18n
  var label: NativeTodoLabel
  var onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color(todoLabelHex: label.colorHex))
        .frame(width: 12, height: 12)

      Text(label.title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.oeText)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.oeMutedText)
          .frame(width: 30, height: 30)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoDeleteLabel, ["name": label.title]))
    }
    .padding(.horizontal, 14)
    .frame(height: 50)
  }
}
