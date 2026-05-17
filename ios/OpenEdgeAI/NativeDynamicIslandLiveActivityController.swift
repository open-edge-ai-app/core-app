import ActivityKit
import Foundation

@MainActor
final class NativeDynamicIslandLiveActivityController {
  static let shared = NativeDynamicIslandLiveActivityController()

  private var activity: Activity<OpenEdgeAIDynamicIslandAttributes>?

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
    queuedCount: Int
  ) {
    guard enabled, isVisible, ActivityAuthorizationInfo().areActivitiesEnabled else {
      end(dismissalPolicy: .immediate)
      return
    }

    let content = ActivityContent(
      state: OpenEdgeAIDynamicIslandAttributes.ContentState(
        title: title,
        subtitle: subtitle,
        pet: pet,
        petEnabled: petEnabled,
        motion: motion,
        queuedCount: queuedCount
      ),
      staleDate: Date().addingTimeInterval(90)
    )

    if let currentActivity = currentActivity() {
      if currentActivity.attributes.sessionId == sessionId {
        activity = currentActivity
        Task {
          await currentActivity.update(content)
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
}
