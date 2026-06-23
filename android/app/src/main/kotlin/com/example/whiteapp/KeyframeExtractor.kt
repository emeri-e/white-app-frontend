package com.example.whiteapp

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.util.Log
import java.io.File
import java.io.FileOutputStream

object KeyframeExtractor {

    /**
     * Extracts keyframes from a video buffer (e.g., MP4/TS segment) using
     * hardware-accelerated MediaMetadataRetriever.
     */
    fun extractKeyframes(context: Context, videoBytes: ByteArray, maxFrames: Int = 3): List<Bitmap> {
        val bitmaps = mutableListOf<Bitmap>()
        var tempFile: File? = null

        try {
            // Write bytes to a secure temp cache file
            tempFile = File.createTempFile("video_seg_", ".tmp", context.cacheDir)
            FileOutputStream(tempFile).use { fos ->
                fos.write(videoBytes)
            }

            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(tempFile.absolutePath)
                
                // Get video duration in milliseconds
                val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                val durationMs = durationStr?.toLongOrNull() ?: 4000L // default to 4s if missing
                
                // Extract frames at spaced intervals
                val intervalUs = (durationMs * 1000) / (maxFrames + 1)
                
                for (i in 1..maxFrames) {
                    val timeUs = i * intervalUs
                    val frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    if (frame != null) {
                        bitmaps.add(frame)
                    }
                }
            } catch (e: Exception) {
                Log.w("KeyframeExtractor", "Failed decoding segment metadata: ${e.message}")
            } finally {
                try {
                    retriever.release()
                } catch (e: Exception) {
                    // ignore
                }
            }
        } catch (e: Exception) {
            Log.e("KeyframeExtractor", "Error writing temp video file: ${e.message}")
        } finally {
            try {
                tempFile?.delete()
            } catch (e: Exception) {
                // ignore
            }
        }

        return bitmaps
    }
}
