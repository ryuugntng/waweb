package com.aether.waweb

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val prefs by lazy { getSharedPreferences("waweb", Context.MODE_PRIVATE) }
    private var pickResult: MethodChannel.Result? = null
    private var permResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "waweb/files")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "save" -> result.success(
                            save(
                                call.argument<String>("name") ?: "file",
                                call.argument<String>("mime") ?: "application/octet-stream",
                                call.argument<ByteArray>("bytes") ?: ByteArray(0)
                            )
                        )
                        "open" -> {
                            openFile(
                                Uri.parse(call.argument<String>("uri")),
                                call.argument<String>("mime") ?: "*/*"
                            )
                            result.success(null)
                        }
                        "pickFolder" -> pickFolder(result)
                        "folderLabel" -> result.success(folderLabel())
                        "resetFolder" -> {
                            releaseTree()
                            result.success(null)
                        }
                        "openDownloads" -> {
                            openFolder()
                            result.success(null)
                        }
                        "prefs" -> result.success(prefs.all)
                        "setPref" -> {
                            val k = call.argument<String>("key") ?: ""
                            val e = prefs.edit()
                            when (val v = call.argument<Any>("value")) {
                                is Boolean -> e.putBoolean(k, v)
                                is Int -> e.putInt(k, v)
                                is Double -> e.putString(k, v.toString())
                                is String -> e.putString(k, v)
                                else -> e.remove(k)
                            }
                            e.apply()
                            result.success(null)
                        }
                        "online" -> result.success(isOnline())
                        "launch" -> {
                            startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(null)
                        }
                        "perms" -> askPerms(
                            call.argument<List<String>>("list") ?: emptyList(), result
                        )
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("waweb", e.message, null)
                }
            }
    }

    // ---------- koneksi ----------
    private fun isOnline(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    // ---------- izin kamera / mikrofon ----------
    private fun askPerms(list: List<String>, result: MethodChannel.Result) {
        val need = list.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (need.isEmpty()) {
            result.success(true)
            return
        }
        permResult?.success(false)
        permResult = result
        requestPermissions(need.toTypedArray(), 4401)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4401) {
            permResult?.success(
                grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            )
            permResult = null
        }
    }

    // ---------- folder unduhan ----------
    private fun treeUri(): Uri? {
        val s = prefs.getString("treeUri", null) ?: return null
        val u = Uri.parse(s)
        val ok = contentResolver.persistedUriPermissions.any {
            it.uri == u && it.isWritePermission
        }
        return if (ok) u else null
    }

    private fun releaseTree() {
        val s = prefs.getString("treeUri", null)
        if (s != null) {
            try {
                contentResolver.releasePersistableUriPermission(
                    Uri.parse(s),
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) {
            }
        }
        prefs.edit().remove("treeUri").apply()
    }

    private fun folderLabel(): String {
        val t = treeUri() ?: return "Download/waweb"
        val id = DocumentsContract.getTreeDocumentId(t)
        val parts = id.split(":", limit = 2)
        val path = if (parts.size == 2) parts[1] else id
        return if (path.isEmpty()) "Penyimpanan internal" else path
    }

    private fun pickFolder(result: MethodChannel.Result) {
        pickResult?.success(null)
        pickResult = result
        val i = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
        )
        if (Build.VERSION.SDK_INT >= 26) {
            i.putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents", "primary:Download"
                )
            )
        }
        startActivityForResult(i, 4402)
    }

    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 4402) {
            val uri = if (resultCode == RESULT_OK) data?.data else null
            if (uri != null) {
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    prefs.edit().putString("treeUri", uri.toString()).apply()
                    pickResult?.success(folderLabel())
                } catch (e: Exception) {
                    pickResult?.error("pick", e.message, null)
                }
            } else {
                pickResult?.success(null)
            }
            pickResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    // ---------- simpan & buka ----------
    private fun save(name: String, mime: String, bytes: ByteArray): String {
        val tree = treeUri()
        if (tree != null) {
            try {
                val parent = DocumentsContract.buildDocumentUriUsingTree(
                    tree, DocumentsContract.getTreeDocumentId(tree)
                )
                val doc = DocumentsContract.createDocument(contentResolver, parent, mime, name)
                if (doc != null) {
                    contentResolver.openOutputStream(doc)?.use { it.write(bytes) }
                    return doc.toString()
                }
            } catch (_: Exception) {
                // folder hilang / izin dicabut -> jatuh ke Download/waweb
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/waweb")
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("insert failed")
        contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
        return uri.toString()
    }

    private fun openFile(uri: Uri, mime: String) {
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, mime)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun openFolder() {
        val tree = treeUri()
        if (tree != null) {
            try {
                val dir = DocumentsContract.buildDocumentUriUsingTree(
                    tree, DocumentsContract.getTreeDocumentId(tree)
                )
                startActivity(
                    Intent(Intent.ACTION_VIEW)
                        .setDataAndType(dir, DocumentsContract.Document.MIME_TYPE_DIR)
                        .addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                        )
                )
                return
            } catch (_: Exception) {
            }
        }
        startActivity(
            Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}
