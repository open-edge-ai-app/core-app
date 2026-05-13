package com.onda.core

import android.content.Context
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

object ModelRuntimeManager {
    private val lock = ReentrantLock()

    @Volatile
    private var engine: Any? = null

    @Volatile
    private var loading: Boolean = false

    @Volatile
    private var lastError: String? = null

    fun getStatus(modelFileManager: ModelFileManager): RuntimeStatus {
        val modelStatus = modelFileManager.getStatus()
        return RuntimeStatus(
            modelInstalled = modelStatus.installed,
            loaded = engine != null,
            loading = loading,
            canGenerate = modelStatus.installed && engine != null,
            localPath = modelStatus.localPath,
            error = lastError,
        )
    }

    fun load(
        context: Context,
        modelFileManager: ModelFileManager,
    ): RuntimeStatus = lock.withLock {
        val modelStatus = modelFileManager.getStatus()
        if (!modelStatus.installed) {
            lastError = "Model is not installed."
            closeEngineLocked()
            loading = false
            return getStatus(modelFileManager)
        }

        if (engine != null) {
            return getStatus(modelFileManager)
        }

        loading = true
        lastError = null
        try {
            engine = LiteRtLmReflector.createEngine(
                context = context,
                modelPath = modelStatus.localPath,
            )
        } catch (error: Exception) {
            closeEngineLocked()
            lastError = error.message ?: error.javaClass.simpleName
        } finally {
            loading = false
        }

        return getStatus(modelFileManager)
    }

    fun generateText(
        message: String,
        useRag: Boolean,
    ): AIResponse = lock.withLock {
        val currentEngine = engine
            ?: return AIResponse(
                type = "error",
                message = "Model runtime is not loaded.",
                route = "invalid",
                modalities = emptyList(),
            )

        val response = LiteRtLmReflector.sendText(currentEngine as LiteRtLmReflector.EngineHandle, message)
        AIResponse(
            type = "text",
            message = response.message,
            route = if (useRag) "rag" else "direct",
            modalities = emptyList(),
            reasoning = response.reasoning,
        )
    }

    fun generateMultimodal(
        request: MultimodalRequest,
        useRag: Boolean,
        modalities: List<String>,
    ): AIResponse = lock.withLock {
        val currentEngine = engine
            ?: return AIResponse(
                type = "error",
                message = "Model runtime is not loaded.",
                route = "invalid",
                modalities = modalities,
            )

        val response = LiteRtLmReflector.sendMultimodal(
            currentEngine as LiteRtLmReflector.EngineHandle,
            request,
        )
        AIResponse(
            type = "text",
            message = response.message,
            route = if (useRag) "rag" else "direct",
            modalities = modalities,
            reasoning = response.reasoning,
        )
    }

    fun generateMultimodalStream(
        request: MultimodalRequest,
        useRag: Boolean,
        modalities: List<String>,
        onPartial: (String, Boolean) -> Unit,
        onComplete: (AIResponse) -> Unit,
        onError: (Throwable) -> Unit,
    ): Boolean {
        val currentEngine = lock.withLock { engine }
            ?: run {
                onComplete(
                    AIResponse(
                        type = "error",
                        message = "Model runtime is not loaded.",
                        route = "invalid",
                        modalities = modalities,
                    ),
                )
                return false
            }

        return try {
            LiteRtLmReflector.sendMultimodalStream(
                handle = currentEngine as LiteRtLmReflector.EngineHandle,
                request = request,
                onPartial = onPartial,
                onComplete = { response ->
                    onComplete(
                        AIResponse(
                            type = "text",
                            message = response.message,
                            route = if (useRag) "rag" else "direct",
                            modalities = modalities,
                            reasoning = response.reasoning,
                        ),
                    )
                },
                onError = onError,
            )
            true
        } catch (error: Exception) {
            onError(error)
            false
        }
    }

    fun unload() = lock.withLock {
        closeEngineLocked()
        loading = false
        lastError = null
    }

    fun isReady(): Boolean = engine != null

    private fun closeEngineLocked() {
        try {
            (engine as? AutoCloseable)?.close()
        } finally {
            engine = null
        }
    }
}
