import Foundation

@MainActor
extension NativeChatStore {
  func makeTodoToolStateSection() -> String? {
    let itemLines = todoItems.prefix(24).map { item in
      let labels = todoLabels
        .filter { item.labelIds.contains($0.id) }
        .map(\.title)
        .joined(separator: ", ")
      let status = item.isCompleted ? "completed" : "open"
      let repeatText = item.recurrenceRule.rawValue
      let labelText = labels.isEmpty ? "none" : labels
      return "- id=\(item.id), title=\(item.title), status=\(status), date=\(todoToolDateTimeText(todoStartDate(for: item))), end=\(todoToolDateTimeText(todoEndDate(for: item))), repeat=\(repeatText), starred=\(item.isStarred), labels=\(labelText)"
    }

    let labelLines = todoLabels.map { "- \($0.title)" }
    return """
    Current Todo state for app tool use:
    Settings: hide_completed=\(todoHideCompletedTasks), show_tags=\(todoTagsVisibleOnTaskCards), calendar_sync=\(todoCalendarSyncEnabled)
    Existing labels:
    \(labelLines.isEmpty ? "- none" : labelLines.joined(separator: "\n"))
    Recent/open Todo items:
    \(itemLines.isEmpty ? "- none" : itemLines.joined(separator: "\n"))
    """
  }

  func applyTodoToolCalls(to assistantId: String, in sessionId: String) {
    guard let session = sessions.first(where: { $0.id == sessionId }),
          let message = session.messages.first(where: { $0.id == assistantId })
    else {
      return
    }

    let parsed = NativeTodoToolParser.extractCalls(from: message.text)
    guard !parsed.calls.isEmpty else {
      return
    }

    let results = parsed.calls.map(executeTodoToolCall)
    let resultSection = results.map { "- \($0)" }.joined(separator: "\n")
    let finalText: String
    if parsed.cleanedText.isEmpty {
      finalText = "Todo 작업을 처리했습니다.\n\(resultSection)"
    } else {
      finalText = "\(parsed.cleanedText)\n\nTodo 작업 결과:\n\(resultSection)"
    }

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }
      session.messages[index].text = finalText
    }
    rebuildLocalMemoryIndex()
  }

  private func executeTodoToolCall(_ call: NativeTodoToolCall) -> String {
    switch call.name {
    case "todo_list":
      return executeTodoList(call.arguments)
    case "todo_create":
      return executeTodoCreate(call.arguments)
    case "todo_update":
      return executeTodoUpdate(call.arguments)
    case "todo_complete":
      return executeTodoComplete(call.arguments)
    case "todo_delete":
      return executeTodoDelete(call.arguments)
    case "todo_star":
      return executeTodoStar(call.arguments)
    case "todo_label_create":
      return executeTodoLabelCreate(call.arguments)
    case "todo_label_delete":
      return executeTodoLabelDelete(call.arguments)
    case "todo_label_assign":
      return executeTodoLabelAssign(call.arguments)
    case "todo_subtask_add":
      return executeTodoSubtaskAdd(call.arguments)
    case "todo_subtask_toggle":
      return executeTodoSubtaskToggle(call.arguments)
    case "todo_subtask_delete":
      return executeTodoSubtaskDelete(call.arguments)
    case "todo_settings_update":
      return executeTodoSettingsUpdate(call.arguments)
    default:
      return "\(call.name)은 지원하지 않는 Todo 도구입니다."
    }
  }

  private func executeTodoList(_ args: [String: Any]) -> String {
    let filter = args.todoString("filter")?.lowercased() ?? "all"
    let targetDate = todoToolDate(from: args.todoString("date")) ?? Date()
    let includeCompleted = args.todoBool("include_completed") ?? !todoHideCompletedTasks
    let items = todoItems.filter { item in
      switch filter {
      case "today":
        return Calendar.current.isDateInToday(item.dueDate) || item.occurs(on: Date())
      case "tomorrow":
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return item.occurs(on: tomorrow)
      case "overdue":
        return item.isOverdue()
      case "date":
        return item.occurs(on: targetDate)
      default:
        return true
      }
    }
      .filter { includeCompleted || !$0.isCompleted(on: targetDate) }
      .prefix(12)

    guard !items.isEmpty else {
      return "조회 결과가 없습니다."
    }
    return "조회 결과:\n" + items.map(todoToolSummary).joined(separator: "\n")
  }

  private func executeTodoCreate(_ args: [String: Any]) -> String {
    guard let title = args.todoString("title", "name") else {
      return "생성 실패: title이 필요합니다."
    }

    let startDate = todoToolDate(from: args.todoString("start_at", "start", "due_at", "date"))
      ?? defaultTodoToolStartDate()
    let endDate = todoToolEndDate(arguments: args, startDate: startDate, fallbackEndDate: nil)
    let repeatRule = todoToolRepeatRule(from: args.todoString("repeat", "repeat_rule")) ?? .none
    let labels = todoToolLabelIds(from: args.todoStringArray("labels", "label_names", "tags") ?? [])
    createTodo(
      title: title,
      note: args.todoString("note", "memo") ?? "",
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      labelIds: labels
    )
    if let starred = args.todoBool("starred", "important"), starred,
       let item = todoItems.first(where: { $0.title == title }) {
      toggleTodoStar(item)
    }
    return "생성: \(title)"
  }

  private func executeTodoUpdate(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args) else {
      return "수정 실패: 대상 Todo를 찾지 못했습니다."
    }

    let currentStart = todoStartDate(for: item)
    let currentEnd = todoEndDate(for: item)
    let newStart = todoToolDate(from: args.todoString("start_at", "start", "due_at", "date"))
    let startDate = newStart ?? currentStart
    let endDate = todoToolEndDate(arguments: args, startDate: startDate, fallbackEndDate: currentEnd)
    let repeatRule = todoToolRepeatRule(from: args.todoString("repeat", "repeat_rule")) ?? item.recurrenceRule
    let labelIds = args.todoStringArray("labels", "label_names", "tags").map(todoToolLabelIds) ?? item.labelIds

    updateTodo(
      item,
      title: args.todoString("title", "name") ?? item.title,
      note: args.todoString("note", "memo") ?? item.note,
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      labelIds: labelIds
    )

    if let starred = args.todoBool("starred", "important"),
       let updated = todoItems.first(where: { $0.id == item.id }),
       updated.isStarred != starred {
      toggleTodoStar(updated)
    }
    return "수정: \(args.todoString("title", "name") ?? item.title)"
  }

  private func executeTodoComplete(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args) else {
      return "완료 변경 실패: 대상 Todo를 찾지 못했습니다."
    }
    let date = todoToolDate(from: args.todoString("date", "occurrence_date")) ?? item.dueDate
    let completed = args.todoBool("completed", "is_completed") ?? true
    if item.isCompleted(on: date) != completed {
      toggleTodoCompletion(item, occurrenceDate: date)
    }
    return "\(completed ? "완료" : "미완료"): \(item.title)"
  }

  private func executeTodoDelete(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args) else {
      return "삭제 실패: 대상 Todo를 찾지 못했습니다."
    }
    deleteTodo(item)
    return "삭제: \(item.title)"
  }

  private func executeTodoStar(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args) else {
      return "중요 표시 실패: 대상 Todo를 찾지 못했습니다."
    }
    let starred = args.todoBool("starred", "important") ?? true
    if item.isStarred != starred {
      toggleTodoStar(item)
    }
    return "\(starred ? "중요 표시" : "중요 해제"): \(item.title)"
  }
}
