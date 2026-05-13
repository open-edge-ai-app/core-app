package com.onda.core

import android.content.Context
import com.onda.db.VectorDao
import com.onda.db.VectorDBHelper
import com.onda.db.VectorRecord

class QueryRouter(
    context: Context,
    vectorDBHelper: VectorDBHelper,
) : AutoCloseable {
    private val gemmaManager = GemmaManager()
    private val embedManager = EmbedManager(context)
    private val vectorDao = VectorDao(vectorDBHelper)
    private val chatContextManager = ChatContextManager(vectorDBHelper, gemmaManager)
    private val webSearchManager = WebSearchManager()

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "Message is empty."
        }

        val toolCall = decideToolCall(normalized)
        return when (toolCall?.name) {
            TOOL_RAG_SEARCH -> {
                val memories = searchMemories(toolCall.query.ifBlank { normalized })
                gemmaManager.generate(buildRagPrompt(normalized, memories), useRag = true)
            }
            TOOL_WEB_SEARCH -> {
                val webContext = webSearchManager.search(toolCall.query.ifBlank { normalized })
                gemmaManager.generate(buildWebPrompt(normalized, webContext), useRag = false)
            }
            else -> gemmaManager.generate(normalized, useRag = false)
        }
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
        val promptWithHistory = chatContextManager.buildPromptWithHistory(
            chatId = request.chatSessionId,
            currentPrompt = normalized,
            requestHistory = request.history,
        )
        val requestWithHistory = request.copy(text = promptWithHistory)
        val toolCall = if (request.useRag == true) {
            ToolCall(TOOL_RAG_SEARCH, normalized)
        } else {
            decideToolCall(normalized)
        }

        if (toolCall?.name == TOOL_RAG_SEARCH) {
            val memories = searchMemories(toolCall.query.ifBlank { normalized })
            val ragRequest = request.copy(text = buildRagPrompt(promptWithHistory, memories))
            return gemmaManager.generateMultimodal(ragRequest, useRag = true, modalities = modalities)
        }

        if (toolCall?.name == TOOL_WEB_SEARCH) {
            val webContext = webSearchManager.search(toolCall.query.ifBlank { normalized })
            val webRequest = request.copy(text = buildWebPrompt(promptWithHistory, webContext))
            return gemmaManager.generateMultimodal(webRequest, useRag = false, modalities = modalities)
        }

        return gemmaManager.generateMultimodal(requestWithHistory, useRag = false, modalities = modalities)
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

        val modalities = request.attachments.map { attachment -> attachment.type }.distinct()
        val promptWithHistory = chatContextManager.buildPromptWithHistory(
            chatId = request.chatSessionId,
            currentPrompt = normalized,
            requestHistory = request.history,
        )
        val requestWithHistory = request.copy(text = promptWithHistory)
        val toolCall = if (request.useRag == true) {
            ToolCall(TOOL_RAG_SEARCH, normalized)
        } else {
            decideToolCall(normalized)
        }
        val routedRequest = when (toolCall?.name) {
            TOOL_RAG_SEARCH -> {
                val memories = searchMemories(toolCall.query.ifBlank { normalized })
                request.copy(text = buildRagPrompt(promptWithHistory, memories))
            }
            TOOL_WEB_SEARCH -> {
                val webContext = webSearchManager.search(toolCall.query.ifBlank { normalized })
                request.copy(text = buildWebPrompt(promptWithHistory, webContext))
            }
            else -> requestWithHistory
        }

        return gemmaManager.generateMultimodalStream(
            request = routedRequest,
            useRag = toolCall?.name == TOOL_RAG_SEARCH,
            modalities = modalities,
            onPartial = onPartial,
            onComplete = onComplete,
            onError = onError,
        )
    }

    private fun decideToolCall(message: String): ToolCall? {
        return fallbackToolDecision(message)
    }

    private fun fallbackToolDecision(message: String): ToolCall? {
        val hints = listOf(
            "기억",
            "사진",
            "문자",
            "메시지",
            "갤러리",
            "영수증",
            "어디",
            "언제",
            "찾아",
            "보여",
            "memory",
            "photo",
            "image",
            "sms",
            "message",
            "receipt",
            "where",
            "when",
            "find",
            "show",
        )
        return if (hints.any { hint -> message.contains(hint, ignoreCase = true) }) {
            ToolCall(TOOL_RAG_SEARCH, message)
        } else {
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
