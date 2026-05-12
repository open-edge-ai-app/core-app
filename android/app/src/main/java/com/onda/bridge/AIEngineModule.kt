package com.onda.bridge

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
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
import com.onda.core.IndexingResult
import com.onda.core.IndexingStatus
import com.onda.core.MemoryIndexer
import com.onda.core.ModelDownloader
import com.onda.core.ModelFileManager
import com.onda.core.ModelRuntimeManager
import com.onda.core.ModelStatus
import com.onda.core.MultimodalAttachment
import com.onda.core.MultimodalRequest
import com.onda.core.QueryRouter
import com.onda.core.RuntimeStatus
import com.onda.core.StartupState
import com.onda.db.ChatHistoryRecord
import com.onda.db.ChatMessageRecord
import com.onda.db.ChatRecord
import com.onda.db.ChatSessionRecord
import com.onda.db.VectorDBHelper
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class AIEngineModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext), LifecycleEventListener {

    private val modelFileManager = ModelFileManager(reactContext)
    private val vectorDBHelper = VectorDBHelper(reactContext)
    private val queryRouter = QueryRouter(reactContext, vectorDBHelper)
    private val memoryIndexer = MemoryIndexer(reactContext, vectorDBHelper)

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
        promise.resolve(memoryIndexer.getStatus().toWritableMap())
    }

    @ReactMethod
    fun startIndexing(promise: Promise) {
        memoryIndexer.startIndexing { result ->
            result
                .onSuccess { indexingResult -> promise.resolve(indexingResult.toWritableMap()) }
                .onFailure { error -> promise.reject("INDEXING_ERROR", error) }
        }
    }

    @ReactMethod
    fun setIndexingSourceEnabled(
        source: String,
        enabled: Boolean,
        promise: Promise,
    ) {
        memoryIndexer.setSourceEnabled(source, enabled) { result ->
            result
                .onSuccess { indexingResult -> promise.resolve(indexingResult.toWritableMap()) }
                .onFailure { error -> promise.reject("INDEXING_SOURCE_ERROR", error) }
        }
    }

    @ReactMethod
    fun startIndexingSource(
        source: String,
        promise: Promise,
    ) {
        memoryIndexer.startSourceIndexing(source) { result ->
            result
                .onSuccess { indexingResult -> promise.resolve(indexingResult.toWritableMap()) }
                .onFailure { error -> promise.reject("INDEXING_SOURCE_ERROR", error) }
        }
    }

    @ReactMethod
    fun deleteIndexingSource(
        source: String,
        promise: Promise,
    ) {
        memoryIndexer.deleteSourceEmbeddings(source) { result ->
            result
                .onSuccess { indexingResult -> promise.resolve(indexingResult.toWritableMap()) }
                .onFailure { error -> promise.reject("INDEXING_DELETE_ERROR", error) }
        }
    }

    @ReactMethod
    fun saveChatSession(
        sessionId: String,
        title: String,
        messages: ReadableArray,
        promise: Promise,
    ) {
        try {
            val now = System.currentTimeMillis()
            val existing = vectorDBHelper.getChatSession(sessionId)
            val chatMessages = messages.toChatMessageList(sessionId)
            vectorDBHelper.upsertChatSession(
                chat = ChatRecord(
                    id = sessionId,
                    title = title.ifBlank { "New chat" },
                    createdAt = existing?.chat?.createdAt ?: now,
                    updatedAt = now,
                ),
                messages = chatMessages,
                historyEvent = ChatHistoryRecord(
                    id = 0,
                    chatId = sessionId,
                    eventType = "messages_saved",
                    payload = "{\"messageCount\":${chatMessages.size}}",
                    createdAt = now,
                ),
            )
            promise.resolve(null)
        } catch (error: Exception) {
            promise.reject("CHAT_SAVE_ERROR", error)
        }
    }

    @ReactMethod
    fun loadChatSession(
        sessionId: String,
        promise: Promise,
    ) {
        try {
            val session = vectorDBHelper.getChatSession(sessionId)
            if (session == null) {
                promise.resolve(null)
            } else {
                promise.resolve(session.toWritableMap())
            }
        } catch (error: Exception) {
            promise.reject("CHAT_LOAD_ERROR", error)
        }
    }

    @ReactMethod
    fun listChatSessions(promise: Promise) {
        try {
            promise.resolve(vectorDBHelper.listChats().toWritableChatArray())
        } catch (error: Exception) {
            promise.reject("CHAT_LIST_ERROR", error)
        }
    }

    @ReactMethod
    fun deleteChatSession(
        sessionId: String,
        promise: Promise,
    ) {
        try {
            promise.resolve(vectorDBHelper.deleteChat(sessionId))
        } catch (error: Exception) {
            promise.reject("CHAT_DELETE_ERROR", error)
        }
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

    @ReactMethod
    fun copyTextToClipboard(text: String, promise: Promise) {
        try {
            val clipboard = reactContext
                .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText("Open Edge AI code", text))
            promise.resolve(true)
        } catch (error: Exception) {
            promise.reject("CLIPBOARD_COPY_ERROR", error)
        }
    }

    override fun onHostResume() = Unit

    override fun onHostPause() = Unit

    override fun onHostDestroy() {
        ModelRuntimeManager.unload()
        queryRouter.close()
        memoryIndexer.close()
    }

    override fun invalidate() {
        reactContext.removeLifecycleEventListener(this)
        ModelRuntimeManager.unload()
        queryRouter.close()
        memoryIndexer.close()
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

    private fun ReadableArray.toChatMessageList(chatId: String): List<ChatMessageRecord> {
        val messages = mutableListOf<ChatMessageRecord>()
        for (index in 0 until size()) {
            val map = getMap(index) ?: continue
            val id = map.getOptionalString("id") ?: "message_${System.nanoTime()}_$index"
            val role = map.getOptionalString("role") ?: "user"
            val text = map.getOptionalString("text").orEmpty()
            val createdAt = map.getOptionalDouble("createdAt")?.toLong() ?: System.currentTimeMillis()
            messages.add(
                ChatMessageRecord(
                    id = id,
                    chatId = chatId,
                    role = role,
                    text = text,
                    modelName = map.getOptionalString("modelName"),
                    createdAt = createdAt,
                    sortOrder = index,
                ),
            )
        }
        return messages
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

    private fun IndexingStatus.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putBoolean("isAvailable", isAvailable)
            putBoolean("isIndexing", isIndexing)
            putInt("indexedItems", indexedItems)
            putBoolean("smsEnabled", smsEnabled)
            putBoolean("galleryEnabled", galleryEnabled)
            putInt("smsIndexedItems", smsIndexedItems)
            putInt("galleryIndexedItems", galleryIndexedItems)
            if (lastIndexedAt == null) {
                putNull("lastIndexedAt")
            } else {
                putString("lastIndexedAt", lastIndexedAt.toIsoString())
            }
            if (lastError == null) {
                putNull("lastError")
            } else {
                putString("lastError", lastError)
            }
        }

    private fun IndexingResult.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putInt("smsIndexed", smsIndexed)
            putInt("galleryIndexed", galleryIndexed)
            putInt("deleted", deleted)
            putInt("skipped", skipped)
            putMap("status", status.toWritableMap())
        }

    private fun ChatSessionRecord.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putMap("chat", chat.toWritableMap())
            putArray("messages", messages.toWritableMessageArray())
            putArray("history", history.toWritableHistoryArray())
        }

    private fun ChatRecord.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putString("id", id)
            putString("title", title)
            putDouble("createdAt", createdAt.toDouble())
            putDouble("updatedAt", updatedAt.toDouble())
        }

    private fun List<ChatRecord>.toWritableChatArray(): WritableArray =
        Arguments.createArray().apply {
            forEach { chat -> pushMap(chat.toWritableMap()) }
        }

    private fun List<ChatMessageRecord>.toWritableMessageArray(): WritableArray =
        Arguments.createArray().apply {
            forEach { message ->
                pushMap(
                    Arguments.createMap().apply {
                        putString("id", message.id)
                        putString("role", message.role)
                        putString("text", message.text)
                        if (message.modelName == null) {
                            putNull("modelName")
                        } else {
                            putString("modelName", message.modelName)
                        }
                        putDouble("createdAt", message.createdAt.toDouble())
                    },
                )
            }
        }

    private fun List<ChatHistoryRecord>.toWritableHistoryArray(): WritableArray =
        Arguments.createArray().apply {
            forEach { event ->
                pushMap(
                    Arguments.createMap().apply {
                        putDouble("id", event.id.toDouble())
                        putString("chatId", event.chatId)
                        putString("eventType", event.eventType)
                        putString("payload", event.payload)
                        putDouble("createdAt", event.createdAt.toDouble())
                    },
                )
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
        private val ISO_FORMAT = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    private fun Long.toIsoString(): String = synchronized(ISO_FORMAT) {
        ISO_FORMAT.format(Date(this))
    }
}
