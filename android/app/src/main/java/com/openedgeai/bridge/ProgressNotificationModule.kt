package com.openedgeai.bridge

import android.app.NotificationManager
import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap

/**
 * Android analogue of the iOS Dynamic Island / Live Activity generation status.
 * Android has no Dynamic Island, so generation progress is surfaced as an ongoing
 * (non-dismissable) progress notification while the model is producing a response.
 *
 * NOTE: Written to match the iOS feature intent but not built/run from this
 * environment. POST_NOTIFICATIONS must be granted on Android 13+; verify on-device.
 */
class ProgressNotificationModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "ProgressNotification"

    @ReactMethod
    fun showProgress(options: ReadableMap, promise: Promise) {
        try {
            val id = options.getStringOrNull("id") ?: DEFAULT_ID
            val title = options.getStringOrNull("title") ?: "Open Edge AI"
            val text = options.getStringOrNull("text") ?: "응답 생성 중…"
            GenerationForegroundService.start(reactContext, title, text)
            promise.resolve(id)
        } catch (error: Exception) {
            promise.reject("notification_error", error.message, error)
        }
    }

    @ReactMethod
    fun hideProgress(id: String, promise: Promise) {
        try {
            notificationManager().cancel(id.hashCode())
            GenerationForegroundService.stop(reactContext)
            promise.resolve(true)
        } catch (error: Exception) {
            promise.reject("notification_error", error.message, error)
        }
    }

    private fun notificationManager(): NotificationManager =
        reactContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ReadableMap.getStringOrNull(key: String): String? =
        if (hasKey(key) && !isNull(key)) getString(key) else null

    companion object {
        private const val DEFAULT_ID = "ai-generation"
    }
}
