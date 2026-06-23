package com.example.whiteapp

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import io.netty.buffer.Unpooled
import io.netty.handler.codec.http.*
import org.littleshoot.proxy.HttpFiltersAdapter
import org.littleshoot.proxy.HttpFiltersSourceAdapter
import java.nio.charset.StandardCharsets

class ImageScanFilter(
    private val context: Context,
    originalRequest: HttpRequest
) : HttpFiltersAdapter(originalRequest) {

    companion object {
        private const val TAG = "ImageScanFilter"
        private const val MAX_RESOURCE_SIZE = 4 * 1024 * 1024 // 4MB buffer to handle HTML and image responses

        // Base64 of a 1x1 white pixel PNG
        private val WHITE_PNG_BYTES by lazy {
            Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=", Base64.NO_WRAP)
        }

        // Regex to match inline base64 data URIs for images (e.g. data:image/png;base64,...)
        // Uses a non-greedy, non-backtracking character class [^"'\s<>]* to prevent CPU hangs on large HTML inputs
        private val DATA_URI_REGEX = Regex("""data:image/[a-zA-Z0-9.\-+]+;base64,[^"'\s<>]*""")
        private const val BLANK_WHITE_DATA_URI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="

        fun createSource(context: Context): HttpFiltersSourceAdapter {
            return object : HttpFiltersSourceAdapter() {
                override fun filterRequest(originalRequest: HttpRequest): HttpFiltersAdapter {
                    return ImageScanFilter(context, originalRequest)
                }

                override fun getMaximumResponseBufferSizeInBytes(): Int {
                    return MAX_RESOURCE_SIZE
                }
            }
        }
    }

    override fun serverToProxyResponse(httpObject: HttpObject): HttpObject {
        if (httpObject is FullHttpResponse) {
            val status = httpObject.status()
            if (status.code() == 200) {
                val contentType = httpObject.headers().get("Content-Type") ?: ""
                val url = originalRequest?.uri ?: ""

                // 1. Intercept and scan Video streams/files using VideoInterceptor (AI keyframe classifier)
                if (isVideo(contentType, url)) {
                    val contentBuf = httpObject.content()
                    val readableBytes = contentBuf.readableBytes()
                    if (readableBytes > 0) {
                        try {
                            val bytes = ByteArray(readableBytes)
                            contentBuf.getBytes(contentBuf.readerIndex(), bytes)

                            val shouldBlock = VideoInterceptor.shouldBlockVideo(
                                context = context,
                                videoBytes = bytes,
                                contentType = contentType,
                                domain = "",
                                url = url
                            )

                            if (shouldBlock) {
                                Log.w(TAG, "🎥 BLOCKED EXPLICIT VIDEO STREAM/FILE: $url")
                                httpObject.setStatus(HttpResponseStatus.FORBIDDEN)
                                httpObject.content().clear()
                                HttpUtil.setContentLength(httpObject, 0)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error filtering video stream response: ${e.message}", e)
                        }
                    }
                    return httpObject
                }

                // 2. Intercept and scan standard Image files using ScreenAnalyzer (AI classifier)
                if (isImage(contentType, url)) {
                    val contentBuf = httpObject.content()
                    val readableBytes = contentBuf.readableBytes()
                    if (readableBytes > 0) {
                        try {
                            // Safely read the image bytes
                            val bytes = ByteArray(readableBytes)
                            contentBuf.getBytes(contentBuf.readerIndex(), bytes)

                            // Decode bitmap
                            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            if (bitmap != null) {
                                // Increment scanned count telemetry
                                incrementScanTelemetry()

                                // Run NudeNet classifier from ScreenAnalyzer
                                val detections = ScreenAnalyzer.classifyBitmap(context, bitmap)
                                
                                var shouldBlock = false
                                var maxConfidence = 0.0f
                                var triggeringLabel = ""

                                for (detection in detections) {
                                    val label = detection.label.uppercase()
                                    val conf = detection.confidence

                                    // Match sensitivity configs and direct triggers
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
                                    
                                    // Log event
                                    BlockEventLogger.logEvent(
                                        context = context,
                                        blockType = "ai_proxy",
                                        appName = "Web Browser / WebView",
                                        domain = "",
                                        url = url,
                                        classLabel = triggeringLabel,
                                        confidence = maxConfidence.toDouble()
                                    )

                                    // Replace response body with the white PNG bytes
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

                // 3. Intercept and redact inline Base64 data images in HTML, CSS, JS, JSON responses
                val isText = contentType.contains("html", ignoreCase = true) ||
                             contentType.contains("css", ignoreCase = true) ||
                             contentType.contains("javascript", ignoreCase = true) ||
                             contentType.contains("json", ignoreCase = true)

                if (isText) {
                    try {
                        val contentBuf = httpObject.content()
                        val readableBytes = contentBuf.readableBytes()
                        if (readableBytes > 0) {
                            val charset = HttpUtil.getCharset(httpObject, StandardCharsets.UTF_8)
                            val originalBody = contentBuf.toString(charset)
                            
                            // Perform a single-pass regex replacement with an AI classifier MatchEvaluator
                            val modifiedBody = DATA_URI_REGEX.replace(originalBody) { matchResult ->
                                val fullMatch = matchResult.value
                                val parts = fullMatch.split(",").takeIf { it.size >= 2 } ?: return@replace fullMatch
                                val base64Data = parts[1].trim()
                                
                                // Skip tiny UI icons, buttons, spacers, and emojis (< 5KB) to conserve battery and CPU
                                if (base64Data.length < 5000) {
                                    return@replace fullMatch
                                }
                                
                                var shouldBlockInline = false
                                try {
                                    val imageBytes = Base64.decode(base64Data, Base64.DEFAULT)
                                    if (imageBytes.isNotEmpty()) {
                                        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                                        if (bitmap != null) {
                                            // Increment scanned count telemetry
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

    private fun isVideo(contentType: String, url: String): Boolean {
        if (contentType.startsWith("video/", ignoreCase = true)) return true
        if (contentType.equals("video/MP2T", ignoreCase = true)) return true
        if (contentType.equals("video/iso.segment", ignoreCase = true)) return true
        if (contentType.equals("application/x-mpegURL", ignoreCase = true)) return true
        if (contentType.equals("application/vnd.apple.mpegurl", ignoreCase = true)) return true
        if (contentType.equals("application/dash+xml", ignoreCase = true)) return true
        
        val cleanUrl = url.split("?").first().lowercase()
        return cleanUrl.endsWith(".mp4") ||
               cleanUrl.endsWith(".webm") ||
               cleanUrl.endsWith(".mkv") ||
               cleanUrl.endsWith(".mov") ||
               cleanUrl.endsWith(".avi") ||
               cleanUrl.endsWith(".m3u8") ||
               cleanUrl.endsWith(".mpd") ||
               cleanUrl.endsWith(".ts")
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
}
