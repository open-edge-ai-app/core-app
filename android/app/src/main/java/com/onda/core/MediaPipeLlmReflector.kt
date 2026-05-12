package com.onda.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File
import java.lang.reflect.Proxy
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

object MediaPipeLlmReflector {
    private const val PACKAGE_NAME = "com.google.mediapipe.tasks.genai.llminference"
    private const val IMAGE_BUILDER_CLASS = "com.google.mediapipe.framework.image.BitmapImageBuilder"
    private const val MP_IMAGE_CLASS = "com.google.mediapipe.framework.image.MPImage"
    private const val MAX_TOKENS = 1024
    private const val MAX_IMAGES = 10
    private const val TEMPERATURE = 0.7f
    private const val TOP_K = 64
    private const val TOP_P = 0.95f

    fun createEngine(
        context: Context,
        modelPath: String,
    ): Any {
        val llmInferenceClass = Class.forName("$PACKAGE_NAME.LlmInference")
        val optionsClass = Class.forName("$PACKAGE_NAME.LlmInference\$LlmInferenceOptions")
        val options = buildInferenceOptions(optionsClass, modelPath, "GPU")
            ?: buildInferenceOptions(optionsClass, modelPath, "CPU")
            ?: error("Unable to create MediaPipe LLM options.")

        return try {
            llmInferenceClass
                .getMethod("createFromOptions", Context::class.java, optionsClass)
                .invoke(null, context.applicationContext, options)
                ?: error("MediaPipe LLM returned a null engine.")
        } catch (gpuError: Exception) {
            val cpuOptions = buildInferenceOptions(optionsClass, modelPath, "CPU")
                ?: throw gpuError
            llmInferenceClass
                .getMethod("createFromOptions", Context::class.java, optionsClass)
                .invoke(null, context.applicationContext, cpuOptions)
                ?: error("MediaPipe LLM returned a null CPU engine.")
        }
    }

    fun sendText(
        engine: Any,
        text: String,
    ): String = createSession(engine, enableVision = false, enableAudio = false).use { session ->
        session.addQueryChunk(text)
        session.generateResponse()
    }

    fun sendMultimodal(
        engine: Any,
        request: MultimodalRequest,
    ): String {
        val hasImages = request.attachments.any { it.type == "image" }
        val hasAudio = request.attachments.any { it.type == "audio" }

        return createSession(engine, enableVision = hasImages, enableAudio = hasAudio).use { session ->
            val text = request.text.trim()
            if (text.isNotEmpty()) {
                session.addQueryChunk(text)
            }

            request.attachments.forEach { attachment ->
                when (attachment.type) {
                    "image" -> session.addImage(attachment.uri)
                    "audio" -> session.addAudio(attachment.uri)
                    else -> session.addQueryChunk(
                        "\nAttached file: ${attachment.name ?: File(attachment.uri).name} (${attachment.uri})",
                    )
                }
            }

            session.generateResponse()
        }
    }

    fun sendMultimodalStream(
        engine: Any,
        request: MultimodalRequest,
        onPartial: (String, Boolean) -> Unit,
        onComplete: (String) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val hasImages = request.attachments.any { it.type == "image" }
        val hasAudio = request.attachments.any { it.type == "audio" }
        val response = StringBuilder()
        val completed = AtomicBoolean(false)

        val session = createSession(engine, enableVision = hasImages, enableAudio = hasAudio)
        try {
            val text = request.text.trim()
            if (text.isNotEmpty()) {
                session.addQueryChunk(text)
            }

            request.attachments.forEach { attachment ->
                when (attachment.type) {
                    "image" -> session.addImage(attachment.uri)
                    "audio" -> session.addAudio(attachment.uri)
                    else -> session.addQueryChunk(
                        "\nAttached file: ${attachment.name ?: File(attachment.uri).name} (${attachment.uri})",
                    )
                }
            }

            session.generateResponseStream(
                onPartial = { partial, done ->
                    if (partial.isNotEmpty()) {
                        response.append(partial)
                        onPartial(partial, done)
                    }

                    if (done && completed.compareAndSet(false, true)) {
                        session.close()
                        onComplete(response.toString())
                    }
                },
                onComplete = { finalResponse ->
                    if (completed.compareAndSet(false, true)) {
                        session.close()
                        onComplete(response.toString().ifBlank { finalResponse })
                    }
                },
                onError = { error ->
                    if (completed.compareAndSet(false, true)) {
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
            onComplete: (String) -> Unit,
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
                    val finalResponse = future
                        ?.javaClass
                        ?.getMethod("get")
                        ?.invoke(future)
                        ?.toString()
                        .orEmpty()
                    onComplete(finalResponse)
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
