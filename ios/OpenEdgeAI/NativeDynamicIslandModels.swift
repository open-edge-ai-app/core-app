import Foundation
import SwiftUI

enum NativeDynamicIslandPet: String, CaseIterable, Identifiable {
  case orbit
  case stacky
  case nullSignal
  case luma
  case flux

  var id: String { rawValue }

  var title: String {
    switch self {
    case .orbit:
      return "Orbit"
    case .stacky:
      return "Stacky"
    case .nullSignal:
      return "Signal"
    case .luma:
      return "Luma"
    case .flux:
      return "Flux"
    }
  }

  var subtitle: String {
    switch self {
    case .orbit:
      return "푸른 궤도로 작업을 따라가는 기본 펫"
    case .stacky:
      return "노란 블록으로 차분하게 쌓아 올리는 펫"
    case .nullSignal:
      return "보라색 신호를 조용히 기다리는 펫"
    case .luma:
      return "민트빛으로 가볍게 반응하는 펫"
    case .flux:
      return "코랄 톤으로 빠르게 뛰는 펫"
    }
  }

  var primaryColor: Color {
    switch self {
    case .orbit:
      return Color(red: 0.18, green: 0.58, blue: 1)
    case .stacky:
      return Color(red: 1, green: 0.68, blue: 0.20)
    case .nullSignal:
      return Color(red: 0.62, green: 0.36, blue: 1)
    case .luma:
      return Color(red: 0.22, green: 0.86, blue: 0.68)
    case .flux:
      return Color(red: 1, green: 0.38, blue: 0.34)
    }
  }

  var secondaryColor: Color {
    switch self {
    case .orbit:
      return Color(red: 0.55, green: 0.92, blue: 1)
    case .stacky:
      return Color(red: 1, green: 0.93, blue: 0.48)
    case .nullSignal:
      return Color(red: 0.90, green: 0.78, blue: 1)
    case .luma:
      return Color(red: 0.78, green: 1, blue: 0.42)
    case .flux:
      return Color(red: 1, green: 0.78, blue: 0.22)
    }
  }

  var outlineColor: Color {
    switch self {
    case .orbit:
      return Color(red: 0.04, green: 0.12, blue: 0.24)
    case .stacky:
      return Color(red: 0.28, green: 0.17, blue: 0.04)
    case .nullSignal:
      return Color(red: 0.20, green: 0.08, blue: 0.36)
    case .luma:
      return Color(red: 0.04, green: 0.24, blue: 0.22)
    case .flux:
      return Color(red: 0.36, green: 0.08, blue: 0.05)
    }
  }

  var eyeColor: Color {
    switch self {
    case .nullSignal:
      return Color(uiColor: .white)
    case .flux:
      return Color(uiColor: .white)
    default:
      return Color(red: 0.03, green: 0.05, blue: 0.07)
    }
  }
}

enum NativeDynamicIslandPetMotion: String {
  case running
  case resting
  case sleeping
}

enum NativeDynamicIslandPhase {
  case hidden
  case generating
  case queued
}

struct NativeDynamicIslandState {
  var phase: NativeDynamicIslandPhase
  var title: String
  var subtitle: String
  var detail: String
  var progress: Double
  var motion: NativeDynamicIslandPetMotion
  var pet: NativeDynamicIslandPet
  var isPetEnabled: Bool
  var queuedCount: Int
  var isGenerating: Bool

  var isVisible: Bool {
    phase != .hidden
  }

  static let hidden = NativeDynamicIslandState(
    phase: .hidden,
    title: "",
    subtitle: "",
    detail: "",
    progress: 0,
    motion: .resting,
    pet: .orbit,
    isPetEnabled: false,
    queuedCount: 0,
    isGenerating: false
  )
}
