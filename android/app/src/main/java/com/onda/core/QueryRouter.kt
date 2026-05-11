package com.onda.core

class QueryRouter {
    private val gemmaManager = GemmaManager()

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "Message is empty."
        }

        val requiresRag = shouldUseRag(normalized)
        return gemmaManager.generate(normalized, requiresRag)
    }

    fun routeMultimodal(request: MultimodalRequest): AIResponse {
        val normalized = request.text.trim()
        if (normalized.isEmpty() && request.attachments.isEmpty()) {
            return AIResponse(
                type = "error",
                message = "Message and attachments are empty.",
                route = "invalid",
                modalities = emptyList(),
            )
        }

        val requiresRag = request.useRag ?: shouldUseRag(normalized)
        val modalities = request.attachments.map { attachment -> attachment.type }.distinct()
        return gemmaManager.generateMultimodal(request, requiresRag, modalities)
    }

    private fun shouldUseRag(message: String): Boolean {
        val ragHints = listOf(
            "memory",
            "photo",
            "image",
            "receipt",
            "schedule",
            "calendar",
            "when",
            "where",
            "find",
        )
        return ragHints.any { hint -> message.contains(hint, ignoreCase = true) }
    }
}
