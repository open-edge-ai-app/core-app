import SwiftUI

struct NativeAttachmentRow: View {
  @EnvironmentObject private var store: NativeChatStore
  let attachments: [NativeAttachment]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(attachments) { attachment in
        HStack(spacing: 8) {
          Image(systemName: icon(for: attachment.type))
          Text(attachment.name)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
        }
        .foregroundColor(store.accentColor.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(store.accentColor.subtleColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
    }
  }

  private func icon(for type: String) -> String {
    switch type {
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

struct NativeSlashCommand: Identifiable, Equatable {
  let id: String
  let trigger: String
  let title: String
  let subtitle: String
  let systemImage: String

  static let search = NativeSlashCommand(
    id: "search",
    trigger: "/search",
    title: "검색 강화",
    subtitle: "현재 대화 기반으로 검색해서 답변 개선",
    systemImage: "magnifyingglass"
  )

  static let all = [search]

  func localizedTitle(_ i18n: NativeI18n) -> String {
    if self == Self.search {
      return i18n.t(.chatSlashSearchTitle)
    }
    return title
  }

  func localizedSubtitle(_ i18n: NativeI18n) -> String {
    if self == Self.search {
      return i18n.t(.chatSlashSearchSubtitle)
    }
    return subtitle
  }

  static func query(in inputText: String) -> String? {
    let leadingTrimmed = inputText.drop { $0.isWhitespace }
    guard leadingTrimmed.hasPrefix("/") else {
      return nil
    }

    let query = String(leadingTrimmed.dropFirst())
    guard !query.contains(where: \.isWhitespace) else {
      return nil
    }

    return query
  }

  static func matching(in inputText: String) -> [NativeSlashCommand] {
    guard let query = query(in: inputText) else {
      return []
    }

    guard !query.isEmpty else {
      return all
    }

    return all.filter { command in
      String(command.trigger.dropFirst()).localizedCaseInsensitiveContains(query)
        || command.title.localizedCaseInsensitiveContains(query)
    }
  }

  static func searchPayload(in inputText: String) -> String? {
    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercased = trimmed.lowercased()
    let trigger = search.trigger

    if lowercased == trigger {
      return ""
    }

    guard lowercased.hasPrefix("\(trigger) ") else {
      return nil
    }

    return String(trimmed.dropFirst(trigger.count))
  }
}

struct NativeSlashCommandMenu: View {
  @EnvironmentObject private var store: NativeChatStore
  let commands: [NativeSlashCommand]
  var onSelect: (NativeSlashCommand) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(commands) { command in
        Button {
          onSelect(command)
        } label: {
          HStack(spacing: 12) {
            Image(systemName: command.systemImage)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(store.accentColor.color)
              .frame(width: 28, height: 28)
              .background(store.accentColor.subtleColor)
              .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 8) {
                Text(command.trigger)
                  .font(.system(size: store.fontSizeSetting.bodySize - 1, weight: .semibold))
                  .foregroundColor(.oeText)

                Text(command.localizedTitle(store.i18n))
                  .font(.system(size: store.fontSizeSetting.bodySize - 2, weight: .medium))
                  .foregroundColor(.oeSecondaryText)
              }

              Text(command.localizedSubtitle(store.i18n))
                .font(.system(size: store.fontSizeSetting.bodySize - 4, weight: .regular))
                .foregroundColor(.oeMutedText)
                .lineLimit(1)
            }

            Spacer(minLength: 8)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(command.trigger) \(command.localizedTitle(store.i18n))")
      }
    }
    .padding(6)
    .background(Color.oeSurface)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Color.oeBorder, lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

struct NativeSearchModeChip: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 11, weight: .bold))

      Text(store.i18n.t(.chatSearchMode))
        .font(.system(size: 12, weight: .semibold))
    }
    .foregroundColor(store.accentColor.color)
    .padding(.horizontal, 9)
    .frame(height: 28)
    .background(store.accentColor.subtleColor)
    .clipShape(Capsule())
    .accessibilityLabel(store.i18n.t(.chatSearchMode))
  }
}

struct NativePromptEditor: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var text: String
  var placeholder: String
  var focused: FocusState<Bool>.Binding

  private var visibleLineCount: Int {
    min(max(1, text.components(separatedBy: .newlines).count), 3)
  }

  private var editorHeight: CGFloat {
    let lineHeight = max(20, store.fontSizeSetting.inputSize + 5)
    return CGFloat(visibleLineCount) * lineHeight + 16
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .font(.system(size: store.fontSizeSetting.inputSize))
        .foregroundColor(.oeText)
        .tint(store.accentColor.color)
        .focused(focused)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(height: editorHeight)
        .fixedSize(horizontal: false, vertical: false)

      if text.isEmpty {
        Text(placeholder)
          .font(.system(size: store.fontSizeSetting.inputSize))
          .foregroundColor(.oeText.opacity(0.35))
          .padding(.top, 8)
          .padding(.leading, 5)
          .allowsHitTesting(false)
      }
    }
  }
}

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
            placeholder: store.i18n.t(.chatInputPlaceholder),
            focused: $focused
          )
          .environmentObject(store)
        }

        Button {
          if showsStopButton {
            store.cancelGeneration()
          } else {
            store.sendCurrentInput()
          }
        } label: {
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

  private func performSlashCommand(_ command: NativeSlashCommand) {
    if command == .search {
      store.inputText = "\(command.trigger) "
      focused = true
    }
  }
}

struct NativeQueueView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    VStack(spacing: 6) {
      ForEach(store.queuedDrafts) { draft in
        HStack(spacing: 8) {
          TextField(store.i18n.t(.chatQueuedFollowUp), text: Binding(
            get: { draft.text },
            set: { store.updateQueuedDraft(draft, text: $0) }
          ))
          .font(.system(size: 13))

          Button {
            store.removeQueuedDraft(draft)
          } label: {
            Image(systemName: "xmark")
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(store.accentColor.subtleColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}
