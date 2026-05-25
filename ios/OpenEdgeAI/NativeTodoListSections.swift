import SwiftUI

extension NativeTodoListView {
  var allTasksContent: some View {
    let i18n = store.i18n

    return ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 26) {
        todoListSection(
          title: i18n.t(.todoOverdue),
          isExpanded: $isOverdueExpanded,
          tasks: overdueTodos,
          occurrenceDate: nil,
          emptyTitle: i18n.t(.todoNoOverdue)
        )

        todoListSection(
          title: selectedTodoSectionTitle,
          isExpanded: $isTodayExpanded,
          tasks: selectedDateTodos,
          occurrenceDate: selectedDate,
          emptyTitle: i18n.t(.todoNoTasksForDate),
          separatesTags: store.todoTagsVisibleOnTaskCards
        )
      }
      .padding(.horizontal, nativeTodoHorizontalPadding)
      .padding(.top, 22)
      .padding(.bottom, 120)
      .animation(.spring(response: 0.36, dampingFraction: 0.9), value: isOverdueExpanded)
      .animation(.spring(response: 0.36, dampingFraction: 0.9), value: isTodayExpanded)
    }
  }

  var todoSectionTransition: AnyTransition {
    .opacity
  }

  @ViewBuilder
  func todoListSection(
    title: String,
    isExpanded: Binding<Bool>,
    tasks: [NativeTodoItem],
    occurrenceDate: Date?,
    emptyTitle: String,
    separatesTags: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: isExpanded.wrappedValue ? 12 : 0) {
      NativeTodoSectionHeader(
        title: title,
        isExpanded: isExpanded
      )

      if isExpanded.wrappedValue {
        todoSectionContent(
          tasks: tasks,
          occurrenceDate: occurrenceDate,
          emptyTitle: emptyTitle,
          separatesTags: separatesTags
        )
        .transition(todoSectionTransition)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  func todoSectionContent(
    tasks: [NativeTodoItem],
    occurrenceDate: Date?,
    emptyTitle: String,
    separatesTags: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      if tasks.isEmpty {
        NativeTodoEmptyRow(title: emptyTitle)
      } else if separatesTags {
        ForEach(todoTagGroups(for: tasks)) { group in
          NativeTodoTagTaskGroupView(
            title: group.title,
            colorHex: group.colorHex
          ) {
            ForEach(group.tasks) { task in
              todoCard(
                for: task,
                occurrenceDate: occurrenceDate ?? task.dueDate,
                showsLabels: false
              )
            }
          }
        }
      } else {
        ForEach(tasks) { task in
          todoCard(for: task, occurrenceDate: occurrenceDate ?? task.dueDate)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  func todoCard(
    for task: NativeTodoItem,
    occurrenceDate: Date,
    showsLabels: Bool = true
  ) -> some View {
    NativeTodoTaskCard(
      i18n: store.i18n,
      task: task,
      occurrenceDate: occurrenceDate,
      labels: labels(for: task),
      availableLabels: store.todoLabels,
      showsLabels: showsLabels && store.todoTagsVisibleOnTaskCards,
      isExpanded: expandedTaskIds.contains(task.id),
      onToggleComplete: {
        withAnimation(.easeInOut(duration: 0.18)) {
          store.toggleTodoCompletion(task, occurrenceDate: occurrenceDate)
        }
      },
      onToggleStar: {
        store.toggleTodoStar(task)
      },
      onToggleSubtask: { subtask in
        store.toggleTodoSubtask(todoId: task.id, subtaskId: subtask.id)
      },
      onSelectLabel: { label in
        store.setTodoLabel(task, label: label)
      },
      onToggleExpanded: {
        withAnimation(.easeInOut(duration: 0.18)) {
          toggleExpandedTask(task)
        }
      },
      onEdit: {
        editingTodo = task
      },
      onDelete: {
        requestDelete(task, occurrenceDate: occurrenceDate)
      }
    )
  }

func requestDelete(_ task: NativeTodoItem, occurrenceDate: Date) {
    if task.recurrenceRule.isRepeating {
      recurringDeleteRequest = NativeRecurringTodoDeleteRequest(
        task: task,
        occurrenceDate: occurrenceDate
      )
    } else {
      withAnimation(.easeInOut(duration: 0.18)) {
        store.deleteTodo(task)
      }
    }
  }

  func toggleExpandedTask(_ task: NativeTodoItem) {
    if expandedTaskIds.contains(task.id) {
      expandedTaskIds.remove(task.id)
    } else {
      expandedTaskIds.insert(task.id)
    }
  }

  func labels(for task: NativeTodoItem) -> [NativeTodoLabel] {
    Array(store.todoLabels.filter { task.labelIds.contains($0.id) }.prefix(1))
  }

  func todoTagGroups(for tasks: [NativeTodoItem]) -> [NativeTodoTagTaskGroup] {
    var tasksByLabelId: [String: [NativeTodoItem]] = [:]
    var untaggedTasks: [NativeTodoItem] = []
    let labelIds = Set(store.todoLabels.map(\.id))

    for task in tasks {
      if let labelId = task.labelIds.first, labelIds.contains(labelId) {
        tasksByLabelId[labelId, default: []].append(task)
      } else {
        untaggedTasks.append(task)
      }
    }

    var groups = store.todoLabels.compactMap { label -> NativeTodoTagTaskGroup? in
      guard let tasks = tasksByLabelId[label.id], !tasks.isEmpty else {
        return nil
      }

      return NativeTodoTagTaskGroup(
        id: label.id,
        title: label.title,
        colorHex: label.colorHex,
        tasks: tasks
      )
    }

    if !untaggedTasks.isEmpty {
      groups.append(
        NativeTodoTagTaskGroup(
          id: "native-todo-untagged",
          title: store.i18n.t(.todoNoLabel),
          colorHex: nil,
          tasks: untaggedTasks
        )
      )
    }

    return groups
  }
}
