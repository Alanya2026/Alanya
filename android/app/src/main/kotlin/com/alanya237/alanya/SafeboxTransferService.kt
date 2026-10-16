package com.alanya237.alanya

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Garde l'application vivante pendant les envois vers le coffre-fort.
 *
 * ── Pourquoi ──
 *
 * Un fichier de 1 Go sur une ligne mobile met des heures à partir. L'inscrit
 * passe à autre chose, éteint l'écran : sans service de premier plan, Android
 * suspend puis tue le processus. Le service garde aussi le processeur éveillé
 * (verrou partiel) : chaque bloc est chiffré sur le téléphone avant de partir.
 *
 * ── Ce qu'il ne fait pas ──
 *
 * Il ne porte pas l'envoi : c'est le code Dart de l'application qui envoie.
 * Quand l'inscrit balaie l'application pour la fermer, le moteur Flutter
 * s'arrête avec elle ; le service s'arrête donc aussi ([onTaskRemoved]) au
 * lieu de laisser une notification qui mentirait. L'envoi reprend, là où il en
 * était, au prochain démarrage de l'application.
 *
 * ── La limite de six heures d'Android 15 ──
 *
 * `dataSync` est plafonné à six heures par 24 h (API 35+). Au terme, [onTimeout]
 * arrête le service proprement ; l'envoi en cours continue tant que
 * l'application reste ouverte, et reprend sinon au démarrage suivant.
 */
class SafeboxTransferService : Service() {

    companion object {
        private const val TAG = "SafeboxFGS"
        private const val CHANNEL_ID = "alanya_safebox"
        private const val NOTIFICATION_ID = 4212
        private const val WAKELOCK_MS = 6L * 60 * 60 * 1000

        private const val EXTRA_CHANNEL_NAME = "channelName"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PERCENT = "percent"

        /** Démarre, ou met à jour la notification d'un service déjà lancé. */
        fun startOrUpdate(context: Context, channelName: String, title: String, text: String, percent: Int) {
            val intent = Intent(context, SafeboxTransferService::class.java)
                .putExtra(EXTRA_CHANNEL_NAME, channelName)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_PERCENT, percent)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SafeboxTransferService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel(intent?.getStringExtra(EXTRA_CHANNEL_NAME) ?: "Coffre-fort")
        val notification = buildNotification(
            intent?.getStringExtra(EXTRA_TITLE) ?: "",
            intent?.getStringExtra(EXTRA_TEXT) ?: "",
            intent?.getIntExtra(EXTRA_PERCENT, -1) ?: -1,
        )
        try {
            startAsForeground(notification)
            acquireWakeLock()
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            stopSelf()
        }
        // NOT_STICKY : relancé seul par le système, le service n'aurait aucun
        // envoi à porter — le code Dart qui envoie ne tourne plus.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "application fermée par l'inscrit → arrêt, reprise au prochain démarrage")
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "délai de service dépassé → arrêt propre")
        stopSelf()
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "alanya:safebox").apply {
            setReferenceCounted(false)
            // Borné : un verrou oublié viderait la batterie.
            acquire(WAKELOCK_MS)
        }
    }

    private fun startAsForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel(name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW).apply {
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        mgr.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, text: String, percent: Int): Notification {
        val ouvrir = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, NOTIFICATION_ID, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(ContextCompat.getColor(this, R.color.notification_accent))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
        if (ouvrir != null) builder.setContentIntent(ouvrir)
        if (percent in 0..100) builder.setProgress(100, percent, false) else builder.setProgress(0, 0, true)
        return builder.build()
    }
}
