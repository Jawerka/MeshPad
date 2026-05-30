package com.meshpad.meshpad

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.meshpad/share"
    private val eventChannelName = "com.meshpad/share_events"

    private var pendingShare: Map<String, String?>? = null
    private var shareEventSink: EventChannel.EventSink? = null

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
        handleIntent(intent)
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

    private fun buildSendPayload(intent: Intent): Map<String, String?>? {
        val mime = intent.type

        if (mime != null && mime.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
            return mapOf(
                "type" to "text",
                "text" to text,
            )
        }

        val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return null
        val path = copyUriToCache(stream, mime) ?: return null
        return mapOf(
            "type" to "file",
            "filePath" to path,
            "mimeType" to mime,
        )
    }

    private fun buildSendMultiplePayload(intent: Intent): Map<String, String?>? {
        val mime = intent.type
        val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        val first = streams?.firstOrNull() ?: return null
        val path = copyUriToCache(first, mime) ?: return null
        return mapOf(
            "type" to "file",
            "filePath" to path,
            "mimeType" to mime,
        )
    }

    private fun copyUriToCache(uri: Uri, mime: String?): String? {
        return try {
            val extension = when {
                mime?.startsWith("image/") == true -> ".jpg"
                mime != null && mime.contains('/') -> ".${mime.substringAfter('/')}"
                else -> ".bin"
            }
            val cacheDir = File(cacheDir, "shared")
            cacheDir.mkdirs()
            val outFile = File(cacheDir, "share_${System.currentTimeMillis()}$extension")

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
}
