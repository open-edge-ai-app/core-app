import SwiftUI

struct NativeSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            NativeGeneralSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "gearshape",
              title: "일반"
            )
          }

          NavigationLink {
            NativeModelSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "cpu",
              title: "모델"
            )
          }

          NavigationLink {
            NativePersonalSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "person.crop.circle",
              title: "개인 맞춤 설정"
            )
          }

          NavigationLink {
            NativeAppearanceSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "circle.lefthalf.filled",
              title: "모양"
            )
          }

          NavigationLink {
            NativeAppInfoSettingsView()
          } label: {
            NativeSettingsNavigationRow(
              icon: "info.circle",
              title: "정보"
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
          Button("완료") {
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
    List {
      Section("백그라운드") {
        Toggle("백그라운드 실행", isOn: $store.backgroundExecutionEnabled)
          .tint(store.accentColor.color)

        Toggle("백그라운드 Dynamic Island 활성", isOn: $store.backgroundDynamicIslandEnabled)
          .tint(store.accentColor.color)
          .disabled(!store.backgroundExecutionEnabled)
          .opacity(store.backgroundExecutionEnabled ? 1 : 0.42)
      }

      Section("Dynamic Island 펫") {
        Toggle("Dynamic Island 펫 활성", isOn: $store.dynamicIslandPetEnabled)
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

      Section("언어") {
        Picker("언어", selection: $store.selectedLanguage) {
          ForEach(NativeLanguage.allCases) { language in
            Text("\(language.nativeName) · \(language.englishName)")
              .tag(language)
          }
        }
      }
    }
    .navigationTitle("일반")
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

        Text(pet.subtitle)
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
    List {
      Section {
        ForEach(NativeModel.allCases) { model in
          let status = store.modelStatuses[model] ?? NativeModelStatus(model: model)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                  .font(.system(size: 16, weight: .semibold))
                Text(model.subtitle)
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
              Button("선택") {
                store.selectedModel = model
                store.saveSettings()
                store.loadSelectedModel()
              }
              .buttonStyle(.bordered)
              .tint(store.accentColor.color)

              if model == .gemma && !status.installed {
                Button(status.downloading ? "다운로드 중" : "다운로드") {
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
    .navigationTitle("모델")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct NativeAppearanceSettingsView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    List {
      Section("글씨 크기") {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("글씨 크기")
              .font(.system(size: 16, weight: .semibold))

            Spacer()

            Text(store.fontSizeSetting.title)
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
              Text(setting.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.oeText.opacity(store.fontSizeSetting == setting ? 0.82 : 0.36))
                .frame(maxWidth: .infinity, alignment: alignment(for: setting))
            }
          }
        }

        HStack {
          Text("미리보기")
            .font(.system(size: store.fontSizeSetting.bodySize))
          Spacer()
          Text(store.fontSizeSetting.title)
            .font(.system(size: 13))
            .foregroundColor(.oeMutedText)
        }
      }

      Section("화면 모드") {
        Picker("모드", selection: $store.appearanceMode) {
          ForEach(NativeAppearanceMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      }

      Section("강조 컬러") {
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

              Text(accentColor.title)
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
    .navigationTitle("모양")
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
    List {
      Section("기본 정보") {
        TextField("이름", text: $store.userName)
        Picker("성격", selection: $store.personality) {
          ForEach(personalities, id: \.self) { personality in
            Text(personality).tag(personality)
          }
        }
      }

      Section("메모리") {
        Toggle("메모리 활성", isOn: $store.memoryEnabled)
          .tint(store.accentColor.color)
        HStack {
          Text("인덱싱된 항목")
          Spacer()
          Text("\(store.localMemoryIndexedItems)개")
            .foregroundColor(.oeMutedText)
        }
        Button("메모리 다시 인덱싱") {
          store.rebuildLocalMemoryIndex()
        }
      }

      Section("맞춤형 지침") {
        TextEditor(text: $store.systemPrompt)
          .frame(minHeight: 160)
      }
    }
    .navigationTitle("개인 맞춤 설정")
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      store.saveSettings()
    }
  }
}

struct NativeAppInfoSettingsView: View {
  var body: some View {
    List {
      Section("지원") {
        Link("문제 신고하기", destination: URL(string: "https://github.com/open-edge-ai-app/core-app/issues")!)
        Link("기여하기", destination: URL(string: "https://github.com/open-edge-ai-app/core-app")!)
      }

      Section("앱 정보") {
        HStack {
          Text("버전")
          Spacer()
          Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1")
            .foregroundColor(.oeMutedText)
        }
        HStack {
          Text("플랫폼")
          Spacer()
          Text("iOS native")
            .foregroundColor(.oeMutedText)
        }
      }
    }
    .navigationTitle("정보")
    .navigationBarTitleDisplayMode(.inline)
  }
}
