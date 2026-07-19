package com.meshpad.meshpad

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.meshpad/share"
    private val eventChannelName = "com.meshpad/share_events"

    private var pendingShare: Map<String, Any?>? = null
    private var shareEventSink: EventChannel.EventSink? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pendingWifiPermissionResult: MethodChannel.Result? = null
    private var cachedWifiSsid: String? = null
    private var wifiSsidMonitor: ConnectivityManager.NetworkCallback? = null

    private companion object {
        private const val REQUEST_WIFI_SSID_PERMISSION = 4242
        private const val TAG = "MeshPadWifi"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        acquireMulticastLock()
        handleIntent(intent)
        ensureWifiSsidMonitor()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    val share = pendingShare
                    pendingShare = null
                    if (share != null) {
                        clearConsumedShareIntent()
                    }
                    result.success(share)
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
                "ensureWifiSsidPermission" -> {
                    val missing = missingWifiSsidPermissions()
                    if (missing.isEmpty()) {
                        ensureWifiSsidMonitor()
                        result.success(true)
                    } else {
                        pendingWifiPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            missing,
                            REQUEST_WIFI_SSID_PERMISSION,
                        )
                    }
                }
                "isLocationEnabled" -> {
                    result.success(isLocationEnabledForSsid())
                }
                "getCurrentSsid" -> {
                    if (!hasWifiSsidPermission()) {
                        Log.w(TAG, "getCurrentSsid: missing permissions")
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    if (!isLocationEnabledForSsid()) {
                        Log.w(TAG, "getCurrentSsid: location services disabled")
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val ssid = readCurrentSsid()
                        Log.i(TAG, "getCurrentSsid: ssid=$ssid")
                        runOnUiThread { result.success(ssid) }
                    }.start()
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
                    val pending = pendingShare
                    if (pending != null && events != null) {
                        pendingShare = null
                        events.success(pending)
                        clearConsumedShareIntent()
                    }
                }

                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            },
        )
    }

    override fun onDestroy() {
        stopWifiSsidMonitor()
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WIFI_SSID_PERMISSION) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        Log.i(
            TAG,
            "onRequestPermissionsResult granted=$granted permissions=${permissions.joinToString()}",
        )
        if (granted) {
            ensureWifiSsidMonitor()
        }
        pendingWifiPermissionResult?.success(granted)
        pendingWifiPermissionResult = null
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
            clearConsumedShareIntent()
        } else {
            pendingShare = payload
        }
    }

    /** Drop sticky ACTION_SEND so a later cold start cannot create a duplicate note. */
    private fun clearConsumedShareIntent() {
        setIntent(Intent(this, MainActivity::class.java))
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

    private fun wifiSsidPermissions(): Array<String> {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                arrayOf(
                    Manifest.permission.NEARBY_WIFI_DEVICES,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
            else -> emptyArray()
        }
    }

    private fun missingWifiSsidPermissions(): Array<String> {
        return wifiSsidPermissions().filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) !=
                PackageManager.PERMISSION_GRANTED
        }.toTypedArray()
    }

    private fun hasWifiSsidPermission(): Boolean {
        return missingWifiSsidPermissions().isEmpty()
    }

    private fun isLocationEnabledForSsid(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        val locationManager =
            applicationContext.getSystemService(Context.LOCATION_SERVICE)
                as? LocationManager
                ?: return false
        return locationManager.isLocationEnabled
    }

    private fun readCurrentSsid(): String? {
        cachedWifiSsid?.let { return it }

        extractSsidFromWifiManager()?.let {
            cachedWifiSsid = it
            Log.i(TAG, "readCurrentSsid via WifiManager: $it")
            return it
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            readSsidViaNetworkCallback()?.let {
                cachedWifiSsid = it
                Log.i(TAG, "readCurrentSsid via NetworkCallback: $it")
                return it
            }
        }

        Log.w(TAG, "readCurrentSsid: all methods failed")
        return null
    }

    private fun ensureWifiSsidMonitor() {
        if (!hasWifiSsidPermission()) return
        if (wifiSsidMonitor != null) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        val connectivity =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                as? ConnectivityManager
                ?: return

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()

        val callback = object : ConnectivityManager.NetworkCallback(
            ConnectivityManager.NetworkCallback.FLAG_INCLUDE_LOCATION_INFO,
        ) {
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) {
                extractSsidFromCapabilities(networkCapabilities)?.let {
                    cachedWifiSsid = it
                    Log.d(TAG, "monitor onCapabilitiesChanged ssid=$it")
                }
            }

            override fun onLost(network: Network) {
                cachedWifiSsid = null
            }
        }

        wifiSsidMonitor = callback
        connectivity.registerNetworkCallback(request, callback)
    }

    private fun stopWifiSsidMonitor() {
        val callback = wifiSsidMonitor ?: return
        val connectivity =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                as? ConnectivityManager
                ?: return
        try {
            connectivity.unregisterNetworkCallback(callback)
        } catch (_: IllegalArgumentException) {
        }
        wifiSsidMonitor = null
        cachedWifiSsid = null
    }

    private fun readSsidViaNetworkCallback(): String? {
        val connectivity =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                as? ConnectivityManager
                ?: return null

        val latch = CountDownLatch(1)
        var ssid: String? = null

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()

        val callback = object : ConnectivityManager.NetworkCallback(
            ConnectivityManager.NetworkCallback.FLAG_INCLUDE_LOCATION_INFO,
        ) {
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) {
                val raw = extractSsidFromCapabilities(networkCapabilities)
                Log.d(TAG, "onCapabilitiesChanged raw=$raw")
                ssid = raw
                latch.countDown()
            }

            override fun onLost(network: Network) {
                latch.countDown()
            }
        }

        connectivity.registerNetworkCallback(request, callback)
        try {
            latch.await(2, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } finally {
            try {
                connectivity.unregisterNetworkCallback(callback)
            } catch (_: IllegalArgumentException) {
            }
        }

        return ssid
    }

    private fun extractSsidFromCapabilities(
        networkCapabilities: NetworkCapabilities,
    ): String? {
        if (!networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            return null
        }
        val transportInfo = networkCapabilities.transportInfo
        if (transportInfo is WifiInfo) {
            return extractSsidFromWifiInfo(transportInfo)
        }
        return null
    }

    @Suppress("DEPRECATION")
    private fun extractSsidFromWifiManager(): String? {
        val wifi =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                ?: return null
        return extractSsidFromWifiInfo(wifi.connectionInfo)
    }

    private fun extractSsidFromWifiInfo(info: WifiInfo?): String? {
        if (info == null) return null
        val raw = info.ssid
        Log.d(TAG, "WifiInfo raw ssid=$raw")
        return normalizeSsid(raw)
    }

    private fun normalizeSsid(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val ssid = raw.trim().removeSurrounding("\"")
        if (ssid.isEmpty()) return null
        val lower = ssid.lowercase()
        if (lower == "<unknown ssid>" || lower == "unknown ssid") return null
        if (lower.startsWith("0x")) return null
        return ssid
    }
}
