package com.example.whiteapp

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.provider.Settings
import android.security.KeyChain
import android.util.Log
import android.view.accessibility.AccessibilityManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.Build
import java.io.ByteArrayInputStream

class MainActivity : FlutterActivity() {

    private val VPN_CHANNEL = "com.whiteapp/vpn"
    private val VPN_REQUEST_CODE = 2026

    private var pendingChannelResult: MethodChannel.Result? = null
    private var keywordReceiver: BroadcastReceiver? = null
    private var pendingDeepLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Pre-load blocklist in memory on a background thread to prevent UI hang on startup
        Thread {
            SafeDnsResolver.loadBlocklist(this)
        }.start()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            val data = intent.dataString
            if (data != null && data.contains("/buddy/accept/")) {
                pendingDeepLink = data
                flutterEngine?.let {
                    MethodChannel(it.dartExecutor.binaryMessenger, VPN_CHANNEL)
                        .invokeMethod("onDeepLink", data)
                }
            }
        }
    }

    override fun onDestroy() {
        keywordReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {}
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // DIAGNOSTIC REFLECTION: Print HttpContentDecompressor constructors
        try {
            val clazz = Class.forName("io.netty.handler.codec.http.HttpContentDecompressor")
            Log.i("MainActivity", "=== DIAGNOSTIC: HttpContentDecompressor constructors ===")
            for (constructor in clazz.constructors) {
                Log.i("MainActivity", "  Constructor: $constructor")
            }
            try {
                val versionClazz = Class.forName("io.netty.util.Version")
                val identifyMethod = versionClazz.getMethod("identify")
                val versionsMap = identifyMethod.invoke(null) as Map<*, *>
                Log.i("MainActivity", "=== Netty Versions: $versionsMap")
            } catch (ex: Exception) {
                Log.e("MainActivity", "Failed to get Netty version: ${ex.message}")
            }
            Log.i("MainActivity", "=========================================================")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to reflect HttpContentDecompressor: ${e.message}", e)
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)

        // Register keyword broadcast receiver
        val filter = IntentFilter("com.whiteapp.KEYWORD_DETECTED")
        keywordReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val keyword = intent?.getStringExtra("keyword") ?: ""
                val appName = intent?.getStringExtra("appName") ?: ""
                channel.invokeMethod("onKeywordDetected", mapOf("keyword" to keyword, "appName" to appName))
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(keywordReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(keywordReceiver, filter)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingDeepLink" -> {
                    val link = pendingDeepLink
                    pendingDeepLink = null
                    result.success(link)
                }
                "startVpn" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        pendingChannelResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        startVpnService()
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                "isVpnRunning" -> {
                    result.success(isServiceRunning(WhiteVpnService::class.java))
                }
                "installCertificate" -> {
                    triggerCertificateInstallation(result)
                }
                "isCertificateInstalled" -> {
                    result.success(CertificateManager.isCertificateInstalled(this))
                }
                "requiresManualInstallation" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "openAppInfoSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.parse("package:$packageName")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "flushNativeBlockEvents" -> {
                    result.success(BlockEventLogger.flushEvents(this))
                }
                "reloadBlocklist" -> {
                    SafeDnsResolver.loadBlocklist(this)
                    result.success(true)
                }
                "startCameraRollMonitoring" -> {
                    CameraRollMonitor.startMonitoring(this)
                    result.success(true)
                }
                "stopCameraRollMonitoring" -> {
                    CameraRollMonitor.stopMonitoring(this)
                    result.success(true)
                }
                "isCameraRollMonitoring" -> {
                    result.success(CameraRollMonitor.isCurrentlyMonitoring())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                startVpnService()
                pendingChannelResult?.success(true)
            } else {
                pendingChannelResult?.success(false)
            }
            pendingChannelResult = null
        }
    }

    private fun startVpnService() {
        val intent = Intent(this, WhiteVpnService::class.java).apply {
            action = "START"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopVpnService() {
        val intent = Intent(this, WhiteVpnService::class.java).apply {
            action = "STOP"
        }
        startService(intent)
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedComponentName = "${context.packageName}/${WhiteAccessibilityService::class.java.name}"
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        
        val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedComponentName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun triggerCertificateInstallation(result: MethodChannel.Result) {
        try {
            CertificateManager.installCertificate(this)
            result.success(true)
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to trigger cert installation: ${e.message}", e)
            result.error("CERT_FAIL", e.message, null)
        }
    }
}
