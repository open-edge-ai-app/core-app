package com.openedgeai.core

data class WebSearchContext(
    val sanitizedQuery: String,
    val privacyMasked: Boolean,
    val llmSanitized: Boolean,
    val maskedTypes: List<String>,
    val resultsText: String,
    val configured: Boolean,
)

class WebSearchManager(
    private val gemmaManager: GemmaManager,
) {
    fun search(query: String): WebSearchContext {
        val firstPass = PrivacyMasker.maskForExternalSearch(query)
        val llmSanitized = sanitizeWithLocalModel(
            originalQuery = query,
            regexMaskedQuery = firstPass.masked,
        )
        val finalCandidate = llmSanitized
            .takeUnless { candidate -> isInvalidSanitizedQuery(candidate) }
            ?: firstPass.masked
        val usedLlmSanitized = finalCandidate == llmSanitized && llmSanitized != firstPass.masked
        val finalPass = PrivacyMasker.maskForExternalSearch(finalCandidate)
        val maskedTypes = (firstPass.findings + finalPass.findings)
            .distinct()
            .sorted()
        val sanitizedQuery = finalPass.masked.take(MAX_QUERY_CHARS)
        val queryRemoved = sanitizedQuery.isBlank()

        return WebSearchContext(
            sanitizedQuery = sanitizedQuery,
            privacyMasked = firstPass.changed || finalPass.changed || queryRemoved,
            llmSanitized = usedLlmSanitized,
            maskedTypes = maskedTypes,
            resultsText = if (queryRemoved) {
                WEB_SEARCH_QUERY_REDACTED_MESSAGE
            } else {
                WEB_SEARCH_NOT_CONFIGURED_MESSAGE
            },
            configured = false,
        )
    }

    private fun sanitizeWithLocalModel(
        originalQuery: String,
        regexMaskedQuery: String,
    ): String {
        val prompt = """
        Rewrite the user request into a safe public web search query.

        Rules:
        - Remove private personal data.
        - Remove SMS contents, local photo paths, local file paths, names, phone numbers, emails, addresses, account numbers, IDs, secrets, and exact local record identifiers.
        - Keep only public, non-sensitive search terms.
        - If the request only contains private/local memory needs and no public web need, return an empty string.
        - Return only the query. No explanation.

        Original local-only request:
        $originalQuery

        Regex-masked draft:
        $regexMaskedQuery
        """.trimIndent()

        return gemmaManager.generate(prompt, useRag = false)
            .trim()
            .lineSequence()
            .firstOrNull { line -> line.isNotBlank() }
            .orEmpty()
            .trim()
            .removeSurrounding("\"")
            .removeSurrounding("'")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun isInvalidSanitizedQuery(query: String): Boolean {
        val normalized = query.trim()
        return normalized.isBlank() ||
            normalized.contains("runtime is not loaded", ignoreCase = true) ||
            normalized.contains("model is not installed", ignoreCase = true) ||
            normalized.contains("error", ignoreCase = true)
    }

    companion object {
        private const val MAX_QUERY_CHARS = 200
        private const val WEB_SEARCH_NOT_CONFIGURED_MESSAGE =
            "Web search provider is not configured yet. No external request was sent."
        private const val WEB_SEARCH_QUERY_REDACTED_MESSAGE =
            "Web search query was removed because it contained only private or local data. No external request was sent."
    }
}
