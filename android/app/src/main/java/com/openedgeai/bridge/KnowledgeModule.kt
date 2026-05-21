package com.openedgeai.bridge

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

/**
 * Mirrors the iOS knowledge services: Vision OCR (recognizeText) and CoreLocation
 * device context (getLocation). OCR uses ML Kit on-device text recognition; the
 * location context uses the built-in LocationManager (no Play Services dependency).
 *
 * NOTE: Written to match the iOS feature set but not built/run from this
 * environment. The ML Kit text-recognition dependency must resolve; verify on-device.
 */
class KnowledgeModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "Knowledge"

    @ReactMethod
    fun recognizeText(uri: String, promise: Promise) {
        try {
            val image = InputImage.fromFilePath(reactContext, Uri.parse(uri))
            val recognizer = TextRecognition.getClient(
                KoreanTextRecognizerOptions.Builder().build(),
            )
            recognizer.process(image)
                .addOnSuccessListener { result ->
                    promise.resolve(result.text)
                    recognizer.close()
                }
                .addOnFailureListener { error ->
                    promise.reject("ocr_failed", error.message, error)
                    recognizer.close()
                }
        } catch (error: Exception) {
            promise.reject("ocr_error", error.message, error)
        }
    }

    @ReactMethod
    fun getLocation(promise: Promise) {
        if (!hasLocationPermission()) {
            promise.reject("location_permission", "Location permission is not granted.")
            return
        }

        try {
            val manager = reactContext.getSystemService(LocationManager::class.java)
            if (manager == null) {
                promise.reject("location_unavailable", "Location service is unavailable.")
                return
            }

            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER,
            )
            var best: Location? = null
            for (provider in providers) {
                if (!manager.isProviderEnabled(provider)) {
                    continue
                }
                val location = try {
                    manager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                }
                if (location != null && (best == null || location.time > best.time)) {
                    best = location
                }
            }

            if (best == null) {
                promise.reject("location_unavailable", "No cached device location available.")
                return
            }

            val payload = Arguments.createMap().apply {
                putDouble("latitude", best.latitude)
                putDouble("longitude", best.longitude)
                putDouble("accuracy", best.accuracy.toDouble())
                putDouble("timestamp", best.time.toDouble())
            }
            promise.resolve(payload)
        } catch (error: Exception) {
            promise.reject("location_error", error.message, error)
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            reactContext,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            reactContext,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }
}
