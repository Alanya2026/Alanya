package com.alanya237.alanya

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.util.Log
import java.io.File

/** Lecture unique d'un fichier importé pour une notification de message. */
object MessageRingtonePlayer {
    private const val TAG = "TalkyMessageRingtone"
    private var player: MediaPlayer? = null

    @Synchronized
    fun playOnce(context: Context, filePath: String) {
        if (!File(filePath).exists()) return
        stop()
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setLegacyStreamType(AudioManager.STREAM_NOTIFICATION)
                        .build(),
                )
                setDataSource(filePath)
                isLooping = false
                setOnCompletionListener { stop() }
                setOnErrorListener { _, _, _ -> stop(); true }
                setOnPreparedListener { it.start() }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "playOnce failed", e)
            stop()
        }
    }

    @Synchronized
    fun stop() {
        val current = player ?: return
        player = null
        try { current.stop() } catch (_: Exception) {}
        try { current.release() } catch (_: Exception) {}
    }
}
