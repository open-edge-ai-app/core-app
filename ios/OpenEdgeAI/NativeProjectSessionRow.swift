import SwiftUI

struct NativeProjectSessionRow: View {
  @EnvironmentObject private var store: NativeChatStore
  var session: NativeChatSession
  var subtitle: String
  var isWriting: Bool
  var availableProjects: [NativeProject]
  var action: () -> Void
  var onRename: () -> Void
  var onAddToProject: (NativeProject) -> Void
  var onDelete: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(session.title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.oeText)
            .lineLimit(1)

          Text(subtitle)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.oeMutedText)
            .lineLimit(1)
        }

        Spacer(minLength: 10)

        if isWriting {
          ProgressView()
            .controlSize(.small)
            .tint(.oeMutedText)
            .frame(width: 18, height: 18)
            .accessibilityLabel(store.i18n.t(.chatGenerating))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button {
        onRename()
      } label: {
        Label(store.i18n.t(.commonRename), systemImage: "pencil")
      }

      Menu {
        if availableProjects.isEmpty {
          Text(store.i18n.t(.menuNoProjectsToAdd))
        } else {
          ForEach(availableProjects) { project in
            Button {
              onAddToProject(project)
            } label: {
              Label(project.title, systemImage: project.iconName)
            }
          }
        }
      } label: {
        Label(store.i18n.t(.menuAddToProject), systemImage: "folder.badge.plus")
      }

      Button(role: .destructive) {
      onDelete()
    } label: {
      Label(store.i18n.t(.commonDelete), systemImage: "trash")
    }
    }
  }
}
