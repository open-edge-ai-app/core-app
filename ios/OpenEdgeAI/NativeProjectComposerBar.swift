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
    NativeGlassEffectContainer(spacing: 8) {
      VStack(spacing: 7) {
        if !store.queuedDrafts.isEmpty {
          NativeQueueView()
        }

        if showsSlashCommands {
          NativeSlashCommandMenu(commands: slashCommands, onSelect: performSlashCommand)
            .environmentObject(store)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        HStack(alignment: .bottom, spacing: 9) {
          Button {
            showingAttachmentOptions = true
          } label: {
            NativeComposerCircleButtonIcon(systemName: "plus")
          }
          .buttonStyle(.plain)
          .accessibilityLabel(store.i18n.t(.chatAttachFile))

          VStack(alignment: .leading, spacing: 7) {
            if isSearchMode || !store.pendingAttachments.isEmpty {
              NativePendingAttachmentStrip(showsSearchMode: isSearchMode)
                .environmentObject(store)
                .padding(.top, 2)
            }

            HStack(alignment: .bottom, spacing: 8) {
              NativePromptEditor(
                text: $store.inputText,
                placeholder: store.i18n.t(.projectMessagePlaceholder, ["name": project.title]),
                focused: $focused
              )
              .environmentObject(store)
              .padding(.leading, 8)
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
          .padding(.leading, 10)
          .padding(.trailing, 8)
          .padding(.vertical, 7)
          .nativePromptGlassPanel(
            cornerRadius: nativePromptInputCornerRadius,
            fill: Color.oeSubtleFill.opacity(0.28),
            borderColor: focused ? store.accentColor.color.opacity(0.72) : Color.oeBorder.opacity(0.4),
            accentColor: focused ? store.accentColor.color : nil,
            interactive: true
          )
          .layoutPriority(1)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 18)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity)
    .background(alignment: .bottom) {
      NativePromptBlurBackdrop()
        .frame(height: 140)
        .ignoresSafeArea(edges: .bottom)
    }
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
