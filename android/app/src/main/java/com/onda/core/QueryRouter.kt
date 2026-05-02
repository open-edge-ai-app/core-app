package com.onda.core

class QueryRouter {
    private val gemmaManager = GemmaManager()

    fun route(message: String): String {
        val normalized = message.trim()
        if (normalized.isEmpty()) {
            return "메시지가 비어 있습니다."
        }

        val requiresRag = shouldUseRag(normalized)
        return gemmaManager.generate(normalized, requiresRag)
    }

    private fun shouldUseRag(message: String): Boolean {
        val ragHints = listOf("기억", "사진", "일정", "언제", "어디")
        return ragHints.any { hint -> message.contains(hint, ignoreCase = true) }
    }
}
