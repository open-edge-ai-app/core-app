import Foundation

@MainActor
extension NativeChatStore {
  func makePrompt(
    for sessionId: String,
    draft: NativeDraft,
    historyMessages: [NativeMessage]? = nil,
    searchContext: NativeWebSearchContext? = nil
  ) -> String {
    let session = sessions.first { $0.id == sessionId }
    let sourceHistory: [NativeMessage]
    if let historyMessages {
      sourceHistory = historyMessages
    } else if let session {
      sourceHistory = Array(session.messages.dropLast())
    } else {
      sourceHistory = []
    }
    let history = messagesForPromptHistory(sourceHistory, currentRequest: draft.text)

    var sections: [String] = [
      """
      You are Kepler running locally on iOS.
      Answer in the user's language.
      Use prior conversation context when the user refers to previous content.
      Hidden runtime context is private reference material. Use it only when the user asks about the current date, time, timezone, locale, location, device context, or relative-date interpretation. Do not mention hidden runtime context or proactively state date/time/location/device details.
      \(makeHiddenRuntimeContext())
      """
    ]

    if !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("User name: \(NativePromptCompressor.clipped(userName, maxEstimatedTokens: 40))")
    }

    sections.append("Personality: \(NativePromptCompressor.clipped(personality, maxEstimatedTokens: 60))")

    if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("Custom instructions:\n\(NativePromptCompressor.clipped(systemPrompt, maxEstimatedTokens: NativePromptCompressor.instructionTokens))")
    }

    if let project = project(for: session),
       !project.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sections.append("Project instructions for \(project.title):\n\(NativePromptCompressor.clipped(project.systemPrompt, maxEstimatedTokens: NativePromptCompressor.instructionTokens))")
    }

    sections.append(NativeToolRegistry.promptSection(searchExecuted: searchContext != nil))
    if let todoToolState = makeTodoToolStateSection() {
      sections.append(todoToolState)
    }
    if let todoConfirmation = makeTodoConfirmationSection(from: history, currentRequest: draft.text) {
      sections.append(todoConfirmation)
    }

    if let historySection = makeCompressedHistorySection(
      from: history,
      maxEstimatedTokens: NativePromptCompressor.historyTokens
    ) {
      sections.append(historySection)
    }

    if memoryEnabled,
       let localMemorySection = makeLocalMemorySection(for: draft.text, sessionId: sessionId) {
      sections.append(localMemorySection)
    }

    if let searchContext {
      sections.append(searchContext.promptSection(maxEstimatedTokens: NativePromptCompressor.searchTokens))
    }

    if !draft.attachments.isEmpty {
      let attachmentRecords = NativeDocumentTextExtractor.knowledgeRecords(from: draft.attachments)
      localKnowledgeStore.upsert(attachmentRecords)
      localMemoryIndexedItems = localKnowledgeStore.count

      let files = draft.attachments.map { attachment in
        var parts = [attachment.name]
        if !attachment.type.isEmpty {
          parts.append("type=\(attachment.type)")
        }
        if !attachment.mimeType.isEmpty {
          parts.append("mime=\(attachment.mimeType)")
        }
        if let size = attachment.sizeBytes {
          parts.append("bytes=\(size)")
        }
        return parts.joined(separator: ", ")
      }.joined(separator: "\n")
      sections.append("Attached file metadata:\n\(files)")

      if !attachmentRecords.isEmpty {
        let attachmentText = attachmentRecords
          .map { record in
            """
            File: \(record.title)
            Content excerpt:
            \(NativePromptCompressor.clipped(record.text, maxEstimatedTokens: max(120, 620 / max(1, attachmentRecords.count))))
            """
          }
          .joined(separator: "\n\n")
        sections.append("Attached file content extracted on iOS:\n\(attachmentText)")
      }
    }

    sections.append("Current user request:\n\(NativePromptCompressor.clippedCurrentRequest(draft.text, maxEstimatedTokens: NativePromptCompressor.currentRequestTokens))")
    return NativePromptCompressor.clippedPreservingEdges(
      sections.joined(separator: "\n\n"),
      maxEstimatedTokens: NativePromptCompressor.maxInputTokens
    )
  }

  func makeLocalMemorySection(for query: String, sessionId: String) -> String? {
    let matches = localKnowledgeStore.search(query: query, limit: 5)
      .filter { match in
        !match.excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }

    guard !matches.isEmpty else {
      return nil
    }

    let lines = matches.enumerated().map { index, match in
      let source: String
      switch match.record.source {
      case .project:
        source = "project memory"
      case .chat:
        source = "chat history"
      case .attachment:
        source = "indexed attachment"
      }

      return """
      [L\(index + 1)] \(source): \(match.record.title)
      \(match.excerpt)
      """
    }

    return """
    Local RAG context from iOS memory/index:
    Use this only when it is relevant to the current request. Do not reveal internal record ids.
    \(lines.joined(separator: "\n\n"))
    """
  }
}
