package com.openedgeai.core

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Telephony
import com.openedgeai.db.DocumentCatalogRecord
import com.openedgeai.db.VectorDao
import com.openedgeai.db.VectorDBHelper
import com.openedgeai.db.VectorRecord
import java.security.MessageDigest
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
    private val documentTextExtractor = DocumentTextExtractor(appContext)
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
        if (!embedManager.isAvailable()) {
            lastError = TEXT_EMBEDDING_MODEL_MISSING
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

    fun addDocumentFolder(
        folderUri: String,
        onComplete: (Result<IndexingResult>) -> Unit,
    ) {
        val normalizedUri = folderUri.trim()
        if (normalizedUri.isBlank()) {
            onComplete(Result.failure(IllegalArgumentException("Document folder URI is empty.")))
            return
        }

        val folders = getDocumentFolderUris().toMutableSet()
        folders.add(normalizedUri)
        preferences.edit().putStringSet(DOCUMENT_FOLDER_URIS_KEY, folders).apply()

        if (!isSourceEnabled(SOURCE_DOCUMENT)) {
            onComplete(Result.success(IndexingResult(0, 0, 0, 0, 0, getStatus())))
            return
        }

        startSourceIndexing(SOURCE_DOCUMENT, onComplete)
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
            throw IllegalStateException(TEXT_EMBEDDING_MODEL_MISSING)
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
            throw IllegalStateException(TEXT_EMBEDDING_MODEL_MISSING)
        }

        // Bound document_excerpt_cache growth by dropping entries older than the retention
        // window each time the user re-indexes. Excerpts are query-specific so old rows are
        // unlikely to hit again, and a fresh excerpt can always be regenerated on demand.
        dao.pruneDocumentExcerptCache(
            System.currentTimeMillis() - DOCUMENT_EXCERPT_CACHE_TTL_MILLIS,
        )

        var indexed = 0
        indexed += indexMediaStoreDocuments(limit)
        indexed += indexSafDocumentFolders(limit)
        return indexed
    }

    private fun indexMediaStoreDocuments(limit: Int? = null): Int {
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
            buildDocumentSelectionArgs(),
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
                if (indexDocumentCatalogRecord(
                        documentId = "mediastore:$id",
                        uri = uri,
                        name = name,
                        modified = modified,
                        mimeType = mimeType,
                        size = size,
                        relativePath = relativePath,
                        accessMode = DOCUMENT_ACCESS_MEDIASTORE,
                    )
                ) {
                    indexed += 1
                }
            }
        }
        return indexed
    }

    private fun indexSafDocumentFolders(limit: Int? = null): Int {
        var indexed = 0
        val maxDocuments = limit ?: MAX_SAF_DOCUMENTS_PER_RUN
        getDocumentFolderUris().forEach { folderUri ->
            if (indexed >= maxDocuments) {
                return@forEach
            }
            indexed += indexSafDocumentFolder(
                treeUri = Uri.parse(folderUri),
                remaining = maxDocuments - indexed,
            )
        }
        return indexed
    }

    private fun indexSafDocumentFolder(
        treeUri: Uri,
        remaining: Int,
    ): Int =
        try {
            val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
            val rootDocumentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocumentId)
            scanSafChildren(
                treeUri = treeUri,
                parentDocumentUri = rootDocumentUri,
                relativePath = "",
                remaining = remaining,
                depth = 0,
            )
        } catch (_: Exception) {
            0
        }

    private fun scanSafChildren(
        treeUri: Uri,
        parentDocumentUri: Uri,
        relativePath: String,
        remaining: Int,
        depth: Int,
    ): Int {
        if (remaining <= 0) {
            return 0
        }
        // Hard-cap the recursion depth so a pathological folder tree (or a symlink loop
        // exposed through SAF) cannot blow the stack. MAX_SAF_DEPTH covers typical user
        // document hierarchies with plenty of headroom.
        if (depth >= MAX_SAF_DEPTH) {
            return 0
        }

        var indexed = 0
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getDocumentId(parentDocumentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
        )

        appContext.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext() && indexed < remaining) {
                val documentId = cursor.getString(0)
                val name = cursor.getString(1).orEmpty()
                val mimeType = cursor.getString(2)
                val modified = cursor.getLong(3)
                val size = cursor.getLong(4)
                val childUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
                val childRelativePath = if (relativePath.isBlank()) name else "$relativePath/$name"

                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                    indexed += scanSafChildren(
                        treeUri = treeUri,
                        parentDocumentUri = childUri,
                        relativePath = childRelativePath,
                        remaining = remaining - indexed,
                        depth = depth + 1,
                    )
                    continue
                }

                if (!isDocumentMimeType(mimeType, name)) {
                    continue
                }

                if (indexDocumentCatalogRecord(
                        documentId = "saf:${childUri.toString().stableDocumentHash()}",
                        uri = childUri,
                        name = name,
                        modified = modified,
                        mimeType = mimeType,
                        size = size.coerceAtLeast(0L),
                        relativePath = childRelativePath,
                        accessMode = DOCUMENT_ACCESS_SAF,
                    )
                ) {
                    indexed += 1
                }
            }
        }
        return indexed
    }

    private fun indexDocumentCatalogRecord(
        documentId: String,
        uri: Uri,
        name: String?,
        modified: Long,
        mimeType: String?,
        size: Long,
        relativePath: String?,
        accessMode: String,
    ): Boolean {
        val resolvedName = name.orEmpty().ifBlank { uri.lastPathSegment.orEmpty() }
        val resolvedMimeType = mimeType ?: appContext.contentResolver.getType(uri)
        val normalizedModified = normalizeDocumentTimestamp(modified)
        val fingerprint = buildDocumentFingerprint(
            name = resolvedName,
            modified = normalizedModified,
            mimeType = resolvedMimeType,
            size = size,
            relativePath = relativePath,
        )
        if (dao.getDocumentFingerprint(documentId) == fingerprint) {
            return false
        }

        val preview = documentTextExtractor.readPreview(uri, resolvedMimeType)
        val indexedAt = System.currentTimeMillis()
        val catalogRecord = DocumentCatalogRecord(
            documentId = documentId,
            uri = uri.toString(),
            name = resolvedName,
            mimeType = resolvedMimeType,
            size = size,
            modifiedAt = normalizedModified,
            relativePath = relativePath,
            accessMode = accessMode,
            fingerprint = fingerprint,
            preview = preview,
            indexedAt = indexedAt,
        )
        val text = buildDocumentIndexText(catalogRecord)
        val embedding = embedManager.embed(text)
        if (embedding.isEmpty()) {
            return false
        }

        dao.upsertDocument(catalogRecord)
        return dao.insert(
            VectorRecord(
                id = 0,
                source = SOURCE_DOCUMENT,
                sourceId = documentId,
                text = text,
                embedding = embedding,
                uri = uri.toString(),
                timestamp = normalizedModified,
                metadata = "documentId=$documentId;mimeType=${resolvedMimeType.orEmpty()};size=$size;relativePath=${relativePath.orEmpty()};accessMode=$accessMode;fingerprint=$fingerprint",
            ),
        ) > 0
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

    private fun buildDocumentIndexText(record: DocumentCatalogRecord): String =
        listOf(
            "${formatDate(record.modifiedAt)} document file ${record.name}",
            "documentId=${record.documentId}",
            "mimeType=${record.mimeType.orEmpty()}",
            "path=${record.relativePath.orEmpty()}",
            "uri=${record.uri}",
            "preview=${record.preview}",
        )
            .joinToString(separator = "\n")
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun buildDocumentFingerprint(
        name: String,
        modified: Long,
        mimeType: String?,
        size: Long,
        relativePath: String?,
    ): String =
        "$name|${mimeType.orEmpty()}|$size|$modified|${relativePath.orEmpty()}".stableDocumentHash()

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
        if (getDocumentFolderUris().isNotEmpty()) {
            true
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
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

    private fun buildDocumentSelection(): String {
        val mimeSelection = DOCUMENT_MIME_TYPES.joinToString(
            prefix = "${MediaStore.Files.FileColumns.MIME_TYPE} IN (",
            postfix = ")",
            separator = ",",
        ) { "?" }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return mimeSelection
        }
        return "$mimeSelection AND (${MediaStore.Files.FileColumns.RELATIVE_PATH} LIKE ? OR ${MediaStore.Files.FileColumns.RELATIVE_PATH} LIKE ?)"
    }

    private fun buildDocumentSelectionArgs(): Array<String> =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            DOCUMENT_MIME_TYPES
        } else {
            DOCUMENT_MIME_TYPES + arrayOf("Download/%", "Documents/%")
        }

    private fun isDocumentMimeType(
        mimeType: String?,
        name: String?,
    ): Boolean {
        val normalizedMime = mimeType?.lowercase(Locale.US)
        if (normalizedMime in DOCUMENT_MIME_TYPES) {
            return true
        }

        val normalizedName = name.orEmpty().lowercase(Locale.US)
        return DOCUMENT_EXTENSIONS.any { extension -> normalizedName.endsWith(extension) }
    }

    private fun getDocumentFolderUris(): Set<String> =
        preferences.getStringSet(DOCUMENT_FOLDER_URIS_KEY, emptySet()).orEmpty()

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
        private const val PREFS_NAME = "open_edge_ai_indexing"
        private const val DEFAULT_SOURCE_ENABLED = false
        private const val DOCUMENT_FOLDER_URIS_KEY = "document_folder_uris"
        private const val DOCUMENT_ACCESS_MEDIASTORE = "mediastore"
        private const val DOCUMENT_ACCESS_SAF = "saf"
        private const val MAX_SAF_DOCUMENTS_PER_RUN = 500
        private const val MAX_SAF_DEPTH = 12
        private const val DOCUMENT_EXCERPT_CACHE_TTL_MILLIS = 14L * 24 * 60 * 60 * 1000 // 14 days
        private const val TEXT_EMBEDDING_MODEL_MISSING =
            "Text embedding model is missing. Add universal_sentence_encoder.tflite to android/app/src/main/assets/models."
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
        private val DOCUMENT_EXTENSIONS = arrayOf(
            ".pdf",
            ".txt",
            ".csv",
            ".md",
            ".markdown",
            ".json",
            ".doc",
            ".docx",
            ".xls",
            ".xlsx",
            ".ppt",
            ".pptx",
        )
    }
}

private fun String.stableDocumentHash(): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(toByteArray(Charsets.UTF_8))
    return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }.take(32)
}
