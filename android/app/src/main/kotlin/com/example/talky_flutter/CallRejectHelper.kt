package com.example.talky_flutter

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Persistance + POST /calls/reject côté natif (app tuée / sans Flutter).
 * Clés SharedPreferences alignées sur [PendingCallRejectStore] Flutter.
 */
object CallRejectHelper {
    private const val TAG = "CallRejectHelper"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_PENDING = "flutter.pending_call_rejects_v1"
    private const val KEY_TOKEN = "flutter.call_reject_access_token"
    private const val KEY_API_BASE = "flutter.call_reject_api_base"
    private val executor = Executors.newSingleThreadExecutor()

    fun enqueueAndPost(context: Context, callerId: String, callId: String?) {
        if (callerId.isBlank()) return
        enqueuePending(context, callerId, callId)
        executor.execute {
            try {
                postReject(context, callerId, callId)
            } catch (e: Exception) {
                Log.e(TAG, "postReject failed", e)
            }
        }
    }

    fun enqueuePending(context: Context, callerId: String, callId: String?) {
        try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, null)
            val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
            val next = JSONArray()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                if (obj.optString("callerId") == callerId) continue
                next.put(obj)
            }
            val entry = JSONObject()
            entry.put("callerId", callerId)
            if (!callId.isNullOrBlank()) entry.put("callId", callId)
            entry.put("ts", System.currentTimeMillis())
            next.put(entry)
            prefs.edit().putString(KEY_PENDING, next.toString()).apply()
            Log.i(TAG, "enqueue callerId=$callerId callId=$callId")
        } catch (e: Exception) {
            Log.e(TAG, "enqueuePending failed", e)
        }
    }

    private fun postReject(context: Context, callerId: String, callId: String?) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)
        if (token.isNullOrBlank() || apiBase.isNullOrBlank()) {
            Log.w(TAG, "token/apiBase manquants — refus en file pour Flutter")
            return
        }

        val url = URL("${apiBase.trimEnd('/')}/calls/reject")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 8000
            readTimeout = 8000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }

        val body = JSONObject()
        body.put("callerId", callerId.toIntOrNull() ?: callerId)
        if (!callId.isNullOrBlank()) body.put("callId", callId)

        OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
        val code = conn.responseCode
        Log.i(TAG, "POST /calls/reject → HTTP $code")
        if (code in 200..299) {
            removePending(context, callerId, callId)
        }
        conn.disconnect()
    }

    private fun removePending(context: Context, callerId: String, callId: String?) {
        try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, null) ?: return
            val arr = JSONArray(raw)
            val next = JSONArray()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                if (obj.optString("callerId") == callerId) {
                    val existing = obj.optString("callId", "")
                    if (callId.isNullOrBlank() || existing.isEmpty() || existing == callId) {
                        continue
                    }
                }
                next.put(obj)
            }
            prefs.edit().putString(KEY_PENDING, next.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "removePending failed", e)
        }
    }
}
