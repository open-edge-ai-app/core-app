package com.openedgeai.core

import android.net.Uri
import com.google.ai.edge.litertlm.Tool
import com.google.ai.edge.litertlm.ToolParam
import com.google.ai.edge.litertlm.ToolSet
import com.openedgeai.db.VectorDao
import com.openedgeai.db.VectorRecord
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

sealed class CitedSource {
    data class Document(
        val documentId: String,
        val name: String,
        val uri: String,
        val relativePath: String?,
    ) : CitedSource()

    data class Memory(
        val source: String,
        val sourceId: String,
        val uri: String?,
        val text: String,
    ) : CitedSource()

    data class Web(
        val title: String,
        val url: String,
    ) : CitedSource()
}

class OpenEdgeAiToolSet(
    private val embedManager: EmbedManager,
    private val vectorDao: VectorDao,
    private val webSearchManager: WebSearchManager,
    private val documentTextExtractor: DocumentTextExtractor,
) : ToolSet {
    private val citationLock = Any()
    private val currentCitations = mutableListOf<CitedSource>()

    fun beginRequest() {
        synchronized(citationLock) {
            currentCitations.clear()
        }
    }

    fun consumeCitations(): List<CitedSource> =
        synchronized(citationLock) {
            val snapshot = currentCitations.toList()
            currentCitations.clear()
            snapshot
        }

    private fun recordCitation(source: CitedSource) {
        synchronized(citationLock) {
            currentCitations.add(source)
        }
    }
    @Tool(
        description = "Search private local device memories such as SMS, gallery photos, documents, receipts, and saved chat context.",
    )
    fun ragSearch(
        @ToolParam(description = "Short semantic search query for private local memory.")
        query: String,
    ): String {
        val normalized = query.trim()
        if (normalized.isBlank()) {
            return "No local memory search query was provided."
        }
        if (!embedManager.isAvailable()) {
            return "Local memory embedding is unavailable, so private memory search could not run."
        }

        val records = vectorDao.search(embedManager.embed(normalized), RAG_RESULT_LIMIT)
        if (records.isEmpty()) {
            return "No local memory records were found for the query: $normalized"
        }

        records.forEach { record -> recordCitation(record.toCitation()) }
        return records.joinToString(separator = "\n") { record -> record.toToolLine() }
    }

    @Tool(
        description = "Open a private local document returned by ragSearch and read relevant text from the actual file.",
    )
    fun readLocalDocument(
        @ToolParam(description = "Local documentId returned by ragSearch for a document result.")
        documentId: String,
        @ToolParam(description = "User question or focused topic for extracting relevant document text.")
        query: String,
    ): String {
        val normalizedDocumentId = documentId.trim()
        if (normalizedDocumentId.isBlank()) {
            return "No local documentId was provided."
        }

        val document = vectorDao.getDocument(normalizedDocumentId)
            ?: return "No local document was found for documentId: $normalizedDocumentId"
        recordCitation(
            CitedSource.Document(
                documentId = document.documentId,
                name = document.name,
                uri = document.uri,
                relativePath = document.relativePath,
            ),
        )
        val querySignature = query.normalizedQuerySignature()
        val cached = vectorDao.getCachedDocumentExcerpt(
            documentId = document.documentId,
            fingerprint = document.fingerprint,
            querySignature = querySignature,
        )
        if (!cached.isNullOrBlank()) {
            return document.formatDocumentExcerpt(cached, cached = true)
        }

        val text = documentTextExtractor.readDocumentText(
            uri = Uri.parse(document.uri),
            mimeType = document.mimeType,
        )
        if (text.isBlank()) {
            return """
            Local document: ${document.name}
            documentId: ${document.documentId}
            URI: ${document.uri}
            MIME: ${document.mimeType.orEmpty()}
            No readable document text was found. v1 can read text, CSV, Markdown, JSON, and DOCX files; PDF/XLSX/PPTX are catalog-search only.
            """.trimIndent()
        }

        val excerpt = documentTextExtractor.extractRelevantExcerpt(
            text = text,
            query = query,
        )
        if (excerpt.isBlank()) {
            return "No relevant readable excerpt was found in local document: ${document.name}"
        }

        vectorDao.upsertDocumentExcerptCache(
            documentId = document.documentId,
            fingerprint = document.fingerprint,
            querySignature = querySignature,
            excerpt = excerpt,
        )
        return document.formatDocumentExcerpt(excerpt, cached = false)
    }

    @Tool(
        description = "Search current or public web information. Use only sanitized public queries and never include private local data.",
    )
    fun webSearch(
        @ToolParam(description = "Sanitized public web search query with no private data.")
        query: String,
    ): String {
        val normalized = query.trim()
        if (normalized.isBlank()) {
            return "No public web search query was provided."
        }

        val context = webSearchManager.search(
            query = normalized,
            useLocalLlmSanitizer = false,
        )
        context.sources.forEach { source ->
            recordCitation(CitedSource.Web(title = source.title, url = source.url))
        }
        val maskedNotice = if (context.privacyMasked) {
            "Privacy masking was applied. Masked fields: ${context.maskedTypes.joinToString(", ").ifBlank { "unknown" }}."
        } else {
            "No privacy masking was needed."
        }

        return """
        Sanitized query: ${context.sanitizedQuery}
        Configured: ${context.configured}
        Privacy: $maskedNotice
        Results:
        ${context.resultsText}
        """.trimIndent()
    }

    @Tool(
        description = "Open a public web URL returned by webSearch and read its page text for detailed evidence.",
    )
    fun readWebPage(
        @ToolParam(description = "Public http or https URL to open.")
        url: String,
        @ToolParam(description = "User question or focused topic for extracting relevant page text.")
        query: String,
    ): String {
        val normalizedUrl = url.trim()
        if (normalizedUrl.isBlank()) {
            return "No URL was provided."
        }

        recordCitation(CitedSource.Web(title = normalizedUrl, url = normalizedUrl))
        return webSearchManager.readUrl(
            url = normalizedUrl,
            query = query.trim(),
        )
    }

    private fun VectorRecord.toCitation(): CitedSource =
        if (source == "document") {
            val catalog = vectorDao.getDocument(sourceId)
            CitedSource.Document(
                documentId = sourceId,
                name = catalog?.name?.ifBlank { sourceId } ?: sourceId,
                uri = catalog?.uri ?: uri.orEmpty(),
                relativePath = catalog?.relativePath,
            )
        } else {
            CitedSource.Memory(
                source = source,
                sourceId = sourceId,
                uri = uri,
                text = text,
            )
        }

    private fun VectorRecord.toToolLine(): String {
        val parts = mutableListOf(
            "type=$source",
            "source_id=$sourceId",
            "time=${timestamp ?: "unknown"}",
            "text=$text",
        )
        if (source == "document") {
            parts.add(1, "documentId=$sourceId")
        }
        if (!uri.isNullOrBlank()) {
            parts.add("uri=$uri")
        }
        if (!metadata.isNullOrBlank()) {
            parts.add("metadata=$metadata")
        }
        return "- ${parts.joinToString(" ")}"
    }

    private fun com.openedgeai.db.DocumentCatalogRecord.formatDocumentExcerpt(
        excerpt: String,
        cached: Boolean,
    ): String =
        """
        Local document: $name
        documentId: $documentId
        URI: $uri
        MIME: ${mimeType.orEmpty()}
        Modified: ${formatModifiedTimestamp(modifiedAt)}
        Cached: $cached
        Excerpt:
        $excerpt
        """.trimIndent()

    private fun formatModifiedTimestamp(timestamp: Long): String =
        if (timestamp <= 0) {
            "unknown"
        } else {
            MODIFIED_DATE_FORMAT.format(Date(timestamp))
        }

    companion object {
        private const val RAG_RESULT_LIMIT = 5
        private val MODIFIED_DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
    }
}

private fun String.normalizedQuerySignature(): String {
    val normalized = lowercase().replace(Regex("\\s+"), " ").trim().take(300)
    val digest = MessageDigest.getInstance("SHA-256").digest(normalized.toByteArray(Charsets.UTF_8))
    return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }.take(32)
}
