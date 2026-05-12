package com.onda.bridge

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ActivityEventListener
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
import com.onda.core.ChatCompactionResult
import com.onda.core.ChatContextManager
import com.onda.core.ConversationMessage
import com.onda.core.GemmaManager
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
) : ReactContextBaseJavaModule(reactContext), LifecycleEventListener, ActivityEventListener {

    private val modelFileManager = ModelFileManager(reactContext)
    private val vectorDBHelper = VectorDBHelper(reactContext)
    private val queryRouter = QueryRouter(reactContext, vectorDBHelper)
    private val memoryIndexer = MemoryIndexer(reactContext, vectorDBHelper)
    private val chatContextManager = ChatContextManager(vectorDBHelper, GemmaManager())
    private var filePickerPromise: Promise? = null

    init {
        reactContext.addLifecycleEventListener(this)
        reactContext.addActivityEventListener(this)
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
                historyEvent = null,
            )
            chatContextManager.recordContextSnapshot(
                chatId = sessionId,
                messages = chatMessages,
            )
            promise.resolve(null)
        } catch (error: Exception) {
            promise.reject("CHAT_SAVE_ERROR", error)
        }
    }

    @ReactMethod
    fun compactChatSession(
        sessionId: String,
        trigger: String,
        promise: Promise,
    ) {
        try {
            promise.resolve(
                chatContextManager.compactIfNeeded(
                    chatId = sessionId,
                    trigger = trigger.ifBlank { "manual" },
                    force = trigger == "manual",
                ).toWritableMap(),
            )
        } catch (error: Exception) {
            promise.reject("CHAT_COMPACT_ERROR", error)
        }
    }

    @ReactMethod
    fun generateChatTitle(
        userMessage: String,
        assistantMessage: String,
        promise: Promise,
    ) {
        try {
            val prompt = """
            Create a short chat title from this first exchange.
            Rules:
            - Match the user's language.
            - Use 3 to 8 words when possible.
            - Do not use quotes.
            - Do not add trailing punctuation.
            - Return only the title.

            User:
            $userMessage

            Assistant:
            $assistantMessage
            """.trimIndent()
            val title = GemmaManager()
                .generate(prompt, useRag = false)
                .toChatTitle()
                .ifBlank { userMessage.toChatTitle() }
            promise.resolve(title)
        } catch (error: Exception) {
            promise.reject("CHAT_TITLE_ERROR", error)
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

    @ReactMethod
    fun pickAttachment(promise: Promise) {
        val activity = reactContext.currentActivity
        if (activity == null) {
            promise.reject("FILE_PICKER_NO_ACTIVITY", "현재 파일 선택 화면을 열 수 없습니다.")
            return
        }

        if (filePickerPromise != null) {
            promise.reject("FILE_PICKER_BUSY", "이미 파일 선택이 진행 중입니다.")
            return
        }

        filePickerPromise = promise

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "image/*",
                    "audio/*",
                    "video/*",
                    "application/pdf",
                    "text/*",
                    "application/json",
                ),
            )
        }

        try {
            activity.startActivityForResult(intent, FILE_PICKER_REQUEST_CODE)
        } catch (error: Exception) {
            filePickerPromise = null
            promise.reject("FILE_PICKER_OPEN_ERROR", error)
        }
    }

    override fun onHostResume() = Unit

    override fun onHostPause() = Unit

    override fun onHostDestroy() {
        filePickerPromise?.resolve(null)
        filePickerPromise = null
        ModelRuntimeManager.unload()
        queryRouter.close()
        memoryIndexer.close()
    }

    override fun invalidate() {
        filePickerPromise?.resolve(null)
        filePickerPromise = null
        reactContext.removeLifecycleEventListener(this)
        reactContext.removeActivityEventListener(this)
        ModelRuntimeManager.unload()
        queryRouter.close()
        memoryIndexer.close()
        super.invalidate()
    }

    override fun onActivityResult(
        activity: Activity,
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        if (requestCode != FILE_PICKER_REQUEST_CODE) {
            return
        }

        val promise = filePickerPromise ?: return
        filePickerPromise = null

        if (resultCode != Activity.RESULT_OK) {
            promise.resolve(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            promise.resolve(null)
            return
        }

        try {
            val flags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (flags != 0) {
                reactContext.contentResolver.takePersistableUriPermission(uri, flags)
            }
        } catch (_: Exception) {
            // Some document providers grant only transient access.
        }

        try {
            promise.resolve(uri.toAttachmentWritableMap())
        } catch (error: Exception) {
            promise.reject("FILE_PICKER_RESULT_ERROR", error)
        }
    }

    override fun onNewIntent(intent: Intent) = Unit

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
            history = if (hasKey("history") && !isNull("history")) {
                getArray("history").toConversationMessageList()
            } else {
                emptyList()
            },
            useRag = options?.getOptionalBoolean("useRag"),
            stream = options?.getOptionalBoolean("stream") ?: false,
            chatSessionId = options?.getOptionalString("chatSessionId"),
        )
    }

    private fun ReadableArray?.toConversationMessageList(): List<ConversationMessage> {
        if (this == null) {
            return emptyList()
        }

        val messages = mutableListOf<ConversationMessage>()
        for (index in 0 until size()) {
            val map = getMap(index) ?: continue
            val content = map.getOptionalString("content")?.trim().orEmpty()
            if (content.isBlank()) {
                continue
            }
            messages.add(
                ConversationMessage(
                    role = map.getOptionalString("role") ?: "user",
                    content = content,
                ),
            )
        }
        return messages
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

    private fun Uri.toAttachmentWritableMap(): WritableMap {
        val resolver = reactContext.contentResolver
        val mimeType = resolver.getType(this)
        var displayName: String? = null
        var sizeBytes: Long? = null

        resolver.query(this, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)

            if (cursor.moveToFirst()) {
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                    displayName = cursor.getString(nameIndex)
                }
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                    sizeBytes = cursor.getLong(sizeIndex)
                }
            }
        }

        return Arguments.createMap().apply {
            putString("id", "attachment-${System.nanoTime()}")
            putString("type", inferAttachmentType(mimeType, displayName))
            putString("uri", toString())
            if (mimeType == null) {
                putNull("mimeType")
            } else {
                putString("mimeType", mimeType)
            }
            if (displayName == null) {
                putNull("name")
            } else {
                putString("name", displayName)
            }
            if (sizeBytes == null) {
                putNull("sizeBytes")
            } else {
                putDouble("sizeBytes", sizeBytes!!.toDouble())
            }
        }
    }

    private fun inferAttachmentType(mimeType: String?, name: String?): String {
        if (mimeType?.startsWith("image/") == true) {
            return "image"
        }
        if (mimeType?.startsWith("audio/") == true) {
            return "audio"
        }
        if (mimeType?.startsWith("video/") == true) {
            return "video"
        }

        val normalizedName = name.orEmpty().lowercase()
        return when {
            Regex("\\.(png|jpe?g|webp|gif|heic)$").containsMatchIn(normalizedName) -> "image"
            Regex("\\.(mp3|wav|m4a|aac|ogg|flac)$").containsMatchIn(normalizedName) -> "audio"
            Regex("\\.(mp4|mov|m4v|webm|mkv)$").containsMatchIn(normalizedName) -> "video"
            else -> "file"
        }
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

    private fun ChatCompactionResult.toWritableMap(): WritableMap =
        Arguments.createMap().apply {
            putString("chatId", chatId)
            putBoolean("compacted", compacted)
            putString("trigger", trigger)
            putString("message", message)
            putInt("beforeTokenEstimate", beforeTokenEstimate)
            putInt("afterTokenEstimate", afterTokenEstimate)
            if (compactedUntilMessageId == null) {
                putNull("compactedUntilMessageId")
            } else {
                putString("compactedUntilMessageId", compactedUntilMessageId)
            }
            putDouble("snapshotId", snapshotId.toDouble())
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

    private fun Long.toIsoString(): String = synchronized(ISO_FORMAT) {
        ISO_FORMAT.format(Date(this))
    }

    private fun String.toChatTitle(): String =
        trim()
            .lineSequence()
            .firstOrNull { it.isNotBlank() }
            .orEmpty()
            .trim()
            .removeSurrounding("\"")
            .removeSurrounding("'")
            .replace(Regex("[\\r\\n]+"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
            .trimEnd('.', '!', '?', '。', '！', '？')
            .take(MAX_CHAT_TITLE_LENGTH)

    companion object {
        const val NAME = "AIEngine"
        private const val FILE_PICKER_REQUEST_CODE = 41042
        private const val STREAM_EVENT_NAME = "AIEngineStreamChunk"
        private const val MAX_CHAT_TITLE_LENGTH = 40
        private val ISO_FORMAT = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }
}
