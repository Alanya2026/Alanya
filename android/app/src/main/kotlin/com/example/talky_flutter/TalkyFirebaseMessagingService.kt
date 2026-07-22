package com.example.talky_flutter

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Couche Android propriétaire (Phase 4) — derrière NOTIFICATION_ANDROID_NATIVE_V2.
 * Pour l'instant : log + délégation au handler Flutter existant.
 * MessagingStyle / RemoteInput / Person : itération 4.2–4.4.
 */
class TalkyFirebaseMessagingService : FirebaseMessagingService() {
    companion object {
        private const val TAG = "TalkyFcmService"
        const val NATIVE_V2_ENABLED = false
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (!NATIVE_V2_ENABLED) {
            Log.d(TAG, "native v2 disabled — Flutter handler expected type=${message.data["type"]}")
            return
        }
        // TODO Phase 4.2: NotificationCompat.MessagingStyle + Person + ShortcutInfoCompat
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "onNewToken (native layer)")
    }
}
