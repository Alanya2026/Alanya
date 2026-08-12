package com.alanya237.alanya

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Pont Flutter ↔ [TripLocationForegroundService].
 * Canal : `com.alanya237.alanya/trip_location`.
 *
 * Bidirectionnel, contrairement à [CallMediaBridge] : l'appui sur « Arrêter »
 * dans la notification part du natif et doit remonter à Dart, qui seul sait
 * clore le trajet côté serveur.
 */
object TripLocationBridge {
    private const val TAG = "TripLocationBridge"
    private const val CHANNEL = "com.alanya237.alanya/trip_location"

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger, context: Context) {
        val appCtx = context.applicationContext
        val ch = MethodChannel(messenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        TripLocationForegroundService.stopRequested = false
                        TripLocationForegroundService.start(
                            appCtx,
                            call.argument<String>("title") ?: "Trajet de confiance",
                            call.argument<String>("body") ?: "",
                            call.argument<String>("stopLabel") ?: "Arrêter",
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "start failed", e)
                        result.error("start_failed", e.message, null)
                    }
                }
                "stop" -> {
                    try {
                        TripLocationForegroundService.stop(appCtx)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "stop failed", e)
                        result.error("stop_failed", e.message, null)
                    }
                }
                // Relevé au démarrage : si le service a été arrêté depuis la
                // notification pendant que Dart ne tournait pas, l'intention ne
                // doit pas se perdre.
                "consumeStopRequest" -> {
                    val demande = TripLocationForegroundService.stopRequested
                    TripLocationForegroundService.stopRequested = false
                    result.success(demande)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Remonte l'appui sur « Arrêter » à Dart, s'il écoute encore. */
    fun notifyStopRequested() {
        try {
            channel?.invokeMethod("stopRequested", null)
        } catch (e: Exception) {
            Log.w(TAG, "notifyStopRequested failed", e)
        }
    }
}
