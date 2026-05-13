package com.onda.core

data class WebSearchContext(
    val sanitizedQuery: String,
    val privacyMasked: Boolean,
    val llmSanitized: Boolean,
    val maskedTypes: List<String>,
    val resultsText: String,
    val configured: Boolean,
)

class WebSearchManager {
    fun search(query: String): WebSearchContext {
        val firstPass = PrivacyMasker.maskForExternalSearch(query)
        val finalPass = PrivacyMasker.maskForExternalSearch(firstPass.masked)
        val maskedTypes = (firstPass.findings + finalPass.findings)
            .distinct()
            .sorted()
        val sanitizedQuery = finalPass.masked.take(MAX_QUERY_CHARS)
        val queryRemoved = sanitizedQuery.isBlank()

        return WebSearchContext(
            sanitizedQuery = sanitizedQuery,
            privacyMasked = firstPass.changed || finalPass.changed || queryRemoved,
            llmSanitized = false,
            maskedTypes = maskedTypes,
            resultsText = if (queryRemoved) {
                WEB_SEARCH_QUERY_REDACTED_MESSAGE
            } else {
                WEB_SEARCH_NOT_CONFIGURED_MESSAGE
            },
            configured = false,
        )
    }

    companion object {
        private const val MAX_QUERY_CHARS = 200
        private const val WEB_SEARCH_NOT_CONFIGURED_MESSAGE =
            "Web search provider is not configured yet. No external request was sent."
        private const val WEB_SEARCH_QUERY_REDACTED_MESSAGE =
            "Web search query was removed because it contained only private or local data. No external request was sent."
    }
}
