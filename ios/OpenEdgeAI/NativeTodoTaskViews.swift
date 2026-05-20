import SwiftUI

struct NativeTodoSectionHeader: View {
  var title: String
  @Binding var isExpanded: Bool

  var body: some View {
    Button {
      withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        Text(title)
          .font(.system(size: 25, weight: .bold))
          .foregroundColor(.oeText)
          .frame(alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(.oeSecondaryText)
          .frame(width: 22, height: 22)
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
          .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isExpanded)

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
            .foregroundColor(isOccurrenceCompleted ? .oeText : .oeSecondaryText)
            .frame(width: 25, height: 25)
            .padding(.top, 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOccurrenceCompleted ? i18n.t(.todoIncomplete) : i18n.t(.todoComplete))

        VStack(alignment: .leading, spacing: 11) {
          HStack(alignment: .top) {
            Text(task.title)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.oeText)
              .lineLimit(2)

            Spacer()

            Button(action: onToggleExpanded) {
              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.oeSecondaryText)
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
          }

          if isExpanded {
            if !task.note.isEmpty {
              Text(task.note)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.oeSecondaryText)
                .lineSpacing(4)
                .lineLimit(4)
            }
          }

          HStack(spacing: 8) {
            if showsLabels && !labels.isEmpty {
              NativeTodoInlineTagGroup(labels: labels)

              Text("•")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.oeMutedText)
            }

            Text(i18n.dueLabel(for: occurrenceDate))
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(Color.oeDestructive.opacity(isOverdue ? 0.9 : 0.74))

            Text("•")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(.oeMutedText)

            Text(task.recurrenceRule.isRepeating ? task.recurrenceRule.localizedTitle(i18n) : i18n.t(.todoTasks))
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.oeMutedText)

            Spacer()

            Button(action: onToggleStar) {
              Image(systemName: task.isStarred ? "star.fill" : "star")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(task.isStarred ? Color.oeDestructive.opacity(0.84) : .oeSecondaryText)
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
                  .foregroundColor(.oeSecondaryText)
                  .padding(.top, 1)

                Text(subtask.title)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundColor(.oeSecondaryText)
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
                .background(Color.oeSeparator)
            }
          }
        }
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.oeSurface)
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
    .fixedSize(horizontal: true, vertical: false)
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
    .foregroundColor(.oeSecondaryText)
    .padding(.horizontal, 7)
    .frame(maxWidth: 72)
    .frame(height: 22)
    .background(Color.oeSubtleFill)
    .clipShape(Capsule())
  }
}

struct NativeTodoTagTaskGroupView<Content: View>: View {
  var title: String
  var colorHex: String?
  @ViewBuilder var content: Content

  private var markerColor: Color {
    guard let colorHex else {
      return .oeMutedText
    }
    return Color(todoLabelHex: colorHex)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Circle()
          .fill(markerColor)
          .frame(width: 9, height: 9)

        Text(title)
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.oeSecondaryText)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 4)
      .padding(.top, 4)

      VStack(alignment: .leading, spacing: 10) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct NativeTodoEmptyRow: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.oeMutedText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
    .background(Color.oeSubtleFill)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
