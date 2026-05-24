import SwiftUI

struct NativeChatComposerBar: View {
  @EnvironmentObject private var store: NativeChatStore
  var project: NativeProject?
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

  private var placeholder: String {
    if let project {
      return store.i18n.t(.projectMessagePlaceholder, ["name": project.title])
    }
    return store.i18n.t(.chatInputPlaceholder)
  }

  var body: some View {
    NativeGlassEffectContainer(spacing: 8) {
      VStack(spacing: 8) {
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
          VStack(alignment: .leading, spacing: 8) {
            if isSearchMode || !store.pendingAttachments.isEmpty {
              NativePendingAttachmentStrip(showsSearchMode: isSearchMode)
                .environmentObject(store)
            }

            HStack(alignment: .center, spacing: 8) {
              attachButton
              promptEditor
              microphoneIcon
              submitButton
            }
          }
          .padding(.leading, 12)
          .padding(.trailing, 8)
          .padding(.vertical, 8)
        }
        .layoutPriority(1)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 18)
    .padding(.bottom, 14)
    .frame(maxWidth: .infinity)
    .animation(.easeOut(duration: 0.18), value: showsSlashCommands)
    .animation(.easeOut(duration: 0.18), value: isSearchMode)
    .animation(.easeOut(duration: 0.14), value: hasDraftInput)
  }

  private var attachButton: some View {
    Button {
      showingAttachmentOptions = true
    } label: {
      NativeComposerInlineIcon(systemName: "plus", size: 27)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(store.i18n.t(.chatAttachFile))
  }

  private var promptEditor: some View {
    NativePromptEditor(
      text: $store.inputText,
      placeholder: placeholder,
      focused: $focused
    )
    .environmentObject(store)
    .layoutPriority(1)
  }

  private var microphoneIcon: some View {
    NativeComposerInlineIcon(
      systemName: "mic.fill",
      color: .oeSecondaryText,
      size: 23
    )
    .accessibilityHidden(true)
  }

  private var submitButton: some View {
    Button(action: submit) {
      NativeComposerSubmitIcon(systemName: submitSystemImage)
        .environmentObject(store)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(showsStopButton ? store.i18n.t(.chatStopResponse) : store.i18n.t(.chatSendMessage))
  }

  private var submitSystemImage: String {
    if showsStopButton {
      return "stop.fill"
    }
    return hasDraftInput ? "arrow.up" : "waveform"
  }

  private func submit() {
    if showsStopButton {
      store.cancelGeneration()
      return
    }
    guard hasDraftInput else {
      return
    }
    if let project {
      store.sendCurrentInput(projectId: project.id)
    } else {
      store.sendCurrentInput()
    }
  }

  private func performSlashCommand(_ command: NativeSlashCommand) {
    if command == .search {
      store.inputText = "\(command.trigger) "
      focused = true
    }
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
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(store.accentColor.foregroundColor)
        .frame(width: nativeComposerSubmitControlSize, height: nativeComposerSubmitControlSize)
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
