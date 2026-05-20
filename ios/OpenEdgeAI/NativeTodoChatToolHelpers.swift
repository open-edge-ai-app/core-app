import Foundation

@MainActor
extension NativeChatStore {
  func executeTodoLabelCreate(_ args: [String: Any]) -> String {
    guard let name = args.todoString("name", "title", "label") else {
      return "태그 생성 실패: name이 필요합니다."
    }
    _ = ensureTodoToolLabel(named: name)
    return "태그 생성: \(name)"
  }

  func executeTodoLabelDelete(_ args: [String: Any]) -> String {
    guard let name = args.todoString("name", "title", "label"),
          let label = todoToolLabel(named: name)
    else {
      return "태그 삭제 실패: 대상 태그를 찾지 못했습니다."
    }
    deleteTodoLabel(label)
    return "태그 삭제: \(label.title)"
  }

  func executeTodoLabelAssign(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args) else {
      return "태그 지정 실패: 대상 Todo를 찾지 못했습니다."
    }
    let names = args.todoStringArray("labels", "label_names", "tags") ?? []
    guard !names.isEmpty else {
      return "태그 지정 실패: labels가 필요합니다."
    }

    let mode = args.todoString("mode")?.lowercased() ?? "replace"
    let ids = todoToolLabelIds(from: names)
    mutateTodoItem(item.id) { todo in
      switch mode {
      case "remove", "delete", "삭제":
        todo.setLabelIds(todo.labelIds.filter { !ids.contains($0) })
      default:
        todo.setLabelIds(ids)
      }
    }
    return "태그 \(mode == "remove" ? "제거" : "지정"): \(item.title)"
  }

  func executeTodoSubtaskAdd(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args),
          let title = args.todoString("title", "subtask", "name")
    else {
      return "하위 할 일 추가 실패: 대상 Todo와 title이 필요합니다."
    }
    mutateTodoItem(item.id) { todo in
      todo.subtasks.append(NativeTodoSubtask(title: title))
    }
    return "하위 할 일 추가: \(title)"
  }

  func executeTodoSubtaskToggle(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args),
          let query = args.todoString("subtask", "subtask_id", "title")
    else {
      return "하위 할 일 변경 실패: 대상 Todo와 subtask가 필요합니다."
    }
    let completed = args.todoBool("completed", "is_completed")
    var changedTitle = query
    mutateTodoItem(item.id) { todo in
      guard let index = todoToolSubtaskIndex(in: todo, query: query) else {
        return
      }
      changedTitle = todo.subtasks[index].title
      if let completed {
        todo.subtasks[index].isComplete = completed
      } else {
        todo.subtasks[index].isComplete.toggle()
      }
    }
    return "하위 할 일 변경: \(changedTitle)"
  }

  func executeTodoSubtaskDelete(_ args: [String: Any]) -> String {
    guard let item = todoToolFindItem(args),
          let query = args.todoString("subtask", "subtask_id", "title")
    else {
      return "하위 할 일 삭제 실패: 대상 Todo와 subtask가 필요합니다."
    }
    mutateTodoItem(item.id) { todo in
      if let index = todoToolSubtaskIndex(in: todo, query: query) {
        todo.subtasks.remove(at: index)
      }
    }
    return "하위 할 일 삭제: \(query)"
  }

  func executeTodoSettingsUpdate(_ args: [String: Any]) -> String {
    if let hideCompleted = args.todoBool("hide_completed", "hideCompleted") {
      setTodoHideCompletedTasks(hideCompleted)
    }
    if let showTags = args.todoBool("show_tags", "showTags", "tags_visible") {
      setTodoTagsVisibleOnTaskCards(showTags)
    }
    if let calendarSync = args.todoBool("calendar_sync", "calendarSync") {
      setTodoCalendarSyncEnabled(calendarSync)
    }
    return "Todo 설정을 업데이트했습니다."
  }

  func todoToolFindItem(_ args: [String: Any]) -> NativeTodoItem? {
    if let id = args.todoString("id", "todo_id", "task_id"),
       let exact = todoItems.first(where: { $0.id == id }) {
      return exact
    }

    guard let query = args.todoString("query", "title", "name")?.lowercased() else {
      return nil
    }
    if let exact = todoItems.first(where: { $0.title.lowercased() == query }) {
      return exact
    }
    return todoItems.first { item in
      item.title.lowercased().contains(query) || item.note.lowercased().contains(query)
    }
  }

  func todoToolLabelIds(from names: [String]) -> [String] {
    names.prefix(1).map { ensureTodoToolLabel(named: $0).id }
  }

  func ensureTodoToolLabel(named name: String) -> NativeTodoLabel {
    if let existing = todoToolLabel(named: name) {
      return existing
    }
    let color = NativeTodoLabel.defaultColors[todoLabels.count % NativeTodoLabel.defaultColors.count]
    let label = NativeTodoLabel(title: name, colorHex: color)
    todoLabels.insert(label, at: 0)
    saveTodoLabels()
    return label
  }

  func todoToolLabel(named name: String) -> NativeTodoLabel? {
    let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return todoLabels.first { $0.title.lowercased() == normalized }
  }

  func todoToolSubtaskIndex(in item: NativeTodoItem, query: String) -> Int? {
    let normalized = query.lowercased()
    if let exact = item.subtasks.firstIndex(where: { $0.id == query || $0.title.lowercased() == normalized }) {
      return exact
    }
    return item.subtasks.firstIndex { $0.title.lowercased().contains(normalized) }
  }

  func todoToolEndDate(arguments args: [String: Any], startDate: Date, fallbackEndDate: Date?) -> Date {
    if let endDate = todoToolDate(from: args.todoString("end_at", "end")) {
      return max(endDate, Calendar.current.date(byAdding: .minute, value: 30, to: startDate) ?? startDate)
    }
    if let minutesText = args.todoString("duration_minutes"),
       let minutes = Double(minutesText) {
      return Calendar.current.date(byAdding: .minute, value: max(30, Int(minutes)), to: startDate) ?? startDate
    }
    if let hoursText = args.todoString("duration_hours", "duration"),
       let hours = Double(hoursText) {
      return Calendar.current.date(byAdding: .minute, value: max(30, Int(hours * 60)), to: startDate) ?? startDate
    }
    if let fallbackEndDate, fallbackEndDate > startDate {
      return fallbackEndDate
    }
    return Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
  }
}
