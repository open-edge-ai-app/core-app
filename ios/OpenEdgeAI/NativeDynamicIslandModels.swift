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
    NativeDynamicIslandPetSprite.primaryColor(for: rawValue)
  }

  var secondaryColor: Color {
    NativeDynamicIslandPetSprite.secondaryColor(for: rawValue)
  }

  var outlineColor: Color {
    NativeDynamicIslandPetSprite.outlineColor(for: rawValue)
  }

  var eyeColor: Color {
    NativeDynamicIslandPetSprite.eyeColor(for: rawValue)
  }

  var cheekColor: Color {
    NativeDynamicIslandPetSprite.cheekColor(for: rawValue)
  }

  var sparkleColor: Color {
    NativeDynamicIslandPetSprite.sparkleColor(for: rawValue)
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
