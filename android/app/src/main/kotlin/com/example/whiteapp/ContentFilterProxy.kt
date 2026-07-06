package com.example.whiteapp

import android.content.Context
import android.util.Log
import org.littleshoot.proxy.HttpProxyServer
import org.littleshoot.proxy.impl.DefaultHttpProxyServer
import java.net.InetSocketAddress

object ContentFilterProxy {
    private const val TAG = "ContentFilterProxy"
    private const val PROXY_PORT = 8888
    private const val MITM_PORT = 8889
    private var proxyServer: HttpProxyServer? = null
    private var routingProxyServer: ConnectProxyServer? = null
    private val lock = Any()

    /**
     * Starts the local LittleProxy MITM server and the Netty routing proxy.
     */
    fun start(context: Context) {
        synchronized(lock) {
            if (proxyServer != null || routingProxyServer != null) {
                Log.w(TAG, "Proxy server is already running.")
                return
            }

            Log.i(TAG, "Starting on-device Content Filter Proxy stack (Routing on $PROXY_PORT, MITM on $MITM_PORT)...")
            try {
                // Load local DNS blocklist
                SafeDnsResolver.loadBlocklist(context)

                // Clear any dynamically learned MITM bypasses from previous sessions
                SelectiveMitmManager.clearDynamicBypasses()

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

                // Bootstrap the LittleProxy server on MITM_PORT (8889)
                proxyServer = DefaultHttpProxyServer.bootstrap()
                    .withAddress(InetSocketAddress("127.0.0.1", MITM_PORT))
                    .withServerResolver(safeResolver)
                    .withManInTheMiddle(mitmManager)
                    .withFiltersSource(ImageScanFilter.createSource(context))
                    .start()

                Log.i(TAG, "LittleProxy MITM server started on 127.0.0.1:$MITM_PORT.")

                // Bootstrap the routing proxy on PROXY_PORT (8888)
                routingProxyServer = ConnectProxyServer(PROXY_PORT, MITM_PORT)
                routingProxyServer?.start()

                Log.i(TAG, "Content Filter Proxy stack started successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Content Filter Proxy stack: ${e.message}", e)
                stop()
            }
        }
    }

    /**
     * Stops the local LittleProxy MITM server and Netty routing proxy.
     */
    fun stop() {
        synchronized(lock) {
            if (proxyServer == null && routingProxyServer == null) {
                Log.d(TAG, "Proxy servers are already stopped.")
                return
            }

            Log.i(TAG, "Stopping on-device Content Filter Proxy stack...")
            
            try {
                routingProxyServer?.stop()
                Log.i(TAG, "Routing proxy stopped successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping routing proxy: ${e.message}", e)
            } finally {
                routingProxyServer = null
            }

            try {
                proxyServer?.stop()
                Log.i(TAG, "LittleProxy MITM server stopped successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping LittleProxy server: ${e.message}", e)
            } finally {
                proxyServer = null
            }
            
            Log.i(TAG, "Content Filter Proxy stack stopped completely.")
        }
    }

    /**
     * Checks if the proxy server stack is running.
     */
    fun isRunning(): Boolean {
        synchronized(lock) {
            return proxyServer != null || routingProxyServer != null
        }
    }
}
