package com.example.talky_flutter

import android.content.Context
import org.json.JSONObject

/**
 * Déduplication FCM alignée sur [NotificationDedupStore] Dart (prefs FlutterSharedPreferences).
 */
object NotificationDedupHelper {

    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.notif_dedup_v1"

    fun isAlreadyHandled(context: Context, msgID: Int, eventId: String): Boolean {
        val key = primaryKey(msgID, eventId) ?: return false
        return when (getState(context, key)) {
            "shown", "cancelled" -> true
            else -> false
        }
    }

    fun tryReserve(context: Context, msgID: Int, eventId: String): Boolean {
        val key = primaryKey(msgID, eventId) ?: return true
        return when (getState(context, key)) {
            "shown", "cancelled", "reserved" -> false
            else -> {
                setState(context, key, "reserved")
                true
            }
        }
    }

    fun markShown(context: Context, msgID: Int, eventId: String) {
        val key = primaryKey(msgID, eventId) ?: return
        setState(context, key, "shown")
    }

    private fun primaryKey(msgID: Int, eventId: String): String? {
        if (msgID > 0) return "message:$msgID"
        if (eventId.isNotEmpty()) return "event:$eventId"
        return null
    }

    private fun getState(context: Context, key: String): String? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return null
        return try {
            val map = JSONObject(raw)
            map.optJSONObject(key)?.optString("state")?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private fun setState(context: Context, key: String, state: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val map = try {
            JSONObject(prefs.getString(KEY, null) ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        map.put(
            key,
            JSONObject().apply {
                put("state", state)
                put("updatedAt", System.currentTimeMillis())
            },
        )
        prefs.edit().putString(KEY, map.toString()).commit()
    }
}
