package com.onda.core

class GemmaManager {
    fun generate(message: String, useRag: Boolean): String {
        val mode = if (useRag) "RAG route" else "direct route"
        return "Kotlin AIEngine connected ($mode). Received: $message"
    }
}
