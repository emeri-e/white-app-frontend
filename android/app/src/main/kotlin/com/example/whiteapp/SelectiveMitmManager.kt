package com.example.whiteapp

import android.util.Log
import io.netty.handler.codec.http.HttpRequest
import org.littleshoot.proxy.MitmManager
import org.littleshoot.proxy.mitm.Authority
import org.littleshoot.proxy.mitm.CertificateSniffingMitmManager
import javax.net.ssl.SSLEngine
import javax.net.ssl.SSLSession

class SelectiveMitmManager(authority: Authority) : MitmManager {
    private val delegate = CertificateSniffingMitmManager(authority)

    // Common certificate-pinned domains that reject custom CA certs.
    // Intercepting these will break app functionality, so we bypass MITM
    // decryption for them and let the Accessibility Service screen scanner protect them.
    private val bypassDomains = setOf(
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
        "twimg.com",
        "t.co"
    )

    private fun shouldBypass(host: String?): Boolean {
        if (host == null) return false
        val cleanHost = host.lowercase().trim()
        return bypassDomains.any { cleanHost == it || cleanHost.endsWith(".$it") }
    }

    override fun serverSslEngine(peerHost: String, peerPort: Int): SSLEngine? {
        if (shouldBypass(peerHost)) {
            Log.i(TAG, "Bypassing MITM for upstream: $peerHost (cert-pinned)")
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
        // Extract Host header to check if we should bypass
        val hostHeader = httpRequest.headers().get("Host")
        val host = hostHeader?.split(":")?.firstOrNull()
        
        if (shouldBypass(host)) {
            Log.i(TAG, "Bypassing MITM for client: $host (cert-pinned)")
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
    }
}
