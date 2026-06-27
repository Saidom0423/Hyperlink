package com.example.hyperlink

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val FILE_CHANNEL = "com.hyperlink/files"
    private val WIFI_DIRECT_CHANNEL = "com.hyperlink/wifi_direct"
    private val FILE_PICK_CODE = 1001

    private var pendingResult: MethodChannel.Result? = null
    private lateinit var wifiDirectManager: WiFiDirectManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        wifiDirectManager.unregister()
        super.onDestroy()
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
}