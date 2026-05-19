import SwiftUI

struct NativeSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    let i18n = store.i18n

    NavigationStack {
      List {
        Section {
          NavigationLink {
            NativeGeneralSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "gearshape",
              title: i18n.t(.settingsGeneral)
            )
          }

          NavigationLink {
            NativeModelSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "cpu",
              title: i18n.t(.settingsModel)
            )
          }

          NavigationLink {
            NativePersonalSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "person.crop.circle",
              title: i18n.t(.settingsPersonalization)
            )
          }

          NavigationLink {
            NativeAppearanceSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "circle.lefthalf.filled",
              title: i18n.t(.settingsAppearance)
            )
          }

          NavigationLink {
            NativeAppInfoSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "info.circle",
              title: i18n.t(.settingsInfo)
            )
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Image("OpenEdgeLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.oeText)
            .frame(width: 138, height: 34)
            .accessibilityLabel("Open Edge AI")
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(i18n.t(.commonDone)) {
            store.saveSettings()
            dismiss()
          }
          .foregroundColor(store.accentColor.color)
        }
      }
    }
  }
}

struct NativeSettingsNavigationRow: View {
  var icon: String
  var title: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
        .frame(width: 28, height: 28)

      Text(title)
        .foregroundColor(.oeText)

      Spacer()
    }
  }
}

struct NativeGeneralSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    let i18n = store.i18n

    List {
      Section(i18n.t(.settingsBackground)) {
        Toggle(i18n.t(.settingsBackgroundExecution), isOn: $store.backgroundExecutionEnabled)
          .tint(store.accentColor.color)

        Toggle(i18n.t(.settingsBackgroundDynamicIsland), isOn: $store.backgroundDynamicIslandEnabled)
          .tint(store.accentColor.color)
          .disabled(!store.backgroundExecutionEnabled)
          .opacity(store.backgroundExecutionEnabled ? 1 : 0.42)
      }

      Section(i18n.t(.settingsDynamicIslandPet)) {
        Toggle(i18n.t(.settingsDynamicIslandPetEnabled), isOn: $store.dynamicIslandPetEnabled)
          .tint(store.accentColor.color)
          .disabled(!store.canRunBackgroundDynamicIsland)

        ForEach(NativeDynamicIslandPet.allCases) { pet in
          Button {
            guard store.canRunBackgroundDynamicIsland else {
              return
            }
            store.selectedDynamicIslandPet = pet
            store.dynamicIslandPetEnabled = true
            store.saveSettings()
          } label: {
            NativeDynamicIslandPetOption(
              i18n: i18n,
              pet: pet,
              isSelected: store.selectedDynamicIslandPet == pet
            )
          }
          .buttonStyle(.plain)
          .disabled(!store.canRunBackgroundDynamicIsland)
        }
      }
      .disabled(!store.canRunBackgroundDynamicIsland)
      .opacity(store.canRunBackgroundDynamicIsland ? 1 : 0.42)

      Section(i18n.t(.settingsLanguage)) {
        Picker(i18n.t(.settingsLanguage), selection: $store.selectedLanguage) {
          ForEach(NativeLanguage.allCases) { language in
            Text("\(language.nativeName) · \(language.englishName)")
              .tag(language)
          }
        }
      }
    }
    .navigationTitle(i18n.t(.settingsGeneral))
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: store.backgroundExecutionEnabled) { _, isEnabled in
      if !isEnabled {
        store.backgroundDynamicIslandEnabled = false
        store.dynamicIslandPetEnabled = false
      }
      store.saveSettings()
      store.refreshBackgroundExecutionState()
    }
    .onChange(of: store.backgroundDynamicIslandEnabled) { _, isEnabled in
      if !isEnabled {
        store.dynamicIslandPetEnabled = false
      }
      store.saveSettings()
      if store.canRunBackgroundDynamicIsland {
        store.runQueuedDraftIfReady()
        store.refreshDynamicIslandActivity()
      } else {
        store.refreshDynamicIslandActivity()
      }
    }
    .onChange(of: store.dynamicIslandPetEnabled) { _, isEnabled in
      if isEnabled && !store.canRunBackgroundDynamicIsland {
        store.dynamicIslandPetEnabled = false
      }
      store.saveSettings()
      store.refreshDynamicIslandActivity()
    }
    .onChange(of: store.selectedDynamicIslandPet) { _, _ in
      store.saveSettings()
      store.refreshDynamicIslandActivity()
    }
    .onChange(of: store.selectedLanguage) { _, _ in
      store.saveSettings()
    }
  }
}

struct NativeDynamicIslandPetOption: View {
  var i18n: NativeI18n
  var pet: NativeDynamicIslandPet
  var isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {
      NativeDynamicIslandPetView(
        pet: pet,
        motion: isSelected ? .running : .resting,
        size: 30
      )
      .frame(width: 42, height: 38)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(pet.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeText)

        Text(pet.localizedSubtitle(i18n))
          .font(.system(size: 12))
          .foregroundColor(.oeSecondaryText)
          .lineLimit(1)
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.oeText)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }
}

struct NativeModelSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    let i18n = store.i18n

    List {
      Section {
        ForEach(NativeModel.allCases) { model in
          let status = store.modelStatuses[model] ?? NativeModelStatus(model: model)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                  .font(.system(size: 16, weight: .semibold))
                Text(model.localizedSubtitle(i18n))
                  .font(.system(size: 13))
                  .foregroundColor(.oeMutedText)
              }
              Spacer()
              if store.selectedModel == model {
                Image(systemName: "checkmark.circle.fill")
              }
            }

            if status.downloading {
              ProgressView(value: status.progress)
                .tint(store.accentColor.color)
            }

            if let error = status.error, !status.installed {
              Text(error)
                .font(.system(size: 12))
                .foregroundColor(.oeMutedText)
            }

            HStack {
              Button(i18n.t(.commonSelect)) {
                store.selectedModel = model
                store.saveSettings()
                store.loadSelectedModel()
              }
              .buttonStyle(.bordered)
              .tint(store.accentColor.color)

              if model == .gemma && !status.installed {
                Button(status.downloading ? i18n.t(.commonDownloading) : i18n.t(.commonDownload)) {
                  store.downloadGemma()
                }
                .buttonStyle(.borderedProminent)
                .tint(store.accentColor.color)
                .disabled(status.downloading)
              }
            }
          }
        }
      }
    }
    .navigationTitle(i18n.t(.settingsModel))
    .navigationBarTitleDisplayMode(.inline)
  }
}

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

struct NativePersonalSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore
  private let personalities = ["Balanced", "Direct", "Friendly", "Creative", "Precise"]

  var body: some View {
    let i18n = store.i18n

    List {
      Section(i18n.t(.settingsBasicInfo)) {
        TextField(i18n.t(.settingsName), text: $store.userName)
        Picker(i18n.t(.settingsPersonality), selection: $store.personality) {
          ForEach(personalities, id: \.self) { personality in
            Text(personality).tag(personality)
          }
        }
      }

      Section(i18n.t(.settingsMemory)) {
        Toggle(i18n.t(.settingsMemoryEnabled), isOn: $store.memoryEnabled)
          .tint(store.accentColor.color)
        HStack {
          Text(i18n.t(.settingsIndexedItems))
          Spacer()
          Text(i18n.t(.settingsIndexedItemCount, ["count": String(store.localMemoryIndexedItems)]))
            .foregroundColor(.oeMutedText)
        }
        Button(i18n.t(.settingsRebuildMemory)) {
          store.rebuildLocalMemoryIndex()
        }
      }

      Section(i18n.t(.settingsCustomInstructions)) {
        TextEditor(text: $store.systemPrompt)
          .frame(minHeight: 160)
      }
    }
    .navigationTitle(i18n.t(.settingsPersonalization))
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      store.saveSettings()
    }
  }
}

struct NativeAppInfoSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    let i18n = store.i18n

    List {
      Section(i18n.t(.settingsSupport)) {
        Link(i18n.t(.settingsReportIssue), destination: URL(string: "https://github.com/open-edge-ai-app/core-app/issues")!)
        Link(i18n.t(.settingsContribute), destination: URL(string: "https://github.com/open-edge-ai-app/core-app")!)
      }

      Section(i18n.t(.settingsAppInfo)) {
        HStack {
          Text(i18n.t(.settingsVersion))
          Spacer()
          Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1")
            .foregroundColor(.oeMutedText)
        }
        HStack {
          Text(i18n.t(.settingsPlatform))
          Spacer()
          Text(i18n.t(.settingsPlatformIosNative))
            .foregroundColor(.oeMutedText)
        }
      }
    }
    .navigationTitle(i18n.t(.settingsInfo))
    .navigationBarTitleDisplayMode(.inline)
  }
}
