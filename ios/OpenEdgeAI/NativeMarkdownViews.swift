import Foundation
import SwiftUI
import UIKit

struct NativeMarkdownText: View {
  let text: String
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(markdownBlocks) { block in
        NativeMarkdownBlockView(block: block, sources: sources, onOpenSource: onOpenSource)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var markdownBlocks: [NativeMarkdownBlock] {
    NativeMarkdownParser.parse(text)
  }
}

struct NativeMarkdownBlock: Identifiable {
  enum Kind {
    case paragraph(String)
    case heading(level: Int, text: String)
    case unorderedList([String])
    case orderedList([String])
    case quote(String)
    case code(language: String?, text: String)
    case divider
  }

  let id = UUID()
  let kind: Kind
}

enum NativeMarkdownParser {
  static func parse(_ markdown: String) -> [NativeMarkdownBlock] {
    let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")
    var blocks: [NativeMarkdownBlock] = []
    var paragraphLines: [String] = []
    var index = 0

    func flushParagraph() {
      guard !paragraphLines.isEmpty else {
        return
      }
      blocks.append(.init(kind: .paragraph(paragraphLines.joined(separator: "\n"))))
      paragraphLines.removeAll()
    }

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.isEmpty {
        flushParagraph()
        index += 1
        continue
      }

      if let fence = codeFence(in: trimmed) {
        flushParagraph()
        let language = fence.language
        var codeLines: [String] = []
        index += 1
        while index < lines.count {
          let candidate = lines[index].trimmingCharacters(in: .whitespaces)
          if candidate.hasPrefix(fence.marker) {
            index += 1
            break
          }
          codeLines.append(lines[index])
          index += 1
        }
        blocks.append(.init(kind: .code(language: language, text: codeLines.joined(separator: "\n"))))
        continue
      }

      if let heading = heading(in: trimmed) {
        flushParagraph()
        blocks.append(.init(kind: .heading(level: heading.level, text: heading.text)))
        index += 1
        continue
      }

      if isDivider(trimmed) {
        flushParagraph()
        blocks.append(.init(kind: .divider))
        index += 1
        continue
      }

      if let firstItem = unorderedListItem(in: line) {
        flushParagraph()
        var items = [firstItem]
        index += 1
        while index < lines.count, let item = unorderedListItem(in: lines[index]) {
          items.append(item)
          index += 1
        }
        blocks.append(.init(kind: .unorderedList(items)))
        continue
      }

      if let firstItem = orderedListItem(in: line) {
        flushParagraph()
        var items = [firstItem]
        index += 1
        while index < lines.count, let item = orderedListItem(in: lines[index]) {
          items.append(item)
          index += 1
        }
        blocks.append(.init(kind: .orderedList(items)))
        continue
      }

      if let firstQuote = quoteLine(in: line) {
        flushParagraph()
        var quoteLines = [firstQuote]
        index += 1
        while index < lines.count, let quote = quoteLine(in: lines[index]) {
          quoteLines.append(quote)
          index += 1
        }
        blocks.append(.init(kind: .quote(quoteLines.joined(separator: "\n"))))
        continue
      }

      paragraphLines.append(line)
      index += 1
    }

    flushParagraph()
    return blocks.isEmpty ? [.init(kind: .paragraph(markdown))] : blocks
  }

  private static func codeFence(in line: String) -> (marker: String, language: String?)? {
    let marker: String
    if line.hasPrefix("```") {
      marker = "```"
    } else if line.hasPrefix("~~~") {
      marker = "~~~"
    } else {
      return nil
    }

    let language = line
      .dropFirst(marker.count)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return (marker, language.isEmpty ? nil : language)
  }

  private static func heading(in line: String) -> (level: Int, text: String)? {
    let level = line.prefix { $0 == "#" }.count
    guard (1...6).contains(level),
          line.dropFirst(level).first?.isWhitespace == true
    else {
      return nil
    }

    let text = line.dropFirst(level)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : (level, text)
  }

  private static func isDivider(_ line: String) -> Bool {
    let compact = line.replacingOccurrences(of: " ", with: "")
    return compact.count >= 3 && Set(compact).isSubset(of: ["-"])
      || compact.count >= 3 && Set(compact).isSubset(of: ["*"])
      || compact.count >= 3 && Set(compact).isSubset(of: ["_"])
  }

  private static func unorderedListItem(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    for marker in ["- ", "* ", "+ ", "• "] {
      if trimmed.hasPrefix(marker) {
        let item = trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        return item.isEmpty ? nil : item
      }
    }
    return nil
  }

  private static func orderedListItem(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var digitCount = 0
    for character in trimmed {
      if character.wholeNumberValue == nil {
        break
      }
      digitCount += 1
    }

    guard digitCount > 0 else {
      return nil
    }

    let markerStart = trimmed.dropFirst(digitCount)
    guard markerStart.hasPrefix(". ") || markerStart.hasPrefix(") ") else {
      return nil
    }

    let item = markerStart.dropFirst(2).trimmingCharacters(in: .whitespaces)
    return item.isEmpty ? nil : item
  }

  private static func quoteLine(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix(">") else {
      return nil
    }

    return trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
  }
}

struct NativeMarkdownBlockView: View {
  @EnvironmentObject private var store: NativeChatStore
  let block: NativeMarkdownBlock
  let sources: [NativeSearchSourceReference]
  let onOpenSource: (Int) -> Void

  var body: some View {
    switch block.kind {
    case .paragraph(let text):
      NativeInlineMarkdownText(
        text: text,
        sources: sources,
        fontSize: store.fontSizeSetting.bodySize,
        fontWeight: .regular,
        textColor: .oeText,
        onOpenSource: onOpenSource
      )
        .fixedSize(horizontal: false, vertical: true)

    case .heading(let level, let text):
      NativeInlineMarkdownText(
        text: text,
        sources: sources,
        fontSize: headingFontSize(for: level),
        fontWeight: .semibold,
        textColor: .oeText,
        onOpenSource: onOpenSource
      )
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, level <= 2 ? 4 : 2)

    case .unorderedList(let items):
      VStack(alignment: .leading, spacing: 7) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          listRow(marker: "•", text: item)
        }
      }

    case .orderedList(let items):
      VStack(alignment: .leading, spacing: 7) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          listRow(marker: "\(index + 1).", text: item)
        }
      }

    case .quote(let text):
      HStack(alignment: .top, spacing: 10) {
        RoundedRectangle(cornerRadius: 1)
          .fill(Color.oeBorder)
          .frame(width: 3)

        NativeInlineMarkdownText(
          text: text,
          sources: sources,
          fontSize: store.fontSizeSetting.bodySize,
          fontWeight: .regular,
          textColor: .oeSecondaryText,
          onOpenSource: onOpenSource
        )
          .fixedSize(horizontal: false, vertical: true)
      }

    case .code(let language, let text):
      NativeMarkdownCodeBlock(language: language, code: text)

    case .divider:
      Divider()
        .padding(.vertical, 4)
    }
  }

  private func listRow(marker: String, text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 9) {
      Text(marker)
        .font(.system(size: store.fontSizeSetting.bodySize, weight: .semibold))
        .foregroundColor(.oeSecondaryText)
        .frame(width: 24, alignment: .trailing)

      NativeInlineMarkdownText(
        text: text,
        sources: sources,
        fontSize: store.fontSizeSetting.bodySize,
        fontWeight: .regular,
        textColor: .oeText,
        onOpenSource: onOpenSource
      )
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func headingFontSize(for level: Int) -> CGFloat {
    let base = store.fontSizeSetting.bodySize
    switch level {
    case 1:
      return base + 7
    case 2:
      return base + 5
    case 3:
      return base + 3
    default:
      return base + 1
    }
  }
}

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
    tag.backgroundColor = store.accentColor.color.opacity(0.12)
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

enum NativeCitationTagRenderer {
  static func image(number: Int, font: UIFont, accentColor: UIColor) -> UIImage {
    let text = "\(number)"
    let horizontalPadding: CGFloat = 8
    let verticalPadding: CGFloat = 4
    let textSize = (text as NSString).size(withAttributes: [.font: font])
    let size = CGSize(
      width: ceil(textSize.width + horizontalPadding * 2),
      height: ceil(textSize.height + verticalPadding * 2)
    )

    return UIGraphicsImageRenderer(size: size).image { context in
      let rect = CGRect(origin: .zero, size: size)
      let capsule = UIBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: size.height / 2)

      accentColor.withAlphaComponent(0.10).setFill()
      capsule.fill()

      accentColor.withAlphaComponent(0.28).setStroke()
      capsule.lineWidth = 1
      capsule.stroke()

      let dotSize: CGFloat = 3.5
      let dotRect = CGRect(
        x: 5,
        y: (size.height - dotSize) / 2,
        width: dotSize,
        height: dotSize
      )
      context.cgContext.setFillColor(accentColor.withAlphaComponent(0.92).cgColor)
      context.cgContext.fillEllipse(in: dotRect)

      let textRect = CGRect(
        x: horizontalPadding + 2,
        y: (size.height - textSize.height) / 2 - 0.5,
        width: textSize.width,
        height: textSize.height
      )
      (text as NSString).draw(
        in: textRect,
        withAttributes: [
          .font: font,
          .foregroundColor: accentColor
        ]
      )
    }
  }
}

struct NativeInteractiveAttributedText: UIViewRepresentable {
  let attributedText: NSAttributedString
  let onOpenSource: (Int) -> Void

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.backgroundColor = .clear
    textView.delegate = context.coordinator
    textView.isEditable = false
    textView.isScrollEnabled = false
    textView.isSelectable = true
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainer.lineBreakMode = .byWordWrapping
    textView.adjustsFontForContentSizeCategory = false
    textView.linkTextAttributes = [:]
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let tapGesture = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    tapGesture.cancelsTouchesInView = false
    textView.addGestureRecognizer(tapGesture)
    return textView
  }

  func updateUIView(_ textView: UITextView, context: Context) {
    context.coordinator.onOpenSource = onOpenSource
    if textView.attributedText != attributedText {
      textView.attributedText = attributedText
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    guard let width = proposal.width else {
      return nil
    }

    let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: ceil(size.height))
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onOpenSource: onOpenSource)
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    var onOpenSource: (Int) -> Void

    init(onOpenSource: @escaping (Int) -> Void) {
      self.onOpenSource = onOpenSource
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard gesture.state == .ended,
            let textView = gesture.view as? UITextView,
            let attributedText = textView.attributedText,
            attributedText.length > 0
      else {
        return
      }

      var location = gesture.location(in: textView)
      location.x -= textView.textContainerInset.left
      location.y -= textView.textContainerInset.top

      let layoutManager = textView.layoutManager
      let textContainer = textView.textContainer
      let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
      guard glyphIndex < layoutManager.numberOfGlyphs else {
        return
      }

      let glyphRect = layoutManager.boundingRect(
        forGlyphRange: NSRange(location: glyphIndex, length: 1),
        in: textContainer
      )
      guard glyphRect.insetBy(dx: -10, dy: -8).contains(location) else {
        return
      }

      let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
      let lowerBound = max(0, characterIndex - 3)
      let upperBound = min(attributedText.length - 1, characterIndex + 3)

      for index in lowerBound...upperBound {
        if let url = attributedText.attribute(.link, at: index, effectiveRange: nil) as? URL,
           handle(url: url) == false {
          return
        }
      }
    }

    func textView(
      _ textView: UITextView,
      shouldInteractWith URL: URL,
      in characterRange: NSRange
    ) -> Bool {
      handle(url: URL)
    }

    private func handle(url: URL) -> Bool {
      guard url.scheme == "openedgeai-source" else {
        return true
      }

      let sourceNumber = Int(url.host ?? "") ?? Int(url.lastPathComponent) ?? 1
      DispatchQueue.main.async {
        self.onOpenSource(sourceNumber)
      }
      return false
    }
  }
}

struct NativeMarkdownCodeBlock: View {
  @EnvironmentObject private var store: NativeChatStore
  let language: String?
  let code: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        if let language, !language.isEmpty {
          Text(language.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.oeMutedText)
        }

        Spacer(minLength: 8)

        Button {
          store.copy(code)
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundColor(store.accentColor.color)
        .accessibilityLabel("코드 복사")
      }

      ScrollView(.horizontal, showsIndicators: false) {
        Text(code)
          .font(.system(size: max(12, store.fontSizeSetting.bodySize - 1), design: .monospaced))
          .foregroundColor(.oeText)
          .textSelection(.enabled)
          .fixedSize(horizontal: true, vertical: false)
          .padding(.bottom, 2)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.oeSubtleFill)
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.oeBorder, lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
