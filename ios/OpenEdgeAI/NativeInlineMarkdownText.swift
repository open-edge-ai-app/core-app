import Foundation
import SwiftUI
import UIKit

struct NativeInlineMarkdownText: View {
  private struct CitationGroup {
    let range: Range<String.Index>
    let numbers: [Int]
  }

  @EnvironmentObject private var store: NativeChatStore
  let text: String
  let sources: [NativeSearchSourceReference]
  let fontSize: CGFloat
  let fontWeight: Font.Weight
  let textColor: Color
  let onOpenSource: (Int) -> Void

  var body: some View {
    if containsValidCitations {
      NativeInteractiveAttributedText(
        attributedText: interactiveAttributedText,
        onOpenSource: onOpenSource
      )
    } else {
      Text(attributedText)
        .font(.system(size: fontSize, weight: fontWeight))
        .foregroundColor(textColor)
    }
  }

  private var attributedText: AttributedString {
    attributedStringWithCitationTags()
  }

  private var interactiveAttributedText: NSAttributedString {
    let groups = citationGroups
    let result = NSMutableAttributedString()

    guard !groups.isEmpty else {
      return styledMarkdownAttributedString(from: text)
    }

    var cursor = text.startIndex

    for group in groups {
      if group.range.lowerBound > cursor {
        result.append(styledMarkdownAttributedString(from: String(text[cursor..<group.range.lowerBound])))
      }

      result.append(citationNSAttributedString(for: group.numbers))
      cursor = group.range.upperBound
    }

    if cursor < text.endIndex {
      result.append(styledMarkdownAttributedString(from: String(text[cursor..<text.endIndex])))
    }

    return result
  }

  private var containsValidCitations: Bool {
    !citationGroups.isEmpty
  }

  private func attributedStringWithCitationTags() -> AttributedString {
    let groups = citationGroups

    guard !groups.isEmpty else {
      return markdownAttributedString(from: text)
    }

    var result = AttributedString()
    var cursor = text.startIndex

    for group in groups {
      if group.range.lowerBound > cursor {
        result += markdownAttributedString(from: String(text[cursor..<group.range.lowerBound]))
      }

      result += citationAttributedString(for: group.numbers)
      cursor = group.range.upperBound
    }

    if cursor < text.endIndex {
      result += markdownAttributedString(from: String(text[cursor..<text.endIndex]))
    }

    return result
  }

  private func markdownAttributedString(from text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
  }

  private var citationGroups: [CitationGroup] {
    guard !sources.isEmpty else {
      return []
    }

    let citationPattern = #"\[((?:\s*\d{1,2}\s*,)*\s*\d{1,2}\s*)\]"#
    let regex = try? NSRegularExpression(pattern: citationPattern)
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = regex?.matches(in: text, range: nsRange) ?? []

    return matches.compactMap { match in
      guard match.numberOfRanges >= 2,
            let fullRange = Range(match.range(at: 0), in: text),
            let numbersRange = Range(match.range(at: 1), in: text)
      else {
        return nil
      }

      let numbers = citationNumbers(from: text[numbersRange])
      return numbers.isEmpty ? nil : CitationGroup(range: fullRange, numbers: numbers)
    }
  }

  private func citationNumbers(from text: Substring) -> [Int] {
    var seen = Set<Int>()
    return text
      .split(separator: ",")
      .compactMap { value in
        Int(String(value).trimmingCharacters(in: .whitespacesAndNewlines))
      }
      .filter { number in
        guard (1...sources.count).contains(number),
              !seen.contains(number)
        else {
          return false
        }
        seen.insert(number)
        return true
      }
  }

  private func citationAttributedString(for numbers: [Int]) -> AttributedString {
    var result = AttributedString()

    for (index, number) in numbers.enumerated() {
      if index > 0 {
        result += AttributedString(" ")
      }
      result += citationAttributedString(number)
    }

    return result
  }

  private func citationAttributedString(_ number: Int) -> AttributedString {
    var tag = AttributedString(" \(number) ")
    tag.link = URL(string: "openedgeai-source://\(number)")
    tag.foregroundColor = store.accentColor.color
    tag.backgroundColor = store.accentColor.color.opacity(0.22)
    tag.font = .system(size: max(11, store.fontSizeSetting.bodySize - 3), weight: .semibold)
    return tag
  }

  private func styledMarkdownAttributedString(from text: String) -> NSAttributedString {
    let markdown = markdownAttributedString(from: text)
    let attributed = NSMutableAttributedString(attributedString: NSAttributedString(markdown))
    let fullRange = NSRange(location: 0, length: attributed.length)
    guard fullRange.length > 0 else {
      return attributed
    }

    attributed.addAttributes([
      .font: UIFont.systemFont(ofSize: fontSize, weight: uiFontWeight),
      .foregroundColor: UIColor(textColor)
    ], range: fullRange)

    let intentKey = NSAttributedString.Key("NSInlinePresentationIntent")
    attributed.enumerateAttribute(intentKey, in: fullRange) { value, range, _ in
      guard let rawValue = (value as? NSNumber)?.intValue else {
        return
      }

      var font = UIFont.systemFont(ofSize: fontSize, weight: uiFontWeight)
      if rawValue & 4 != 0 {
        font = UIFont.monospacedSystemFont(ofSize: max(12, fontSize - 1), weight: .regular)
        attributed.addAttribute(
          .backgroundColor,
          value: UIColor.secondarySystemFill,
          range: range
        )
      } else if rawValue & 2 != 0 {
        font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
      }

      if rawValue & 1 != 0,
         let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
        font = UIFont(descriptor: descriptor, size: fontSize)
      }

      if rawValue & 32 != 0 {
        attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
      }

      attributed.addAttribute(.font, value: font, range: range)
    }

    return attributed
  }

  private func citationNSAttributedString(for numbers: [Int]) -> NSAttributedString {
    let result = NSMutableAttributedString()

    for (index, number) in numbers.enumerated() {
      if index > 0 {
        result.append(NSAttributedString(string: " "))
      }
      result.append(citationNSAttributedString(number))
    }

    return result
  }

  private func citationNSAttributedString(_ number: Int) -> NSAttributedString {
    let accentColor = UIColor(store.accentColor.color)
    let font = UIFont.systemFont(ofSize: max(11, fontSize - 3), weight: .bold)
    let image = NativeCitationTagRenderer.image(
      number: number,
      font: font,
      accentColor: accentColor
    )
    let attachment = NSTextAttachment()
    attachment.image = image
    attachment.bounds = CGRect(x: 0, y: -3, width: image.size.width, height: image.size.height)

    let tag = NSMutableAttributedString(attachment: attachment)
    tag.addAttributes(
      [.link: URL(string: "openedgeai-source://\(number)")!],
      range: NSRange(location: 0, length: tag.length)
    )
    return tag
  }

  private var uiFontWeight: UIFont.Weight {
    switch fontWeight {
    case .bold:
      return .bold
    case .semibold:
      return .semibold
    case .medium:
      return .medium
    default:
      return .regular
    }
  }
}
