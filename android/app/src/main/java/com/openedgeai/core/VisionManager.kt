package com.openedgeai.core

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File

class VisionManager(
    context: Context,
) : AutoCloseable {
    private val appContext = context.applicationContext
    private var imageEmbedder: Any? = null

    fun embedImage(uri: Uri): FloatArray {
        val bitmap = appContext.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open image: $uri" }
            BitmapFactory.decodeStream(input)
        } ?: error("Unable to decode image: $uri")
        return embedBitmap(bitmap)
    }

    fun embedImage(path: String): FloatArray {
        val bitmap = BitmapFactory.decodeFile(path)
            ?: error("Unable to decode image: $path")
        return embedBitmap(bitmap)
    }

    fun labelImage(uri: String): List<String> = emptyList()

    fun isAvailable(): Boolean = findImageModelAsset() != null

    override fun close() {
        (imageEmbedder as? AutoCloseable)?.close()
        imageEmbedder = null
    }

    private fun embedBitmap(bitmap: android.graphics.Bitmap): FloatArray {
        val embedder = imageEmbedder ?: createImageEmbedder().also { imageEmbedder = it }
        val mpImage = Class.forName("com.google.mediapipe.framework.image.BitmapImageBuilder")
            .getConstructor(android.graphics.Bitmap::class.java)
            .newInstance(bitmap)
            .let { builder -> builder.javaClass.getMethod("build").invoke(builder) }
        val result = embedder.javaClass
            .getMethod("embed", Class.forName("com.google.mediapipe.framework.image.MPImage"))
            .invoke(embedder, mpImage)
        return extractEmbedding(result)
    }

    private fun createImageEmbedder(): Any {
        val modelAssetPath = findImageModelAsset()
            ?: error("Image embedding model is missing. Add $IMAGE_MODEL_ASSET_PATH to android/app/src/main/assets.")
        val baseOptionsClass = Class.forName("com.google.mediapipe.tasks.core.BaseOptions")
        val runningModeClass = Class.forName("com.google.mediapipe.tasks.vision.core.RunningMode")
        val imageEmbedderClass = Class.forName("com.google.mediapipe.tasks.vision.imageembedder.ImageEmbedder")
        val optionsClass =
            Class.forName("com.google.mediapipe.tasks.vision.imageembedder.ImageEmbedder\$ImageEmbedderOptions")

        val baseOptions = baseOptionsClass.getMethod("builder").invoke(null)
            .callBuilder("setModelAssetPath", String::class.java, modelAssetPath)
            .callBuild()
        val runningMode = java.lang.Enum.valueOf(
            runningModeClass as Class<out Enum<*>>,
            "IMAGE",
        )
        val options = optionsClass.getMethod("builder").invoke(null)
            .callBuilder("setBaseOptions", baseOptionsClass, baseOptions)
            .callBuilder("setRunningMode", runningModeClass, runningMode)
            .callBuilderIfExists("setL2Normalize", Boolean::class.javaPrimitiveType, true)
            .callBuild()

        return imageEmbedderClass
            .getMethod("createFromOptions", Context::class.java, optionsClass)
            .invoke(null, appContext, options)
            ?: error("MediaPipe ImageEmbedder returned null.")
    }

    private fun findImageModelAsset(): String? =
        findModelAsset(IMAGE_MODEL_ASSET_PATH)

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
        const val IMAGE_MODEL_NAME = "MobileNet-V3 small"
        const val IMAGE_MODEL_ASSET_PATH = "models/mobilenet_v3_small.tflite"
        const val IMAGE_MODEL_DOWNLOAD_URL =
            "https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/latest/mobilenet_v3_small.tflite"
    }
}
