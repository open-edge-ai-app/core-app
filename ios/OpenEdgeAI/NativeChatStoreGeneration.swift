import Foundation

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
    resetPendingStreamBuffer(for: assistantId)
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
    mutateSession(sessionId, persist: false, resort: false) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }

      session.messages[index].contextCompressed = isCompressed
    }
  }


  func finishGeneration(message: String?, error: String?, assistantId: String, sessionId: String) {
    guard activeAssistantMessageId == assistantId else {
      return
    }

    flushPendingStreamChunks(to: assistantId, in: sessionId, persist: true)
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
}
