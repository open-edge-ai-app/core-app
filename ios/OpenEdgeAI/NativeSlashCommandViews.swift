import SwiftUI

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
              .nativeLiquidGlassCircle(
                tint: store.accentColor.color.opacity(0.72),
                interactive: true
              )

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
    .nativeLiquidGlass(cornerRadius: 16)
    .nativeGlassStroke(cornerRadius: 16)
  }
}

struct NativeSearchModeChip: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    NativeComposerChipSurface(accentColor: store.accentColor.color) {
      HStack(spacing: 5) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11, weight: .bold))

        Text(store.i18n.t(.chatSearchMode))
          .font(.system(size: 12, weight: .semibold))
      }
      .foregroundColor(store.accentColor.color)
      .padding(.horizontal, 9)
      .frame(height: 28)
    }
    .accessibilityLabel(store.i18n.t(.chatSearchMode))
  }
}
