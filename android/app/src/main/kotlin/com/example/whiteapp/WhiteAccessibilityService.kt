package com.example.whiteapp

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.Executors

class WhiteAccessibilityService : AccessibilityService() {

    private val blockedApps = setOf(
        "com.android.chrome", // Browser block incognito checks
        "com.android.vending", // Play Store settings guard
        "com.google.android.youtube"
    )

    private val whitelistedApps = setOf(
        "com.example.whiteapp",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.android.systemui",
        "com.miui.home",                    // Xiaomi MIUI launcher
        "com.mi.android.globallauncher",    // Xiaomi Global launcher
        "com.sec.android.app.launcher",     // Samsung launcher
        "com.android.dialer",              // Phone dialer
        "com.android.contacts",            // Contacts
        "com.android.mms",                 // SMS app
        "com.google.android.dialer"        // Google Phone
    )

    private var lastScanTime = 0L
    private val scanIntervalMs = 400L
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var isScanInProgress = false
    private var scaleBitmap: Bitmap? = null
    private var scaleCanvas: android.graphics.Canvas? = null
    private val scaleRect = android.graphics.Rect(0, 0, 320, 320)

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        // Log event for developers to see it's active
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d("WhiteAccessibility", "ACCESSIBILITY EVENT: Active app changed to [$packageName]")
        }
        
        // Keyword search monitoring on text change
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            val textVal = event.text?.joinToString(" ") ?: ""
            if (textVal.isNotEmpty()) {
                checkForTriggerKeywords(textVal, packageName)
            }
        }

        val rootNode = rootInActiveWindow ?: return

        // Browser incognito blocker
        if (packageName == "com.android.chrome") {
            inspectChromeIncognito(rootNode)
            // Recursively inspect Chrome nodes for triggering keywords in URL bar
            inspectNodeForKeywordsRecursive(rootNode, packageName)
        }

        // Screen visual scanning
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            triggerScreenScan(packageName)
        }
    }

    private val triggerKeywords = setOf("porn", "xxx", "sex", "hentai", "nudity", "explicit", "erotic", "nsfw")

    private fun checkForTriggerKeywords(text: String, appName: String) {
        val lowerText = text.lowercase()
        for (keyword in triggerKeywords) {
            if (lowerText.contains(keyword)) {
                Log.w("WhiteAccessibility", "Keyword block event triggered: '$keyword' in $appName")
                
                // Log block event locally
                BlockEventLogger.logEvent(
                    context = this,
                    blockType = "keyword",
                    appName = appName,
                    domain = "keyword-match",
                    url = "Search: $keyword",
                    classLabel = "KEYWORD_BLOCKED",
                    confidence = 1.0
                )

                // Broadcast keyword block so MainActivity can notify Flutter
                val intent = Intent("com.whiteapp.KEYWORD_DETECTED").apply {
                    putExtra("keyword", keyword)
                    putExtra("appName", appName)
                    setPackage(packageName)
                }
                sendBroadcast(intent)

                // Prevent exposure (go home or show overlay)
                mainHandler.post {
                    BlockingOverlay.show(this@WhiteAccessibilityService, "KEYWORD_BLOCKED_OVERLAY") {
                        goHome()
                    }
                }
                break
            }
        }
    }

    private fun inspectNodeForKeywordsRecursive(node: AccessibilityNodeInfo?, appName: String) {
        if (node == null) return
        val nodeText = node.text?.toString() ?: ""
        if (nodeText.isNotEmpty()) {
            checkForTriggerKeywords(nodeText, appName)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            inspectNodeForKeywordsRecursive(child, appName)
        }
    }

    private fun triggerScreenScan(packageName: String) {
        if (whitelistedApps.contains(packageName)) return
        if (BlockingOverlay.isShowing()) return
        if (isScanInProgress) return

        val now = System.currentTimeMillis()
        if (now - lastScanTime < scanIntervalMs) return
        lastScanTime = now

        isScanInProgress = true

        try {
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshotResult: ScreenshotResult) {
                        try {
                            val hardwareBuffer = screenshotResult.hardwareBuffer
                            val colorSpace = screenshotResult.colorSpace
                            val hardwareBitmap = Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                            
                            if (hardwareBitmap != null) {
                                // Convert hardware-backed GPU bitmap to software-backed CPU bitmap
                                val bitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
                                hardwareBitmap.recycle()
                                
                                if (bitmap != null) {
                                    // Initialize pre-allocated bitmap if needed
                                    if (scaleBitmap == null) {
                                        scaleBitmap = Bitmap.createBitmap(320, 320, Bitmap.Config.ARGB_8888)
                                        scaleCanvas = android.graphics.Canvas(scaleBitmap!!)
                                    }
                                    
                                    // Draw and scale software bitmap directly to our software bitmap
                                    scaleCanvas!!.drawBitmap(bitmap, null, scaleRect, null)
                                    
                                    // Recycle software copy immediately to free memory
                                    bitmap.recycle()
                                    
                                    val isBlocked = ScreenAnalyzer.analyzeScreen(
                                        context = this@WhiteAccessibilityService,
                                        screenshot = scaleBitmap!!,
                                        packageName = packageName
                                    )
                                    
                                    if (isBlocked) {
                                        mainHandler.post {
                                            BlockingOverlay.show(this@WhiteAccessibilityService, "EXPLICIT_CONTENT_OVERLAY") {
                                                goHome()
                                            }
                                        }
                                    }
                                }
                            }
                            hardwareBuffer.close()
                        } catch (e: Exception) {
                            Log.e("WhiteAccessibility", "Error in screenshot processing callback: ${e.message}", e)
                        } finally {
                            isScanInProgress = false
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        Log.e("WhiteAccessibility", "Screen capture failed with error code: $errorCode")
                        isScanInProgress = false
                    }
                }
            )
        } catch (e: Exception) {
            Log.e("WhiteAccessibility", "Screen capture scan error: ${e.message}")
            isScanInProgress = false
        }
    }

    private fun inspectChromeIncognito(node: AccessibilityNodeInfo) {
        val incognitoNodes = node.findAccessibilityNodeInfosByText("Incognito")
        if (incognitoNodes.isNotEmpty()) {
            Log.w("WhiteAccessibility", "Chrome Incognito Mode block triggered!")
            goHome()
        }
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
    }

    override fun onInterrupt() {
        Log.e("WhiteAccessibility", "Bodyguard accessibility service was interrupted.")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i("WhiteAccessibility", "Bodyguard Accessibility Service successfully connected.")
    }

    override fun onDestroy() {
        executor.shutdown()
        BlockingOverlay.dismiss()
        super.onDestroy()
    }
}
