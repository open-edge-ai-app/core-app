import Foundation

@MainActor
extension NativeChatStore {
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

    mutateSession(sessionId, persist: false, resort: false) { session in
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

    mutateSession(sessionId, persist: false, resort: false) { session in
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
