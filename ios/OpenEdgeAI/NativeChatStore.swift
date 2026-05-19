import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
final class NativeChatStore: ObservableObject {
  @Published var sessions: [NativeChatSession] = []
  @Published var projects: [NativeProject] = []
  @Published var todoItems: [NativeTodoItem] = []
  @Published var todoLabels: [NativeTodoLabel] = []
  @Published var todoCalendarSyncEnabled = false
  @Published var todoCalendarAuthorizationState: NativeTodoCalendarAuthorizationState = .unknown
  @Published var todoCalendarSyncMessage: String?
  @Published var selectedSessionId: String?
  @Published var inputText = ""
  @Published var pendingAttachments: [NativeAttachment] = []
  @Published var queuedDrafts: [NativeDraft] = []
  @Published var selectedModel: NativeModel = .appleFoundation
  @Published var modelStatuses: [NativeModel: NativeModelStatus] = [:]
  @Published var isGenerating = false
  @Published var statusMessage: String?
  @Published var systemPrompt = ""
  @Published var userName = ""
  @Published var personality = "Balanced"
  @Published var memoryEnabled = true
  @Published var fontSizeSetting: NativeFontSizeSetting = .standard
  @Published var appearanceMode: NativeAppearanceMode = .light
  @Published var accentColor: NativeAccentColor = .black
  @Published var selectedLanguage: NativeLanguage = .korean
  @Published var backgroundExecutionEnabled = false
  @Published var backgroundDynamicIslandEnabled = true
  @Published var dynamicIslandPetEnabled = false
  @Published var selectedDynamicIslandPet: NativeDynamicIslandPet = .orbit
  @Published var localMemoryIndexedItems = 0

  let storageKey = "OpenEdgeAI.NativeChatSessions.v1"
  let projectsStorageKey = "OpenEdgeAI.NativeProjects.v1"
  let todoStorageKey = "OpenEdgeAI.NativeTodoItems.v1"
  let todoLabelsStorageKey = "OpenEdgeAI.NativeTodoLabels.v1"
  let todoCalendarIdentifierKey = "OpenEdgeAI.NativeTodoCalendarIdentifier.v1"
  let settingsKey = "OpenEdgeAI.NativeSettings.v1"
  let currentSettingsSchemaVersion = 2
  let todoEventStore = EKEventStore()
  let dynamicIslandActivityId = "open-edge-ai.live-generation"
  var activeAssistantMessageId: String?
  @Published var activeRequestSessionId: String?
  var generationBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  var searchProgressTasks: [String: Task<Void, Never>] = [:]
  let deviceContextProvider = NativeDeviceContextProvider()
  let localKnowledgeStore = NativeLocalKnowledgeStore.shared
  let searchFallbackRequestText = "현재 대화 내용을 기반으로 검색해서 내용을 개선해줘."

  init() {
    loadSettings()
    loadSessions()
    loadProjects()
    loadTodoItems()
    loadTodoLabels()
    refreshTodoCalendarAuthorizationState()
    rebuildLocalMemoryIndex()

    if sessions.isEmpty {
      createNewSession()
    } else {
      selectedSessionId = sessions.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }

    modelStatuses = Dictionary(
      uniqueKeysWithValues: NativeModel.allCases.map { ($0, NativeModelStatus(model: $0)) }
    )

    Task {
      await refreshModelStatuses()
    }

    syncDynamicIslandLiveActivity()
  }

  var currentSession: NativeChatSession? {
    guard let selectedSessionId else {
      return nil
    }
    return sessions.first { $0.id == selectedSessionId }
  }

  var currentMessages: [NativeMessage] {
    currentSession?.messages ?? []
  }

  var activeWritingSessionId: String? {
    isGenerating ? activeRequestSessionId : nil
  }


  var canSend: Bool {
    !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
  }
}
