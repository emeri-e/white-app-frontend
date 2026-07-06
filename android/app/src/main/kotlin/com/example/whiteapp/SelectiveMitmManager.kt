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

    private fun shouldBypass(host: String?): Boolean {
        if (host == null) return false
        val cleanHost = host.lowercase().trim()

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

    override fun serverSslEngine(peerHost: String, peerPort: Int): SSLEngine? {
        if (shouldBypass(peerHost)) {
            Log.i(TAG, "Bypassing MITM for upstream: $peerHost (cert-pinned/learned)")
            return null
        }
        return try {
            val engine = delegate.serverSslEngine(peerHost, peerPort)
            Log.d(TAG, "Created upstream SSLEngine for $peerHost:$peerPort")
            engine
        } catch (e: Exception) {
            Log.e(TAG, "FAILED to create upstream SSLEngine for $peerHost:$peerPort: ${e.message}", e)
            throw e
        }
    }

    override fun serverSslEngine(): SSLEngine? {
        return try {
            delegate.serverSslEngine()
        } catch (e: Exception) {
            Log.e(TAG, "FAILED to create default upstream SSLEngine: ${e.message}", e)
            throw e
        }
    }

    override fun clientSslEngineFor(httpRequest: HttpRequest, serverSslSession: SSLSession): SSLEngine? {
        val hostHeader = httpRequest.headers().get("Host")
        val host = hostHeader?.split(":")?.firstOrNull()

        if (shouldBypass(host)) {
            Log.i(TAG, "Bypassing MITM for client: $host (cert-pinned/learned)")
            return null
        }
        return try {
            val engine = delegate.clientSslEngineFor(httpRequest, serverSslSession)
            Log.d(TAG, "Created client SSLEngine for $host (forged cert presented)")
            engine
        } catch (e: Exception) {
            Log.e(TAG, "FAILED to create client SSLEngine for $host: ${e.message}", e)
            throw e
        }
    }

    companion object {
        private const val TAG = "SelectiveMitmManager"

        /**
         * Dynamic bypass set: hosts that have been learned at runtime to reject MITM.
         * Thread-safe. Populated by [recordFailure] when connection failures are detected.
         * Persists for the lifetime of the VPN session.
         *
         * Modeled after mitmproxy's tls_passthrough.py "Conservative Strategy":
         * once a host fails even once, bypass it for all future connections.
         */
        private val dynamicBypassHosts: MutableSet<String> =
            ConcurrentHashMap.newKeySet()

        /**
         * Record that a host has failed MITM (e.g. SSL handshake rejected by client due to cert pinning).
         * All future connections to this host will bypass MITM decryption.
         */
        fun recordFailure(host: String?) {
            if (host.isNullOrBlank()) return
            val cleanHost = host.lowercase().trim()
            if (dynamicBypassHosts.add(cleanHost)) {
                Log.w(TAG, "🔓 LEARNED BYPASS: $cleanHost (cert-pinned app detected, future connections will passthrough)")
            }
        }

        /**
         * Check if a host is currently bypassed (static or dynamic).
         * Useful for debugging/logging.
         */
        fun isHostBypassed(host: String): Boolean {
            return dynamicBypassHosts.contains(host.lowercase().trim())
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
