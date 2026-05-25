import Foundation

extension NativeModel {
  func localizedSubtitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .appleFoundation:
      return i18n.t(.modelAppleSubtitle)
    case .gemma:
      return i18n.t(.modelGemmaSubtitle)
    }
  }
}

extension NativeFontSizeSetting {
  func localizedTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .small:
      return i18n.t(.fontSizeSmall)
    case .standard:
      return i18n.t(.fontSizeStandard)
    case .large:
      return i18n.t(.fontSizeLarge)
    }
  }
}

extension NativeAppearanceMode {
  func localizedTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .light:
      return i18n.t(.appearanceLight)
    case .dark:
      return i18n.t(.appearanceDark)
    }
  }
}

extension NativeAccentColor {
  func localizedTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .black:
      return i18n.t(.accentBlack)
    case .blue:
      return i18n.t(.accentBlue)
    case .green:
      return i18n.t(.accentGreen)
    case .purple:
      return i18n.t(.accentPurple)
    case .orange:
      return i18n.t(.accentOrange)
    }
  }
}

extension NativeDynamicIslandPet {
  func localizedSubtitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .orbit:
      return i18n.t(.petOrbitSubtitle)
    case .stacky:
      return i18n.t(.petStackySubtitle)
    case .nullSignal:
      return i18n.t(.petSignalSubtitle)
    case .luma:
      return i18n.t(.petLumaSubtitle)
    case .flux:
      return i18n.t(.petFluxSubtitle)
    }
  }
}

extension NativeTodoRepeatRule {
  func localizedTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .none:
      return i18n.t(.todoRepeatNone)
    case .daily:
      return i18n.t(.todoRepeatDaily)
    case .weekdays:
      return i18n.t(.todoRepeatWeekdays)
    case .weekly:
      return i18n.t(.todoRepeatWeekly)
    case .monthly:
      return i18n.t(.todoRepeatMonthly)
    }
  }
}

extension NativeTodoCalendarAuthorizationState {
  func localizedTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .notDetermined:
      return i18n.t(.todoCalendarPermissionNeeded)
    case .denied:
      return i18n.t(.todoCalendarDenied)
    case .restricted:
      return i18n.t(.todoCalendarRestricted)
    case .writeOnly:
      return i18n.t(.todoCalendarWriteOnly)
    case .fullAccess:
      return i18n.t(.todoCalendarConnected)
    case .unknown:
      return i18n.t(.todoCalendarUnknown)
    }
  }
}

extension NativeRenameTarget {
  func localizedNavigationTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .session:
      return i18n.t(.renameSessionTitle)
    case .project:
      return i18n.t(.renameProjectTitle)
    }
  }

  func localizedFieldTitle(_ i18n: NativeI18n) -> String {
    switch self {
    case .session:
      return i18n.t(.renameSessionField)
    case .project:
      return i18n.t(.renameProjectField)
    }
  }

  func localizedPlaceholder(_ i18n: NativeI18n) -> String {
    switch self {
    case .session:
      return i18n.t(.renameSessionPlaceholder)
    case .project:
      return i18n.t(.renameProjectPlaceholder)
    }
  }
}
