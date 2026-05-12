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

    fun generateMultimodalStream(
        request: MultimodalRequest,
        useRag: Boolean,
        modalities: List<String>,
        onPartial: (String, Boolean) -> Unit,
        onComplete: (AIResponse) -> Unit,
        onError: (Throwable) -> Unit,
    ): Boolean {
        return ModelRuntimeManager.generateMultimodalStream(
            request = request,
            useRag = useRag,
            modalities = modalities,
            onPartial = onPartial,
            onComplete = onComplete,
            onError = onError,
        )
    }
}
