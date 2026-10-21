package com.aether.waweb

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "waweb/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        try {
                            val name = call.argument<String>("name") ?: "file"
                            val mime = call.argument<String>("mime") ?: "application/octet-stream"
                            val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, name)
                                put(MediaStore.Downloads.MIME_TYPE, mime)
                                put(
                                    MediaStore.Downloads.RELATIVE_PATH,
                                    Environment.DIRECTORY_DOWNLOADS + "/waweb"
                                )
                            }
                            val uri = contentResolver.insert(
                                MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                            )
                            if (uri == null) {
                                result.error("save", "insert failed", null)
                            } else {
                                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                                result.success(uri.toString())
                            }
                        } catch (e: Exception) {
                            result.error("save", e.message, null)
                        }
                    }
                    "open" -> {
                        try {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            val mime = call.argument<String>("mime") ?: "*/*"
                            val i = Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, mime)
                                .addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_ACTIVITY_NEW_TASK
                                )
                            startActivity(i)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("open", e.message, null)
                        }
                    }
                    "openDownloads" -> {
                        try {
                            startActivity(
                                Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("open", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
