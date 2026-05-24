import SwiftUI

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
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color.oeGroupedBackground)
    .navigationTitle(i18n.t(.settingsInfo))
    .navigationBarTitleDisplayMode(.inline)
  }
}
