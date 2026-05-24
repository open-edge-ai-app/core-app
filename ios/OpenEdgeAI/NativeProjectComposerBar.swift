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

        NativeComposerInputSurface(
          isFocused: focused,
          accentColor: store.accentColor.color
        ) {
          VStack(alignment: .leading, spacing: 7) {
            if isSearchMode || !store.pendingAttachments.isEmpty {
              NativePendingAttachmentStrip(showsSearchMode: isSearchMode)
                .environmentObject(store)
                .padding(.top, 2)
            }

            HStack(alignment: .bottom, spacing: 8) {
              Button {
                showingAttachmentOptions = true
              } label: {
                NativeComposerInlineIcon(systemName: "plus", size: 28)
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

              NativeComposerInlineIcon(
                systemName: "mic.fill",
                color: .oeSecondaryText,
                size: 22
              )
              .accessibilityHidden(true)

              Button(action: send) {
                NativeComposerSubmitIcon(
                  systemName: submitSystemImage
                )
                .environmentObject(store)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(showsStopButton ? store.i18n.t(.chatStopResponse) : store.i18n.t(.chatSendMessage))
            }
          }
          .padding(.leading, 14)
          .padding(.trailing, 7)
          .padding(.vertical, 7)
        }
        .layoutPriority(1)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 18)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity)
    .background(alignment: .bottom) {
      NativeFloatingComposerBackdrop()
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

  private var submitSystemImage: String {
    if showsStopButton {
      return "stop.fill"
    }
    return hasDraftInput ? "arrow.up" : "waveform"
  }
}
