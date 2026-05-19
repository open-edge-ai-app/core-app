import Foundation
import EventKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

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
      You are Open Edge AI running locally on iOS.
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

  func messagesForPromptHistory(_ messages: [NativeMessage], currentRequest: String) -> [NativeMessage] {
    var history = messages
    if let last = history.last,
       last.role == .user,
       normalizedPromptText(last.text) == normalizedPromptText(currentRequest) {
      history.removeLast()
    }
    return history
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

  func project(for session: NativeChatSession?) -> NativeProject? {
    guard let projectId = session?.projectId else {
      return nil
    }
    return projects.first { $0.id == projectId }
  }

  func makeHiddenRuntimeContext() -> String {
    let now = Date()
    let locale = Locale.current
    let localeParts = locale.identifier
      .replacingOccurrences(of: "-", with: "_")
      .split(separator: "_")
      .map(String.init)
    let languageCode = localeParts.first ?? "unknown"
    let regionCode = localeParts.dropFirst().first { $0.count == 2 } ?? "unknown"
    let timeZone = TimeZone.current
    deviceContextProvider.refreshLocationIfAuthorized()

    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: selectedLanguage.localeIdentifier)
    displayFormatter.timeZone = timeZone
    displayFormatter.dateStyle = .full
    displayFormatter.timeStyle = .medium

    let localISOFormatter = ISO8601DateFormatter()
    localISOFormatter.timeZone = timeZone
    localISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let utcISOFormatter = ISO8601DateFormatter()
    utcISOFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    utcISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var lines = [
      "Local date/time: \(displayFormatter.string(from: now))",
      "Local ISO timestamp: \(localISOFormatter.string(from: now))",
      "UTC timestamp: \(utcISOFormatter.string(from: now))",
      "Timezone: \(timeZone.identifier), \(timeZone.abbreviation(for: now) ?? "unknown"), \(gmtOffset(seconds: timeZone.secondsFromGMT(for: now)))",
      "Device locale: \(locale.identifier)",
      "Device language: \(languageCode)",
      "Device region: \(regionCode)",
      "App response locale: \(selectedLanguage.localeIdentifier)",
      "Calendar: \(String(describing: Calendar.current.identifier))",
      "Device: \(UIDevice.current.model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    ]

    lines.append(contentsOf: deviceContextProvider.locationContextLines(now: now))
    return "Hidden runtime context:\n" + lines.map { "- \($0)" }.joined(separator: "\n")
  }

  func gmtOffset(seconds: Int) -> String {
    let sign = seconds >= 0 ? "+" : "-"
    let absoluteSeconds = abs(seconds)
    let hours = absoluteSeconds / 3600
    let minutes = (absoluteSeconds % 3600) / 60
    return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
  }
}
