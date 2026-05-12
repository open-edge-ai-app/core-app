package com.onda.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

class VectorDBHelper(
    context: Context,
) : SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS memory_vectors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source TEXT NOT NULL,
                source_id TEXT NOT NULL,
                text TEXT NOT NULL,
                embedding BLOB NOT NULL,
                dimension INTEGER NOT NULL,
                uri TEXT,
                timestamp INTEGER,
                metadata TEXT,
                created_at INTEGER NOT NULL,
                UNIQUE(source, source_id)
            )
            """.trimIndent(),
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_memory_vectors_source ON memory_vectors(source)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_memory_vectors_timestamp ON memory_vectors(timestamp)")
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS chats (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                chat_id TEXT NOT NULL,
                role TEXT NOT NULL,
                text TEXT NOT NULL,
                model_name TEXT,
                created_at INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS chat_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_chats_updated_at ON chats(updated_at)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_order ON chat_messages(chat_id, sort_order)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_chat_history_chat_created ON chat_history(chat_id, created_at)")
    }

    override fun onUpgrade(
        db: SQLiteDatabase,
        oldVersion: Int,
        newVersion: Int,
    ) {
        db.execSQL("DROP TABLE IF EXISTS memory_vectors")
        db.execSQL("DROP TABLE IF EXISTS chat_history")
        db.execSQL("DROP TABLE IF EXISTS chat_messages")
        db.execSQL("DROP TABLE IF EXISTS chats")
        onCreate(db)
    }

    fun insert(record: VectorRecord): Long {
        if (record.embedding.isEmpty()) {
            return -1L
        }

        val values = ContentValues().apply {
            put("source", record.source)
            put("source_id", record.sourceId)
            put("text", record.text)
            put("embedding", record.embedding.toBlob())
            put("dimension", record.embedding.size)
            put("uri", record.uri)
            put("timestamp", record.timestamp)
            put("metadata", record.metadata)
            put("created_at", System.currentTimeMillis())
        }

        return writableDatabase.insertWithOnConflict(
            "memory_vectors",
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun search(queryEmbedding: FloatArray, limit: Int): List<VectorRecord> {
        if (queryEmbedding.isEmpty() || limit <= 0) {
            return emptyList()
        }

        return readableDatabase.rawQuery(
            """
            SELECT id, source, source_id, text, embedding, uri, timestamp, metadata
            FROM memory_vectors
            """.trimIndent(),
            emptyArray(),
        ).use { cursor ->
            val records = mutableListOf<Pair<VectorRecord, Float>>()
            while (cursor.moveToNext()) {
                val embedding = cursor.getBlob(4).toFloatArray()
                val score = cosineSimilarity(queryEmbedding, embedding)
                records.add(
                    VectorRecord(
                        id = cursor.getLong(0),
                        source = cursor.getString(1),
                        sourceId = cursor.getString(2),
                        text = cursor.getString(3),
                        embedding = embedding,
                        uri = cursor.getStringOrNull(5),
                        timestamp = cursor.getLongOrNull(6),
                        metadata = cursor.getStringOrNull(7),
                    ) to score,
                )
            }

            records
                .sortedByDescending { (_, score) -> score }
                .take(limit)
                .map { (record, _) -> record }
        }
    }

    fun count(): Int =
        readableDatabase.rawQuery("SELECT COUNT(*) FROM memory_vectors", emptyArray()).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }

    fun countBySource(source: String): Int =
        readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM memory_vectors WHERE source = ?",
            arrayOf(source),
        ).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }

    fun deleteBySource(source: String): Int =
        writableDatabase.delete("memory_vectors", "source = ?", arrayOf(source))

    fun lastIndexedAt(): Long? =
        readableDatabase.rawQuery("SELECT MAX(created_at) FROM memory_vectors", emptyArray()).use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }

    fun upsertChatSession(
        chat: ChatRecord,
        messages: List<ChatMessageRecord>,
        historyEvent: ChatHistoryRecord?,
    ) {
        writableDatabase.beginTransaction()
        try {
            writableDatabase.insertWithOnConflict(
                "chats",
                null,
                ContentValues().apply {
                    put("id", chat.id)
                    put("title", chat.title)
                    put("created_at", chat.createdAt)
                    put("updated_at", chat.updatedAt)
                },
                SQLiteDatabase.CONFLICT_REPLACE,
            )
            writableDatabase.delete("chat_messages", "chat_id = ?", arrayOf(chat.id))
            messages.forEach { message ->
                writableDatabase.insertWithOnConflict(
                    "chat_messages",
                    null,
                    ContentValues().apply {
                        put("id", message.id)
                        put("chat_id", message.chatId)
                        put("role", message.role)
                        put("text", message.text)
                        put("model_name", message.modelName)
                        put("created_at", message.createdAt)
                        put("sort_order", message.sortOrder)
                    },
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            }
            if (historyEvent != null) {
                writableDatabase.insert(
                    "chat_history",
                    null,
                    ContentValues().apply {
                        put("chat_id", historyEvent.chatId)
                        put("event_type", historyEvent.eventType)
                        put("payload", historyEvent.payload)
                        put("created_at", historyEvent.createdAt)
                    },
                )
            }
            writableDatabase.setTransactionSuccessful()
        } finally {
            writableDatabase.endTransaction()
        }
    }

    fun getChatSession(chatId: String): ChatSessionRecord? {
        val chat = readableDatabase.rawQuery(
            "SELECT id, title, created_at, updated_at FROM chats WHERE id = ?",
            arrayOf(chatId),
        ).use { cursor ->
            if (!cursor.moveToFirst()) {
                return@use null
            }
            ChatRecord(
                id = cursor.getString(0),
                title = cursor.getString(1),
                createdAt = cursor.getLong(2),
                updatedAt = cursor.getLong(3),
            )
        } ?: return null

        return ChatSessionRecord(
            chat = chat,
            messages = listChatMessages(chatId),
            history = listChatHistory(chatId),
        )
    }

    fun listChats(limit: Int = DEFAULT_CHAT_LIMIT): List<ChatRecord> =
        readableDatabase.rawQuery(
            "SELECT id, title, created_at, updated_at FROM chats ORDER BY updated_at DESC LIMIT ?",
            arrayOf(limit.coerceAtLeast(1).toString()),
        ).use { cursor ->
            val chats = mutableListOf<ChatRecord>()
            while (cursor.moveToNext()) {
                chats.add(
                    ChatRecord(
                        id = cursor.getString(0),
                        title = cursor.getString(1),
                        createdAt = cursor.getLong(2),
                        updatedAt = cursor.getLong(3),
                    ),
                )
            }
            chats
        }

    fun deleteChat(chatId: String): Int {
        writableDatabase.beginTransaction()
        return try {
            writableDatabase.delete("chat_history", "chat_id = ?", arrayOf(chatId))
            writableDatabase.delete("chat_messages", "chat_id = ?", arrayOf(chatId))
            val deleted = writableDatabase.delete("chats", "id = ?", arrayOf(chatId))
            writableDatabase.setTransactionSuccessful()
            deleted
        } finally {
            writableDatabase.endTransaction()
        }
    }

    private fun listChatMessages(chatId: String): List<ChatMessageRecord> =
        readableDatabase.rawQuery(
            """
            SELECT id, chat_id, role, text, model_name, created_at, sort_order
            FROM chat_messages
            WHERE chat_id = ?
            ORDER BY sort_order ASC, created_at ASC
            """.trimIndent(),
            arrayOf(chatId),
        ).use { cursor ->
            val messages = mutableListOf<ChatMessageRecord>()
            while (cursor.moveToNext()) {
                messages.add(
                    ChatMessageRecord(
                        id = cursor.getString(0),
                        chatId = cursor.getString(1),
                        role = cursor.getString(2),
                        text = cursor.getString(3),
                        modelName = cursor.getStringOrNull(4),
                        createdAt = cursor.getLong(5),
                        sortOrder = cursor.getInt(6),
                    ),
                )
            }
            messages
        }

    private fun listChatHistory(chatId: String): List<ChatHistoryRecord> =
        readableDatabase.rawQuery(
            """
            SELECT id, chat_id, event_type, payload, created_at
            FROM chat_history
            WHERE chat_id = ?
            ORDER BY created_at ASC
            """.trimIndent(),
            arrayOf(chatId),
        ).use { cursor ->
            val history = mutableListOf<ChatHistoryRecord>()
            while (cursor.moveToNext()) {
                history.add(
                    ChatHistoryRecord(
                        id = cursor.getLong(0),
                        chatId = cursor.getString(1),
                        eventType = cursor.getString(2),
                        payload = cursor.getString(3),
                        createdAt = cursor.getLong(4),
                    ),
                )
            }
            history
        }

    private fun FloatArray.toBlob(): ByteArray {
        val buffer = ByteBuffer.allocate(size * FLOAT_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        forEach { value -> buffer.putFloat(value) }
        return buffer.array()
    }

    private fun ByteArray.toFloatArray(): FloatArray {
        if (isEmpty()) {
            return FloatArray(0)
        }

        val buffer = ByteBuffer.wrap(this).order(ByteOrder.LITTLE_ENDIAN)
        return FloatArray(size / FLOAT_BYTES) { buffer.getFloat() }
    }

    private fun cosineSimilarity(
        first: FloatArray,
        second: FloatArray,
    ): Float {
        val size = minOf(first.size, second.size)
        if (size == 0) {
            return 0f
        }

        var dot = 0f
        var firstNorm = 0f
        var secondNorm = 0f
        for (index in 0 until size) {
            dot += first[index] * second[index]
            firstNorm += first[index] * first[index]
            secondNorm += second[index] * second[index]
        }

        if (firstNorm == 0f || secondNorm == 0f) {
            return 0f
        }
        return dot / (sqrt(firstNorm) * sqrt(secondNorm))
    }

    private fun android.database.Cursor.getStringOrNull(index: Int): String? =
        if (isNull(index)) null else getString(index)

    private fun android.database.Cursor.getLongOrNull(index: Int): Long? =
        if (isNull(index)) null else getLong(index)

    companion object {
        private const val DB_NAME = "onda_memory.db"
        private const val DB_VERSION = 1
        private const val FLOAT_BYTES = 4
        private const val DEFAULT_CHAT_LIMIT = 50
    }
}
