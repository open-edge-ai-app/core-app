package com.openedgeai.core

import android.content.Context
import com.openedgeai.db.VectorDao
import com.openedgeai.db.VectorDBHelper
import com.openedgeai.db.VectorRecord
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
    private val nativeTools = OpenEdgeAiToolSet(
        embedManager = embedManager,
        vectorDao = vectorDao,
        webSearchManager = webSearchManager,
    )

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "Message is empty."
        }

        return gemmaManager.generate(
            message = normalized,
            useRag = false,
            nativeTools = nativeTools,
        )
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

        val modalities = request.attachments.map { attachment -> attachment.type }.distinct()
        val requestWithHistory = request.withBackendContext(normalized)

        if (request.useRag != true && shouldUseWebSearch(normalized)) {
            val webContext = webSearchManager.search(
                query = normalized,
                useLocalLlmSanitizer = true,
            )
            val webRequest = requestWithHistory.copy(
                text = buildWebSearchPrompt(normalized, webContext),
                nativeTools = null,
            )
            return gemmaManager.generateMultimodal(webRequest, useRag = false, modalities = modalities)
        }

        if (request.useRag == true) {
            val memories = searchMemories(normalized)
            val ragRequest = requestWithHistory.copy(
                text = buildRagPrompt(normalized, memories),
                nativeTools = null,
            )
            return gemmaManager.generateMultimodal(ragRequest, useRag = true, modalities = modalities)
        }

        return gemmaManager.generateMultimodal(
            request = requestWithHistory,
            useRag = false,
            modalities = modalities,
        )
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

        return try {
            val modalities = request.attachments.map { attachment -> attachment.type }.distinct()
            val requestWithHistory = request.withBackendContext(normalized)
            val completed = AtomicBoolean(false)

            fun completeOnce(response: AIResponse) {
                if (completed.compareAndSet(false, true)) {
                    onComplete(response)
                }
            }

            fun errorOnce(error: Throwable) {
                if (completed.compareAndSet(false, true)) {
                    onError(error)
                }
            }

            if (request.useRag == true) {
                val memories = searchMemories(normalized)
                val ragRequest = requestWithHistory.copy(
                    text = buildRagPrompt(normalized, memories),
                    nativeTools = null,
                )
                return gemmaManager.generateMultimodalStream(
                    request = ragRequest,
                    useRag = true,
                    modalities = modalities,
                    onPartial = onPartial,
                    onComplete = ::completeOnce,
                    onError = ::errorOnce,
                )
            }

            if (shouldUseWebSearch(normalized)) {
                val webContext = webSearchManager.search(
                    query = normalized,
                    useLocalLlmSanitizer = true,
                )
                val webRequest = requestWithHistory.copy(
                    text = buildWebSearchPrompt(normalized, webContext),
                    nativeTools = null,
                )
                return gemmaManager.generateMultimodalStream(
                    request = webRequest,
                    useRag = false,
                    modalities = modalities,
                    onPartial = onPartial,
                    onComplete = ::completeOnce,
                    onError = ::errorOnce,
                )
            }

            gemmaManager.generateMultimodalStream(
                request = requestWithHistory,
                useRag = false,
                modalities = modalities,
                onPartial = onPartial,
                onComplete = ::completeOnce,
                onError = ::errorOnce,
            )
        } catch (error: Exception) {
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

    private fun searchMemories(query: String): List<VectorRecord> {
        if (!embedManager.isAvailable()) {
            return emptyList()
        }

        val queryEmbedding = embedManager.embed(query)
        return vectorDao.search(queryEmbedding, RAG_RESULT_LIMIT)
    }

    private fun buildRagPrompt(
        question: String,
        memories: List<VectorRecord>,
    ): String {
        val memoryText = if (memories.isEmpty()) {
            "No local memory records were found."
        } else {
            memories.joinToString(separator = "\n") { record ->
                val uriPart = record.uri?.let { " uri=$it" }.orEmpty()
                "- type=${record.source} time=${record.timestamp ?: "unknown"}$uriPart text=${record.text}"
            }
        }

        return """
        You are an on-device assistant. Answer the user's question using the local memory records below.
        If the records do not contain enough evidence, say that you could not find it in local memory.
        Do not invent personal facts.

        Local memory records:
        $memoryText

        User question:
        $question
        """.trimIndent()
    }

    private fun shouldUseWebSearch(query: String): Boolean {
        val normalized = query.lowercase()
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
                .uppercase()
                .startsWith("WEB")
        }.getOrDefault(false)
    }

    private fun buildWebSearchPrompt(
        question: String,
        webContext: WebSearchContext,
    ): String =
        """
        Answer the user's question using the web search and opened URL results below.
        Treat these results as fetched live from the public web.
        If the results are empty or failed, say that web search did not return enough information.
        Cite source URLs for factual claims based on web results.
        Prefer the opened URL details over search result snippets.
        Do not say that you cannot browse the web; the web search has already been performed.

        Sanitized web queries:
        ${webContext.sanitizedQuery}

        Privacy:
        ${if (webContext.privacyMasked) "Private data was masked before external search." else "No private data was detected in the public query."}

        Web search results:
        ${webContext.resultsText}

        User question:
        $question
        """.trimIndent()

    override fun close() {
        embedManager.close()
    }

    companion object {
        private const val RAG_RESULT_LIMIT = 5
        private val WEB_SEARCH_TRIGGERS = listOf(
            "웹",
            "검색",
            "찾아봐",
            "찾아줘",
            "뒤져",
            "구글",
            "뉴스",
            "최신",
            "실시간",
            "현재",
            "요즘",
        )
    }
}
