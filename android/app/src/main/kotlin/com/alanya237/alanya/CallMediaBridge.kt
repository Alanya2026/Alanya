package com.alanya237.alanya

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Pont Flutter → [CallMediaForegroundService]
 * Canal : `com.alanya237.alanya/call_media` (start / stop).
 */
object CallMediaBridge {
    private const val TAG = "CallMediaBridge"
    private const val CHANNEL = "com.alanya237.alanya/call_media"

    fun attach(messenger: BinaryMessenger, context: Context) {
        val appCtx = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    try {
                        CallMediaForegroundService.start(appCtx, isVideo)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "start failed", e)
                        result.error("start_failed", e.message, null)
                    }
                }
                "stop" -> {
                    try {
                        CallMediaForegroundService.stop(appCtx)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "stop failed", e)
                        result.error("stop_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
