package com.example.talky_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Pont natif → Flutter pour les actions CallKit (raccrochage / refus depuis
 * la notification quand l'événement plugin n'atteint pas Dart).
 */
object CallNativeBridge {

    private const val CHANNEL = "com.alanya/call_native"
    private var channel: MethodChannel? = null
    private var ready = false

    fun attach(binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, CHANNEL)
        ready = true
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
