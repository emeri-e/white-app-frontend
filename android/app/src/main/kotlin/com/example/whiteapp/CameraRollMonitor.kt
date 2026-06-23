package com.example.whiteapp

import android.content.Context
import android.database.ContentObserver
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import java.io.InputStream

object CameraRollMonitor {
    private var contentObserver: ContentObserver? = null
    private var isMonitoring = false
    private var lastScannedUri: String? = null

    fun startMonitoring(context: Context) {
        if (isMonitoring) return
        isMonitoring = true
        Log.i("CameraRollMonitor", "Starting Camera Roll content monitoring...")

        // Persist setting
        context.getSharedPreferences("camera_roll_monitor_prefs", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("enabled", true)
            .apply()

        val handler = Handler(Looper.getMainLooper())
        contentObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                if (uri != null) {
                    // MediaStore Uri can trigger multiple times, debounce same item
                    if (uri.toString() == lastScannedUri) return
                    lastScannedUri = uri.toString()
                    
                    scanImageUri(context, uri)
                } else {
                    // Fallback: Query latest image in background thread
                    Thread {
                        queryLatestImage(context)
                    }.start()
                }
            }
        }

        context.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            contentObserver!!
        )
    }

    fun stopMonitoring(context: Context) {
        if (!isMonitoring) return
        isMonitoring = false
        contentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
        contentObserver = null
        Log.i("CameraRollMonitor", "Camera Roll content monitoring stopped.")

        // Persist setting
        context.getSharedPreferences("camera_roll_monitor_prefs", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("enabled", false)
            .apply()
    }

    fun isCurrentlyMonitoring(): Boolean = isMonitoring

    fun restoreMonitoringState(context: Context) {
        val prefs = context.getSharedPreferences("camera_roll_monitor_prefs", Context.MODE_PRIVATE)
        val shouldEnable = prefs.getBoolean("enabled", false)
        if (shouldEnable) {
            Log.i("CameraRollMonitor", "Restoring active camera roll monitoring after boot/service startup.")
            startMonitoring(context)
        }
    }

    private fun queryLatestImage(context: Context) {
        val projection = arrayOf(
            MediaStore.Images.ImageColumns._ID,
            MediaStore.Images.ImageColumns.DATA,
            MediaStore.Images.ImageColumns.DATE_ADDED
        )
        val cursor = context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Images.ImageColumns.DATE_ADDED} DESC LIMIT 1"
        )

        cursor?.use {
            if (it.moveToFirst()) {
                val idIndex = it.getColumnIndexOrThrow(MediaStore.Images.ImageColumns._ID)
                val id = it.getLong(idIndex)
                val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
                
                if (uri.toString() != lastScannedUri) {
                    lastScannedUri = uri.toString()
                    scanImageUri(context, uri)
                }
            }
        }
    }

    private fun scanImageUri(context: Context, uri: Uri) {
        Thread {
            try {
                // Read image from stream
                val inputStream: InputStream? = context.contentResolver.openInputStream(uri)
                if (inputStream == null) {
                    Log.w("CameraRollMonitor", "Unable to open input stream for Uri: $uri")
                    return@Thread
                }

                // Parse image dimensions and size
                val options = BitmapFactory.Options().apply {
                    inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
                }
                val bitmap = BitmapFactory.decodeStream(inputStream, null, options)
                inputStream.close()

                if (bitmap == null) {
                    Log.w("CameraRollMonitor", "Decoded bitmap was null for Uri: $uri")
                    return@Thread
                }

                val classifier = NudeNetClassifier(context)
                val detections = classifier.classify(bitmap)
                bitmap.recycle() // free native memory immediately

                if (detections.isEmpty()) {
                    return@Thread
                }

                var shouldBlock = false
                var triggeringLabel = ""
                var maxConfidence = 0.0f

                for (detection in detections) {
                    val label = detection.label.uppercase()
                    val conf = detection.confidence

                    val threshold = when (label) {
                        "GENITALIA_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "ANUS_EXPOSED" -> 0.65f
                        "FEMALE_BREAST_EXPOSED" -> 0.75f
                        "BUTTOCKS_EXPOSED" -> 0.70f
                        else -> 0.85f
                    }

                    if (conf >= threshold) {
                        shouldBlock = true
                        if (conf > maxConfidence) {
                            maxConfidence = conf
                            triggeringLabel = label
                        }
                    }
                }

                if (shouldBlock) {
                    Log.w("CameraRollMonitor", "EXPLICIT PHOTO DETECTED IN CAMERA ROLL: $uri ($triggeringLabel)")

                    // Log block event
                    BlockEventLogger.logEvent(
                        context = context,
                        blockType = "camera_roll",
                        appName = "CameraRoll",
                        domain = uri.lastPathSegment ?: "unknown",
                        url = uri.toString(),
                        classLabel = triggeringLabel,
                        confidence = maxConfidence.toDouble()
                    )

                    // Execute media purging
                    purgeMediaFile(context, uri)
                }
            } catch (e: Exception) {
                Log.e("CameraRollMonitor", "Error scanning camera roll image: ${e.message}")
            }
        }.start()
    }

    private fun purgeMediaFile(context: Context, uri: Uri) {
        try {
            // Delete programmatically from MediaStore
            val rowsDeleted = context.contentResolver.delete(uri, null, null)
            if (rowsDeleted > 0) {
                Log.i("CameraRollMonitor", "Purged flagged explicit media from gallery: $uri")
            } else {
                Log.w("CameraRollMonitor", "ContentResolver delete returned 0 rows for: $uri")
            }
        } catch (e: Exception) {
            // On modern Android (Q+), deletes throw RecoverableSecurityExceptions unless permission is elevated,
            // so we log the event as standard accountability reporting.
            Log.e("CameraRollMonitor", "Programmatic media purge failed (expected on Q+ without security prompt): ${e.message}")
        }
    }
}
