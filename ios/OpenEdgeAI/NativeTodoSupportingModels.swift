import Foundation

enum NativeTodoRepeatRule: String, CaseIterable, Codable, Identifiable, Hashable {
  case none
  case daily
  case weekdays
  case weekly
  case monthly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .none:
      return "반복 없음"
    case .daily:
      return "매일"
    case .weekdays:
      return "평일"
    case .weekly:
      return "매주"
    case .monthly:
      return "매월"
    }
  }

  var isRepeating: Bool {
    self != .none
  }
}

struct NativeTodoLabel: Identifiable, Codable, Equatable, Hashable {
  var id: String
  var title: String
  var colorHex: String
  var createdAt: Date

  init(
    id: String = UUID().uuidString,
    title: String,
    colorHex: String = NativeTodoLabel.defaultColors[0],
    createdAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.colorHex = colorHex
    self.createdAt = createdAt
  }

  static let defaultColors = [
    "#111111",
    "#FF3B30",
    "#007AFF",
    "#34C759",
    "#FF9500",
    "#AF52DE"
  ]
}

enum NativeTodoCalendarAuthorizationState: String, Equatable {
  case notDetermined
  case denied
  case restricted
  case writeOnly
  case fullAccess
  case unknown

  var title: String {
    switch self {
    case .notDetermined:
      return "권한 필요"
    case .denied:
      return "권한 거부됨"
    case .restricted:
      return "제한됨"
    case .writeOnly:
      return "쓰기 권한"
    case .fullAccess:
      return "연동됨"
    case .unknown:
      return "확인 필요"
    }
  }

  var canSync: Bool {
    self == .fullAccess || self == .writeOnly
  }
}
