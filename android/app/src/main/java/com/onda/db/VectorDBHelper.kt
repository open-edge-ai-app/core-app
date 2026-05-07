package com.onda.db

class VectorDBHelper {
    private val records = mutableListOf<VectorRecord>()

    fun insert(record: VectorRecord): Long {
        records.add(record)
        return record.id
    }

    fun search(queryEmbedding: FloatArray, limit: Int): List<VectorRecord> {
        if (queryEmbedding.isEmpty()) {
            return emptyList()
        }
        return records.take(limit.coerceAtLeast(0))
    }
}
