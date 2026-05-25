import Foundation

@MainActor
extension NativeChatStore {
  func messagesForPromptHistory(_ messages: [NativeMessage], currentRequest: String) -> [NativeMessage] {
    var history = messages
    if let last = history.last,
       last.role == .user,
       normalizedPromptText(last.text) == normalizedPromptText(currentRequest) {
      history.removeLast()
    }
    return history
  }

  func makeTodoConfirmationSection(from messages: [NativeMessage], currentRequest: String) -> String? {
    guard isAffirmativeTodoConfirmation(currentRequest) else {
      return nil
    }

    guard let assistantIndex = messages.indices.reversed().first(where: { index in
      messages[index].role == .assistant && isTodoRegistrationQuestion(messages[index].text)
    }) else {
      return nil
    }

    let priorMessages = messages[..<assistantIndex]
    guard let scheduleMessage = priorMessages.reversed().first(where: { message in
      message.role == .user && NativeToolRegistry.shouldUseTodoTool(message.text)
    }) else {
      return nil
    }

    let scheduleText = NativePromptCompressor.clippedMessageBody(
      normalizedPromptText(scheduleMessage.text),
      maxEstimatedTokens: 90
    )

    return """
    Todo confirmation carry-over:
    - The current user message is an affirmative response to the assistant asking whether to register a Todo/schedule.
    - Create the Todo now by using this previous user schedule statement as the source: \(scheduleText)
    - Do not ask for confirmation again.
    - Emit a todo_create openedge_tool block and keep the visible answer brief.
    """
  }

  func isAffirmativeTodoConfirmation(_ text: String) -> Bool {
    let normalized = normalizedPromptText(text).lowercased()
    guard !normalized.isEmpty, normalized.count <= 40 else {
      return false
    }

    let affirmativeTerms = [
      "네", "응", "그래", "좋아", "알겠", "맞아", "등록", "추가", "해줘", "부탁", "ㅇㅋ",
      "ok", "okay", "yes", "yep", "sure", "please", "do it"
    ]
    return affirmativeTerms.contains { normalized.contains($0) }
  }

  func isTodoRegistrationQuestion(_ text: String) -> Bool {
    let normalized = normalizedPromptText(text).lowercased()
    let questionTerms = [
      "등록해 드릴까요", "등록해드릴까요", "등록할까요", "일정으로 등록", "todo로 등록",
      "할 일로 등록", "추가해 드릴까요", "추가해드릴까요", "추가할까요", "저장해 드릴까요",
      "저장해드릴까요", "would you like me to add", "should i add", "add this to"
    ]
    return questionTerms.contains { normalized.contains($0) }
  }

  func makeCompressedHistorySection(from messages: [NativeMessage], maxEstimatedTokens: Int) -> String? {
    let meaningfulMessages = messages.filter { message in
      !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !message.attachments.isEmpty
    }

    guard !meaningfulMessages.isEmpty else {
      return nil
    }

    var reversedEntries: [String] = []
    var usedTokens = NativePromptCompressor.estimatedTokens("Conversation history")

    for message in meaningfulMessages.reversed() {
      let role = message.role == .assistant ? "assistant" : "user"
      let perMessageLimit = message.role == .assistant ? 150 : 130
      let sourceText = NativePromptCompressor.shouldPreserveStructure(message.text)
        ? message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        : normalizedPromptText(message.text)
      var body = NativePromptCompressor.clippedMessageBody(
        sourceText,
        maxEstimatedTokens: perMessageLimit,
      )

      if body.isEmpty, !message.attachments.isEmpty {
        body = "첨부 파일: " + message.attachments.map(\.name).joined(separator: ", ")
      } else if !message.attachments.isEmpty {
        body += "\n첨부 파일: " + message.attachments.map(\.name).joined(separator: ", ")
      }

      let entry = "\(role): \(body)"
      let entryTokens = NativePromptCompressor.estimatedTokens(entry)
      if usedTokens + entryTokens > maxEstimatedTokens {
        break
      }

      reversedEntries.append(entry)
      usedTokens += entryTokens
    }

    guard !reversedEntries.isEmpty else {
      return nil
    }

    let omittedCount = max(0, meaningfulMessages.count - reversedEntries.count)
    var lines = ["Conversation history (compressed to fit the on-device model context):"]
    if omittedCount > 0 {
      lines.append("Earlier \(omittedCount) messages were omitted. Prioritize the recent turns below.")
    }
    lines.append(contentsOf: reversedEntries.reversed())
    return lines.joined(separator: "\n")
  }

  func normalizedPromptText(_ text: String) -> String {
    text
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

}
