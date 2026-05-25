import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIEngineFoundationModelError: LocalizedError {
  case unavailable(String)

  var errorDescription: String? {
    switch self {
    case .unavailable(let message):
      return message
    }
  }
}

extension AIEngineFoundationModelClient {
  func generateText(for prompt: String) async throws -> String {
    try Task.checkCancellation()

    #if canImport(FoundationModels)
    if #available(iOS 26.0, *), foundationModelIsAvailable() {
      loaded = true
      return try await generateWithFoundationModels(prompt: prompt)
    }
    #endif

    loaded = false
    throw AIEngineFoundationModelError.unavailable(foundationModelAvailabilityDescription())
  }

  func streamText(for prompt: String, onChunk: @escaping (NSString) -> Void) async throws -> String {
    try Task.checkCancellation()

    #if canImport(FoundationModels)
    if #available(iOS 26.0, *), foundationModelIsAvailable() {
      loaded = true
      return try await streamWithFoundationModels(prompt: prompt, onChunk: onChunk)
    }
    #endif

    loaded = false
    throw AIEngineFoundationModelError.unavailable(foundationModelAvailabilityDescription())
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  func generateWithFoundationModels(prompt: String) async throws -> String {
    let session = LanguageModelSession(model: .default, instructions: baseInstructions)
    let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: maximumResponseTokens(for: prompt))
    let response = try await session.respond(to: prompt, options: options)
    return cleanResponse(response.content)
  }

  @available(iOS 26.0, *)
  func streamWithFoundationModels(
    prompt: String,
    onChunk: @escaping (NSString) -> Void
  ) async throws -> String {
    let session = LanguageModelSession(model: .default, instructions: baseInstructions)
    let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: maximumResponseTokens(for: prompt))
    let stream = session.streamResponse(to: prompt, options: options)
    var previous = ""

    for try await snapshot in stream {
      try Task.checkCancellation()
      let current = snapshot.content

      if current.count > previous.count {
        let delta = String(current.dropFirst(previous.count))
        if !delta.isEmpty {
          onChunk(delta as NSString)
        }
      }

      previous = current
    }

    return cleanResponse(previous)
  }
  #endif

  func maximumResponseTokens(for prompt: String) -> Int {
    estimatedTokens(prompt) > 3_000 ? 760 : 900
  }

  func estimatedTokens(_ text: String) -> Int {
    var tokens = 0
    var asciiRun = 0

    func flushAsciiRun() {
      if asciiRun > 0 {
        tokens += max(1, (asciiRun + 3) / 4)
        asciiRun = 0
      }
    }

    for scalar in text.unicodeScalars {
      if CharacterSet.whitespacesAndNewlines.contains(scalar) {
        flushAsciiRun()
        continue
      }

      if scalar.value < 128, CharacterSet.alphanumerics.contains(scalar) {
        asciiRun += 1
        continue
      }

      flushAsciiRun()
      tokens += 1
    }

    flushAsciiRun()
    return tokens
  }

  private func splitForStreaming(_ text: String) -> [String] {
    let chunks = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)

    if chunks.isEmpty {
      return text.isEmpty ? [] : [text]
    }

    var result: [String] = []
    var searchStart = text.startIndex

    for chunk in chunks {
      guard let range = text[searchStart...].range(of: chunk) else {
        result.append(chunk)
        continue
      }

      if range.lowerBound > searchStart {
        result.append(String(text[searchStart..<range.lowerBound]))
      }
      result.append(String(text[range]))
      searchStart = range.upperBound
    }

    if searchStart < text.endIndex {
      result.append(String(text[searchStart..<text.endIndex]))
    }

    return result
  }

  func cleanResponse(_ text: String) -> String {
    text
      .replacingOccurrences(of: "<turn>", with: "")
      .replacingOccurrences(of: "</turn>", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func makeTitle(from userMessage: String, assistantMessage: String) -> String {
    let source = [userMessage, assistantMessage]
      .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty } ?? "새 채팅"

    return cleanTitle(source, fallback: "새 채팅")
  }

  func cleanTitle(_ title: String, fallback: String) -> String {
    let cleaned = title
      .replacingOccurrences(of: "\"", with: "")
      .replacingOccurrences(of: "'", with: "")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "#", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleaned.isEmpty else {
      return fallback
    }

    return cleaned.count <= 24 ? cleaned : "\(cleaned.prefix(24))..."
  }

  func foundationModelIsAvailable() -> Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return SystemLanguageModel.default.isAvailable
    }
    #endif

    return false
  }

  func foundationModelAvailabilityDescription() -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return "Apple Foundation Models 사용 가능"
      case .unavailable(.deviceNotEligible):
        return "현재 기기는 Apple Intelligence 시스템 모델을 지원하지 않습니다."
      case .unavailable(.appleIntelligenceNotEnabled):
        return "Apple Intelligence가 꺼져 있습니다."
      case .unavailable(.modelNotReady):
        return "Apple Intelligence 모델이 아직 준비되지 않았습니다."
      @unknown default:
        return "Apple Foundation Models 상태를 확인할 수 없습니다."
      }
    }
    #endif

    return "Foundation Models는 iOS 26 이상에서 사용할 수 있습니다."
  }
}
