import Foundation

enum NativeI18nKey: String, CaseIterable {
  case commonCancel
  case commonDone
  case commonSave
  case commonSelect
  case commonDownload
  case commonDownloading
  case commonClose
  case commonOk
  case commonOpenSettings
  case commonDelete
  case commonRename

  case chatGreeting
  case chatSubtitlePrimary
  case chatSubtitleSecondary
  case chatSuggestionsTitle
  case chatSuggestionPriority
  case chatSuggestionDevelopIdea
  case chatSuggestionSummarize
  case chatSuggestionDebugCode
  case chatAttachmentFallback
  case chatResponsePreparing
  case chatSources
  case chatSourcesCount
  case chatContextCompressed
  case chatNewChat
  case chatButton
  case chatSendMessage
  case chatStopResponse
  case chatInputPlaceholder
  case chatAttachFile
  case chatQueuedFollowUp
  case chatSearchMode
  case chatSlashSearchTitle
  case chatSlashSearchSubtitle
  case chatOpenList
  case chatGenerating
  case chatCopyCode

  case attachmentAdd
  case attachmentPhotoOrVideo
  case attachmentFile
  case attachmentDialogMessage
  case attachmentPhotoPermissionTitle
  case attachmentPhotoPermissionMessage

  case menuTodoList
  case menuProjects
  case menuNewProject
  case menuRecent
  case menuNoRecentChats
  case menuProjectSettings
  case menuAddToProject
  case menuNoProjectsToAdd

  case searchTitle
  case searchClearQuery
  case searchRecentChats
  case searchNoResults
  case searchResults
  case searchConversationFallback

  case projectName
  case projectIcon
  case projectSystemPrompt
  case projectInstructionPlaceholder
  case projectNew
  case projectCreate
  case projectList
  case projectShare
  case projectChatTab
  case projectSourcesTab
  case projectNoChats
  case projectNoSources
  case projectSourcesPlaceholder
  case projectNewConversation
  case projectMessagePlaceholder
  case renameSessionTitle
  case renameProjectTitle
  case renameSessionField
  case renameProjectField
  case renameSessionPlaceholder
  case renameProjectPlaceholder

  case settingsGeneral
  case settingsModel
  case settingsPersonalization
  case settingsAppearance
  case settingsInfo
  case settingsBackground
  case settingsBackgroundExecution
  case settingsBackgroundDynamicIsland
  case settingsDynamicIslandPet
  case settingsDynamicIslandPetEnabled
  case settingsLanguage
  case settingsFontSize
  case settingsPreview
  case settingsDisplayMode
  case settingsMode
  case settingsAccentColor
  case settingsBasicInfo
  case settingsName
  case settingsPersonality
  case settingsMemory
  case settingsMemoryEnabled
  case settingsIndexedItems
  case settingsIndexedItemCount
  case settingsRebuildMemory
  case settingsCustomInstructions
  case settingsSupport
  case settingsReportIssue
  case settingsContribute
  case settingsAppInfo
  case settingsVersion
  case settingsPlatform
  case settingsPlatformIosNative

  case modelAppleSubtitle
  case modelGemmaSubtitle

  case fontSizeSmall
  case fontSizeStandard
  case fontSizeLarge
  case appearanceLight
  case appearanceDark
  case accentBlack
  case accentBlue
  case accentGreen
  case accentPurple
  case accentOrange

  case todoListTitle
  case todoBackToMenu
  case todoSettings
  case todoAdd
  case todoViewPicker
  case todoTabList
  case todoTabCalendar
  case todoOverdue
  case todoToday
  case todoYesterday
  case todoTomorrow
  case todoTasks
  case todoNoOverdue
  case todoNoTasksForDate
  case todoComplete
  case todoIncomplete
  case todoStar
  case todoUnstar
  case todoEdit
  case todoDelete
  case todoDeleteRepeatTitle
  case todoDeleteRepeatMessage
  case todoDeleteThisOccurrence
  case todoDeleteEntireSeries
  case todoDisplay
  case todoHideCompletedTasks
  case todoLabels
  case todoShowLabelsOnTasks
  case todoNewLabelName
  case todoAddLabel
  case todoNoLabels
  case todoNoLabel
  case todoDeleteLabel
  case todoIosCalendar
  case todoDefaultCalendarIntegration
  case todoCalendarIntegrationDescription
  case todoAllowPermission
  case todoSyncNow
  case todoTitleField
  case todoNewTaskPlaceholder
  case todoNoteField
  case todoOptionalDetails
  case todoSchedule
  case todoStart
  case todoEnd
  case todoRepeat
  case todoEditTitle
  case todoAddTitle
  case todoFallbackTitle
  case todoCalendarPermissionNeeded
  case todoCalendarDenied
  case todoCalendarRestricted
  case todoCalendarWriteOnly
  case todoCalendarConnected
  case todoCalendarUnknown
  case todoRepeatNone
  case todoRepeatDaily
  case todoRepeatWeekdays
  case todoRepeatWeekly
  case todoRepeatMonthly
  case todoNoCalendarPermission
  case todoAllowCalendarFirst
  case todoNothingToSync
  case todoSyncedCount

  case petOrbitSubtitle
  case petStackySubtitle
  case petSignalSubtitle
  case petLumaSubtitle
  case petFluxSubtitle
}

struct NativeI18n {
  var language: NativeLanguage

  func t(_ key: NativeI18nKey, _ values: [String: String] = [:]) -> String {
    let message =
      Self.localizedMessages[language]?[key] ??
      Self.localizedMessages[.english]?[key] ??
      Self.localizedMessages[.korean]?[key] ??
      key.rawValue

    return values.reduce(message) { result, entry in
      result.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
    }
  }

  func locale() -> Locale {
    Locale(identifier: language.localeIdentifier)
  }

  func dateTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate("EEE dd MMMM")
    return formatter.string(from: date)
  }

  func shortDateTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate("MMM d")
    return formatter.string(from: date)
  }

  func weekdayLetter(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate("EEEEE")
    return formatter.string(from: date)
  }

  func dayNumber(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.dateFormat = "dd"
    return formatter.string(from: date)
  }

  func timelineHour(_ hour: Int) -> String {
    let hourText = String(format: "%02d", hour)
    return language == .korean ? "\(hourText)시" : "\(hourText):00"
  }

  func dueLabel(for date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(date) {
      return t(.todoToday)
    }
    if calendar.isDateInYesterday(date) {
      return t(.todoYesterday)
    }
    if calendar.isDateInTomorrow(date) {
      return t(.todoTomorrow)
    }

    let formatter = DateFormatter()
    formatter.locale = locale()
    formatter.setLocalizedDateFormatFromTemplate(
      calendar.component(.year, from: date) == calendar.component(.year, from: referenceDate)
        ? "MMM d"
        : "MMM d yyyy"
    )
    return formatter.string(from: date)
  }
}

extension NativeChatStore {
  var i18n: NativeI18n {
    NativeI18n(language: selectedLanguage)
  }
}

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
