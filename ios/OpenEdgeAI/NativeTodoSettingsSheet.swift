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
        VStack(alignment: .leading, spacing: 22) {
          displaySection
          labelSection
          calendarSection
        }
        .padding(22)
      }
      .background(Color.white)
      .navigationTitle(i18n.t(.todoSettings))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(i18n.t(.commonDone)) {
            dismiss()
          }
        }
      }
      .onAppear {
        store.refreshTodoCalendarAuthorizationState()
      }
    }
  }

  private var displaySection: some View {
    let i18n = store.i18n

    return VStack(alignment: .leading, spacing: 12) {
      Text(i18n.t(.todoDisplay))
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color.black.opacity(0.48))

      NativeTodoSettingsToggleRow(
        title: i18n.t(.todoHideCompletedTasks),
        isOn: Binding(
          get: { store.todoHideCompletedTasks },
          set: { store.setTodoHideCompletedTasks($0) }
        ),
        accentColor: store.accentColor.color
      )

      NativeTodoSettingsToggleRow(
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

    return VStack(alignment: .leading, spacing: 12) {
      Text(i18n.t(.todoLabels))
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color.black.opacity(0.48))

      HStack(spacing: 10) {
        TextField(i18n.t(.todoNewLabelName), text: $newLabelTitle)
          .font(.system(size: 16, weight: .semibold))
          .textInputAutocapitalization(.words)
          .padding(.horizontal, 14)
          .frame(height: 50)
          .background(Color.black.opacity(0.055))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        Button {
          store.createTodoLabel(title: newLabelTitle)
          newLabelTitle = ""
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(canAddLabel ? Color.black : Color.black.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canAddLabel)
        .accessibilityLabel(i18n.t(.todoAddLabel))
      }

      if store.todoLabels.isEmpty {
        Text(i18n.t(.todoNoLabels))
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(Color.black.opacity(0.42))
          .padding(.horizontal, 14)
          .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
          .background(Color.black.opacity(0.035))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      } else {
        LazyVStack(spacing: 8) {
          ForEach(store.todoLabels) { label in
            NativeTodoLabelRow(i18n: i18n, label: label) {
              store.deleteTodoLabel(label)
            }
          }
        }
      }
    }
  }

  private var calendarSection: some View {
    let i18n = store.i18n

    return VStack(alignment: .leading, spacing: 12) {
      Text(i18n.t(.todoIosCalendar))
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color.black.opacity(0.48))

      VStack(spacing: 0) {
        HStack(spacing: 12) {
          Image(systemName: "calendar")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.black)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 3) {
            Text(i18n.t(.todoDefaultCalendarIntegration))
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.black)
            Text(store.todoCalendarAuthorizationState.localizedTitle(i18n))
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.46))
          }

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.todoCalendarSyncEnabled },
            set: { store.setTodoCalendarSyncEnabled($0) }
          ))
          .labelsHidden()
          .tint(store.accentColor.color)
        }
        .padding(14)

        Divider()
          .background(Color.black.opacity(0.07))
          .padding(.leading, 50)

        VStack(alignment: .leading, spacing: 10) {
          Text(i18n.t(.todoCalendarIntegrationDescription))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.black.opacity(0.48))
            .lineSpacing(3)

          HStack(spacing: 10) {
            if !store.todoCalendarAuthorizationState.canSync {
              Button {
                store.requestTodoCalendarAccess()
              } label: {
                Text(i18n.t(.todoAllowPermission))
                  .font(.system(size: 14, weight: .bold))
                  .foregroundColor(.white)
                  .frame(height: 40)
                  .frame(maxWidth: .infinity)
                  .background(Color.black)
                  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              }
              .buttonStyle(.plain)
            }

            Button {
              store.syncTodoItemsToCalendar()
            } label: {
              Text(i18n.t(.todoSyncNow))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(store.todoCalendarAuthorizationState.canSync ? .black : Color.black.opacity(0.34))
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!store.todoCalendarAuthorizationState.canSync)
          }

          if let message = store.todoCalendarSyncMessage {
            Text(message)
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.45))
          }
        }
        .padding(14)
      }
      .background(Color.black.opacity(0.055))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }
}

struct NativeTodoSettingsToggleRow: View {
  var title: String
  @Binding var isOn: Bool
  var accentColor: Color

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.black)

      Spacer()

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(accentColor)
    }
    .padding(.horizontal, 14)
    .frame(height: 52)
    .background(Color.black.opacity(0.035))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .frame(width: 13, height: 13)

      Text(label.title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.black)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(Color.black.opacity(0.42))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoDeleteLabel, ["name": label.title]))
    }
    .padding(.horizontal, 14)
    .frame(height: 48)
    .background(Color.black.opacity(0.035))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
