package com.alanya237.alanya

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Pont natif ↔ Flutter pour les actions CallKit (raccrochage / refus depuis
 * la notification quand l'événement plugin n'atteint pas Dart).
 */
object CallNativeBridge {

    private const val CHANNEL = "com.alanya/call_native"
    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var ready = false

    fun attach(binaryMessenger: io.flutter.plugin.common.BinaryMessenger, context: Context) {
        appContext = context.applicationContext
        channel = MethodChannel(binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "dismissIncomingSilently" -> {
                        val callId = call.argument<String>("callId")?.trim() ?: ""
                        dismissIncomingSilently(callId)
                        result.success(null)
                    }
                    // Flutter s'apprête à retirer ces appels de CallKit
                    // (endCall/endAllCalls) : les marquer AVANT le retrait pour
                    // que TalkyApplication ne les prenne pas pour des refus
                    // utilisateur (sinon POST /calls/reject fratricide).
                    "markProgrammaticDismiss" -> {
                        val ids = call.argument<List<String>>("callIds") ?: emptyList()
                        ids.forEach { CallDismissRegistry.markProgrammaticDismiss(it) }
                        result.success(null)
                    }
                    // Mode de sonnerie du téléphone : 0 silencieux, 1 vibreur,
                    // 2 normal. La sonnerie et la vibration jouées par Flutter
                    // n'en tenaient pas compte (groupe 3GI 2029, bug A9).
                    "getRingerMode" -> {
                        val am = appContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        result.success(am?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        ready = true
    }

    fun dismissIncomingSilently(callId: String) {
        val ctx = appContext ?: return
        if (callId.isEmpty()) return
        CallIncomingHelper.dismissIncomingSilently(ctx, callId)
    }

    fun notifyCallEnded(callId: String?, callerId: String?) {
        // Filet : l'appel est fini côté CallKit, même si Flutter n'a pas pu
        // jouer sa clôture — l'app ne doit plus passer par-dessus le verrou.
        LockScreenBridge.apply(false)
        if (!ready) return
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod(
                "onCallEnded",
                mapOf(
                    "callId" to (callId ?: ""),
                    "callerId" to (callerId ?: ""),
                ),
            )
        }
    }
}
