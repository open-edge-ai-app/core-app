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
  case todoLabels
  case todoNewLabelName
  case todoAddLabel
  case todoNoLabels
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

private extension NativeI18n {
  static let localizedMessages: [NativeLanguage: [NativeI18nKey: String]] = {
    var messages: [NativeLanguage: [NativeI18nKey: String]] = [
      .korean: koreanMessages,
      .english: englishMessages,
      .simplifiedChinese: compactChineseMessages,
      .hindi: compactHindiMessages,
      .spanish: compactSpanishMessages,
      .french: compactFrenchMessages,
      .arabic: compactArabicMessages,
      .bengali: compactBengaliMessages,
      .russian: compactRussianMessages,
      .portuguese: compactPortugueseMessages,
      .urdu: compactUrduMessages,
      .indonesian: compactIndonesianMessages,
      .german: compactGermanMessages,
      .japanese: compactJapaneseMessages,
      .turkish: compactTurkishMessages
    ]
    return messages
  }()

  static let koreanMessages: [NativeI18nKey: String] = [
    .commonCancel: "취소",
    .commonDone: "완료",
    .commonSave: "저장",
    .commonSelect: "선택",
    .commonDownload: "다운로드",
    .commonDownloading: "다운로드 중",
    .commonClose: "닫기",
    .commonOk: "확인",
    .commonOpenSettings: "설정 열기",
    .commonDelete: "삭제",
    .commonRename: "이름 변경",
    .chatGreeting: "안녕하세요, 무엇을 도와드릴까요?",
    .chatSubtitlePrimary: "필요한 내용을 편하게 물어보세요.",
    .chatSubtitleSecondary: "생각 정리부터 글쓰기, 코드까지 이어서 도와드릴게요.",
    .chatSuggestionsTitle: "추천 질문",
    .chatSuggestionPriority: "오늘 할 일 우선순위 정리해줘",
    .chatSuggestionDevelopIdea: "이 아이디어를 더 구체화해줘",
    .chatSuggestionSummarize: "긴 글을 핵심만 요약해줘",
    .chatSuggestionDebugCode: "코드 오류 원인을 같이 찾아줘",
    .chatAttachmentFallback: "첨부 파일",
    .chatResponsePreparing: "응답 준비 중...",
    .chatSources: "출처",
    .chatSourcesCount: "출처 {count}개",
    .chatContextCompressed: "컨텍스트 압축됨",
    .chatNewChat: "새 채팅",
    .chatButton: "채팅",
    .chatSendMessage: "메시지 보내기",
    .chatStopResponse: "응답 중지",
    .chatInputPlaceholder: "무엇이든 묻거나 검색하고 만들어보세요...",
    .chatAttachFile: "파일 첨부",
    .chatQueuedFollowUp: "대기 중인 후속 질문",
    .chatSearchMode: "검색 모드",
    .chatSlashSearchTitle: "검색 강화",
    .chatSlashSearchSubtitle: "현재 대화 기반으로 검색해서 답변 개선",
    .chatOpenList: "채팅 목록 열기",
    .chatGenerating: "응답 생성 중",
    .chatCopyCode: "코드 복사",
    .attachmentAdd: "첨부 추가",
    .attachmentPhotoOrVideo: "사진 또는 동영상",
    .attachmentFile: "파일",
    .attachmentDialogMessage: "이미지, 동영상, 문서 파일을 대화에 첨부할 수 있습니다.",
    .attachmentPhotoPermissionTitle: "사진 접근 권한 필요",
    .attachmentPhotoPermissionMessage: "사진과 동영상을 첨부하려면 사진 보관함 접근 권한을 허용해 주세요.",
    .menuTodoList: "Todo List",
    .menuProjects: "프로젝트",
    .menuNewProject: "새 프로젝트",
    .menuRecent: "최근",
    .menuNoRecentChats: "최근 대화가 없습니다",
    .menuProjectSettings: "프로젝트 설정",
    .menuAddToProject: "프로젝트에 추가",
    .menuNoProjectsToAdd: "추가할 프로젝트 없음",
    .searchTitle: "검색",
    .searchClearQuery: "검색어 지우기",
    .searchRecentChats: "최근 대화",
    .searchNoResults: "검색 결과가 없습니다",
    .searchResults: "검색 결과",
    .searchConversationFallback: "대화",
    .projectName: "프로젝트 이름",
    .projectIcon: "아이콘",
    .projectSystemPrompt: "시스템 프롬프트",
    .projectInstructionPlaceholder: "이 프로젝트에서 항상 적용할 지침을 입력하세요.",
    .projectNew: "새 프로젝트",
    .projectCreate: "생성",
    .projectList: "프로젝트 목록",
    .projectShare: "프로젝트 공유",
    .projectChatTab: "채팅",
    .projectSourcesTab: "출처",
    .projectNoChats: "프로젝트에 채팅이 없습니다",
    .projectNoSources: "출처가 없습니다",
    .projectSourcesPlaceholder: "첨부 파일이나 참조 자료를 추가하면 여기에 표시됩니다.",
    .projectNewConversation: "새 대화",
    .projectMessagePlaceholder: "{name}에 메시지...",
    .renameSessionTitle: "채팅 이름 변경",
    .renameProjectTitle: "프로젝트 설정",
    .renameSessionField: "채팅 이름",
    .renameProjectField: "프로젝트 이름",
    .renameSessionPlaceholder: "예: 새 채팅",
    .renameProjectPlaceholder: "예: Atlas",
    .settingsGeneral: "일반",
    .settingsModel: "모델",
    .settingsPersonalization: "개인 맞춤 설정",
    .settingsAppearance: "모양",
    .settingsInfo: "정보",
    .settingsBackground: "백그라운드",
    .settingsBackgroundExecution: "백그라운드 실행",
    .settingsBackgroundDynamicIsland: "백그라운드 Dynamic Island 활성",
    .settingsDynamicIslandPet: "Dynamic Island 펫",
    .settingsDynamicIslandPetEnabled: "Dynamic Island 펫 활성",
    .settingsLanguage: "언어",
    .settingsFontSize: "글씨 크기",
    .settingsPreview: "미리보기",
    .settingsDisplayMode: "화면 모드",
    .settingsMode: "모드",
    .settingsAccentColor: "강조 컬러",
    .settingsBasicInfo: "기본 정보",
    .settingsName: "이름",
    .settingsPersonality: "성격",
    .settingsMemory: "메모리",
    .settingsMemoryEnabled: "메모리 활성",
    .settingsIndexedItems: "인덱싱된 항목",
    .settingsIndexedItemCount: "{count}개",
    .settingsRebuildMemory: "메모리 다시 인덱싱",
    .settingsCustomInstructions: "맞춤형 지침",
    .settingsSupport: "지원",
    .settingsReportIssue: "문제 신고하기",
    .settingsContribute: "기여하기",
    .settingsAppInfo: "앱 정보",
    .settingsVersion: "버전",
    .settingsPlatform: "플랫폼",
    .settingsPlatformIosNative: "iOS native",
    .modelAppleSubtitle: "Apple 기본 온디바이스 AI",
    .modelGemmaSubtitle: "다운로드 가능한 로컬 모델",
    .fontSizeSmall: "작게",
    .fontSizeStandard: "기본",
    .fontSizeLarge: "크게",
    .appearanceLight: "화이트 모드",
    .appearanceDark: "다크 모드",
    .accentBlack: "검정",
    .accentBlue: "파랑",
    .accentGreen: "초록",
    .accentPurple: "보라",
    .accentOrange: "주황",
    .todoListTitle: "Todo List",
    .todoBackToMenu: "메뉴로 돌아가기",
    .todoSettings: "Todo 설정",
    .todoAdd: "Todo 추가",
    .todoViewPicker: "Todo 보기",
    .todoTabList: "리스트",
    .todoTabCalendar: "캘린더",
    .todoOverdue: "Overdue",
    .todoToday: "Today",
    .todoYesterday: "Yesterday",
    .todoTomorrow: "Tomorrow",
    .todoTasks: "Tasks",
    .todoNoOverdue: "지연된 Todo가 없습니다.",
    .todoNoTasksForDate: "이 날짜에 등록된 Todo가 없습니다.",
    .todoComplete: "Todo 완료",
    .todoIncomplete: "Todo 완료 해제",
    .todoStar: "중요 표시",
    .todoUnstar: "중요 해제",
    .todoEdit: "수정",
    .todoDelete: "삭제",
    .todoLabels: "Labels",
    .todoNewLabelName: "새 라벨 이름",
    .todoAddLabel: "라벨 추가",
    .todoNoLabels: "아직 만든 라벨이 없습니다.",
    .todoDeleteLabel: "{name} 라벨 삭제",
    .todoIosCalendar: "iOS Calendar",
    .todoDefaultCalendarIntegration: "기본 캘린더 앱 연동",
    .todoCalendarIntegrationDescription: "Open Edge AI Todo 캘린더를 만들고, Todo 항목을 iOS Calendar 이벤트로 동기화합니다.",
    .todoAllowPermission: "권한 허용",
    .todoSyncNow: "지금 동기화",
    .todoTitleField: "Title",
    .todoNewTaskPlaceholder: "New task",
    .todoNoteField: "Note",
    .todoOptionalDetails: "Optional details",
    .todoSchedule: "Schedule",
    .todoStart: "Start",
    .todoEnd: "End",
    .todoRepeat: "Repeat",
    .todoEditTitle: "Edit Todo",
    .todoAddTitle: "Add Todo",
    .todoFallbackTitle: "New Todo",
    .todoCalendarPermissionNeeded: "권한 필요",
    .todoCalendarDenied: "권한 거부됨",
    .todoCalendarRestricted: "제한됨",
    .todoCalendarWriteOnly: "쓰기 권한",
    .todoCalendarConnected: "연동됨",
    .todoCalendarUnknown: "확인 필요",
    .todoRepeatNone: "반복 없음",
    .todoRepeatDaily: "매일",
    .todoRepeatWeekdays: "평일",
    .todoRepeatWeekly: "매주",
    .todoRepeatMonthly: "매월",
    .todoNoCalendarPermission: "캘린더 권한이 허용되지 않았습니다.",
    .todoAllowCalendarFirst: "캘린더 권한을 먼저 허용해주세요.",
    .todoNothingToSync: "동기화할 Todo가 없습니다.",
    .todoSyncedCount: "{count}개 Todo를 iOS 캘린더에 동기화했습니다.",
    .petOrbitSubtitle: "푸른 궤도로 작업을 따라가는 기본 펫",
    .petStackySubtitle: "노란 블록으로 차분하게 쌓아 올리는 펫",
    .petSignalSubtitle: "보라색 신호를 조용히 기다리는 펫",
    .petLumaSubtitle: "민트빛으로 가볍게 반응하는 펫",
    .petFluxSubtitle: "코랄 톤으로 빠르게 뛰는 펫"
  ]

  static let englishMessages: [NativeI18nKey: String] = [
    .commonCancel: "Cancel",
    .commonDone: "Done",
    .commonSave: "Save",
    .commonSelect: "Select",
    .commonDownload: "Download",
    .commonDownloading: "Downloading",
    .commonClose: "Close",
    .commonOk: "OK",
    .commonOpenSettings: "Open Settings",
    .commonDelete: "Delete",
    .commonRename: "Rename",
    .chatGreeting: "Hello, how can I help?",
    .chatSubtitlePrimary: "Ask whatever you need.",
    .chatSubtitleSecondary: "I can help organize thoughts, write, and work through code.",
    .chatSuggestionsTitle: "Suggested questions",
    .chatSuggestionPriority: "Prioritize what I should do today",
    .chatSuggestionDevelopIdea: "Make this idea more concrete",
    .chatSuggestionSummarize: "Summarize the key points of a long text",
    .chatSuggestionDebugCode: "Help me find the cause of a code error",
    .chatAttachmentFallback: "Attachment",
    .chatResponsePreparing: "Preparing response...",
    .chatSources: "Sources",
    .chatSourcesCount: "{count} sources",
    .chatContextCompressed: "Context compressed",
    .chatNewChat: "New chat",
    .chatButton: "Chat",
    .chatSendMessage: "Send message",
    .chatStopResponse: "Stop response",
    .chatInputPlaceholder: "Ask, search, or make anything...",
    .chatAttachFile: "Attach file",
    .chatQueuedFollowUp: "Queued follow-up",
    .chatSearchMode: "Search mode",
    .chatSlashSearchTitle: "Enhanced search",
    .chatSlashSearchSubtitle: "Search from the current conversation to improve the answer",
    .chatOpenList: "Open chat list",
    .chatGenerating: "Generating response",
    .chatCopyCode: "Copy code",
    .attachmentAdd: "Add attachment",
    .attachmentPhotoOrVideo: "Photo or video",
    .attachmentFile: "File",
    .attachmentDialogMessage: "Attach images, videos, and documents to the conversation.",
    .attachmentPhotoPermissionTitle: "Photo access needed",
    .attachmentPhotoPermissionMessage: "Allow photo library access to attach photos and videos.",
    .menuTodoList: "Todo List",
    .menuProjects: "Projects",
    .menuNewProject: "New project",
    .menuRecent: "Recent",
    .menuNoRecentChats: "No recent chats",
    .menuProjectSettings: "Project settings",
    .menuAddToProject: "Add to project",
    .menuNoProjectsToAdd: "No projects to add",
    .searchTitle: "Search",
    .searchClearQuery: "Clear search query",
    .searchRecentChats: "Recent chats",
    .searchNoResults: "No search results",
    .searchResults: "Search results",
    .searchConversationFallback: "Conversation",
    .projectName: "Project name",
    .projectIcon: "Icon",
    .projectSystemPrompt: "System prompt",
    .projectInstructionPlaceholder: "Enter instructions that should always apply in this project.",
    .projectNew: "New project",
    .projectCreate: "Create",
    .projectList: "Project list",
    .projectShare: "Share project",
    .projectChatTab: "Chat",
    .projectSourcesTab: "Sources",
    .projectNoChats: "No chats in this project",
    .projectNoSources: "No sources",
    .projectSourcesPlaceholder: "Attachments and references you add will appear here.",
    .projectNewConversation: "New conversation",
    .projectMessagePlaceholder: "Message {name}...",
    .renameSessionTitle: "Rename chat",
    .renameProjectTitle: "Project settings",
    .renameSessionField: "Chat name",
    .renameProjectField: "Project name",
    .renameSessionPlaceholder: "E.g. New chat",
    .renameProjectPlaceholder: "E.g. Atlas",
    .settingsGeneral: "General",
    .settingsModel: "Model",
    .settingsPersonalization: "Personalization",
    .settingsAppearance: "Appearance",
    .settingsInfo: "Info",
    .settingsBackground: "Background",
    .settingsBackgroundExecution: "Background execution",
    .settingsBackgroundDynamicIsland: "Background Dynamic Island",
    .settingsDynamicIslandPet: "Dynamic Island pet",
    .settingsDynamicIslandPetEnabled: "Enable Dynamic Island pet",
    .settingsLanguage: "Language",
    .settingsFontSize: "Font size",
    .settingsPreview: "Preview",
    .settingsDisplayMode: "Display mode",
    .settingsMode: "Mode",
    .settingsAccentColor: "Accent color",
    .settingsBasicInfo: "Basic information",
    .settingsName: "Name",
    .settingsPersonality: "Personality",
    .settingsMemory: "Memory",
    .settingsMemoryEnabled: "Memory enabled",
    .settingsIndexedItems: "Indexed items",
    .settingsIndexedItemCount: "{count} items",
    .settingsRebuildMemory: "Rebuild memory index",
    .settingsCustomInstructions: "Custom instructions",
    .settingsSupport: "Support",
    .settingsReportIssue: "Report an issue",
    .settingsContribute: "Contribute",
    .settingsAppInfo: "App information",
    .settingsVersion: "Version",
    .settingsPlatform: "Platform",
    .settingsPlatformIosNative: "iOS native",
    .modelAppleSubtitle: "Apple on-device AI",
    .modelGemmaSubtitle: "Downloadable local model",
    .fontSizeSmall: "Small",
    .fontSizeStandard: "Default",
    .fontSizeLarge: "Large",
    .appearanceLight: "Light mode",
    .appearanceDark: "Dark mode",
    .accentBlack: "Black",
    .accentBlue: "Blue",
    .accentGreen: "Green",
    .accentPurple: "Purple",
    .accentOrange: "Orange",
    .todoListTitle: "Todo List",
    .todoBackToMenu: "Back to menu",
    .todoSettings: "Todo settings",
    .todoAdd: "Add Todo",
    .todoViewPicker: "Todo view",
    .todoTabList: "List",
    .todoTabCalendar: "Calendar",
    .todoOverdue: "Overdue",
    .todoToday: "Today",
    .todoYesterday: "Yesterday",
    .todoTomorrow: "Tomorrow",
    .todoTasks: "Tasks",
    .todoNoOverdue: "No overdue tasks",
    .todoNoTasksForDate: "No tasks for this date",
    .todoComplete: "Mark Todo complete",
    .todoIncomplete: "Mark Todo incomplete",
    .todoStar: "Mark important",
    .todoUnstar: "Unmark important",
    .todoEdit: "Edit",
    .todoDelete: "Delete",
    .todoLabels: "Labels",
    .todoNewLabelName: "New label name",
    .todoAddLabel: "Add label",
    .todoNoLabels: "No labels yet.",
    .todoDeleteLabel: "Delete {name} label",
    .todoIosCalendar: "iOS Calendar",
    .todoDefaultCalendarIntegration: "Default Calendar integration",
    .todoCalendarIntegrationDescription: "Create an Open Edge AI Todo calendar and sync Todo items as iOS Calendar events.",
    .todoAllowPermission: "Allow permission",
    .todoSyncNow: "Sync now",
    .todoTitleField: "Title",
    .todoNewTaskPlaceholder: "New task",
    .todoNoteField: "Note",
    .todoOptionalDetails: "Optional details",
    .todoSchedule: "Schedule",
    .todoStart: "Start",
    .todoEnd: "End",
    .todoRepeat: "Repeat",
    .todoEditTitle: "Edit Todo",
    .todoAddTitle: "Add Todo",
    .todoFallbackTitle: "New Todo",
    .todoCalendarPermissionNeeded: "Permission needed",
    .todoCalendarDenied: "Permission denied",
    .todoCalendarRestricted: "Restricted",
    .todoCalendarWriteOnly: "Write access",
    .todoCalendarConnected: "Connected",
    .todoCalendarUnknown: "Needs check",
    .todoRepeatNone: "No repeat",
    .todoRepeatDaily: "Daily",
    .todoRepeatWeekdays: "Weekdays",
    .todoRepeatWeekly: "Weekly",
    .todoRepeatMonthly: "Monthly",
    .todoNoCalendarPermission: "Calendar permission was not granted.",
    .todoAllowCalendarFirst: "Allow Calendar permission first.",
    .todoNothingToSync: "No Todo items to sync.",
    .todoSyncedCount: "Synced {count} Todo items to iOS Calendar.",
    .petOrbitSubtitle: "Default pet that follows tasks with a blue orbit",
    .petStackySubtitle: "A calm yellow block pet that stacks work",
    .petSignalSubtitle: "A purple signal pet that waits quietly",
    .petLumaSubtitle: "A mint pet that reacts lightly",
    .petFluxSubtitle: "A fast coral-toned pet"
  ]

  static let compactChineseMessages = compactMessages(
    settings: ["一般", "模型", "个性化", "外观", "信息", "语言"],
    todo: ["列表", "日历", "逾期", "今天", "任务"],
    actions: ["完成", "取消", "保存"]
  )

  static let compactHindiMessages = compactMessages(
    settings: ["सामान्य", "मॉडल", "व्यक्तिकरण", "दिखावट", "जानकारी", "भाषा"],
    todo: ["सूची", "कैलेंडर", "अतिदेय", "आज", "कार्य"],
    actions: ["पूर्ण", "रद्द", "सहेजें"]
  )

  static let compactSpanishMessages = compactMessages(
    settings: ["General", "Modelo", "Personalización", "Apariencia", "Información", "Idioma"],
    todo: ["Lista", "Calendario", "Atrasado", "Hoy", "Tareas"],
    actions: ["Listo", "Cancelar", "Guardar"]
  )

  static let compactFrenchMessages = compactMessages(
    settings: ["Général", "Modèle", "Personnalisation", "Apparence", "Infos", "Langue"],
    todo: ["Liste", "Calendrier", "En retard", "Aujourd'hui", "Tâches"],
    actions: ["Terminé", "Annuler", "Enregistrer"]
  )

  static let compactArabicMessages = compactMessages(
    settings: ["عام", "النموذج", "تخصيص", "المظهر", "معلومات", "اللغة"],
    todo: ["قائمة", "تقويم", "متأخر", "اليوم", "مهام"],
    actions: ["تم", "إلغاء", "حفظ"]
  )

  static let compactBengaliMessages = compactMessages(
    settings: ["সাধারণ", "মডেল", "ব্যক্তিগতকরণ", "চেহারা", "তথ্য", "ভাষা"],
    todo: ["তালিকা", "ক্যালেন্ডার", "বিলম্বিত", "আজ", "কাজ"],
    actions: ["সম্পন্ন", "বাতিল", "সংরক্ষণ"]
  )

  static let compactRussianMessages = compactMessages(
    settings: ["Общие", "Модель", "Персонализация", "Вид", "Инфо", "Язык"],
    todo: ["Список", "Календарь", "Просрочено", "Сегодня", "Задачи"],
    actions: ["Готово", "Отмена", "Сохранить"]
  )

  static let compactPortugueseMessages = compactMessages(
    settings: ["Geral", "Modelo", "Personalização", "Aparência", "Info", "Idioma"],
    todo: ["Lista", "Calendário", "Atrasado", "Hoje", "Tarefas"],
    actions: ["Concluído", "Cancelar", "Salvar"]
  )

  static let compactUrduMessages = compactMessages(
    settings: ["عام", "ماڈل", "ذاتی", "ظاہری شکل", "معلومات", "زبان"],
    todo: ["فہرست", "کیلنڈر", "تاخیر", "آج", "کام"],
    actions: ["مکمل", "منسوخ", "محفوظ"]
  )

  static let compactIndonesianMessages = compactMessages(
    settings: ["Umum", "Model", "Personalisasi", "Tampilan", "Info", "Bahasa"],
    todo: ["Daftar", "Kalender", "Terlambat", "Hari ini", "Tugas"],
    actions: ["Selesai", "Batal", "Simpan"]
  )

  static let compactGermanMessages = compactMessages(
    settings: ["Allgemein", "Modell", "Personalisierung", "Darstellung", "Info", "Sprache"],
    todo: ["Liste", "Kalender", "Überfällig", "Heute", "Aufgaben"],
    actions: ["Fertig", "Abbrechen", "Speichern"]
  )

  static let compactJapaneseMessages = compactMessages(
    settings: ["一般", "モデル", "パーソナライズ", "外観", "情報", "言語"],
    todo: ["リスト", "カレンダー", "期限切れ", "今日", "タスク"],
    actions: ["完了", "キャンセル", "保存"]
  )

  static let compactTurkishMessages = compactMessages(
    settings: ["Genel", "Model", "Kişiselleştirme", "Görünüm", "Bilgi", "Dil"],
    todo: ["Liste", "Takvim", "Gecikmiş", "Bugün", "Görevler"],
    actions: ["Bitti", "İptal", "Kaydet"]
  )

  static func compactMessages(
    settings: [String],
    todo: [String],
    actions: [String]
  ) -> [NativeI18nKey: String] {
    [
      .settingsGeneral: settings[0],
      .settingsModel: settings[1],
      .settingsPersonalization: settings[2],
      .settingsAppearance: settings[3],
      .settingsInfo: settings[4],
      .settingsLanguage: settings[5],
      .todoTabList: todo[0],
      .todoTabCalendar: todo[1],
      .todoOverdue: todo[2],
      .todoToday: todo[3],
      .todoTasks: todo[4],
      .commonDone: actions[0],
      .commonCancel: actions[1],
      .commonSave: actions[2]
    ]
  }
}
