package com.alanya237.alanya

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Parcel
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.ContextHolder
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService
import io.flutter.plugins.firebase.messaging.FlutterFirebaseRemoteMessageLiveData

/**
 * Couche Android propriétaire (Phase 4) — activée via manifest placeholder
 * `talkyNotificationNativeV2=true`.
 *
 * Messages : MessagingStyle natif. Appels / meetings : délégués à Flutter FCM.
 */
class TalkyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        ensureFlutterContext()

        val data = message.data
        val type = data["type"] ?: run {
            forwardToFlutter(message)
            return
        }

        when (type) {
            "message" -> {
                // Accusé de remise AVANT tout court-circuit : la notification
                // peut être supprimée (conversation déjà ouverte) ou silencieuse
                // (sourdine), l'expéditeur doit voir ses 2 coches dans tous les cas.
                DeliveryAckHelper.enqueueAndPost(this, data["conversationId"], data["msgID"])

                if (data["silent"] == "1") {
                    Log.d(TAG, "message silencieux (sourdine) conv=${data["conversationId"]} — accusé seul")
                    return
                }
                if (MessageNotificationHelper.shouldSuppress(this, data)) {
                    Log.d(TAG, "message suppressed (active conv)")
                    return
                }
                Log.d(TAG, "message native show conv=${data["conversationId"]} msgID=${data["msgID"]}")
                MessageNotificationHelper.showMessage(this, data)
            }
            "message_read_sync" -> {
                val convId = data["conversationId"]?.toIntOrNull() ?: return
                MessageNotificationHelper.cancelConversation(this, convId)
            }
            "call", "group_call" -> {
                if (isApplicationForeground(this)) {
                    // Premier plan : Flutter + socket (IncomingCallScreen + sonnerie).
                    Log.d(TAG, "call foreground → forward Flutter callId=${data["callId"] ?: data["roomId"]}")
                    forwardToFlutter(message)
                } else {
                    Log.d(TAG, "call native show callId=${data["callId"] ?: data["roomId"]}")
                    CallIncomingHelper.showIncoming(this, data)
                }
            }
            "call_ended" -> {
                Log.d(TAG, "call native end callId=${data["callId"]}")
                CallIncomingHelper.endCall(this, data)
                forwardToFlutter(message)
            }
            "meeting_invite", "meeting_reminder", "status_view",
            -> forwardToFlutter(message)
            else -> forwardToFlutter(message)
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "onNewToken — Flutter syncTokenWithBackend expected")
    }

    private fun ensureFlutterContext() {
        if (ContextHolder.getApplicationContext() == null) {
            ContextHolder.setApplicationContext(applicationContext)
        }
    }

    private fun forwardToFlutter(message: RemoteMessage) {
        val context: Context = applicationContext
        if (isApplicationForeground(context)) {
            FlutterFirebaseRemoteMessageLiveData.getInstance().postRemoteMessage(message)
            return
        }
        val intent = Intent(context, FlutterFirebaseMessagingBackgroundService::class.java)
        val parcel = Parcel.obtain()
        try {
            message.writeToParcel(parcel, 0)
            // Même clé que FlutterFirebaseMessagingUtils.EXTRA_REMOTE_MESSAGE ("notification").
            intent.putExtra(FLUTTER_REMOTE_MESSAGE_EXTRA, parcel.marshall())
        } finally {
            parcel.recycle()
        }
        FlutterFirebaseMessagingBackgroundService.enqueueMessageProcessing(
            context,
            intent,
            message.originalPriority == RemoteMessage.PRIORITY_HIGH,
        )
    }

    /**
     * Copie de la logique FlutterFirebaseMessagingUtils (classe package-private).
     *
     * Le test d'importance était strictement `== IMPORTANCE_FOREGROUND` (100).
     * Or quand FCM réveille ce service, le processus est fréquemment rapporté
     * en `IMPORTANCE_FOREGROUND_SERVICE` (125) alors que l'activité est bien
     * visible : la comparaison échouait, la fonction renvoyait toujours faux,
     * et l'UI CallKit native s'affichait par-dessus l'IncomingCallScreen de
     * Flutter — double UI entrante, dont le decline raccrochait l'appel.
     * On accepte donc les deux niveaux, et on journalise la décision.
     */
    private fun isApplicationForeground(context: Context): Boolean {
        val keyguardManager =
            context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val locked = keyguardManager?.isKeyguardLocked == true

        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val processes = activityManager?.runningAppProcesses
        val packageName = context.packageName
        var importance = -1
        if (processes != null) {
            for (process in processes) {
                if (process.processName == packageName) {
                    importance = process.importance
                    break
                }
            }
        }

        val visible = importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE
        // Écran verrouillé : l'UI native plein écran reste la bonne réponse,
        // même si le processus est encore visible.
        val foreground = !locked && visible
        Log.d(
            TAG,
            "isApplicationForeground=$foreground (keyguardLocked=$locked, importance=$importance, visible=$visible)",
        )
        return foreground
    }

    companion object {
        private const val TAG = "TalkyFcmService"
        private const val FLUTTER_REMOTE_MESSAGE_EXTRA = "notification"
    }
}
