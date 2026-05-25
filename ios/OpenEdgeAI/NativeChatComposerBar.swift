import SwiftUI

struct NativeChatComposerBar: View {
  @EnvironmentObject private var store: NativeChatStore
  var project: NativeProject?
  @Binding var showingAttachmentOptions: Bool
  var onPickPhotoOrVideo: () -> Void
  var onPickFile: () -> Void
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

        HStack(alignment: .center, spacing: 7) {
          attachButton

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
                promptEditor
                submitButton
              }
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
          }
          .layoutPriority(1)
        }
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
      withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
        showingAttachmentOptions.toggle()
      }
    } label: {
      NativeComposerCircleSurface(
        isActive: false,
        accentColor: store.accentColor.color
      ) {
        Image(systemName: "plus")
          .font(.system(size: 22, weight: .medium))
          .foregroundColor(.oeText)
          .frame(width: nativeComposerAttachControlSize, height: nativeComposerAttachControlSize)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(store.i18n.t(.chatAttachFile))
    .overlay(alignment: .bottomLeading) {
      if showingAttachmentOptions {
        NativeAttachmentOptionsMenu(
          onPickPhotoOrVideo: selectPhotoOrVideo,
          onPickFile: selectFile
        )
        .environmentObject(store)
        .offset(y: -(nativeComposerAttachControlSize + 10))
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .zIndex(showingAttachmentOptions ? 3 : 0)
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
    return "arrow.up"
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

  private func selectPhotoOrVideo() {
    closeAttachmentMenu()
    onPickPhotoOrVideo()
  }

  private func selectFile() {
    closeAttachmentMenu()
    onPickFile()
  }

  private func closeAttachmentMenu() {
    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
      showingAttachmentOptions = false
    }
  }
}

private struct NativeAttachmentOptionsMenu: View {
  @EnvironmentObject private var store: NativeChatStore
  var onPickPhotoOrVideo: () -> Void
  var onPickFile: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      menuButton(
        title: store.i18n.t(.attachmentPhotoOrVideo),
        systemImage: "photo.on.rectangle",
        action: onPickPhotoOrVideo
      )

      Divider()
        .overlay(Color.oeBorder.opacity(0.18))
        .padding(.leading, 42)

      menuButton(
        title: store.i18n.t(.attachmentFile),
        systemImage: "doc",
        action: onPickFile
      )
    }
    .padding(.vertical, 6)
    .frame(width: 190, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.white.opacity(0.12))
        .allowsHitTesting(false)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.oeBorder.opacity(0.24), lineWidth: 1)
        .allowsHitTesting(false)
    }
    .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 8)
  }

  private func menuButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 18)

        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(1)
      }
      .foregroundColor(.oeText)
      .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
      .padding(.horizontal, 14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
