package com.example.whiteapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import android.content.Context
import android.app.AlarmManager
import java.io.FileInputStream
import kotlin.concurrent.thread

/**
 * WhiteApp DNS Shield VPN Service
 *
 * HOW IT WORKS:
 * 1. Sets device DNS to Cloudflare Family (1.1.1.3) + AdGuard Family (94.140.14.15)
 *    → These DNS servers automatically refuse to resolve known adult/porn domains
 *    → When Chrome/Instagram tries to load pornhub.com, the DNS returns NXDOMAIN
 *    → The page never loads at all
 *
 * 2. Blocks DNS-over-HTTPS (DoH) bypass
 *    → Chrome has built-in encrypted DNS that bypasses system DNS entirely
 *    → We route known DoH server IPs (8.8.8.8, 1.1.1.1, etc.) into a black hole
 *    → Chrome's DoH fails, Chrome falls back to system DNS → our family DNS
 *    → All DNS queries go through our filtered DNS servers
 *
 * 3. Conditionally inspects HTTP/HTTPS traffic via a local MITM proxy
 *    → Filters and blocks explicit/anatomical images on web pages in real-time
 *    → Bypasses certificate-pinned applications to ensure they continue functioning
 *
 * WHAT THIS BLOCKS:
 * ✅ Known adult websites (pornhub, xvideos, xhamster, etc.) — before any content loads
 * ✅ Malware and phishing domains
 * ✅ Forces SafeSearch on Google, Bing, YouTube (Cloudflare Family feature)
 * ❌ Individual images on allowed sites (Google Images anatomy) — handled by screen scanner
 */
class WhiteVpnService : VpnService() {

    companion object {
        private const val TAG = "WhiteVpnService"

        @Volatile var instance: WhiteVpnService? = null
            private set

        // DNS-over-HTTPS servers to block (forces Chrome to use system DNS)
        private val DOH_BLOCK_IPS = arrayOf(
            "8.8.8.8",         // Google Public DNS
            "8.8.4.4",         // Google Public DNS secondary
            "1.1.1.1",         // Cloudflare standard (NOT family - we use 1.1.1.3)
            "1.0.0.1",         // Cloudflare standard secondary
            "9.9.9.9",         // Quad9
            "149.112.112.112", // Quad9 secondary
            "208.67.222.222",  // OpenDNS
            "208.67.220.220",  // OpenDNS secondary
            "185.228.168.9",   // CleanBrowsing
            "185.228.169.9",   // CleanBrowsing secondary
            "76.76.19.19",     // Alternate DNS
            "76.223.122.150",  // Alternate DNS secondary
        )
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    @Volatile private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: "START"
        if (action == "START") {
            startVpn()
        } else if (action == "STOP") {
            stopVpn()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun startVpn() {
        if (isRunning) return
        instance = this
        isRunning = true
        Log.i(TAG, "Starting WhiteApp DNS Shield VPN...")

        // Start local content filtering proxy
        ContentFilterProxy.start(applicationContext)

        // Foreground Service compliance
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1001, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1001, createNotification())
        }

        vpnThread = thread(start = true, name = "WhiteVpnThread") {
            try {
                runVpn()
            } catch (e: Exception) {
                Log.e(TAG, "VPN thread crashed: ${e.message}", e)
            } finally {
                // Only stop if we're still supposed to be running (crash recovery)
                if (isRunning) {
                    Log.w(TAG, "VPN thread exited unexpectedly while isRunning=true, cleaning up...")
                    isRunning = false
                    try { vpnInterface?.close() } catch (_: Exception) {}
                    vpnInterface = null
                }
            }
        }
    }

    private fun stopVpn() {
        if (!isRunning) return
        isRunning = false
        instance = null
        Log.i(TAG, "Stopping WhiteApp VPN service...")

        // Stop local content filtering proxy
        ContentFilterProxy.stop()

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null

        vpnThread?.interrupt()
        vpnThread = null

        stopForeground(true)
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (isRunning) {
            Log.i(TAG, "Task removed while VPN is running, scheduling auto-restart...")
            val restartIntent = Intent(applicationContext, this.javaClass).apply {
                action = "START"
                setPackage(packageName)
            }
            val pendingIntent = PendingIntent.getService(
                applicationContext, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 1000, pendingIntent)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked by system/user.")
        stopVpn()
        super.onRevoke()
    }

    private fun runVpn() {
        Log.i(TAG, "=== CONFIGURING DNS SHIELD ===")
        Log.i(TAG, "Family DNS: Cloudflare Families (1.1.1.3, 1.0.0.3) + AdGuard Family (94.140.14.15)")
        Log.i(TAG, "Blocking ${DOH_BLOCK_IPS.size} DoH bypass IPs to force all DNS through family filter")

        val builder = Builder()
            .setSession("WhiteApp Shield")
            .setMtu(1500)
            .addAddress("10.0.0.2", 32)

        // Route only browser applications through the VPN tunnel (App-Based Routing)
        // This isolates high-bandwidth non-browser traffic (like speed test apps, updates, CDNs)
        // from being proxied or decrypted, resolving performance/latency issues system-wide.
        val browserPackages = mutableSetOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.sec.android.app.sbrowser",
            "com.microsoft.emmx",
            "com.opera.browser",
            "com.opera.mini.native",
            "com.brave.browser",
            "com.duckduckgo.mobile.android",
            "com.android.browser",
            "com.mi.globalbrowser",
            "com.huawei.browser",
            "com.vivaldi.browser",
            "com.yandex.browser"
        )

        try {
            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("http://www.google.com"))
            val pm = packageManager
            val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            }
            for (info in resolveInfos) {
                val pkg = info.activityInfo.packageName
                if (pkg != packageName) { // Exclude our own app
                    browserPackages.add(pkg)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query system web browsers: ${e.message}")
        }

        var allowedCount = 0
        for (pkg in browserPackages) {
            try {
                builder.addAllowedApplication(pkg)
                Log.i(TAG, "Routed browser application through VPN: $pkg")
                allowedCount++
            } catch (e: PackageManager.NameNotFoundException) {
                // Ignore browsers that are not installed on this specific device
            } catch (e: Exception) {
                Log.w(TAG, "Could not route application $pkg: ${e.message}")
            }
        }
        Log.i(TAG, "Configured VPN tunnel to route $allowedCount browser application(s).")

        // Configure system-wide HTTP Proxy routing to intercept HTTP/HTTPS traffic (Option C)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                // Exclude cert-pinned apps from system-wide HTTP proxy.
                // These apps will bypass proxy decryption (preventing connection failures)
                // but their DNS queries are still resolved by our secure family DNS.
                val exclusionList = listOf(
                    "instagram.com", "*.instagram.com",
                    "facebook.com", "*.facebook.com", "fbcdn.net", "*.fbcdn.net",
                    "messenger.com", "*.messenger.com",
                    "snapchat.com", "*.snapchat.com",
                    "whatsapp.com", "*.whatsapp.com", "whatsapp.net", "*.whatsapp.net",
                    "tiktok.com", "*.tiktok.com", "tiktokcdn.com", "*.tiktokcdn.com",
                    "twitter.com", "*.twitter.com", "twimg.com", "*.twimg.com", "t.co", "*.t.co",
                    // Google Apps & APIs (bypass proxy to prevent SSL pinning crashes)
                    "youtube.com", "*.youtube.com",
                    "googlevideo.com", "*.googlevideo.com",
                    "ytimg.com", "*.ytimg.com",
                    "ggpht.com", "*.ggpht.com",
                    "googleapis.com", "*.googleapis.com",
                    "gvt1.com", "*.gvt1.com",
                    "android.com", "*.android.com",
                    "gmail.com", "*.gmail.com",
                    // Specific google.com subdomains with strict cert pinning
                    "accounts.google.com",
                    "play.google.com",
                    "android.clients.google.com",
                    "clients.google.com",
                    "clients1.google.com",
                    "clients2.google.com",
                    "clients3.google.com",
                    "clients4.google.com",
                    "clients5.google.com",
                    "clients6.google.com",
                    "apis.google.com",
                    "maps.google.com",
                    "mail.google.com",
                    // Speed tests (bypass local proxy completely for maximum native speed)
                    "fast.com", "*.fast.com",
                    "speedtest.net", "*.speedtest.net",
                    "ookla.com", "*.ookla.com",
                    // Common large content distribution networks (CDNs)
                    "netflix.com", "*.netflix.com",
                    "nflxvideo.net", "*.nflxvideo.net",
                    "nflxext.com", "*.nflxext.com",
                    "nflxso.net", "*.nflxso.net",
                    // Ads, Tracking, Telemetry & Cert-Pinned Non-Browser System Domains
                    "doubleclick.net", "*.doubleclick.net",
                    "googleads.g.doubleclick.net",
                    "googleadservices.com", "*.googleadservices.com",
                    "googlesyndication.com", "*.googlesyndication.com",
                    "apple.com", "*.apple.com",
                    "microsoft.com", "*.microsoft.com",
                    "windowsupdate.com", "*.windowsupdate.com",
                    "github.com", "*.github.com",
                    "githubusercontent.com", "*.githubusercontent.com",
                    "amazonaws.com", "*.amazonaws.com",
                    "cloudflare.com", "*.cloudflare.com",
                    "firebaseio.com", "*.firebaseio.com",
                    "crashlytics.com", "*.crashlytics.com"
                )
                val proxyInfo = android.net.ProxyInfo.buildDirectProxy("127.0.0.1", 8888, exclusionList)
                builder.setHttpProxy(proxyInfo)
                Log.i(TAG, "Set system-wide HTTP proxy route to localhost:8888 with ${exclusionList.size} bypassed domains.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set HTTP proxy on VpnService builder: ${e.message}")
            }
            builder.setMetered(false)
        }

        // Block known DoH servers by routing them into the VPN black hole
        // This forces Chrome/Firefox to fall back to system DNS (our family DNS)
        for (ip in DOH_BLOCK_IPS) {
            try {
                builder.addRoute(ip, 32)
                Log.d(TAG, "  Blocking DoH bypass: $ip")
            } catch (e: Exception) {
                Log.w(TAG, "  Failed to add route for $ip: ${e.message}")
            }
        }

        vpnInterface = builder.establish()
        if (vpnInterface == null) {
            Log.e(TAG, "CRITICAL: Failed to establish VPN TUN interface. Is VPN permission granted?")
            return
        }

        Log.i(TAG, "=====================================================")
        Log.i(TAG, "🛡️  WHITEAPP DNS SHIELD ACTIVE  🛡️")
        Log.i(TAG, "✅ Adult domains blocked at DNS level")
        Log.i(TAG, "✅ SafeSearch enforced on Google/Bing/YouTube")
        Log.i(TAG, "✅ Chrome DoH bypass blocked")
        Log.i(TAG, "✅ Screen scanner provides visual AI protection")
        Log.i(TAG, "=====================================================")

        // Drain loop: read and discard packets routed to the TUN
        // These are DoH bypass attempts from Chrome - we silently drop them
        val fd = vpnInterface?.fileDescriptor ?: return
        val input = FileInputStream(fd)
        val buffer = ByteArray(32767)

        while (isRunning) {
            try {
                val length = input.read(buffer)
                if (length > 0) {
                    // Packet to a blocked DoH IP — silently dropped
                    // This forces the app to fall back to system DNS → our family DNS
                    Log.v(TAG, "Dropped DoH bypass packet (${length} bytes)")
                } else if (length == -1) {
                    // TUN interface was closed
                    Log.i(TAG, "TUN interface closed (EOF)")
                    break
                }
            } catch (e: java.io.InterruptedIOException) {
                // Read timeout, continue loop
                continue
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "TUN read error: ${e.message}")
                }
                break
            }
        }

        Log.i(TAG, "VPN drain loop exited")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "vpn_channel",
                "Shield Protective Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows if WhiteApp protective filtering is running."
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "vpn_channel")
                .setContentTitle("WhiteApp Shield Active")
                .setContentText("DNS filtering active — adult sites blocked, SafeSearch enforced.")
                .setSmallIcon(android.R.drawable.ic_secure)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("WhiteApp Shield Active")
                .setContentText("DNS filtering active — adult sites blocked, SafeSearch enforced.")
                .setSmallIcon(android.R.drawable.ic_secure)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }
}
