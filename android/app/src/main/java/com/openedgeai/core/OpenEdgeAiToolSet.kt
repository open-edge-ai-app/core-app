package com.openedgeai.core

import com.google.ai.edge.litertlm.Tool
import com.google.ai.edge.litertlm.ToolParam
import com.google.ai.edge.litertlm.ToolSet
import com.openedgeai.db.VectorDao
import com.openedgeai.db.VectorRecord

class OpenEdgeAiToolSet(
    private val embedManager: EmbedManager,
    private val vectorDao: VectorDao,
    private val webSearchManager: WebSearchManager,
) : ToolSet {
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

        return records.joinToString(separator = "\n") { record -> record.toToolLine() }
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

        return webSearchManager.readUrl(
            url = normalizedUrl,
            query = query.trim(),
        )
    }

    private fun VectorRecord.toToolLine(): String {
        val parts = mutableListOf(
            "type=$source",
            "source_id=$sourceId",
            "time=${timestamp ?: "unknown"}",
            "text=$text",
        )
        if (!uri.isNullOrBlank()) {
            parts.add("uri=$uri")
        }
        if (!metadata.isNullOrBlank()) {
            parts.add("metadata=$metadata")
        }
        return "- ${parts.joinToString(" ")}"
    }

    companion object {
        private const val RAG_RESULT_LIMIT = 5
    }
}
