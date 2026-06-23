package com.example.whiteapp

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object BlockEventLogger {
    private const val QUEUE_FILENAME = "block_events_queue.json"
    private val lock = Any()

    fun logEvent(
        context: Context,
        blockType: String,
        appName: String,
        domain: String,
        url: String,
        classLabel: String,
        confidence: Double
    ) {
        synchronized(lock) {
            try {
                val file = File(context.filesDir, QUEUE_FILENAME)
                val jsonArray = if (file.exists()) {
                    try {
                        JSONArray(file.readText())
                    } catch (e: Exception) {
                        JSONArray()
                    }
                } else {
                    JSONArray()
                }

                val df = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                df.timeZone = TimeZone.getTimeZone("UTC")
                val timestampStr = df.format(Date())

                val event = JSONObject().apply {
                    put("block_type", blockType)
                    put("app_name", appName)
                    put("domain", domain)
                    put("url", url)
                    put("ai_class_label", classLabel)
                    put("confidence_score", confidence)
                    put("timestamp", timestampStr)
                }

                jsonArray.put(event)
                file.writeText(jsonArray.toString())
                Log.i("BlockEventLogger", "Logged native block event: $blockType - $domain ($classLabel)")
            } catch (e: Exception) {
                Log.e("BlockEventLogger", "Failed to log block event: ${e.message}")
            }
        }
    }

    fun flushEvents(context: Context): String {
        synchronized(lock) {
            try {
                val file = File(context.filesDir, QUEUE_FILENAME)
                if (!file.exists()) return "[]"
                
                val content = file.readText()
                file.delete()
                return content
            } catch (e: Exception) {
                Log.e("BlockEventLogger", "Failed to flush block events: ${e.message}")
                return "[]"
            }
        }
    }
}
