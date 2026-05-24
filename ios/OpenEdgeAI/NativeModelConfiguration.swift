import Foundation
import SwiftUI

enum NativeRole: String, Codable {
  case user
  case assistant
}

enum NativeModel: String, CaseIterable, Identifiable, Codable {
  case appleFoundation = "apple-foundation"
  case gemma = "gemma-4"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .appleFoundation:
      return "Apple Intelligence"
    case .gemma:
      return "Gemma 4"
    }
  }

  var subtitle: String {
    switch self {
    case .appleFoundation:
      return "Apple 기본 온디바이스 AI"
    case .gemma:
      return "다운로드 가능한 로컬 모델"
    }
  }
}

enum NativeFontSizeSetting: String, CaseIterable, Identifiable {
  case small
  case standard
  case large

  var id: String { rawValue }

  var title: String {
    switch self {
    case .small:
      return "작게"
    case .standard:
      return "기본"
    case .large:
      return "크게"
    }
  }

  var bodySize: CGFloat {
    switch self {
    case .small:
      return 15
    case .standard:
      return 16
    case .large:
      return 18
    }
  }

  var inputSize: CGFloat {
    switch self {
    case .small:
      return 15
    case .standard:
      return 16
    case .large:
      return 17
    }
  }

  var sliderValue: Double {
    switch self {
    case .small:
      return 0
    case .standard:
      return 1
    case .large:
      return 2
    }
  }

  init(sliderValue: Double) {
    switch Int(sliderValue.rounded()) {
    case 0:
      self = .small
    case 2:
      self = .large
    default:
      self = .standard
    }
  }
}

enum NativeAppearanceMode: String, CaseIterable, Identifiable {
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .light:
      return "화이트 모드"
    case .dark:
      return "다크 모드"
    }
  }

  var colorScheme: ColorScheme {
    switch self {
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}

enum NativeAccentColor: String, CaseIterable, Identifiable {
  case black
  case blue
  case green
  case purple
  case orange

  var id: String { rawValue }

  var title: String {
    switch self {
    case .black:
      return "기본"
    case .blue:
      return "파랑"
    case .green:
      return "초록"
    case .purple:
      return "보라"
    case .orange:
      return "주황"
    }
  }

  var color: Color {
    switch self {
    case .black:
      return .primary
    case .blue:
      return .blue
    case .green:
      return .green
    case .purple:
      return .purple
    case .orange:
      return .orange
    }
  }

  var foregroundColor: Color {
    switch self {
    case .black:
      return .oeControlText
    case .green, .orange:
      return Color(uiColor: .black)
    case .blue, .purple:
      return Color(uiColor: .white)
    }
  }

  var subtleColor: Color {
    color.opacity(0.22)
  }
}

enum NativeLanguage: String, CaseIterable, Identifiable {
  case korean = "ko"
  case english = "en"
  case simplifiedChinese = "zh-Hans"
  case hindi = "hi"
  case spanish = "es"
  case french = "fr"
  case arabic = "ar"
  case bengali = "bn"
  case russian = "ru"
  case portuguese = "pt"
  case urdu = "ur"
  case indonesian = "id"
  case german = "de"
  case japanese = "ja"
  case turkish = "tr"

  var id: String { rawValue }

  var nativeName: String {
    switch self {
    case .korean:
      return "한국어"
    case .english:
      return "English"
    case .simplifiedChinese:
      return "简体中文"
    case .hindi:
      return "हिन्दी"
    case .spanish:
      return "Español"
    case .french:
      return "Français"
    case .arabic:
      return "العربية"
    case .bengali:
      return "বাংলা"
    case .russian:
      return "Русский"
    case .portuguese:
      return "Português"
    case .urdu:
      return "اردو"
    case .indonesian:
      return "Bahasa Indonesia"
    case .german:
      return "Deutsch"
    case .japanese:
      return "日本語"
    case .turkish:
      return "Türkçe"
    }
  }

  var englishName: String {
    switch self {
    case .korean:
      return "Korean"
    case .english:
      return "English"
    case .simplifiedChinese:
      return "Chinese (Simplified)"
    case .hindi:
      return "Hindi"
    case .spanish:
      return "Spanish"
    case .french:
      return "French"
    case .arabic:
      return "Arabic"
    case .bengali:
      return "Bengali"
    case .russian:
      return "Russian"
    case .portuguese:
      return "Portuguese"
    case .urdu:
      return "Urdu"
    case .indonesian:
      return "Indonesian"
    case .german:
      return "German"
    case .japanese:
      return "Japanese"
    case .turkish:
      return "Turkish"
    }
  }

  var localeIdentifier: String {
    switch self {
    case .korean:
      return "ko_KR"
    case .english:
      return "en_US"
    case .simplifiedChinese:
      return "zh_Hans_CN"
    case .hindi:
      return "hi_IN"
    case .spanish:
      return "es_ES"
    case .french:
      return "fr_FR"
    case .arabic:
      return "ar_SA"
    case .bengali:
      return "bn_BD"
    case .russian:
      return "ru_RU"
    case .portuguese:
      return "pt_BR"
    case .urdu:
      return "ur_PK"
    case .indonesian:
      return "id_ID"
    case .german:
      return "de_DE"
    case .japanese:
      return "ja_JP"
    case .turkish:
      return "tr_TR"
    }
  }
}
