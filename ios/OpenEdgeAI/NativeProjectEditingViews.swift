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
