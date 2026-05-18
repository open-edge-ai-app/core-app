import SwiftUI

enum NativeProjectPageTab {
  case chats
  case sources
}

struct NativeProjectSessionsPage: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  var project: NativeProject
  @Binding var showingAttachmentOptions: Bool
  var onSelectSession: (NativeChatSession) -> Void
  @State private var selectedTab: NativeProjectPageTab = .chats
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
            tabBar
              .padding(.bottom, 28)

            if selectedTab == .chats {
              chatList
            } else {
              sourcesPlaceholder
            }
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
      .accessibilityLabel("프로젝트 목록")

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
        store.copy(currentProject.title)
      } label: {
        Image(systemName: "square.and.arrow.up")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("프로젝트 공유")

      Button {
        renameTarget = .project(currentProject)
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 22, weight: .bold))
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("프로젝트 설정")
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(Color.oeBackground)
  }

  private var tabBar: some View {
    HStack(spacing: 12) {
      projectTabButton("채팅", tab: .chats)
      projectTabButton("출처", tab: .sources)
      Spacer()
    }
  }

  private func projectTabButton(_ title: String, tab: NativeProjectPageTab) -> some View {
    Button {
      selectedTab = tab
    } label: {
      Text(title)
        .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
        .foregroundColor(selectedTab == tab ? .oeText : .oeMutedText)
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(selectedTab == tab ? Color.oeSubtleFill : Color.clear)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private var chatList: some View {
    VStack(alignment: .leading, spacing: 20) {
      if projectSessions.isEmpty {
        Text("프로젝트에 채팅이 없습니다")
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

  private var sourcesPlaceholder: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("출처가 없습니다")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.oeText)

      Text("첨부 파일이나 참조 자료를 추가하면 여기에 표시됩니다.")
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(.oeMutedText)
    }
    .padding(.top, 6)
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
      return "새 대화"
    }
    return cleaned.count > 48 ? "\(cleaned.prefix(48))..." : cleaned
  }
}

struct NativeProjectSessionRow: View {
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
            .accessibilityLabel("응답 생성 중")
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
        Label("이름 변경", systemImage: "pencil")
      }

      Menu {
        if availableProjects.isEmpty {
          Text("추가할 프로젝트 없음")
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
        Label("프로젝트에 추가", systemImage: "folder.badge.plus")
      }

      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("삭제", systemImage: "trash")
      }
    }
  }
}

struct NativeProjectComposerBar: View {
  @EnvironmentObject private var store: NativeChatStore
  var project: NativeProject
  @Binding var showingAttachmentOptions: Bool
  @FocusState private var focused: Bool

  private var slashCommands: [NativeSlashCommand] {
    NativeSlashCommand.matching(in: store.inputText)
  }

  private var showsSlashCommands: Bool {
    focused && !slashCommands.isEmpty
  }

  private var isSearchMode: Bool {
    NativeSlashCommand.searchPayload(in: store.inputText) != nil
  }

  private var hasDraftInput: Bool {
    !store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.pendingAttachments.isEmpty
  }

  private var showsStopButton: Bool {
    store.isGenerating && !hasDraftInput
  }

  private var submitButtonIsActive: Bool {
    showsStopButton || hasDraftInput
  }

  var body: some View {
    VStack(spacing: 7) {
      if !store.queuedDrafts.isEmpty {
        NativeQueueView()
      }

      if !store.pendingAttachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(store.pendingAttachments) { attachment in
              HStack(spacing: 6) {
                Text(attachment.name)
                  .lineLimit(1)
                Button {
                  store.removePendingAttachment(attachment)
                } label: {
                  Image(systemName: "xmark")
                }
              }
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(store.accentColor.color)
              .padding(.horizontal, 10)
              .padding(.vertical, 7)
              .background(store.accentColor.subtleColor)
              .clipShape(Capsule())
            }
          }
        }
      }

      if showsSlashCommands {
        NativeSlashCommandMenu(commands: slashCommands, onSelect: performSlashCommand)
          .environmentObject(store)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      HStack(alignment: .bottom, spacing: 8) {
        Button {
          showingAttachmentOptions = true
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.oeText)
            .frame(width: 34, height: 34)
            .background(Color.oeSubtleFill)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("파일 첨부")

        VStack(alignment: .leading, spacing: 6) {
          if isSearchMode {
            NativeSearchModeChip()
              .environmentObject(store)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
          }

          NativePromptEditor(
            text: $store.inputText,
            placeholder: "\(project.title)에 메시지...",
            focused: $focused
          )
          .environmentObject(store)
        }

        Button(action: send) {
          Image(systemName: showsStopButton ? "stop.fill" : "arrow.up")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(submitButtonIsActive ? store.accentColor.foregroundColor : .oeMutedText)
            .frame(width: 34, height: 34)
            .background(submitButtonIsActive ? store.accentColor.color : Color.oeSubtleFill)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!showsStopButton && !hasDraftInput)
        .accessibilityLabel(showsStopButton ? "응답 중지" : "메시지 보내기")
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(Color.oeElevatedSurface)
      .overlay(
        Capsule(style: .continuous)
          .stroke(Color.oeBorder.opacity(focused ? 1 : 0.75), lineWidth: 1)
      )
      .clipShape(Capsule(style: .continuous))
    }
    .padding(.horizontal, 12)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(.regularMaterial)
    .animation(.easeOut(duration: 0.18), value: showsSlashCommands)
    .animation(.easeOut(duration: 0.18), value: isSearchMode)
    .animation(.easeOut(duration: 0.14), value: hasDraftInput)
  }

  private func send() {
    if showsStopButton {
      store.cancelGeneration()
      return
    }
    guard hasDraftInput else {
      return
    }
    store.sendCurrentInput(projectId: project.id)
  }

  private func performSlashCommand(_ command: NativeSlashCommand) {
    if command == .search {
      store.inputText = "\(command.trigger) "
      focused = true
    }
  }
}

struct NativeSessionListRow: View {
  var title: String
  var isWriting = false

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
        .font(.system(size: 16, weight: .regular))
        .foregroundColor(.oeText)
        .lineLimit(1)

      Spacer(minLength: 10)

      if isWriting {
        ProgressView()
          .controlSize(.small)
          .tint(.oeMutedText)
          .frame(width: 18, height: 18)
          .accessibilityLabel("응답 생성 중")
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}
