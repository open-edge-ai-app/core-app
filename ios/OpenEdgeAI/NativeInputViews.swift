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
                placeholder: store.i18n.t(.chatInputPlaceholder),
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

              Button {
                if showsStopButton {
                  store.cancelGeneration()
                } else {
                  store.sendCurrentInput()
                }
                } label: {
                  NativeComposerSubmitIcon(
                    systemName: submitSystemImage
                  )
                  .environmentObject(store)
              }
              .buttonStyle(.plain)
              .disabled(!showsStopButton && !hasDraftInput)
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

struct NativeComposerSubmitIcon: View {
  @EnvironmentObject private var store: NativeChatStore
  var systemName: String

  var body: some View {
    NativeComposerCircleSurface(
      isActive: true,
      accentColor: store.accentColor.color
    ) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(store.accentColor.foregroundColor)
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
