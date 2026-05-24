import SwiftUI

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
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color.oeGroupedBackground)
    .navigationTitle(i18n.t(.settingsPersonalization))
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      store.saveSettings()
    }
  }
}
