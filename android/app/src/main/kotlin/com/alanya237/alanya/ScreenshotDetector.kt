package com.alanya237.alanya

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Détecte une capture d'écran PENDANT que l'écran d'une discussion est ouvert.
 *
 * - Android 14+ : callback officiel `Activity.registerScreenCaptureCallback`
 *   (permission `DETECT_SCREEN_CAPTURE`, accordée à l'installation, sans
 *   demande à l'utilisateur).
 * - Avant : on observe la galerie (`MediaStore`) et on cherche une nouvelle image
 *   dont le nom ou le chemin contient « screenshot ». Cela suppose l'accès aux
 *   images, que l'app peut déjà avoir : on ne le DEMANDE jamais pour cette seule
 *   fonction. Sans lui la détection est simplement inactive sur ces versions.
 *
 * Le résultat part vers Dart (`onScreenshot`), qui décide quoi en faire.
 */
class ScreenshotDetector(
    private val activity: Activity,
    private val channel: MethodChannel,
) {
    private var started = false
    private var callback: Activity.ScreenCaptureCallback? = null
    private var observer: ContentObserver? = null
    private var lastEmitMs = 0L

    fun start() {
        if (started) return
        started = true
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                val cb = Activity.ScreenCaptureCallback { emit() }
                activity.registerScreenCaptureCallback(activity.mainExecutor, cb)
                callback = cb
            } else {
                startGalleryObserver()
            }
        } catch (e: Exception) {
            Log.w(TAG, "détection de capture indisponible: ${e.message}")
        }
    }

    fun stop() {
        if (!started) return
        started = false
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                callback?.let { activity.unregisterScreenCaptureCallback(it) }
            }
            observer?.let { activity.contentResolver.unregisterContentObserver(it) }
        } catch (e: Exception) {
            Log.w(TAG, "arrêt de la détection: ${e.message}")
        }
        callback = null
        observer = null
    }

    private fun hasGalleryAccess(): Boolean {
        val perm = if (Build.VERSION.SDK_INT >= 33) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return activity.checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun startGalleryObserver() {
        if (!hasGalleryAccess()) return
        val startedAtSec = System.currentTimeMillis() / 1000
        val obs = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                if (looksLikeScreenshot(startedAtSec)) emit()
            }
        }
        activity.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, obs,
        )
        observer = obs
    }

    /** La dernière image de la galerie est-elle une capture prise depuis le démarrage ? */
    private fun looksLikeScreenshot(sinceSec: Long): Boolean {
        return try {
            val projection = arrayOf(
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATE_ADDED,
            )
            activity.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection, null, null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC LIMIT 1",
            )?.use { c ->
                if (!c.moveToFirst()) return false
                val name = c.getString(0)?.lowercase() ?: return false
                val added = c.getLong(1)
                added >= sinceSec && (name.contains("screenshot") || name.contains("capture"))
            } ?: false
        } catch (e: Exception) {
            false
        }
    }

    private fun emit() {
        // Une capture déclenche parfois plusieurs notifications : une seule part.
        val now = System.currentTimeMillis()
        if (now - lastEmitMs < 2000) return
        lastEmitMs = now
        activity.runOnUiThread { channel.invokeMethod("onScreenshot", null) }
    }

    private companion object {
        const val TAG = "ScreenshotDetector"
    }
}
