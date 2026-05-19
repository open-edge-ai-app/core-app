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
        .accessibilityLabel(store.i18n.t(.chatAttachFile))

        VStack(alignment: .leading, spacing: 6) {
          if isSearchMode {
            NativeSearchModeChip()
              .environmentObject(store)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
          }

          NativePromptEditor(
            text: $store.inputText,
            placeholder: store.i18n.t(.projectMessagePlaceholder, ["name": project.title]),
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
        .accessibilityLabel(showsStopButton ? store.i18n.t(.chatStopResponse) : store.i18n.t(.chatSendMessage))
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
