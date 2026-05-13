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
    private val webSearchManager = WebSearchManager(gemmaManager)
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

    override fun close() {
        embedManager.close()
    }

    companion object {
        private const val RAG_RESULT_LIMIT = 5
    }
}
