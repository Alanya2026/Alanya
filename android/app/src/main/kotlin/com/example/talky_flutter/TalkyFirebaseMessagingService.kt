package com.example.talky_flutter

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

    /** Copie de la logique FlutterFirebaseMessagingUtils (classe package-private). */
    private fun isApplicationForeground(context: Context): Boolean {
        val keyguardManager =
            context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (keyguardManager?.isKeyguardLocked == true) return false

        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        val processes = activityManager.runningAppProcesses ?: return false
        val packageName = context.packageName
        for (process in processes) {
            if (process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                process.processName == packageName
            ) {
                return true
            }
        }
        return false
    }

    companion object {
        private const val TAG = "TalkyFcmService"
        private const val FLUTTER_REMOTE_MESSAGE_EXTRA = "notification"
    }
}
