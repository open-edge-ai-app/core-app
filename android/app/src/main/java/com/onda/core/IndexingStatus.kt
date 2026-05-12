package com.onda.core

data class IndexingStatus(
    val isAvailable: Boolean,
    val isIndexing: Boolean,
    val indexedItems: Int,
    val lastIndexedAt: Long?,
    val lastError: String?,
    val smsEnabled: Boolean,
    val galleryEnabled: Boolean,
    val smsIndexedItems: Int,
    val galleryIndexedItems: Int,
)

data class IndexingResult(
    val smsIndexed: Int,
    val galleryIndexed: Int,
    val deleted: Int,
    val skipped: Int,
    val status: IndexingStatus,
)
