package com.example.whiteapp

import android.content.Context
import android.util.Log
import org.littleshoot.proxy.HttpProxyServer
import org.littleshoot.proxy.impl.DefaultHttpProxyServer
import java.net.InetSocketAddress

object ContentFilterProxy {
    private const val TAG = "ContentFilterProxy"
    private const val PROXY_PORT = 8888
    private var proxyServer: HttpProxyServer? = null
    private val lock = Any()

    /**
     * Starts the local LittleProxy MITM server.
     */
    fun start(context: Context) {
        synchronized(lock) {
            if (proxyServer != null) {
                Log.w(TAG, "Proxy server is already running.")
                return
            }

            Log.i(TAG, "Starting on-device Content Filter Proxy on port $PROXY_PORT...")
            try {
                // Get or generate Root CA authority parameters
                val authority = CertificateManager.getOrGenerateAuthority(context)

                // Instantiate our custom selective MITM manager
                val mitmManager = SelectiveMitmManager(authority)

                // Create a custom host resolver using SafeDnsResolver
                val safeResolver = org.littleshoot.proxy.HostResolver { host, port ->
                    try {
                        val resolvedIp = SafeDnsResolver.resolve(host)
                        java.net.InetSocketAddress(resolvedIp, port)
                    } catch (e: Exception) {
                        Log.e(TAG, "SafeDnsResolver failed for $host: ${e.message}")
                        throw java.net.UnknownHostException("DNS resolution failed for $host: ${e.message}")
                    }
                }

                // Bootstrap the LittleProxy server
                proxyServer = DefaultHttpProxyServer.bootstrap()
                    .withAddress(InetSocketAddress("127.0.0.1", PROXY_PORT))
                    .withServerResolver(safeResolver)
                    .withManInTheMiddle(mitmManager)
                    .withFiltersSource(ImageScanFilter.createSource(context))
                    .start()

                Log.i(TAG, "Content Filter Proxy started successfully on 127.0.0.1:$PROXY_PORT.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Content Filter Proxy: ${e.message}", e)
                proxyServer = null
            }
        }
    }

    /**
     * Stops the local LittleProxy MITM server.
     */
    fun stop() {
        synchronized(lock) {
            if (proxyServer == null) {
                Log.d(TAG, "Proxy server is already stopped.")
                return
            }

            Log.i(TAG, "Stopping on-device Content Filter Proxy...")
            try {
                proxyServer?.stop()
                Log.i(TAG, "Content Filter Proxy stopped successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping Content Filter Proxy: ${e.message}", e)
            } finally {
                proxyServer = null
            }
        }
    }

    /**
     * Checks if the proxy server is running.
     */
    fun isRunning(): Boolean {
        synchronized(lock) {
            return proxyServer != null
        }
    }
}
