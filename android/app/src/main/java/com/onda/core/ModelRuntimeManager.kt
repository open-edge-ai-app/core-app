package com.onda.core

import android.app.ActivityManager
import android.content.Context
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

object ModelRuntimeManager {
    private val lock = ReentrantLock()
    private const val MIN_GENERATION_AVAILABLE_MEMORY_BYTES = 1_500_000_000L

    @Volatile
    private var engine: Any? = null

    @Volatile
    private var loading: Boolean = false

    @Volatile
    private var lastError: String? = null

    @Volatile
    private var appContext: Context? = null

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
        appContext = context.applicationContext
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
            engine = MediaPipeLlmReflector.createEngine(
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
        memoryPressureMessage()?.let { message ->
            closeEngineLocked()
            lastError = message
            return AIResponse(
                type = "error",
                message = message,
                route = "invalid",
                modalities = emptyList(),
            )
        }

        val response = MediaPipeLlmReflector.sendText(currentEngine, message)
        AIResponse(
            type = "text",
            message = response,
            route = if (useRag) "rag" else "direct",
            modalities = emptyList(),
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
        memoryPressureMessage()?.let { message ->
            closeEngineLocked()
            lastError = message
            return AIResponse(
                type = "error",
                message = message,
                route = "invalid",
                modalities = modalities,
            )
        }

        val response = MediaPipeLlmReflector.sendMultimodal(currentEngine, request)
        AIResponse(
            type = "text",
            message = response,
            route = if (useRag) "rag" else "direct",
            modalities = modalities,
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
        val blockedReason = lock.withLock {
            memoryPressureMessage()?.also { message ->
                closeEngineLocked()
                lastError = message
            }
        }
        if (blockedReason != null) {
            onComplete(
                AIResponse(
                    type = "error",
                    message = blockedReason,
                    route = "invalid",
                    modalities = modalities,
                ),
            )
            return false
        }

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
            MediaPipeLlmReflector.sendMultimodalStream(
                engine = currentEngine,
                request = request,
                onPartial = onPartial,
                onComplete = { response ->
                    onComplete(
                        AIResponse(
                            type = "text",
                            message = response,
                            route = if (useRag) "rag" else "direct",
                            modalities = modalities,
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

    private fun memoryPressureMessage(): String? {
        val context = appContext ?: return null
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return null
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        if (
            !memoryInfo.lowMemory &&
            memoryInfo.availMem >= MIN_GENERATION_AVAILABLE_MEMORY_BYTES
        ) {
            return null
        }

        val availableMb = memoryInfo.availMem / (1024 * 1024)
        val requiredMb = MIN_GENERATION_AVAILABLE_MEMORY_BYTES / (1024 * 1024)
        return "현재 기기 메모리가 부족해서 온디바이스 모델 응답을 시작하지 않았습니다. 사용 가능 메모리 ${availableMb}MB, 권장 최소 ${requiredMb}MB입니다. 다른 앱을 종료하거나 더 가벼운 모델을 사용해주세요."
    }
}
