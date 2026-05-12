package com.onda.bridge

import android.net.Uri
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.onda.core.AIResponse
import com.onda.core.ModelDownloader
import com.onda.core.ModelFileManager
import com.onda.core.ModelRuntimeManager
import com.onda.core.ModelStatus
import com.onda.core.MultimodalAttachment
import com.onda.core.MultimodalRequest
import com.onda.core.QueryRouter
import com.onda.core.RuntimeStatus
import com.onda.core.StartupState
import java.io.File
import java.io.FileOutputStream

class AIEngineModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext), LifecycleEventListener {

    private val queryRouter = QueryRouter()
    private val modelFileManager = ModelFileManager(reactContext)

    init {
        reactContext.addLifecycleEventListener(this)
    }

    override fun getName(): String = NAME

    @ReactMethod
    fun sendMessage(message: String, promise: Promise) {
        try {
            promise.resolve(queryRouter.route(message))
        } catch (error: Exception) {
            promise.reject("AI_ENGINE_ERROR", error)
        }
    }

    @ReactMethod
    fun sendMultimodalMessage(request: ReadableMap, promise: Promise) {
        try {
            val multimodalRequest = request.toMultimodalRequest()
            promise.resolve(queryRouter.routeMultimodal(multimodalRequest).toWritableMap())
        } catch (error: Exception) {
            promise.reject("AI_ENGINE_MULTIMODAL_ERROR", error)
        }
    }

    @ReactMethod
    fun sendMultimodalMessageStream(requestId: String, request: ReadableMap, promise: Promise) {
        try {
            val multimodalRequest = request.toMultimodalRequest()
            queryRouter.routeMultimodalStream(
                request = multimodalRequest,
                onPartial = { partial, done ->
                    emitStreamEvent(
                        requestId = requestId,
                        chunk = partial,
                        done = false,
                    )
                },
                onComplete = { response ->
                    emitStreamEvent(
                        requestId = requestId,
                        done = true,
                        message = response.message,
                    )
                },
                onError = { error ->
                    emitStreamEvent(
                        requestId = requestId,
                        done = true,
                        error = error.message ?: error.javaClass.simpleName,
                    )
                },
            )
            promise.resolve(
                Arguments.createMap().apply {
                    putBoolean("started", true)
                },
            )
        } catch (error: Exception) {
            promise.reject("AI_ENGINE_STREAM_ERROR", error)
        }
    }

    @ReactMethod
    fun getIndexingStatus(promise: Promise) {
        val status = Arguments.createMap().apply {
            putInt("indexedItems", 0)
            putBoolean("isIndexing", false)
        }
        promise.resolve(status)
    }

    @ReactMethod
    fun getModelStatus(promise: Promise) {
        promise.resolve(modelFileManager.getStatus().toWritableMap())
    }

    @ReactMethod
    fun getStartupState(promise: Promise) {
        promise.resolve(modelFileManager.getStartupState().toWritableMap())
    }

    @ReactMethod
    fun getRuntimeStatus(promise: Promise) {
        promise.resolve(ModelRuntimeManager.getStatus(modelFileManager).toWritableMap())
    }

    @ReactMethod
    fun loadModel(promise: Promise) {
        try {
            promise.resolve(
                ModelRuntimeManager.load(
                    reactContext.applicationContext,
                    modelFileManager,
                ).toWritableMap(),
            )
        } catch (error: Exception) {
            promise.reject("MODEL_LOAD_ERROR", error)
        }
    }

    @ReactMethod
    fun unloadModel(promise: Promise) {
        ModelRuntimeManager.unload()
        promise.resolve(ModelRuntimeManager.getStatus(modelFileManager).toWritableMap())
    }

    @ReactMethod
    fun downloadModel(promise: Promise) {
        try {
            val started = ModelDownloader.start(modelFileManager)
            val status = modelFileManager.getStatus().toWritableMap().apply {
                putBoolean("started", started)
            }
            promise.resolve(status)
        } catch (error: Exception) {
            promise.reject("MODEL_DOWNLOAD_ERROR", error)
        }
    }

    @ReactMethod
    fun ensureModelDownloaded(promise: Promise) {
        try {
            val currentStatus = modelFileManager.getStatus()
            val started = if (currentStatus.installed || currentStatus.isDownloading) {
                false
            } else {
                ModelDownloader.start(modelFileManager)
            }
            val status = modelFileManager.getStatus().toWritableMap().apply {
                putBoolean("started", started)
            }
            promise.resolve(status)
        } catch (error: Exception) {
            promise.reject("MODEL_ENSURE_ERROR", error)
        }
    }

    @ReactMethod
    fun cancelModelDownload(promise: Promise) {
        ModelDownloader.cancel()
        promise.resolve(modelFileManager.getStatus().toWritableMap())
    }

    override fun onHostResume() = Unit

    override fun onHostPause() = Unit

    override fun onHostDestroy() {
        ModelRuntimeManager.unload()
    }

    override fun invalidate() {
        reactContext.removeLifecycleEventListener(this)
        ModelRuntimeManager.unload()
        super.invalidate()
    }

    @ReactMethod
    fun addListener(eventName: String) = Unit

    @ReactMethod
    fun removeListeners(count: Int) = Unit

    private fun emitStreamEvent(
        requestId: String,
        chunk: String? = null,
        done: Boolean = false,
        message: String? = null,
        error: String? = null,
    ) {
        reactContext.runOnJSQueueThread {
            val event = Arguments.createMap().apply {
                putString("requestId", requestId)
                putBoolean("done", done)
                if (chunk != null) {
                    putString("chunk", chunk)
                }
                if (message != null) {
                    putString("message", message)
                }
                if (error != null) {
                    putString("error", error)
                }
            }

            reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit(STREAM_EVENT_NAME, event)
        }
    }

    private fun ReadableMap.toMultimodalRequest(): MultimodalRequest {
        val options = if (hasKey("options") && !isNull("options")) getMap("options") else null
        return MultimodalRequest(
            text = getOptionalString("text").orEmpty(),
            attachments = if (hasKey("attachments") && !isNull("attachments")) {
                getArray("attachments").toAttachmentList()
            } else {
                emptyList()
            },
            useRag = options?.getOptionalBoolean("useRag"),
            stream = options?.getOptionalBoolean("stream") ?: false,
        )
    }

    private fun ReadableArray?.toAttachmentList(): List<MultimodalAttachment> {
        if (this == null) {
            return emptyList()
        }

        val attachments = mutableListOf<MultimodalAttachment>()
        for (index in 0 until size()) {
            val map = getMap(index) ?: continue
            val uri = map.getOptionalString("uri") ?: continue
            val type = map.getOptionalString("type") ?: "file"
            attachments.add(
                MultimodalAttachment(
                    id = map.getOptionalString("id"),
                    type = type,
                    uri = resolveAttachmentPath(uri, type, map.getOptionalString("name")),
                    mimeType = map.getOptionalString("mimeType"),
                    name = map.getOptionalString("name"),
                    sizeBytes = map.getOptionalDouble("sizeBytes")?.toLong(),
                    width = map.getOptionalDouble("width")?.toInt(),
                    height = map.getOptionalDouble("height")?.toInt(),
                ),
            )
        }
        return attachments
    }

    private fun resolveAttachmentPath(
        uriValue: String,
        type: String,
        name: String?,
    ): String {
        val uri = Uri.parse(uriValue)
        return when (uri.scheme) {
            "content" -> copyContentUriToCache(uri, type, name)
            "file" -> requireNotNull(uri.path) { "Invalid file uri: $uriValue" }
            else -> uriValue
        }
    }

    private fun copyContentUriToCache(
        uri: Uri,
        type: String,
        name: String?,
    ): String {
        val directory = File(reactContext.cacheDir, "onda_attachments").apply {
            mkdirs()
        }
        val extension = when (type) {
            "image" -> ".jpg"
            "audio" -> ".wav"
            else -> ".bin"
        }
        val safeName = name
            ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
            ?.takeIf { it.isNotBlank() }
            ?: "attachment_${System.nanoTime()}$extension"
        val outputFile = File(directory, safeName)

        reactContext.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open attachment: $uri" }
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        }
        return outputFile.absolutePath
    }

    private fun AIResponse.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putString("type", type)
            putString("message", message)
            putString("route", route)
            putArray("modalities", modalities.toWritableArray())
        }

    private fun ModelStatus.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putString("modelName", modelName)
            putBoolean("installed", installed)
            putBoolean("isDownloading", isDownloading)
            putDouble("bytesDownloaded", bytesDownloaded.toDouble())
            putDouble("totalBytes", totalBytes.toDouble())
            putString("localPath", localPath)
            putString("downloadUrl", downloadUrl)
            if (error == null) {
                putNull("error")
            } else {
                putString("error", error)
            }
        }

    private fun StartupState.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putBoolean("ready", ready)
            putString("nextAction", nextAction)
            putString("message", message)
            putMap("modelStatus", modelStatus.toWritableMap())
        }

    private fun RuntimeStatus.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putBoolean("modelInstalled", modelInstalled)
            putBoolean("loaded", loaded)
            putBoolean("loading", loading)
            putBoolean("canGenerate", canGenerate)
            putString("localPath", localPath)
            if (error == null) {
                putNull("error")
            } else {
                putString("error", error)
            }
        }

    private fun List<String>.toWritableArray(): WritableArray =
        Arguments.createArray().apply {
            forEach { value -> pushString(value) }
        }

    private fun ReadableMap.getOptionalString(key: String): String? =
        if (hasKey(key) && !isNull(key)) getString(key) else null

    private fun ReadableMap.getOptionalBoolean(key: String): Boolean? =
        if (hasKey(key) && !isNull(key)) getBoolean(key) else null

    private fun ReadableMap.getOptionalDouble(key: String): Double? =
        if (hasKey(key) && !isNull(key)) getDouble(key) else null

    companion object {
        const val NAME = "AIEngine"
        private const val STREAM_EVENT_NAME = "AIEngineStreamChunk"
    }
}
