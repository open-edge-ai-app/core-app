package com.onda.bridge

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.onda.core.QueryRouter

class AIEngineModule(
    reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    private val queryRouter = QueryRouter()

    override fun getName(): String = NAME

    @ReactMethod
    fun sendMessage(message: String, promise: Promise) {
        try {
            promise.resolve(queryRouter.route(message))
        } catch (error: Exception) {
            promise.reject("AI_ENGINE_ERROR", error)
        }
    }

    @ReactMethod
    fun getIndexingStatus(promise: Promise) {
        val status = Arguments.createMap().apply {
            putInt("indexedItems", 0)
            putBoolean("isIndexing", false)
        }
        promise.resolve(status)
    }

    companion object {
        const val NAME = "AIEngine"
    }
}
