import SwiftUI

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
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color.oeGroupedBackground)
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
      .background(Color(uiColor: .black))
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
