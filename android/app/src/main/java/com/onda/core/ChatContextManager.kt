package com.onda.core

import com.onda.db.ChatHistoryRecord
import com.onda.db.ChatMessageRecord
import com.onda.db.VectorDBHelper
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max

data class ChatCompactionResult(
    val chatId: String,
    val compacted: Boolean,
    val trigger: String,
    val message: String,
    val beforeTokenEstimate: Int,
    val afterTokenEstimate: Int,
    val compactedUntilMessageId: String?,
    val snapshotId: Long,
)

class ChatContextManager(
    private val dbHelper: VectorDBHelper,
    private val gemmaManager: GemmaManager,
) {
    fun recordContextSnapshot(
        chatId: String,
        messages: List<ChatMessageRecord>,
        systemPrompt: String? = null,
    ): Long {
        val latestSnapshot = getLatestSnapshot(chatId)
        val carriedSummary = latestSnapshot?.compactSummary()
        val snapshot = if (carriedSummary == null) {
            buildRawSnapshot(chatId, messages, systemPrompt)
        } else {
            val compactedUntilSortOrder = latestSnapshot.compactedUntilSortOrder()
            buildCarriedSnapshot(
                chatId = chatId,
                summary = carriedSummary,
                compactedUntilMessageId = latestSnapshot.compactedUntilMessageId(),
                compactedUntilSortOrder = compactedUntilSortOrder,
                messages = messages.filter { message ->
                    compactedUntilSortOrder == null || message.sortOrder > compactedUntilSortOrder
                },
                systemPrompt = systemPrompt,
            )
        }
        return dbHelper.insertChatHistory(
            ChatHistoryRecord(
                id = 0,
                chatId = chatId,
                eventType = EVENT_CONTEXT_SNAPSHOT,
                payload = snapshot.toString(),
                createdAt = System.currentTimeMillis(),
            ),
        )
    }

    fun compactIfNeeded(
        chatId: String,
        trigger: String,
        force: Boolean = false,
    ): ChatCompactionResult {
        val session = dbHelper.getChatSession(chatId)
            ?: return ChatCompactionResult(
                chatId = chatId,
                compacted = false,
                trigger = trigger,
                message = "Chat session was not found.",
                beforeTokenEstimate = 0,
                afterTokenEstimate = 0,
                compactedUntilMessageId = null,
                snapshotId = 0,
            )

        val messages = session.messages.filter { message ->
            message.text.isNotBlank() && message.id != WELCOME_MESSAGE_ID
        }
        val beforeTokens = estimateTokens(messages.joinToString("\n") { "${it.role}: ${it.text}" })

        if (!force && beforeTokens < AUTO_COMPACT_THRESHOLD_TOKENS) {
            val snapshotId = recordContextSnapshot(chatId, messages)
            return ChatCompactionResult(
                chatId = chatId,
                compacted = false,
                trigger = trigger,
                message = "Context is below the auto compact threshold.",
                beforeTokenEstimate = beforeTokens,
                afterTokenEstimate = beforeTokens,
                compactedUntilMessageId = null,
                snapshotId = snapshotId,
            )
        }

        if (messages.size <= RECENT_MESSAGE_COUNT) {
            val snapshotId = recordContextSnapshot(chatId, messages)
            return ChatCompactionResult(
                chatId = chatId,
                compacted = false,
                trigger = trigger,
                message = "There are not enough messages to compact yet.",
                beforeTokenEstimate = beforeTokens,
                afterTokenEstimate = beforeTokens,
                compactedUntilMessageId = null,
                snapshotId = snapshotId,
            )
        }

        val latestSnapshot = getLatestSnapshot(chatId)
        val carriedSummary = latestSnapshot?.compactSummary()
        val compactedUntilSortOrder = latestSnapshot?.compactedUntilSortOrder()
        val uncompactedMessages = messages.filter { message ->
            compactedUntilSortOrder == null || message.sortOrder > compactedUntilSortOrder
        }
        val recentMessages = messages.takeLast(RECENT_MESSAGE_COUNT)
        val messagesToSummarize = if (uncompactedMessages.size > RECENT_MESSAGE_COUNT) {
            uncompactedMessages.dropLast(RECENT_MESSAGE_COUNT)
        } else {
            messages.dropLast(RECENT_MESSAGE_COUNT)
        }
        val compactedUntil = messagesToSummarize.lastOrNull()
        val summary = summarizeContext(
            previousSummary = carriedSummary,
            messages = messagesToSummarize,
        )
        val snapshot = buildCompactSnapshot(
            chatId = chatId,
            summary = summary,
            compactedUntil = compactedUntil,
            recentMessages = recentMessages,
            trigger = trigger,
            beforeTokens = beforeTokens,
        )
        val snapshotId = dbHelper.insertChatHistory(
            ChatHistoryRecord(
                id = 0,
                chatId = chatId,
                eventType = EVENT_COMPACT_SNAPSHOT,
                payload = snapshot.toString(),
                createdAt = System.currentTimeMillis(),
            ),
        )
        val afterTokens = estimateTokens(snapshot.toString())

        return ChatCompactionResult(
            chatId = chatId,
            compacted = true,
            trigger = trigger,
            message = "Context was compacted into a summary snapshot.",
            beforeTokenEstimate = beforeTokens,
            afterTokenEstimate = afterTokens,
            compactedUntilMessageId = compactedUntil?.id,
            snapshotId = snapshotId,
        )
    }

    fun buildPromptWithHistory(
        chatId: String?,
        currentPrompt: String,
    ): String {
        if (chatId.isNullOrBlank()) {
            return currentPrompt
        }

        val snapshot = getLatestSnapshot(chatId) ?: return currentPrompt
        val contextMessages = snapshot.optJSONArray("messages") ?: return currentPrompt
        val renderedContext = renderMessages(contextMessages, currentPrompt)
        if (renderedContext.isBlank()) {
            return currentPrompt
        }

        return """
        You are continuing a local chat session.
        Use the context history below as the active conversation state. It may contain a compacted summary followed by recent exact messages.

        Context history:
        $renderedContext

        Current user message:
        $currentPrompt
        """.trimIndent()
    }

    private fun summarizeContext(
        previousSummary: String?,
        messages: List<ChatMessageRecord>,
    ): String {
        val messageText = messages.joinToString("\n") { message ->
            "${message.role}: ${message.text}"
        }
        val prompt = """
        Summarize this conversation context for a local on-device assistant.
        Preserve user goals, decisions, constraints, unresolved tasks, important technical details, and any file/API names.
        Keep it compact but specific enough that the next model call can continue the session.

        Previous compact summary:
        ${previousSummary ?: "None"}

        Messages to compact:
        $messageText
        """.trimIndent()

        val generated = gemmaManager.generate(prompt, useRag = false).trim()
        return generated
            .takeUnless { it.isBlank() || it.contains("runtime is not loaded", ignoreCase = true) }
            ?: fallbackSummary(previousSummary, messages)
    }

    private fun buildRawSnapshot(
        chatId: String,
        messages: List<ChatMessageRecord>,
        systemPrompt: String? = null,
    ): JSONObject =
        JSONObject().apply {
            put("version", SNAPSHOT_VERSION)
            put("type", "context_snapshot")
            put("chatId", chatId)
            put("messages", JSONArray().apply {
                if (!systemPrompt.isNullOrBlank()) {
                    put(
                        JSONObject().apply {
                            put("role", "system")
                            put("content", systemPrompt)
                        },
                    )
                }
                messages.forEach { message -> put(message.toContextJson()) }
            })
            put(
                "compact",
                JSONObject().apply {
                    put("isCompacted", false)
                    put("summary", JSONObject.NULL)
                    put("compactedUntilMessageId", JSONObject.NULL)
                    put("compactedUntilSortOrder", JSONObject.NULL)
                    put("trigger", JSONObject.NULL)
                    put("tokenEstimateBefore", estimateTokens(messages.joinToString("\n") { it.text }))
                    put("tokenEstimateAfter", estimateTokens(messages.joinToString("\n") { it.text }))
                },
            )
        }

    private fun buildCompactSnapshot(
        chatId: String,
        summary: String,
        compactedUntil: ChatMessageRecord?,
        recentMessages: List<ChatMessageRecord>,
        trigger: String,
        beforeTokens: Int,
    ): JSONObject =
        JSONObject().apply {
            put("version", SNAPSHOT_VERSION)
            put("type", "context_snapshot")
            put("chatId", chatId)
            put("messages", JSONArray().apply {
                put(
                    JSONObject().apply {
                        put("role", "system")
                        put(
                            "content",
                            "Previous conversation summary:\n$summary",
                        )
                        put("kind", "compact_boundary")
                    },
                )
                recentMessages.forEach { message -> put(message.toContextJson()) }
            })
            put(
                "compact",
                JSONObject().apply {
                    put("isCompacted", true)
                    put("summary", summary)
                    if (compactedUntil == null) {
                        put("compactedUntilMessageId", JSONObject.NULL)
                        put("compactedUntilSortOrder", JSONObject.NULL)
                    } else {
                        put("compactedUntilMessageId", compactedUntil.id)
                        put("compactedUntilSortOrder", compactedUntil.sortOrder)
                    }
                    put("trigger", trigger)
                    put("tokenEstimateBefore", beforeTokens)
                    put("tokenEstimateAfter", estimateTokens(summary) + estimateTokens(recentMessages.joinToString("\n") { it.text }))
                },
            )
        }

    private fun buildCarriedSnapshot(
        chatId: String,
        summary: String,
        compactedUntilMessageId: String?,
        compactedUntilSortOrder: Int?,
        messages: List<ChatMessageRecord>,
        systemPrompt: String? = null,
    ): JSONObject =
        JSONObject().apply {
            put("version", SNAPSHOT_VERSION)
            put("type", "context_snapshot")
            put("chatId", chatId)
            put("messages", JSONArray().apply {
                if (!systemPrompt.isNullOrBlank()) {
                    put(
                        JSONObject().apply {
                            put("role", "system")
                            put("content", systemPrompt)
                        },
                    )
                }
                put(
                    JSONObject().apply {
                        put("role", "system")
                        put("content", "Previous conversation summary:\n$summary")
                        put("kind", "compact_boundary")
                    },
                )
                messages.forEach { message -> put(message.toContextJson()) }
            })
            put(
                "compact",
                JSONObject().apply {
                    put("isCompacted", true)
                    put("summary", summary)
                    if (compactedUntilMessageId == null) {
                        put("compactedUntilMessageId", JSONObject.NULL)
                    } else {
                        put("compactedUntilMessageId", compactedUntilMessageId)
                    }
                    if (compactedUntilSortOrder == null) {
                        put("compactedUntilSortOrder", JSONObject.NULL)
                    } else {
                        put("compactedUntilSortOrder", compactedUntilSortOrder)
                    }
                    put("trigger", "carry_forward")
                    put("tokenEstimateBefore", estimateTokens(messages.joinToString("\n") { it.text }))
                    put("tokenEstimateAfter", estimateTokens(summary) + estimateTokens(messages.joinToString("\n") { it.text }))
                },
            )
        }

    private fun getLatestSnapshot(chatId: String): JSONObject? {
        val history = dbHelper.getLatestChatHistory(
            chatId = chatId,
            eventTypes = listOf(EVENT_COMPACT_SNAPSHOT, EVENT_CONTEXT_SNAPSHOT),
        ) ?: return null

        return try {
            JSONObject(history.payload)
        } catch (_: Exception) {
            null
        }
    }

    private fun renderMessages(messages: JSONArray, currentPrompt: String): String {
        val rendered = mutableListOf<String>()
        val normalizedCurrentPrompt = currentPrompt.trim()
        val lastNonBlankIndex = findLastNonBlankMessageIndex(messages)
        for (index in 0 until messages.length()) {
            val message = messages.optJSONObject(index) ?: continue
            val role = message.optString("role", "user")
            val content = message.optString("content", "").trim()
            val isCurrentPromptAlreadyInSnapshot =
                index == lastNonBlankIndex &&
                    role == "user" &&
                    normalizedCurrentPrompt.isNotBlank() &&
                    content == normalizedCurrentPrompt
            if (isCurrentPromptAlreadyInSnapshot) {
                continue
            }
            if (content.isNotBlank()) {
                rendered.add("$role: $content")
            }
        }
        return rendered.joinToString("\n")
    }

    private fun findLastNonBlankMessageIndex(messages: JSONArray): Int {
        for (index in messages.length() - 1 downTo 0) {
            val content = messages
                .optJSONObject(index)
                ?.optString("content", "")
                ?.trim()
                .orEmpty()
            if (content.isNotBlank()) {
                return index
            }
        }
        return -1
    }

    private fun JSONObject.compactSummary(): String? {
        val compact = optJSONObject("compact") ?: return null
        if (!compact.optBoolean("isCompacted", false)) {
            return null
        }
        return compact.optString("summary", "").takeIf { it.isNotBlank() }
    }

    private fun JSONObject.compactedUntilMessageId(): String? {
        val compact = optJSONObject("compact") ?: return null
        if (compact.isNull("compactedUntilMessageId")) {
            return null
        }
        return compact.optString("compactedUntilMessageId").takeIf { it.isNotBlank() }
    }

    private fun JSONObject.compactedUntilSortOrder(): Int? {
        val compact = optJSONObject("compact") ?: return null
        if (compact.isNull("compactedUntilSortOrder")) {
            return null
        }
        return compact.optInt("compactedUntilSortOrder")
    }

    private fun fallbackSummary(
        previousSummary: String?,
        messages: List<ChatMessageRecord>,
    ): String {
        val latest = messages.takeLast(max(1, RECENT_MESSAGE_COUNT / 2))
            .joinToString("\n") { "${it.role}: ${it.text}" }
        return listOfNotNull(previousSummary, latest.ifBlank { null })
            .joinToString("\n\n")
            .take(MAX_FALLBACK_SUMMARY_CHARS)
    }

    private fun ChatMessageRecord.toContextJson(): JSONObject =
        JSONObject().apply {
            put("id", id)
            put("role", role)
            put("content", text)
            put("createdAt", createdAt)
            put("sortOrder", sortOrder)
            if (modelName == null) {
                put("modelName", JSONObject.NULL)
            } else {
                put("modelName", modelName)
            }
        }

    companion object {
        const val EVENT_CONTEXT_SNAPSHOT = "context_snapshot"
        const val EVENT_COMPACT_SNAPSHOT = "compact_snapshot"
        private const val SNAPSHOT_VERSION = 1
        private const val AUTO_COMPACT_THRESHOLD_TOKENS = 6000
        private const val RECENT_MESSAGE_COUNT = 10
        private const val MAX_FALLBACK_SUMMARY_CHARS = 4000
        private const val WELCOME_MESSAGE_ID = "welcome"

        fun estimateTokens(text: String): Int =
            max(1, text.length / 4)
    }
}
