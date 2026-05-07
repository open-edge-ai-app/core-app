package com.onda.db

data class VectorRecord(
    val id: Long,
    val source: String,
    val text: String,
    val embedding: FloatArray,
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
}
