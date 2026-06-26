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

    override fun serverSslEngine(peerHost: String, peerPort: Int): SSLEngine? {
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
        val host = hostHeader?.split(":")?.firstOrNull() ?: ""
        return try {
            val engine = delegate.clientSslEngineFor(httpRequest, serverSslSession)
            Log.d(TAG, "Created client SSLEngine for $host")
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
