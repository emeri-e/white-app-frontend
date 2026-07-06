package com.example.whiteapp

import android.util.Log
import io.netty.handler.codec.http.HttpRequest
import org.littleshoot.proxy.MitmManager
import org.littleshoot.proxy.mitm.Authority
import org.littleshoot.proxy.mitm.CertificateSniffingMitmManager
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
            "gmail.com"
        )

        // Dynamic bypass set: hosts that have been learned at runtime to reject MITM.
        private val dynamicBypassHosts: MutableSet<String> =
            ConcurrentHashMap.newKeySet()

        /**
         * Checks if a host should bypass MITM proxy decryption (using static list or dynamic learned list).
         */
        fun shouldBypass(host: String?): Boolean {
            if (host == null) return false
            val cleanHost = host.lowercase().trim()

            // 0. Automatically bypass raw IP addresses (IPv4 and IPv6)
            // They are used by background system APIs/pinned apps and never contain browser-filterable pages.
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
            // Also check parent domain in dynamic set (e.g. "api.example.com" matches "example.com")
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

        /**
         * Record that a host has failed MITM (e.g. SSL handshake rejected by client due to cert pinning).
         * All future connections to this host will bypass MITM decryption.
         */
        fun recordFailure(host: String?) {
            if (host.isNullOrBlank()) return
            val cleanHost = host.lowercase().trim()
            
            // Do not record raw IP addresses
            if (cleanHost.all { it.isDigit() || it == '.' || it == ':' || it == '[' || it == ']' }) return

            if (dynamicBypassHosts.add(cleanHost)) {
                Log.w(TAG, "🔓 LEARNED BYPASS: $cleanHost (cert-pinned app detected, future connections will passthrough)")
            }

            val registrable = getRegistrableDomain(cleanHost)
            if (registrable != cleanHost && registrable.isNotEmpty()) {
                if (dynamicBypassHosts.add(registrable)) {
                    Log.w(TAG, "🔓 LEARNED REGISTERED DOMAIN BYPASS: $registrable (derived from $cleanHost)")
                }
            }
        }

        /**
         * Extract the registrable domain of a host name (e.g. "api.example.com" -> "example.com").
         */
        private fun getRegistrableDomain(host: String): String {
            val parts = host.split(".")
            if (parts.size <= 2) return host

            // Check for common double TLDs (e.g., co.uk, com.br, net.ru, co.jp)
            val secondToLast = parts[parts.size - 2]
            val last = parts.last()
            val isDoubleTld = (last.length == 2 && (secondToLast == "com" || secondToLast == "co" || secondToLast == "net" || secondToLast == "org" || secondToLast == "edu" || secondToLast == "gov"))

            return if (isDoubleTld && parts.size >= 3) {
                parts.subList(parts.size - 3, parts.size).joinToString(".")
            } else {
                parts.subList(parts.size - 2, parts.size).joinToString(".")
            }
        }

        /**
         * Check if a host is currently bypassed (static or dynamic).
         * Useful for debugging/logging.
         */
        fun isHostBypassed(host: String): Boolean {
            return shouldBypass(host)
        }

        /**
         * Clear all dynamically learned bypasses. Called when VPN restarts.
         */
        fun clearDynamicBypasses() {
            val count = dynamicBypassHosts.size
            dynamicBypassHosts.clear()
            if (count > 0) {
                Log.i(TAG, "Cleared $count dynamically learned bypass hosts")
            }
        }

        /**
         * Get count of dynamically learned bypass hosts (for telemetry/debugging).
         */
        fun getDynamicBypassCount(): Int = dynamicBypassHosts.size
    }
}
