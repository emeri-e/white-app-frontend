package com.example.whiteapp

import android.content.Context
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
        private const val MAX_RESOURCE_SIZE = 4 * 1024 * 1024 // 4MB buffer limit for HTML responses

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

                // 1. Intercept and block Video streams/files
                if (isVideo(contentType, url)) {
                    Log.w(TAG, "🎥 BLOCKED VIDEO STREAM/FILE: $url (Lightweight Mode)")
                    try {
                        httpObject.setStatus(HttpResponseStatus.FORBIDDEN)
                        httpObject.content().clear()
                        HttpUtil.setContentLength(httpObject, 0)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error blocking video response: ${e.message}", e)
                    }
                    return httpObject
                }

                // 2. Intercept and replace Image files with white PNG
                if (isImage(contentType, url)) {
                    Log.d(TAG, "📸 INTERCEPTED IMAGE: $url - replacing with white PNG (Lightweight Mode)")
                    try {
                        val newBuf = Unpooled.copiedBuffer(WHITE_PNG_BYTES)
                        httpObject.content().clear().writeBytes(newBuf)
                        httpObject.headers().set("Content-Type", "image/png")
                        HttpUtil.setContentLength(httpObject, WHITE_PNG_BYTES.size.toLong())
                    } catch (e: Exception) {
                        Log.e(TAG, "Error replacing image response: ${e.message}", e)
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
                            val modifiedBody = DATA_URI_REGEX.replace(originalBody, BLANK_WHITE_DATA_URI)
                            
                            if (modifiedBody != originalBody) {
                                Log.i(TAG, "✏️ REDACTED INLINE IMAGES inside text response: $url")
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
}
