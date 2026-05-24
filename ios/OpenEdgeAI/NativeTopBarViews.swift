import SwiftUI

struct NativeTopBar: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var showingSessions: Bool

  var body: some View {
    NativeGlassEffectContainer(spacing: 12) {
      HStack(spacing: 12) {
      Button {
        withAnimation(.easeOut(duration: 0.24)) {
          showingSessions = true
        }
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
      }
      .accessibilityLabel(store.i18n.t(.chatOpenList))
      .buttonStyle(.plain)

      Button {
        store.createNewSession()
      } label: {
        Text(store.currentSession?.title ?? "Open Edge AI")
          .font(.system(size: 15, weight: .semibold))
          .lineLimit(1)
      }
      .buttonStyle(.plain)

      Spacer(minLength: 8)

      NativeModelMenu()
      }
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
  }
}

struct NativeModelMenu: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    Menu {
      ForEach(NativeModel.allCases) { model in
        let status = store.modelStatuses[model] ?? NativeModelStatus(model: model)
        Button {
          store.selectedModel = model
          store.saveSettings()
          if status.installed || status.systemManaged {
            store.loadSelectedModel()
          }
        } label: {
          Label(model.title, systemImage: store.selectedModel == model ? "checkmark" : "")
        }

        if model == .gemma && !status.installed {
          Button {
            store.downloadGemma()
          } label: {
            Label(
              status.downloading ? store.i18n.t(.commonDownloading) : store.i18n.t(.commonDownload),
              systemImage: status.downloading ? "arrow.triangle.2.circlepath" : "arrow.down.circle"
            )
          }
        }
      }
    } label: {
      HStack(spacing: 6) {
        Text(store.selectedModel.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "chevron.down")
          .font(.system(size: 10, weight: .bold))
      }
      .foregroundColor(.oeText)
      .padding(.horizontal, 10)
      .frame(height: 34)
      .background(.ultraThinMaterial, in: Capsule(style: .continuous))
      .overlay(
        Capsule(style: .continuous)
          .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
      )
    }
  }
}
