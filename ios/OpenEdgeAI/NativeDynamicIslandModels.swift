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
      return "Noa"
    case .stacky:
      return "Mino"
    case .nullSignal:
      return "Sia"
    case .luma:
      return "Lumi"
    case .flux:
      return "Rio"
    }
  }

  var subtitle: String {
    switch self {
    case .orbit:
      return "차분하게 생각을 정리하는 파란 동료"
    case .stacky:
      return "할 일을 착착 쌓아 올리는 노란 동료"
    case .nullSignal:
      return "조용히 신호를 읽고 기다리는 보라 동료"
    case .luma:
      return "밝게 반응하며 흐름을 밝혀주는 민트 동료"
    case .flux:
      return "빠르게 움직이며 작업을 밀어주는 코랄 동료"
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

  var skinColor: Color {
    NativeDynamicIslandPetSprite.skinColor(for: rawValue)
  }

  var hairColor: Color {
    NativeDynamicIslandPetSprite.hairColor(for: rawValue)
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
