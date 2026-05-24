import SwiftUI

struct NativeSearchResult: Identifiable {
  enum Kind {
    case session(NativeChatSession)
    case project(NativeProject)
  }

  var id: String
  var title: String
  var subtitle: String
  var systemImage: String
  var kind: Kind
}

struct NativeSearchView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  var onSelectSession: (NativeChatSession) -> Void
  var onSelectProject: (NativeProject) -> Void
  @State private var query = ""
  @FocusState private var isSearchFocused: Bool

  private var normalizedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var searchResults: [NativeSearchResult] {
    let query = normalizedQuery
    guard !query.isEmpty else {
      return []
    }

    let projectResults = store.projects
      .sorted { $0.createdAt > $1.createdAt }
      .filter { project in
        project.title.localizedCaseInsensitiveContains(query)
          || project.systemPrompt.localizedCaseInsensitiveContains(query)
      }
      .map { project in
        NativeSearchResult(
          id: "project-\(project.id)",
          title: project.title,
          subtitle: project.systemPrompt.isEmpty ? store.i18n.t(.menuProjects) : clipped(project.systemPrompt),
          systemImage: project.iconName,
          kind: .project(project)
        )
      }

    let sessionResults = store.sessions
      .sorted { $0.updatedAt > $1.updatedAt }
      .filter { store.shouldShowSession($0) }
      .filter { session in
        session.title.localizedCaseInsensitiveContains(query)
          || session.messages.contains { message in
            message.text.localizedCaseInsensitiveContains(query)
              || message.attachments.contains { attachment in
                attachment.name.localizedCaseInsensitiveContains(query)
              }
          }
      }
      .map { session in
        let matchingMessage = session.messages.first { message in
          message.text.localizedCaseInsensitiveContains(query)
            || message.attachments.contains { attachment in
              attachment.name.localizedCaseInsensitiveContains(query)
            }
        }
        return NativeSearchResult(
          id: "session-\(session.id)",
          title: session.title,
          subtitle: clipped(matchingMessage?.text ?? session.updatedAt.formatted(date: .abbreviated, time: .shortened)),
          systemImage: "bubble.left.and.bubble.right",
          kind: .session(session)
        )
      }

    return projectResults + sessionResults
  }

  private var recentSessions: [NativeChatSession] {
    Array(
      store.sessions
        .filter { store.shouldShowSession($0) }
        .sorted { $0.updatedAt > $1.updatedAt }
        .prefix(8)
    )
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.oeSecondaryText)

          TextField(store.i18n.t(.searchTitle), text: $query)
            .focused($isSearchFocused)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.oeText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.oeText.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.i18n.t(.searchClearQuery))
          }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .nativeLiquidGlass(cornerRadius: 16, interactive: true)
        .nativeGlassStroke(cornerRadius: 16, color: Color.oeBorder.opacity(0.32))
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 24) {
            if normalizedQuery.isEmpty {
              NativeSearchSection(title: store.i18n.t(.searchRecentChats)) {
                if recentSessions.isEmpty {
                  NativeSearchEmptyState(text: store.i18n.t(.menuNoRecentChats))
                } else {
                  ForEach(recentSessions) { session in
                    NativeSearchSessionButton(session: session, subtitle: session.updatedAt.formatted(date: .abbreviated, time: .shortened)) {
                      select(session)
                    }
                  }
                }
              }
            } else if searchResults.isEmpty {
              NativeSearchEmptyState(text: store.i18n.t(.searchNoResults))
                .padding(.top, 80)
            } else {
              NativeSearchSection(title: store.i18n.t(.searchResults)) {
                ForEach(searchResults) { result in
                  NativeSearchResultRow(result: result) {
                    switch result.kind {
                    case .session(let session):
                      select(session)
                    case .project(let project):
                      select(project)
                    }
                  }
                }
              }
            }
          }
          .padding(.horizontal, 22)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
      }
      .background(Color.oeBackground)
      .navigationTitle(store.i18n.t(.searchTitle))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(store.i18n.t(.commonClose)) {
            dismiss()
          }
          .foregroundColor(.oeText)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          isSearchFocused = true
        }
      }
    }
  }

  private func select(_ session: NativeChatSession) {
    dismiss()
    onSelectSession(session)
  }

  private func select(_ project: NativeProject) {
    dismiss()
    onSelectProject(project)
  }

  private func clipped(_ text: String) -> String {
    let cleaned = text
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return store.i18n.t(.searchConversationFallback)
    }
    return cleaned.count > 92 ? "\(cleaned.prefix(92))..." : cleaned
  }
}

struct NativeSearchSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.oeSecondaryText)

      VStack(alignment: .leading, spacing: 12) {
        content
      }
    }
  }
}

struct NativeSearchSessionButton: View {
  var session: NativeChatSession
  var subtitle: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      NativeSearchRowContent(
        systemImage: "bubble.left.and.bubble.right",
        title: session.title,
        subtitle: subtitle,
        showsChevron: true
      )
    }
    .buttonStyle(.plain)
  }
}

struct NativeSearchResultRow: View {
  var result: NativeSearchResult
  var action: () -> Void

  var body: some View {
    switch result.kind {
    case .session:
      Button(action: action) {
        NativeSearchRowContent(
          systemImage: result.systemImage,
          title: result.title,
          subtitle: result.subtitle,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)
    case .project:
      Button(action: action) {
        NativeSearchRowContent(
          systemImage: result.systemImage,
          title: result.title,
          subtitle: result.subtitle,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)
    }
  }
}

struct NativeSearchRowContent: View {
  var systemImage: String
  var title: String
  var subtitle: String
  var showsChevron: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeText)
          .lineLimit(1)

        Text(subtitle)
          .font(.system(size: 13, weight: .regular))
          .foregroundColor(.oeMutedText)
          .lineLimit(2)
      }

      Spacer(minLength: 8)

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.oeText.opacity(0.25))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .nativeLiquidGlass(cornerRadius: 16, interactive: true)
    .nativeGlassStroke(cornerRadius: 16, color: Color.oeBorder.opacity(0.26))
    .contentShape(Rectangle())
  }
}

struct NativeSearchEmptyState: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.system(size: 15, weight: .medium))
      .foregroundColor(.oeMutedText)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.vertical, 24)
  }
}
