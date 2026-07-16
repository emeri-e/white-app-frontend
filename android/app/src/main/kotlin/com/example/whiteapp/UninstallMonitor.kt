package com.example.whiteapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class UninstallMonitor : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_PACKAGE_REMOVED) {
            val packageName = intent.data?.schemeSpecificPart ?: return
            
            if (packageName == context.packageName) {
                Log.w("UninstallMonitor", "App uninstall action initiated!")
                
                // Fetch email and apiBaseUrl from Flutter SharedPreferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val userEmail = prefs.getString("flutter.user_email", "") ?: ""
                val apiBaseUrl = prefs.getString("flutter.api_base_url", "") ?: ""
                val targetBase = if (apiBaseUrl.isNotEmpty()) apiBaseUrl else "https://businessportal.site/api"
                val finalUrlString = if (targetBase.endsWith("/")) {
                    "${targetBase}filtering/alerts/app-uninstall/"
                } else {
                    "${targetBase}/filtering/alerts/app-uninstall/"
                }

                // Best effort direct HTTP post to alert the buddy immediately
                thread {
                    try {
                        val url = URL(finalUrlString)
                        val connection = (url.openConnection() as HttpURLConnection).apply {
                            requestMethod = "POST"
                            connectTimeout = 4000
                            readTimeout = 4000
                            doOutput = true
                            setRequestProperty("Content-Type", "application/json")
                        }
                        
                        val jsonPayload = "{\"email\":\"$userEmail\"}"
                        connection.outputStream.use { os ->
                            os.write(jsonPayload.toByteArray())
                        }
                        
                        connection.connect()
                        Log.i("UninstallMonitor", "Uninstall alert triggered on backend: ${connection.responseCode} for $userEmail at $finalUrlString")
                    } catch (e: Exception) {
                        Log.e("UninstallMonitor", "Failed to report uninstall alert to $finalUrlString: ${e.message}")
                    }
                }
            }
        }
    }
}
