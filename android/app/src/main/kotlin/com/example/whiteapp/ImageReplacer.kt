package com.example.whiteapp

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import java.io.ByteArrayOutputStream

object ImageReplacer {

    fun generateWhiteImage(width: Int, height: Int): ByteArray {
        val w = Math.max(width, 1)
        val h = Math.max(height, 1)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.GRAY
            textSize = Math.max(12f, Math.min(w, h) / 15f)
            isAntiAlias = true
            textAlign = Paint.Align.CENTER
        }

        canvas.drawText(
            "Content Blocked by WhiteApp Shield",
            w / 2f,
            h / 2f + paint.textSize / 3f,
            paint
        )

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, outputStream)
        bitmap.recycle()
        return outputStream.toByteArray()
    }

    fun generateBlurredImage(original: Bitmap, detections: List<NativeDetection>): ByteArray {
        val bitmap = original.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(bitmap)
        val paint = Paint().apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }

        // Standard response: Draw a solid white block over detected areas
        for (detection in detections) {
            val left = detection.x - detection.w / 2f
            val top = detection.y - detection.h / 2f
            val right = detection.x + detection.w / 2f
            val bottom = detection.y + detection.h / 2f
            
            canvas.drawRect(
                Math.max(0f, left),
                Math.max(0f, top),
                Math.min(bitmap.width.toFloat(), right),
                Math.min(bitmap.height.toFloat(), bottom),
                paint
            )
        }

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, outputStream)
        bitmap.recycle()
        return outputStream.toByteArray()
    }
}
