package com.onda.core

import android.content.Context
import com.onda.db.VectorDao
import com.onda.db.VectorDBHelper
import com.onda.db.VectorRecord
import org.json.JSONObject

class QueryRouter(
    context: Context,
    vectorDBHelper: VectorDBHelper,
) : AutoCloseable {
    private val gemmaManager = GemmaManager()
    private val embedManager = EmbedManager(context)
    private val vectorDao = VectorDao(vectorDBHelper)
    private val chatContextManager = ChatContextManager(vectorDBHelper, gemmaManager)

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "Message is empty."
        }

        val toolCall = decideToolCall(normalized)
        if (toolCall?.name != TOOL_RAG_SEARCH) {
            return gemmaManager.generate(normalized, useRag = false)
        }

        val memories = searchMemories(toolCall.query.ifBlank { normalized })
        return gemmaManager.generate(buildRagPrompt(normalized, memories), useRag = true)
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
        )
        val requestWithHistory = request.copy(text = promptWithHistory)
        val toolCall = if (request.useRag == true) {
            RagToolCall(TOOL_RAG_SEARCH, normalized)
        } else {
            decideToolCall(normalized)
        }

        if (toolCall?.name != TOOL_RAG_SEARCH) {
            return gemmaManager.generateMultimodal(requestWithHistory, useRag = false, modalities = modalities)
        }

        val memories = searchMemories(toolCall.query.ifBlank { normalized })
        val ragRequest = request.copy(text = buildRagPrompt(promptWithHistory, memories))
        return gemmaManager.generateMultimodal(ragRequest, useRag = true, modalities = modalities)
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
        )
        val requestWithHistory = request.copy(text = promptWithHistory)
        val toolCall = if (request.useRag == true) {
            RagToolCall(TOOL_RAG_SEARCH, normalized)
        } else {
            decideToolCall(normalized)
        }
        val routedRequest = if (toolCall?.name == TOOL_RAG_SEARCH) {
            val memories = searchMemories(toolCall.query.ifBlank { normalized })
            request.copy(text = buildRagPrompt(promptWithHistory, memories))
        } else {
            requestWithHistory
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

    private fun decideToolCall(message: String): RagToolCall? {
        val decision = gemmaManager.generate(buildToolDecisionPrompt(message), useRag = false)
        val json = extractJsonObject(decision) ?: return fallbackToolDecision(message)
        return try {
            val parsed = JSONObject(json)
            val tool = parsed.optString("tool", "none")
            if (tool == TOOL_RAG_SEARCH) {
                val arguments = parsed.optJSONObject("arguments")
                RagToolCall(
                    name = tool,
                    query = arguments?.optString("query").orEmpty().ifBlank { message },
                )
            } else {
                null
            }
        } catch (_: Exception) {
            fallbackToolDecision(message)
        }
    }

    private fun fallbackToolDecision(message: String): RagToolCall? {
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
            RagToolCall(TOOL_RAG_SEARCH, message)
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

    private fun buildToolDecisionPrompt(message: String): String =
        """
        You are the tool router for an on-device assistant.
        Decide whether the user question requires searching the local memory database.

        Available tool:
        - rag.search: Search local embedded memories from SMS and gallery photos.

        Use rag.search only when the user asks about personal past events, photos, receipts, messages, locations, dates, or something that must be remembered from the device.
        If no memory search is needed, return {"tool":"none","arguments":{}}.
        If memory search is needed, return {"tool":"rag.search","arguments":{"query":"short search query"}}.

        Return only compact JSON. Do not explain.

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

    private fun extractJsonObject(text: String): String? {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        return if (start >= 0 && end > start) {
            text.substring(start, end + 1)
        } else {
            null
        }
    }

    override fun close() {
        embedManager.close()
    }

    private data class RagToolCall(
        val name: String,
        val query: String,
    )

    companion object {
        private const val TOOL_RAG_SEARCH = "rag.search"
        private const val RAG_RESULT_LIMIT = 5
    }
}
