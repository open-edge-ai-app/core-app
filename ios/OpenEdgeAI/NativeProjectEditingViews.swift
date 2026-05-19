import SwiftUI

struct NativeRenameSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  let target: NativeRenameTarget
  @State private var title: String
  @State private var selectedIconName: String
  @State private var systemPrompt: String
  @FocusState private var isFocused: Bool

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  init(target: NativeRenameTarget) {
    self.target = target
    _title = State(initialValue: target.title)
    if case .project(let project) = target {
      _selectedIconName = State(initialValue: project.iconName)
      _systemPrompt = State(initialValue: project.systemPrompt)
    } else {
      _selectedIconName = State(initialValue: NativeProjectIcon.defaultIcon.systemImage)
      _systemPrompt = State(initialValue: "")
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 24) {
          NativeProjectCreatorSection(title: target.localizedFieldTitle(store.i18n)) {
            TextField(target.localizedPlaceholder(store.i18n), text: $title)
              .focused($isFocused)
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(.oeText)
              .textInputAutocapitalization(.sentences)
              .padding(.horizontal, 16)
              .frame(height: 54)
              .background(Color.oeSubtleFill)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }

          if target.isProject {
            NativeProjectCreatorSection(title: store.i18n.t(.projectIcon)) {
              LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                alignment: .leading,
                spacing: 10
              ) {
                ForEach(NativeProjectIcon.all) { icon in
                  NativeProjectIconOption(
                    icon: icon,
                    isSelected: selectedIconName == icon.systemImage,
                    accentColor: store.accentColor
                  ) {
                    selectedIconName = icon.systemImage
                  }
                }
              }
            }

            NativeProjectCreatorSection(title: store.i18n.t(.projectSystemPrompt)) {
              ZStack(alignment: .topLeading) {
                TextEditor(text: $systemPrompt)
                  .font(.system(size: 16, weight: .regular))
                  .foregroundColor(.oeText)
                  .scrollContentBackground(.hidden)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 10)
                  .frame(minHeight: 168)

                if systemPrompt.isEmpty {
                  Text(store.i18n.t(.projectInstructionPlaceholder))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.oeText.opacity(0.35))
                    .padding(.horizontal, 17)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
                }
              }
              .background(Color.oeSubtleFill)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 34)
      }
      .background(Color.oeBackground)
      .navigationTitle(target.localizedNavigationTitle(store.i18n))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(store.i18n.t(.commonCancel)) {
            dismiss()
          }
          .foregroundColor(.oeText)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(store.i18n.t(.commonSave), action: save)
            .fontWeight(.semibold)
            .foregroundColor(canSave ? store.accentColor.color : Color.oeText.opacity(0.3))
            .disabled(!canSave)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          isFocused = true
        }
      }
    }
  }

  private func save() {
    guard canSave else {
      return
    }

    switch target {
    case .session(let id, _):
      store.renameSession(id: id, title: title)
    case .project(let project):
      store.updateProject(
        id: project.id,
        title: title,
        iconName: selectedIconName,
        systemPrompt: systemPrompt
      )
    }
    dismiss()
  }
}

struct NativeProjectCreatorView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore
  @State private var projectTitle = ""
  @State private var selectedIconName = NativeProjectIcon.defaultIcon.systemImage
  @State private var systemPrompt = ""
  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case title
    case systemPrompt
  }

  private var canCreate: Bool {
    !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 26) {
          NativeProjectCreatorSection(title: store.i18n.t(.projectName)) {
            TextField(store.i18n.t(.renameProjectPlaceholder), text: $projectTitle)
              .focused($focusedField, equals: .title)
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(.oeText)
              .textInputAutocapitalization(.words)
              .padding(.horizontal, 16)
              .frame(height: 54)
              .background(Color.oeSubtleFill)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }

          NativeProjectCreatorSection(title: store.i18n.t(.projectIcon)) {
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
              alignment: .leading,
              spacing: 10
            ) {
              ForEach(NativeProjectIcon.all) { icon in
                NativeProjectIconOption(
                  icon: icon,
                  isSelected: selectedIconName == icon.systemImage,
                  accentColor: store.accentColor
                ) {
                  selectedIconName = icon.systemImage
                }
              }
            }
          }

          NativeProjectCreatorSection(title: store.i18n.t(.projectSystemPrompt)) {
            ZStack(alignment: .topLeading) {
              TextEditor(text: $systemPrompt)
                .focused($focusedField, equals: .systemPrompt)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.oeText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 168)

              if systemPrompt.isEmpty {
                Text(store.i18n.t(.projectInstructionPlaceholder))
                  .font(.system(size: 16, weight: .regular))
                  .foregroundColor(.oeText.opacity(0.35))
                  .padding(.horizontal, 17)
                  .padding(.vertical, 18)
                  .allowsHitTesting(false)
              }
            }
            .background(Color.oeSubtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 34)
      }
      .background(Color.oeBackground)
      .navigationTitle(store.i18n.t(.projectNew))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(store.i18n.t(.commonCancel)) {
            dismiss()
          }
          .foregroundColor(.oeText)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(store.i18n.t(.projectCreate), action: createProject)
            .fontWeight(.semibold)
            .foregroundColor(canCreate ? store.accentColor.color : Color.oeText.opacity(0.3))
            .disabled(!canCreate)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          focusedField = .title
        }
      }
    }
  }

  private func createProject() {
    guard canCreate else {
      return
    }
    store.createProject(
      title: projectTitle,
      iconName: selectedIconName,
      systemPrompt: systemPrompt
    )
    dismiss()
  }
}

struct NativeProjectCreatorSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.oeSecondaryText)

      content
    }
  }
}

struct NativeProjectIconOption: View {
  var icon: NativeProjectIcon
  var isSelected: Bool
  var accentColor: NativeAccentColor
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon.systemImage)
          .font(.system(size: 19, weight: .semibold))
        Text(icon.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
      }
      .foregroundColor(isSelected ? accentColor.foregroundColor : .oeText)
      .frame(maxWidth: .infinity)
      .frame(height: 78)
      .background(isSelected ? accentColor.color : Color.oeSubtleFill)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(isSelected ? accentColor.color : Color.oeBorder, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

struct NativeSessionsSearchPill: View {
  @EnvironmentObject private var store: NativeChatStore
  var onSearchPress: () -> Void
  var onSettingsPress: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: onSearchPress) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 21, weight: .semibold))
          .foregroundColor(store.accentColor.color)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.i18n.t(.searchTitle))

      Button(action: onSettingsPress) {
        Image(systemName: "gearshape")
          .font(.system(size: 19, weight: .semibold))
          .foregroundColor(store.accentColor.color)
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.i18n.t(.commonOpenSettings))
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .frame(height: 52)
    .background(Color.oeSurface)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 12)
  }
}

struct NativeSessionsSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.oeText)

      VStack(alignment: .leading, spacing: 20) {
        content
      }
    }
  }
}

struct NativeSessionsIconRow: View {
  var systemImage: String
  var title: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
        .frame(width: 26, height: 22)

      Text(title)
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.oeText)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}
