package com.openedgeai.core

import android.content.Context
import java.io.File

class ModelFileManager(
    context: Context,
) {
    private val appContext = context.applicationContext

    val modelFile: File
        get() = File(File(appContext.filesDir, MODEL_DIR), MODEL_FILE_NAME)

    fun getStatus(): ModelStatus {
        val file = modelFile
        val downloadedBytes = if (file.exists()) file.length() else 0L
        return ModelStatus(
            modelName = MODEL_NAME,
            installed = downloadedBytes == MODEL_SIZE_BYTES,
            isDownloading = ModelDownloader.isDownloading,
            bytesDownloaded = if (ModelDownloader.isDownloading) {
                ModelDownloader.bytesDownloaded
            } else {
                downloadedBytes
            },
            totalBytes = MODEL_SIZE_BYTES,
            localPath = file.absolutePath,
            downloadUrl = MODEL_DOWNLOAD_URL,
            error = ModelDownloader.lastError,
        )
    }

    fun getStartupState(): StartupState {
        val status = getStatus()
        return when {
            status.installed -> StartupState(
                ready = true,
                nextAction = "continue",
                message = "Model is installed. On-device inference is ready.",
                modelStatus = status,
            )
            status.isDownloading -> StartupState(
                ready = false,
                nextAction = "show_download_progress",
                message = "Model download is in progress.",
                modelStatus = status,
            )
            else -> StartupState(
                ready = false,
                nextAction = "show_model_download",
                message = "Model is required before local inference can start.",
                modelStatus = status,
            )
        }
    }

    fun ensureModelDirectory(): File {
        val directory = modelFile.parentFile
        if (directory != null && !directory.exists()) {
            directory.mkdirs()
        }
        return requireNotNull(directory)
    }

    companion object {
        const val MODEL_NAME = "gemma-4-E2B-it"
        const val MODEL_FILE_NAME = "gemma-4-E2B-it.litertlm"
        const val MODEL_SIZE_BYTES = 2_588_147_712L
        const val MODEL_DIR = "models"
        const val MODEL_DOWNLOAD_URL =
            "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true"
    }
}
