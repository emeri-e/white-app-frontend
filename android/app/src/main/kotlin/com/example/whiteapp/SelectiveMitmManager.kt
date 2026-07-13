package com.example.whiteapp

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.util.Log
import io.netty.channel.ChannelHandlerContext
import io.netty.handler.codec.http.HttpRequest
import org.littleshoot.proxy.MitmManager
import org.littleshoot.proxy.mitm.Authority
import org.littleshoot.proxy.mitm.CertificateSniffingMitmManager
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap
import javax.net.ssl.SSLEngine
import javax.net.ssl.SSLSession

class SelectiveMitmManager(authority: Authority) : MitmManager {
    private val delegate = CertificateSniffingMitmManager(authority)

    override fun serverSslEngine(peerHost: String, peerPort: Int): SSLEngine {
        return delegate.serverSslEngine(peerHost, peerPort)
    }

    override fun serverSslEngine(): SSLEngine {
        return delegate.serverSslEngine()
    }

    override fun clientSslEngineFor(httpRequest: HttpRequest, serverSslSession: SSLSession): SSLEngine {
        return delegate.clientSslEngineFor(httpRequest, serverSslSession)
    }

    companion object {
        private const val TAG = "SelectiveMitmManager"

        // Static seed list: well-known certificate-pinned domains.
        // These bypass MITM from the very first connection (no initial failure needed).
        private val staticBypassDomains = setOf(
            "instagram.com",
            "fbcdn.net",
            "facebook.com",
            "messenger.com",
            "snapchat.com",
            "whatsapp.com",
            "whatsapp.net",
            "tiktok.com",
            "tiktokcdn.com",
            "twitter.com",
            "x.com",
            "twimg.com",
            "t.co",
            // Google Services & Pinned App bypasses
            "youtube.com",
            "googlevideo.com",
            "ytimg.com",
            "ggpht.com",
            "googleapis.com",
            "gvt1.com",
            "android.com",
            "gmail.com",
            // Additional popular cert-pinned apps
            "linkedin.com",
            "licdn.com",
            "spotify.com",
            "scdn.co",
            "netflix.com",
            "nflxext.com",
            "nflxso.net",
            "nflxvideo.net",
            "zoom.us",
            "slack.com",
            "reddit.com",
            "pinterest.com"
        )

        // Per-app dynamic bypass: Map of PackageName -> Set of bypassed hosts
        private val appBypassMap = ConcurrentHashMap<String, MutableSet<String>>()

        // Dynamic bypass set: hosts that have been learned globally when package is unknown.
        private val dynamicBypassHosts: MutableSet<String> = ConcurrentHashMap.newKeySet()

        private fun normalizeAddr(addr: InetSocketAddress): InetSocketAddress {
            val ip = addr.address ?: return addr
            if (ip is java.net.Inet6Address) {
                if (ip.isIPv4CompatibleAddress || ip.hostAddress.startsWith("::ffff:")) {
                    val ipv4Bytes = ip.address.copyOfRange(12, 16)
                    try {
                        val ipv4 = java.net.InetAddress.getByAddress(ip.hostName, ipv4Bytes)
                        return InetSocketAddress(ipv4, addr.port)
                    } catch (e: Exception) {}
                }
            }
            return addr
        }

        private fun getUid(cm: ConnectivityManager, local: InetSocketAddress, remote: InetSocketAddress): Int {
            val normLocal = normalizeAddr(local)
            val normRemote = normalizeAddr(remote)
            
            // Try standard order
            var uid = cm.getConnectionOwnerUid(6, normLocal, normRemote)
            if (uid != Process.INVALID_UID) return uid
            
            // Try swapped order
            uid = cm.getConnectionOwnerUid(6, normRemote, normLocal)
            if (uid != Process.INVALID_UID) return uid
            
            // Try original un-normalized order
            uid = cm.getConnectionOwnerUid(6, local, remote)
            if (uid != Process.INVALID_UID) return uid
            
            uid = cm.getConnectionOwnerUid(6, remote, local)
            return uid
        }

        /**
         * Resolves the package names of the application that initiated the TCP connection.
         */
        fun getCallingAppPackages(ctx: ChannelHandlerContext): List<String> {
            val context = ContentFilterProxy.appContext ?: return emptyList()
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                return emptyList()
            }
            val remoteSocketAddr = ctx.channel().remoteAddress() as? InetSocketAddress ?: return emptyList()
            val localSocketAddr = ctx.channel().localAddress() as? InetSocketAddress ?: return emptyList()

            try {
                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return emptyList()
                val uid = getUid(cm, remoteSocketAddr, localSocketAddr)
                if (uid != Process.INVALID_UID && uid > 0) {
                    val pm = context.packageManager
                    val packages = pm.getPackagesForUid(uid)
                    if (packages != null) {
                        val pkgList = packages.toList()
                        Log.d(TAG, "🔍 Socket lookup: local=$localSocketAddr, remote=$remoteSocketAddr -> UID=$uid -> packages=$pkgList")
                        return pkgList
                    }
                }
                Log.d(TAG, "⚠️ Socket lookup failed: local=$localSocketAddr, remote=$remoteSocketAddr -> UID=$uid")
            } catch (e: Exception) {
                Log.e(TAG, "Error getting connection owner UID: ${e.message}")
            }
            return emptyList()
        }

        /**
         * Checks if a connection should bypass MITM proxy decryption based on the destination host and the calling app context.
         */
        fun shouldBypass(host: String?, ctx: ChannelHandlerContext): Boolean {
            if (host == null) return false
            val cleanHost = host.lowercase().trim()

            // 0. Automatically bypass raw IP addresses (IPv4 and IPv6)
            if (cleanHost.all { it.isDigit() || it == '.' || it == ':' || it == '[' || it == ']' }) {
                return true
            }

            // 1. Identify calling app package name(s)
            val packages = getCallingAppPackages(ctx)
            if (packages.isNotEmpty()) {
                // Check if any of the packages has a learned bypass for this host
                for (pkg in packages) {
                    val bypassedHosts = appBypassMap[pkg]
                    if (bypassedHosts != null) {
                        if (bypassedHosts.contains(cleanHost) || bypassedHosts.any { cleanHost.endsWith(".$it") }) {
                            Log.i(TAG, "✈️ BYPASS (APP-LEARNED): $cleanHost (App $pkg previously failed handshake on this host)")
                            return true
                        }
                    }
                }

                // If it is a browser, check if it's a domain we statically bypass (ads/telemetry/etc.)
                if (staticBypassDomains.any { cleanHost == it || cleanHost.endsWith(".$it") }) {
                    Log.i(TAG, "🔓 BYPASS (STATIC): $cleanHost (app $packages matches static bypass list)")
                    return true
                }
                
                // Otherwise, decrypt it!
                Log.d(TAG, "🔍 MITM INTERCEPT: $cleanHost (Initiated by app: $packages)")
                return false
            }

            // 2. Fallback to host-only check if calling app couldn't be determined (backward compatibility)
            return shouldBypass(host)
        }

        /**
         * Checks if a host should bypass MITM proxy decryption (using static list or dynamic learned list).
         * Fallback version for backwards-compatibility when calling context is not available.
         */
        fun shouldBypass(host: String?): Boolean {
            if (host == null) return false
            val cleanHost = host.lowercase().trim()

            // 0. Automatically bypass raw IP addresses (IPv4 and IPv6)
            if (cleanHost.all { it.isDigit() || it == '.' || it == ':' || it == '[' || it == ']' }) {
                return true
            }

            // 1. Check static seed list
            if (staticBypassDomains.any { cleanHost == it || cleanHost.endsWith(".$it") }) {
                return true
            }

            // 2. Check dynamic learned bypass set (hosts that failed MITM at runtime)
            if (dynamicBypassHosts.contains(cleanHost)) {
                return true
            }
            // Also check parent domain in dynamic set
            val parts = cleanHost.split(".")
            if (parts.size > 2) {
                for (i in 1 until parts.size - 1) {
                    val parentDomain = parts.subList(i, parts.size).joinToString(".")
                    if (dynamicBypassHosts.contains(parentDomain)) {
                        return true
                    }
                }
            }

            return false
        }

        private fun isNeverBypassDomain(host: String): Boolean {
            val cleanHost = host.lowercase().trim()

            // 1. Google (except subdomains already in staticBypassDomains)
            val isGoogle = cleanHost == "google.com" || cleanHost.endsWith(".google.com") || 
                           cleanHost.contains(Regex("""\bgoogle\.[a-z]{2,3}(\.[a-z]{2})?$"""))
            if (isGoogle) {
                // If it is in the static bypass list, allow it. Otherwise, NEVER dynamically bypass it.
                if (staticBypassDomains.any { cleanHost == it || cleanHost.endsWith(".$it") }) {
                    return false
                }
                return true
            }

            // 2. Other search engines
            val searchEngines = setOf(
                "bing.com", "duckduckgo.com", "yahoo.com", "yandex.com", "yandex.ru", "baidu.com"
            )
            if (searchEngines.any { cleanHost == it || cleanHost.endsWith(".$it") }) {
                return true
            }

            // 3. Any domain that is blocked by local blocklist or contains blocked keywords
            if (SafeDnsResolver.isDomainBlocked(cleanHost) || SafeDnsResolver.isKeywordBlocked(cleanHost)) {
                return true
            }

            return false
        }

        /**
         * Record that a host has failed MITM (e.g. SSL handshake rejected by client due to cert pinning).
         * All future connections to this host from this specific app will bypass MITM decryption.
         */
        fun recordFailure(host: String?, ctx: ChannelHandlerContext?) {
            if (host.isNullOrBlank()) return
            val cleanHost = host.lowercase().trim()
            
            // Do not record raw IP addresses
            if (cleanHost.all { it.isDigit() || it == '.' || it == ':' || it == '[' || it == ']' }) return

            // Never dynamically bypass critical filter targets and search engines
            if (isNeverBypassDomain(cleanHost)) {
                Log.i(TAG, "Not recording failure for $cleanHost because it is a critical filter target.")
                return
            }

            if (ctx != null) {
                val packages = getCallingAppPackages(ctx)
                if (packages.isNotEmpty()) {
                    for (pkg in packages) {
                        val bypassedHosts = appBypassMap.getOrPut(pkg) { ConcurrentHashMap.newKeySet() }
                        if (bypassedHosts.add(cleanHost)) {
                            Log.w(TAG, "🔓 LEARNED BYPASS (APP-ISOLATED): $cleanHost for app $pkg")
                        }
                    }
                    return
                }
            }

            if (dynamicBypassHosts.add(cleanHost)) {
                Log.w(TAG, "🔓 LEARNED BYPASS (GLOBAL): $cleanHost (cert-pinned app detected, future connections will passthrough)")
            }
        }

        /**
         * Record that a host has failed MITM (fallback signature).
         */
        fun recordFailure(host: String?) {
            recordFailure(host, null)
        }

        /**
         * Check if a host is currently bypassed (static or dynamic).
         */
        fun isHostBypassed(host: String): Boolean {
            return shouldBypass(host)
        }

        /**
         * Clear all dynamically learned bypasses. Called when VPN restarts.
         */
        fun clearDynamicBypasses() {
            val countGlobal = dynamicBypassHosts.size
            val countApp = appBypassMap.size
            dynamicBypassHosts.clear()
            appBypassMap.clear()
            if (countGlobal > 0 || countApp > 0) {
                Log.i(TAG, "Cleared $countGlobal global and $countApp app-specific dynamically learned bypass hosts")
            }
        }

        /**
         * Get count of dynamically learned bypass hosts.
         */
        fun getDynamicBypassCount(): Int = dynamicBypassHosts.size + appBypassMap.values.sumOf { it.size }
    }
}
