import SwiftUI

struct NativeInputBar: View {
  @EnvironmentObject private var store: NativeChatStore
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
                NativePromptEditor(
                  text: $store.inputText,
                  placeholder: store.i18n.t(.chatInputPlaceholder),
                  focused: $focused
                )
                .environmentObject(store)
                .padding(.leading, 8)
                .layoutPriority(1)

                Button {
                  if showsStopButton {
                    store.cancelGeneration()
                  } else {
                    store.sendCurrentInput()
                  }
                } label: {
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
          }
          .layoutPriority(1)
        }
      }
    }
    .padding(.horizontal, 12)
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

  private func performSlashCommand(_ command: NativeSlashCommand) {
    if command == .search {
      store.inputText = "\(command.trigger) "
      focused = true
    }
  }
}

struct NativeComposerCircleButtonIcon: View {
  @EnvironmentObject private var store: NativeChatStore
  var systemName: String

  var body: some View {
    NativeComposerCircleSurface(accentColor: store.accentColor.color) {
      Image(systemName: systemName)
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(.oeText)
        .frame(width: 34, height: 34)
    }
  }
}

struct NativeComposerSubmitIcon: View {
  @EnvironmentObject private var store: NativeChatStore
  var systemName: String
  var isActive: Bool

  var body: some View {
    NativeComposerCircleSurface(
      isActive: isActive,
      accentColor: store.accentColor.color
    ) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(isActive ? store.accentColor.foregroundColor : .oeMutedText)
        .frame(width: 34, height: 34)
    }
  }
}

struct NativePendingAttachmentStrip: View {
  @EnvironmentObject private var store: NativeChatStore
  var showsSearchMode: Bool = false

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        if showsSearchMode {
          NativeSearchModeChip()
            .environmentObject(store)
        }

        ForEach(store.pendingAttachments) { attachment in
          NativePendingAttachmentChip(attachment: attachment) {
            store.removePendingAttachment(attachment)
          }
        }
      }
      .padding(.horizontal, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct NativePendingAttachmentChip: View {
  var attachment: NativeAttachment
  var onRemove: () -> Void

  var body: some View {
    NativeComposerChipSurface {
      HStack(spacing: 6) {
        Image(systemName: iconName)
          .font(.system(size: 11, weight: .semibold))

        Text(verbatim: attachment.compactDisplayName)
          .lineLimit(1)

        Button(action: onRemove) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
      }
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(Color.oeText)
      .padding(.leading, 9)
      .padding(.trailing, 6)
      .frame(height: 29)
    }
    .accessibilityLabel(Text(verbatim: attachment.name))
  }

  private var iconName: String {
    switch attachment.type {
    case "image":
      return "photo"
    case "audio":
      return "waveform"
    case "video":
      return "film"
    default:
      return "doc"
    }
  }
}
