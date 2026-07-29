package com.alanya237.alanya

import android.content.Context
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
