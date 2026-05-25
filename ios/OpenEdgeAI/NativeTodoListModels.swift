import SwiftUI

enum NativeTodoTab: String {
  case all
  case calendar
}

let nativeTodoHorizontalPadding: CGFloat = 24
let nativeTodoCurrentTimeLineID = "native-todo-current-time-line"

struct NativeCalendarEvent: Identifiable {
  var id: String
  var task: NativeTodoItem
  var title: String
  var note: String
  var labels: [NativeTodoLabel]
  var startHour: CGFloat
  var duration: CGFloat
  var lane: Int
  var timeText: String
  var isCompleted: Bool
}

struct NativeRecurringTodoDeleteRequest {
  var task: NativeTodoItem
  var occurrenceDate: Date
}

struct NativeTodoTagTaskGroup: Identifiable {
  var id: String
  var title: String
  var colorHex: String?
  var tasks: [NativeTodoItem]
}
