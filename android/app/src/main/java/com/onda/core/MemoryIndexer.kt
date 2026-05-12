package com.onda.core

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Telephony
import com.onda.db.VectorDao
import com.onda.db.VectorDBHelper
import com.onda.db.VectorRecord
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.ZipInputStream

class MemoryIndexer(
    context: Context,
    private val dbHelper: VectorDBHelper,
) : AutoCloseable {
    private val appContext = context.applicationContext
    private val dao = VectorDao(dbHelper)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private val embedManager = EmbedManager(appContext)
    private val visionManager = VisionManager(appContext)
    private val preferences: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    @Volatile
    private var lastError: String? = null

    fun getStatus(): IndexingStatus =
        IndexingStatus(
            isAvailable = true,
            isIndexing = running.get(),
            indexedItems = dbHelper.count(),
            lastIndexedAt = dbHelper.lastIndexedAt(),
            lastError = lastError,
            smsEnabled = isSourceEnabled(SOURCE_SMS),
            galleryEnabled = isSourceEnabled(SOURCE_IMAGE),
            documentEnabled = isSourceEnabled(SOURCE_DOCUMENT),
            smsIndexedItems = dbHelper.countBySource(SOURCE_SMS),
            galleryIndexedItems = dbHelper.countBySource(SOURCE_IMAGE),
            documentIndexedItems = dbHelper.countBySource(SOURCE_DOCUMENT),
        )

    fun startIndexing(
        onComplete: (Result<IndexingResult>) -> Unit,
    ) {
        if (!running.compareAndSet(false, true)) {
            onComplete(Result.success(IndexingResult(0, 0, 0, 0, 0, getStatus())))
            return
        }

        executor.execute {
            try {
                lastError = null
                var skipped = 0
                val smsIndexed =
                    if (isSourceEnabled(SOURCE_SMS)) {
                        try {
                            indexSms()
                        } catch (error: Exception) {
                            skipped += 1
                            lastError = error.message ?: error.javaClass.simpleName
                            0
                        }
                    } else {
                        0
                    }
                val galleryIndexed =
                    if (isSourceEnabled(SOURCE_IMAGE)) {
                        try {
                            indexGallery()
                        } catch (error: Exception) {
                            skipped += 1
                            lastError = error.message ?: error.javaClass.simpleName
                            0
                        }
                    } else {
                        0
                    }
                val documentIndexed =
                    if (isSourceEnabled(SOURCE_DOCUMENT)) {
                        try {
                            indexDocuments()
                        } catch (error: Exception) {
                            skipped += 1
                            lastError = error.message ?: error.javaClass.simpleName
                            0
                        }
                    } else {
                        0
                    }
                running.set(false)
                onComplete(
                    Result.success(
                        IndexingResult(
                            smsIndexed,
                            galleryIndexed,
                            documentIndexed,
                            0,
                            skipped,
                            getStatus(),
                        ),
                    ),
                )
            } catch (error: Exception) {
                lastError = error.message ?: error.javaClass.simpleName
                running.set(false)
                onComplete(Result.failure(error))
            } finally {
                running.set(false)
            }
        }
    }

    fun indexIncomingSms(
        address: String?,
        body: String?,
        timestamp: Long,
    ): Boolean {
        if (!isSourceEnabled(SOURCE_SMS)) {
            return false
        }
        val text = buildSmsText(address, timestamp, body)
        val embedding = embedManager.embed(text)
        return dao.insert(
            VectorRecord(
                id = 0,
                source = SOURCE_SMS,
                sourceId = "incoming:${timestamp}:${address.orEmpty().hashCode()}:${body.orEmpty().hashCode()}",
                text = text,
                embedding = embedding,
                uri = Telephony.Sms.CONTENT_URI.toString(),
                timestamp = timestamp,
                metadata = "incoming",
            ),
        ) > 0
    }

    fun setSourceEnabled(
        source: String,
        enabled: Boolean,
        onComplete: (Result<IndexingResult>) -> Unit,
    ) {
        val normalizedSource = normalizeSource(source)
        if (normalizedSource == null) {
            onComplete(Result.failure(IllegalArgumentException("Unsupported memory source: $source")))
            return
        }

        preferences.edit().putBoolean(enabledKey(normalizedSource), enabled).apply()
        if (enabled) {
            startSourceIndexing(normalizedSource, onComplete)
            return
        }

        executor.execute {
            try {
                val deleted = dao.deleteBySource(normalizedSource)
                onComplete(Result.success(IndexingResult(0, 0, 0, deleted, 0, getStatus())))
            } catch (error: Exception) {
                lastError = error.message ?: error.javaClass.simpleName
                onComplete(Result.failure(error))
            }
        }
    }

    fun deleteSourceEmbeddings(
        source: String,
        onComplete: (Result<IndexingResult>) -> Unit,
    ) {
        val normalizedSource = normalizeSource(source)
        if (normalizedSource == null) {
            onComplete(Result.failure(IllegalArgumentException("Unsupported memory source: $source")))
            return
        }

        executor.execute {
            try {
                val deleted = dao.deleteBySource(normalizedSource)
                onComplete(Result.success(IndexingResult(0, 0, 0, deleted, 0, getStatus())))
            } catch (error: Exception) {
                lastError = error.message ?: error.javaClass.simpleName
                onComplete(Result.failure(error))
            }
        }
    }

    fun startSourceIndexing(
        source: String,
        onComplete: (Result<IndexingResult>) -> Unit,
    ) {
        val normalizedSource = normalizeSource(source)
        if (normalizedSource == null) {
            onComplete(Result.failure(IllegalArgumentException("Unsupported memory source: $source")))
            return
        }
        if (!running.compareAndSet(false, true)) {
            onComplete(Result.success(IndexingResult(0, 0, 0, 0, 0, getStatus())))
            return
        }

        executor.execute {
            try {
                lastError = null
                val count = when (normalizedSource) {
                    SOURCE_SMS -> indexSms()
                    SOURCE_IMAGE -> indexGallery()
                    SOURCE_DOCUMENT -> indexDocuments()
                    else -> 0
                }
                running.set(false)
                onComplete(
                    Result.success(
                        IndexingResult(
                            smsIndexed = if (normalizedSource == SOURCE_SMS) count else 0,
                            galleryIndexed = if (normalizedSource == SOURCE_IMAGE) count else 0,
                            documentIndexed = if (normalizedSource == SOURCE_DOCUMENT) count else 0,
                            deleted = 0,
                            skipped = 0,
                            status = getStatus(),
                        ),
                    ),
                )
            } catch (error: Exception) {
                lastError = error.message ?: error.javaClass.simpleName
                running.set(false)
                onComplete(Result.failure(error))
            } finally {
                running.set(false)
            }
        }
    }

    private fun indexSms(limit: Int? = null): Int {
        if (!hasPermission(Manifest.permission.READ_SMS)) {
            return 0
        }
        if (!embedManager.isAvailable()) {
            error("Text embedding model is missing.")
        }

        var indexed = 0
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.DATE,
            Telephony.Sms.BODY,
            Telephony.Sms.TYPE,
        )
        appContext.contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            projection,
            null,
            null,
            buildSortOrder(Telephony.Sms.DATE, limit),
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val address = cursor.getString(1)
                val date = cursor.getLong(2)
                val body = cursor.getString(3)
                val type = cursor.getInt(4)
                val uri = ContentUris.withAppendedId(Telephony.Sms.CONTENT_URI, id)
                val text = buildSmsText(address, date, body, type)
                val embedding = embedManager.embed(text)
                val insertedId = dao.insert(
                    VectorRecord(
                        id = 0,
                        source = SOURCE_SMS,
                        sourceId = id.toString(),
                        text = text,
                        embedding = embedding,
                        uri = uri.toString(),
                        timestamp = date,
                        metadata = "type=$type",
                    ),
                )
                if (insertedId > 0) {
                    indexed += 1
                }
            }
        }
        return indexed
    }

    private fun indexDocuments(limit: Int? = null): Int {
        if (!hasDocumentPermission()) {
            return 0
        }
        if (!embedManager.isAvailable()) {
            error("Text embedding model is missing.")
        }

        var indexed = 0
        val externalFiles = MediaStore.Files.getContentUri("external")
        val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                MediaStore.Files.FileColumns._ID,
                MediaStore.Files.FileColumns.DISPLAY_NAME,
                MediaStore.Files.FileColumns.DATE_MODIFIED,
                MediaStore.Files.FileColumns.MIME_TYPE,
                MediaStore.Files.FileColumns.SIZE,
                MediaStore.Files.FileColumns.RELATIVE_PATH,
            )
        } else {
            arrayOf(
                MediaStore.Files.FileColumns._ID,
                MediaStore.Files.FileColumns.DISPLAY_NAME,
                MediaStore.Files.FileColumns.DATE_MODIFIED,
                MediaStore.Files.FileColumns.MIME_TYPE,
                MediaStore.Files.FileColumns.SIZE,
            )
        }

        appContext.contentResolver.query(
            externalFiles,
            projection,
            buildDocumentSelection(),
            DOCUMENT_MIME_TYPES,
            buildSortOrder(MediaStore.Files.FileColumns.DATE_MODIFIED, limit),
        )?.use { cursor ->
            val relativePathIndex = cursor.getColumnIndex(MediaStore.Files.FileColumns.RELATIVE_PATH)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val name = cursor.getString(1)
                val modified = normalizeDocumentTimestamp(cursor.getLong(2))
                val mimeType = cursor.getString(3)
                val size = cursor.getLong(4)
                val relativePath = if (relativePathIndex >= 0) cursor.getString(relativePathIndex) else null
                val uri = ContentUris.withAppendedId(externalFiles, id)
                val baseText = buildDocumentText(name, modified, mimeType, relativePath, uri)
                val extractedText = extractDocumentText(uri, mimeType)
                val chunks = buildDocumentChunks(baseText, extractedText)
                chunks.forEachIndexed { chunkIndex, chunk ->
                    val embedding = embedManager.embed(chunk)
                    val insertedId = dao.insert(
                        VectorRecord(
                            id = 0,
                            source = SOURCE_DOCUMENT,
                            sourceId = "$id:$chunkIndex",
                            text = chunk,
                            embedding = embedding,
                            uri = uri.toString(),
                            timestamp = modified,
                            metadata = "mimeType=${mimeType.orEmpty()};size=$size;relativePath=${relativePath.orEmpty()};chunk=$chunkIndex;chunks=${chunks.size}",
                        ),
                    )
                    if (insertedId > 0) {
                        indexed += 1
                    }
                }
            }
        }
        return indexed
    }

    private fun indexGallery(limit: Int? = null): Int {
        if (!hasImagePermission()) {
            return 0
        }
        if (!visionManager.isAvailable()) {
            error("Image embedding model is missing.")
        }

        var indexed = 0
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_TAKEN,
            MediaStore.Images.Media.MIME_TYPE,
        )
        appContext.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            buildSortOrder(MediaStore.Images.Media.DATE_TAKEN, limit),
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val name = cursor.getString(1)
                val dateTaken = cursor.getLong(2)
                val mimeType = cursor.getString(3)
                val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                val embedding = visionManager.embedImage(uri)
                val text = buildImageText(name, dateTaken, uri)
                val insertedId = dao.insert(
                    VectorRecord(
                        id = 0,
                        source = SOURCE_IMAGE,
                        sourceId = id.toString(),
                        text = text,
                        embedding = embedding,
                        uri = uri.toString(),
                        timestamp = dateTaken,
                        metadata = "mimeType=${mimeType.orEmpty()}",
                    ),
                )
                if (insertedId > 0) {
                    indexed += 1
                }
            }
        }
        return indexed
    }

    private fun buildSmsText(
        address: String?,
        timestamp: Long,
        body: String?,
        type: Int = Telephony.Sms.MESSAGE_TYPE_INBOX,
    ): String {
        val direction = when (type) {
            Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
            Telephony.Sms.MESSAGE_TYPE_OUTBOX -> "outbox"
            else -> "received"
        }
        return "${formatDate(timestamp)} ${address.orEmpty()} $direction SMS: ${body.orEmpty()}"
    }

    private fun buildImageText(
        name: String?,
        timestamp: Long,
        uri: Uri,
    ): String = "${formatDate(timestamp)} gallery image ${name.orEmpty()} at $uri"

    private fun buildDocumentText(
        name: String?,
        timestamp: Long,
        mimeType: String?,
        relativePath: String?,
        uri: Uri,
    ): String =
        "${formatDate(timestamp)} document file ${name.orEmpty()} ${mimeType.orEmpty()} from ${relativePath.orEmpty()} at $uri"

    private fun extractDocumentText(uri: Uri, mimeType: String?): String =
        try {
            when (mimeType?.lowercase(Locale.US)) {
                "text/plain",
                "text/csv",
                "text/markdown",
                "application/json" -> readTextDocument(uri)
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> readDocxDocument(uri)
                else -> ""
            }
        } catch (error: Exception) {
            ""
        }

    private fun readTextDocument(uri: Uri): String =
        appContext.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open document: $uri" }
            input.bufferedReader(Charsets.UTF_8).use { reader ->
                reader.readText().take(MAX_DOCUMENT_TEXT_CHARS)
            }
        }

    private fun readDocxDocument(uri: Uri): String {
        val text = StringBuilder()
        appContext.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open document: $uri" }
            ZipInputStream(input.buffered()).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.name == "word/document.xml") {
                        val xml = zip.bufferedReader(Charsets.UTF_8).use { reader ->
                            reader.readText()
                        }
                        text.append(
                            xml
                                .replace(Regex("<w:tab\\b[^>]*/>"), "\t")
                                .replace(Regex("</w:p>"), "\n")
                                .replace(Regex("<[^>]+>"), " ")
                                .replace("&amp;", "&")
                                .replace("&lt;", "<")
                                .replace("&gt;", ">")
                                .replace("&quot;", "\"")
                                .replace("&apos;", "'"),
                        )
                        break
                    }
                }
            }
        }
        return normalizeDocumentBody(text.toString()).take(MAX_DOCUMENT_TEXT_CHARS)
    }

    private fun buildDocumentChunks(baseText: String, extractedText: String): List<String> {
        val body = normalizeDocumentBody(extractedText)
        if (body.isBlank()) {
            return listOf(baseText)
        }

        val chunks = mutableListOf<String>()
        var start = 0
        while (start < body.length && chunks.size < MAX_DOCUMENT_CHUNKS) {
            val end = minOf(body.length, start + DOCUMENT_CHUNK_CHARS)
            val chunkBody = body.substring(start, end).trim()
            if (chunkBody.isNotBlank()) {
                chunks.add("$baseText\nContent chunk ${chunks.size + 1}:\n$chunkBody")
            }
            if (end == body.length) {
                break
            }
            start = maxOf(end - DOCUMENT_CHUNK_OVERLAP_CHARS, start + 1)
        }
        return chunks.ifEmpty { listOf(baseText) }
    }

    private fun normalizeDocumentBody(text: String): String =
        text
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun formatDate(timestamp: Long): String =
        if (timestamp <= 0) {
            "unknown date"
        } else {
            DATE_FORMAT.format(Date(timestamp))
        }

    private fun hasImagePermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            hasPermission(Manifest.permission.READ_MEDIA_IMAGES)
        } else {
            hasPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    private fun hasDocumentPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            true
        } else {
            hasPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    private fun hasPermission(permission: String): Boolean =
        appContext.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun buildSortOrder(column: String, limit: Int?): String =
        if (limit == null) {
            "$column DESC"
        } else {
            "$column DESC LIMIT $limit"
        }

    private fun buildDocumentSelection(): String =
        DOCUMENT_MIME_TYPES.joinToString(
            prefix = "${MediaStore.Files.FileColumns.MIME_TYPE} IN (",
            postfix = ")",
            separator = ",",
        ) { "?" }

    private fun normalizeDocumentTimestamp(timestamp: Long): Long =
        if (timestamp in 1 until 10_000_000_000L) {
            timestamp * 1000
        } else {
            timestamp
        }

    private fun isSourceEnabled(source: String): Boolean =
        preferences.getBoolean(enabledKey(source), DEFAULT_SOURCE_ENABLED)

    private fun enabledKey(source: String): String = "indexing_enabled_$source"

    private fun normalizeSource(source: String): String? =
        when (source.lowercase(Locale.US)) {
            SOURCE_SMS -> SOURCE_SMS
            "gallery", SOURCE_IMAGE -> SOURCE_IMAGE
            SOURCE_DOCUMENT, "documents", "download", "downloads" -> SOURCE_DOCUMENT
            else -> null
        }

    override fun close() {
        embedManager.close()
        visionManager.close()
        executor.shutdownNow()
    }

    companion object {
        private const val SOURCE_SMS = "sms"
        private const val SOURCE_IMAGE = "image"
        private const val SOURCE_DOCUMENT = "document"
        private const val PREFS_NAME = "onda_indexing"
        private const val DEFAULT_SOURCE_ENABLED = false
        private const val DOCUMENT_CHUNK_CHARS = 1200
        private const val DOCUMENT_CHUNK_OVERLAP_CHARS = 160
        private const val MAX_DOCUMENT_CHUNKS = 24
        private const val MAX_DOCUMENT_TEXT_CHARS = 30_000
        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.KOREA)
        private val DOCUMENT_MIME_TYPES = arrayOf(
            "application/pdf",
            "text/plain",
            "text/csv",
            "text/markdown",
            "application/json",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        )
    }
}
