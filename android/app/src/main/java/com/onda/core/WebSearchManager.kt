package com.onda.core

data class WebSearchContext(
    val sanitizedQuery: String,
    val privacyMasked: Boolean,
    val maskedTypes: List<String>,
    val resultsText: String,
    val configured: Boolean,
)

class WebSearchManager {
    fun search(query: String): WebSearchContext {
        val maskResult = PrivacyMasker.maskForExternalSearch(query)

        return WebSearchContext(
            sanitizedQuery = maskResult.masked,
            privacyMasked = maskResult.changed,
            maskedTypes = maskResult.findings,
            resultsText = WEB_SEARCH_NOT_CONFIGURED_MESSAGE,
            configured = false,
        )
    }

    companion object {
        private const val WEB_SEARCH_NOT_CONFIGURED_MESSAGE =
            "Web search provider is not configured yet. No external request was sent."
    }
}
