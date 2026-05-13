package com.openedgeai.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

object LiteRtLmReflector {
    private const val TAG = "OpenEdgeAILiteRtLm"
    private const val MAX_NUM_TOKENS = 4096
    private const val TEMPERATURE = 0.7
    private const val TOP_K = 64
    private const val TOP_P = 0.95
    private const val STREAM_IDLE_COMPLETE_MS = 2_500L
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
    )

    class EngineHandle(
        private val context: Context,
        val engine: Engine,
    ) : AutoCloseable {
        fun createConversation(initialMessages: List<ConversationMessage>): Conversation =
            engine.createConversation(
                ConversationConfig(
                    initialMessages = initialMessages.toLiteRtMessages(),
                    samplerConfig = SamplerConfig(
                        topK = TOP_K,
                        topP = TOP_P,
                        temperature = TEMPERATURE,
                    ),
                ),
            )

        override fun close() {
            engine.close()
        }
    }

    fun createEngine(
        context: Context,
        modelPath: String,
    ): EngineHandle {
        val preferredBackend = if (canUseGpuBackend()) Backend.GPU() else Backend.CPU()
        val engineConfig = EngineConfig(
            modelPath = modelPath,
            backend = preferredBackend,
            visionBackend = preferredBackend,
            audioBackend = Backend.CPU(),
            maxNumTokens = MAX_NUM_TOKENS,
            cacheDir = context.cacheDir.absolutePath,
        )
        val engine = Engine(engineConfig)
        return try {
            engine.initialize()
            EngineHandle(context.applicationContext, engine)
        } catch (error: Exception) {
            try {
                engine.close()
            } catch (_: Exception) {
                // Ignore cleanup failures from a partially initialized engine.
            }
            if (preferredBackend is Backend.CPU) {
                throw error
            }

            val cpuConfig = EngineConfig(
                modelPath = modelPath,
                backend = Backend.CPU(),
                visionBackend = Backend.CPU(),
                audioBackend = Backend.CPU(),
                maxNumTokens = MAX_NUM_TOKENS,
                cacheDir = context.cacheDir.absolutePath,
            )
            val cpuEngine = Engine(cpuConfig)
            cpuEngine.initialize()
            EngineHandle(context.applicationContext, cpuEngine)
        }
    }

    fun sendText(
        handle: EngineHandle,
        text: String,
    ): ParsedOutput =
        handle.createConversation(emptyList()).use { conversation ->
            val message = conversation.sendMessage(text, noThinkingContext())
            ParsedOutput(message = message.toFinalText())
        }

    fun sendMultimodal(
        handle: EngineHandle,
        request: MultimodalRequest,
    ): ParsedOutput =
        handle.createConversation(request.history).use { conversation ->
            val message = conversation.sendMessage(request.toContents(), noThinkingContext())
            ParsedOutput(message = message.toFinalText())
        }

    fun sendMultimodalStream(
        handle: EngineHandle,
        request: MultimodalRequest,
        onPartial: (String, Boolean) -> Unit,
        onComplete: (ParsedOutput) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val conversation = handle.createConversation(request.history)
        val output = StringBuilder()
        val completed = AtomicBoolean(false)
        val lastOutputAt = AtomicLong(System.currentTimeMillis())
        val watchdogExecutor = Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "open-edge-ai-litertlm-idle-watch").apply {
                isDaemon = true
            }
        }
        var watchdog: ScheduledFuture<*>? = null

        fun finish(cancelGeneration: Boolean) {
            if (!completed.compareAndSet(false, true)) {
                return
            }

            watchdog?.cancel(false)
            watchdogExecutor.shutdownNow()
            if (cancelGeneration) {
                try {
                    conversation.cancelProcess()
                } catch (error: Exception) {
                    Log.w(TAG, "Failed to cancel LiteRT-LM generation", error)
                }
            }
            closeConversation(conversation)
            onComplete(ParsedOutput(message = output.toString().cleanModelOutput()))
        }

        fun fail(error: Throwable) {
            if (!completed.compareAndSet(false, true)) {
                return
            }

            watchdog?.cancel(false)
            watchdogExecutor.shutdownNow()
            closeConversation(conversation)
            Log.e(TAG, "LiteRT-LM stream error", error)
            onError(error)
        }

        watchdog = watchdogExecutor.scheduleWithFixedDelay(
            {
                if (completed.get() || output.isBlank()) {
                    return@scheduleWithFixedDelay
                }

                val idleMs = System.currentTimeMillis() - lastOutputAt.get()
                if (idleMs >= STREAM_IDLE_COMPLETE_MS) {
                    Log.d(TAG, "stream idle complete idleMs=$idleMs chars=${output.length}")
                    finish(cancelGeneration = true)
                }
            },
            STREAM_IDLE_COMPLETE_MS,
            500L,
            TimeUnit.MILLISECONDS,
        )

        conversation.sendMessageAsync(
            request.toContents(),
            object : MessageCallback {
                override fun onMessage(message: Message) {
                    if (completed.get()) {
                        return
                    }

                    val text = message.toFinalText()
                    if (text.isBlank()) {
                        return
                    }

                    output.append(text)
                    lastOutputAt.set(System.currentTimeMillis())
                    onPartial(text, false)
                }

                override fun onDone() {
                    finish(cancelGeneration = false)
                }

                override fun onError(throwable: Throwable) {
                    if (throwable is CancellationException) {
                        finish(cancelGeneration = false)
                    } else {
                        fail(throwable)
                    }
                }
            },
            noThinkingContext(),
        )
    }

    private fun MultimodalRequest.toContents(): Contents {
        val contents = mutableListOf<Content>()
        attachments.forEach { attachment ->
            when (attachment.type) {
                "image" -> contents.add(Content.ImageBytes(attachment.uri.toPngByteArray()))
                "audio" -> contents.add(Content.AudioBytes(File(attachment.uri).readBytes()))
            }
        }

        val textParts = mutableListOf<String>()
        if (text.trim().isNotEmpty()) {
            textParts.add(text.trim())
        }
        attachments
            .filterNot { attachment -> attachment.type == "image" || attachment.type == "audio" }
            .mapTo(textParts) { attachment ->
                "Attached file: ${attachment.name ?: File(attachment.uri).name} (${attachment.uri})"
            }
        if (textParts.isNotEmpty()) {
            contents.add(Content.Text(textParts.joinToString("\n\n")))
        }

        return Contents.of(contents)
    }

    private fun List<ConversationMessage>.toLiteRtMessages(): List<Message> =
        mapNotNull { message ->
            val content = message.content.cleanModelOutput()
            if (content.isBlank()) {
                null
            } else {
                when (message.role.lowercase()) {
                    "assistant", "model" -> Message.model(content)
                    "tool" -> Message.model(content)
                    else -> Message.user(content)
                }
            }
        }

    private fun Message.toFinalText(): String =
        toString().cleanModelOutput()

    private fun String.toPngByteArray(): ByteArray {
        val bitmap = requireNotNull(BitmapFactory.decodeFile(this)) {
            "Unable to decode image attachment: $this"
        }
        return ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        }
    }

    private fun noThinkingContext(): Map<String, Any> =
        mapOf("enable_thinking" to false)

    private fun closeConversation(conversation: Conversation) {
        try {
            conversation.close()
        } catch (error: Exception) {
            Log.w(TAG, "Failed to close conversation", error)
        }
    }

    private fun String.cleanModelOutput(): String =
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
            .stripPrivateReasoning()
            .stripToolControlText()
            .stripEmptyJsonFences()
            .collapseRepeatedText()
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun String.stripPrivateReasoning(): String {
        val markerIndex = listOf(
            "Thinking Process",
            "Response Plan",
            "Analyze the Request",
            "Analyze the Context",
            "The user is asking",
            "Based on the context",
        )
            .map { marker -> indexOf(marker, ignoreCase = true) }
            .filter { index -> index >= 0 }
            .minOrNull()
            ?: return this
        return substring(0, markerIndex)
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
    }

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
}
