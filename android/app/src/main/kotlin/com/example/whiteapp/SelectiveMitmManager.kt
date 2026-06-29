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

    // Certificate-pinned domains that reject custom CA certs.
    // Returning null SSLEngine for these causes LittleProxy to fall back to
    // a raw TCP tunnel passthrough — the connection is forwarded without
    // certificate impersonation, so cert-pinned apps continue to function.
    //
    // Note: LittleProxy internally throws an NPE when it receives null from
    // serverSslEngine() (at ProxyConnection.encrypt line 337), but this is
    // safely caught by Netty's DefaultPromise handler and logged as a warning.
    // The connection is cleaned up and the app retries via direct connection.
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
        "t.co",
        // Google Services & Pinned App bypasses (maps, youtube, play store, gmail, system sync)
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
