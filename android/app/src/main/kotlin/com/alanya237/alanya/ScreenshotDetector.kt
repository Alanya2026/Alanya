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
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel
import java.util.function.Consumer

/**
 * Détecte une capture d'écran — ou un enregistrement vidéo de l'écran —
 * PENDANT que l'écran d'une discussion est ouvert.
 *
 * Capture :
 * - Android 14+ : callback officiel `Activity.registerScreenCaptureCallback`
 *   (permission `DETECT_SCREEN_CAPTURE`, accordée à l'installation, sans
 *   demande à l'utilisateur).
 * - Avant : on observe la galerie (`MediaStore`) et on cherche une nouvelle image
 *   dont le nom ou le chemin contient « screenshot ». Cela suppose l'accès aux
 *   images, que l'app peut déjà avoir : on ne le DEMANDE jamais pour cette seule
 *   fonction. Sans lui la détection est simplement inactive sur ces versions.
 *
 * Enregistrement :
 * - Android 15+ : callback officiel `WindowManager.addScreenRecordingCallback`
 *   (permission `DETECT_SCREEN_RECORDING`, accordée à l'installation). Il dit
 *   si les fenêtres de l'app sont visibles dans un enregistrement en cours :
 *   on signale dès qu'elles le deviennent, y compris si l'enregistrement avait
 *   commencé avant l'ouverture de la discussion.
 * - Avant : même principe que la capture, sur les vidéos de la galerie (nom ou
 *   dossier du type « Screen recordings », « ScreenRecorder »…). La vidéo n'y
 *   apparaît qu'à la FIN de l'enregistrement : on ne la voit donc que si
 *   l'enregistrement s'arrête pendant que la discussion est ouverte.
 *
 * Le résultat part vers Dart (`onScreenshot` / `onScreenRecording`), qui décide
 * quoi en faire.
 */
class ScreenshotDetector(
    private val activity: Activity,
    private val channel: MethodChannel,
) {
    private var started = false
    private var callback: Activity.ScreenCaptureCallback? = null
    private var recordingCallback: Consumer<Int>? = null
    private val observers = mutableListOf<ContentObserver>()
    private val lastEmitMs = mutableMapOf<String, Long>()

    fun start() {
        if (started) return
        started = true
        val startedAtSec = System.currentTimeMillis() / 1000
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                val cb = Activity.ScreenCaptureCallback { emit(SCREENSHOT) }
                activity.registerScreenCaptureCallback(activity.mainExecutor, cb)
                callback = cb
            } else {
                startGalleryObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, startedAtSec) {
                    looksLikeScreenshot(it)
                }?.let { observers += it }
            }
        } catch (e: Exception) {
            Log.w(TAG, "détection de capture indisponible: ${e.message}")
        }
        try {
            if (Build.VERSION.SDK_INT >= 35) {
                startRecordingCallback()
            } else {
                startGalleryObserver(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, startedAtSec) {
                    looksLikeScreenRecording(it)
                }?.let { observers += it }
            }
        } catch (e: Exception) {
            Log.w(TAG, "détection d'enregistrement indisponible: ${e.message}")
        }
    }

    fun stop() {
        if (!started) return
        started = false
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                callback?.let { activity.unregisterScreenCaptureCallback(it) }
            }
            if (Build.VERSION.SDK_INT >= 35) {
                recordingCallback?.let { activity.windowManager.removeScreenRecordingCallback(it) }
            }
            observers.forEach { activity.contentResolver.unregisterContentObserver(it) }
        } catch (e: Exception) {
            Log.w(TAG, "arrêt de la détection: ${e.message}")
        }
        callback = null
        recordingCallback = null
        observers.clear()
    }

    private fun startRecordingCallback() {
        if (Build.VERSION.SDK_INT < 35) return
        val cb = Consumer<Int> { state ->
            if (state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE) emit(SCREEN_RECORDING)
        }
        // L'état initial est rendu par l'abonnement, pas par le callback.
        val initial = activity.windowManager.addScreenRecordingCallback(activity.mainExecutor, cb)
        recordingCallback = cb
        if (initial == WindowManager.SCREEN_RECORDING_STATE_VISIBLE) emit(SCREEN_RECORDING)
    }

    private fun hasGalleryAccess(uri: Uri): Boolean {
        val video = uri == MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val perm = when {
            Build.VERSION.SDK_INT < 33 -> Manifest.permission.READ_EXTERNAL_STORAGE
            video -> Manifest.permission.READ_MEDIA_VIDEO
            else -> Manifest.permission.READ_MEDIA_IMAGES
        }
        return activity.checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED
    }

    /** Observe [uri] ; [check] dit si son dernier élément trahit l'événement. */
    private fun startGalleryObserver(
        uri: Uri,
        sinceSec: Long,
        check: (Long) -> String?,
    ): ContentObserver? {
        if (!hasGalleryAccess(uri)) return null
        val obs = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, changed: Uri?) {
                check(sinceSec)?.let { emit(it) }
            }
        }
        activity.contentResolver.registerContentObserver(uri, true, obs)
        return obs
    }

    /** La dernière image de la galerie est-elle une capture prise depuis le démarrage ? */
    private fun looksLikeScreenshot(sinceSec: Long): String? {
        val (where, added, _) = latest(MediaStore.Images.Media.EXTERNAL_CONTENT_URI) ?: return null
        val hit = added >= sinceSec && (where.contains("screenshot") || where.contains("capture"))
        return if (hit) SCREENSHOT else null
    }

    /**
     * La dernière vidéo de la galerie est-elle un enregistrement d'écran terminé
     * depuis le démarrage ? On regarde la date de MODIFICATION : un
     * enregistrement lancé avant l'ouverture de la discussion a filmé celle-ci
     * tout autant, et sa ligne a été créée à son début.
     */
    private fun looksLikeScreenRecording(sinceSec: Long): String? {
        val (where, added, modified) = latest(MediaStore.Video.Media.EXTERNAL_CONTENT_URI) ?: return null
        val compact = where.replace(Regex("[\\s_-]"), "")
        // « Screen recordings/ » (Samsung), « ScreenRecorder/ » (Xiaomi),
        // « Screen_Recording_… » ; Huawei/Honor rangent la vidéo dans
        // « Screenshots/ » ; l'enregistreur d'AOSP la nomme « screen-AAAAMMJJ-HHMMSS ».
        val looksLike = compact.contains("screenrecord") ||
            compact.contains("screenshot") ||
            AOSP_RECORDING.containsMatchIn(where)
        val hit = maxOf(added, modified) >= sinceSec && looksLike
        return if (hit) SCREEN_RECORDING else null
    }

    /**
     * Nom (+ dossier, en minuscules), date d'ajout et de modification du dernier
     * élément ajouté à [uri]. Pas de `LIMIT` dans le tri : Android 11+ le refuse
     * (`Invalid token LIMIT`) — le curseur n'est de toute façon lu qu'en tête.
     */
    private fun latest(uri: Uri): Triple<String, Long, Long>? {
        return try {
            val folder = if (Build.VERSION.SDK_INT >= 29) {
                MediaStore.MediaColumns.RELATIVE_PATH
            } else {
                @Suppress("DEPRECATION") MediaStore.MediaColumns.DATA
            }
            val projection = arrayOf(
                MediaStore.MediaColumns.DISPLAY_NAME,
                folder,
                MediaStore.MediaColumns.DATE_ADDED,
                MediaStore.MediaColumns.DATE_MODIFIED,
            )
            activity.contentResolver.query(
                uri, projection, null, null,
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { c ->
                if (!c.moveToFirst()) return null
                val name = c.getString(0) ?: return null
                val where = "${c.getString(1) ?: ""}/$name".lowercase()
                Triple(where, c.getLong(2), c.getLong(3))
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun emit(method: String) {
        // Un même événement déclenche parfois plusieurs notifications : une seule part.
        val now = System.currentTimeMillis()
        if (now - (lastEmitMs[method] ?: 0L) < 2000) return
        lastEmitMs[method] = now
        activity.runOnUiThread { channel.invokeMethod(method, null) }
    }

    private companion object {
        const val TAG = "ScreenshotDetector"
        const val SCREENSHOT = "onScreenshot"
        const val SCREEN_RECORDING = "onScreenRecording"
        val AOSP_RECORDING = Regex("(^|/)screen-\\d{8}-\\d{6}")
    }
}
