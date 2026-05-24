import SwiftUI

struct NativeTodoSettingsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  @State private var newLabelTitle = ""

  private var canAddLabel: Bool {
    !newLabelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    let i18n = store.i18n

    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          NativeTodoSettingsHeader(i18n: i18n)
          displaySection
          labelSection
          calendarSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 34)
      }
      .background(Color.oeGroupedBackground)
      .navigationTitle(i18n.t(.todoSettings))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(i18n.t(.commonDone)) {
            dismiss()
          }
          .font(.system(size: 15, weight: .semibold))
        }
      }
      .onAppear {
        store.refreshTodoCalendarAuthorizationState()
      }
    }
  }

  private var displaySection: some View {
    let i18n = store.i18n

    return NativeTodoSettingsGroup(title: i18n.t(.todoDisplay)) {
      NativeTodoSettingsToggleRow(
        icon: "checkmark.circle",
        title: i18n.t(.todoHideCompletedTasks),
        isOn: Binding(
          get: { store.todoHideCompletedTasks },
          set: { store.setTodoHideCompletedTasks($0) }
        ),
        accentColor: store.accentColor.color
      )

      NativeTodoSettingsDivider()

      NativeTodoSettingsToggleRow(
        icon: "tag",
        title: i18n.t(.todoShowLabelsOnTasks),
        isOn: Binding(
          get: { store.todoTagsVisibleOnTaskCards },
          set: { store.setTodoTagsVisibleOnTaskCards($0) }
        ),
        accentColor: store.accentColor.color
      )
    }
  }

  private var labelSection: some View {
    let i18n = store.i18n

    return NativeTodoSettingsGroup(
      title: i18n.t(.todoLabels),
      trailingText: store.todoLabels.isEmpty ? nil : "\(store.todoLabels.count)"
    ) {
      HStack(spacing: 10) {
        Image(systemName: "plus")
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.oeSecondaryText)
          .frame(width: 28, height: 28)
          .nativeLiquidGlassCircle(interactive: true)

        TextField(i18n.t(.todoNewLabelName), text: $newLabelTitle)
          .font(.system(size: 15, weight: .semibold))
          .textInputAutocapitalization(.words)
          .submitLabel(.done)
          .onSubmit(addLabel)

        Button(action: addLabel) {
          Text(i18n.t(.todoAddLabel))
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(canAddLabel ? .oeControlText : .oeMutedText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .nativeLiquidGlassCapsule(
              tint: canAddLabel ? store.accentColor.color.opacity(0.48) : nil,
              interactive: true
            )
        }
        .buttonStyle(.plain)
        .disabled(!canAddLabel)
      }
      .padding(.horizontal, 14)
      .frame(height: 54)

      if store.todoLabels.isEmpty {
        NativeTodoSettingsDivider()
        NativeTodoSettingsEmptyRow(
          icon: "tag.slash",
          title: i18n.t(.todoNoLabels)
        )
      } else {
        NativeTodoSettingsDivider()
        LazyVStack(spacing: 0) {
          ForEach(store.todoLabels) { label in
            NativeTodoLabelRow(i18n: i18n, label: label) {
              withAnimation(.easeInOut(duration: 0.16)) {
                store.deleteTodoLabel(label)
              }
            }

            if label.id != store.todoLabels.last?.id {
              NativeTodoSettingsDivider()
            }
          }
        }
      }
    }
  }

  private var calendarSection: some View {
    let i18n = store.i18n
    let canSync = store.todoCalendarAuthorizationState.canSync

    return NativeTodoSettingsGroup(title: i18n.t(.todoIosCalendar)) {
      HStack(alignment: .center, spacing: 12) {
        NativeTodoSettingsIcon(systemName: "calendar")

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(i18n.t(.todoDefaultCalendarIntegration))
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.oeText)

            NativeTodoSettingsStatusPill(
              title: store.todoCalendarAuthorizationState.localizedTitle(i18n),
              isActive: canSync
            )
          }
        }

        Spacer(minLength: 10)

        Toggle("", isOn: Binding(
          get: { store.todoCalendarSyncEnabled },
          set: { store.setTodoCalendarSyncEnabled($0) }
        ))
        .labelsHidden()
        .tint(store.accentColor.color)
      }
      .padding(14)

      if let message = store.todoCalendarSyncMessage {
        NativeTodoSettingsDivider()
        Text(message)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.oeMutedText)
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
      }
    }
  }

  private func addLabel() {
    guard canAddLabel else {
      return
    }
    withAnimation(.easeInOut(duration: 0.16)) {
      store.createTodoLabel(title: newLabelTitle)
      newLabelTitle = ""
    }
  }
}

private struct NativeTodoSettingsHeader: View {
  var i18n: NativeI18n

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(i18n.t(.todoSettings))
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(.oeText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 4)
  }
}

private struct NativeTodoSettingsGroup<Content: View>: View {
  var title: String
  var trailingText: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text(title)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.oeMutedText)
          .textCase(.uppercase)

        Spacer()

        if let trailingText {
          Text(trailingText)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.oeMutedText)
        }
      }
      .padding(.horizontal, 4)

      VStack(spacing: 0) {
        content
      }
      .nativeLiquidGlass(cornerRadius: 20)
      .nativeGlassStroke(cornerRadius: 20)
    }
  }
}

private struct NativeTodoSettingsToggleRow: View {
  var icon: String
  var title: String
  @Binding var isOn: Bool
  var accentColor: Color

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      NativeTodoSettingsIcon(systemName: icon)

      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.oeText)

      Spacer(minLength: 12)

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(accentColor)
    }
    .padding(.horizontal, 14)
    .frame(height: 60)
  }
}

private struct NativeTodoSettingsIcon: View {
  var systemName: String

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 15, weight: .semibold))
      .foregroundColor(.oeText)
      .frame(width: 34, height: 34)
      .nativeLiquidGlass(cornerRadius: 10)
  }
}

private struct NativeTodoSettingsDivider: View {
  var body: some View {
    Divider()
      .background(Color.oeSeparator)
      .padding(.leading, 60)
  }
}

private struct NativeTodoSettingsEmptyRow: View {
  var icon: String
  var title: String

  var body: some View {
    HStack(spacing: 12) {
      NativeTodoSettingsIcon(systemName: icon)

      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.oeMutedText)

      Spacer()
    }
    .padding(.horizontal, 14)
    .frame(height: 54)
  }
}

private struct NativeTodoSettingsStatusPill: View {
  var title: String
  var isActive: Bool

  var body: some View {
    Text(title)
      .font(.system(size: 10, weight: .bold))
      .foregroundColor(isActive ? .oeControlText : .oeSecondaryText)
      .padding(.horizontal, 8)
      .frame(height: 20)
      .nativeLiquidGlassCapsule(
        tint: isActive ? Color.oeControlFill.opacity(0.38) : nil
      )
  }
}

struct NativeTodoLabelRow: View {
  var i18n: NativeI18n
  var label: NativeTodoLabel
  var onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color(todoLabelHex: label.colorHex))
        .frame(width: 12, height: 12)

      Text(label.title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.oeText)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.oeMutedText)
          .frame(width: 30, height: 30)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoDeleteLabel, ["name": label.title]))
    }
    .padding(.horizontal, 14)
    .frame(height: 50)
  }
}
