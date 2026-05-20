import SwiftUI

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
