import SwiftUI

struct NativeProjectSessionsPage: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  var project: NativeProject
  @Binding var showingAttachmentOptions: Bool
  var onSelectSession: (NativeChatSession) -> Void
  @State private var renameTarget: NativeRenameTarget?

  private var currentProject: NativeProject {
    store.projects.first { $0.id == project.id } ?? project
  }

  private var projectSessions: [NativeChatSession] {
    store.sessions
      .filter { $0.projectId == currentProject.id && store.shouldShowSession($0) }
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
        .zIndex(2)

      Divider()

      ZStack(alignment: .bottom) {
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            chatList
          }
          .padding(.horizontal, 28)
          .padding(.top, 22)
          .padding(.bottom, 132)
        }

        NativeProjectComposerBar(
          project: currentProject,
          showingAttachmentOptions: $showingAttachmentOptions
        )
      }
    }
    .background(Color.oeBackground.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $renameTarget) { target in
      NativeRenameSheet(target: target)
        .environmentObject(store)
        .presentationDetents(target.isProject ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }
  }

  private var topBar: some View {
    HStack(spacing: 12) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.i18n.t(.projectList))

      Button {
        renameTarget = .project(currentProject)
      } label: {
        Text(currentProject.title)
          .font(.system(size: 15, weight: .semibold))
          .lineLimit(1)
      }
      .buttonStyle(.plain)

      Spacer(minLength: 8)

      Button {
        renameTarget = .project(currentProject)
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 22, weight: .bold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.i18n.t(.menuProjectSettings))
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(Color.oeBackground)
  }

  private var chatList: some View {
    VStack(alignment: .leading, spacing: 20) {
      if projectSessions.isEmpty {
        Text(store.i18n.t(.projectNoChats))
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.oeMutedText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 8)
      } else {
        ForEach(projectSessions) { session in
          NativeProjectSessionRow(
            session: session,
            subtitle: sessionSubtitle(for: session),
            isWriting: store.activeWritingSessionId == session.id,
            availableProjects: store.projects.filter { $0.id != session.projectId }
          ) {
            onSelectSession(session)
          } onRename: {
            renameTarget = .session(id: session.id, title: session.title)
          } onAddToProject: { project in
            store.addSession(session, to: project)
          } onDelete: {
            store.deleteSession(session)
          }
        }
      }
    }
  }

  private func sessionSubtitle(for session: NativeChatSession) -> String {
    let text = session.messages.reversed().first { message in
      !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }?.text ?? session.updatedAt.formatted(date: .abbreviated, time: .shortened)
    return clipped(text)
  }

  private func clipped(_ text: String) -> String {
    let cleaned = text
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return store.i18n.t(.projectNewConversation)
    }
    return cleaned.count > 48 ? "\(cleaned.prefix(48))..." : cleaned
  }
}
