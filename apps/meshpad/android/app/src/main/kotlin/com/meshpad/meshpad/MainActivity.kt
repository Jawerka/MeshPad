package com.meshpad.meshpad

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.meshpad/share"
    private val eventChannelName = "com.meshpad/share_events"

    private var pendingShare: Map<String, Any?>? = null
    private var shareEventSink: EventChannel.EventSink? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    result.success(pendingShare)
                    pendingShare = null
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.meshpad/install",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallApk" -> {
                    result.success(canInstallApk())
                }
                "openInstallUnknownAppsSettings" -> {
                    openInstallUnknownAppsSettings()
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("ARG_ERROR", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(path)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error(
                            if (e is InstallUnknownAppsRequiredException) {
                                "INSTALL_UNKNOWN_APPS_REQUIRED"
                            } else {
                                "INSTALL_ERROR"
                            },
                            e.message,
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.meshpad/wifi",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentSsid" -> {
                    val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                    val info = wifi?.connectionInfo
                    result.success(info?.ssid)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            },
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        acquireMulticastLock()
        handleIntent(intent)
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }

    private fun acquireMulticastLock() {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return
        multicastLock = wifi.createMulticastLock("meshpad_lan").apply {
            setReferenceCounted(true)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let {
            if (it.isHeld) it.release()
        }
        multicastLock = null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        val payload = when (intent.action) {
            Intent.ACTION_SEND -> buildSendPayload(intent)
            Intent.ACTION_SEND_MULTIPLE -> buildSendMultiplePayload(intent)
            else -> null
        } ?: return

        if (shareEventSink != null) {
            shareEventSink?.success(payload)
        } else {
            pendingShare = payload
        }
    }

    private fun buildSendPayload(intent: Intent): Map<String, Any?>? {
        val mime = intent.type

        if (mime != null && mime.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
            return mapOf(
                "type" to "text",
                "text" to text,
            )
        }

        val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return null
        val path = copyUriToCache(stream, mime, displayName(stream)) ?: return null
        return mapOf(
            "type" to "file",
            "filePath" to path,
            "mimeType" to mime,
        )
    }

    private fun buildSendMultiplePayload(intent: Intent): Map<String, Any?>? {
        val mime = intent.type
        val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            ?: return null

        val paths = streams.mapNotNull { uri ->
            copyUriToCache(uri, mime, displayName(uri))
        }
        if (paths.isEmpty()) return null

        return if (paths.size == 1) {
            mapOf(
                "type" to "file",
                "filePath" to paths.first(),
                "mimeType" to mime,
            )
        } else {
            mapOf(
                "type" to "files",
                "filePaths" to paths,
                "mimeType" to mime,
            )
        }
    }

    private fun displayName(uri: Uri): String? {
        return contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0 || !cursor.moveToFirst()) return@use null
            cursor.getString(index)
        }
    }

    private fun copyUriToCache(uri: Uri, mime: String?, preferredName: String?): String? {
        return try {
            val safeName = sanitizeFileName(
                preferredName ?: fallbackName(mime),
            )
            val cacheDir = File(cacheDir, "shared")
            cacheDir.mkdirs()
            val outFile = File(cacheDir, "${System.currentTimeMillis()}_$safeName")

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun fallbackName(mime: String?): String {
        val extension = when {
            mime?.startsWith("image/") == true -> ".jpg"
            mime != null && mime.contains('/') -> ".${mime.substringAfter('/')}"
            else -> ".bin"
        }
        return "shared$extension"
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace(Regex("[\\\\/:*?\"<>|]"), "_").take(180)
    }

    private fun canInstallApk(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallUnknownAppsSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
            .setData(Uri.parse("package:$packageName"))
        startActivity(intent)
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("APK not found: $path")
        }

        if (!canInstallApk()) {
            openInstallUnknownAppsSettings()
            throw InstallUnknownAppsRequiredException()
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addCategory(Intent.CATEGORY_DEFAULT)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (intent.resolveActivity(packageManager) == null) {
            throw IllegalStateException("No package installer found on device")
        }
        startActivity(intent)
    }

    private class InstallUnknownAppsRequiredException :
        Exception("Install unknown apps permission required")
}
