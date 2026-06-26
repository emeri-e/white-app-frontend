package com.example.whiteapp

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import io.netty.buffer.Unpooled
import io.netty.channel.ChannelHandlerContext
import io.netty.handler.codec.http.*
import org.littleshoot.proxy.HttpFiltersAdapter
import org.littleshoot.proxy.HttpFiltersSourceAdapter
import java.nio.charset.StandardCharsets

class ImageScanFilter(
    private val context: Context,
    originalRequest: HttpRequest,
    ctx: ChannelHandlerContext
) : HttpFiltersAdapter(originalRequest, ctx) {

    companion object {
        private const val TAG = "ImageScanFilter"
        private const val MAX_RESOURCE_SIZE = 4 * 1024 * 1024 // 4MB buffer to handle HTML and image responses

        // Base64 of a 1x1 white pixel PNG
        private val WHITE_PNG_BYTES by lazy {
            Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=", Base64.NO_WRAP)
        }

        // Regex to match inline base64 data URIs for images (e.g. data:image/png;base64,...)
        private val DATA_URI_REGEX = Regex("""data:image/[a-zA-Z0-9.\-+]+;base64,[^"'\s<>]*""")
        private const val BLANK_WHITE_DATA_URI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="

        fun createSource(context: Context): HttpFiltersSourceAdapter {
            return object : HttpFiltersSourceAdapter() {
                override fun filterRequest(originalRequest: HttpRequest, ctx: ChannelHandlerContext): HttpFiltersAdapter {
                    return ImageScanFilter(context, originalRequest, ctx)
                }

                override fun getMaximumResponseBufferSizeInBytes(): Int {
                    return MAX_RESOURCE_SIZE
                }
            }
        }
    }

    override fun serverToProxyResponse(httpObject: HttpObject): HttpObject {
        if (httpObject is HttpResponse) {
            httpObject.headers().remove("Alt-Svc")
        }
        if (httpObject is FullHttpResponse) {
            val status = httpObject.status()
            if (status.code() == 200) {
                val contentType = httpObject.headers().get("Content-Type") ?: ""
                val url = originalRequest?.uri ?: ""

                // 1. Intercept and scan standard Image files using ScreenAnalyzer (AI classifier)
                if (isImage(contentType, url)) {
                    val contentBuf = httpObject.content()
                    val readableBytes = contentBuf.readableBytes()
                    if (readableBytes > 0) {
                        try {
                            val bytes = ByteArray(readableBytes)
                            contentBuf.getBytes(contentBuf.readerIndex(), bytes)

                            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            if (bitmap != null) {
                                incrementScanTelemetry()
                                val detections = ScreenAnalyzer.classifyBitmap(context, bitmap)
                                var shouldBlock = false
                                var maxConfidence = 0.0f
                                var triggeringLabel = ""

                                for (detection in detections) {
                                    val label = detection.label.uppercase()
                                    val conf = detection.confidence
                                    val threshold = when (label) {
                                        "GENITALIA_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "ANUS_EXPOSED" -> 0.35f
                                        "FEMALE_BREAST_EXPOSED" -> 0.45f
                                        "BUTTOCKS_EXPOSED" -> 0.40f
                                        else -> 0.50f
                                    }
                                    val isCompositeOnly = when (label) {
                                        "GENITALIA_COVERED", "FEMALE_BREAST_COVERED", "BUTTOCKS_COVERED", "MALE_BREAST_EXPOSED", "BELLY_EXPOSED", "FEET_EXPOSED", "ARMPITS_EXPOSED" -> true
                                        else -> false
                                    }
                                    if (conf >= threshold && !isCompositeOnly) {
                                        shouldBlock = true
                                        if (conf > maxConfidence) {
                                            maxConfidence = conf
                                            triggeringLabel = label
                                        }
                                    }
                                }

                                if (shouldBlock) {
                                    Log.w(TAG, "🔞 BLOCKED EXPLICIT IMAGE: $triggeringLabel with confidence ${"%.2f".format(maxConfidence)} - URL: $url")
                                    BlockEventLogger.logEvent(
                                        context = context,
                                        blockType = "ai_proxy",
                                        appName = "Web Browser / WebView",
                                        domain = "",
                                        url = url,
                                        classLabel = triggeringLabel,
                                        confidence = maxConfidence.toDouble()
                                    )
                                    val newBuf = Unpooled.copiedBuffer(WHITE_PNG_BYTES)
                                    httpObject.content().clear().writeBytes(newBuf)
                                    httpObject.headers().set("Content-Type", "image/png")
                                    HttpUtil.setContentLength(httpObject, WHITE_PNG_BYTES.size.toLong())
                                }
                                bitmap.recycle()
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error filtering image response: ${e.message}", e)
                        }
                    }
                    return httpObject
                }

                // 2. Intercept and redact inline Base64 data images in HTML, CSS, JS, JSON responses
                if (isText(contentType)) {
                    try {
                        val contentBuf = httpObject.content()
                        val readableBytes = contentBuf.readableBytes()
                        if (readableBytes > 0) {
                            val charset = HttpUtil.getCharset(httpObject, StandardCharsets.UTF_8)
                            val originalBody = contentBuf.toString(charset)
                            
                            val modifiedBody = DATA_URI_REGEX.replace(originalBody) { matchResult ->
                                val fullMatch = matchResult.value
                                val parts = fullMatch.split(",").takeIf { it.size >= 2 } ?: return@replace fullMatch
                                val base64Data = parts[1].trim()
                                if (base64Data.length < 5000) {
                                    return@replace fullMatch
                                }
                                
                                var shouldBlockInline = false
                                try {
                                    val imageBytes = Base64.decode(base64Data, Base64.DEFAULT)
                                    if (imageBytes.isNotEmpty()) {
                                        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                                        if (bitmap != null) {
                                            incrementScanTelemetry()
                                            val detections = ScreenAnalyzer.classifyBitmap(context, bitmap)
                                            bitmap.recycle()
                                            
                                            var triggeringLabel = ""
                                            var maxConfidence = 0.0f
                                            for (detection in detections) {
                                                val label = detection.label.uppercase()
                                                val conf = detection.confidence
                                                val threshold = when (label) {
                                                    "GENITALIA_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "ANUS_EXPOSED" -> 0.35f
                                                    "FEMALE_BREAST_EXPOSED" -> 0.45f
                                                    "BUTTOCKS_EXPOSED" -> 0.40f
                                                    else -> 0.50f
                                                }
                                                val isCompositeOnly = when (label) {
                                                    "GENITALIA_COVERED", "FEMALE_BREAST_COVERED", "BUTTOCKS_COVERED", "MALE_BREAST_EXPOSED", "BELLY_EXPOSED", "FEET_EXPOSED", "ARMPITS_EXPOSED" -> true
                                                    else -> false
                                                }
                                                if (conf >= threshold && !isCompositeOnly) {
                                                    shouldBlockInline = true
                                                    if (conf > maxConfidence) {
                                                        maxConfidence = conf
                                                        triggeringLabel = label
                                                    }
                                                }
                                            }
                                            if (shouldBlockInline) {
                                                Log.w(TAG, "🔞 REDACTED EXPLICIT INLINE BASE64 IMAGE: $triggeringLabel with confidence ${"%.2f".format(maxConfidence)}")
                                                BlockEventLogger.logEvent(
                                                    context = context,
                                                    blockType = "ai_inline",
                                                    appName = "Web Browser / WebView",
                                                    domain = "",
                                                    url = "Inline base64 image",
                                                    classLabel = triggeringLabel,
                                                    confidence = maxConfidence.toDouble()
                                                )
                                                return@replace BLANK_WHITE_DATA_URI
                                            }
                                        }
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error scanning inline base64 image: ${e.message}")
                                }
                                fullMatch
                            }
                            
                            if (modifiedBody != originalBody) {
                                Log.i(TAG, "✏️ REDACTED EXPLICIT INLINE IMAGES inside text response: $url")
                                val newBytes = modifiedBody.toByteArray(charset)
                                val newBuf = Unpooled.copiedBuffer(newBytes)
                                contentBuf.clear().writeBytes(newBuf)
                                HttpUtil.setContentLength(httpObject, newBytes.size.toLong())
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error redacting inline images in text response: ${e.message}", e)
                    }
                }
            }
        }
        return httpObject
    }

    private fun isText(contentType: String): Boolean {
        return contentType.contains("html", ignoreCase = true) ||
               contentType.contains("css", ignoreCase = true) ||
               contentType.contains("javascript", ignoreCase = true) ||
               contentType.contains("json", ignoreCase = true)
    }

    private fun isImage(contentType: String, url: String): Boolean {
        if (contentType.startsWith("image/", ignoreCase = true)) return true
        val cleanUrl = url.split("?").first().lowercase()
        return cleanUrl.endsWith(".png") ||
               cleanUrl.endsWith(".jpg") ||
               cleanUrl.endsWith(".jpeg") ||
               cleanUrl.endsWith(".gif") ||
               cleanUrl.endsWith(".webp") ||
               cleanUrl.endsWith(".svg")
    }

    private fun isWebOrImageRequest(request: HttpRequest): Boolean {
        val accept = request.headers().get("Accept") ?: ""
        if (accept.contains("text/html", ignoreCase = true)) return true
        if (accept.contains("image/", ignoreCase = true)) return true
        
        val url = request.uri ?: ""
        val cleanUrl = url.split("?").first().lowercase()
        return cleanUrl.endsWith(".html") ||
               cleanUrl.endsWith(".htm") ||
               cleanUrl.endsWith(".jpg") ||
               cleanUrl.endsWith(".jpeg") ||
               cleanUrl.endsWith(".png") ||
               cleanUrl.endsWith(".gif") ||
               cleanUrl.endsWith(".webp")
    }

    private fun incrementScanTelemetry() {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val currentScanned = try {
                prefs.getLong("flutter.telemetry_scanned_today", 0L)
            } catch (e: Exception) {
                prefs.getInt("flutter.telemetry_scanned_today", 0).toLong()
            }
            val currentAnalyzed = try {
                prefs.getLong("flutter.telemetry_screens_analyzed", 0L)
            } catch (e: Exception) {
                prefs.getInt("flutter.telemetry_screens_analyzed", 0).toLong()
            }
            prefs.edit().apply {
                putLong("flutter.telemetry_scanned_today", currentScanned + 1)
                putLong("flutter.telemetry_screens_analyzed", currentAnalyzed + 1)
                apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to increment telemetry: ${e.message}")
        }
    }

    override fun clientToProxyRequest(httpObject: HttpObject): HttpResponse? {
        if (httpObject is HttpRequest) {
            val uriStr = httpObject.uri ?: ""
            val host = httpObject.headers().get("Host")?.split(":")?.first()?.lowercase() ?: ""
            val accept = httpObject.headers().get("Accept") ?: ""

            // 1. If this is NOT a web page or image request, dynamically remove the response aggregator
            // and decompressor from the client channel pipeline to allow raw, ultra-fast streaming bypass!
            if (!isWebOrImageRequest(httpObject)) {
                try {
                    val pipeline = ctx?.pipeline()
                    if (pipeline != null) {
                        if (pipeline.get("aggregator") != null) {
                            pipeline.remove("aggregator")
                            Log.d(TAG, "🚀 Removed aggregator for non-web request: $uriStr")
                        }
                        if (pipeline.get("inflater") != null) {
                            pipeline.remove("inflater")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error dynamically removing pipeline handlers: ${e.message}")
                }
            } else {
                // Force identity encoding for images and HTML requests so they stream uncompressed
                httpObject.headers().set("Accept-Encoding", "identity")
            }

            if (host.isNotEmpty() && !host.contains("businessportal.site") && !host.contains("10.0.2.2")) {
                Log.d(TAG, "Incoming HTTP request: host=$host, uri=$uriStr")
            }

            // 1. Skip if it is our backend to avoid loops
            if (host.contains("businessportal.site") || uriStr.contains("businessportal.site") || host.contains("10.0.2.2") || uriStr.contains("10.0.2.2")) {
                return null
            }

            // 2. Check if the domain is blocked
            if (SafeDnsResolver.isDomainBlocked(host)) {
                Log.w(TAG, "Blocking domain request (MITM Redirect): $host")
                
                // Log block event
                BlockEventLogger.logEvent(
                    context = context,
                    blockType = "dns",
                    appName = "Web Browser",
                    domain = host,
                    url = uriStr,
                    classLabel = "DOMAIN_BLOCKED",
                    confidence = 1.0
                )

                val redirectUrl = "${getRedirectBaseUrl()}?type=dns&query=$host"
                return createRedirectResponse(redirectUrl)
            }

            // 3. Check if the URL contains search queries with blocked keywords
            val queryParams = getQueryParameters(uriStr)
            val searchKeys = listOf("q", "query", "p", "wd")
            for (key in searchKeys) {
                val searchQuery = queryParams[key]
                if (searchQuery != null && searchQuery.isNotEmpty()) {
                    if (SafeDnsResolver.isKeywordBlocked(searchQuery)) {
                        Log.w(TAG, "Blocking search keyword: '$searchQuery' under parameter '$key'")
                        
                        // Log block event
                        BlockEventLogger.logEvent(
                            context = context,
                            blockType = "keyword",
                            appName = "Web Browser",
                            domain = host,
                            url = uriStr,
                            classLabel = "KEYWORD_BLOCKED",
                            confidence = 1.0
                        )

                        val encodedQuery = java.net.URLEncoder.encode(searchQuery, "UTF-8")
                        val redirectUrl = "${getRedirectBaseUrl()}?type=keyword&query=$encodedQuery"
                        return createRedirectResponse(redirectUrl)
                    }
                }
            }
        }
        return null
    }

    private fun getRedirectBaseUrl(): String {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val savedBase = prefs.getString("flutter.api_base_url", "") ?: ""
            if (savedBase.isNotEmpty()) {
                val base = if (savedBase.endsWith("/api")) savedBase.substring(0, savedBase.length - 4) else savedBase
                return "$base/api/filtering/blocked/"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load redirect base URL from prefs: ${e.message}")
        }
        return "https://businessportal.site/api/filtering/blocked/"
    }

    private fun getQueryParameters(uriStr: String): Map<String, String> {
        val params = mutableMapOf<String, String>()
        try {
            val queryIndex = uriStr.indexOf('?')
            if (queryIndex != -1 && queryIndex < uriStr.length - 1) {
                val query = uriStr.substring(queryIndex + 1)
                val pairs = query.split("&")
                for (pair in pairs) {
                    val idx = pair.indexOf("=")
                    if (idx != -1) {
                        val key = java.net.URLDecoder.decode(pair.substring(0, idx), "UTF-8")
                        val value = java.net.URLDecoder.decode(pair.substring(idx + 1), "UTF-8")
                        params[key] = value
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse query params: ${e.message}")
        }
        return params
    }

    private fun createRedirectResponse(redirectUrl: String): HttpResponse {
        val response = DefaultFullHttpResponse(
            HttpVersion.HTTP_1_1,
            HttpResponseStatus.FOUND
        )
        response.headers().set(HttpHeaderNames.LOCATION, redirectUrl)
        response.headers().set(HttpHeaderNames.CONTENT_LENGTH, 0)
        response.headers().set(HttpHeaderNames.CONNECTION, HttpHeaderValues.CLOSE)
        return response
    }
}
