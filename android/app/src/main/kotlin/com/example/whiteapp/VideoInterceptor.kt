package com.example.whiteapp

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

object VideoInterceptor {
    private val analysisSemaphore = Semaphore(1) // Max 1 concurrent video analysis to protect CPU
    private var classifier: NudeNetClassifier? = null

    @Synchronized
    private fun getClassifier(context: Context): NudeNetClassifier {
        if (classifier == null) {
            classifier = NudeNetClassifier(context.applicationContext)
        }
        return classifier!!
    }

    /**
     * Scans intercepted video stream packets (HLS/DASH segments or MP4 buffers).
     * Returns true if the video contains explicit content and should be blocked.
     */
    fun shouldBlockVideo(
        context: Context,
        videoBytes: ByteArray,
        contentType: String,
        domain: String,
        url: String
    ): Boolean {
        // Skip check if data-saver or high-traffic settings request optimization
        if (shouldSkipAnalysis(context)) {
            return false
        }

        // Failsafe: Try to acquire semaphore with timeout to prevent blocking thread pool
        val acquired = analysisSemaphore.tryAcquire(200, TimeUnit.MILLISECONDS)
        if (!acquired) {
            Log.i("VideoInterceptor", "Analysis busy, skipping segment check for performance")
            return false
        }

        var isExplicit = false
        try {
            // Run analysis with strict execution timeout of 2 seconds
            val task = java.util.concurrent.Callable {
                val keyframes = KeyframeExtractor.extractKeyframes(context, videoBytes)
                if (keyframes.isEmpty()) return@Callable false

                val nudenet = getClassifier(context)
                for (frame in keyframes) {
                    val detections = nudenet.classify(frame)
                    frame.recycle() // Clean up bitmap memory immediately

                    for (detection in detections) {
                        val label = detection.label.uppercase()
                        val conf = detection.confidence

                        // Sensitivity thresholds matching DB/Dart
                        val threshold = when (label) {
                            "GENITALIA_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "ANUS_EXPOSED" -> 0.65f
                            "FEMALE_BREAST_EXPOSED" -> 0.75f
                            "BUTTOCKS_EXPOSED" -> 0.70f
                            else -> 0.85f
                        }

                        val isCompositeOnly = when (label) {
                            "GENITALIA_COVERED", "FEMALE_BREAST_COVERED", "BUTTOCKS_COVERED", "MALE_BREAST_EXPOSED", "BELLY_EXPOSED", "FEET_EXPOSED", "ARMPITS_EXPOSED" -> true
                            else -> false
                        }

                        if (!isCompositeOnly && conf >= threshold) {
                            Log.w("VideoInterceptor", "BLOCKED EXPLICIT VIDEO STREAM: $domain ($label at ${"%.2f".format(conf)})")
                            
                            // Log video block event
                            BlockEventLogger.logEvent(
                                context = context,
                                blockType = "ai_video",
                                appName = "NetworkVideoProxy",
                                domain = domain,
                                url = url,
                                classLabel = label,
                                confidence = conf.toDouble()
                            )
                            return@Callable true
                        }
                    }
                }
                false
            }

            val future = java.util.concurrent.Executors.newSingleThreadExecutor().submit(task)
            try {
                isExplicit = future.get(2000, TimeUnit.MILLISECONDS)
            } catch (e: TimeoutException) {
                Log.w("VideoInterceptor", "Video analysis timed out. Falling back to Screen-Track protection.")
                future.cancel(true)
            } catch (e: Exception) {
                Log.e("VideoInterceptor", "Error inside background video analyzer: ${e.message}")
            }
        } finally {
            analysisSemaphore.release()
        }

        return isExplicit
    }

    private fun shouldSkipAnalysis(context: Context): Boolean {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                if (cm.isActiveNetworkMetered && cm.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED) {
                    return true // skip to save data and battery
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }
}
