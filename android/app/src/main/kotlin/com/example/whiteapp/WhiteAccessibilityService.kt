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

    // Overlay cooldown: prevents the flash-dismiss-show loop.
    // After an overlay is shown, we suppress re-showing for this many ms.
    private var lastOverlayShowTime = 0L
    private val overlayCooldownMs = 4000L // 4 second cooldown after overlay is shown

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

    /**
     * Shows the blocking overlay with cooldown protection.
     * Prevents the flash-dismiss-show race condition by enforcing a minimum
     * interval between overlay presentations.
     */
    private fun showOverlayWithCooldown(triggeringClass: String, delayBeforeHomeMs: Long = 3000L) {
        val now = System.currentTimeMillis()
        if (now - lastOverlayShowTime < overlayCooldownMs) {
            Log.d("WhiteAccessibility", "Overlay cooldown active, suppressing re-show for $triggeringClass")
            return
        }
        if (BlockingOverlay.isShowing()) {
            Log.d("WhiteAccessibility", "Overlay already showing, skipping for $triggeringClass")
            return
        }

        lastOverlayShowTime = now
        mainHandler.post {
            BlockingOverlay.show(this@WhiteAccessibilityService, triggeringClass) {
                goHome()
            }
        }
        // Single delayed goHome — no duplicates
        mainHandler.postDelayed({ goHome() }, delayBeforeHomeMs)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        // Log event for developers to see it's active
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d("WhiteAccessibility", "ACCESSIBILITY EVENT: Active app changed to [$packageName]")
            
            // Auto-dismiss active overlay when user switches back to a whitelisted safe app/launcher.
            // CRITICAL FIX: Do NOT auto-dismiss if the package is our own app (com.example.whiteapp).
            // The overlay itself triggers window state changes with our package name, causing it to
            // instantly dismiss itself and let the user see the blocked browser.
            if (packageName != "com.example.whiteapp" && whitelistedApps.contains(packageName)) {
                mainHandler.post {
                    Log.d("WhiteAccessibility", "Auto-dismissing overlay because active app is $packageName")
                    BlockingOverlay.dismiss()
                }
            }

            // Block disallowed browsers
            if (isDisallowedBrowser(packageName)) {
                Log.w("WhiteAccessibility", "Blocking unauthorized browser app: $packageName")
                showOverlayWithCooldown("UNSUPPORTED_BROWSER")
                return
            }
        }

        // Diagnostic Chrome UI hierarchy dumper to pinpoint Incognito differences
        if (packageName == "com.android.chrome" && 
            (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || 
             event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)) {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                Log.d("WhiteAccessibilityDiagnostics", "--- START CHROME NODE TREE DUMP ---")
                dumpNodeTreeRecursive(rootNode, 0)
                Log.d("WhiteAccessibilityDiagnostics", "--- END CHROME NODE TREE DUMP ---")
            }
        }
        
        // Keyword search monitoring on text change is disabled (handled at proxy level)
        /*
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            val textVal = event.text?.joinToString(" ") ?: ""
            if (textVal.isNotEmpty()) {
                checkForTriggerKeywords(textVal, packageName)
            }
        }
        */

        // Screen visual scanning — only for target apps, not everything
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && scanTargetApps.contains(packageName)) {
            triggerScreenScan(packageName)
        }

        val rootNode = rootInActiveWindow ?: return

        // Browser incognito / private tab blocker — check on both window state and content changes to ensure instant blocking
        if ((packageName == "com.android.chrome" || packageName == "org.mozilla.firefox") &&
            (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
             event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)) {
            if (checkIncognitoOrPrivate(rootNode, packageName)) {
                showOverlayWithCooldown("INCOGNITO_MODE")
            }
        }

        // Recursively inspect Chrome nodes for triggering keywords in URL bar is disabled (handled at proxy level)
        /*
        if (packageName == "com.android.chrome") {
            inspectNodeForKeywordsRecursive(rootNode, packageName)
        }
        */
    }

    private val triggerKeywords = java.util.Collections.synchronizedSet(mutableSetOf("porn", "xxx", "sex", "hentai", "nudity", "explicit", "erotic", "nsfw"))

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
                showOverlayWithCooldown("KEYWORD_BLOCKED_OVERLAY")
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
                                        showOverlayWithCooldown("EXPLICIT_CONTENT_OVERLAY")
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

    /**
     * Chrome incognito detection.
     *
     * IMPORTANT: We ONLY trigger on the actual incognito page content strings:
     *   - "You've gone Incognito"
     *   - "You're Incognito" (some Chrome versions)
     *   - "Incognito mode" in content descriptions
     *
     * We do NOT trigger on:
     *   - The standalone word "Incognito" (this matches "New incognito tab" menu items,
     *     tab labels, and other Chrome UI elements visible in normal browsing)
     */
    private fun checkIncognitoOrPrivate(node: AccessibilityNodeInfo, packageName: String): Boolean {
        return checkNodeRecursive(node, packageName)
    }

    private fun checkNodeRecursive(node: AccessibilityNodeInfo?, packageName: String): Boolean {
        if (node == null) return false

        val text = node.text?.toString() ?: ""
        val desc = node.contentDescription?.toString() ?: ""

        val normalizedText = text.replace("’", "'").lowercase()
        val normalizedDesc = desc.replace("’", "'").lowercase()

        if (packageName == "com.android.chrome") {
            // Chrome Incognito checks
            val isNtp = normalizedText.contains("you've gone incognito") || 
                         normalizedText.contains("you're incognito") ||
                         normalizedText.contains("in incognito mode")
            
            val isTabSwitcher = normalizedText.contains("search your incognito tabs") || 
                                 normalizedDesc.contains("incognito tabs")
            
            val isMenu = normalizedText.contains("close incognito tabs")
            
            // Only trigger on active incognito mode indicator (exclude menu button "New Incognito tab" itself)
            val isActiveBadge = normalizedDesc.contains("incognito mode") && !normalizedDesc.contains("new")

            if (isNtp || isTabSwitcher || isMenu || isActiveBadge) {
                Log.w("WhiteAccessibility", "Chrome Incognito Mode detected: text='$text', desc='$desc'")
                return true
            }
        } else if (packageName == "org.mozilla.firefox") {
            // Firefox Private Browsing checks
            val isPrivateNtp = normalizedText.contains("private browsing") || 
                               normalizedText.contains("private tab") ||
                               normalizedDesc.contains("private browsing") ||
                               normalizedDesc.contains("private tab")

            if (isPrivateNtp) {
                Log.w("WhiteAccessibility", "Firefox Private Browsing detected: text='$text', desc='$desc'")
                return true
            }
        }

        // Recursively inspect children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (checkNodeRecursive(child, packageName)) {
                return true
            }
        }
        return false
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
        loadDynamicKeywords()
    }

    private fun loadDynamicKeywords() {
        // Load explicit keywords
        try {
            val file = getDatabasePath("blocked_keywords.txt")
            if (file.exists()) {
                val lines = file.readLines()
                    .map { it.lowercase().trim() }
                    .filter { it.isNotEmpty() }
                triggerKeywords.addAll(lines)
                Log.i("WhiteAccessibility", "Loaded ${lines.size} dynamic keywords into accessibility filter. Total keywords: ${triggerKeywords.size}")
            }
        } catch (e: Exception) {
            Log.e("WhiteAccessibility", "Failed to load dynamic keywords: ${e.message}")
        }

        // Load domain base names as keywords
        try {
            val file = getDatabasePath("blocked_domains.txt")
            if (file.exists()) {
                val lines = file.readLines()
                    .map { it.lowercase().trim() }
                    .filter { it.isNotEmpty() }
                val baseNames = lines.map { SafeDnsResolver.getDomainBaseName(it) }.filter { it.length > 2 }
                triggerKeywords.addAll(baseNames)
                Log.i("WhiteAccessibility", "Extracted and loaded ${baseNames.size} base names from domains as keywords. Total: ${triggerKeywords.size}")
            }
        } catch (e: Exception) {
            Log.e("WhiteAccessibility", "Failed to load domain base names: ${e.message}")
        }
    }

    private fun dumpNodeTreeRecursive(node: AccessibilityNodeInfo?, depth: Int) {
        if (node == null || depth > 20) return
        val indent = "  ".repeat(depth)
        val viewId = node.viewIdResourceName ?: "no-id"
        val text = node.text?.toString() ?: ""
        val desc = node.contentDescription?.toString() ?: ""
        val className = node.className?.toString() ?: ""
        
        // Print only nodes that have some identifying info (id, text, desc) to keep logs readable
        if (viewId != "no-id" || text.isNotEmpty() || desc.isNotEmpty()) {
            Log.d("WhiteAccessibilityDiagnostics", "$indent[Class: $className | ID: $viewId | Text: $text | Desc: $desc]")
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            dumpNodeTreeRecursive(child, depth + 1)
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        BlockingOverlay.dismiss()
        super.onDestroy()
    }
}
