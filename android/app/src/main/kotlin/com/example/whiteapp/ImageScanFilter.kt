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
import java.io.ByteArrayOutputStream

class ImageScanFilter(
    private val context: Context,
    originalRequest: HttpRequest
) : HttpFiltersAdapter(originalRequest) {

    companion object {
        private const val TAG = "ImageScanFilter"
        private const val MAX_IMAGE_SIZE = 2 * 1024 * 1024 // 2MB

        // Base64 of a 1x1 white pixel PNG
        private val WHITE_PNG_BYTES by lazy {
            Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=", Base64.NO_WRAP)
        }

        fun createSource(context: Context): HttpFiltersSourceAdapter {
            return object : HttpFiltersSourceAdapter() {
                override fun filterRequest(originalRequest: HttpRequest): HttpFiltersAdapter {
                    return ImageScanFilter(context, originalRequest)
                }

                override fun getMaximumResponseBufferSizeInBytes(): Int {
                    return MAX_IMAGE_SIZE
                }
            }
        }
    }

    override fun serverToProxyResponse(httpObject: HttpObject): HttpObject {
        if (httpObject is FullHttpResponse) {
            val status = httpObject.status()
            if (status.code() == 200) {
                val contentType = httpObject.headers().get("Content-Type") ?: ""
                if (contentType.startsWith("image/", ignoreCase = true)) {
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
                                    Log.w(TAG, "🔞 BLOCKED EXPLICIT IMAGE: $triggeringLabel with confidence ${"%.2f".format(maxConfidence)}")
                                    
                                    // Log event
                                    BlockEventLogger.logEvent(
                                        context = context,
                                        blockType = "ai_proxy",
                                        appName = "Web Browser / WebView",
                                        domain = "",
                                        url = originalRequest?.uri ?: "",
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
                }
            }
        }
        return httpObject
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
