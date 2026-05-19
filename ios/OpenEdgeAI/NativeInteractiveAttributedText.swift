import Foundation
import SwiftUI
import UIKit

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
