package com.example.whiteapp

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
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
            // 1. Ensure local CA files always exist by calling getOrGenerateAuthority.
            //    This will restore from backup or generate new files if needed.
            getOrGenerateAuthority(context)

            val caDir = File(context.filesDir, "ca")
            val pemFile = File(caDir, "$ALIAS.pem")

            // 2. If we still don't have a local PEM (generation somehow failed), not installed
            if (!pemFile.exists()) {
                Log.w(TAG, "Local CA PEM file does not exist even after generation. Reporting as NOT installed.")
                return false
            }

            // 3. Load our local CA certificate
            val pemBytes = pemFile.readBytes()
            val cf = CertificateFactory.getInstance("X.509")
            val localCert = cf.generateCertificate(ByteArrayInputStream(pemBytes)) as? X509Certificate
            if (localCert == null) {
                Log.e(TAG, "Failed to parse local PEM certificate. Reporting as NOT installed.")
                return false
            }

            // 4. Check if a certificate with matching public key is installed in the system trust store
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null, null)
            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val alias = aliases.nextElement() as String
                val cert = keyStore.getCertificate(alias) as? X509Certificate
                if (cert != null && cert.publicKey == localCert.publicKey) {
                    Log.i(TAG, "Verified: Matching WhiteApp Root CA is installed and active in AndroidCAStore ($alias).")
                    return true
                }
            }
            Log.w(TAG, "No matching certificate found in AndroidCAStore for our local public key.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check AndroidCAStore: ${e.message}", e)
        }
        return false
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

            val fileName = "whiteapp-ca.crt"

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

                val insertedUri = resolver.insert(uri, contentValues)
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

    private fun restoreBackupFiles(context: Context, pemFile: File, p12File: File): Boolean {
        val pemRestored = restoreBackupFile(context, pemFile, PEM_BACKUP_NAME)
        val p12Restored = restoreBackupFile(context, p12File, P12_BACKUP_NAME)
        return pemRestored && p12Restored
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
                val insertedUri = resolver.insert(uri, contentValues)
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

    private fun restoreBackupFile(context: Context, destFile: File, displayName: String): Boolean {
        try {
            val keySeed = android.provider.Settings.Secure.getString(context.contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: "default_seed"
            val resolver = context.contentResolver
            
            val backupBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val projection = arrayOf(MediaStore.MediaColumns._ID)
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                val selectionArgs = arrayOf(displayName)
                var fileUri: android.net.Uri? = null
                
                resolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                        fileUri = android.content.ContentUris.withAppendedId(uri, id)
                    }
                }
                
                fileUri?.let { targetUri ->
                    resolver.openInputStream(targetUri)?.use { input ->
                        input.readBytes()
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val targetFile = File(downloadDir, displayName)
                if (targetFile.exists()) targetFile.readBytes() else null
            }

            if (backupBytes != null && backupBytes.isNotEmpty()) {
                val decryptedBytes = CryptoUtils.decrypt(backupBytes, keySeed)
                destFile.writeBytes(decryptedBytes)
                Log.i(TAG, "Successfully restored CA backup file: $displayName")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore backup file $displayName: ${e.message}", e)
        }
        return false
    }
}
