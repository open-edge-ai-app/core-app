import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
extension NativeChatStore {
  func shouldShowSession(_ session: NativeChatSession) -> Bool {
    sessionHasContent(session)
  }

  func createNewSession(projectId: String? = nil) {
    pruneEmptyDraftSessions()

    let now = Date()
    let session = NativeChatSession(
      id: UUID().uuidString,
      title: "새 채팅",
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
      messages: []
    )
    sessions.insert(session, at: 0)
    selectedSessionId = session.id
    inputText = ""
    pendingAttachments = []
    saveSessions()
  }

  func selectSession(_ session: NativeChatSession) {
    pruneEmptyDraftSessions(keeping: session.id)
    selectedSessionId = session.id
    inputText = ""
    pendingAttachments = []
    saveSessions()
  }

  func deleteSession(_ session: NativeChatSession) {
    sessions.removeAll { $0.id == session.id }
    if activeRequestSessionId == session.id {
      activeRequestSessionId = nil
    }
    if selectedSessionId == session.id {
      selectedSessionId = sessions.first?.id
    }
    if sessions.isEmpty {
      createNewSession()
    } else {
      saveSessions()
    }
  }

  func renameSession(id: String, title: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty,
          let index = sessions.firstIndex(where: { $0.id == id })
    else {
      return
    }

    sessions[index].title = trimmedTitle
    saveSessions()
  }

  func addSession(_ session: NativeChatSession, to project: NativeProject) {
    guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
      return
    }

    sessions[index].projectId = project.id
    sessions[index].updatedAt = Date()
    sessions.sort { $0.updatedAt > $1.updatedAt }
    saveSessions()
  }

  func createProject(title: String, iconName: String, systemPrompt: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }
    let selectedIconName = iconName.isEmpty ? NativeProjectIcon.defaultIcon.systemImage : iconName
    let trimmedSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

    let project = NativeProject(
      id: UUID().uuidString,
      title: trimmedTitle,
      iconName: selectedIconName,
      systemPrompt: trimmedSystemPrompt,
      createdAt: Date()
    )
    projects.insert(project, at: 0)
    saveProjects()
    rebuildLocalMemoryIndex()
  }

  func deleteProject(_ project: NativeProject) {
    let deletedSessionIds = Set(sessions.filter { $0.projectId == project.id }.map(\.id))
    projects.removeAll { $0.id == project.id }
    sessions.removeAll { $0.projectId == project.id }
    if let activeRequestSessionId, deletedSessionIds.contains(activeRequestSessionId) {
      self.activeRequestSessionId = nil
    }
    if let selectedSessionId,
       sessions.contains(where: { $0.id == selectedSessionId }) == false {
      self.selectedSessionId = sessions.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }
    if sessions.isEmpty {
      createNewSession()
    } else {
      saveSessions()
    }
    saveProjects()
    rebuildLocalMemoryIndex()
  }

  func updateProject(id: String, title: String, iconName: String, systemPrompt: String) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty,
          let index = projects.firstIndex(where: { $0.id == id })
    else {
      return
    }

    projects[index].title = trimmedTitle
    projects[index].iconName = iconName.isEmpty ? NativeProjectIcon.defaultIcon.systemImage : iconName
    projects[index].systemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    saveProjects()
    rebuildLocalMemoryIndex()
  }
}
