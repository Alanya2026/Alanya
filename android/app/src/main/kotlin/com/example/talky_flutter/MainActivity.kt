package com.example.talky_flutter

import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.alanya/media_export"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Permet à l'écran d'appel d'apparaître par-dessus l'écran de verrouillage
        // et de réveiller l'écran quand un appel entrant arrive (CallKit/FCM).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        try {
                            val path = call.argument<String>("path")
                            val fileName = call.argument<String>("fileName")
                            val mimeType = call.argument<String>("mimeType")
                                ?: "application/octet-stream"
                            val subdir = call.argument<String>("subdir") ?: "Alanya"
                            if (path.isNullOrBlank() || fileName.isNullOrBlank()) {
                                result.error("bad_args", "path/fileName requis", null)
                                return@setMethodCallHandler
                            }
                            val saved = saveToDownloads(path, fileName, mimeType, subdir)
                            if (saved) result.success(true)
                            else result.error("save_failed", "Échec copie Downloads", null)
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(
        srcPath: String,
        fileName: String,
        mimeType: String,
        subdir: String,
    ): Boolean {
        val src = File(srcPath)
        if (!src.exists() || !src.isFile) return false

        // subdir peut être imbriqué : "Alanya/Alanya Images"
        val relative = Environment.DIRECTORY_DOWNLOADS + "/" +
            subdir.trim('/').replace('\\', '/')

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relative)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return false
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { input -> input.copyTo(out) }
            } ?: return false
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return true
        }

        @Suppress("DEPRECATION")
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            subdir.trim('/').replace('\\', '/'),
        )
        if (!dir.exists() && !dir.mkdirs()) return false
        val dest = File(dir, fileName)
        src.copyTo(dest, overwrite = true)
        return true
    }
}
