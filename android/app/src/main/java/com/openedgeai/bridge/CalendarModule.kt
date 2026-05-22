package com.openedgeai.bridge

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * Mirrors the iOS EventKit calendar sync. Writes Todo items to the system
 * calendar via CalendarContract so that scheduled todos appear in the device
 * calendar, matching the iOS NativeChatStoreTodo behaviour.
 *
 * NOTE: This module is written to match the existing native pattern but has not
 * been built/run on a device from this environment. Verify on-device.
 */
class CalendarModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    private val executor = Executors.newSingleThreadExecutor()

    override fun getName(): String = "CalendarSync"

    @ReactMethod
    fun isAvailable(promise: Promise) {
        promise.resolve(true)
    }

    @ReactMethod
    fun hasPermission(promise: Promise) {
        promise.resolve(hasCalendarPermission())
    }

    @ReactMethod
    fun upsertEvent(event: ReadableMap, promise: Promise) {
        executor.execute {
            try {
                if (!hasCalendarPermission()) {
                    promise.reject("calendar_permission", "Calendar read/write permission is not granted.")
                    return@execute
                }

                val title = event.getStringOrNull("title")?.takeIf { it.isNotBlank() }
                    ?: run {
                        promise.reject("calendar_invalid", "Event title is required.")
                        return@execute
                    }
                val startMs = event.getLongOrNull("startMs")
                    ?: run {
                        promise.reject("calendar_invalid", "Event startMs is required.")
                        return@execute
                    }
                val endMs = event.getLongOrNull("endMs") ?: (startMs + DEFAULT_DURATION_MS)
                val notes = event.getStringOrNull("notes").orEmpty()
                val existingId = event.getStringOrNull("eventId")?.toLongOrNull()

                val values = ContentValues().apply {
                    put(CalendarContract.Events.TITLE, title)
                    put(CalendarContract.Events.DESCRIPTION, notes)
                    put(CalendarContract.Events.DTSTART, startMs)
                    put(CalendarContract.Events.DTEND, endMs)
                    put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                }

                val resolver = reactContext.contentResolver

                if (existingId != null) {
                    val updateUri = ContentUris.withAppendedId(
                        CalendarContract.Events.CONTENT_URI,
                        existingId,
                    )
                    val updated = resolver.update(updateUri, values, null, null)
                    if (updated > 0) {
                        promise.resolve(existingId.toString())
                        return@execute
                    }
                }

                val calendarId = writableCalendarId()
                    ?: run {
                        promise.reject("calendar_unavailable", "No writable calendar found.")
                        return@execute
                    }
                values.put(CalendarContract.Events.CALENDAR_ID, calendarId)
                val insertUri = resolver.insert(CalendarContract.Events.CONTENT_URI, values)
                val newId = insertUri?.lastPathSegment
                if (newId == null) {
                    promise.reject("calendar_insert_failed", "Failed to insert calendar event.")
                } else {
                    promise.resolve(newId)
                }
            } catch (error: Exception) {
                promise.reject("calendar_error", error.message, error)
            }
        }
    }

    @ReactMethod
    fun deleteEvent(eventId: String, promise: Promise) {
        executor.execute {
            try {
                if (!hasCalendarPermission()) {
                    promise.reject("calendar_permission", "Calendar read/write permission is not granted.")
                    return@execute
                }
                val id = eventId.toLongOrNull()
                    ?: run {
                        promise.resolve(false)
                        return@execute
                    }
                val deleteUri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id)
                val deleted = reactContext.contentResolver.delete(deleteUri, null, null)
                promise.resolve(deleted > 0)
            } catch (error: Exception) {
                promise.reject("calendar_error", error.message, error)
            }
        }
    }

    private fun hasCalendarPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            reactContext,
            Manifest.permission.READ_CALENDAR,
        ) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(
                reactContext,
                Manifest.permission.WRITE_CALENDAR,
            ) == PackageManager.PERMISSION_GRANTED

    private fun writableCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.IS_PRIMARY,
        )
        reactContext.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            null,
            null,
            null,
        )?.use { cursor ->
            var fallback: Long? = null
            val idIndex = cursor.getColumnIndex(CalendarContract.Calendars._ID)
            val accessIndex = cursor.getColumnIndex(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
            val primaryIndex = cursor.getColumnIndex(CalendarContract.Calendars.IS_PRIMARY)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIndex)
                val access = if (accessIndex >= 0) cursor.getInt(accessIndex) else 0
                val isPrimary = primaryIndex >= 0 && cursor.getInt(primaryIndex) == 1
                if (access >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR) {
                    if (isPrimary) {
                        return id
                    }
                    if (fallback == null) {
                        fallback = id
                    }
                }
            }
            return fallback
        }
        return null
    }

    private fun ReadableMap.getStringOrNull(key: String): String? =
        if (hasKey(key) && !isNull(key)) getString(key) else null

    private fun ReadableMap.getLongOrNull(key: String): Long? =
        if (hasKey(key) && !isNull(key)) getDouble(key).toLong() else null

    companion object {
        private const val DEFAULT_DURATION_MS = 60L * 60L * 1000L
    }
}
