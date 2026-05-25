import Foundation
import PDFKit
import UIKit
import Vision

enum NativeDocumentTextExtractor {
  static func knowledgeRecords(from attachments: [NativeAttachment]) -> [NativeKnowledgeRecord] {
    attachments.compactMap { attachment in
      guard let text = extractedText(from: attachment), !text.isEmpty else {
        return nil
      }
      return NativeKnowledgeRecord(
        id: "attachment:\(attachment.id)",
        source: .attachment,
        title: attachment.name,
        text: text,
        url: attachment.url,
        updatedAt: Date()
      )
    }
  }

  static func promptText(from attachments: [NativeAttachment], maxTokens: Int) -> String? {
    let records = knowledgeRecords(from: attachments)
    guard !records.isEmpty else {
      return nil
    }

    let text = records
      .map { record in
        """
        File: \(record.title)
        Content excerpt:
        \(NativePromptCompressor.clipped(record.text, maxEstimatedTokens: max(120, maxTokens / max(1, records.count))))
        """
      }
      .joined(separator: "\n\n")
    return NativePromptCompressor.clipped(text, maxEstimatedTokens: maxTokens)
  }

  private static func extractedText(from attachment: NativeAttachment) -> String? {
    guard let url = URL(string: attachment.url), url.isFileURL else {
      return nil
    }

    let hasAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    if attachment.mimeType == "application/pdf" || url.pathExtension.lowercased() == "pdf" {
      return pdfText(from: url)
    }

    if attachment.type == "image" {
      return recognizedText(from: url)
    }

    if isTextLike(attachment: attachment, url: url) {
      return textFileContents(from: url)
    }

    return nil
  }

  private static func isTextLike(attachment: NativeAttachment, url: URL) -> Bool {
    let mime = attachment.mimeType.lowercased()
    let ext = url.pathExtension.lowercased()
    return mime.hasPrefix("text/") ||
      mime.contains("json") ||
      mime.contains("xml") ||
      ["txt", "md", "markdown", "json", "csv", "tsv", "xml", "html", "css", "js", "ts", "tsx", "jsx", "swift", "kt", "java", "py", "go", "rs", "c", "cpp", "h"].contains(ext)
  }

  private static func textFileContents(from url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else {
      return nil
    }
    defer {
      try? handle.close()
    }

    let data = handle.readData(ofLength: 700_000)
    return String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .utf16)
      ?? String(data: data, encoding: .isoLatin1)
  }

  private static func pdfText(from url: URL) -> String? {
    guard let document = PDFDocument(url: url) else {
      return nil
    }

    var parts: [String] = []
    let pageLimit = min(document.pageCount, 24)
    for index in 0..<pageLimit {
      if let pageText = document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
         !pageText.isEmpty {
        parts.append(pageText)
      }
    }
    return parts.joined(separator: "\n\n")
  }

  private static func recognizedText(from url: URL) -> String? {
    guard let image = UIImage(contentsOfFile: url.path)?.cgImage else {
      return nil
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["ko-KR", "en-US"]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return nil
    }

    return request.results?
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
