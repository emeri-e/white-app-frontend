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

    // Apps where AI screen scanning is active. Only scan apps likely to show explicit imagery.
    private val scanTargetApps = setOf(
        // Browsers
        "com.android.chrome",
        "org.mozilla.firefox",
        // Social media
        "com.instagram.android",
        "com.snapchat.android",
        "com.twitter.android",             // X / Twitter
        "com.zhiliaoapp.musically",        // TikTok
        "com.reddit.frontpage",
        "com.tumblr",
        "com.pinterest",
        // Messaging with image sharing
        "org.telegram.messenger",
        "com.whatsapp",
        "com.facebook.orca",               // Messenger
        "com.discord",
        // Social / media
        "com.facebook.katana",
        "com.google.android.apps.photos",  // Google Photos
        "com.google.android.youtube",
    )

    private var lastScanTime = 0L
    private var lastScanStartTime = 0L
    private val scanIntervalMs = 1500L // Scan at most once every 1.5 seconds to prevent OS queue congestion
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var isScanInProgress = false
    private var scaleBitmap: Bitmap? = null
    private var scaleCanvas: android.graphics.Canvas? = null
    private val scaleRect = android.graphics.Rect(0, 0, 320, 320)

    @Volatile private var cachedBrowsers = setOf<String>()
    private var lastBrowserQueryTime = 0L

    private fun isDisallowedBrowser(packageName: String): Boolean {
        if (packageName == "com.android.chrome" || packageName == "org.mozilla.firefox" || packageName == "com.example.whiteapp") {
            return false
        }
        val now = System.currentTimeMillis()
        if (now - lastBrowserQueryTime > 30000 || cachedBrowsers.isEmpty()) {
            try {
                val pm = packageManager
                val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://www.google.com")).apply {
                    addCategory(Intent.CATEGORY_BROWSABLE)
                }
                val list = pm.queryIntentActivities(intent, 0)
                cachedBrowsers = list.mapNotNull { it.activityInfo?.packageName }.toSet()
                lastBrowserQueryTime = now
            } catch (e: Exception) {
                Log.e("WhiteAccessibility", "Failed to query browsers: ${e.message}")
            }
        }
        if (cachedBrowsers.contains(packageName)) {
            return true
        }
        val lowerPkg = packageName.lowercase()
        return lowerPkg.contains("browser") || 
               lowerPkg.contains("sbrowser") || 
               lowerPkg.contains("ucmobile") || 
               lowerPkg.contains("opera") || 
               lowerPkg.contains("duckduckgo") || 
               lowerPkg.contains("brave") || 
               lowerPkg.contains("kiwi") || 
               lowerPkg.contains("via")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        // Log event for developers to see it's active
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d("WhiteAccessibility", "ACCESSIBILITY EVENT: Active app changed to [$packageName]")
            
            // Auto-dismiss active overlay when user switches back to a whitelisted safe app/launcher
            if (whitelistedApps.contains(packageName)) {
                mainHandler.post {
                    BlockingOverlay.dismiss()
                }
            }

            // Block disallowed browsers
            if (isDisallowedBrowser(packageName)) {
                Log.w("WhiteAccessibility", "Blocking unauthorized browser app: $packageName")
                // Show overlay immediately, then go home after a short delay so user can read the message
                mainHandler.post {
                    BlockingOverlay.show(this@WhiteAccessibilityService, "UNSUPPORTED_BROWSER") {
                        goHome()
                    }
                }
                mainHandler.postDelayed({ goHome() }, 2000) // 2 seconds to read, then force home
                return
            }
        }
        
        // Keyword search monitoring on text change
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            val textVal = event.text?.joinToString(" ") ?: ""
            if (textVal.isNotEmpty()) {
                checkForTriggerKeywords(textVal, packageName)
            }
        }

        // Screen visual scanning — only for target apps, not everything
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && scanTargetApps.contains(packageName)) {
            triggerScreenScan(packageName)
        }

        val rootNode = rootInActiveWindow ?: return

        // Browser incognito blocker — only check on window state changes to avoid menu false positives
        if (packageName == "com.android.chrome" && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            inspectChromeIncognito(rootNode)
        }

        // Recursively inspect Chrome nodes for triggering keywords in URL bar
        if (packageName == "com.android.chrome") {
            inspectNodeForKeywordsRecursive(rootNode, packageName)
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

        val now = System.currentTimeMillis()
        if (isScanInProgress) {
            // Self-recovery if callback was dropped by the OS
            if (now - lastScanStartTime > 5000) {
                Log.w("WhiteAccessibility", "Screen scanner: Stuck lock detected (>5s). Resetting isScanInProgress.")
                isScanInProgress = false
            } else {
                return
            }
        }
        if (now - lastScanTime < scanIntervalMs) return
        lastScanTime = now

        isScanInProgress = true
        lastScanStartTime = now

        Log.d("WhiteAccessibility", "Screen scanner: Triggering takeScreenshot for package: $packageName")
        try {
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshotResult: ScreenshotResult) {
                        Log.d("WhiteAccessibility", "Screen scanner: Screenshot taken successfully.")
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
                                    Log.d("WhiteAccessibility", "Screen scanner: Analysis result: isBlocked=$isBlocked")
                                    
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
        if (incognitoNodes.isEmpty()) return

        // Filter out false positives: menu items like "New incognito tab" contain the word
        // but don't mean incognito is active. Only trigger if we find a node whose text
        // is exactly "Incognito" (the tab indicator) or contains "You've gone Incognito".
        val isActuallyIncognito = incognitoNodes.any { incognitoNode ->
            val text = incognitoNode.text?.toString() ?: ""
            val desc = incognitoNode.contentDescription?.toString() ?: ""
            // Exact standalone "Incognito" label (tab indicator, not menu item)
            text.equals("Incognito", ignoreCase = true) ||
            // Chrome's incognito new tab page heading
            text.contains("You've gone Incognito", ignoreCase = true) ||
            text.contains("You're Incognito", ignoreCase = true) ||
            // Content description on incognito indicator
            desc.equals("Incognito", ignoreCase = true) ||
            desc.contains("Incognito mode", ignoreCase = true)
        }

        if (isActuallyIncognito) {
            Log.w("WhiteAccessibility", "Chrome Incognito Mode block triggered!")
            // Show overlay, then force home after delay so user can read
            mainHandler.post {
                BlockingOverlay.show(this@WhiteAccessibilityService, "INCOGNITO_MODE") {
                    goHome()
                }
            }
            mainHandler.postDelayed({ goHome() }, 2000)
        }
    }

    private fun goHome() {
        performGlobalAction(GLOBAL_ACTION_HOME)
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
