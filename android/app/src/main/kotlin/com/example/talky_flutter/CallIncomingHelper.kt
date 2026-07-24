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

        // Sonnerie importée par l'utilisateur : le plugin CallKit ne sait pas
        // jouer un fichier arbitraire, on la joue nous-mêmes et on rend CallKit
        // muet (voir [CustomRingtonePlayer]).
        val customPath = resolveCustomRingtonePath(context)
        // Fichier importé → CallKit muet + on joue le fichier. Sinon CallKit
        // joue lui-même la ressource compilée résolue par Flutter ('ringback'
        // pour la Sonnerie Alanya, 'system_ringtone_default', ...).
        val ringtonePath =
            if (customPath != null) "silence" else resolveNativeRingtoneName(context)
        val bundle = buildIncomingBundle(data, ringtonePath)
        try {
            notificationManager?.showIncomingNotification(bundle)
            addCall(context.applicationContext, Data.fromBundle(bundle))
            if (customPath != null) {
                CustomRingtonePlayer.start(context, customPath)
            }
            Log.d(TAG, "showIncoming callId=$callId caller=${data["callerId"]} custom=${customPath != null}")
        } catch (e: Exception) {
            Log.e(TAG, "showIncoming failed", e)
        }
    }

    /**
     * Chemin du fichier de sonnerie importé actuellement sélectionné, ou null
     * si l'utilisateur est sur la sonnerie système / fournie par l'app (dans
     * ces cas CallKit joue son propre son). Écrit par Flutter
     * (`RingtonePreferences`) dans les SharedPreferences du plugin
     * shared_preferences.
     */
    private fun resolveCustomRingtonePath(context: Context): String? {
        return try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            val path = prefs.getString("flutter.call_ringtone_active_path", null)
                ?.trim()
                .orEmpty()
            if (path.isNotEmpty() && java.io.File(path).exists()) path else null
        } catch (e: Exception) {
            Log.e(TAG, "resolveCustomRingtonePath failed", e)
            null
        }
    }

    /**
     * Nom de ressource `res/raw` que CallKit doit jouer pour la sonnerie
     * fournie/système sélectionnée (écrit par Flutter `RingtonePreferences`).
     * Défaut : sonnerie système.
     */
    private fun resolveNativeRingtoneName(context: Context): String {
        return try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            prefs.getString("flutter.call_ringtone_native_name", null)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: "system_ringtone_default"
        } catch (e: Exception) {
            Log.e(TAG, "resolveNativeRingtoneName failed", e)
            "system_ringtone_default"
        }
    }

    fun dismissIncomingSilently(context: Context, callId: String) {
        val id = callId.trim()
        if (id.isEmpty()) return
        CallDismissRegistry.markProgrammaticDismiss(id)
        endCall(context, mapOf("callId" to id))
    }

    fun endCall(context: Context, data: Map<String, String>) {
        ensureInitialized(context)
        lastShownCallId = null
        CustomRingtonePlayer.stop()
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

    private fun buildIncomingBundle(
        data: Map<String, String>,
        ringtonePath: String = "system_ringtone_default",
    ): android.os.Bundle {
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
                // Résolu par l'appelant : nom de ressource res/raw compilée
                // ('ringback', 'system_ringtone_default'), ou 'silence' quand on
                // joue nous-mêmes un fichier importé (voir CustomRingtonePlayer).
                // NB : passer "" ne rend PAS muet — le plugin retombe alors sur
                // la sonnerie système.
                "ringtonePath" to ringtonePath,
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
