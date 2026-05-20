import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
extension NativeChatStore {
  func refreshModelStatuses() async {
    let apple = NativeModelStatus(
      model: .appleFoundation,
      dictionary: AIEngineFoundationModelClient.shared.modelStatus()
    )
    let gemma = NativeModelStatus(
      model: .gemma,
      dictionary: AIEngineGemmaModelClient.shared.modelStatus()
    )
    modelStatuses[.appleFoundation] = apple
    modelStatuses[.gemma] = gemma
  }

  func pollModelStatuses() async {
    while !Task.isCancelled {
      await refreshModelStatuses()
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  func downloadGemma() {
    _ = AIEngineGemmaModelClient.shared.downloadModel()
    Task {
      await refreshModelStatuses()
    }
  }

  func loadSelectedModel() {
    switch selectedModel {
    case .appleFoundation:
      _ = AIEngineFoundationModelClient.shared.loadModel()
    case .gemma:
      _ = AIEngineGemmaModelClient.shared.loadModel()
    }
    Task {
      await refreshModelStatuses()
    }
  }

  func saveSettings() {
    let data: [String: Any] = [
      "settingsSchemaVersion": currentSettingsSchemaVersion,
      "systemPrompt": systemPrompt,
      "userName": userName,
      "personality": personality,
      "memoryEnabled": memoryEnabled,
      "selectedModel": selectedModel.rawValue,
      "fontSize": fontSizeSetting.rawValue,
      "appearanceMode": appearanceMode.rawValue,
      "accentColor": accentColor.rawValue,
      "selectedLanguage": selectedLanguage.rawValue,
      "backgroundExecutionEnabled": backgroundExecutionEnabled,
      "backgroundDynamicIslandEnabled": backgroundDynamicIslandEnabled,
      "dynamicIslandPetEnabled": dynamicIslandPetEnabled,
      "selectedDynamicIslandPet": selectedDynamicIslandPet.rawValue,
      "todoHideCompletedTasks": todoHideCompletedTasks,
      "todoTagsVisibleOnTaskCards": todoTagsVisibleOnTaskCards,
      "todoCalendarSyncEnabled": todoCalendarSyncEnabled
    ]
    UserDefaults.standard.set(data, forKey: settingsKey)
  }

  func rebuildLocalMemoryIndex() {
    localKnowledgeStore.replaceGeneratedRecords(projects: projects, sessions: sessions)
    localMemoryIndexedItems = localKnowledgeStore.count
  }

  func indexAttachments(_ attachments: [NativeAttachment]) {
    let records = NativeDocumentTextExtractor.knowledgeRecords(from: attachments)
    localKnowledgeStore.upsert(records)
    localMemoryIndexedItems = localKnowledgeStore.count
  }
}
