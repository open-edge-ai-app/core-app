import SwiftUI

struct NativeAppearanceSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    let i18n = store.i18n

    List {
      Section(i18n.t(.settingsFontSize)) {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text(i18n.t(.settingsFontSize))
              .font(.system(size: 16, weight: .semibold))

            Spacer()

            Text(store.fontSizeSetting.localizedTitle(i18n))
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(.oeMutedText)
          }

          Slider(
            value: Binding(
              get: { store.fontSizeSetting.sliderValue },
              set: { store.fontSizeSetting = NativeFontSizeSetting(sliderValue: $0) }
            ),
            in: 0...2,
            step: 1
          )
          .tint(store.accentColor.color)

          HStack {
            ForEach(NativeFontSizeSetting.allCases) { setting in
              Text(setting.localizedTitle(i18n))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.oeText.opacity(store.fontSizeSetting == setting ? 0.82 : 0.36))
                .frame(maxWidth: .infinity, alignment: alignment(for: setting))
            }
          }
        }

        HStack {
          Text(i18n.t(.settingsPreview))
            .font(.system(size: store.fontSizeSetting.bodySize))
          Spacer()
          Text(store.fontSizeSetting.localizedTitle(i18n))
            .font(.system(size: 13))
            .foregroundColor(.oeMutedText)
        }
      }

      Section(i18n.t(.settingsDisplayMode)) {
        Picker(i18n.t(.settingsMode), selection: $store.appearanceMode) {
          ForEach(NativeAppearanceMode.allCases) { mode in
            Text(mode.localizedTitle(i18n)).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      }

      Section(i18n.t(.settingsAccentColor)) {
        ForEach(NativeAccentColor.allCases) { accentColor in
          Button {
            store.accentColor = accentColor
            store.saveSettings()
          } label: {
            HStack(spacing: 12) {
              Circle()
                .fill(accentColor.color)
                .frame(width: 22, height: 22)
                .overlay(
                  Circle()
                    .stroke(Color.oeBorder, lineWidth: 1)
                )

              Text(accentColor.localizedTitle(i18n))
                .foregroundColor(.oeText)

              Spacer()

              if store.accentColor == accentColor {
                Image(systemName: "checkmark")
                  .font(.system(size: 14, weight: .bold))
                  .foregroundColor(store.accentColor.color)
              }
            }
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationTitle(i18n.t(.settingsAppearance))
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: store.fontSizeSetting) { _, _ in
      store.saveSettings()
    }
    .onChange(of: store.appearanceMode) { _, _ in
      store.saveSettings()
    }
  }

  private func alignment(for setting: NativeFontSizeSetting) -> Alignment {
    switch setting {
    case .small:
      return .leading
    case .standard:
      return .center
    case .large:
      return .trailing
    }
  }
}
