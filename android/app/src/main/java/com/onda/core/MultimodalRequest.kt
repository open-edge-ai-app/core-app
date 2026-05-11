package com.onda.core

data class MultimodalRequest(
    val text: String,
    val attachments: List<MultimodalAttachment>,
    val useRag: Boolean?,
    val stream: Boolean,
)
