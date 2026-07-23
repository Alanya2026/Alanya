package com.example.talky_flutter

import android.content.Context
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitNotificationManager
import com.hiennv.flutter_callkit_incoming.CallkitSoundPlayerManager
import com.hiennv.flutter_callkit_incoming.Data
import com.hiennv.flutter_callkit_incoming.addCall
import com.hiennv.flutter_callkit_incoming.removeAllCalls
import com.hiennv.flutter_callkit_incoming.removeCall

/**
 * Affiche CallKit / plein écran sans isolate Flutter (app tuée).
 * Le BroadcastReceiver du plugin exige une instance plugin initialisée ;
 * on instancie directement [CallkitNotificationManager] au démarrage app.
 */
object CallIncomingHelper {

    private const val TAG = "TalkyCallIncoming"

    private var notificationManager: CallkitNotificationManager? = null
    private var soundManager: CallkitSoundPlayerManager? = null
    private var lastShownCallId: String? = null

    fun ensureInitialized(context: Context) {
        if (notificationManager != null) return
        val appContext = context.applicationContext
        soundManager = CallkitSoundPlayerManager(appContext)
        notificationManager = CallkitNotificationManager(appContext, soundManager!!)
        Log.d(TAG, "CallkitNotificationManager ready")
    }

    fun showIncoming(context: Context, data: Map<String, String>) {
        val callId = (data["callId"] ?: data["roomId"] ?: "").trim()
        if (callId.isNotEmpty() && callId == lastShownCallId) {
            Log.d(TAG, "skip duplicate callId=$callId")
            return
        }
        if (callId.isNotEmpty()) lastShownCallId = callId

        ensureInitialized(context)
        val bundle = buildIncomingBundle(data)
        try {
            notificationManager?.showIncomingNotification(bundle)
            addCall(context.applicationContext, Data.fromBundle(bundle))
            Log.d(TAG, "showIncoming callId=$callId caller=${data["callerId"]}")
        } catch (e: Exception) {
            Log.e(TAG, "showIncoming failed", e)
        }
    }

    fun endCall(context: Context, data: Map<String, String>) {
        ensureInitialized(context)
        lastShownCallId = null
        val callId = (data["callId"] ?: "").trim()
        try {
            if (callId.isEmpty()) {
                soundManager?.stop()
                removeAllCalls(context.applicationContext)
                Log.d(TAG, "endCall all")
                return
            }
            val bundle = Data(hashMapOf<String, Any?>("id" to callId)).toBundle()
            notificationManager?.clearIncomingNotification(bundle, false)
            removeCall(context.applicationContext, Data.fromBundle(bundle))
            Log.d(TAG, "endCall callId=$callId")
        } catch (e: Exception) {
            Log.e(TAG, "endCall failed", e)
        }
    }

    private fun buildIncomingBundle(data: Map<String, String>): android.os.Bundle {
        val callId = (data["callId"] ?: data["roomId"] ?: "").trim()
        val callerId = data["callerId"] ?: ""
        val callerName = data["callerName"] ?: data["title"] ?: "Alanya"
        val isVideo = data["isVideo"] == "true"
        val roomId = data["roomId"] ?: ""
        val photo = data["photo"] ?: ""

        val extra = hashMapOf<String, Any?>(
            "callId" to callId,
            "callerId" to callerId,
            "callerName" to callerName,
            "callerPhoto" to photo,
            "isVideo" to isVideo,
            "roomId" to roomId,
        )

        val args = hashMapOf<String, Any?>(
            "id" to callId,
            "nameCaller" to callerName,
            "appName" to "Alanya",
            "handle" to callerId,
            "avatar" to photo,
            "type" to if (isVideo) 1 else 0,
            "duration" to 30000L,
            "textAccept" to "Accepter",
            "textDecline" to "Refuser",
            "extra" to extra,
            "android" to hashMapOf(
                "isCustomNotification" to true,
                "isShowLogo" to false,
                "ringtonePath" to "system_ringtone_default",
                "backgroundColor" to "#0955fa",
                "actionColor" to "#4CAF50",
                "incomingCallNotificationChannelName" to "Appels entrants",
                "missedCallNotificationChannelName" to "Appels manqués",
                "isShowFullLockedScreen" to true,
            ),
        )
        return Data(args).toBundle()
    }
}
