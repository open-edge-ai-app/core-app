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
            smsIndexedItems = dbHelper.countBySource(SOURCE_SMS),
            galleryIndexedItems = dbHelper.countBySource(SOURCE_IMAGE),
        )

    fun startIndexing(
        onComplete: (Result<IndexingResult>) -> Unit,
    ) {
        if (!running.compareAndSet(false, true)) {
            onComplete(Result.success(IndexingResult(0, 0, 0, 0, getStatus())))
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
                running.set(false)
                onComplete(Result.success(IndexingResult(smsIndexed, galleryIndexed, 0, skipped, getStatus())))
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
                onComplete(Result.success(IndexingResult(0, 0, deleted, 0, getStatus())))
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
                onComplete(Result.success(IndexingResult(0, 0, deleted, 0, getStatus())))
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
            onComplete(Result.success(IndexingResult(0, 0, 0, 0, getStatus())))
            return
        }

        executor.execute {
            try {
                lastError = null
                val count = when (normalizedSource) {
                    SOURCE_SMS -> indexSms()
                    SOURCE_IMAGE -> indexGallery()
                    else -> 0
                }
                running.set(false)
                onComplete(
                    Result.success(
                        IndexingResult(
                            smsIndexed = if (normalizedSource == SOURCE_SMS) count else 0,
                            galleryIndexed = if (normalizedSource == SOURCE_IMAGE) count else 0,
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

    private fun indexSms(limit: Int = DEFAULT_SMS_LIMIT): Int {
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
            "${Telephony.Sms.DATE} DESC LIMIT $limit",
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

    private fun indexGallery(limit: Int = DEFAULT_GALLERY_LIMIT): Int {
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
            "${MediaStore.Images.Media.DATE_TAKEN} DESC LIMIT $limit",
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

    private fun hasPermission(permission: String): Boolean =
        appContext.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun isSourceEnabled(source: String): Boolean =
        preferences.getBoolean(enabledKey(source), DEFAULT_SOURCE_ENABLED)

    private fun enabledKey(source: String): String = "indexing_enabled_$source"

    private fun normalizeSource(source: String): String? =
        when (source.lowercase(Locale.US)) {
            SOURCE_SMS -> SOURCE_SMS
            "gallery", SOURCE_IMAGE -> SOURCE_IMAGE
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
        private const val PREFS_NAME = "onda_indexing"
        private const val DEFAULT_SOURCE_ENABLED = true
        private const val DEFAULT_SMS_LIMIT = 200
        private const val DEFAULT_GALLERY_LIMIT = 100
        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.KOREA)
    }
}
