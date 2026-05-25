import Foundation

@MainActor
extension NativeChatStore {
  func appendChunk(_ chunk: String, to assistantId: String, in sessionId: String) {
    guard isGenerating, activeAssistantMessageId == assistantId else {
      return
    }

    pendingStreamChunks[assistantId, default: ""] += chunk
    scheduleStreamFlush(to: assistantId, in: sessionId)
  }

  func scheduleStreamFlush(to assistantId: String, in sessionId: String) {
    guard streamFlushTasks[assistantId] == nil else {
      return
    }

    streamFlushTasks[assistantId] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: self?.streamFlushIntervalNanoseconds ?? 80_000_000)
      await MainActor.run { [weak self] in
        self?.flushPendingStreamChunks(to: assistantId, in: sessionId, persist: false)
      }
    }
  }

  func flushPendingStreamChunks(to assistantId: String, in sessionId: String, persist: Bool) {
    streamFlushTasks[assistantId]?.cancel()
    streamFlushTasks[assistantId] = nil

    guard let pending = pendingStreamChunks[assistantId],
          !pending.isEmpty,
          isGenerating,
          activeAssistantMessageId == assistantId
    else {
      pendingStreamChunks[assistantId] = nil
      return
    }

    pendingStreamChunks[assistantId] = nil

    mutateSession(sessionId, persist: persist, resort: persist) { session in
      guard let index = session.messages.firstIndex(where: { $0.id == assistantId }) else {
        return
      }
      if isSearchProgressText(session.messages[index].text) {
        session.messages[index].text = ""
      }
      session.messages[index].text += pending
    }
  }

  func resetPendingStreamBuffer(for assistantId: String) {
    streamFlushTasks[assistantId]?.cancel()
    streamFlushTasks[assistantId] = nil
    pendingStreamChunks[assistantId] = nil
  }

}
