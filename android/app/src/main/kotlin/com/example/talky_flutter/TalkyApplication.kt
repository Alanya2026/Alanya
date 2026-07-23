package com.example.talky_flutter

import android.app.Application
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Détecte un refus CallKit même si l'Intent est explicite (plugin) et que
 * Flutter n'est pas booté.
 *
 * Ordre cold-start decline :
 * 1. Application.onCreate → snapshot ACTIVE_CALLS + listener
 * 2. CallkitIncomingBroadcastReceiver → removeCall
 * 3. Listener → appel disparu non accepté → POST /calls/reject
 */
class TalkyApplication : Application() {
    companion object {
        private const val TAG = "TalkyApplication"
        private const val CALLKIT_PREFS = "flutter_callkit_incoming"
        private const val KEY_ACTIVE = "ACTIVE_CALLS"
    }

    /** Référence forte obligatoire (sinon GC du listener). */
    private lateinit var callkitPrefs: SharedPreferences
    private var activeCallsSnapshot: JSONArray = JSONArray()

    private val activeCallsListener =
        SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == KEY_ACTIVE) onActiveCallsChanged()
        }

    override fun onCreate() {
        super.onCreate()
        callkitPrefs = getSharedPreferences(CALLKIT_PREFS, MODE_PRIVATE)
        activeCallsSnapshot = readActiveCalls()
        callkitPrefs.registerOnSharedPreferenceChangeListener(activeCallsListener)
        Log.i(TAG, "CallKit ACTIVE_CALLS listener armé (snapshot=${activeCallsSnapshot.length()})")
        CallIncomingHelper.ensureInitialized(this)
    }

    private fun onActiveCallsChanged() {
        val before = activeCallsSnapshot
        val after = readActiveCalls()
        activeCallsSnapshot = after

        for (i in 0 until before.length()) {
            val prev = before.optJSONObject(i) ?: continue
            val id = prev.optString("id", "")
            if (id.isEmpty()) continue
            val stillThere = (0 until after.length()).any { j ->
                after.optJSONObject(j)?.optString("id") == id
            }
            if (stillThere) continue

            if (CallDismissRegistry.consumeIfProgrammatic(id)) {
                Log.i(TAG, "ACTIVE_CALLS: dismiss programmatique id=$id (pas de reject)")
                continue
            }

            val callerId = extractCallerId(prev)
            val callId = extractCallId(prev)
            val wasAccepted = prev.optBoolean("isAccepted", false)

            if (wasAccepted) {
                Log.i(TAG, "ACTIVE_CALLS: raccrochage notif id=$id callId=$callId")
                CallNativeBridge.notifyCallEnded(callId, callerId)
                continue
            }

            if (callerId.isNullOrBlank()) {
                Log.w(TAG, "ACTIVE_CALLS: retrait sans callerId id=$id")
                continue
            }
            Log.i(TAG, "ACTIVE_CALLS: refus/timeout détecté caller=$callerId callId=$callId")
            CallRejectHelper.enqueueAndPost(this, callerId, callId)
            CallNativeBridge.notifyCallEnded(callId, callerId)
        }
    }

    private fun readActiveCalls(): JSONArray {
        return try {
            val raw = callkitPrefs.getString(KEY_ACTIVE, "[]") ?: "[]"
            JSONArray(raw)
        } catch (e: Exception) {
            Log.e(TAG, "readActiveCalls failed", e)
            JSONArray()
        }
    }

    private fun extractCallerId(call: JSONObject): String? {
        val extra = call.optJSONObject("extra")
        val fromExtra = extra?.optString("callerId")?.trim()
        if (!fromExtra.isNullOrEmpty()) return fromExtra
        // Parfois extra est sérialisé différemment ; handle = callerId côté Talky.
        val handle = call.optString("handle", "").trim()
        return handle.ifEmpty { null }
    }

    private fun extractCallId(call: JSONObject): String? {
        val extra = call.optJSONObject("extra")
        val fromExtra = extra?.optString("callId")?.trim()
        if (!fromExtra.isNullOrEmpty()) return fromExtra
        val id = call.optString("id", "").trim()
        return id.ifEmpty { null }
    }
}
