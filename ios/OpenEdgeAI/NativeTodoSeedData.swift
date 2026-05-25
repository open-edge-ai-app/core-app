import Foundation

extension NativeTodoItem {
static func seedItems(now: Date = Date(), calendar: Calendar = .current) -> [NativeTodoItem] {
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today) ?? today
    let afternoon = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today

    return [
      NativeTodoItem(
        title: "Call Jason",
        dueDate: yesterday,
        startHour: 11,
        durationHours: 1
      ),
      NativeTodoItem(
        title: "Email Back Mrs James",
        note: "Email Mrs. James for the new intern we have next week from Alex Carter, a marketing student from Brookfield University. Confirm their start date, schedule, and onboarding needs.",
        dueDate: evening,
        isStarred: true,
        startHour: 19,
        durationHours: 1
      ),
      NativeTodoItem(
        title: "New Design System",
        dueDate: afternoon,
        subtasks: [
          NativeTodoSubtask(title: "Update the UI system with a modern, cohesive design.", isComplete: true),
          NativeTodoSubtask(title: "Focus on consistency, scalability, and accessibility."),
          NativeTodoSubtask(title: "Use clean aesthetics with reusable, responsive components."),
          NativeTodoSubtask(title: "Enhance usability for a seamless user experience."),
          NativeTodoSubtask(title: "Streamline development with clear design guidelines.")
        ],
        startHour: 13,
        durationHours: 4
      )
    ]
  }
}
