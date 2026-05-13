package com.openedgeai.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import java.io.File
import java.lang.reflect.Proxy
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

object MediaPipeLlmReflector {
    private const val TAG = "OpenEdgeAILlm"
    private const val PACKAGE_NAME = "com.google.mediapipe.tasks.genai.llminference"
    private const val IMAGE_BUILDER_CLASS = "com.google.mediapipe.framework.image.BitmapImageBuilder"
    private const val MP_IMAGE_CLASS = "com.google.mediapipe.framework.image.MPImage"
    private const val MAX_TOKENS = 512
    private const val MAX_IMAGES = 10
    private const val TEMPERATURE = 0.7f
    private const val TOP_K = 64
    private const val TOP_P = 0.95f
    private val MODEL_TOKENS = listOf(
        "<turn|>",
        "<eos>",
        "<bos>",
        "<start_of_turn>system",
        "<start_of_turn>user",
        "<start_of_turn>model",
        "<start_of_turn>",
        "<end_of_turn>",
        "<|channel>final",
        "<|channel|>final",
        "<channel|>",
        "<channel>",
    )
    private val PRIVATE_REASONING_MARKERS = listOf(
        "<|channel>thought",
        "<|channel|>thought",
        "<channel>thought",
        "Thinking Process",
        "Thinking Process:",
        "Response Plan",
        "Analyze the Request",
        "Analyze the Context",
        "The user is asking",
        "Based on the context",
    )
    private val FINAL_CHANNEL_MARKERS = listOf(
        "<channel>",
        "<|channel>final",
        "<|channel|>final",
    )
    private val OPENCL_LIBRARY_PATHS = listOf(
        "/system/lib64/libOpenCL.so",
        "/system/vendor/lib64/libOpenCL.so",
        "/vendor/lib64/libOpenCL.so",
        "/system/lib/libOpenCL.so",
        "/system/vendor/lib/libOpenCL.so",
        "/vendor/lib/libOpenCL.so",
    )

    data class ParsedOutput(
        val message: String,
        val reasoning: String? = null,
        val hasFinalChannel: Boolean = false,
    )

    private data class ThoughtBlock(
        val reasoning: String,
        val answer: String,
    )

    fun createEngine(
        context: Context,
        modelPath: String,
    ): Any {
        val llmInferenceClass = Class.forName("$PACKAGE_NAME.LlmInference")
        val optionsClass = Class.forName("$PACKAGE_NAME.LlmInference\$LlmInferenceOptions")
        val preferredBackend = if (canUseGpuBackend()) "GPU" else "CPU"
        val options = buildInferenceOptions(optionsClass, modelPath, preferredBackend)
            ?: buildInferenceOptions(optionsClass, modelPath, "CPU")
            ?: error("Unable to create MediaPipe LLM options.")

        return try {
            llmInferenceClass
                .getMethod("createFromOptions", Context::class.java, optionsClass)
                .invoke(null, context.applicationContext, options)
                ?: error("MediaPipe LLM returned a null $preferredBackend engine.")
        } catch (error: Exception) {
            if (preferredBackend == "CPU") {
                throw error
            }
            val cpuOptions = buildInferenceOptions(optionsClass, modelPath, "CPU")
                ?: throw error
            llmInferenceClass
                .getMethod("createFromOptions", Context::class.java, optionsClass)
                .invoke(null, context.applicationContext, cpuOptions)
                ?: error("MediaPipe LLM returned a null CPU engine.")
        }
    }

    fun sendText(
        engine: Any,
        text: String,
    ): ParsedOutput = createSession(engine, enableVision = false, enableAudio = false).use { session ->
        session.addQueryChunk(text.toGemmaItPrompt())
        parseModelOutput(session.generateResponse())
    }

    fun sendMultimodal(
        engine: Any,
        request: MultimodalRequest,
    ): ParsedOutput {
        val hasImages = request.attachments.any { it.type == "image" }
        val hasAudio = request.attachments.any { it.type == "audio" }

        return createSession(engine, enableVision = hasImages, enableAudio = hasAudio).use { session ->
            val prompt = request.toPromptTextWithAttachmentNotes()
            if (prompt.isNotEmpty()) {
                session.addQueryChunk(prompt.toGemmaItPrompt())
            }

            request.attachments.forEach { attachment ->
                when (attachment.type) {
                    "image" -> session.addImage(attachment.uri)
                    "audio" -> session.addAudio(attachment.uri)
                }
            }

            parseModelOutput(session.generateResponse())
        }
    }

    fun sendMultimodalStream(
        engine: Any,
        request: MultimodalRequest,
        onPartial: (String, Boolean) -> Unit,
        onComplete: (ParsedOutput) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val hasImages = request.attachments.any { it.type == "image" }
        val hasAudio = request.attachments.any { it.type == "audio" }
        var rawResponse = ""
        var emittedLength = 0
        val completed = AtomicBoolean(false)

        val session = createSession(engine, enableVision = hasImages, enableAudio = hasAudio)
        try {
            val prompt = request.toPromptTextWithAttachmentNotes()
            if (prompt.isNotEmpty()) {
                session.addQueryChunk(prompt.toGemmaItPrompt())
            }

            request.attachments.forEach { attachment ->
                when (attachment.type) {
                    "image" -> session.addImage(attachment.uri)
                    "audio" -> session.addAudio(attachment.uri)
                }
            }

            session.generateResponseStream(
                onPartial = { partial, done ->
                    rawResponse = mergeStreamPartial(rawResponse, partial)
                    val parsed = parseModelOutput(rawResponse)
                    val cleaned = if (parsed.hasFinalChannel || !shouldBufferPotentialReasoning(rawResponse)) {
                        parsed.message
                    } else {
                        ""
                    }

                    if (
                        rawResponse.hasPrivateReasoningMarker() &&
                        cleaned.isNotBlank() &&
                        completed.compareAndSet(false, true)
                    ) {
                        Log.d(TAG, "stream stopped before private reasoning chars=${cleaned.length}")
                        session.close()
                        onComplete(ParsedOutput(message = cleaned))
                        return@generateResponseStream
                    }

                    val safeLength = cleaned.length - cleaned.trailingBlockedPrefixLength()
                    if (safeLength > emittedLength) {
                        val delta = cleaned.substring(emittedLength, safeLength)
                        emittedLength = safeLength
                        Log.d(TAG, "stream chunk chars=${delta.length} done=$done")
                        onPartial(delta, done)
                    }

                    if (done && completed.compareAndSet(false, true)) {
                        val finalOutput = parseModelOutput(rawResponse)
                        val finalResponse = finalOutput.message
                        if (finalResponse.length > emittedLength) {
                            onPartial(finalResponse.substring(emittedLength), true)
                        }
                        Log.d(TAG, "stream complete chars=${finalResponse.length}")
                        session.close()
                        onComplete(finalOutput)
                    }
                },
                onFinished = {
                    if (completed.compareAndSet(false, true)) {
                        val finalOutput = parseModelOutput(rawResponse)
                        val finalResponse = finalOutput.message
                        if (finalResponse.length > emittedLength) {
                            onPartial(finalResponse.substring(emittedLength), true)
                        }
                        Log.d(TAG, "stream finished chars=${finalResponse.length}")
                        session.close()
                        onComplete(finalOutput)
                    }
                },
                onError = { error ->
                    if (completed.compareAndSet(false, true)) {
                        Log.e(TAG, "stream error", error)
                        session.close()
                        onError(error)
                    }
                },
            )
        } catch (error: Exception) {
            if (completed.compareAndSet(false, true)) {
                session.close()
            }
            throw error
        }
    }

    private fun buildInferenceOptions(
        optionsClass: Class<*>,
        modelPath: String,
        backendName: String,
    ): Any? {
        val builder = optionsClass.getMethod("builder").invoke(null)
            ?: error("MediaPipe LLM options builder is unavailable.")
        builder.callBuilder("setModelPath", String::class.java, modelPath)
        builder.callBuilder("setMaxTokens", Int::class.javaPrimitiveType, MAX_TOKENS)
        builder.callBuilderIfExists("setMaxNumImages", Int::class.javaPrimitiveType, MAX_IMAGES)

        val backend = createBackend(backendName)
        if (backend != null) {
            builder.callBuilderIfExists("setPreferredBackend", backend.javaClass, backend)
        }

        return builder.callBuild()
    }

    private fun createBackend(name: String): Any? = try {
        val backendClass = Class.forName("$PACKAGE_NAME.LlmInference\$Backend")
        @Suppress("UNCHECKED_CAST")
        java.lang.Enum.valueOf(backendClass as Class<out Enum<*>>, name)
    } catch (_: Exception) {
        null
    }

    fun parseModelOutput(raw: String): ParsedOutput {
        val thoughtBlock = raw.extractThoughtBlock()
        if (thoughtBlock != null) {
            return ParsedOutput(
                message = thoughtBlock.answer.cleanModelOutput(),
                hasFinalChannel = true,
            )
        }

        val channelIndex = raw.firstFinalChannelIndex()
        val answerRaw = if (channelIndex == null) raw else raw.substring(channelIndex.second)
        return ParsedOutput(
            message = answerRaw.cleanModelOutput(),
            hasFinalChannel = channelIndex != null,
        )
    }

    private fun String.cleanModelOutput(): String =
        stripModelTokens()
            .stripPrivateReasoning()
            .stripToolControlText()
            .stripEmptyJsonFences()
            .collapseRepeatedText()
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun String.toGemmaItPrompt(): String {
        val prompt = trim()
        if (prompt.isBlank() || prompt.contains("<start_of_turn>")) {
            return prompt
        }

        return """
            <start_of_turn>user
            $prompt
            <end_of_turn>
            <start_of_turn>model
        """.trimIndent()
    }

    private fun MultimodalRequest.toPromptTextWithAttachmentNotes(): String {
        val notes = attachments
            .filterNot { attachment -> attachment.type == "image" || attachment.type == "audio" }
            .joinToString("\n") { attachment ->
                "Attached file: ${attachment.name ?: File(attachment.uri).name} (${attachment.uri})"
            }
        return listOf(text.trim(), notes)
            .filter { part -> part.isNotBlank() }
            .joinToString("\n\n")
    }

    private fun String.stripModelTokens(): String =
        replace("<turn|>", "")
            .replace("<eos>", "")
            .replace("<bos>", "")
            .replace("<start_of_turn>system", "")
            .replace("<start_of_turn>user", "")
            .replace("<start_of_turn>model", "")
            .replace("<start_of_turn>", "")
            .replace("<end_of_turn>", "")
            .replace("<|channel>thought", "")
            .replace("<|channel|>thought", "")
            .replace("<channel>thought", "")
            .replace("<|channel>final", "")
            .replace("<|channel|>final", "")
            .replace("<channel|>", "")
            .replace("<channel>", "")

    private fun String.stripPrivateReasoning(): String {
        val firstMarker = PRIVATE_REASONING_MARKERS
            .map { marker -> indexOf(marker, ignoreCase = true) }
            .filter { index -> index >= 0 }
            .minOrNull()
            ?: return this
        return substring(0, firstMarker)
    }

    private fun String.stripToolControlText(): String =
        replace(Regex("""\{\s*"tool_result"\s*:\s*"[^"]*"\s*\}\s*"""), "")
            .replace(Regex("""\(\s*No tool call required\s*\)""", RegexOption.IGNORE_CASE), "")
            .replace(Regex("""No tool call required\.?""", RegexOption.IGNORE_CASE), "")

    private fun String.stripEmptyJsonFences(): String =
        replace(Regex("""(?is)```\s*json\s*```\s*"""), "")

    private fun String.collapseRepeatedText(): String {
        val normalized = trim()
        if (normalized.isEmpty()) {
            return normalized
        }

        for (parts in 2..6) {
            if (normalized.length % parts != 0) {
                continue
            }
            val chunkLength = normalized.length / parts
            val first = normalized.substring(0, chunkLength).trim()
            if (first.isNotBlank() && (1 until parts).all { index ->
                    normalized
                        .substring(index * chunkLength, (index + 1) * chunkLength)
                        .trim() == first
                }
            ) {
                return first
            }
        }

        return normalized
            .split(Regex("""(?<=[.!?])\s+"""))
            .fold(mutableListOf<String>()) { acc, sentence ->
                val cleaned = sentence.trim()
                if (cleaned.isNotBlank() && acc.lastOrNull() != cleaned) {
                    acc.add(cleaned)
                }
                acc
            }
            .joinToString(" ")
    }

    private fun mergeStreamPartial(
        current: String,
        incoming: String,
    ): String {
        if (incoming.isEmpty()) {
            return current
        }
        if (incoming == current || current.endsWith(incoming)) {
            return current
        }
        if (incoming.startsWith(current)) {
            return incoming
        }
        val overlap = minOf(current.length, incoming.length)
        for (length in overlap downTo 1) {
            if (current.endsWith(incoming.substring(0, length))) {
                return current + incoming.substring(length)
            }
        }
        return current + incoming
    }

    private fun String.extractThoughtBlock(): ThoughtBlock? {
        val start = PRIVATE_REASONING_MARKERS
            .mapNotNull { marker ->
                val index = indexOf(marker, ignoreCase = true)
                if (index >= 0) index to marker.length else null
            }
            .minByOrNull { it.first }
            ?: return null
        val reasoningStart = start.first + start.second
        val end = indexOf("<channel|>", startIndex = reasoningStart, ignoreCase = true)
        if (end < 0) {
            return null
        }
        return ThoughtBlock(
            reasoning = substring(reasoningStart, end),
            answer = substring(end + "<channel|>".length),
        )
    }

    private fun String.firstFinalChannelIndex(): Pair<Int, Int>? {
        val explicitFinalMarkers = FINAL_CHANNEL_MARKERS
            .filterNot { marker -> marker == "<channel>" }
            .mapNotNull { marker ->
                val index = indexOf(marker, ignoreCase = true)
                if (index >= 0) index to (index + marker.length) else null
            }
        val genericFinalMarkers = Regex("""<channel>(?!thought)""", RegexOption.IGNORE_CASE)
            .findAll(this)
            .map { match -> match.range.first to (match.range.last + 1) }
            .toList()
        return (explicitFinalMarkers + genericFinalMarkers).minByOrNull { it.first }
    }

    private fun shouldBufferPotentialReasoning(text: String): Boolean {
        val normalized = text.trimStart().lowercase()
        return normalized.startsWith("the user ") ||
            normalized.startsWith("based on ") ||
            normalized.startsWith("response plan") ||
            normalized.startsWith("analysis") ||
            normalized.startsWith("thinking process") ||
            normalized.contains("i should ")
    }

    private fun String.trailingBlockedPrefixLength(): Int {
        var length = 0
        for (token in MODEL_TOKENS + PRIVATE_REASONING_MARKERS) {
            for (prefixLength in 1 until token.length) {
                if (endsWith(token.substring(0, prefixLength), ignoreCase = true)) {
                    length = maxOf(length, prefixLength)
                }
            }
        }
        return length
    }

    private fun String.hasPrivateReasoningMarker(): Boolean =
        PRIVATE_REASONING_MARKERS.any { marker -> contains(marker, ignoreCase = true) }

    private fun canUseGpuBackend(): Boolean {
        if (isProbablyEmulator()) {
            return false
        }
        return OPENCL_LIBRARY_PATHS.any { path -> File(path).exists() }
    }

    private fun isProbablyEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val product = Build.PRODUCT.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        return fingerprint.contains("generic") ||
            fingerprint.contains("emulator") ||
            model.contains("sdk") ||
            model.contains("emulator") ||
            product.contains("sdk") ||
            hardware.contains("ranchu") ||
            hardware.contains("goldfish")
    }

    private fun createSession(
        engine: Any,
        enableVision: Boolean,
        enableAudio: Boolean,
    ): MediaPipeSession {
        val sessionClass = Class.forName("$PACKAGE_NAME.LlmInferenceSession")
        val optionsClass = Class.forName("$PACKAGE_NAME.LlmInferenceSession\$LlmInferenceSessionOptions")
        val llmInferenceClass = Class.forName("$PACKAGE_NAME.LlmInference")
        val builder = optionsClass.getMethod("builder").invoke(null)
            ?: error("MediaPipe LLM session options builder is unavailable.")
        builder.callBuilder("setTemperature", Float::class.javaPrimitiveType, TEMPERATURE)
        builder.callBuilder("setTopK", Int::class.javaPrimitiveType, TOP_K)
        builder.callBuilderIfExists("setTopP", Float::class.javaPrimitiveType, TOP_P)
        createGraphOptions(enableVision, enableAudio)?.let { graphOptions ->
            builder.callBuilderIfExists("setGraphOptions", graphOptions.javaClass, graphOptions)
        }

        val options = builder.callBuild()
        val session = sessionClass
            .getMethod("createFromOptions", llmInferenceClass, optionsClass)
            .invoke(null, engine, options)
            ?: error("MediaPipe LLM returned a null session.")
        return MediaPipeSession(session)
    }

    private fun createGraphOptions(
        enableVision: Boolean,
        enableAudio: Boolean,
    ): Any? = try {
        val graphOptionsClass = Class.forName("$PACKAGE_NAME.GraphOptions")
        val builder = graphOptionsClass.getMethod("builder").invoke(null)
            ?: error("MediaPipe graph options builder is unavailable.")
        builder.callBuilderIfExists(
            "setEnableVisionModality",
            Boolean::class.javaPrimitiveType,
            enableVision,
        )
        builder.callBuilderIfExists(
            "setEnableAudioModality",
            Boolean::class.javaPrimitiveType,
            enableAudio,
        )
        builder.callBuild()
    } catch (_: Exception) {
        null
    }

    private fun Any.callBuilder(
        methodName: String,
        parameterType: Class<*>?,
        value: Any,
    ) {
        requireNotNull(parameterType) { "Missing parameter type for $methodName." }
        val method = javaClass.getMethod(methodName, parameterType)
        method.invoke(this, value)
    }

    private fun Any.callBuilderIfExists(
        methodName: String,
        parameterType: Class<*>?,
        value: Any,
    ) {
        try {
            callBuilder(methodName, parameterType, value)
        } catch (_: NoSuchMethodException) {
            return
        }
    }

    private fun Any.callBuild(): Any =
        javaClass.getMethod("build").invoke(this)
            ?: error("MediaPipe builder returned null.")

    private class MediaPipeSession(
        private val delegate: Any,
    ) : AutoCloseable {
        fun addQueryChunk(text: String) {
            delegate.javaClass.getMethod("addQueryChunk", String::class.java).invoke(delegate, text)
        }

        fun addImage(path: String) {
            val bitmap = requireNotNull(BitmapFactory.decodeFile(path)) {
                "Unable to decode image attachment: $path"
            }
            val mpImage = Class.forName(IMAGE_BUILDER_CLASS)
                .getConstructor(Bitmap::class.java)
                .newInstance(bitmap)
                .let { builder -> builder.javaClass.getMethod("build").invoke(builder) }
            delegate.javaClass.getMethod("addImage", Class.forName(MP_IMAGE_CLASS)).invoke(delegate, mpImage)
        }

        fun addAudio(path: String) {
            val audioData = File(path).readBytes()
            delegate.javaClass.getMethod("addAudio", ByteArray::class.java).invoke(delegate, audioData)
        }

        fun generateResponse(): String =
            delegate.javaClass.getMethod("generateResponse").invoke(delegate)?.toString().orEmpty()

        fun generateResponseStream(
            onPartial: (String, Boolean) -> Unit,
            onFinished: () -> Unit,
            onError: (Throwable) -> Unit,
        ) {
            val listenerClass = Class.forName("$PACKAGE_NAME.ProgressListener")
            val listener = Proxy.newProxyInstance(
                listenerClass.classLoader,
                arrayOf(listenerClass),
            ) { _, method, args ->
                if (method.name == "run") {
                    val partial = args?.getOrNull(0)?.toString().orEmpty()
                    val done = args?.getOrNull(1) as? Boolean ?: false
                    onPartial(partial, done)
                }
                null
            }
            val future = delegate.javaClass
                .getMethod("generateResponseAsync", listenerClass)
                .invoke(delegate, listener)

            thread(name = "open-edge-ai-stream-watch") {
                try {
                    future?.javaClass?.getMethod("get")?.invoke(future)
                    onFinished()
                } catch (error: Exception) {
                    onError(error.cause ?: error)
                }
            }
        }

        override fun close() {
            (delegate as? AutoCloseable)?.close()
        }
    }
}
