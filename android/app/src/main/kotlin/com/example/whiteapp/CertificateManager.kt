package com.example.whiteapp

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.net.Uri
import android.security.KeyChain
import android.util.Log
import android.widget.Toast
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.littleshoot.proxy.mitm.Authority
import org.littleshoot.proxy.mitm.CertificateSniffingMitmManager
import java.io.ByteArrayInputStream
import java.io.File
import java.security.KeyStore
import java.security.Security
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec
import java.nio.charset.StandardCharsets

/**
 * CertificateManager handles the full lifecycle of the WhiteApp Root CA:
 *   1. Registers our own BouncyCastle provider (fixes Android's stripped-down BC conflict)
 *   2. Generates the Root CA keypair + self-signed certificate via littleproxy-mitm
 *   3. Backs up the generated certificate and private key securely (encrypted with ANDROID_ID)
 *      to the public Downloads folder so it survives app uninstalls and reinstalls.
 *   4. Exports the CA certificate to Downloads on Android 11+ for manual installation
 *   5. Launches the standard installer dialog on Android 10 and below
 *   6. Programmatically checks the Android trust store to verify if the certificate is active
 */
object CertificateManager {
    private const val TAG = "CertificateManager"
    private const val ALIAS = "whiteapp-ca"
    private const val PASSWORD = "WhiteAppSecurityPassword"
    private const val PEM_BACKUP_NAME = "whiteapp_ca_pem.bak"
    private const val P12_BACKUP_NAME = "whiteapp_ca_p12.bak"

    private object CryptoUtils {
        private const val ALGORITHM = "AES"
        private const val TRANSFORMATION = "AES/ECB/PKCS5Padding"

        fun encrypt(data: ByteArray, keySeed: String): ByteArray {
            val digest = MessageDigest.getInstance("SHA-256")
            val keyBytes = digest.digest(keySeed.toByteArray(StandardCharsets.UTF_8))
            val secretKey = SecretKeySpec(keyBytes, ALGORITHM)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            return cipher.doFinal(data)
        }

        fun decrypt(data: ByteArray, keySeed: String): ByteArray {
            val digest = MessageDigest.getInstance("SHA-256")
            val keyBytes = digest.digest(keySeed.toByteArray(StandardCharsets.UTF_8))
            val secretKey = SecretKeySpec(keyBytes, ALGORITHM)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey)
            return cipher.doFinal(data)
        }
    }

    /**
     * CRITICAL: Android ships a stripped-down BouncyCastle provider internally.
     * Fix: Remove the system's BC provider and insert our full BouncyCastle
     * library at highest priority BEFORE any crypto operations.
     */
    fun ensureBouncyCastleProvider() {
        try {
            Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME)
            Security.insertProviderAt(BouncyCastleProvider(), 1)
            Log.i(TAG, "Registered full BouncyCastle provider at position 1.")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register BouncyCastle provider: ${e.message}")
        }
    }

    /**
     * Checks programmatically if the WhiteApp Root CA is currently installed
     * and trusted in the Android CA store (System/User store).
     */
    fun isCertificateInstalled(context: Context): Boolean {
        try {
            ensureBouncyCastleProvider()

            val caDir = File(context.filesDir, "ca")
            val pemFile = File(caDir, "$ALIAS.pem")
            val p12File = File(caDir, "$ALIAS.p12")

            // 1. If local files don't exist, try ONLY to restore from backup.
            //    DO NOT generate a new cert here — that would create a new keypair
            //    that won't match the certificate the user already installed.
            if (!pemFile.exists() || !p12File.exists()) {
                Log.i(TAG, "Local CA files missing. Checking for backup files to restore before verifying trust store...")
                if (!caDir.exists()) caDir.mkdirs()
                restoreBackupFiles(context, pemFile, p12File)
            }

            // 2. If we have a local PEM, compare its public key against AndroidCAStore
            if (pemFile.exists()) {
                val pemBytes = pemFile.readBytes()
                val cf = CertificateFactory.getInstance("X.509")
                val localCert = cf.generateCertificate(ByteArrayInputStream(pemBytes)) as? X509Certificate
                if (localCert != null) {
                    val localFingerprint = getFingerprint(localCert)
                    Log.i(TAG, "Local CA fingerprint (SHA-256): $localFingerprint")

                    val keyStore = KeyStore.getInstance("AndroidCAStore")
                    keyStore.load(null, null)
                    val aliases = keyStore.aliases()
                    while (aliases.hasMoreElements()) {
                        val alias = aliases.nextElement() as String
                        val cert = keyStore.getCertificate(alias) as? X509Certificate ?: continue
                        if (getFingerprint(cert) == localFingerprint) {
                            Log.i(TAG, "Verified: Matching WhiteApp Root CA is installed in AndroidCAStore (alias=$alias).")
                            return true
                        }
                    }
                    Log.w(TAG, "No matching certificate found in AndroidCAStore for our local fingerprint.")
                    return false
                }
            }

            // 3. No local PEM at all — We must return false because without the local private key (P12),
            //    we cannot run the MITM proxy even if the user still has an old certificate installed in settings.
            Log.w(TAG, "No local PEM available and backup restoration was unsuccessful. Reporting as not installed.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check AndroidCAStore: ${e.message}", e)
        }
        return false
    }

    /**
     * Returns the SHA-256 fingerprint of an X509Certificate for reliable comparison.
     */
    private fun getFingerprint(cert: X509Certificate): String {
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(cert.encoded)
        return digest.joinToString(":") { "%02X".format(it) }
    }

    /**
     * Initializes and returns the Authority configuration.
     * If the CA files do not exist, tries to restore them from external storage backup.
     * If no backup exists, generates new CA files.
     */
    fun getOrGenerateAuthority(context: Context): Authority {
        ensureBouncyCastleProvider()

        val caDir = File(context.filesDir, "ca").apply { if (!exists()) mkdirs() }
        val pemFile = File(caDir, "$ALIAS.pem")
        val p12File = File(caDir, "$ALIAS.p12")

        // 1. If files don't exist, check if backups exist in public Downloads and restore them
        if (!pemFile.exists() || !p12File.exists()) {
            Log.i(TAG, "Root CA files not found locally. Checking for backup files in Downloads...")
            val restored = restoreBackupFiles(context, pemFile, p12File)
            if (restored) {
                Log.i(TAG, "Successfully restored CA certificate and private key from backup.")
            }
        }

        // Auto-detect and purge old certificates with invalid metadata
        if (pemFile.exists()) {
            try {
                val pemBytes = pemFile.readBytes()
                val cf = CertificateFactory.getInstance("X.509")
                val cert = cf.generateCertificate(ByteArrayInputStream(pemBytes)) as X509Certificate
                val subjectName = cert.subjectDN.name
                if (subjectName.contains("C=WhiteApp") || subjectName.contains("Country=WhiteApp")) {
                    Log.i(TAG, "Purging legacy certificate with invalid country code: $subjectName")
                    pemFile.delete()
                    p12File.delete()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to parse existing certificate, deleting to regenerate: ${e.message}")
                pemFile.delete()
                p12File.delete()
            }
        }

        val authority = Authority(
            caDir,
            ALIAS,
            PASSWORD.toCharArray(),
            "WhiteApp Root CA",      // CN (Common Name)
            "WhiteApp",              // O  (Organization)
            "WhiteApp Security",     // OU (Organizational Unit)
            "US",                    // C  (Country)
            "California"             // ST (State)
        )

        if (!pemFile.exists() || !p12File.exists()) {
            Log.i(TAG, "Root CA files not found. Generating new root certificate...")
            try {
                CertificateSniffingMitmManager(authority)
                Log.i(TAG, "Root CA generated successfully at ${pemFile.absolutePath}")
                
                // Immediately save backup
                createBackupFiles(context, pemFile, p12File)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to generate Root CA: ${e.message}", e)
            }
        }

        return authority
    }

    /**
     * Exports the CA certificate to the public Downloads directory.
     * This is required on Android 11+ so the user can manually select it in Settings.
     */
    fun exportCertificateToDownloads(context: Context): String? {
        try {
            val caDir = File(context.filesDir, "ca")
            val pemFile = File(caDir, "$ALIAS.pem")

            if (!pemFile.exists()) {
                getOrGenerateAuthority(context)
            }

            if (!pemFile.exists()) {
                Log.e(TAG, "CA PEM file still does not exist after generation attempt.")
                return null
            }

            val pemBytes = pemFile.readBytes()
            val cf = CertificateFactory.getInstance("X.509")
            val cert = cf.generateCertificate(ByteArrayInputStream(pemBytes)) as X509Certificate
            val derBytes = cert.encoded

            var fileName = "whiteapp-ca.crt"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                val selectionArgs = arrayOf(fileName)

                try {
                    resolver.delete(uri, selection, selectionArgs)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to clear old certificate: ${e.message}")
                }

                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/x-x509-ca-cert")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }

                var insertedUri: Uri? = null
                try {
                    insertedUri = resolver.insert(uri, contentValues)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to insert default filename: ${e.message}. Trying with timestamp.")
                }

                if (insertedUri == null) {
                    // Fallback to timestamped name to avoid naming/ownership conflicts
                    fileName = "whiteapp-ca-${System.currentTimeMillis() / 1000}.crt"
                    val fallbackValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "application/x-x509-ca-cert")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    }
                    try {
                        insertedUri = resolver.insert(uri, fallbackValues)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to insert fallback timestamp filename: ${e.message}")
                    }
                }

                if (insertedUri != null) {
                    resolver.openOutputStream(insertedUri)?.use { outputStream ->
                        outputStream.write(derBytes)
                    }
                    Log.i(TAG, "Exported CA cert to Downloads folder: $insertedUri")
                    return "Downloads/$fileName"
                }
            } else {
                @Suppress("DEPRECATION")
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloadDir.exists()) {
                    downloadDir.mkdirs()
                }
                val targetFile = File(downloadDir, fileName)
                targetFile.writeBytes(derBytes)
                Log.i(TAG, "Exported CA cert to legacy Downloads: ${targetFile.absolutePath}")
                return "Downloads/$fileName"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to export CA cert: ${e.message}", e)
        }
        return null
    }

    /**
     * Initiates the CA certificate installation.
     *   - Android 11+ (API 30+): Exports the certificate to Downloads and opens the Security Settings.
     *   - Android 10 and below: Launches the standard KeyChain installation dialog.
     */
    fun installCertificate(context: Context) {
        ensureBouncyCastleProvider()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+: KeyChain.createInstallIntent is blocked for CA certificates.
                // We export to public Downloads and redirect to system security settings.
                val exportedPath = exportCertificateToDownloads(context)
                if (exportedPath != null) {
                    Toast.makeText(
                        context,
                        "Saved as: $exportedPath. Please install manually in settings.",
                        Toast.LENGTH_LONG
                    ).show()

                    val intent = Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Log.i(TAG, "Exported certificate to $exportedPath and opened security settings.")
                } else {
                    Toast.makeText(context, "Failed to save certificate to Downloads", Toast.LENGTH_SHORT).show()
                }
            } else {
                // Android 10 and below: KeyChain.createInstallIntent works automatically.
                val caDir = File(context.filesDir, "ca")
                val pemFile = File(caDir, "$ALIAS.pem")

                if (!pemFile.exists()) {
                    getOrGenerateAuthority(context)
                }

                if (pemFile.exists()) {
                    val pemBytes = pemFile.readBytes()
                    val cf = CertificateFactory.getInstance("X.509")
                    val cert = cf.generateCertificate(ByteArrayInputStream(pemBytes)) as X509Certificate
                    val derBytes = cert.encoded

                    val intent = KeyChain.createInstallIntent().apply {
                        putExtra(KeyChain.EXTRA_CERTIFICATE, derBytes)
                        putExtra(KeyChain.EXTRA_NAME, "WhiteApp Root CA")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Log.i(TAG, "Launched KeyChain installer for Android <= 10.")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error installing certificate: ${e.message}", e)
        }
    }

    private fun createBackupFiles(context: Context, pemFile: File, p12File: File) {
        if (pemFile.exists()) {
            saveBackupFile(context, pemFile, PEM_BACKUP_NAME)
        }
        if (p12File.exists()) {
            saveBackupFile(context, p12File, P12_BACKUP_NAME)
        }
    }

    private data class DecryptedBackup(
        val uri: Uri,
        val displayName: String,
        val dateModified: Long,
        val decryptedBytes: ByteArray,
        val fingerprint: String
    )

    private fun extractFingerprintFromP12(decryptedBytes: ByteArray): String? {
        return try {
            val keyStore = KeyStore.getInstance("PKCS12")
            keyStore.load(ByteArrayInputStream(decryptedBytes), PASSWORD.toCharArray())
            val aliases = keyStore.aliases()
            if (aliases.hasMoreElements()) {
                val alias = aliases.nextElement()
                val cert = keyStore.getCertificate(alias) as? X509Certificate
                if (cert != null) {
                    getFingerprint(cert)
                } else null
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun extractFingerprintFromPem(decryptedBytes: ByteArray): String? {
        return try {
            val cf = CertificateFactory.getInstance("X.509")
            val cert = cf.generateCertificate(ByteArrayInputStream(decryptedBytes)) as? X509Certificate
            if (cert != null) {
                getFingerprint(cert)
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun readBytesFromUri(context: Context, uri: Uri): ByteArray? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read bytes from URI $uri: ${e.message}")
            null
        }
    }

    private fun isFingerprintInstalled(fingerprint: String): Boolean {
        try {
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null, null)
            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val alias = aliases.nextElement() as String
                val cert = keyStore.getCertificate(alias) as? X509Certificate ?: continue
                if (getFingerprint(cert) == fingerprint) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to check AndroidCAStore for fingerprint: ${e.message}")
        }
        return false
    }

    private fun restoreBackupFiles(context: Context, pemFile: File, p12File: File): Boolean {
        try {
            val keySeed = android.provider.Settings.Secure.getString(context.contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: "default_seed"
            val rawCandidates = mutableListOf<Triple<Uri, String, Long>>() // Triple(Uri, displayName, dateModified)
            val uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val projection = arrayOf(
                    MediaStore.MediaColumns._ID,
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    MediaStore.MediaColumns.DATE_MODIFIED
                )
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"
                val selectionArgs = arrayOf("whiteapp_ca_%")
                
                context.contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                        val name = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)) ?: ""
                        val dateModified = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED))
                        val fileUri = android.content.ContentUris.withAppendedId(uri, id)
                        rawCandidates.add(Triple(fileUri, name, dateModified))
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (downloadDir.exists()) {
                    val files = downloadDir.listFiles()
                    if (files != null) {
                        for (file in files) {
                            val name = file.name
                            if (name.startsWith("whiteapp_ca_") && name.endsWith(".bak")) {
                                val fileUri = Uri.fromFile(file)
                                rawCandidates.add(Triple(fileUri, name, file.lastModified() / 1000))
                            }
                        }
                    }
                }
            }

            Log.i(TAG, "Found ${rawCandidates.size} raw backup files matching 'whiteapp_ca_%' in Downloads.")

            val pemBackups = mutableListOf<DecryptedBackup>()
            val p12Backups = mutableListOf<DecryptedBackup>()

            for (candidate in rawCandidates) {
                val fileUri = candidate.first
                val name = candidate.second
                val dateModified = candidate.third

                val encryptedBytes = readBytesFromUri(context, fileUri) ?: continue
                val decryptedBytes = try {
                    CryptoUtils.decrypt(encryptedBytes, keySeed)
                } catch (e: Exception) {
                    null
                } ?: continue

                if (name.startsWith("whiteapp_ca_pem")) {
                    val fingerprint = extractFingerprintFromPem(decryptedBytes)
                    if (fingerprint != null) {
                        pemBackups.add(DecryptedBackup(fileUri, name, dateModified, decryptedBytes, fingerprint))
                    }
                } else if (name.startsWith("whiteapp_ca_p12")) {
                    val fingerprint = extractFingerprintFromP12(decryptedBytes)
                    if (fingerprint != null) {
                        p12Backups.add(DecryptedBackup(fileUri, name, dateModified, decryptedBytes, fingerprint))
                    }
                }
            }

            Log.i(TAG, "Successfully decrypted and parsed ${pemBackups.size} PEM backups and ${p12Backups.size} P12 backups.")

            // Match PEM and P12 backups by certificate fingerprint
            val matchedPairs = mutableListOf<Pair<DecryptedBackup, DecryptedBackup>>() // Pair(PEM, P12)
            for (pemBackup in pemBackups) {
                val p12Backup = p12Backups.find { it.fingerprint == pemBackup.fingerprint }
                if (p12Backup != null) {
                    matchedPairs.add(Pair(pemBackup, p12Backup))
                }
            }

            Log.i(TAG, "Found ${matchedPairs.size} matching PEM/P12 certificate-key pairs in backups.")

            var selectedPair: Pair<DecryptedBackup, DecryptedBackup>? = null

            // Sort matched pairs by PEM date modified descending (newest first)
            val sortedPairs = matchedPairs.sortedByDescending { it.first.dateModified }

            // Step A: Find the newest pair matching a certificate currently installed/trusted in Android settings
            for (pair in sortedPairs) {
                if (isFingerprintInstalled(pair.first.fingerprint)) {
                    selectedPair = pair
                    Log.i(TAG, "Found backup pair matching currently installed certificate (fingerprint: ${pair.first.fingerprint}, pem: ${pair.first.displayName}, p12: ${pair.second.displayName}). Selecting for restoration.")
                    break
                }
            }

            // Step B: Fallback - pick the newest pair overall
            if (selectedPair == null && sortedPairs.isNotEmpty()) {
                selectedPair = sortedPairs.first()
                Log.w(TAG, "No backup pair matched an installed certificate. Selecting the newest overall backup pair (pem: ${selectedPair.first.displayName}, p12: ${selectedPair.second.displayName}) for restoration.")
            }

            // Write decrypted bytes to app's secure files directory
            if (selectedPair != null) {
                pemFile.writeBytes(selectedPair.first.decryptedBytes)
                p12File.writeBytes(selectedPair.second.decryptedBytes)
                Log.i(TAG, "Successfully restored matching certificate pair: PEM=${selectedPair.first.displayName}, P12=${selectedPair.second.displayName}")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring backup files: ${e.message}", e)
        }
        return false
    }

    private fun saveBackupFile(context: Context, sourceFile: File, displayName: String) {
        try {
            val keySeed = android.provider.Settings.Secure.getString(context.contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: "default_seed"
            val encryptedBytes = CryptoUtils.encrypt(sourceFile.readBytes(), keySeed)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                
                // Clear any existing old backup row
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                val selectionArgs = arrayOf(displayName)
                try {
                    resolver.delete(uri, selection, selectionArgs)
                } catch (e: Exception) {}

                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }

                var insertedUri: Uri? = null
                try {
                    insertedUri = resolver.insert(uri, contentValues)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to insert default backup: ${e.message}. Trying with timestamp.")
                }

                if (insertedUri == null) {
                    val nameWithoutExtension = displayName.substringBeforeLast(".")
                    val extension = displayName.substringAfterLast(".")
                    val fallbackName = "${nameWithoutExtension}_${System.currentTimeMillis() / 1000}.$extension"
                    val fallbackValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fallbackName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    }
                    try {
                        insertedUri = resolver.insert(uri, fallbackValues)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to insert fallback timestamp backup: ${e.message}")
                    }
                }

                if (insertedUri != null) {
                    resolver.openOutputStream(insertedUri)?.use { output ->
                        output.write(encryptedBytes)
                    }
                    Log.i(TAG, "Saved encrypted CA backup to Downloads: $displayName")
                }
            } else {
                @Suppress("DEPRECATION")
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val targetFile = File(downloadDir, displayName)
                targetFile.writeBytes(encryptedBytes)
                Log.i(TAG, "Saved encrypted CA backup to legacy Downloads: ${targetFile.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save backup file $displayName: ${e.message}", e)
        }
    }

}
