import ActivityKit
import Foundation

struct OpenEdgeAIDynamicIslandAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String
    var subtitle: String
    var pet: String
    var petEnabled: Bool
    var motion: String
    var queuedCount: Int
    var progress: Double
    var detail: String
  }

  var sessionId: String
}
