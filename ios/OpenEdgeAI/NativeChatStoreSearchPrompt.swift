import Foundation

@MainActor
extension NativeChatStore {
  func makeDraftInput(from rawText: String) -> (text: String, mode: NativeDraftMode) {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

    if let searchPayload = NativeSlashCommand.searchPayload(in: trimmed) {
      let requestText = searchPayload.trimmingCharacters(in: .whitespacesAndNewlines)
      return (requestText.isEmpty ? searchFallbackRequestText : requestText, .search)
    }

    return (trimmed, .standard)
  }

  func makeSearchQuery(
    for sessionId: String,
    draft: NativeDraft,
    historyMessages: [NativeMessage]? = nil
  ) -> String {
    let session = sessions.first { $0.id == sessionId }
    let sourceHistory: [NativeMessage]
    if let historyMessages {
      sourceHistory = historyMessages
    } else if let session {
      sourceHistory = Array(session.messages.dropLast(2))
    } else {
      sourceHistory = []
    }

    let promptHistory = messagesForPromptHistory(sourceHistory, currentRequest: draft.text)
    let explicitRequest = draft.text == searchFallbackRequestText ? "" : draft.text
    let historyText = promptHistory
      .suffix(8)
      .map(\.text)
      .map { $0.replacingOccurrences(of: "\n", with: " ") }
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: " ")

    let rawQuery = explicitRequest.isEmpty ? historyText : "\(historyText) \(explicitRequest)"
    let cleaned = NativePromptCompressor.clipped(rawQuery, maxEstimatedTokens: 120, keepTail: true)
      .replacingOccurrences(of: "... [앞부분 압축]\n", with: "")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if cleaned.isEmpty {
      return draft.text
    }

    return cleaned.count > 260 ? String(cleaned.prefix(260)) : cleaned
  }

}
