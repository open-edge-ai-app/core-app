import Foundation
import SwiftUI
import UIKit

@MainActor
extension NativeChatStore {
func project(for session: NativeChatSession?) -> NativeProject? {
    guard let projectId = session?.projectId else {
      return nil
    }
    return projects.first { $0.id == projectId }
  }

  func makeHiddenRuntimeContext() -> String {
    let now = Date()
    let locale = Locale.current
    let localeParts = locale.identifier
      .replacingOccurrences(of: "-", with: "_")
      .split(separator: "_")
      .map(String.init)
    let languageCode = localeParts.first ?? "unknown"
    let regionCode = localeParts.dropFirst().first { $0.count == 2 } ?? "unknown"
    let timeZone = TimeZone.current
    deviceContextProvider.refreshLocationIfAuthorized()

    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: selectedLanguage.localeIdentifier)
    displayFormatter.timeZone = timeZone
    displayFormatter.dateStyle = .full
    displayFormatter.timeStyle = .medium

    let localISOFormatter = ISO8601DateFormatter()
    localISOFormatter.timeZone = timeZone
    localISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let utcISOFormatter = ISO8601DateFormatter()
    utcISOFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    utcISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var lines = [
      "Local date/time: \(displayFormatter.string(from: now))",
      "Local ISO timestamp: \(localISOFormatter.string(from: now))",
      "UTC timestamp: \(utcISOFormatter.string(from: now))",
      "Timezone: \(timeZone.identifier), \(timeZone.abbreviation(for: now) ?? "unknown"), \(gmtOffset(seconds: timeZone.secondsFromGMT(for: now)))",
      "Device locale: \(locale.identifier)",
      "Device language: \(languageCode)",
      "Device region: \(regionCode)",
      "App response locale: \(selectedLanguage.localeIdentifier)",
      "Calendar: \(String(describing: Calendar.current.identifier))",
      "Device: \(UIDevice.current.model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    ]

    lines.append(contentsOf: deviceContextProvider.locationContextLines(now: now))
    return "Hidden runtime context:\n" + lines.map { "- \($0)" }.joined(separator: "\n")
  }

  func gmtOffset(seconds: Int) -> String {
    let sign = seconds >= 0 ? "+" : "-"
    let absoluteSeconds = abs(seconds)
    let hours = absoluteSeconds / 3600
    let minutes = (absoluteSeconds % 3600) / 60
    return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
  }
}
