package com.openedgeai.core

data class ModelStatus(
    val modelId: String,
    val modelName: String,
    val installed: Boolean,
    val isDownloading: Boolean,
    val bytesDownloaded: Long,
    val totalBytes: Long,
    val localPath: String,
    val downloadUrl: String,
    val error: String?,
    val provider: String,
    val runnable: Boolean,
    val started: Boolean = false,
    val systemManaged: Boolean = false,
)
