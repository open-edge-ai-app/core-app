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
      HStack(spacing: 12) {
        Text(title)
          .font(.system(size: 25, weight: .bold))
          .foregroundColor(.black)

        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(Color.black.opacity(0.68))
      }
    }
    .buttonStyle(.plain)
    .padding(.top, 2)
  }
}

struct NativeTodoTaskCard: View {
  var i18n: NativeI18n
  var task: NativeTodoItem
  var onToggleComplete: () -> Void
  var onToggleStar: () -> Void
  var onToggleSubtask: (NativeTodoSubtask) -> Void
  var onEdit: () -> Void
  var onDelete: () -> Void

  private var isOverdue: Bool {
    task.isOverdue()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 14) {
        Button(action: onToggleComplete) {
          Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 23, weight: .medium))
            .foregroundColor(task.isCompleted ? .black : Color.black.opacity(0.56))
            .frame(width: 25, height: 25)
            .padding(.top, 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted ? i18n.t(.todoIncomplete) : i18n.t(.todoComplete))

        VStack(alignment: .leading, spacing: 11) {
          HStack(alignment: .top) {
            Text(task.title)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.black)
              .lineLimit(2)

            Spacer()

            Image(systemName: "chevron.up")
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.52))
          }

          if !task.note.isEmpty {
            Text(task.note)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(Color.black.opacity(0.52))
              .lineSpacing(4)
              .lineLimit(4)
          }

          HStack(spacing: 8) {
            Text(i18n.dueLabel(for: task.dueDate))
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

            Image(systemName: isOverdue ? "calendar" : "alarm")
              .font(.system(size: 17, weight: .regular))
              .foregroundColor(Color.black.opacity(0.48))
          }
        }
      }

      if !task.subtasks.isEmpty {
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

      Button(role: .destructive, action: onDelete) {
        Label(i18n.t(.todoDelete), systemImage: "trash")
      }
    }
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
