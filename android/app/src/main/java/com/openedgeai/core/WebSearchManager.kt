package com.openedgeai.core

import java.io.StringReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import javax.xml.parsers.DocumentBuilderFactory
import org.xml.sax.InputSource

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
    fun search(
        query: String,
        useLocalLlmSanitizer: Boolean = true,
    ): WebSearchContext {
        val firstPass = PrivacyMasker.maskForExternalSearch(query)
        val llmSanitized = if (useLocalLlmSanitizer) {
            sanitizeWithLocalModel(
                originalQuery = query,
                regexMaskedQuery = firstPass.masked,
            )
        } else {
            firstPass.masked
        }
        val finalCandidate = llmSanitized
            .takeUnless { candidate -> isInvalidSanitizedQuery(candidate) }
            ?: firstPass.masked
        val usedLlmSanitized = useLocalLlmSanitizer &&
            finalCandidate == llmSanitized &&
            llmSanitized != firstPass.masked
        val finalPass = PrivacyMasker.maskForExternalSearch(finalCandidate)
        val maskedTypes = (firstPass.findings + finalPass.findings)
            .distinct()
            .sorted()
        val sanitizedQuery = finalPass.masked.take(MAX_QUERY_CHARS)
        val queryRemoved = sanitizedQuery.isBlank()

        val results = if (queryRemoved) {
            WEB_SEARCH_QUERY_REDACTED_MESSAGE
        } else {
            runCatching { searchBingRss(sanitizedQuery) }
                .getOrElse { error ->
                    "Web search request failed: ${error.message ?: error.javaClass.simpleName}"
                }
        }

        return WebSearchContext(
            sanitizedQuery = sanitizedQuery,
            privacyMasked = firstPass.changed || finalPass.changed || queryRemoved,
            llmSanitized = usedLlmSanitized,
            maskedTypes = maskedTypes,
            resultsText = results,
            configured = !queryRemoved,
        )
    }

    private fun searchBingRss(query: String): String {
        val encodedQuery = URLEncoder.encode(query, Charsets.UTF_8.name())
        val url = URL(
            "https://www.bing.com/search?q=$encodedQuery&format=rss&mkt=ko-KR&setlang=ko-KR",
        )
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = WEB_SEARCH_CONNECT_TIMEOUT_MS
            readTimeout = WEB_SEARCH_READ_TIMEOUT_MS
            setRequestProperty(
                "User-Agent",
                "OpenEdgeAI/1.0 (+https://github.com/open-edge-ai-app/open-edge-ai)",
            )
            setRequestProperty("Accept", "application/rss+xml, application/xml, text/xml")
        }

        return connection.use { http ->
            if (http.responseCode !in 200..299) {
                throw IllegalStateException("HTTP ${http.responseCode}")
            }

            val xml = http.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            parseRssResults(xml)
        }
    }

    private fun parseRssResults(xml: String): String {
        val document = DocumentBuilderFactory
            .newInstance()
            .apply {
                isNamespaceAware = false
                isValidating = false
            }
            .newDocumentBuilder()
            .parse(InputSource(StringReader(xml)))
        val items = document.getElementsByTagName("item")
        if (items.length == 0) {
            return "No web search results were found."
        }

        return (0 until minOf(items.length, WEB_SEARCH_RESULT_LIMIT))
            .mapNotNull { index ->
                val item = items.item(index)
                val children = item.childNodes
                val fields = mutableMapOf<String, String>()
                for (childIndex in 0 until children.length) {
                    val child = children.item(childIndex)
                    fields[child.nodeName] = child.textContent.orEmpty().replace(Regex("\\s+"), " ").trim()
                }

                val title = fields["title"].orEmpty()
                val link = fields["link"].orEmpty()
                val description = fields["description"].orEmpty()
                val date = fields["pubDate"].orEmpty()
                if (title.isBlank() && description.isBlank()) {
                    null
                } else {
                    """
                    Source [${index + 1}]: $title
                    URL: $link
                    Date: ${date.ifBlank { "N/A" }}
                    Content: $description
                    """.trimIndent()
                }
            }
            .joinToString(separator = "\n---\n")
            .ifBlank { "No web search results were found." }
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
        private const val WEB_SEARCH_CONNECT_TIMEOUT_MS = 8_000
        private const val WEB_SEARCH_READ_TIMEOUT_MS = 10_000
        private const val WEB_SEARCH_RESULT_LIMIT = 5
        private const val WEB_SEARCH_QUERY_REDACTED_MESSAGE =
            "Web search query was removed because it contained only private or local data. No external request was sent."
    }
}

private inline fun <T : HttpURLConnection, R> T.use(block: (T) -> R): R =
    try {
        block(this)
    } finally {
        disconnect()
    }
