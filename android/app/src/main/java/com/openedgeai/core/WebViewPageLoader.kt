package com.openedgeai.core

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONArray
import org.json.JSONObject

internal data class RenderedWebPage(
    val title: String,
    val url: String,
    val text: String,
)

internal class WebViewPageLoader(
    context: Context,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())

    fun load(url: String): RenderedWebPage? {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return null
        }
        if (!isHttpUrl(url)) {
            return null
        }

        val acquired = runCatching {
            renderSlots.tryAcquire(WEBVIEW_QUEUE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }.getOrDefault(false)
        if (!acquired) {
            return null
        }

        return try {
            loadWithWebView(url)
        } finally {
            renderSlots.release()
        }
    }

    private fun loadWithWebView(url: String): RenderedWebPage? {
        val result = AtomicReference<RenderedWebPage?>()
        val webViewRef = AtomicReference<WebView?>()
        val completed = AtomicBoolean(false)
        val extracting = AtomicBoolean(false)
        val attempts = AtomicInteger(0)
        val startedAt = SystemClock.elapsedRealtime()
        val latch = CountDownLatch(1)

        fun complete(page: RenderedWebPage?) {
            if (!completed.compareAndSet(false, true)) {
                return
            }
            result.set(page?.takeIf { it.text.isNotBlank() })
            val webView = webViewRef.getAndSet(null)
            if (Looper.myLooper() == Looper.getMainLooper()) {
                destroyWebView(webView)
            } else {
                mainHandler.post { destroyWebView(webView) }
            }
            latch.countDown()
        }

        fun scheduleExtraction(delayMs: Long) {
            mainHandler.postDelayed(
                {
                    val webView = webViewRef.get()
                    if (completed.get() || webView == null || !extracting.compareAndSet(false, true)) {
                        return@postDelayed
                    }

                    extractRenderedPage(webView) { page ->
                        extracting.set(false)
                        val elapsedMs = SystemClock.elapsedRealtime() - startedAt
                        val attempt = attempts.incrementAndGet()
                        val hasUsefulText = page != null && page.text.length >= MIN_RENDERED_TEXT_CHARS
                        val hasFallbackText = page != null &&
                            page.text.isNotBlank() &&
                            elapsedMs >= MIN_RENDER_WAIT_MS

                        when {
                            hasUsefulText || hasFallbackText || attempt >= MAX_EXTRACTION_ATTEMPTS -> {
                                complete(page)
                            }
                            elapsedMs >= WEBVIEW_TOTAL_TIMEOUT_MS -> {
                                complete(page)
                            }
                            else -> {
                                scheduleExtraction(EXTRACTION_RETRY_DELAY_MS)
                            }
                        }
                    }
                },
                delayMs,
            )
        }

        mainHandler.post {
            val webView = WebView(appContext)
            webViewRef.set(webView)
            configureWebView(webView)

            webView.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView,
                    request: WebResourceRequest,
                ): Boolean = !isHttpUri(request.url)

                @Suppress("OVERRIDE_DEPRECATION")
                override fun shouldOverrideUrlLoading(
                    view: WebView,
                    url: String,
                ): Boolean = !isHttpUrl(url)

                override fun onPageFinished(view: WebView, finishedUrl: String) {
                    scheduleExtraction(POST_FINISH_EXTRACTION_DELAY_MS)
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    if (request.isForMainFrame) {
                        complete(null)
                    }
                }

                override fun onReceivedHttpError(
                    view: WebView,
                    request: WebResourceRequest,
                    errorResponse: WebResourceResponse,
                ) {
                    if (request.isForMainFrame && errorResponse.statusCode >= 400) {
                        complete(null)
                    }
                }
            }
            webView.webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView, newProgress: Int) {
                    if (newProgress >= 100) {
                        scheduleExtraction(PROGRESS_EXTRACTION_DELAY_MS)
                    }
                }
            }

            scheduleExtraction(INITIAL_EXTRACTION_DELAY_MS)
            webView.loadUrl(url)
        }

        val finished = runCatching {
            latch.await(WEBVIEW_TOTAL_TIMEOUT_MS + WEBVIEW_LATCH_GRACE_MS, TimeUnit.MILLISECONDS)
        }.getOrElse { error ->
            if (error is InterruptedException) {
                Thread.currentThread().interrupt()
            }
            false
        }
        if (!finished) {
            mainHandler.post { complete(null) }
        }
        return result.get()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebView(webView: WebView) {
        webView.setBackgroundColor(Color.TRANSPARENT)
        webView.layout(0, 0, WEBVIEW_WIDTH_PX, WEBVIEW_HEIGHT_PX)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            loadsImagesAutomatically = false
            blockNetworkImage = true
            cacheMode = WebSettings.LOAD_NO_CACHE
            mediaPlaybackRequiresUserGesture = true
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            allowFileAccess = false
            allowContentAccess = false
            userAgentString = USER_AGENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            CookieManager.getInstance().setAcceptThirdPartyCookies(webView, false)
        }
    }

    private fun extractRenderedPage(
        webView: WebView,
        callback: (RenderedWebPage?) -> Unit,
    ) {
        webView.evaluateJavascript(EXTRACT_PAGE_SCRIPT) { rawResult ->
            callback(parseRenderedPage(rawResult))
        }
    }

    private fun parseRenderedPage(rawResult: String?): RenderedWebPage? {
        val decoded = rawResult.decodeEvaluateJavascriptString() ?: return null
        return runCatching {
            val json = JSONObject(decoded)
            val text = json.optString("text").cleanRenderedText()
            if (text.isBlank()) {
                null
            } else {
                RenderedWebPage(
                    title = json.optString("title").replace(Regex("\\s+"), " ").trim(),
                    url = json.optString("url").trim(),
                    text = text,
                )
            }
        }.getOrNull()
    }

    private fun destroyWebView(webView: WebView?) {
        if (webView == null) {
            return
        }
        runCatching { webView.stopLoading() }
        webView.webChromeClient = null
        webView.webViewClient = WebViewClient()
        runCatching { webView.loadUrl("about:blank") }
        runCatching { webView.removeAllViews() }
        runCatching { webView.destroy() }
    }

    private fun isHttpUri(uri: Uri?): Boolean {
        val scheme = uri?.scheme ?: return false
        return scheme.equals("http", ignoreCase = true) ||
            scheme.equals("https", ignoreCase = true)
    }

    private fun isHttpUrl(url: String): Boolean =
        url.startsWith("http://", ignoreCase = true) ||
            url.startsWith("https://", ignoreCase = true)

    companion object {
        private val renderSlots = Semaphore(2, true)

        private const val WEBVIEW_TOTAL_TIMEOUT_MS = 12_000L
        private const val WEBVIEW_QUEUE_TIMEOUT_MS = 2_000L
        private const val WEBVIEW_LATCH_GRACE_MS = 500L
        private const val MIN_RENDER_WAIT_MS = 2_500L
        private const val INITIAL_EXTRACTION_DELAY_MS = 2_000L
        private const val POST_FINISH_EXTRACTION_DELAY_MS = 900L
        private const val PROGRESS_EXTRACTION_DELAY_MS = 700L
        private const val EXTRACTION_RETRY_DELAY_MS = 900L
        private const val MAX_EXTRACTION_ATTEMPTS = 6
        private const val MIN_RENDERED_TEXT_CHARS = 700
        private const val WEBVIEW_WIDTH_PX = 1080
        private const val WEBVIEW_HEIGHT_PX = 1920
        private const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 OpenEdgeAI/1.0"
        private val EXTRACT_PAGE_SCRIPT = """
            (function() {
              var root = document.body || document.documentElement;
              var text = root ? (root.innerText || root.textContent || "") : "";
              if (text.length > 50000) {
                text = text.slice(0, 50000);
              }
              return JSON.stringify({
                title: document.title || "",
                url: location.href || "",
                text: text
              });
            })();
        """.trimIndent()
    }
}

private fun String?.decodeEvaluateJavascriptString(): String? {
    val trimmed = this?.trim()
    if (trimmed.isNullOrBlank() || trimmed == "null") {
        return null
    }
    return runCatching { JSONArray("[$trimmed]").getString(0) }.getOrNull()
        ?: trimmed.trim('"')
}

private fun String.cleanRenderedText(): String =
    replace(Regex("""[\u0000-\u0008\u000B\u000C\u000E-\u001F]+"""), " ")
        .replace(Regex("""[ \t\r]+"""), " ")
        .replace(Regex("""\n\s+"""), "\n")
        .replace(Regex("""\n{3,}"""), "\n\n")
        .trim()
