package com.example.hyperlink

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.ContentUris
import android.os.Build
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import android.provider.ContactsContract
import java.security.KeyPairGenerator
import java.security.KeyFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import java.security.PublicKey
import java.security.PrivateKey
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec
import javax.crypto.spec.GCMParameterSpec
import android.util.Base64
import java.security.SecureRandom

class MainActivity : FlutterActivity() {

    private val FILE_CHANNEL = "com.hyperlink/files"
    private val WIFI_DIRECT_CHANNEL = "com.hyperlink/wifi_direct"
    private val CONTACTS_CHANNEL = "com.hyperlink/contacts"
    private val CRYPTO_CHANNEL = "com.hyperlink/crypto"
    private val ACCESSIBILITY_CHANNEL = "com.hyperlink/accessibility"
    private val FILE_PICK_CODE = 1001

    private var pendingResult: MethodChannel.Result? = null
    private lateinit var wifiDirectManager: WiFiDirectManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Accessibility channel ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityServiceEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Contacts channel ──────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getContacts") {
                    result.success(getContacts())
                } else {
                    result.notImplemented()
                }
            }

        // ── Crypto channel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRYPTO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "generateKeyPair" -> {
                        try {
                            result.success(CryptoHelper.generateKeyPair())
                        } catch (e: Exception) {
                            result.error("KEYGEN_FAILED", e.message, null)
                        }
                    }
                    "encryptText" -> {
                        try {
                            val text = call.argument<String>("text")!!
                            val publicKey = call.argument<String>("publicKey")!!
                            val map = CryptoHelper.encrypt(text.toByteArray(Charsets.UTF_8), publicKey)
                            val encDataB64 = Base64.encodeToString(map["encryptedData"] as ByteArray, Base64.NO_WRAP)
                            result.success(mapOf(
                                "encryptedKey" to map["encryptedKey"],
                                "iv" to map["iv"],
                                "encryptedData" to encDataB64
                            ))
                        } catch (e: Exception) {
                            result.error("ENCRYPT_FAILED", e.message, null)
                        }
                    }
                    "decryptText" -> {
                        try {
                            val encryptedKey = call.argument<String>("encryptedKey")!!
                            val iv = call.argument<String>("iv")!!
                            val encryptedData = call.argument<String>("encryptedData")!!
                            val privateKey = call.argument<String>("privateKey")!!
                            val decryptedBytes = CryptoHelper.decrypt(
                                encryptedKey,
                                iv,
                                Base64.decode(encryptedData, Base64.NO_WRAP),
                                privateKey
                            )
                            result.success(String(decryptedBytes, Charsets.UTF_8))
                        } catch (e: Exception) {
                            result.error("DECRYPT_FAILED", e.message, null)
                        }
                    }
                    "encryptBytes" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")!!
                            val publicKey = call.argument<String>("publicKey")!!
                            val map = CryptoHelper.encrypt(bytes, publicKey)
                            result.success(mapOf(
                                "encryptedKey" to map["encryptedKey"],
                                "iv" to map["iv"],
                                "encryptedData" to map["encryptedData"]
                            ))
                        } catch (e: Exception) {
                            result.error("ENCRYPT_FAILED", e.message, null)
                        }
                    }
                    "decryptBytes" -> {
                        try {
                            val encryptedKey = call.argument<String>("encryptedKey")!!
                            val iv = call.argument<String>("iv")!!
                            val encryptedData = call.argument<ByteArray>("encryptedData")!!
                            val privateKey = call.argument<String>("privateKey")!!
                            val decryptedBytes = CryptoHelper.decrypt(
                                encryptedKey,
                                iv,
                                encryptedData,
                                privateKey
                            )
                            result.success(decryptedBytes)
                        } catch (e: Exception) {
                            result.error("DECRYPT_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── File channel ──────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(intent, FILE_PICK_CODE)
                    }
                    "saveFile" -> {
                        val fileName = call.argument<String>("fileName")!!
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val savedUri = saveToDownloads(fileName, bytes)
                        if (savedUri != null) {
                            result.success(savedUri)
                        } else {
                            result.error("SAVE_FAILED", "Could not save file", null)
                        }
                    }
                    "loadBackupFile" -> {
                        val fileName = call.argument<String>("fileName")!!
                        val bytes = loadFromDownloads(fileName)
                        result.success(bytes)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── WiFi Direct channel ───────────────────────────────────────────
        wifiDirectManager = WiFiDirectManager(this)
        wifiDirectManager.register()

        val wifiChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_DIRECT_CHANNEL
        )

        wifiDirectManager.onPeersChanged = { peers ->
            runOnUiThread {
                wifiChannel.invokeMethod("onPeersChanged", peers)
            }
        }

        wifiDirectManager.onConnectionChanged = { info ->
            runOnUiThread {
                wifiChannel.invokeMethod("onConnectionChanged", info)
            }
        }

        wifiChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverPeers" -> {
                    wifiDirectManager.discoverPeers(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("DISCOVERY_FAILED", "Reason: $it", null) }
                    )
                }
                "getPeers" -> {
                    result.success(wifiDirectManager.getPeers())
                }
                "connectPeer" -> {
                    val address = call.argument<String>("address")!!
                    wifiDirectManager.connect(
                        address = address,
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("CONNECT_FAILED", "Reason: $it", null) }
                    )
                }
                "createGroup" -> {
                    wifiDirectManager.createGroup(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("GROUP_FAILED", "Reason: $it", null) }
                    )
                }
                "removeGroup" -> {
                    wifiDirectManager.removeGroup(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("REMOVE_FAILED", "Reason: $it", null) }
                    )
                }
                "getConnectionInfo" -> {
                    result.success(wifiDirectManager.getConnectionInfo())
                }
                "disconnect" -> {
                    wifiDirectManager.disconnect(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("DISCONNECT_FAILED", "Reason: $it", null) }
                    )
                }
                "setDeviceName" -> {
                    val name = call.argument<String>("name")!!
                    wifiDirectManager.setDeviceName(
                        newName = name,
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("RENAME_FAILED", "Reason: $it", null) }
                    )
                }
                "startAdvertising" -> {
                    val hash = call.argument<String>("hash")!!
                    wifiDirectManager.startAdvertising(
                        hash = hash,
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("ADVERTISE_FAILED", "Reason: $it", null) }
                    )
                }
                "stopAdvertising" -> {
                    wifiDirectManager.stopAdvertising(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("STOP_ADVERTISE_FAILED", "Reason: $it", null) }
                    )
                }
                "startServiceDiscovery" -> {
                    wifiDirectManager.startServiceDiscovery(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("SERVICE_DISCOVERY_FAILED", "Reason: $it", null) }
                    )
                }
                "stopServiceDiscovery" -> {
                    wifiDirectManager.stopServiceDiscovery(
                        onSuccess = { result.success(true) },
                        onFailure = { result.error("STOP_SERVICE_DISCOVERY_FAILED", "Reason: $it", null) }
                    )
                }
                "clearDiscoveredPeers" -> {
                    wifiDirectManager.clearDiscoveredPeers()
                    result.success(true)
                }
                "isWifiEnabled" -> {
                    result.success(wifiDirectManager.isWifiEnabled())
                }
                "openWifiSettings" -> {
                    wifiDirectManager.openWifiSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        wifiDirectManager.unregister()
        super.onDestroy()
    }

    // ── Contacts retrieval helper ─────────────────────────────────────────
    private fun getContacts(): List<Map<String, String>> {
        val contactsList = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null,
                null,
                null
            )
            cursor?.use {
                val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val phoneIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (it.moveToNext()) {
                    val name = if (nameIdx >= 0) it.getString(nameIdx) else ""
                    val phone = if (phoneIdx >= 0) it.getString(phoneIdx) else ""
                    contactsList.add(mapOf("name" to name, "phone" to phone))
                }
            }
        } catch (e: Exception) {}
        return contactsList
    }

    // ── File helpers ──────────────────────────────────────────────────────

    private fun saveToDownloads(fileName: String, bytes: ByteArray): String? {
        return try {
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, getMimeType(fileName))
                put(MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/Hyperlink")
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues
            )
            uri?.let {
                contentResolver.openOutputStream(it)?.use { stream ->
                    stream.write(bytes)
                }
                it.toString()
            }
        } catch (e: Exception) { null }
    }

    private fun loadFromDownloads(fileName: String): ByteArray? {
        // Try direct file path first (works if MANAGE_EXTERNAL_STORAGE is granted)
        try {
            val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val file = File(downloadDir, "Hyperlink/$fileName")
            if (file.exists()) {
                android.util.Log.d("WFDBackup", "Direct file load successful: ${file.absolutePath}")
                return file.readBytes()
            }
        } catch (e: Exception) {
            android.util.Log.e("WFDBackup", "Direct file load failed, trying MediaStore...", e)
        }

        // Fallback to MediaStore query
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val projection = arrayOf(MediaStore.Downloads._ID)
                val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} LIKE ?"
                val selectionArgs = arrayOf(fileName, "%Download/Hyperlink%")

                contentResolver.query(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                        val id = cursor.getLong(idColumn)
                        val uri = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)
                        contentResolver.openInputStream(uri)?.use { inputStream ->
                            inputStream.readBytes()
                        }
                    } else null
                }
            } else {
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val file = File(dir, "Hyperlink/$fileName")
                if (file.exists()) {
                    file.readBytes()
                } else null
            }
        } catch (e: Exception) {
            android.util.Log.e("WFDBackup", "MediaStore load failed", e)
            null
        }
    }

    private fun getMimeType(fileName: String): String {
        return when {
            fileName.endsWith(".jpg", true) ||
                    fileName.endsWith(".jpeg", true) -> "image/jpeg"
            fileName.endsWith(".png", true) -> "image/png"
            fileName.endsWith(".mp4", true) -> "video/mp4"
            fileName.endsWith(".pdf", true) -> "application/pdf"
            fileName.endsWith(".mp3", true) -> "audio/mpeg"
            fileName.endsWith(".gif", true) -> "image/gif"
            fileName.endsWith(".zip", true) -> "application/zip"
            else -> "application/octet-stream"
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_PICK_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                val path = copyUriToCache(uri)
                pendingResult?.success(path)
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }

    private fun copyUriToCache(uri: Uri): String {
        val fileName = getFileName(uri) ?: "file_${System.currentTimeMillis()}"
        val cacheFile = File(cacheDir, fileName)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(cacheFile).use { output -> input.copyTo(output) }
        }
        return cacheFile.absolutePath
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(
                    android.provider.OpenableColumns.DISPLAY_NAME
                )
                if (idx >= 0) name = cursor.getString(idx)
            }
        }
        return name ?: uri.lastPathSegment
    }

    // ── Accessibility Service helper ─────────────────────────────────────
    /**
     * Checks whether the WifiDirectAutoAcceptService is currently enabled
     * in Android Accessibility Settings.
     *
     * Uses two strategies:
     * 1. The static [WifiDirectAutoAcceptService.isRunning] flag (fastest)
     * 2. The [AccessibilityManager] API as a reliable fallback
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        // Strategy 1: Check the static runtime flag
        if (WifiDirectAutoAcceptService.isRunning) return true

        // Strategy 2: Query the AccessibilityManager for enabled services
        try {
            val am = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabledServices = am.getEnabledAccessibilityServiceList(
                AccessibilityServiceInfo.FEEDBACK_GENERIC
            )
            val myComponent = ComponentName(this, WifiDirectAutoAcceptService::class.java)
            for (service in enabledServices) {
                val enabledComponent = ComponentName.unflattenFromString(service.id)
                if (enabledComponent == myComponent) return true
            }
        } catch (_: Exception) {}

        return false
    }
}
// ── Native RSA + AES/GCM/NoPadding Crypto Helper ────────────────────────
object CryptoHelper {
    fun generateKeyPair(): Map<String, String> {
        val kpg = KeyPairGenerator.getInstance("RSA")
        kpg.initialize(2048)
        val kp = kpg.genKeyPair()
        val publicKeyBase64 = Base64.encodeToString(kp.public.encoded, Base64.NO_WRAP)
        val privateKeyBase64 = Base64.encodeToString(kp.private.encoded, Base64.NO_WRAP)
        return mapOf("publicKey" to publicKeyBase64, "privateKey" to privateKeyBase64)
    }

    fun encrypt(data: ByteArray, publicKeyStr: String): Map<String, Any> {
        val keyGen = KeyGenerator.getInstance("AES")
        keyGen.init(256)
        val aesKey = keyGen.generateKey()

        val iv = ByteArray(12)
        SecureRandom().nextBytes(iv)

        val aesCipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(128, iv)
        aesCipher.init(Cipher.ENCRYPT_MODE, aesKey, spec)
        val encryptedData = aesCipher.doFinal(data)

        val pubKeyBytes = Base64.decode(publicKeyStr, Base64.NO_WRAP)
        val keySpec = X509EncodedKeySpec(pubKeyBytes)
        val kf = KeyFactory.getInstance("RSA")
        val rsaPublicKey = kf.generatePublic(keySpec)

        val rsaCipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
        rsaCipher.init(Cipher.ENCRYPT_MODE, rsaPublicKey)
        val encryptedAesKey = rsaCipher.doFinal(aesKey.encoded)

        return mapOf(
            "encryptedKey" to Base64.encodeToString(encryptedAesKey, Base64.NO_WRAP),
            "iv" to Base64.encodeToString(iv, Base64.NO_WRAP),
            "encryptedData" to encryptedData
        )
    }

    fun decrypt(encryptedAesKeyStr: String, ivStr: String, encryptedData: ByteArray, privateKeyStr: String): ByteArray {
        val privKeyBytes = Base64.decode(privateKeyStr, Base64.NO_WRAP)
        val keySpec = PKCS8EncodedKeySpec(privKeyBytes)
        val kf = KeyFactory.getInstance("RSA")
        val rsaPrivateKey = kf.generatePrivate(keySpec)

        val rsaCipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
        rsaCipher.init(Cipher.DECRYPT_MODE, rsaPrivateKey)
        val decryptedAesKeyBytes = rsaCipher.doFinal(Base64.decode(encryptedAesKeyStr, Base64.NO_WRAP))
        val aesKey: SecretKey = SecretKeySpec(decryptedAesKeyBytes, 0, decryptedAesKeyBytes.size, "AES")

        val iv = Base64.decode(ivStr, Base64.NO_WRAP)
        val aesCipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(128, iv)
        aesCipher.init(Cipher.DECRYPT_MODE, aesKey, spec)
        return aesCipher.doFinal(encryptedData)
    }
}