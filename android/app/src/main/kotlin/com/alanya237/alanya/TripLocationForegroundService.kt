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
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Service en avant-plan qui maintient la localisation active pendant un trajet
 * de confiance.
 *
 * Sans lui, Android 10+ coupe les mises à jour dès que l'application passe en
 * arrière-plan : le suivi s'arrêtait à l'instant où l'utilisateur verrouillait
 * son téléphone — c'est-à-dire au moment précis où il sert.
 *
 * **Aucune permission supplémentaire n'est requise.** Un service
 * `foregroundServiceType="location"` démarré pendant que l'application est
 * visible n'exige ni `ACCESS_BACKGROUND_LOCATION`, ni déclaration au Play Store.
 * `ACCESS_FINE_LOCATION` et `FOREGROUND_SERVICE_LOCATION` suffisent.
 *
 * Deux différences assumées avec [CallMediaForegroundService], dont il reprend
 * la structure :
 *
 *  - **`START_STICKY`** au lieu de `START_NOT_STICKY`. Un appel tué ne doit pas
 *    ressusciter ; un trajet, si. Le service redémarré relit le trajet ouvert et
 *    reprend l'émission.
 *  - La notification **nomme les destinataires** et propose « Arrêter » en un
 *    appui. Ce n'est pas cosmétique : une notification de suivi qui ne dit pas à
 *    qui elle envoie la position se comporte comme un logiciel espion. C'est
 *    aussi ce qui rend l'arrêt gratuit — si arrêter coûtait cher, arrêter
 *    deviendrait punissable par quelqu'un qui regarde par-dessus l'épaule.
 */
class TripLocationForegroundService : Service() {

    companion object {
        private const val TAG = "TripLocationFGS"
        private const val CHANNEL_ID = "alanya_trip_location"
        private const val CHANNEL_NAME = "Trajet de confiance"
        private const val NOTIFICATION_ID = 23702

        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_STOP_LABEL = "stopLabel"
        const val ACTION_STOP = "com.alanya237.alanya.TRIP_STOP"

        /** Rempli par le pont : consommé par Flutter au prochain démarrage. */
        @Volatile
        var stopRequested: Boolean = false

        fun start(context: Context, title: String, body: String, stopLabel: String) {
            val intent = Intent(context, TripLocationForegroundService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_STOP_LABEL, stopLabel)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TripLocationForegroundService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // L'utilisateur a appuyé sur « Arrêter » depuis la notification.
            // On note l'intention et on s'arrête ; Flutter la relèvera et clora
            // le trajet côté serveur.
            stopRequested = true
            TripLocationBridge.notifyStopRequested()
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: CHANNEL_NAME
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""
        val stopLabel = intent?.getStringExtra(EXTRA_STOP_LABEL) ?: "Arrêter"

        try {
            ensureChannel()
            startAsForeground(buildNotification(title, body, stopLabel))
            Log.i(TAG, "started")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            stopSelf()
            return START_NOT_STICKY
        }
        // Collant : le système peut tuer le processus, le trajet doit reprendre.
        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "stopped")
        super.onDestroy()
    }

    private fun startAsForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            // LOW : visible et non masquable, mais silencieuse. Un trajet dure
            // des dizaines de minutes ; il ne doit pas sonner.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Partage votre position pendant un trajet de confiance"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        mgr.createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        body: String,
        stopLabel: String,
    ): Notification {
        val ouvrir = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val arreter = PendingIntent.getService(
            this,
            1,
            Intent(this, TripLocationForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(ContextCompat.getColor(this, R.color.notification_accent))
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .apply { if (ouvrir != null) setContentIntent(ouvrir) }
            .addAction(0, stopLabel, arreter)
            .build()
    }
}
