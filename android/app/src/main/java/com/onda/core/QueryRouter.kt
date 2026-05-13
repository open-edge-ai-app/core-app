package com.onda.core

import android.content.Context
import com.onda.db.VectorDao
import com.onda.db.VectorDBHelper
import com.onda.db.VectorRecord
import org.json.JSONObject

class QueryRouter(
    context: Context,
    private val vectorDBHelper: VectorDBHelper,
) : AutoCloseable {
    private val gemmaManager = GemmaManager()
    private val embedManager = EmbedManager(context)
    private val vectorDao = VectorDao(vectorDBHelper)
    private val chatContextManager = ChatContextManager(vectorDBHelper, gemmaManager)
    private val webSearchManager = WebSearchManager(gemmaManager)

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "Message is empty."
        }

        if (!shouldUseToolPrompt(normalized)) {
            return gemmaManager.generate(normalized, useRag = false)
        }

        val initialResponse = gemmaManager.generate(buildToolAwarePrompt(normalized), useRag = false)
        return generateAfterToolCall(initialResponse, normalized) ?: initialResponse
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

        val historyMessages = chatContextManager.buildHistoryMessages(
            chatId = request.chatSessionId,
            currentPrompt = normalized,
            requestHistory = request.history,
        )
        val requestWithHistory = request.copy(text = normalized, history = historyMessages)

        if (request.useRag == true) {
            val memories = searchMemories(normalized)
            val ragRequest = requestWithHistory.copy(text = buildRagPrompt(normalized, memories))
            return gemmaManager.generateMultimodal(ragRequest, useRag = true, modalities = modalities)
        }

        val shouldUseTools = shouldUseToolPrompt(normalized)
        val initialRequest = requestWithHistory.copy(
            text = if (shouldUseTools) buildToolAwarePrompt(normalized) else normalized,
        )
        val initialResponse = gemmaManager.generateMultimodal(
            request = initialRequest,
            useRag = false,
            modalities = modalities,
        )

        return if (shouldUseTools) {
            generateMultimodalAfterToolCall(
                initialText = initialResponse.message,
                originalQuestion = normalized,
                originalRequest = requestWithHistory,
                modalities = modalities,
            ) ?: initialResponse
        } else {
            initialResponse
        }
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

            val historyMessages = chatContextManager.buildHistoryMessages(
                chatId = request.chatSessionId,
                currentPrompt = normalized,
                requestHistory = request.history,
            )
            val requestWithHistory = request.copy(text = normalized, history = historyMessages)
            val completed = java.util.concurrent.atomic.AtomicBoolean(false)
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
                val ragRequest = requestWithHistory.copy(text = buildRagPrompt(normalized, memories))
                return gemmaManager.generateMultimodalStream(
                    request = ragRequest,
                    useRag = true,
                    modalities = modalities,
                    onPartial = onPartial,
                    onComplete = ::completeOnce,
                    onError = ::errorOnce,
                )
            }

            val shouldUseTools = shouldUseToolPrompt(normalized)
            val initialRequest = requestWithHistory.copy(
                text = if (shouldUseTools) buildToolAwarePrompt(normalized) else normalized,
            )
            val initialBuffer = StringBuilder()
            var directStreaming = !shouldUseTools

            gemmaManager.generateMultimodalStream(
                request = initialRequest,
                useRag = false,
                modalities = modalities,
                onPartial = { chunk, done ->
                    if (directStreaming) {
                        onPartial(chunk, done)
                    } else {
                        initialBuffer.append(chunk)
                        val buffered = initialBuffer.toString()
                        val trimmedStart = buffered.trimStart()
                        if (trimmedStart.isNotEmpty() && trimmedStart.first() != '{') {
                            directStreaming = true
                            onPartial(buffered, false)
                            initialBuffer.clear()
                        }
                    }
                },
                onComplete = { initialResponse ->
                    val initialText = initialResponse.message.ifBlank { initialBuffer.toString() }
                    if (directStreaming) {
                        completeOnce(
                            AIResponse(
                                type = initialResponse.type,
                                message = initialText,
                                route = initialResponse.route,
                                modalities = modalities,
                            ),
                        )
                        return@generateMultimodalStream
                    }

                    val toolCall = parseToolCall(initialText)
                    if (toolCall == null) {
                        onPartial(initialText, true)
                        completeOnce(
                            AIResponse(
                                type = initialResponse.type,
                                message = initialText,
                                route = initialResponse.route,
                                modalities = modalities,
                            ),
                        )
                        return@generateMultimodalStream
                    }

                    when (toolCall.name) {
                        TOOL_RAG_SEARCH -> {
                            val memories = searchMemories(toolCall.query.ifBlank { normalized })
                            val ragRequest = requestWithHistory.copy(text = buildRagPrompt(normalized, memories))
                            gemmaManager.generateMultimodalStream(
                                request = ragRequest,
                                useRag = true,
                                modalities = modalities,
                                onPartial = onPartial,
                                onComplete = ::completeOnce,
                                onError = ::errorOnce,
                            )
                        }
                        TOOL_WEB_SEARCH -> {
                            val webContext = webSearchManager.search(toolCall.query.ifBlank { normalized })
                            val webRequest = requestWithHistory.copy(text = buildWebPrompt(normalized, webContext))
                            gemmaManager.generateMultimodalStream(
                                request = webRequest,
                                useRag = false,
                                modalities = modalities,
                                onPartial = onPartial,
                                onComplete = ::completeOnce,
                                onError = ::errorOnce,
                            )
                        }
                        else -> {
                            onPartial(initialText, true)
                            completeOnce(
                                AIResponse(
                                    type = initialResponse.type,
                                    message = initialText,
                                    route = initialResponse.route,
                                    modalities = modalities,
                                ),
                            )
                        }
                    }
                },
                onError = ::errorOnce,
            )
        } catch (error: Exception) {
            onError(error)
            false
        }
    }

    private fun generateAfterToolCall(
        initialText: String,
        originalQuestion: String,
    ): String? {
        val toolCall = parseToolCall(initialText) ?: return null
        return when (toolCall.name) {
            TOOL_RAG_SEARCH -> {
                val memories = searchMemories(toolCall.query.ifBlank { originalQuestion })
                gemmaManager.generate(buildRagPrompt(originalQuestion, memories), useRag = true)
            }
            TOOL_WEB_SEARCH -> {
                val webContext = webSearchManager.search(toolCall.query.ifBlank { originalQuestion })
                gemmaManager.generate(buildWebPrompt(originalQuestion, webContext), useRag = false)
            }
            else -> null
        }
    }

    private fun generateMultimodalAfterToolCall(
        initialText: String,
        originalQuestion: String,
        originalRequest: MultimodalRequest,
        modalities: List<String>,
    ): AIResponse? {
        val toolCall = parseToolCall(initialText) ?: return null
        return when (toolCall.name) {
            TOOL_RAG_SEARCH -> {
                val memories = searchMemories(toolCall.query.ifBlank { originalQuestion })
                val ragRequest = originalRequest.copy(text = buildRagPrompt(originalQuestion, memories))
                gemmaManager.generateMultimodal(ragRequest, useRag = true, modalities = modalities)
            }
            TOOL_WEB_SEARCH -> {
                val webContext = webSearchManager.search(toolCall.query.ifBlank { originalQuestion })
                val webRequest = originalRequest.copy(text = buildWebPrompt(originalQuestion, webContext))
                gemmaManager.generateMultimodal(webRequest, useRag = false, modalities = modalities)
            }
            else -> null
        }
    }

    private fun parseToolCall(text: String): ToolCall? {
        val json = text.trim()
        if (!json.startsWith("{") || !json.endsWith("}")) {
            return null
        }
        return try {
            val parsed = JSONObject(json)
            val tool = parsed.optString("tool", parsed.optString("name", "none"))
            if (tool == TOOL_RAG_SEARCH || tool == TOOL_WEB_SEARCH) {
                val arguments = parsed.optJSONObject("arguments")
                ToolCall(
                    name = tool,
                    query = arguments?.optString("query").orEmpty(),
                )
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun searchMemories(query: String): List<VectorRecord> {
        if (!embedManager.isAvailable()) {
            return emptyList()
        }

        val queryEmbedding = embedManager.embed(query)
        return vectorDao.search(queryEmbedding, RAG_RESULT_LIMIT)
    }

    private fun shouldUseToolPrompt(message: String): Boolean {
        val normalized = message.lowercase()
        val toolHints = listOf(
            "rag",
            "검색",
            "찾아",
            "찾아줘",
            "보여",
            "기억",
            "사진",
            "이미지",
            "갤러리",
            "문자",
            "sms",
            "메시지",
            "파일",
            "문서",
            "pdf",
            "영수증",
            "일정",
            "캘린더",
            "최신",
            "뉴스",
            "날씨",
            "주가",
            "search",
            "find",
            "show",
            "photo",
            "image",
            "message",
            "document",
            "receipt",
            "calendar",
            "latest",
            "news",
            "weather",
            "stock",
        )
        return toolHints.any { hint -> normalized.contains(hint) }
    }

    private fun buildToolAwarePrompt(message: String): String =
        """
        Answer normally unless a tool is clearly required.

        Tools:
        - rag.search: private local memories: SMS, gallery photos, documents, saved chat context.
        - web.search: current or public web information.

        Tool call format:
        {"tool":"rag.search","arguments":{"query":"short search query"}}
        or
        {"tool":"web.search","arguments":{"query":"sanitized public search query"}}

        Only output a tool call when the whole response is exactly one compact JSON object.
        Never output tool_result. Never write "No tool call required".
        Use rag.search only for explicit requests to find remembered private data from the device.
        Use web.search only for explicit requests for current public information.
        Do not use tools for greetings, assistant identity, math, writing help, coding help, or facts already present in this chat.
        Never send private text, file paths, phone numbers, emails, addresses, account numbers, or secrets to web.search.
        Never output hidden reasoning, analysis steps, Thinking Process text, or channel tags.

        User question:
        $message
        """.trimIndent()

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

    private fun buildWebPrompt(
        question: String,
        webContext: WebSearchContext,
    ): String {
        val maskedNotice = if (webContext.privacyMasked) {
            "Privacy masking was applied before any web request. Masked fields: ${webContext.maskedTypes.joinToString(", ")}."
        } else {
            "No privacy masking was needed for the web query."
        }
        val llmSanitizeNotice = if (webContext.llmSanitized) {
            "A local LLM sanitizer rewrote the web query before provider execution."
        } else {
            "The local LLM sanitizer did not change the web query."
        }

        return """
        You are an on-device assistant. The user asked for public web information.
        Use only the public web search context below. If web search is not configured or the results are insufficient, say that current web information is unavailable instead of inventing facts.

        Sanitized web query:
        ${webContext.sanitizedQuery}

        Privacy status:
        $maskedNotice
        $llmSanitizeNotice

        Public web search context:
        ${webContext.resultsText}

        User question:
        $question
        """.trimIndent()
    }

    override fun close() {
        embedManager.close()
    }

    private data class ToolCall(
        val name: String,
        val query: String,
    )

    companion object {
        private const val TOOL_RAG_SEARCH = "rag.search"
        private const val TOOL_WEB_SEARCH = "web.search"
        private const val RAG_RESULT_LIMIT = 5
    }
}
