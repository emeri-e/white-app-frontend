package com.example.whiteapp

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

data class NativeDetection(
    val label: String,
    val confidence: Float,
    val x: Float,
    val y: Float,
    val w: Float,
    val h: Float
)

class NudeNetClassifier(private val context: Context) {
    private var interpreter: Interpreter? = null
    private val modelFilename = "models/nudenet_320n.tflite"

    private val labels = arrayOf(
        "FEMALE_GENITALIA_COVERED",
        "FACE_FEMALE",
        "BUTTOCKS_EXPOSED",
        "FEMALE_BREAST_EXPOSED",
        "FEMALE_GENITALIA_EXPOSED",
        "MALE_BREAST_EXPOSED",
        "ANUS_EXPOSED",
        "FEET_EXPOSED",
        "BELLY_COVERED",
        "FEET_COVERED",
        "ARMPITS_COVERED",
        "ARMPITS_EXPOSED",
        "FACE_MALE",
        "BELLY_EXPOSED",
        "MALE_GENITALIA_EXPOSED",
        "ANUS_COVERED",
        "FEMALE_BREAST_COVERED",
        "BUTTOCKS_COVERED"
    )

    init {
        try {
            val assetManager = context.assets
            val fileDescriptor = assetManager.openFd(modelFilename)
            val fileInputStream = FileInputStream(fileDescriptor.fileDescriptor)
            val fileChannel = fileInputStream.channel
            val startOffset = fileDescriptor.startOffset
            val declaredLength = fileDescriptor.declaredLength
            val mappedByteBuffer = fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
            
            interpreter = Interpreter(mappedByteBuffer)
            Log.i("NudeNetClassifier", "Android TFLite model loaded successfully")
        } catch (e: Exception) {
            Log.e("NudeNetClassifier", "Error loading model: ${e.message}")
        }
    }

    private var inputBuffer: ByteBuffer? = null
    private var outputBuffer: ByteBuffer? = null
    private var intValues: IntArray? = null

    @Synchronized
    fun classify(bitmap: Bitmap): List<NativeDetection> {
        try {
            val interpreter = this.interpreter ?: return emptyList()

            // Pre-process: Resize Bitmap to 320x320
            val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 320, 320, true)

            // Reuse or allocate input buffer
            if (inputBuffer == null) {
                inputBuffer = ByteBuffer.allocateDirect(1 * 320 * 320 * 3 * 4).apply {
                    order(ByteOrder.nativeOrder())
                }
            }
            val byteBuffer = inputBuffer!!
            byteBuffer.rewind()

            // Reuse or allocate pixel values array
            if (intValues == null) {
                intValues = IntArray(320 * 320)
            }
            val pixels = intValues!!
            resizedBitmap.getPixels(pixels, 0, 320, 0, 0, 320, 320)

            for (pixelValue in pixels) {
                byteBuffer.putFloat(((pixelValue shr 16) and 0xFF) / 255.0f)
                byteBuffer.putFloat(((pixelValue shr 8) and 0xFF) / 255.0f)
                byteBuffer.putFloat((pixelValue and 0xFF) / 255.0f)
            }

            // Recycle resized bitmap immediately if it's a new instance to prevent leaking memory
            if (resizedBitmap != bitmap) {
                resizedBitmap.recycle()
            }

            // Output buffer initialization (based on NudeNet dimensions [1, 22, 2100])
            val outputTensor = interpreter.getOutputTensor(0)
            val outputShape = outputTensor.shape()
            
            if (outputBuffer == null) {
                outputBuffer = ByteBuffer.allocateDirect(outputShape[0] * outputShape[1] * outputShape[2] * 4).apply {
                    order(ByteOrder.nativeOrder())
                }
            }
            val outBuf = outputBuffer!!
            outBuf.rewind()

            // Run inference
            interpreter.run(byteBuffer, outBuf)

            // Post-process to extract classifications
            return parseNativeOutput(outBuf, outputShape, bitmap.width, bitmap.height)
        } catch (e: Exception) {
            Log.e("NudeNetClassifier", "Android TFLite inference run failed: ${e.message}")
            return emptyList()
        }
    }

    private fun parseNativeOutput(
        buffer: ByteBuffer,
        shape: IntArray,
        origW: Int,
        origH: Int
    ): List<NativeDetection> {
        val candidates = mutableListOf<NativeDetection>()
        val numClasses = 18
        val numAnchors = 2100
        val confidenceThreshold = 0.25f
        val iouThreshold = 0.45f

        val scaleX = origW.toFloat() / 320.0f
        val scaleY = origH.toFloat() / 320.0f

        buffer.rewind()
        val floatBuffer = buffer.asFloatBuffer()
        val data = FloatArray(numClasses + 4 * numAnchors)
        
        // Output matrix is [22, 2100]. In row-major: 22 rows of 2100 columns each
        // Let's parse each anchor/column
        for (c in 0 until numAnchors) {
            // Box coordinates: x_center, y_center, width, height (rows 0, 1, 2, 3)
            val xCenter = floatBuffer.get(0 * numAnchors + c)
            val yCenter = floatBuffer.get(1 * numAnchors + c)
            val w = floatBuffer.get(2 * numAnchors + c)
            val h = floatBuffer.get(3 * numAnchors + c)

            // Find class with highest confidence (rows 4 to 21)
            var maxClassId = -1
            var maxScore = 0.0f
            for (classId in 0 until numClasses) {
                val score = floatBuffer.get((4 + classId) * numAnchors + c)
                if (score > maxScore) {
                    maxScore = score
                    maxClassId = classId
                }
            }

            if (maxScore >= confidenceThreshold && maxClassId != -1) {
                // Convert coordinates to top-left and scale
                val x1 = (xCenter - w / 2.0f) * scaleX
                val y1 = (yCenter - h / 2.0f) * scaleY
                val boxW = w * scaleX
                val boxH = h * scaleY

                candidates.add(
                    NativeDetection(
                        label = labels[maxClassId],
                        confidence = maxScore,
                        x = Math.max(0.0f, x1),
                        y = Math.max(0.0f, y1),
                        w = boxW,
                        h = boxH
                    )
                )
            }
        }

        // Apply Non-Maximum Suppression (NMS)
        // Sort candidates by confidence descending
        candidates.sortByDescending { it.confidence }

        val selected = mutableListOf<NativeDetection>()
        for (candidate in candidates) {
            var keep = true
            for (active in selected) {
                if (active.label == candidate.label) {
                    val iou = calculateIoU(candidate, active)
                    if (iou > iouThreshold) {
                        keep = false
                        break
                    }
                }
            }
            if (keep) {
                selected.add(candidate)
            }
        }

        return selected
    }

    private fun calculateIoU(a: NativeDetection, b: NativeDetection): Float {
        val x1 = Math.max(a.x, b.x)
        val y1 = Math.max(a.y, b.y)
        val x2 = Math.min(a.x + a.w, b.x + b.w)
        val y2 = Math.min(a.y + a.h, b.y + b.h)

        val intersectionWidth = Math.max(0.0f, x2 - x1)
        val intersectionHeight = Math.max(0.0f, y2 - y1)
        val intersectionArea = intersectionWidth * intersectionHeight

        val areaA = a.w * a.h
        val areaB = b.w * b.h
        val unionArea = areaA + areaB - intersectionArea

        if (unionArea <= 0.0f) return 0.0f
        return intersectionArea / unionArea
    }

    fun close() {
        interpreter?.close()
        interpreter = null
    }
}
