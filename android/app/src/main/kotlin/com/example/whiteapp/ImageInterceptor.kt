package com.example.whiteapp

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log

object ImageInterceptor {
    private var classifier: NudeNetClassifier? = null

    @Synchronized
    private fun getClassifier(context: Context): NudeNetClassifier {
        if (classifier == null) {
            classifier = NudeNetClassifier(context.applicationContext)
        }
        return classifier!!
    }

    /**
     * Intercepts an HTTP image response body byte array and scans it.
     * Returns either the original bytes or the blocked replacement bytes.
     */
    fun processImage(
        context: Context,
        imageBytes: ByteArray,
        contentType: String,
        domain: String,
        url: String
    ): ByteArray {
        // Performance guard: Skip very small images (icons, thumbnails)
        if (imageBytes.size < 5 * 1024) {
            return imageBytes
        }

        try {
            // Decode image metadata first to check size
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)
            
            val width = options.outWidth
            val height = options.outHeight
            
            // Skip icons/favicons
            if (width < 50 || height < 50) {
                return imageBytes
            }

            // Decode full bitmap
            val decodeOptions = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, decodeOptions) 
                ?: return imageBytes

            val nudenet = getClassifier(context)
            val detections = nudenet.classify(bitmap)

            if (detections.isEmpty()) {
                bitmap.recycle()
                return imageBytes
            }

            // Threshold rules matching Dart/DB configurations
            var shouldBlock = false
            var triggeringLabel = ""
            var maxConfidence = 0.0f

            for (detection in detections) {
                val label = detection.label.uppercase()
                val conf = detection.confidence

                // Fallback thresholds identical to Flutter
                val threshold = when (label) {
                    "GENITALIA_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "ANUS_EXPOSED" -> 0.65f
                    "FEMALE_BREAST_EXPOSED" -> 0.75f
                    "BUTTOCKS_EXPOSED" -> 0.70f
                    else -> 0.85f // safer fallback for others
                }

                val isCompositeOnly = when (label) {
                    "GENITALIA_COVERED", "FEMALE_BREAST_COVERED", "BUTTOCKS_COVERED", "MALE_BREAST_EXPOSED", "BELLY_EXPOSED", "FEET_EXPOSED", "ARMPITS_EXPOSED" -> true
                    else -> false
                }

                if (!isCompositeOnly && conf >= threshold) {
                    shouldBlock = true
                    if (conf > maxConfidence) {
                        maxConfidence = conf
                        triggeringLabel = label
                    }
                }
            }

            if (shouldBlock) {
                Log.w("ImageInterceptor", "BLOCKED EXPLICIT IMAGE: $domain ($triggeringLabel at ${"%.2f".format(maxConfidence)})")
                
                // Log block event
                BlockEventLogger.logEvent(
                    context = context,
                    blockType = "ai_image",
                    appName = "NetworkProxy",
                    domain = domain,
                    url = url,
                    classLabel = triggeringLabel,
                    confidence = maxConfidence.toDouble()
                )

                // Generate clean replacement image of identical aspect ratio/size
                val replacement = ImageReplacer.generateWhiteImage(width, height)
                bitmap.recycle()
                return replacement
            }

            bitmap.recycle()
        } catch (e: Exception) {
            Log.e("ImageInterceptor", "Error processing image: ${e.message}")
        }

        return imageBytes
    }
}
