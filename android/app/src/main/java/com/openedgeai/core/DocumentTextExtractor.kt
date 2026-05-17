package com.openedgeai.core

import android.content.Context
import android.net.Uri
import java.io.InputStreamReader
import java.io.Reader
import java.util.Locale
import java.util.zip.ZipInputStream

class DocumentTextExtractor(
    context: Context,
) {
    private val appContext = context.applicationContext

    fun readPreview(
        uri: Uri,
        mimeType: String?,
    ): String =
        readDocumentText(uri, mimeType, DOCUMENT_PREVIEW_CHARS)

    fun readDocumentText(
        uri: Uri,
        mimeType: String?,
        maxChars: Int = MAX_DOCUMENT_TEXT_CHARS,
    ): String =
        try {
            when (mimeType?.lowercase(Locale.US)) {
                "text/plain",
                "text/csv",
                "text/markdown",
                "application/json" -> readTextDocument(uri, maxChars)
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ->
                    readDocxDocument(uri, maxChars)
                else -> ""
            }
        } catch (_: Exception) {
            ""
        }

    fun extractRelevantExcerpt(
        text: String,
        query: String,
        maxChars: Int = DOCUMENT_EXCERPT_CHARS,
    ): String {
        val normalizedText = normalizeDocumentBody(text)
        if (normalizedText.isBlank()) {
            return ""
        }

        val terms = query
            .lowercase()
            .split(Regex("""[^0-9A-Za-z\uAC00-\uD7A3]+"""))
            .map { term -> term.trim() }
            .filter { term -> term.length >= 3 }
            .filterNot { term -> term in documentSearchStopWords }
            .distinct()
            .take(12)
        if (terms.isEmpty()) {
            return normalizedText.take(maxChars)
        }

        val paragraphs = text
            .split(Regex("""\n{2,}|(?<=[.!?])\s+"""))
            .map { paragraph -> normalizeDocumentBody(paragraph) }
            .filter { paragraph -> paragraph.length >= 40 }
        val ranked = paragraphs
            .map { paragraph ->
                val lower = paragraph.lowercase()
                val score = terms.count { term -> lower.contains(term) }
                score to paragraph
            }
            .filter { (score, _) -> score > 0 }
            .sortedByDescending { (score, paragraph) -> score * 1000 + paragraph.length.coerceAtMost(500) }
            .map { (_, paragraph) -> paragraph }

        return ranked
            .ifEmpty { paragraphs.take(3) }
            .joinToString(separator = "\n\n")
            .take(maxChars)
            .trim()
            .ifBlank { normalizedText.take(maxChars) }
    }

    fun normalizeDocumentBody(text: String): String =
        text
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun readTextDocument(
        uri: Uri,
        maxChars: Int,
    ): String =
        appContext.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open document: $uri" }
            InputStreamReader(input, Charsets.UTF_8).use { reader ->
                reader.readTextLimited(maxChars)
            }
        }

    private fun readDocxDocument(
        uri: Uri,
        maxChars: Int,
    ): String {
        val text = StringBuilder()
        appContext.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open document: $uri" }
            ZipInputStream(input.buffered()).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.name == "word/document.xml") {
                        val xml = zip.bufferedReader(Charsets.UTF_8).use { reader ->
                            reader.readTextLimited(maxOf(maxChars * 4, DOCX_XML_READ_CHARS))
                        }
                        text.append(
                            xml
                                .replace(Regex("<w:tab\\b[^>]*/>"), "\t")
                                .replace(Regex("</w:p>"), "\n")
                                .replace(Regex("<[^>]+>"), " ")
                                .replace("&amp;", "&")
                                .replace("&lt;", "<")
                                .replace("&gt;", ">")
                                .replace("&quot;", "\"")
                                .replace("&apos;", "'"),
                        )
                        break
                    }
                }
            }
        }
        return normalizeDocumentBody(text.toString()).take(maxChars)
    }

    private fun Reader.readTextLimited(maxChars: Int): String =
        StringBuilder().also { builder ->
            val buffer = CharArray(DEFAULT_BUFFER_SIZE)
            var remaining = maxChars
            while (remaining > 0) {
                val read = read(buffer, 0, minOf(buffer.size, remaining))
                if (read <= 0) {
                    break
                }
                builder.append(buffer, 0, read)
                remaining -= read
            }
        }.toString()

    companion object {
        const val DOCUMENT_PREVIEW_CHARS = 2_000
        const val MAX_DOCUMENT_TEXT_CHARS = 30_000
        const val DOCUMENT_EXCERPT_CHARS = 3_500
        private const val DOCX_XML_READ_CHARS = 40_000
    }
}

private val documentSearchStopWords = setOf(
    "the",
    "and",
    "for",
    "with",
    "from",
    "that",
    "this",
    "what",
    "when",
    "where",
    "which",
    "about",
    "document",
    "file",
    "please",
)
