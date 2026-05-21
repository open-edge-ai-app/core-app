package com.openedgeai.core

data class ConversationMessage(
    val role: String,
    val content: String,
)

data class MultimodalRequest(
    val text: String,
    val attachments: List<MultimodalAttachment>,
    val history: List<ConversationMessage>,
    val modelId: String?,
    val useRag: Boolean?,
    val stream: Boolean,
    val chatSessionId: String?,
    val forceWebSearch: Boolean = false,
    val disableRetrieval: Boolean = false,
    val nativeTools: OpenEdgeAiToolSet? = null,
)
