import SwiftUI

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

      if showsSlashCommands {
        NativeSlashCommandMenu(commands: slashCommands, onSelect: performSlashCommand)
          .environmentObject(store)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      VStack(alignment: .leading, spacing: 6) {
        if isSearchMode || !store.pendingAttachments.isEmpty {
          NativePendingAttachmentStrip(showsSearchMode: isSearchMode)
            .environmentObject(store)
            .padding(.top, 2)
        }

        HStack(alignment: .bottom, spacing: 8) {
          Button {
            showingAttachmentOptions = true
          } label: {
            NativeComposerCircleButtonIcon(systemName: "plus")
          }
          .buttonStyle(.plain)
          .accessibilityLabel(store.i18n.t(.chatAttachFile))

          NativePromptEditor(
            text: $store.inputText,
            placeholder: store.i18n.t(.projectMessagePlaceholder, ["name": project.title]),
            focused: $focused
          )
          .environmentObject(store)
          .layoutPriority(1)

          Button(action: send) {
            NativeComposerSubmitIcon(
              systemName: showsStopButton ? "stop.fill" : "arrow.up",
              isActive: submitButtonIsActive
            )
            .environmentObject(store)
          }
          .buttonStyle(.plain)
          .disabled(!showsStopButton && !hasDraftInput)
          .accessibilityLabel(showsStopButton ? store.i18n.t(.chatStopResponse) : store.i18n.t(.chatSendMessage))
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(Color.oeElevatedSurface)
      .overlay(
        RoundedRectangle(cornerRadius: nativePromptInputCornerRadius, style: .continuous)
          .stroke(Color.oeBorder.opacity(focused ? 1 : 0.75), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: nativePromptInputCornerRadius, style: .continuous))
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
