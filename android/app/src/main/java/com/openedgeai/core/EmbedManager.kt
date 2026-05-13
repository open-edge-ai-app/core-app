package com.openedgeai.core

import android.content.Context

class EmbedManager(
    context: Context,
) : AutoCloseable {
    private val appContext = context.applicationContext
    private var textEmbedder: Any? = null

    fun embed(text: String): FloatArray {
        val normalized = text.trim()
        if (normalized.isEmpty()) {
            return FloatArray(0)
        }

        val embedder = textEmbedder ?: createTextEmbedder().also { textEmbedder = it }
        val result = embedder.javaClass
            .getMethod("embed", String::class.java)
            .invoke(embedder, normalized)
        return extractEmbedding(result)
    }

    fun isAvailable(): Boolean = findTextModelAsset() != null

    override fun close() {
        (textEmbedder as? AutoCloseable)?.close()
        textEmbedder = null
    }

    private fun createTextEmbedder(): Any {
        val modelAssetPath = findTextModelAsset()
            ?: error("Text embedding model is missing. Add $TEXT_MODEL_ASSET_PATH to android/app/src/main/assets.")
        val baseOptionsClass = Class.forName("com.google.mediapipe.tasks.core.BaseOptions")
        val textEmbedderClass = Class.forName("com.google.mediapipe.tasks.text.textembedder.TextEmbedder")
        val optionsClass =
            Class.forName("com.google.mediapipe.tasks.text.textembedder.TextEmbedder\$TextEmbedderOptions")

        val baseOptions = baseOptionsClass.getMethod("builder").invoke(null)
            .callBuilder("setModelAssetPath", String::class.java, modelAssetPath)
            .callBuild()
        val options = optionsClass.getMethod("builder").invoke(null)
            .callBuilder("setBaseOptions", baseOptionsClass, baseOptions)
            .callBuilderIfExists("setL2Normalize", Boolean::class.javaPrimitiveType, true)
            .callBuild()

        return textEmbedderClass
            .getMethod("createFromOptions", Context::class.java, optionsClass)
            .invoke(null, appContext, options)
            ?: error("MediaPipe TextEmbedder returned null.")
    }

    private fun findTextModelAsset(): String? =
        findModelAsset(TEXT_MODEL_ASSET_PATH)

    private fun findModelAsset(assetPath: String): String? =
        try {
            appContext.assets.open(assetPath).close()
            assetPath
        } catch (_: Exception) {
            null
        }

    private fun extractEmbedding(result: Any?): FloatArray {
        val embeddingResult = result?.javaClass?.getMethod("embeddingResult")?.invoke(result)
            ?: return FloatArray(0)
        val embeddings = embeddingResult.javaClass.getMethod("embeddings").invoke(embeddingResult) as? List<*>
            ?: return FloatArray(0)
        val firstEmbedding = embeddings.firstOrNull() ?: return FloatArray(0)
        val values = firstEmbedding.javaClass.getMethod("floatEmbedding").invoke(firstEmbedding)
        return values.toFloatArray()
    }

    private fun Any?.toFloatArray(): FloatArray {
        val resolved = if (this is java.util.Optional<*>) orElse(null) else this
        return when (resolved) {
            is FloatArray -> resolved
            is List<*> -> FloatArray(resolved.size) { index ->
                (resolved[index] as? Number)?.toFloat() ?: 0f
            }
            else -> FloatArray(0)
        }
    }

    private fun Any.callBuilder(
        methodName: String,
        parameterType: Class<*>,
        value: Any,
    ): Any {
        javaClass.getMethod(methodName, parameterType).invoke(this, value)
        return this
    }

    private fun Any.callBuilderIfExists(
        methodName: String,
        parameterType: Class<*>?,
        value: Any,
    ): Any {
        try {
            if (parameterType != null) {
                javaClass.getMethod(methodName, parameterType).invoke(this, value)
            }
        } catch (_: NoSuchMethodException) {
            return this
        }
        return this
    }

    private fun Any.callBuild(): Any =
        javaClass.getMethod("build").invoke(this)
            ?: error("MediaPipe builder returned null.")

    companion object {
        const val TEXT_MODEL_NAME = "Universal Sentence Encoder"
        const val TEXT_MODEL_ASSET_PATH = "models/universal_sentence_encoder.tflite"
        const val TEXT_MODEL_DOWNLOAD_URL =
            "https://storage.googleapis.com/mediapipe-models/text_embedder/universal_sentence_encoder/float32/latest/universal_sentence_encoder.tflite"
    }
}
