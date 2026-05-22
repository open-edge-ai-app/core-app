package com.openedgeai.core

import android.content.Context
import android.net.Uri
import android.util.Log
import com.openedgeai.db.DocumentCatalogRecord
import com.openedgeai.db.VectorDao
import com.openedgeai.db.VectorDBHelper
import com.openedgeai.db.VectorRecord
import com.openedgeai.db.VectorSearchResult
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class QueryRouter(
    context: Context,
    private val vectorDBHelper: VectorDBHelper,
) : AutoCloseable {
    private val gemmaManager = GemmaManager()
    private val embedManager = EmbedManager(context)
    private val vectorDao = VectorDao(vectorDBHelper)
    private val chatContextManager = ChatContextManager(vectorDBHelper, gemmaManager)
    private val webSearchManager = WebSearchManager(context.applicationContext, gemmaManager)
    private val documentTextExtractor = DocumentTextExtractor(context.applicationContext)
    private val nativeTools = OpenEdgeAiToolSet(
        embedManager = embedManager,
        vectorDao = vectorDao,
        webSearchManager = webSearchManager,
        documentTextExtractor = documentTextExtractor,
    )

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "Message is empty."
        }

        nativeTools.beginRequest()
        val text = gemmaManager.generate(
            message = normalized,
            useRag = false,
            nativeTools = nativeTools,
        )
        val footer = buildCitationFooter(emptyList(), nativeTools.consumeCitations())
        return text + footer
    }

    fun routeMultimodal(request: MultimodalRequest): AIResponse {
        val normalized = request.text.trim()
        if (normalized.isEmpty() && request.attachments.isEmpty()) {
            return AIResponse(
                type = "error",
                message = "Message and attachments are empty.",
                route = "invalid",
                modalities = emptyList(),
            )
        }

        request.unsupportedAndroidModelResponse()?.let { response ->
            return response
        }

        nativeTools.beginRequest()
        val modalities = request.attachments.map { attachment -> attachment.type }.distinct()
        val requestWithHistory = request.withBackendContext(normalized)
        val localRagPlan = buildLocalRagPlan(
            question = normalized,
            force = request.useRag == true,
        )
        if (localRagPlan.shouldUse && !request.forceWebSearch && !request.disableRetrieval) {
            val ragRequest = requestWithHistory.copy(
                text = buildRagPrompt(
                    question = normalized,
                    memories = localRagPlan.memories,
                    documentExcerpts = localRagPlan.documentExcerpts,
                ),
                nativeTools = nativeTools,
            )
            val response = gemmaManager.generateMultimodal(ragRequest, useRag = true, modalities = modalities)
            return response.withCitationFooter(routerCitationsFor(localRagPlan))
        }

        if (!request.disableRetrieval && (request.forceWebSearch || shouldUseWebSearch(normalized))) {
            val webContext = webSearchManager.search(
                query = normalized,
                useLocalLlmSanitizer = true,
            )
            val webRequest = requestWithHistory.copy(
                text = buildWebSearchPrompt(normalized, webContext),
                nativeTools = null,
            )
            val response = gemmaManager.generateMultimodal(webRequest, useRag = false, modalities = modalities)
            return response.withCitationFooter(routerCitationsFor(webContext))
        }

        val response = gemmaManager.generateMultimodal(
            request = requestWithHistory,
            useRag = false,
            modalities = modalities,
        )
        return response.withCitationFooter(emptyList())
    }

    private fun AIResponse.withCitationFooter(routerCitations: List<CitedSource>): AIResponse {
        val footer = buildCitationFooter(routerCitations, nativeTools.consumeCitations())
        if (footer.isEmpty()) {
            return this
        }
        return copy(message = message + footer)
    }

    fun routeMultimodalStream(
        request: MultimodalRequest,
        onPartial: (String, Boolean) -> Unit,
        onComplete: (AIResponse) -> Unit,
        onError: (Throwable) -> Unit,
    ): Boolean {
        val normalized = request.text.trim()
        if (normalized.isEmpty() && request.attachments.isEmpty()) {
            onComplete(
                AIResponse(
                    type = "error",
                    message = "Message and attachments are empty.",
                    route = "invalid",
                    modalities = emptyList(),
                ),
            )
            return false
        }

        request.unsupportedAndroidModelResponse()?.let { response ->
            onComplete(
                response,
            )
            return false
        }

        nativeTools.beginRequest()
        return try {
            val modalities = request.attachments.map { attachment -> attachment.type }.distinct()
            val requestWithHistory = request.withBackendContext(normalized)
            val completed = AtomicBoolean(false)

            fun completeWithFooter(routerCitations: List<CitedSource>, response: AIResponse) {
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                val footer = buildCitationFooter(routerCitations, nativeTools.consumeCitations())
                if (footer.isNotEmpty()) {
                    runCatching { onPartial(footer, false) }
                }
                val finalResponse =
                    if (footer.isEmpty()) response else response.copy(message = response.message + footer)
                onComplete(finalResponse)
            }

            fun errorOnce(error: Throwable) {
                if (completed.compareAndSet(false, true)) {
                    nativeTools.consumeCitations()
                    onError(error)
                }
            }

            val localRagPlan = buildLocalRagPlan(
                question = normalized,
                force = request.useRag == true,
            )
            if (localRagPlan.shouldUse && !request.forceWebSearch && !request.disableRetrieval) {
                val ragRequest = requestWithHistory.copy(
                    text = buildRagPrompt(
                        question = normalized,
                        memories = localRagPlan.memories,
                        documentExcerpts = localRagPlan.documentExcerpts,
                    ),
                    nativeTools = nativeTools,
                )
                val routerCitations = routerCitationsFor(localRagPlan)
                return gemmaManager.generateMultimodalStream(
                    request = ragRequest,
                    useRag = true,
                    modalities = modalities,
                    onPartial = onPartial,
                    onComplete = { response -> completeWithFooter(routerCitations, response) },
                    onError = ::errorOnce,
                )
            }

            if (!request.disableRetrieval && (request.forceWebSearch || shouldUseWebSearch(normalized))) {
                val webContext = webSearchManager.search(
                    query = normalized,
                    useLocalLlmSanitizer = true,
                )
                val webRequest = requestWithHistory.copy(
                    text = buildWebSearchPrompt(normalized, webContext),
                    nativeTools = null,
                )
                val routerCitations = routerCitationsFor(webContext)
                return gemmaManager.generateMultimodalStream(
                    request = webRequest,
                    useRag = false,
                    modalities = modalities,
                    onPartial = onPartial,
                    onComplete = { response -> completeWithFooter(routerCitations, response) },
                    onError = ::errorOnce,
                )
            }

            gemmaManager.generateMultimodalStream(
                request = requestWithHistory,
                useRag = false,
                modalities = modalities,
                onPartial = onPartial,
                onComplete = { response -> completeWithFooter(emptyList(), response) },
                onError = ::errorOnce,
            )
        } catch (error: Exception) {
            nativeTools.consumeCitations()
            onError(error)
            false
        }
    }

    private fun MultimodalRequest.withBackendContext(normalizedPrompt: String): MultimodalRequest {
        val historyMessages = chatContextManager.buildHistoryMessages(
            chatId = chatSessionId,
            currentPrompt = normalizedPrompt,
            requestHistory = history,
        )
        return copy(
            text = normalizedPrompt,
            history = historyMessages,
            nativeTools = nativeTools,
        )
    }

    private fun MultimodalRequest.unsupportedAndroidModelResponse(): AIResponse? {
        val normalizedModelId = modelId?.trim()?.lowercase(Locale.US).orEmpty()
        if (normalizedModelId.isEmpty() || normalizedModelId in ANDROID_GEMMA_MODEL_IDS) {
            return null
        }

        val modalities = attachments.map { attachment -> attachment.type }.distinct()
        if (normalizedModelId == APPLE_FOUNDATION_MODEL_ID) {
            return AIResponse(
                type = "error",
                message = IOS_SYSTEM_MODEL_ANDROID_ERROR,
                route = "invalid",
                modalities = modalities,
                modelId = APPLE_FOUNDATION_MODEL_ID,
                modelName = "Unsupported system model",
                provider = "system",
                requestedModelId = normalizedModelId,
            )
        }

        return AIResponse(
            type = "error",
            message = "Model '$normalizedModelId' is not supported on Android. Supported Android runtime is Gemma 4.",
            route = "invalid",
            modalities = modalities,
            modelId = normalizedModelId,
            modelName = normalizedModelId,
            provider = "unknown",
            requestedModelId = normalizedModelId,
        )
    }

    private fun searchMemoriesWithScores(query: String): List<VectorSearchResult> {
        if (!embedManager.isAvailable()) {
            return emptyList()
        }

        val queryEmbedding = embedManager.embed(query)
        return vectorDao.searchWithScores(queryEmbedding, RAG_RESULT_LIMIT)
    }

    private fun buildLocalRagPlan(
        question: String,
        force: Boolean,
    ): LocalRagPlan {
        val results = searchMemoriesWithScores(question)
        if (results.isEmpty()) {
            return LocalRagPlan(
                shouldUse = false,
                memories = emptyList(),
                documentExcerpts = emptyList(),
            )
        }

        val documentExcerpts = buildRelevantDocumentExcerpts(
            question = question,
            results = results,
            force = force,
        )
        val selectedDocumentIds = documentExcerpts.map { excerpt -> excerpt.documentId }.toSet()
        val localMemoryIntent = hasLocalMemoryIntent(question)
        val strongNonDocumentMemory = results.any { result ->
            result.record.source != SOURCE_DOCUMENT && result.score >= AUTO_MEMORY_VECTOR_MIN_SCORE
        }
        val shouldUse =
            (force && results.isNotEmpty()) ||
                documentExcerpts.isNotEmpty() ||
                (localMemoryIntent && strongNonDocumentMemory)

        if (!shouldUse) {
            Log.d(TAG, "BalancedRAG skipped query=${question.take(LOG_QUERY_CHARS)}")
            return LocalRagPlan(
                shouldUse = false,
                memories = emptyList(),
                documentExcerpts = emptyList(),
            )
        }

        val memories = results
            .filter { result ->
                force ||
                    result.record.source != SOURCE_DOCUMENT ||
                    result.record.sourceId in selectedDocumentIds
            }
            .map { result -> result.record }
            .take(RAG_RESULT_LIMIT)

        Log.d(
            TAG,
            "BalancedRAG use force=$force memories=${memories.size} docs=${documentExcerpts.size} query=${question.take(LOG_QUERY_CHARS)}",
        )
        return LocalRagPlan(
            shouldUse = true,
            memories = memories,
            documentExcerpts = documentExcerpts,
        )
    }

    private fun buildRelevantDocumentExcerpts(
        question: String,
        results: List<VectorSearchResult>,
        force: Boolean,
    ): List<DocumentExcerptEvidence> =
        results
            .filter { result -> result.record.source == SOURCE_DOCUMENT }
            .mapNotNull { result ->
                val document = vectorDao.getDocument(result.record.sourceId) ?: return@mapNotNull null
                val lexicalScore = documentLexicalScore(
                    query = question,
                    documentText = listOf(
                        document.name,
                        document.relativePath.orEmpty(),
                        document.preview,
                        result.record.text,
                    ).joinToString(" "),
                )
                ScoredDocumentCandidate(
                    result = result,
                    document = document,
                    lexicalScore = lexicalScore,
                )
            }
            .filter { candidate ->
                force ||
                    candidate.lexicalScore >= AUTO_DOCUMENT_LEXICAL_MIN_SCORE ||
                    (
                        hasLocalMemoryIntent(question) &&
                            candidate.lexicalScore >= LOCAL_INTENT_DOCUMENT_LEXICAL_MIN_SCORE
                    )
            }
            .sortedWith(
                compareByDescending<ScoredDocumentCandidate> { candidate -> candidate.lexicalScore }
                    .thenByDescending { candidate -> candidate.result.score },
            )
            .take(MAX_DOCUMENT_EXCERPTS)
            .mapNotNull { candidate ->
                val text = documentTextExtractor.readDocumentText(
                    uri = Uri.parse(candidate.document.uri),
                    mimeType = candidate.document.mimeType,
                )
                val excerpt = documentTextExtractor.extractRelevantExcerpt(
                    text = text.ifBlank { candidate.document.preview },
                    query = question,
                )
                if (excerpt.isBlank()) {
                    return@mapNotNull null
                }
                DocumentExcerptEvidence(
                    documentId = candidate.document.documentId,
                    name = candidate.document.name,
                    uri = candidate.document.uri,
                    relativePath = candidate.document.relativePath,
                    score = candidate.result.score,
                    lexicalScore = candidate.lexicalScore,
                    excerpt = excerpt,
                )
            }

    private fun hasLocalMemoryIntent(query: String): Boolean {
        val normalized = query.lowercase(Locale.US)
        return LOCAL_MEMORY_HINTS.any { hint -> normalized.contains(hint) }
    }

    private fun documentLexicalScore(
        query: String,
        documentText: String,
    ): Int {
        val document = documentText.lowercase(Locale.US)
        return querySearchTerms(query).count { term -> document.contains(term) }
    }

    private fun querySearchTerms(query: String): Set<String> {
        val terms = linkedSetOf<String>()
        TOKEN_REGEX.findAll(query.lowercase(Locale.US)).forEach { match ->
            val token = match.value.trim()
            if (token.length >= MIN_QUERY_TERM_LENGTH && token !in QUERY_STOP_WORDS) {
                terms.add(token)
            }
            if (token.any { char -> char in '가'..'힣' } && token.length >= 3) {
                token.windowed(size = 2).forEach { gram ->
                    if (gram !in QUERY_STOP_WORDS) {
                        terms.add(gram)
                    }
                }
            }
        }
        return terms
    }

    private fun buildRagPrompt(
        question: String,
        memories: List<VectorRecord>,
        documentExcerpts: List<DocumentExcerptEvidence>,
    ): String {
        val memoryText = if (memories.isEmpty()) {
            "No local memory records were found."
        } else {
            memories.joinToString(separator = "\n") { record ->
                val uriPart = record.uri?.let { " uri=$it" }.orEmpty()
                val metadataPart = record.metadata?.let { " metadata=$it" }.orEmpty()
                "- type=${record.source} source_id=${record.sourceId} time=${record.timestamp ?: "unknown"}$uriPart$metadataPart text=${record.text}"
            }
        }
        val documentExcerptText = if (documentExcerpts.isEmpty()) {
            "No relevant local document excerpts were read."
        } else {
            documentExcerpts.joinToString(separator = "\n\n") { excerpt ->
                """
                - document=${excerpt.name}
                  documentId=${excerpt.documentId}
                  score=${"%.3f".format(Locale.US, excerpt.score)}
                  lexicalScore=${excerpt.lexicalScore}
                  uri=${excerpt.uri}
                  excerpt=${excerpt.excerpt}
                """.trimIndent()
            }
        }

        return """
        You are an on-device assistant. Answer the user's question using the local memory records below.
        Use local document excerpts only when they are directly relevant to the user's question.
        When relevant document excerpts are present, prefer them over general model knowledge for document-specific details.
        Document catalog records are lightweight hits. If the excerpts are missing but a document record is clearly relevant, use readLocalDocument with the document source_id before finalizing.
        If the local records and excerpts do not contain enough evidence, say that you could not find it in local memory.
        Do not invent personal facts.
        Do not append your own source list, citation section, or "## 참고" footer to the answer. The system attaches a citation footer with file paths automatically after your answer.

        Local memory records:
        $memoryText

        Relevant local document excerpts:
        $documentExcerptText

        User question:
        $question
        """.trimIndent()
    }

    private fun routerCitationsFor(plan: LocalRagPlan): List<CitedSource> = buildList {
        plan.documentExcerpts.forEach { excerpt ->
            add(
                CitedSource.Document(
                    documentId = excerpt.documentId,
                    name = excerpt.name,
                    uri = excerpt.uri,
                    relativePath = excerpt.relativePath,
                ),
            )
        }
        plan.memories.forEach { record ->
            if (record.source == SOURCE_DOCUMENT) {
                return@forEach
            }
            add(
                CitedSource.Memory(
                    source = record.source,
                    sourceId = record.sourceId,
                    uri = record.uri,
                    text = record.text,
                ),
            )
        }
    }

    private fun routerCitationsFor(webContext: WebSearchContext): List<CitedSource> =
        webContext.sources.map { source ->
            CitedSource.Web(title = source.title, url = source.url)
        }

    private fun buildCitationFooter(
        routerCitations: List<CitedSource>,
        toolCitations: List<CitedSource>,
    ): String {
        val merged = (routerCitations + toolCitations).dedupCitations()
        if (merged.isEmpty()) {
            return ""
        }
        val lines = merged.map { citation -> citation.toFooterLine() }
        return buildString {
            append("\n\n## ")
            append(CITATION_HEADER)
            append('\n')
            append(lines.joinToString(separator = "\n"))
        }
    }

    private fun List<CitedSource>.dedupCitations(): List<CitedSource> {
        val seen = linkedSetOf<String>()
        return filter { citation ->
            val key = when (citation) {
                is CitedSource.Document -> "doc:${citation.documentId}"
                is CitedSource.Memory -> "mem:${citation.source}:${citation.sourceId}"
                is CitedSource.Web -> "web:${citation.url}"
            }
            seen.add(key)
        }
    }

    private fun CitedSource.toFooterLine(): String =
        when (this) {
            is CitedSource.Document -> {
                val location = relativePath?.takeIf { path -> path.isNotBlank() }
                    ?: uri.takeIf { value -> value.isNotBlank() }
                    ?: documentId
                "- 문서: $name — $location"
            }
            is CitedSource.Memory -> {
                val label = when (source) {
                    "sms" -> "SMS"
                    "gallery" -> "사진"
                    else -> source.replaceFirstChar { char -> char.uppercase() }
                }
                val location = uri?.takeIf { value -> value.isNotBlank() } ?: sourceId
                "- $label 기억: $location"
            }
            is CitedSource.Web -> {
                val label = title.takeIf { value -> value.isNotBlank() } ?: url
                "- 웹: $label — $url"
            }
        }

    private fun shouldUseWebSearch(query: String): Boolean {
        val normalized = query.lowercase(Locale.US)
        if (WEB_SEARCH_TRIGGERS.any { trigger -> normalized.contains(trigger) }) {
            return true
        }

        return shouldUseWebSearchWithLocalModel(query)
    }

    private fun shouldUseWebSearchWithLocalModel(query: String): Boolean {
        val prompt = """
        Decide whether this user request should use public web search before answering.

        Return exactly one token:
        - WEB
        - NO_WEB

        Use WEB when:
        - The user asks for latest, recent, current, live, news, prices, schedules, versions, laws, public people, companies, products, research trends, or facts that may have changed.
        - The answer likely requires public external details not available from local/private memory or stable model knowledge.
        - The user explicitly asks to search, look up, verify, compare current options, or cite external sources.

        Use NO_WEB when:
        - The request is about private/local files, SMS, photos, saved chats, or device memory.
        - The request is a stable general explanation, writing task, calculation, translation, or ordinary conversation.
        - The request can be answered from the provided conversation context without public external facts.

        User request:
        $query
        """.trimIndent()

        return runCatching {
            gemmaManager.generate(prompt, useRag = false)
                .trim()
                .lineSequence()
                .firstOrNull { line -> line.isNotBlank() }
                .orEmpty()
                .trim()
                .uppercase(Locale.US)
                .startsWith("WEB")
        }.getOrDefault(false)
    }

    private fun buildWebSearchPrompt(
        question: String,
        webContext: WebSearchContext,
    ): String =
        """
        Answer the user's question using the numbered web sources below.
        Treat these results as fetched live from the public web.
        If the results are empty or failed, say that web search did not return enough information.
        Prefer sources that include "Page content" over snippet-only sources.
        Cite sources inline as [1], [2], ... using the source numbers below. The numbers match the source list shown to the user, so cite the exact number of each source you rely on.
        Do not say that you cannot browse the web; the web search has already been performed.
        Do not append your own source list, citation section, or "## 참고" footer to the answer. The system attaches a citation footer with URLs automatically after your answer.

        Sanitized web queries:
        ${webContext.sanitizedQuery}

        Privacy:
        ${if (webContext.privacyMasked) "Private data was masked before external search." else "No private data was detected in the public query."}

        Numbered web sources:
        ${webContext.resultsText}

        User question:
        $question
        """.trimIndent()

    override fun close() {
        embedManager.close()
    }

    companion object {
        private const val TAG = "QueryRouter"
        private const val RAG_RESULT_LIMIT = 5
        private const val CITATION_HEADER = "참고한 자료"
        private const val MAX_DOCUMENT_EXCERPTS = 3
        private const val AUTO_DOCUMENT_LEXICAL_MIN_SCORE = 2
        private const val LOCAL_INTENT_DOCUMENT_LEXICAL_MIN_SCORE = 1
        private const val AUTO_MEMORY_VECTOR_MIN_SCORE = 0.52f
        private const val LOG_QUERY_CHARS = 80
        private const val SOURCE_DOCUMENT = "document"
        private const val MIN_QUERY_TERM_LENGTH = 2
        private const val APPLE_FOUNDATION_MODEL_ID = "apple-foundation"
        private const val IOS_SYSTEM_MODEL_ANDROID_ERROR =
            "Requested iOS system model is not available on Android. Android uses the Gemma runtime."
        private val ANDROID_GEMMA_MODEL_IDS = setOf(
            "",
            "auto",
            "gemma-4",
            "gemma-lite",
            "gemma-deep",
        )
        private val TOKEN_REGEX = Regex("""[0-9A-Za-z가-힣]+""")
        private val LOCAL_MEMORY_HINTS = listOf(
            "document",
            "documents",
            "file",
            "files",
            "local",
            "memory",
            "rag",
            "문서",
            "파일",
            "자료",
            "내부",
            "로컬",
            "기억",
            "저장",
            "다운로드",
        )
        private val QUERY_STOP_WORDS = setOf(
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
            "files",
            "문서",
            "파일",
            "내용",
            "어떤",
            "점들",
            "뭐야",
            "뭔가",
            "해줘",
            "해야",
            "관련",
            "설명",
            "정리",
        )
        private val WEB_SEARCH_TRIGGERS = listOf(
            "검색",
            "찾아",
            "찾아봐",
            "찾아줘",
            "구글",
            "웹",
            "인터넷",
            "출처",
            "근거",
            "링크",
            "뉴스",
            "최신",
            "실시간",
            "현재",
            "검증",
            "search",
            "google",
            "web",
            "internet",
            "source",
            "sources",
            "lookup",
            "look up",
            "latest",
            "recent",
            "current",
            "news",
            "verify",
        )
    }
}

private data class LocalRagPlan(
    val shouldUse: Boolean,
    val memories: List<VectorRecord>,
    val documentExcerpts: List<DocumentExcerptEvidence>,
)

private data class ScoredDocumentCandidate(
    val result: VectorSearchResult,
    val document: DocumentCatalogRecord,
    val lexicalScore: Int,
)

private data class DocumentExcerptEvidence(
    val documentId: String,
    val name: String,
    val uri: String,
    val relativePath: String?,
    val score: Float,
    val lexicalScore: Int,
    val excerpt: String,
)
