import SwiftUI

private enum NativeSessionsRoute: Hashable {
  case project(NativeProject)
  case todoList
}

struct NativeSessionsView: View {
  @Binding var isPresented: Bool
  @Binding var showingSettings: Bool
  @Binding var showingAttachmentOptions: Bool
  @EnvironmentObject private var store: NativeChatStore
  @State private var isSearchPresented = false
  @State private var isProjectCreatorPresented = false
  @State private var navigationPath: [NativeSessionsRoute] = []
  @State private var renameTarget: NativeRenameTarget?

  private var recentSessions: [NativeChatSession] {
    store.sessions
      .filter { $0.projectId == nil && store.shouldShowSession($0) }
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  @ViewBuilder
  private var sessionsContent: some View {
    VStack(alignment: .leading, spacing: 26) {
      rootSessionsContent
    }
  }

  @ViewBuilder
  private var rootSessionsContent: some View {
    Button {
      navigationPath = [.todoList]
    } label: {
      NativeSessionsIconRow(systemImage: "checklist", title: "Todo List")
    }
    .buttonStyle(.plain)

    NativeSessionsSection(title: "프로젝트") {
      Button {
        isProjectCreatorPresented = true
      } label: {
        NativeSessionsIconRow(systemImage: "folder.badge.plus", title: "새 프로젝트")
      }
      .buttonStyle(.plain)

      ForEach(store.projects) { project in
        Button {
          navigateToProject(project)
        } label: {
          NativeSessionsIconRow(systemImage: project.iconName, title: project.title)
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button {
            renameTarget = .project(project)
          } label: {
            Label("프로젝트 설정", systemImage: "slider.horizontal.3")
          }

          Button(role: .destructive) {
            store.deleteProject(project)
            navigationPath.removeAll { route in
              if case .project(let currentProject) = route {
                return currentProject.id == project.id
              }
              return false
            }
          } label: {
            Label("삭제", systemImage: "trash")
          }
        }
      }
    }

    NativeSessionsSection(title: "최근") {
      sessionList(recentSessions, emptyText: "최근 대화가 없습니다")
    }
  }

  @ViewBuilder
  private func sessionList(_ sessions: [NativeChatSession], emptyText: String) -> some View {
    if sessions.isEmpty {
      Text(emptyText)
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.oeMutedText)
        .padding(.vertical, 6)
    } else {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(sessions) { session in
          Button {
            store.selectSession(session)
            close()
          } label: {
            NativeSessionListRow(
              title: session.title,
              isWriting: store.activeWritingSessionId == session.id
            )
          }
          .buttonStyle(.plain)
          .contextMenu {
            sessionMenuItems(for: session)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func sessionMenuItems(for session: NativeChatSession) -> some View {
    Button {
      renameTarget = .session(id: session.id, title: session.title)
    } label: {
      Label("이름 변경", systemImage: "pencil")
    }

    Menu {
      let availableProjects = store.projects.filter { $0.id != session.projectId }
      if availableProjects.isEmpty {
        Text("추가할 프로젝트 없음")
      } else {
        ForEach(availableProjects) { project in
          Button {
            store.addSession(session, to: project)
          } label: {
            Label(project.title, systemImage: project.iconName)
          }
        }
      }
    } label: {
      Label("프로젝트에 추가", systemImage: "folder.badge.plus")
    }

    Button(role: .destructive) {
      store.deleteSession(session)
    } label: {
      Label("삭제", systemImage: "trash")
    }
  }

  var body: some View {
    NavigationStack(path: $navigationPath) {
      ZStack(alignment: .bottomTrailing) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .center, spacing: 16) {
            Image("OpenEdgeLogo")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .foregroundStyle(Color.oeText)
              .frame(width: 160, height: 40, alignment: .leading)
              .accessibilityLabel("Open Edge AI")

            Spacer(minLength: 12)

            NativeSessionsSearchPill(
              onSearchPress: openSearch,
              onSettingsPress: openSettings
            )
          }
          .padding(.horizontal, 30)
          .padding(.top, 22)
          .padding(.bottom, 28)

          ScrollView(showsIndicators: false) {
            sessionsContent
            .padding(.horizontal, 36)
            .padding(.bottom, 108)
          }

          Spacer(minLength: 0)
        }

        Button {
          store.createNewSession()
          close()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
              .font(.system(size: 17, weight: .semibold))
            Text("채팅")
              .font(.system(size: 15, weight: .bold))
          }
          .foregroundColor(store.accentColor.foregroundColor)
          .padding(.horizontal, 18)
          .frame(height: 48)
          .background(store.accentColor.color)
          .clipShape(Capsule())
          .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 채팅")
        .padding(.trailing, 26)
        .padding(.bottom, 26)
      }
      .background(Color.oeBackground)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationDestination(for: NativeSessionsRoute.self) { route in
        switch route {
        case .project(let project):
          NativeProjectSessionsPage(
            project: project,
            showingAttachmentOptions: $showingAttachmentOptions
          ) { session in
            store.selectSession(session)
            close()
          }
          .environmentObject(store)
        case .todoList:
          NativeTodoListView()
        }
      }
      .toolbar(.hidden, for: .navigationBar)
    }
    .sheet(isPresented: $isProjectCreatorPresented) {
      NativeProjectCreatorView()
        .environmentObject(store)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $isSearchPresented) {
      NativeSearchView { session in
        store.selectSession(session)
        close()
      } onSelectProject: { project in
        navigateToProject(project)
      }
      .environmentObject(store)
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .sheet(item: $renameTarget) { target in
      NativeRenameSheet(target: target)
        .environmentObject(store)
        .presentationDetents(target.isProject ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }
    .gesture(
      DragGesture(minimumDistance: 24)
        .onEnded { value in
          if value.translation.width < -70 {
            close()
          }
        }
    )
  }

  private func close() {
    withAnimation(.easeIn(duration: 0.2)) {
      isPresented = false
    }
  }

  private func openSettings() {
    showingSettings = true
  }

  private func openSearch() {
    isSearchPresented = true
  }

  private func navigateToProject(_ project: NativeProject) {
    navigationPath = [.project(project)]
  }
}

struct NativeTodoListView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "line.3.horizontal")
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("메뉴로 돌아가기")

        Text("Todo List")
          .font(.system(size: 15, weight: .semibold))
          .lineLimit(1)

        Spacer(minLength: 8)
      }
      .foregroundColor(.oeText)
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 8)
      .background(Color.oeBackground)

      Divider()

      VStack(alignment: .leading, spacing: 0) {
        Text("Todo List")
          .font(.system(size: 28, weight: .bold))
          .foregroundColor(.oeText)
          .padding(.horizontal, 24)
          .padding(.top, 28)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color.oeBackground)
    }
    .background(Color.oeBackground.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
}
