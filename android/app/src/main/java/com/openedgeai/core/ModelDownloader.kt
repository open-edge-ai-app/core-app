package com.openedgeai.core

import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

object ModelDownloader {
    @Volatile
    var isDownloading: Boolean = false
        private set

    @Volatile
    var bytesDownloaded: Long = 0L
        private set

    @Volatile
    var lastError: String? = null
        private set

    @Volatile
    private var shouldCancel: Boolean = false

    private val executor = Executors.newSingleThreadExecutor()

    fun start(manager: ModelFileManager): Boolean {
        if (isDownloading) {
            return false
        }

        val modelFile = manager.modelFile
        if (modelFile.exists() && modelFile.length() == ModelFileManager.MODEL_SIZE_BYTES) {
            bytesDownloaded = modelFile.length()
            lastError = null
            return false
        }

        manager.ensureModelDirectory()
        shouldCancel = false
        isDownloading = true
        lastError = null
        bytesDownloaded = if (modelFile.exists()) modelFile.length() else 0L

        executor.execute {
            try {
                downloadToFile(modelFile)
                if (modelFile.length() != ModelFileManager.MODEL_SIZE_BYTES) {
                    throw IllegalStateException(
                        "Model size mismatch: ${modelFile.length()} != ${ModelFileManager.MODEL_SIZE_BYTES}",
                    )
                }
                bytesDownloaded = modelFile.length()
            } catch (error: Exception) {
                if (!shouldCancel) {
                    lastError = error.message ?: error.javaClass.simpleName
                }
            } finally {
                isDownloading = false
                shouldCancel = false
            }
        }

        return true
    }

    fun cancel() {
        shouldCancel = true
    }

    private fun downloadToFile(modelFile: File) {
        val existingBytes = if (modelFile.exists()) modelFile.length() else 0L
        val connection = (URL(ModelFileManager.MODEL_DOWNLOAD_URL).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20_000
            readTimeout = 30_000
            instanceFollowRedirects = true
            if (existingBytes > 0L) {
                setRequestProperty("Range", "bytes=$existingBytes-")
            }
        }

        try {
            val append = existingBytes > 0L && connection.responseCode == HttpURLConnection.HTTP_PARTIAL
            if (connection.responseCode !in listOf(HttpURLConnection.HTTP_OK, HttpURLConnection.HTTP_PARTIAL)) {
                throw IllegalStateException("Model download failed: HTTP ${connection.responseCode}")
            }

            if (!append && existingBytes > 0L) {
                modelFile.delete()
                bytesDownloaded = 0L
            }

            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(modelFile, append).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        if (shouldCancel) {
                            throw InterruptedException("Model download cancelled")
                        }
                        val read = input.read(buffer)
                        if (read == -1) {
                            break
                        }
                        output.write(buffer, 0, read)
                        bytesDownloaded += read.toLong()
                    }
                }
            }
        } finally {
            connection.disconnect()
        }
    }
}
