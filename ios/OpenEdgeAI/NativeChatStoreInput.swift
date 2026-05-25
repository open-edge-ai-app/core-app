import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
extension NativeChatStore {
  func sendCurrentInput() {
    let draftInput = makeDraftInput(from: inputText)
    guard !draftInput.text.isEmpty || !pendingAttachments.isEmpty else {
      return
    }

    let draft = NativeDraft(
      id: UUID().uuidString,
      text: draftInput.text,
      attachments: pendingAttachments,
      createdAt: Date(),
      mode: draftInput.mode
    )

    inputText = ""
    pendingAttachments = []

    if isGenerating {
      queuedDrafts.append(draft)
      showDynamicIslandWork()
      return
    }

    send(draft)
  }

  func sendCurrentInput(projectId: String) {
    selectProjectSessionForInput(projectId: projectId)
    sendCurrentInput()
  }

  func removeQueuedDraft(_ draft: NativeDraft) {
    queuedDrafts.removeAll { $0.id == draft.id }
    syncDynamicIslandLiveActivity()
  }

  func updateQueuedDraft(_ draft: NativeDraft, text: String) {
    guard let index = queuedDrafts.firstIndex(where: { $0.id == draft.id }) else {
      return
    }
    queuedDrafts[index].text = text
    syncDynamicIslandLiveActivity()
  }

  func runQueuedDraftIfReady() {
    guard !isGenerating, !queuedDrafts.isEmpty else {
      return
    }
    let next = queuedDrafts.removeFirst()
    send(next)
  }

  func selectProjectSessionForInput(projectId: String) {
    if let selectedSessionId,
       sessions.first(where: { $0.id == selectedSessionId })?.projectId == projectId {
      return
    }

    if let existingSession = sessions
      .filter({ $0.projectId == projectId && sessionHasContent($0) })
      .sorted(by: { $0.updatedAt > $1.updatedAt })
      .first {
      selectedSessionId = existingSession.id
      return
    }

    let currentInput = inputText
    let currentAttachments = pendingAttachments
    createNewSession(projectId: projectId)
    inputText = currentInput
    pendingAttachments = currentAttachments
  }

  func retry(message: NativeMessage) {
    guard !isGenerating,
          let session = currentSession,
          let assistantIndex = session.messages.firstIndex(where: { $0.id == message.id }),
          session.messages[assistantIndex].role == .assistant
    else {
      return
    }

    let previousUser = session.messages[..<assistantIndex]
      .last { $0.role == .user }

    guard let previousUser else {
      return
    }

    let draft = NativeDraft(
      id: UUID().uuidString,
      text: previousUser.text,
      attachments: previousUser.attachments,
      createdAt: Date(),
      mode: message.sourceReferences.isEmpty ? .standard : .search
    )
    let historyMessages = Array(session.messages[..<assistantIndex])

    rewrite(draft, replacingAssistantId: message.id, in: session.id, historyMessages: historyMessages)
  }

  func cancelGeneration() {
    let appleCancelled = AIEngineFoundationModelClient.shared.cancelActiveGeneration()
    let gemmaCancelled = AIEngineGemmaModelClient.shared.cancelActiveGeneration()

    if let activeRequestSessionId, let activeAssistantMessageId {
      flushPendingStreamChunks(to: activeAssistantMessageId, in: activeRequestSessionId, persist: true)
      stopSearchProgress(for: activeAssistantMessageId, in: activeRequestSessionId, clearMessage: false)
      mutateSession(activeRequestSessionId) { session in
        if let index = session.messages.firstIndex(where: { $0.id == activeAssistantMessageId }),
           session.messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          session.messages[index].text = "응답 생성이 중지되었습니다."
        } else if let index = session.messages.firstIndex(where: { $0.id == activeAssistantMessageId }),
                  isSearchProgressText(session.messages[index].text) {
          session.messages[index].text = "검색이 중지되었습니다."
        }
      }
    }

    isGenerating = false
    activeAssistantMessageId = nil
    activeRequestSessionId = nil
    endGenerationBackgroundTaskIfNeeded()
    if queuedDrafts.isEmpty {
      syncDynamicIslandLiveActivity()
    } else {
      showDynamicIslandWork()
    }
    statusMessage = appleCancelled || gemmaCancelled ? "응답을 중지했습니다." : nil
  }

  func addAttachments(from urls: [URL]) {
    let newAttachments = urls.compactMap(makeAttachment)
    pendingAttachments.append(contentsOf: newAttachments)
  }

  func addPhotoAttachments(from items: [PhotosPickerItem]) async {
    var newAttachments: [NativeAttachment] = []

    for item in items {
      guard let data = try? await item.loadTransferable(type: Data.self) else {
        continue
      }

      let contentType = item.supportedContentTypes.first ?? .image
      let fileExtension = contentType.preferredFilenameExtension
        ?? (contentType.conforms(to: .movie) ? "mov" : "jpg")
      let fileName = "Photo-\(Self.attachmentTimestamp()).\(fileExtension)"
      guard let url = persistAttachmentData(data, fileName: fileName) else {
        continue
      }

      newAttachments.append(
        makeAttachment(
          displayName: fileName,
          mimeType: contentType.preferredMIMEType ?? mimeType(fileName: fileName, typeIdentifier: contentType.identifier),
          sizeBytes: Int64(data.count),
          url: url
        )
      )
    }

    pendingAttachments.append(contentsOf: newAttachments)
  }

  func removePendingAttachment(_ attachment: NativeAttachment) {
    pendingAttachments.removeAll { $0.id == attachment.id }
  }

  func copy(_ text: String) {
    UIPasteboard.general.string = text
    statusMessage = "복사했습니다."
  }
}
