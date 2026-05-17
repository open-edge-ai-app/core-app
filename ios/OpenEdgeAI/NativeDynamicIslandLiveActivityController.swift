import ActivityKit
import Foundation

@MainActor
final class NativeDynamicIslandLiveActivityController {
  static let shared = NativeDynamicIslandLiveActivityController()

  private var activeActivity: Activity<OpenEdgeAIDynamicIslandAttributes>?
  private var lastLogMessage: String?

  private init() {}

  func sync(
    enabled: Bool,
    isVisible: Bool,
    sessionId: String,
    title: String,
    subtitle: String,
    pet: String,
    petEnabled: Bool,
    motion: String,
    queuedCount: Int,
    progress: Double,
    detail: String
  ) {
    guard enabled else {
      endAll(reason: "disabled in settings", dismissalPolicy: .immediate)
      return
    }

    guard isVisible else {
      endAll(reason: "no active or queued work", dismissalPolicy: .immediate)
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      endAll(reason: "Live Activities disabled by system", dismissalPolicy: .immediate)
      return
    }

    let content = ActivityContent(
      state: OpenEdgeAIDynamicIslandAttributes.ContentState(
        title: title,
        subtitle: subtitle,
        pet: pet,
        petEnabled: petEnabled,
        motion: motion,
        queuedCount: queuedCount,
        progress: progress,
        detail: detail
      ),
      staleDate: Date().addingTimeInterval(90)
    )

    if let activity = activity(for: sessionId) {
      activeActivity = activity
      Task {
        await activity.update(content)
        self.log("updated")
      }
      return
    }

    endMismatchedActivities(keeping: sessionId)

    do {
      activeActivity = try Activity.request(
        attributes: OpenEdgeAIDynamicIslandAttributes(sessionId: sessionId),
        content: content,
        pushType: nil
      )
      log("requested")
    } catch {
      print("OpenEdgeAI Live Activity request failed: \(error.localizedDescription)")
    }
  }

  func end(dismissalPolicy: ActivityUIDismissalPolicy = .after(Date().addingTimeInterval(3))) {
    endAll(reason: "ended", dismissalPolicy: dismissalPolicy)
  }

  private func activity(for sessionId: String) -> Activity<OpenEdgeAIDynamicIslandAttributes>? {
    if activeActivity?.attributes.sessionId == sessionId {
      return activeActivity
    }
    return Activity<OpenEdgeAIDynamicIslandAttributes>.activities.first { activity in
      activity.attributes.sessionId == sessionId
    }
  }

  private func endMismatchedActivities(keeping sessionId: String) {
    let activities = Activity<OpenEdgeAIDynamicIslandAttributes>.activities
      .filter { $0.attributes.sessionId != sessionId }
    guard !activities.isEmpty else {
      return
    }

    Task {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  private func endAll(reason: String, dismissalPolicy: ActivityUIDismissalPolicy) {
    let activities = Activity<OpenEdgeAIDynamicIslandAttributes>.activities
    activeActivity = nil
    log("skipped: \(reason)")

    guard !activities.isEmpty else {
      return
    }

    Task {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: dismissalPolicy)
      }
    }
  }

  private func log(_ message: String) {
    guard lastLogMessage != message else {
      return
    }
    lastLogMessage = message
    print("OpenEdgeAI Live Activity \(message)")
  }
}
