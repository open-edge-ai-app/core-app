package com.openedgeai.core

import android.content.Context
import java.io.StringReader
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.Charset
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
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

private data class WebSearchResult(
    val title: String,
    val url: String,
    val description: String,
    val date: String? = null,
)

private data class WebPageDetail(
    val sourceIndex: Int,
    val title: String,
    val url: String,
    val excerpt: String,
)

class WebSearchManager(
    context: Context,
    private val gemmaManager: GemmaManager,
) {
    private val webViewPageLoader = WebViewPageLoader(context.applicationContext)

    fun search(
        query: String,
        useLocalLlmSanitizer: Boolean = true,
    ): WebSearchContext {
        val firstPass = PrivacyMasker.maskForExternalSearch(query)
        val fallbackQuery = cleanPublicSearchQuery(firstPass.masked)
        val queryCandidates = buildSearchQueries(
            originalQuery = query,
            regexMaskedQuery = firstPass.masked,
            fallbackQuery = fallbackQuery,
            useLocalLlmSanitizer = useLocalLlmSanitizer,
        )
        val finalPasses = queryCandidates.map { candidate ->
            PrivacyMasker.maskForExternalSearch(candidate)
        }
        val maskedTypes = (firstPass.findings + finalPasses.flatMap { pass -> pass.findings })
            .distinct()
            .sorted()
        val sanitizedQueries = finalPasses
            .map { pass -> cleanPublicSearchQuery(pass.masked).take(MAX_QUERY_CHARS) }
            .filterNot(::isInvalidSanitizedQuery)
            .distinctBy { candidate -> candidate.lowercase() }
            .take(MAX_WEB_SEARCH_QUERIES)
        val queryRemoved = sanitizedQueries.isEmpty()
        val usedLlmSanitized = useLocalLlmSanitizer &&
            sanitizedQueries.any { candidate -> candidate != fallbackQuery }

        val results = if (queryRemoved) {
            WEB_SEARCH_QUERY_REDACTED_MESSAGE
        } else {
            runCatching {
                searchAllQueries(
                    originalQuestion = query,
                    queries = sanitizedQueries,
                )
            }
                .getOrElse { error ->
                    "Web search request failed: ${error.message ?: error.javaClass.simpleName}"
                }
        }

        return WebSearchContext(
            sanitizedQuery = sanitizedQueries.joinToString(separator = "\n") { candidate -> "- $candidate" },
            privacyMasked = firstPass.changed || finalPasses.any { pass -> pass.changed } || queryRemoved,
            llmSanitized = usedLlmSanitized,
            maskedTypes = maskedTypes,
            resultsText = results,
            configured = !queryRemoved,
        )
    }

    private fun buildSearchQueries(
        originalQuery: String,
        regexMaskedQuery: String,
        fallbackQuery: String,
        useLocalLlmSanitizer: Boolean,
    ): List<String> {
        val llmQueries = if (useLocalLlmSanitizer) {
            generateSearchQueriesWithLocalModel(
                originalQuery = originalQuery,
                regexMaskedQuery = regexMaskedQuery,
            )
        } else {
            emptyList()
        }

        return (llmQueries + fallbackQuery + expandFallbackSearchQueries(fallbackQuery))
            .map(::cleanPublicSearchQuery)
            .map { candidate -> candidate.take(MAX_QUERY_CHARS) }
            .filterNot(::isInvalidSanitizedQuery)
            .distinctBy { candidate -> candidate.lowercase() }
            .take(MAX_WEB_SEARCH_QUERIES)
    }

    private fun expandFallbackSearchQueries(query: String): List<String> {
        if (query.isBlank()) {
            return emptyList()
        }

        val normalized = query.lowercase()
        val looksCurrentOrResearch = listOf(
            "최신",
            "최근",
            "동향",
            "연구",
            "논문",
            "latest",
            "recent",
            "trend",
            "research",
            "paper",
        ).any { keyword -> normalized.contains(keyword) }
        if (!looksCurrentOrResearch) {
            return emptyList()
        }

        val hasKorean = Regex("""[\uAC00-\uD7A3]""").containsMatchIn(query)
        return if (hasKorean) {
            listOf(
                "$query 논문 리뷰 2025 2026",
                "$query research trends 2025 2026",
            )
        } else {
            listOf(
                "$query 2025 2026 review",
                "$query research trends",
            )
        }
    }

    fun readUrl(
        url: String,
        query: String,
    ): String {
        val normalizedUrl = url.trim()
        if (!normalizedUrl.startsWith("http://") && !normalizedUrl.startsWith("https://")) {
            return "Only http and https URLs can be read."
        }

        val result = WebSearchResult(
            title = normalizedUrl,
            url = normalizedUrl,
            description = "",
        )
        val detail = fetchPageDetail(
            result = result,
            sourceIndex = 1,
            question = query,
        ) ?: return "No readable page text was found for URL: $normalizedUrl"
        return formatPageDetails(listOf(detail))
    }

    private fun searchAllQueries(
        originalQuestion: String,
        queries: List<String>,
    ): String {
        val results = searchQueriesInParallel(queries)
            .distinctBy { result -> result.url.normalizeUrlForDedupe() }
            .take(WEB_SEARCH_CANDIDATE_LIMIT)
        val pageDetails = fetchSelectedPageDetails(
            question = originalQuestion,
            results = results,
        )
        return listOf(
            formatSearchResults(results, fallbackDate = null),
            formatPageDetails(pageDetails),
        )
            .filter { section -> section.isNotBlank() }
            .joinToString(separator = "\n\n")
    }

    private fun fetchSelectedPageDetails(
        question: String,
        results: List<WebSearchResult>,
    ): List<WebPageDetail> {
        if (results.isEmpty()) {
            return emptyList()
        }

        val selectedUrls = selectDetailUrlsWithLocalModel(
            question = question,
            results = results,
        ).ifEmpty {
            results.take(WEB_PAGE_DETAIL_LIMIT).map { result -> result.url }
        }
        val selectedResults = selectedUrls
            .mapNotNull { selectedUrl ->
                results.firstOrNull { result ->
                    result.url.normalizeUrlForDedupe() == selectedUrl.normalizeUrlForDedupe()
                }
            }
            .ifEmpty { results.take(WEB_PAGE_DETAIL_LIMIT) }
            .take(WEB_PAGE_DETAIL_LIMIT)

        val executor = Executors.newFixedThreadPool(minOf(selectedResults.size, WEB_PAGE_DETAIL_LIMIT))
        return try {
            val tasks = selectedResults.mapIndexed { index, result ->
                Callable {
                    fetchPageDetail(
                        result = result,
                        sourceIndex = index + 1,
                        question = question,
                    )
                }
            }
            executor
                .invokeAll(tasks, WEB_PAGE_TOTAL_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                .mapNotNull { future ->
                    runCatching {
                        if (future.isCancelled) null else future.get()
                    }.getOrNull()
                }
        } finally {
            executor.shutdownNow()
        }
    }

    private fun selectDetailUrlsWithLocalModel(
        question: String,
        results: List<WebSearchResult>,
    ): List<String> {
        val candidates = results
            .take(WEB_SEARCH_CANDIDATE_LIMIT)
            .mapIndexed { index, result ->
                """
                [${index + 1}] ${result.title}
                URL: ${result.url}
                Snippet: ${result.description}
                """.trimIndent()
            }
            .joinToString(separator = "\n\n")
        val prompt = """
        Select up to 3 URLs that should be opened for detailed reading before answering the user.

        Rules:
        - Prefer authoritative, specific, recent, primary, or technically detailed sources.
        - Avoid duplicate, shallow, generic dictionary, homepage, or low-relevance URLs.
        - Return only URLs, one per line.
        - Do not explain.

        User question:
        $question

        Search results:
        $candidates
        """.trimIndent()

        return runCatching {
            gemmaManager.generate(prompt, useRag = false)
                .lineSequence()
                .map { line -> line.trim().trim('-', '*', ' ', '"', '\'') }
                .mapNotNull { line -> Regex("""https?://\S+""").find(line)?.value }
                .map { url -> url.trimEnd('.', ',', ')', ']', '"', '\'') }
                .distinctBy { url -> url.normalizeUrlForDedupe() }
                .take(WEB_PAGE_DETAIL_LIMIT)
                .toList()
        }.getOrDefault(emptyList())
    }

    private fun fetchPageDetail(
        result: WebSearchResult,
        sourceIndex: Int,
        question: String,
    ): WebPageDetail? {
        val safeDetail = fetchSafePageDetail(
            result = result,
            sourceIndex = sourceIndex,
            question = question,
        )
        if (safeDetail != null && safeDetail.excerpt.length >= WEB_PAGE_MIN_SAFE_EXCERPT_CHARS) {
            return safeDetail
        }

        return fetchRenderedPageDetail(
            result = result,
            sourceIndex = sourceIndex,
            question = question,
        ) ?: safeDetail
    }

    private fun fetchSafePageDetail(
        result: WebSearchResult,
        sourceIndex: Int,
        question: String,
    ): WebPageDetail? {
        val url = result.url.trim()
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            return null
        }

        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = WEB_PAGE_CONNECT_TIMEOUT_MS
            readTimeout = WEB_PAGE_READ_TIMEOUT_MS
            instanceFollowRedirects = true
            setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 OpenEdgeAI/1.0",
            )
            setRequestProperty("Accept", "text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5")
            setRequestProperty("Accept-Language", "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7")
        }

        return runCatching {
            connection.use { http ->
                if (http.responseCode !in 200..299) {
                    return@use null
                }
                val contentType = http.contentType.orEmpty()
                if (!contentType.isLikelyReadableText()) {
                    return@use null
                }

                val charset = contentType.extractCharset() ?: Charsets.UTF_8
                val raw = http.inputStream.readTextLimited(charset, WEB_PAGE_MAX_BYTES)
                val text = if (contentType.contains("html", ignoreCase = true)) {
                    raw.cleanPageText()
                } else {
                    raw.replace(Regex("\\s+"), " ").trim()
                }
                val excerpt = extractRelevantPageExcerpt(
                    text = text,
                    question = question,
                )
                if (excerpt.isBlank()) {
                    null
                } else {
                    WebPageDetail(
                        sourceIndex = sourceIndex,
                        title = result.title,
                        url = http.url.toString(),
                        excerpt = excerpt,
                    )
                }
            }
        }.getOrNull()
    }

    private fun fetchRenderedPageDetail(
        result: WebSearchResult,
        sourceIndex: Int,
        question: String,
    ): WebPageDetail? {
        val url = result.url.trim()
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            return null
        }

        val rendered = webViewPageLoader.load(url) ?: return null
        val excerpt = extractRelevantPageExcerpt(
            text = rendered.text,
            question = question,
        )
        if (excerpt.isBlank()) {
            return null
        }

        return WebPageDetail(
            sourceIndex = sourceIndex,
            title = rendered.title.ifBlank { result.title },
            url = rendered.url.ifBlank { url },
            excerpt = excerpt,
        )
    }

    private fun searchQueriesInParallel(queries: List<String>): List<WebSearchResult> {
        val executor = Executors.newFixedThreadPool(minOf(queries.size, WEB_SEARCH_PARALLELISM))
        return try {
            val tasks = queries.map { query ->
                Callable { searchOneQuery(query) }
            }
            executor
                .invokeAll(tasks, WEB_SEARCH_TOTAL_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                .flatMap { future ->
                    runCatching {
                        if (future.isCancelled) emptyList() else future.get()
                    }.getOrDefault(emptyList())
                }
        } finally {
            executor.shutdownNow()
        }
    }

    private fun searchOneQuery(query: String): List<WebSearchResult> =
        runCatching { searchDuckDuckGo(query) }
            .recoverCatching { searchBingRss(query) }
            .getOrDefault(emptyList())

    private fun searchDuckDuckGo(query: String): List<WebSearchResult> {
        val encodedQuery = URLEncoder.encode(query, Charsets.UTF_8.name())
        val url = URL(
            "https://html.duckduckgo.com/html/?q=$encodedQuery&kl=kr-ko",
        )
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = WEB_SEARCH_CONNECT_TIMEOUT_MS
            readTimeout = WEB_SEARCH_READ_TIMEOUT_MS
            instanceFollowRedirects = true
            setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 OpenEdgeAI/1.0",
            )
            setRequestProperty("Accept", "text/html,application/xhtml+xml")
            setRequestProperty("Accept-Language", "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7")
        }

        return connection.use { http ->
            if (http.responseCode !in 200..299) {
                throw IllegalStateException("DuckDuckGo HTTP ${http.responseCode}")
            }

            val html = http.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            if (html.contains("anomaly-modal", ignoreCase = true) ||
                html.contains("Unfortunately, bots use DuckDuckGo too", ignoreCase = true)
            ) {
                throw IllegalStateException("DuckDuckGo returned a bot challenge")
            }

            val results = parseDuckDuckGoResults(html)
            if (results.isEmpty()) {
                throw IllegalStateException("DuckDuckGo returned no parseable results")
            }
            results
        }
    }

    private fun parseDuckDuckGoResults(html: String): List<WebSearchResult> {
        val resultBlocks = Regex(
            """(?is)<div\b[^>]*class=["'][^"']*\bresult\b[^"']*["'][^>]*>(.*?)</div>\s*</div>""",
        )
            .findAll(html)
            .map { match -> match.groupValues[1] }
            .toList()
            .ifEmpty {
                Regex("""(?is)<tr\b[^>]*>(.*?)</tr>""")
                    .findAll(html)
                    .map { match -> match.groupValues[1] }
                    .toList()
            }

        return resultBlocks
            .mapNotNull(::parseDuckDuckGoResultBlock)
            .distinctBy { result -> result.url }
            .take(WEB_SEARCH_RESULT_LIMIT)
    }

    private fun parseDuckDuckGoResultBlock(block: String): WebSearchResult? {
        val anchor = Regex(
            """(?is)<a\b[^>]*class=["'][^"']*(?:result__a|result-link)[^"']*["'][^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>""",
        ).find(block) ?: Regex(
            """(?is)<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>""",
        ).find(block)
        val href = anchor?.groupValues?.getOrNull(1).orEmpty()
        val title = anchor?.groupValues?.getOrNull(2).orEmpty().cleanHtmlText()
        val url = decodeDuckDuckGoUrl(href)
        if (title.isBlank() || url.isBlank() || url.contains("duckduckgo.com", ignoreCase = true)) {
            return null
        }

        val description = Regex(
            """(?is)<a\b[^>]*class=["'][^"']*result__snippet[^"']*["'][^>]*>(.*?)</a>""",
        ).find(block)?.groupValues?.getOrNull(1)
            ?: Regex(
                """(?is)<td\b[^>]*class=["'][^"']*result-snippet[^"']*["'][^>]*>(.*?)</td>""",
            ).find(block)?.groupValues?.getOrNull(1)
            ?: Regex(
                """(?is)<div\b[^>]*class=["'][^"']*result__snippet[^"']*["'][^>]*>(.*?)</div>""",
            ).find(block)?.groupValues?.getOrNull(1)

        return WebSearchResult(
            title = title,
            url = url,
            description = description.orEmpty().cleanHtmlText(),
        )
    }

    private fun decodeDuckDuckGoUrl(rawUrl: String): String {
        val normalized = rawUrl
            .replace("&amp;", "&")
            .let { value -> if (value.startsWith("//")) "https:$value" else value }
        val uddg = Regex("""[?&]uddg=([^&]+)""").find(normalized)
            ?.groupValues
            ?.getOrNull(1)
        return if (uddg.isNullOrBlank()) {
            normalized
        } else {
            URLDecoder.decode(uddg, Charsets.UTF_8.name())
        }
    }

    private fun searchBingRss(query: String): List<WebSearchResult> {
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

    private fun parseRssResults(xml: String): List<WebSearchResult> {
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
            return emptyList()
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
                    WebSearchResult(
                        title = title,
                        url = link,
                        date = date.ifBlank { null },
                        description = description,
                    )
                }
            }
    }

    private fun formatSearchResults(
        results: List<WebSearchResult>,
        fallbackDate: String?,
    ): String {
        if (results.isEmpty()) {
            return "No web search results were found."
        }

        return results
            .take(WEB_SEARCH_RESULT_LIMIT)
            .mapIndexed { index, result ->
                val date = result.date ?: fallbackDate
                """
                Source [${index + 1}]: ${result.title}
                URL: ${result.url}
                ${date?.let { "Date: $it\n" }.orEmpty()}Content: ${result.description.ifBlank { result.title }}
                """.trimIndent()
            }
            .joinToString(separator = "\n---\n")
    }

    private fun formatPageDetails(details: List<WebPageDetail>): String {
        if (details.isEmpty()) {
            return ""
        }

        return details
            .joinToString(separator = "\n---\n") { detail ->
                """
                Detailed page [${detail.sourceIndex}]: ${detail.title}
                URL: ${detail.url}
                Page text excerpt:
                ${detail.excerpt}
                """.trimIndent()
            }
            .let { detailsText ->
                """
                Opened URL details:
                $detailsText
                """.trimIndent()
            }
    }

    private fun generateSearchQueriesWithLocalModel(
        originalQuery: String,
        regexMaskedQuery: String,
    ): List<String> {
        val prompt = """
        Create up to 3 safe public web search queries for the user request.

        Rules:
        - Return only search queries, one per line.
        - Remove SMS contents, local photo paths, local file paths, names, phone numbers, emails, addresses, account numbers, IDs, secrets, and exact local record identifiers.
        - Query 1 should be concise and in the user's language.
        - Query 2 may use English or global technical terms when useful.
        - Query 3 should target authoritative and current sources. For research topics, include review, paper, 2025, or 2026 when useful.
        - Do not include numbering, bullets, quotes, explanations, or private data.
        - If the request has no public web search need, return nothing.

        User request:
        $originalQuery

        Privacy-masked draft:
        $regexMaskedQuery
        """.trimIndent()

        return gemmaManager.generate(prompt, useRag = false)
            .lineSequence()
            .map(::cleanGeneratedQueryLine)
            .filterNot(::isInvalidSanitizedQuery)
            .distinctBy { candidate -> candidate.lowercase() }
            .take(MAX_WEB_SEARCH_QUERIES)
            .toList()
    }

    private fun cleanGeneratedQueryLine(line: String): String =
        line
            .replace(Regex("""^\s*(?:[-*•]|\d+[.)])\s*"""), "")
            .replace(Regex("""(?i)^\s*query\s*\d*\s*[:：]\s*"""), "")
            .trim()
            .removeSurrounding("\"")
            .removeSurrounding("'")
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun cleanPublicSearchQuery(query: String): String {
        val withoutCommandNoise = query
            .replace(Regex("""(?i)\b(?:please|can you|could you|would you|search(?:\s+for)?|look\s+up|find|tell\s+me|show\s+me)\b"""), " ")
            .replace(Regex("""(?i)\b(?:latest|recent|current)\s+(?:info(?:rmation)?\s+)?(?:about|on)\b"""), " latest ")
            .replace(
                Regex(
                    """(?x)
                    (검색\s*(?:해\s*줘|해줘|해|해봐|해서\s*알려줘|해서\s*정리해줘)?)
                    |(찾아\s*(?:봐|줘|서\s*알려줘|서\s*정리해줘)?)
                    |(알려\s*줘)
                    |(정리\s*해\s*줘)
                    |(요약\s*해\s*줘)
                    |(조사\s*해\s*줘)
                    |(뒤져\s*줘?)
                    |(구글링\s*해\s*줘?)
                    """,
                ),
                " ",
            )
            .replace(Regex("""(?i)\b(?:web|internet|online)\s+search\b"""), " ")

        return withoutCommandNoise
            .replace(Regex("""[\r\n\t]+"""), " ")
            .replace(Regex("""[?？!！]+"""), " ")
            .replace(Regex("""\s+"""), " ")
            .trim()
            .trim('"', '\'', '.', ',', ':', ';', '-', '_', '·', 'ㆍ')
            .replace(Regex("""\s+"""), " ")
            .trim()
    }

    private fun extractRelevantPageExcerpt(
        text: String,
        question: String,
    ): String {
        val normalizedText = text.replace(Regex("\\s+"), " ").trim()
        if (normalizedText.isBlank()) {
            return ""
        }

        val terms = question
            .lowercase()
            .split(Regex("""[^0-9A-Za-z\uAC00-\uD7A3]+"""))
            .map { term -> term.trim() }
            .filter { term -> term.length >= 3 }
            .filterNot { term -> term in pageSearchStopWords }
            .distinct()
            .take(12)
        if (terms.isEmpty()) {
            return normalizedText.take(WEB_PAGE_EXCERPT_CHARS)
        }

        val paragraphs = text
            .split(Regex("""\n{2,}|(?<=[.!?。])\s+"""))
            .map { paragraph -> paragraph.replace(Regex("\\s+"), " ").trim() }
            .filter { paragraph -> paragraph.length >= 80 }
        val ranked = paragraphs
            .map { paragraph ->
                val lower = paragraph.lowercase()
                val score = terms.count { term -> lower.contains(term) }
                score to paragraph
            }
            .filter { (score, _) -> score > 0 }
            .sortedByDescending { (score, paragraph) -> score * 1000 + paragraph.length.coerceAtMost(500) }
            .map { (_, paragraph) -> paragraph }

        val selected = ranked.ifEmpty { paragraphs.take(3) }
        return selected
            .joinToString(separator = "\n\n")
            .take(WEB_PAGE_EXCERPT_CHARS)
            .trim()
            .ifBlank { normalizedText.take(WEB_PAGE_EXCERPT_CHARS) }
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
        private const val WEB_SEARCH_TOTAL_TIMEOUT_MS = 15_000L
        private const val WEB_SEARCH_PARALLELISM = 3
        private const val WEB_SEARCH_RESULT_LIMIT = 5
        private const val WEB_SEARCH_CANDIDATE_LIMIT = 8
        private const val MAX_WEB_SEARCH_QUERIES = 3
        private const val WEB_PAGE_DETAIL_LIMIT = 3
        private const val WEB_PAGE_CONNECT_TIMEOUT_MS = 6_000
        private const val WEB_PAGE_READ_TIMEOUT_MS = 8_000
        private const val WEB_PAGE_TOTAL_TIMEOUT_MS = 28_000L
        private const val WEB_PAGE_MAX_BYTES = 350_000
        private const val WEB_PAGE_EXCERPT_CHARS = 3_500
        private const val WEB_PAGE_MIN_SAFE_EXCERPT_CHARS = 700
        private const val WEB_SEARCH_QUERY_REDACTED_MESSAGE =
            "Web search query was removed because it contained only private or local data. No external request was sent."
    }
}

private fun String.cleanHtmlText(): String =
    replace(Regex("""(?is)<script\b.*?</script>"""), " ")
        .replace(Regex("""(?is)<style\b.*?</style>"""), " ")
        .replace(Regex("""(?is)<[^>]+>"""), " ")
        .decodeHtmlEntities()
        .replace(Regex("\\s+"), " ")
        .trim()

private fun String.cleanPageText(): String =
    replace(Regex("""(?is)<script\b.*?</script>"""), " ")
        .replace(Regex("""(?is)<style\b.*?</style>"""), " ")
        .replace(Regex("""(?is)<noscript\b.*?</noscript>"""), " ")
        .replace(Regex("""(?is)<(br|p|div|section|article|li|tr|h[1-6])\b[^>]*>"""), "\n")
        .replace(Regex("""(?is)</(p|div|section|article|li|tr|h[1-6])>"""), "\n")
        .replace(Regex("""(?is)<[^>]+>"""), " ")
        .decodeHtmlEntities()
        .replace(Regex("""[ \t\x0B\f\r]+"""), " ")
        .replace(Regex("""\n\s+"""), "\n")
        .replace(Regex("""\n{3,}"""), "\n\n")
        .trim()

private fun String.isLikelyReadableText(): Boolean {
    val normalized = lowercase()
    if (normalized.isBlank()) {
        return true
    }
    return normalized.startsWith("text/") ||
        normalized.contains("html") ||
        normalized.contains("xhtml") ||
        normalized.contains("xml") ||
        normalized.contains("json")
}

private fun String.extractCharset(): Charset? =
    Regex("""(?i)charset=([^;\s]+)""").find(this)
        ?.groupValues
        ?.getOrNull(1)
        ?.trim('"', '\'')
        ?.let { charsetName -> runCatching { Charset.forName(charsetName) }.getOrNull() }

private fun InputStream.readTextLimited(
    charset: Charset,
    maxBytes: Int,
): String {
    val output = ByteArrayOutputStream()
    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
    var remaining = maxBytes
    while (remaining > 0) {
        val read = read(buffer, 0, minOf(buffer.size, remaining))
        if (read <= 0) {
            break
        }
        output.write(buffer, 0, read)
        remaining -= read
    }
    return output.toString(charset.name())
}

private fun String.decodeHtmlEntities(): String {
    val numericDecoded = Regex("""&#(\d+);""").replace(this) { match ->
        match.groupValues[1].toIntOrNull()?.let { codePoint ->
            runCatching { String(Character.toChars(codePoint)) }.getOrNull()
        } ?: match.value
    }
    val hexDecoded = Regex("""&#x([0-9A-Fa-f]+);""").replace(numericDecoded) { match ->
        match.groupValues[1].toIntOrNull(16)?.let { codePoint ->
            runCatching { String(Character.toChars(codePoint)) }.getOrNull()
        } ?: match.value
    }
    return htmlEntities.fold(hexDecoded) { text, (entity, value) ->
        text.replace(entity, value)
    }
}

private val htmlEntities = listOf(
    "&amp;" to "&",
    "&lt;" to "<",
    "&gt;" to ">",
    "&quot;" to "\"",
    "&#39;" to "'",
    "&apos;" to "'",
    "&nbsp;" to " ",
)

private val pageSearchStopWords = setOf(
    "the",
    "and",
    "for",
    "with",
    "from",
    "this",
    "that",
    "what",
    "when",
    "where",
    "how",
    "latest",
    "recent",
    "search",
    "find",
    "about",
    "2025",
    "2026",
)

private fun String.normalizeUrlForDedupe(): String =
    lowercase()
        .substringBefore("#")
        .trimEnd('/')

private inline fun <T : HttpURLConnection, R> T.use(block: (T) -> R): R =
    try {
        block(this)
    } finally {
        disconnect()
    }
