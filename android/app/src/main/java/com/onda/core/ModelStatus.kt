package com.onda.core

data class ModelStatus(
    val modelName: String,
    val installed: Boolean,
    val isDownloading: Boolean,
    val bytesDownloaded: Long,
    val totalBytes: Long,
    val localPath: String,
    val downloadUrl: String,
    val error: String?,
)
