package com.example.whiteapp

import android.content.Context
import android.util.Log
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.UnknownHostException
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap

/**
 * SafeDnsResolver is a lightweight, on-device DNS-over-UDP resolver that queries
 * Cloudflare Family DNS (1.1.1.3) directly. It bypasses the Android system's default DNS
 * resolution (to ensure adult-content filtering is active for the proxy) and implements
 * an in-memory DNS cache to eliminate duplicate UDP roundtrips.
 */
object SafeDnsResolver {
    private const val TAG = "SafeDnsResolver"
    private const val DNS_SERVER = "1.1.1.3"
    private const val DNS_PORT = 53
    private const val TIMEOUT_MS = 3000
    private const val DEFAULT_TTL_MS = 300_000L // 5 minutes default fallback TTL

    // In-memory set of custom blocked domains (loaded from blocked_domains.txt)
    private val blockedDomains = ConcurrentHashMap.newKeySet<String>()

    // In-memory DNS cache: hostname (lowercase) -> Cached IP and expiration timestamp
    private val dnsCache = ConcurrentHashMap<String, CachedDnsResponse>()

    private data class CachedDnsResponse(
        val ipAddress: InetAddress,
        val expirationTimeMillis: Long
    )

    // Simple regex for IPv4 address literals
    private val IPV4_PATTERN = Regex("""^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$""")

    /**
     * Loads the domain blocklist from the local blocked_domains.txt file.
     */
    fun loadBlocklist(context: Context) {
        try {
            val file = context.getDatabasePath("blocked_domains.txt")
            if (file.exists()) {
                val lines = file.readLines()
                    .map { it.lowercase().trim() }
                    .filter { it.isNotEmpty() }
                blockedDomains.clear()
                blockedDomains.addAll(lines)
                Log.i(TAG, "Loaded ${blockedDomains.size} domains into local DNS blocklist.")
            } else {
                Log.w(TAG, "Local DNS blocklist file does not exist.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load local DNS blocklist: ${e.message}", e)
        }
    }

    /**
     * Checks if a domain or any of its parent subdomains are blocked.
     */
    private fun isDomainBlocked(host: String): Boolean {
        if (blockedDomains.isEmpty()) return false
        var target = host.lowercase().trim()
        
        while (target.contains('.')) {
            if (blockedDomains.contains(target)) {
                return true
            }
            val parts = target.split(".", limit = 2)
            if (parts.size < 2) break
            target = parts[1]
        }
        return blockedDomains.contains(target)
    }

    /**
     * Resolves the given host to an InetAddress.
     * If the host is already an IP address literal, returns it directly.
     * Otherwise checks the local cache and blocklist before performing a UDP request.
     */
    fun resolve(host: String): InetAddress {
        val lowercaseHost = host.lowercase().trim()

        // Fast path: if host is already an IP address, return it directly (no DNS query)
        if (IPV4_PATTERN.matches(lowercaseHost) || lowercaseHost.contains(':')) {
            Log.d(TAG, "IP literal detected, skipping DNS: $lowercaseHost")
            return InetAddress.getByName(lowercaseHost)
        }

        // Check custom local blocklist first
        if (isDomainBlocked(lowercaseHost)) {
            Log.w(TAG, "DNS Blocked (Local policy): $lowercaseHost")
            throw UnknownHostException("Domain blocked by local DNS policy: $lowercaseHost")
        }

        val now = System.currentTimeMillis()

        // 1. Check local cache
        val cached = dnsCache[lowercaseHost]
        if (cached != null) {
            if (now < cached.expirationTimeMillis) {
                Log.d(TAG, "Cache HIT: $lowercaseHost -> ${cached.ipAddress.hostAddress}")
                return cached.ipAddress
            } else {
                Log.d(TAG, "Cache EXPIRED: $lowercaseHost. Evicting from cache.")
                dnsCache.remove(lowercaseHost)
            }
        }

        // 2. Perform direct DNS-over-UDP query
        Log.i(TAG, "Cache MISS: Resolving $lowercaseHost via DNS-over-UDP ($DNS_SERVER:53)...")
        val resolvedIp = resolveDirect(lowercaseHost)

        return resolvedIp
    }

    /**
     * Queries 1.1.1.3 directly using standard UDP DNS protocol.
     */
    private fun resolveDirect(host: String): InetAddress {
        val socket = DatagramSocket()
        socket.soTimeout = TIMEOUT_MS

        // Protect socket to ensure it bypasses the VPN tunnel interface
        val vpnInstance = WhiteVpnService.instance
        if (vpnInstance != null) {
            val protected = vpnInstance.protect(socket)
            Log.v(TAG, "Socket protect status: $protected")
        } else {
            Log.w(TAG, "WhiteVpnService instance not available to protect socket.")
        }

        try {
            val query = buildDnsQuery(host)
            val dnsIp = InetAddress.getByName(DNS_SERVER)
            val packet = DatagramPacket(query, query.size, dnsIp, DNS_PORT)
            socket.send(packet)

            val responseBuffer = ByteArray(512)
            val responsePacket = DatagramPacket(responseBuffer, responseBuffer.size)
            socket.receive(responsePacket)

            val dnsResult = parseDnsResponse(responseBuffer, responsePacket.length, host)

            // Cache the result
            val ttlMs = if (dnsResult.ttl > 0) dnsResult.ttl * 1000L else DEFAULT_TTL_MS
            val expiration = System.currentTimeMillis() + ttlMs
            dnsCache[host] = CachedDnsResponse(dnsResult.address, expiration)
            Log.i(TAG, "Resolved & Cached: $host -> ${dnsResult.address.hostAddress} (TTL: ${dnsResult.ttl}s)")

            return dnsResult.address
        } catch (e: UnknownHostException) {
            Log.w(TAG, "Host lookup failed for $host: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "UDP DNS query failed for $host: ${e.message}", e)
            throw UnknownHostException("Failed to resolve $host: ${e.message}")
        } finally {
            try { socket.close() } catch (_: Exception) {}
        }
    }

    private fun buildDnsQuery(host: String): ByteArray {
        val baos = java.io.ByteArrayOutputStream()
        val dos = java.io.DataOutputStream(baos)

        // Header
        dos.writeShort(0x1234) // Transaction ID
        dos.writeShort(0x0100) // Flags: Standard query, recursion desired
        dos.writeShort(0x0001) // Questions count: 1
        dos.writeShort(0x0000) // Answer RRs: 0
        dos.writeShort(0x0000) // Authority RRs: 0
        dos.writeShort(0x0000) // Additional RRs: 0

        // Question: Name (encoded in label components)
        val parts = host.split(".")
        for (part in parts) {
            val bytes = part.toByteArray(Charsets.UTF_8)
            dos.writeByte(bytes.size)
            dos.write(bytes)
        }
        dos.writeByte(0) // Null byte terminates name

        dos.writeShort(0x0001) // Query Type: A (IPv4)
        dos.writeShort(0x0001) // Query Class: IN (Internet)

        return baos.toByteArray()
    }

    private data class DnsResult(
        val address: InetAddress,
        val ttl: Int
    )

    private fun parseDnsResponse(response: ByteArray, length: Int, host: String): DnsResult {
        val buffer = ByteBuffer.wrap(response, 0, length)
        
        val txId = buffer.short
        val flags = buffer.short
        
        // Extract Response Code (rcode: lower 4 bits of flags)
        val rcode = flags.toInt() and 0x0F
        if (rcode != 0) {
            throw UnknownHostException("Domain blocked or unrecognized (rcode: $rcode)")
        }

        val questions = buffer.short.toInt() and 0xFFFF
        val answers = buffer.short.toInt() and 0xFFFF
        val authority = buffer.short.toInt() and 0xFFFF
        val additional = buffer.short.toInt() and 0xFFFF

        // Skip Question Section
        for (i in 0 until questions) {
            skipName(buffer)
            buffer.short // type
            buffer.short // class
        }

        // Parse Answer Section to find the first A-record
        for (i in 0 until answers) {
            skipName(buffer) // name
            val type = buffer.short.toInt() and 0xFFFF
            val clazz = buffer.short.toInt() and 0xFFFF
            val ttl = buffer.int
            val rdLength = buffer.short.toInt() and 0xFFFF

            if (type == 1 && rdLength == 4) { // Type A (IPv4)
                val ipBytes = ByteArray(4)
                buffer.get(ipBytes)
                val address = InetAddress.getByAddress(host, ipBytes)
                return DnsResult(address, ttl)
            } else {
                // Skip rdLength bytes (like CNAME target, IPv6 address, etc.)
                if (buffer.remaining() >= rdLength) {
                    buffer.position(buffer.position() + rdLength)
                } else {
                    break
                }
            }
        }

        throw UnknownHostException("No IPv4 address (A record) returned for $host")
    }

    private fun skipName(buffer: ByteBuffer) {
        if (!buffer.hasRemaining()) return
        var len = buffer.get().toInt() and 0xFF
        while (len > 0) {
            if ((len and 0xC0) == 0xC0) {
                // Compressed name pointer - skip the second byte of the offset pointer
                if (buffer.hasRemaining()) {
                    buffer.get()
                }
                return
            } else {
                // Normal label string - skip the characters
                if (buffer.remaining() >= len) {
                    buffer.position(buffer.position() + len)
                } else {
                    buffer.position(buffer.limit())
                    return
                }
                if (buffer.hasRemaining()) {
                    len = buffer.get().toInt() and 0xFF
                } else {
                    return
                }
            }
        }
    }
}
