import ActivityKit
import Foundation

@MainActor
final class NativeDynamicIslandLiveActivityController {
  static let shared = NativeDynamicIslandLiveActivityController()

  private var activity: Activity<OpenEdgeAIDynamicIslandAttributes>?
  private var lastSkippedReason: String?

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
      logSkipped("disabled in settings")
      end(dismissalPolicy: .immediate)
      return
    }

    guard isVisible else {
      logSkipped("no active or queued work")
      end(dismissalPolicy: .immediate)
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      logSkipped("Live Activities disabled by system")
      end(dismissalPolicy: .immediate)
      return
    }

    lastSkippedReason = nil

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

    if let currentActivity = currentActivity() {
      if currentActivity.attributes.sessionId == sessionId {
        activity = currentActivity
        Task {
          await currentActivity.update(content)
          print("OpenEdgeAI Live Activity updated")
        }
        return
      }

      end(dismissalPolicy: .immediate)
    }

    do {
      activity = try Activity.request(
        attributes: OpenEdgeAIDynamicIslandAttributes(sessionId: sessionId),
        content: content,
        pushType: nil
      )
      print("OpenEdgeAI Live Activity requested")
    } catch {
      print("OpenEdgeAI Live Activity request failed: \(error.localizedDescription)")
    }
  }

  func end(dismissalPolicy: ActivityUIDismissalPolicy = .after(Date().addingTimeInterval(3))) {
    let activities = Activity<OpenEdgeAIDynamicIslandAttributes>.activities
    activity = nil

    Task {
      for liveActivity in activities {
        await liveActivity.end(nil, dismissalPolicy: dismissalPolicy)
      }
    }
  }

  private func currentActivity() -> Activity<OpenEdgeAIDynamicIslandAttributes>? {
    if let activity {
      return activity
    }
    return Activity<OpenEdgeAIDynamicIslandAttributes>.activities.first
  }

  private func logSkipped(_ reason: String) {
    guard lastSkippedReason != reason else {
      return
    }
    lastSkippedReason = reason
    print("OpenEdgeAI Live Activity skipped: \(reason)")
  }
}
