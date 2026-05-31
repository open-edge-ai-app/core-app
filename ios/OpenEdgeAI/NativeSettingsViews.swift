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
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Color.oeGroupedBackground)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Image("OpenEdgeLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.oeText)
            .frame(width: 138, height: 34)
            .accessibilityLabel("Kepler")
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
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }
}
