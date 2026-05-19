import Foundation
import UIKit

enum NativePromptCompressor {
  static let maxModelTokens = 4_096
  static let responseReserveTokens = 820
  static let maxInputTokens = maxModelTokens - responseReserveTokens
  static let historyTokens = 920
  static let searchTokens = 1_180
  static let instructionTokens = 240
  static let currentRequestTokens = 1_180

  static func estimatedTokens(_ text: String) -> Int {
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

  static func clipped(_ text: String, maxEstimatedTokens: Int, keepTail: Bool = false) -> String {
    guard maxEstimatedTokens > 0,
          estimatedTokens(text) > maxEstimatedTokens
    else {
      return text
    }

    let marker = keepTail ? "... [앞부분 압축]\n" : "\n... [이후 내용 압축]"
    let markerTokens = estimatedTokens(marker)
    let targetTokens = max(1, maxEstimatedTokens - markerTokens)
    var selected = ""
    var usedTokens = 0
    let characters = keepTail ? Array(text.reversed()) : Array(text)

    for character in characters {
      let cost = max(0, estimatedTokens(String(character)))
      if usedTokens + cost > targetTokens {
        break
      }

      if keepTail {
        selected.insert(character, at: selected.startIndex)
      } else {
        selected.append(character)
      }
      usedTokens += cost
    }

    let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
    return keepTail ? marker + trimmed : trimmed + marker
  }

  static func clippedPreservingEdges(_ text: String, maxEstimatedTokens: Int) -> String {
    guard estimatedTokens(text) > maxEstimatedTokens else {
      return text
    }

    let marker = "\n\n[중간 컨텍스트 압축]\n\n"
    let markerTokens = estimatedTokens(marker)
    let edgeBudget = max(1, (maxEstimatedTokens - markerTokens) / 2)
    return clipped(text, maxEstimatedTokens: edgeBudget)
      + marker
      + clipped(text, maxEstimatedTokens: edgeBudget, keepTail: true)
  }

  static func containsCompressionMarker(_ text: String) -> Bool {
    text.contains("[중간 컨텍스트 압축]")
      || text.contains("[앞부분 압축]")
      || text.contains("[이후 내용 압축]")
      || (
        text.contains("Earlier ")
          && text.contains(" messages were omitted.")
      )
  }

  static func clippedCurrentRequest(_ text: String, maxEstimatedTokens: Int) -> String {
    if shouldPreserveStructure(text) {
      return clippedPreservingEdges(text, maxEstimatedTokens: maxEstimatedTokens)
    }
    return clipped(text, maxEstimatedTokens: maxEstimatedTokens, keepTail: true)
  }

  static func clippedMessageBody(_ text: String, maxEstimatedTokens: Int) -> String {
    if shouldPreserveStructure(text) {
      return clippedPreservingEdges(text, maxEstimatedTokens: maxEstimatedTokens)
    }
    return clipped(text, maxEstimatedTokens: maxEstimatedTokens, keepTail: true)
  }

  static func shouldPreserveStructure(_ text: String) -> Bool {
    let lower = text.lowercased()
    let lineCount = text.filter { $0 == "\n" }.count
    return lineCount >= 8
      || text.contains("```")
      || lower.contains("func ")
      || lower.contains("class ")
      || lower.contains("struct ")
      || lower.contains("import ")
      || lower.contains("const ")
      || lower.contains("let ")
      || lower.contains("var ")
      || lower.contains("return ")
      || lower.contains("error:")
      || lower.contains("exception")
      || lower.contains("stack trace")
  }
}
