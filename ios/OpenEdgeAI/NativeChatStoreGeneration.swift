import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

@MainActor
extension NativeChatStore {
  func send(_ draft: NativeDraft) {
    guard let sessionId = selectedSessionId else {
      return
    }

    let now = Date()
    let userMessage = NativeMessage(
      id: UUID().uuidString,
      role: .user,
      text: draft.text,
      createdAt: now,
      attachments: draft.attachments
    )
    let assistantMessage = NativeMessage(
      id: UUID().uuidString,
      role: .assistant,
      text: "",
      createdAt: Date(),
      attachments: []
    )

    mutateSession(sessionId) { session in
      session.messages.append(userMessage)
      session.messages.append(assistantMessage)
      if session.title == "새 채팅" {
        session.title = makeLocalTitle(from: draft.text)
      }
    }

    isGenerating = true
    activeAssistantMessageId = assistantMessage.id
    activeRequestSessionId = sessionId
    statusMessage = nil
    beginGenerationBackgroundTaskIfNeeded()
    showDynamicIslandWork()

    let selectedTools = NativeToolRegistry.selectedTools(for: draft)
    if selectedTools.contains(.webSearch) {
      statusMessage = "검색 중..."
      startSearchProgress(assistantId: assistantMessage.id, sessionId: sessionId)
      let searchQuery = makeSearchQuery(for: sessionId, draft: draft)
      Task { [weak self] in
        let searchContext = await NativeWebSearchClient.shared.search(query: searchQuery)
        await MainActor.run { [weak self] in
          guard let self,
                self.activeAssistantMessageId == assistantMessage.id,
                self.activeRequestSessionId == sessionId
          else {
            return
          }

          self.statusMessage = nil
          self.stopSearchProgress(for: assistantMessage.id, in: sessionId, clearMessage: true)
          self.applySearchSources(searchContext.sourceReferences, to: assistantMessage.id, in: sessionId)
          let prompt = self.makePrompt(for: sessionId, draft: draft, searchContext: searchContext)
          self.streamResponse(prompt: prompt, assistantId: assistantMessage.id, sessionId: sessionId)
        }
      }
    } else {
      let prompt = makePrompt(for: sessionId, draft: draft)
      streamResponse(prompt: prompt, assistantId: assistantMessage.id, sessionId: sessionId)
    }
  }

  func rewrite(
    _ draft: NativeDraft,
    replacingAssistantId assistantId: String,
    in sessionId: String,
    historyMessages: [NativeMessage]
  ) {
    let now = Date()
    var didResetMessage = false

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].text = ""
      session.messages[index].attachments = []
      session.messages[index].sourceReferences = []
      session.messages[index].contextCompressed = false
      session.messages[index].createdAt = now
      didResetMessage = true
    }

    guard didResetMessage else {
      return
    }

    isGenerating = true
    activeAssistantMessageId = assistantId
    activeRequestSessionId = sessionId
    statusMessage = nil
    beginGenerationBackgroundTaskIfNeeded()
    showDynamicIslandWork()

    let selectedTools = NativeToolRegistry.selectedTools(for: draft)
    if selectedTools.contains(.webSearch) {
      statusMessage = "검색 중..."
      startSearchProgress(assistantId: assistantId, sessionId: sessionId)
      let searchQuery = makeSearchQuery(for: sessionId, draft: draft, historyMessages: historyMessages)
      Task { [weak self] in
        let searchContext = await NativeWebSearchClient.shared.search(query: searchQuery)
        await MainActor.run { [weak self] in
          guard let self,
                self.activeAssistantMessageId == assistantId,
                self.activeRequestSessionId == sessionId
          else {
            return
          }

          self.statusMessage = nil
          self.stopSearchProgress(for: assistantId, in: sessionId, clearMessage: true)
          self.applySearchSources(searchContext.sourceReferences, to: assistantId, in: sessionId)
          let prompt = self.makePrompt(
            for: sessionId,
            draft: draft,
            historyMessages: historyMessages,
            searchContext: searchContext
          )
          self.streamResponse(prompt: prompt, assistantId: assistantId, sessionId: sessionId)
        }
      }
    } else {
      let prompt = makePrompt(for: sessionId, draft: draft, historyMessages: historyMessages)
      streamResponse(prompt: prompt, assistantId: assistantId, sessionId: sessionId)
    }
  }

  func streamResponse(prompt: String, assistantId: String, sessionId: String) {
    let model = selectedModel
    let didCompressContext = NativePromptCompressor.estimatedTokens(prompt) > NativePromptCompressor.maxInputTokens
      || NativePromptCompressor.containsCompressionMarker(prompt)
    let compactedPrompt = NativePromptCompressor.clippedPreservingEdges(
      prompt,
      maxEstimatedTokens: NativePromptCompressor.maxInputTokens
    )
    setContextCompressionNotice(didCompressContext, to: assistantId, in: sessionId)

    if model == .gemma {
      AIEngineGemmaModelClient.shared.streamResponse(prompt: compactedPrompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantId, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantId, sessionId: sessionId)
        }
      }
    } else {
      AIEngineFoundationModelClient.shared.streamResponse(prompt: compactedPrompt) { [weak self] chunk in
        Task { @MainActor in
          self?.appendChunk(chunk as String, to: assistantId, in: sessionId)
        }
      } completion: { [weak self] message, error in
        Task { @MainActor in
          self?.finishGeneration(message: message as String?, error: error as String?, assistantId: assistantId, sessionId: sessionId)
        }
      }
    }
  }

  func setContextCompressionNotice(_ isCompressed: Bool, to assistantId: String, in sessionId: String) {
    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].contextCompressed = isCompressed
    }
  }

  func appendChunk(_ chunk: String, to assistantId: String, in sessionId: String) {
    guard isGenerating, activeAssistantMessageId == assistantId else {
      return
    }
    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }
      if isSearchProgressText(session.messages[index].text) {
        session.messages[index].text = ""
      }
      session.messages[index].text += chunk
    }
  }

  func finishGeneration(message: String?, error: String?, assistantId: String, sessionId: String) {
    guard activeAssistantMessageId == assistantId else {
      return
    }

    stopSearchProgress(for: assistantId, in: sessionId, clearMessage: false)

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      if let error, !error.isEmpty {
        session.messages[index].text = "오류: \(error)"
      } else if session.messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        session.messages[index].text = message ?? ""
      }
    }

    if error?.isEmpty ?? true {
      applyTodoToolCalls(to: assistantId, in: sessionId)
    }

    isGenerating = false
    activeAssistantMessageId = nil
    activeRequestSessionId = nil
    endGenerationBackgroundTaskIfNeeded()
    rebuildLocalMemoryIndex()

    if queuedDrafts.isEmpty {
      syncDynamicIslandLiveActivity()
    } else {
      scheduleNextQueuedDraft()
    }
  }

  func startSearchProgress(assistantId: String, sessionId: String) {
    stopSearchProgress(for: assistantId, in: sessionId, clearMessage: false)
    let startedAt = Date()
    updateSearchProgress(startedAt: startedAt, assistantId: assistantId, sessionId: sessionId)

    searchProgressTasks[assistantId] = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled else {
          break
        }
        await MainActor.run { [weak self] in
          self?.updateSearchProgress(startedAt: startedAt, assistantId: assistantId, sessionId: sessionId)
        }
      }
    }
  }

  func stopSearchProgress(for assistantId: String, in sessionId: String, clearMessage: Bool) {
    searchProgressTasks[assistantId]?.cancel()
    searchProgressTasks[assistantId] = nil

    guard clearMessage else {
      return
    }

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }),
            isSearchProgressText(session.messages[index].text)
      else {
        return
      }

      session.messages[index].text = ""
    }
  }

  func updateSearchProgress(startedAt: Date, assistantId: String, sessionId: String) {
    guard activeAssistantMessageId == assistantId,
          activeRequestSessionId == sessionId,
          isGenerating
    else {
      stopSearchProgress(for: assistantId, in: sessionId, clearMessage: false)
      return
    }

    let elapsed = max(0, Int(Date().timeIntervalSince(startedAt)))
    let minutes = elapsed / 60
    let seconds = elapsed % 60
    let elapsedText: String
    if minutes > 0 {
      elapsedText = String(format: "%dm %02ds", minutes, seconds)
    } else {
      elapsedText = String(format: "%02ds", seconds)
    }
    let progressText = "\(elapsedText) 동안 검색하는 중..."

    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }),
            session.messages[index].text.isEmpty || isSearchProgressText(session.messages[index].text)
      else {
        return
      }

      session.messages[index].text = progressText
    }
  }

  func isSearchProgressText(_ text: String) -> Bool {
    text.contains("동안 검색하는 중...")
  }

  func applySearchSources(_ sources: [NativeSearchSourceReference], to assistantId: String, in sessionId: String) {
    mutateSession(sessionId) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].sourceReferences = sources
    }
  }
}
