package com.onda.core

class GemmaManager {
    fun generate(message: String, useRag: Boolean): String {
        return ModelRuntimeManager.generateText(message, useRag).message
    }

    fun generateMultimodal(
        request: MultimodalRequest,
        useRag: Boolean,
        modalities: List<String>,
    ): AIResponse {
        return ModelRuntimeManager.generateMultimodal(request, useRag, modalities)
    }
}
