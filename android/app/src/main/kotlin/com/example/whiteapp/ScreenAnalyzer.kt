package com.example.whiteapp

import android.content.Context
import android.graphics.Bitmap
import android.util.Log

object ScreenAnalyzer {
    private var classifier: NudeNetClassifier? = null

    @Synchronized
    private fun getClassifier(context: Context): NudeNetClassifier {
        if (classifier == null) {
            classifier = NudeNetClassifier(context.applicationContext)
        }
        return classifier!!
    }

    fun classifyBitmap(context: Context, bitmap: Bitmap): List<NativeDetection> {
        return synchronized(this) {
            getClassifier(context).classify(bitmap)
        }
    }


    fun analyzeScreen(context: Context, screenshot: Bitmap, packageName: String): Boolean {
        try {
            // Increment telemetry counters in Flutter SharedPreferences
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
            } catch (te: Exception) {
                Log.e("ScreenAnalyzer", "Failed to update Flutter SharedPreferences telemetry: ${te.message}")
            }

            val nudenet = getClassifier(context)
            val detections = nudenet.classify(screenshot)

            Log.d("ScreenAnalyzer", "AI SCREEN SCAN RUNNING: App [$packageName] - Found ${detections.size} visual elements.")
            if (detections.isNotEmpty()) {
                val detectionSummary = detections.joinToString(", ") { "${it.label} (${"%.2f".format(it.confidence)})" }
                Log.i("ScreenAnalyzer", "   └─ Detections: $detectionSummary")
            }

            if (detections.isEmpty()) {
                return false
            }

            var shouldBlock = false
            var triggeringLabel = ""
            var maxConfidence = 0.0f

            for (detection in detections) {
                val label = detection.label.uppercase()
                val conf = detection.confidence

                // Matching sensitivity configs and direct triggers with lower thresholds
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

                if (conf >= threshold) {
                    if (!isCompositeOnly) {
                        shouldBlock = true
                        if (conf > maxConfidence) {
                            maxConfidence = conf
                            triggeringLabel = label
                        }
                        Log.i("ScreenAnalyzer", "   └─ [TRIGGER] $label: conf=${"%.2f".format(conf)} >= threshold=$threshold")
                    } else {
                        Log.d("ScreenAnalyzer", "   └─ [IGNORED-COMPOSITE] $label: conf=${"%.2f".format(conf)}")
                    }
                } else {
                    Log.d("ScreenAnalyzer", "   └─ [REJECTED-CONFIDENCE] $label: conf=${"%.2f".format(conf)} < threshold=$threshold")
                }
            }

            if (shouldBlock) {
                Log.w("ScreenAnalyzer", "BLOCKED SCREEN IN APP: $packageName ($triggeringLabel at ${"%.2f".format(maxConfidence)})")
                
                // Log block event
                BlockEventLogger.logEvent(
                    context = context,
                    blockType = "ai_screen",
                    appName = packageName,
                    domain = "",
                    url = "",
                    classLabel = triggeringLabel,
                    confidence = maxConfidence.toDouble()
                )
                
                return true
            }
        } catch (e: Exception) {
            Log.e("ScreenAnalyzer", "Error analyzing screen capture: ${e.message}")
        }
        return false
    }
}
