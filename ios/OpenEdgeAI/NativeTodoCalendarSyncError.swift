import Foundation

enum NativeTodoCalendarSyncError: LocalizedError {
  case noCalendarSource

  var errorDescription: String? {
    switch self {
    case .noCalendarSource:
      return "사용 가능한 iOS 캘린더 소스를 찾을 수 없습니다."
    }
  }
}
