import SwiftUI

struct NativeDynamicIslandPetSprite {
  static let dimension = 11

  static func rows(for pet: String) -> [[Int]] {
    switch pet {
    case "stacky":
      return stackyRows
    case "nullSignal":
      return nullSignalRows
    case "luma":
      return lumaRows
    case "flux":
      return fluxRows
    default:
      return orbitRows
    }
  }

  static func primaryColor(for pet: String) -> Color {
    switch pet {
    case "stacky":
      return Color(red: 1, green: 0.68, blue: 0.20)
    case "nullSignal":
      return Color(red: 0.62, green: 0.36, blue: 1)
    case "luma":
      return Color(red: 0.22, green: 0.86, blue: 0.68)
    case "flux":
      return Color(red: 1, green: 0.38, blue: 0.34)
    default:
      return Color(red: 0.18, green: 0.58, blue: 1)
    }
  }

  static func secondaryColor(for pet: String) -> Color {
    switch pet {
    case "stacky":
      return Color(red: 1, green: 0.93, blue: 0.48)
    case "nullSignal":
      return Color(red: 0.90, green: 0.78, blue: 1)
    case "luma":
      return Color(red: 0.78, green: 1, blue: 0.42)
    case "flux":
      return Color(red: 1, green: 0.78, blue: 0.22)
    default:
      return Color(red: 0.55, green: 0.92, blue: 1)
    }
  }

  static func outlineColor(for pet: String) -> Color {
    switch pet {
    case "stacky":
      return Color(red: 0.28, green: 0.17, blue: 0.04)
    case "nullSignal":
      return Color(red: 0.20, green: 0.08, blue: 0.36)
    case "luma":
      return Color(red: 0.04, green: 0.24, blue: 0.22)
    case "flux":
      return Color(red: 0.36, green: 0.08, blue: 0.05)
    default:
      return Color(red: 0.04, green: 0.12, blue: 0.24)
    }
  }

  static func eyeColor(for pet: String) -> Color {
    Color(red: 0.03, green: 0.05, blue: 0.07)
  }

  static func sparkleColor(for pet: String) -> Color {
    Color(uiColor: .white).opacity(0.96)
  }

  static func cheekColor(for pet: String) -> Color {
    switch pet {
    case "nullSignal":
      return Color(red: 1, green: 0.70, blue: 0.95)
    case "luma":
      return Color(red: 1, green: 0.82, blue: 0.62)
    case "flux":
      return Color(red: 1, green: 0.84, blue: 0.70)
    default:
      return Color(red: 1, green: 0.64, blue: 0.74)
    }
  }

  private static let orbitRows: [[Int]] = [
    [0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0],
    [0, 2, 3, 1, 2, 0, 2, 1, 3, 2, 0],
    [2, 3, 1, 1, 1, 2, 1, 1, 1, 3, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 4, 6, 1, 1, 1, 6, 4, 1, 2],
    [2, 1, 4, 4, 5, 3, 5, 4, 4, 1, 2],
    [2, 1, 1, 5, 1, 2, 1, 5, 1, 1, 2],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [0, 0, 2, 1, 1, 1, 1, 1, 2, 0, 0],
    [0, 2, 3, 2, 1, 2, 1, 2, 3, 2, 0],
    [0, 2, 3, 0, 0, 0, 0, 0, 3, 2, 0]
  ]

  private static let stackyRows: [[Int]] = [
    [0, 0, 0, 2, 2, 2, 2, 2, 0, 0, 0],
    [0, 0, 2, 3, 3, 3, 3, 3, 2, 0, 0],
    [0, 2, 3, 1, 1, 1, 1, 1, 3, 2, 0],
    [2, 3, 1, 1, 1, 1, 1, 1, 1, 3, 2],
    [2, 1, 4, 6, 1, 1, 1, 6, 4, 1, 2],
    [2, 1, 4, 4, 5, 3, 5, 4, 4, 1, 2],
    [2, 3, 1, 5, 1, 2, 1, 5, 1, 3, 2],
    [0, 2, 3, 1, 1, 1, 1, 1, 3, 2, 0],
    [0, 0, 2, 3, 3, 3, 3, 3, 2, 0, 0],
    [0, 2, 1, 2, 0, 0, 0, 2, 1, 2, 0],
    [0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0]
  ]

  private static let nullSignalRows: [[Int]] = [
    [0, 0, 0, 0, 2, 3, 2, 0, 0, 0, 0],
    [0, 0, 0, 2, 1, 3, 1, 2, 0, 0, 0],
    [0, 0, 2, 1, 1, 3, 1, 1, 2, 0, 0],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [2, 1, 4, 6, 1, 1, 1, 6, 4, 1, 2],
    [2, 1, 4, 4, 5, 1, 5, 4, 4, 1, 2],
    [2, 1, 3, 5, 1, 2, 1, 5, 3, 1, 2],
    [0, 2, 1, 3, 3, 3, 3, 3, 1, 2, 0],
    [0, 0, 2, 1, 3, 1, 3, 1, 2, 0, 0],
    [0, 0, 0, 2, 1, 0, 1, 2, 0, 0, 0],
    [0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0]
  ]

  private static let lumaRows: [[Int]] = [
    [0, 0, 2, 3, 2, 0, 0, 2, 3, 2, 0],
    [0, 2, 3, 1, 3, 2, 2, 3, 1, 3, 2],
    [0, 2, 1, 3, 1, 1, 1, 1, 3, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 4, 6, 1, 3, 1, 6, 4, 1, 2],
    [2, 1, 4, 4, 5, 1, 5, 4, 4, 1, 2],
    [0, 2, 1, 5, 1, 2, 1, 5, 1, 2, 0],
    [0, 0, 2, 1, 1, 1, 1, 1, 2, 0, 0],
    [0, 2, 3, 2, 1, 2, 1, 2, 3, 2, 0],
    [0, 2, 1, 0, 2, 0, 2, 0, 1, 2, 0],
    [0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0]
  ]

  private static let fluxRows: [[Int]] = [
    [0, 0, 2, 3, 2, 0, 0, 0, 2, 3, 0],
    [0, 2, 3, 1, 3, 2, 0, 2, 1, 3, 2],
    [2, 3, 1, 1, 1, 1, 2, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 3, 2],
    [2, 1, 4, 6, 1, 3, 1, 6, 4, 1, 2],
    [2, 1, 4, 4, 5, 1, 5, 4, 4, 1, 2],
    [0, 2, 1, 5, 1, 2, 1, 5, 1, 2, 0],
    [0, 0, 2, 1, 1, 1, 1, 1, 2, 0, 0],
    [0, 2, 3, 2, 1, 2, 1, 2, 3, 2, 0],
    [0, 2, 3, 0, 2, 0, 2, 0, 3, 2, 0],
    [0, 0, 0, 2, 2, 0, 2, 2, 0, 0, 0]
  ]
}
