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
      .background(Color(red: 0.956, green: 0.958, blue: 0.965))
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
        subtitle: i18n.t(.todoHideCompletedTasksDescription),
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
        subtitle: i18n.t(.todoShowLabelsOnTasksDescription),
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
          .foregroundColor(.black.opacity(0.54))
          .frame(width: 28, height: 28)
          .background(Color.black.opacity(0.055))
          .clipShape(Circle())

        TextField(i18n.t(.todoNewLabelName), text: $newLabelTitle)
          .font(.system(size: 15, weight: .semibold))
          .textInputAutocapitalization(.words)
          .submitLabel(.done)
          .onSubmit(addLabel)

        Button(action: addLabel) {
          Text(i18n.t(.todoAddLabel))
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(canAddLabel ? .white : Color.black.opacity(0.34))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(canAddLabel ? Color.black : Color.black.opacity(0.06))
            .clipShape(Capsule())
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
              .foregroundColor(.black)

            NativeTodoSettingsStatusPill(
              title: store.todoCalendarAuthorizationState.localizedTitle(i18n),
              isActive: canSync
            )
          }

          Text(i18n.t(.todoCalendarIntegrationDescription))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.black.opacity(0.46))
            .lineLimit(3)
            .lineSpacing(2)
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

      NativeTodoSettingsDivider()

      HStack(spacing: 10) {
        if !canSync {
          NativeTodoSettingsActionButton(
            title: i18n.t(.todoAllowPermission),
            isPrimary: true,
            isEnabled: true
          ) {
            store.requestTodoCalendarAccess()
          }
        }

        NativeTodoSettingsActionButton(
          title: i18n.t(.todoSyncNow),
          isPrimary: false,
          isEnabled: canSync
        ) {
          store.syncTodoItemsToCalendar()
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)

      if let message = store.todoCalendarSyncMessage {
        NativeTodoSettingsDivider()
        Text(message)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(Color.black.opacity(0.45))
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
        .foregroundColor(.black)

      Text(i18n.t(.todoSettingsSubtitle))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(Color.black.opacity(0.48))
        .lineSpacing(3)
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
          .foregroundColor(Color.black.opacity(0.42))
          .textCase(.uppercase)

        Spacer()

        if let trailingText {
          Text(trailingText)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color.black.opacity(0.34))
        }
      }
      .padding(.horizontal, 4)

      VStack(spacing: 0) {
        content
      }
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(Color.black.opacity(0.045), lineWidth: 1)
      )
    }
  }
}

private struct NativeTodoSettingsToggleRow: View {
  var icon: String
  var title: String
  var subtitle: String
  @Binding var isOn: Bool
  var accentColor: Color

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      NativeTodoSettingsIcon(systemName: icon)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.black)

        Text(subtitle)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(Color.black.opacity(0.44))
          .lineLimit(2)
      }

      Spacer(minLength: 12)

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(accentColor)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 13)
  }
}

private struct NativeTodoSettingsIcon: View {
  var systemName: String

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 15, weight: .semibold))
      .foregroundColor(.black)
      .frame(width: 34, height: 34)
      .background(Color.black.opacity(0.055))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

private struct NativeTodoSettingsDivider: View {
  var body: some View {
    Divider()
      .background(Color.black.opacity(0.05))
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
        .foregroundColor(Color.black.opacity(0.46))

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
      .foregroundColor(isActive ? .white : Color.black.opacity(0.52))
      .padding(.horizontal, 8)
      .frame(height: 20)
      .background(isActive ? Color.black : Color.black.opacity(0.07))
      .clipShape(Capsule())
  }
}

private struct NativeTodoSettingsActionButton: View {
  var title: String
  var isPrimary: Bool
  var isEnabled: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(foregroundColor)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }

  private var foregroundColor: Color {
    if isPrimary {
      return .white
    }
    return isEnabled ? .black : Color.black.opacity(0.32)
  }

  private var backgroundColor: Color {
    if isPrimary {
      return .black
    }
    return Color.black.opacity(isEnabled ? 0.06 : 0.035)
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
        .foregroundColor(.black)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(Color.black.opacity(0.28))
          .frame(width: 30, height: 30)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoDeleteLabel, ["name": label.title]))
    }
    .padding(.horizontal, 14)
    .frame(height: 50)
  }
}
