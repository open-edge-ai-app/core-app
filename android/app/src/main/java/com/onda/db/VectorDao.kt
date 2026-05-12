package com.onda.db

data class VectorRecord(
    val id: Long,
    val source: String,
    val sourceId: String,
    val text: String,
    val embedding: FloatArray,
    val uri: String? = null,
    val timestamp: Long? = null,
    val metadata: String? = null,
)

data class ChatRecord(
    val id: String,
    val title: String,
    val createdAt: Long,
    val updatedAt: Long,
)

data class ChatMessageRecord(
    val id: String,
    val chatId: String,
    val role: String,
    val text: String,
    val modelName: String?,
    val createdAt: Long,
    val sortOrder: Int,
)

data class ChatHistoryRecord(
    val id: Long,
    val chatId: String,
    val eventType: String,
    val payload: String,
    val createdAt: Long,
)

data class ChatSessionRecord(
    val chat: ChatRecord,
    val messages: List<ChatMessageRecord>,
    val history: List<ChatHistoryRecord>,
)

class VectorDao(
    private val dbHelper: VectorDBHelper,
) {
    fun insert(record: VectorRecord): Long {
        return dbHelper.insert(record)
    }

    fun search(queryEmbedding: FloatArray, limit: Int): List<VectorRecord> {
        return dbHelper.search(queryEmbedding, limit)
    }

    fun deleteBySource(source: String): Int {
        return dbHelper.deleteBySource(source)
    }

    fun upsertChatSession(
        chat: ChatRecord,
        messages: List<ChatMessageRecord>,
        historyEvent: ChatHistoryRecord?,
    ) {
        dbHelper.upsertChatSession(chat, messages, historyEvent)
    }

    fun getChatSession(chatId: String): ChatSessionRecord? {
        return dbHelper.getChatSession(chatId)
    }

    fun listChats(limit: Int): List<ChatRecord> {
        return dbHelper.listChats(limit)
    }

    fun deleteChat(chatId: String): Int {
        return dbHelper.deleteChat(chatId)
    }
}
