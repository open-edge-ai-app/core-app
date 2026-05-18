package com.openedgeai.db

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

data class VectorSearchResult(
    val record: VectorRecord,
    val score: Float,
)

data class DocumentCatalogRecord(
    val documentId: String,
    val uri: String,
    val name: String,
    val mimeType: String?,
    val size: Long,
    val modifiedAt: Long,
    val relativePath: String?,
    val accessMode: String,
    val fingerprint: String,
    val preview: String,
    val indexedAt: Long,
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

    fun searchWithScores(queryEmbedding: FloatArray, limit: Int): List<VectorSearchResult> {
        return dbHelper.searchWithScores(queryEmbedding, limit)
    }

    fun deleteBySource(source: String): Int {
        return dbHelper.deleteBySource(source)
    }

    fun upsertDocument(record: DocumentCatalogRecord): Long {
        return dbHelper.upsertDocument(record)
    }

    fun getDocument(documentId: String): DocumentCatalogRecord? {
        return dbHelper.getDocument(documentId)
    }

    fun getDocumentFingerprint(documentId: String): String? {
        return dbHelper.getDocumentFingerprint(documentId)
    }

    fun getCachedDocumentExcerpt(
        documentId: String,
        fingerprint: String,
        querySignature: String,
    ): String? {
        return dbHelper.getCachedDocumentExcerpt(documentId, fingerprint, querySignature)
    }

    fun upsertDocumentExcerptCache(
        documentId: String,
        fingerprint: String,
        querySignature: String,
        excerpt: String,
    ): Long {
        return dbHelper.upsertDocumentExcerptCache(documentId, fingerprint, querySignature, excerpt)
    }

    fun pruneDocumentExcerptCache(olderThanMillis: Long): Int {
        return dbHelper.pruneDocumentExcerptCache(olderThanMillis)
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
