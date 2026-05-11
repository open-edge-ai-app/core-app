package com.onda.core

data class MultimodalAttachment(
    val id: String?,
    val type: String,
    val uri: String,
    val mimeType: String?,
    val name: String?,
    val sizeBytes: Long?,
    val width: Int?,
    val height: Int?,
)
