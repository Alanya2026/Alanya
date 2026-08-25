package com.alanya237.alanya

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.hiennv.flutter_callkit_incoming.CallkitConstants
import com.hiennv.flutter_callkit_incoming.CallkitNotificationManager
import com.hiennv.flutter_callkit_incoming.CallkitNotificationService
import com.hiennv.flutter_callkit_incoming.CallkitSoundPlayerManager
import com.hiennv.flutter_callkit_incoming.Data
import com.hiennv.flutter_callkit_incoming.addCall
import com.hiennv.flutter_callkit_incoming.getDataActiveCalls
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
            // Le plugin recharge une URL d'avatar puis reposte la notification.
            // Sur certains Samsung, ce second `notify` redéclenche le
            // fullScreenIntent et ouvre deux CallkitIncomingActivity pour le
            // même callId. La notification native n'a donc pas d'avatar distant;
            // l'entrée ACTIVE_CALLS conserve en revanche le bundle complet pour
            // que Flutter retrouve callerPhoto après l'acceptation/cold start.
            val notificationBundle = Bundle(bundle).apply {
                putString(CallkitConstants.EXTRA_CALLKIT_AVATAR, "")
            }
            notificationManager?.showIncomingNotification(notificationBundle)
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

    /**
     * Coupe la sonnerie native jouée par CETTE instance (soundManager propre).
     * Nécessaire car le BroadcastReceiver du plugin arrête le soundManager du
     * plugin (ou rien si l'app est tuée : FlutterCallkitIncomingPlugin.getInstance()
     * est null), jamais celui-ci → sinon la sonnerie continue après refus/accept.
     */
    fun stopSound() {
        try {
            soundManager?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "stopSound failed", e)
        }
    }

    /**
     * Annule la vibration d'appel entrant.
     *
     * La présentation entrante démarre une vibration à motif RÉPÉTITIF (un seul
     * appel à `service.vibrate`, puis des cycles on/off toutes les 2 s). Retirer
     * la notification ne l'arrête pas : une vibration lancée par programme avec
     * répétition court jusqu'à annulation explicite. Mesuré sur la trace B2 du
     * 25/08 : notification republiée retirée à 16:07:51.615, son coupé à
     * 16:07:52.122, mais vibration de 16:07:51.309 à 16:08:15.309 — 24 s après
     * le décrochage, perçues comme une seconde sonnerie.
     */
    fun stopVibration(context: Context) {
        try {
            val vibrator: Vibrator? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    (context.applicationContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                        as? VibratorManager)?.defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    context.applicationContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                }
            vibrator?.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "stopVibration failed", e)
        }
    }

    /**
     * Annule explicitement la notification d'appel EN COURS d'un [callId] (id
     * calqué sur le plugin : `("ongoing_$callId").hashCode()`). Complète
     * stopService : sur certains OEM la notif de service au premier plan ne
     * disparaît pas toujours à l'arrêt du service.
     */
    fun cancelOngoingNotification(context: Context, callId: String) {
        val id = callId.trim()
        if (id.isEmpty()) return
        try {
            NotificationManagerCompat.from(context.applicationContext)
                .cancel("ongoing_$id".hashCode())
        } catch (e: Exception) {
            Log.e(TAG, "cancelOngoingNotification failed", e)
        }
    }

    fun endCall(context: Context, data: Map<String, String>) {
        ensureInitialized(context)
        lastShownCallId = null
        // Annuler la vibration entrante : son motif est répétitif et survit au
        // retrait de la notification comme à l'arrêt du lecteur audio.
        stopVibration(context)
        // Couper la sonnerie importée jouée nativement (voir CustomRingtonePlayer).
        CustomRingtonePlayer.stop()
        // …et la sonnerie par défaut jouée par le soundManager de CETTE instance.
        // Elle n'était coupée que dans la branche `callId.isEmpty()` plus bas :
        // avec un callId précis — le cas de dismissIncomingSilently, donc de la
        // preview dupliquée — elle continuait jusqu'au timeout du plugin. Mesuré
        // sur la trace T17 : vibrations de 16:08:00.831 à 16:08:30.831, soit
        // 30,2 s après l'accept, puis 44 s en T18. L'arrêt de ACTIVE_CALLS ne
        // suffit pas, il dépend qu'aucun entrant non accepté ne subsiste.
        soundManager?.stop()
        // Coupe aussi le service/notification d'appel EN COURS (chronomètre +
        // raccrocher). Le plugin ne le fait pas quand getInstance() est null
        // (app tuée) → sinon notification fantôme aux boutons morts après l'appel.
        try {
            CallkitNotificationService.stopService(context.applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "stopService (endCall) failed", e)
        }
        val callId = (data["callId"] ?: "").trim()
        // Retrait piloté par le serveur (push call_ended) ou par Flutter — pas
        // un refus utilisateur : marquer AVANT removeCall pour que le listener
        // ACTIVE_CALLS de TalkyApplication ne POST pas /calls/reject.
        try {
            if (callId.isNotEmpty()) {
                CallDismissRegistry.markProgrammaticDismiss(callId)
            } else {
                getDataActiveCalls(context.applicationContext).forEach {
                    CallDismissRegistry.markProgrammaticDismiss(it.id)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "markProgrammaticDismiss (endCall) failed", e)
        }
        try {
            if (callId.isEmpty()) {
                soundManager?.stop()
                removeAllCalls(context.applicationContext)
                Log.d(TAG, "endCall all")
                return
            }
            cancelOngoingNotification(context, callId)
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
        val sessionId = (data["sessionId"] ?: "").trim()
        val roomId = (data["roomId"] ?: sessionId).ifBlank {
            if (callId.startsWith("conf_")) callId else ""
        }
        val photo = data["photo"] ?: ""

        val extra = hashMapOf<String, Any?>(
            "callId" to callId,
            "callerId" to callerId,
            "callerName" to callerName,
            "callerPhoto" to photo,
            "isVideo" to isVideo,
            "roomId" to roomId,
            "sessionId" to (sessionId.ifBlank { if (callId.startsWith("conf_")) callId else "" }),
            "sessionKind" to (data["sessionKind"] ?: if (callId.startsWith("conf_")) "conference" else ""),
            "mode" to (data["mode"] ?: ""),
            // Fraîcheur pour le cold start Flutter (main.dart) : une entrée
            // ACTIVE_CALLS résiduelle d'un essai précédent ne doit jamais
            // déclencher une auto-réponse ou un écran entrant fantôme.
            "shownAt" to System.currentTimeMillis(),
        )

        val args = hashMapOf<String, Any?>(
            "id" to callId,
            "nameCaller" to callerName,
            "appName" to "Alanya",
            "handle" to callerId,
            "avatar" to photo,
            "type" to if (isVideo) 1 else 0,
            // Sous le NO_ANSWER_MS serveur (45 s) : la notification doit expirer
            // AVANT que le serveur classe l'appel « sans réponse », jamais après.
            "duration" to 40000L,
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
        val bundle = Data(args).toBundle()
        // CRUCIAL — quand l'app est tuée, le tap « Accepter » déclenche
        // ContextCompat.startForegroundService(CallkitNotificationService) alors
        // que le service ne peut PAS appeler startForeground() : son
        // CallkitNotificationManager vient de FlutterCallkitIncomingPlugin
        // .getInstance(), null tant qu'aucun engine Flutter n'est attaché →
        // ForegroundServiceDidNotStartInTimeException ~10 s après l'acceptation,
        // le process meurt en plein appel. Avec ce flag à false, l'accept passe
        // par startService + stopSelf (aucun contrat startForeground) ; le
        // foreground service légitime est démarré ensuite par Dart
        // (CallKitService.startOutgoingCall) une fois l'engine prêt.
        bundle.putBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW, false)
        return bundle
    }

    /**
     * Efface la notification d'appel ENTRANT d'un [callId] (sonnerie comprise).
     * Utilisé par TalkyApplication quand l'appel passe à isAccepted : la branche
     * ACCEPT du service plugin ne peut pas le faire (manager null app tuée), et
     * avec EXTRA_CALLKIT_CALLING_SHOW=false elle fait stopSelf() immédiatement.
     */
    fun clearIncomingNotification(context: Context, callId: String) {
        val id = callId.trim()
        if (id.isEmpty()) return
        ensureInitialized(context)
        // Point le plus précoce du flux : TalkyApplication appelle ceci dès la
        // bascule isAccepted. La vibration répétitive doit y être annulée aussi,
        // sans quoi elle survit au retrait de la notification.
        stopVibration(context)
        try {
            val bundle = Data(hashMapOf<String, Any?>("id" to id)).toBundle()
            notificationManager?.clearIncomingNotification(bundle, true)
        } catch (e: Exception) {
            Log.e(TAG, "clearIncomingNotification failed", e)
        }
    }
}
