import SwiftUI

struct NativeTodoSectionHeader: View {
  var title: String
  @Binding var isExpanded: Bool

  var body: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.18)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        Text(title)
          .font(.system(size: 25, weight: .bold))
          .foregroundColor(.black)
          .frame(alignment: .leading)

        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(Color.black.opacity(0.68))
          .frame(width: 22, height: 22)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.top, 2)
  }
}

struct NativeTodoTaskCard: View {
  var i18n: NativeI18n
  var task: NativeTodoItem
  var occurrenceDate: Date
  var labels: [NativeTodoLabel]
  var availableLabels: [NativeTodoLabel]
  var showsLabels: Bool
  var isExpanded: Bool
  var onToggleComplete: () -> Void
  var onToggleStar: () -> Void
  var onToggleSubtask: (NativeTodoSubtask) -> Void
  var onSelectLabel: (NativeTodoLabel?) -> Void
  var onToggleExpanded: () -> Void
  var onEdit: () -> Void
  var onDelete: () -> Void

  private var isOverdue: Bool {
    task.isOverdue()
  }

  private var isOccurrenceCompleted: Bool {
    task.isCompleted(on: occurrenceDate)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 14) {
        Button(action: onToggleComplete) {
          Image(systemName: isOccurrenceCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 23, weight: .medium))
            .foregroundColor(isOccurrenceCompleted ? .black : Color.black.opacity(0.56))
            .frame(width: 25, height: 25)
            .padding(.top, 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOccurrenceCompleted ? i18n.t(.todoIncomplete) : i18n.t(.todoComplete))

        VStack(alignment: .leading, spacing: 11) {
          HStack(alignment: .top) {
            Text(task.title)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.black)
              .lineLimit(2)

            Spacer()

            Button(action: onToggleExpanded) {
              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.52))
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
          }

          if isExpanded {
            if !task.note.isEmpty {
              Text(task.note)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.52))
                .lineSpacing(4)
                .lineLimit(4)
            }
          }

          HStack(spacing: 8) {
            if showsLabels && !labels.isEmpty {
              NativeTodoInlineTagGroup(labels: labels)

              Text("•")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.black.opacity(0.28))
            }

            Text(i18n.dueLabel(for: occurrenceDate))
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(isOverdue ? .red.opacity(0.78) : .red.opacity(0.64))

            Text("•")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(Color.black.opacity(0.28))

            Text(task.recurrenceRule.isRepeating ? task.recurrenceRule.localizedTitle(i18n) : i18n.t(.todoTasks))
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.42))

            Spacer()

            Button(action: onToggleStar) {
              Image(systemName: task.isStarred ? "star.fill" : "star")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(task.isStarred ? .red.opacity(0.74) : Color.black.opacity(0.48))
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isStarred ? i18n.t(.todoUnstar) : i18n.t(.todoStar))
          }
        }
      }

      if isExpanded && !task.subtasks.isEmpty {
        VStack(spacing: 0) {
          ForEach(task.subtasks) { subtask in
            Button {
              onToggleSubtask(subtask)
            } label: {
              HStack(alignment: .top, spacing: 14) {
                Image(systemName: subtask.isComplete ? "checkmark.circle" : "circle")
                  .font(.system(size: 19, weight: .medium))
                  .foregroundColor(Color.black.opacity(0.58))
                  .padding(.top, 1)

                Text(subtask.title)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundColor(Color.black.opacity(0.68))
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)

                Spacer()
              }
              .padding(.leading, 46)
              .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if subtask.id != task.subtasks.last?.id {
              Divider()
                .padding(.leading, 46)
                .background(Color.black.opacity(0.07))
            }
          }
        }
      }
    }
    .padding(22)
    .background(Color(red: 0.94, green: 0.945, blue: 0.95))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .contextMenu {
      Button(action: onEdit) {
        Label(i18n.t(.todoEdit), systemImage: "pencil")
      }

      Menu {
        if availableLabels.isEmpty {
          Text(i18n.t(.todoNoLabels))
        } else {
          Button {
            onSelectLabel(nil)
          } label: {
            Label(
              i18n.t(.todoNoLabel),
              systemImage: task.labelIds.isEmpty ? "checkmark" : "tag.slash"
            )
          }

          ForEach(availableLabels) { label in
            Button {
              onSelectLabel(label)
            } label: {
              Label(
                label.title,
                systemImage: task.labelIds.contains(label.id) ? "checkmark" : "tag"
              )
            }
          }
        }
      } label: {
        Label(i18n.t(.todoLabels), systemImage: "tag")
      }

      Button(role: .destructive, action: onDelete) {
        Label(i18n.t(.todoDelete), systemImage: "trash")
      }
    }
  }
}

struct NativeTodoInlineTagGroup: View {
  var labels: [NativeTodoLabel]

  private var visibleLabels: [NativeTodoLabel] {
    Array(labels.prefix(1))
  }

  var body: some View {
    HStack(spacing: 5) {
      ForEach(visibleLabels) { label in
        NativeTodoInlineTagChip(label: label)
      }

    }
    .frame(maxWidth: 150, alignment: .leading)
  }
}

struct NativeTodoInlineTagChip: View {
  var label: NativeTodoLabel

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(Color(todoLabelHex: label.colorHex))
        .frame(width: 6, height: 6)

      Text(label.title)
        .font(.system(size: 11, weight: .bold))
        .lineLimit(1)
    }
    .foregroundColor(Color.black.opacity(0.62))
    .padding(.horizontal, 7)
    .frame(maxWidth: 72)
    .frame(height: 22)
    .background(Color.black.opacity(0.045))
    .clipShape(Capsule())
  }
}

struct NativeTodoEmptyRow: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(Color.black.opacity(0.42))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
    .background(Color.black.opacity(0.035))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
