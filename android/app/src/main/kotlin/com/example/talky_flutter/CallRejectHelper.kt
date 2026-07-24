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
    private const val KEY_REFRESH = "flutter.call_reject_refresh_token"
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
        var token = prefs.getString(KEY_TOKEN, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)
        if (token.isNullOrBlank() || apiBase.isNullOrBlank()) {
            Log.w(TAG, "token/apiBase manquants — refus en file pour Flutter")
            return
        }

        var code = doRejectPost(apiBase, token, callerId, callId)

        // Access token expiré : rafraîchir via le refresh token (endpoint stateless,
        // ne périme pas le refresh stocké côté Flutter) puis réessayer UNE fois.
        if (code == 401) {
            val newToken = refreshAccessToken(context, apiBase)
            if (!newToken.isNullOrBlank()) {
                token = newToken
                code = doRejectPost(apiBase, token, callerId, callId)
            }
        }

        Log.i(TAG, "POST /calls/reject → HTTP $code")
        if (code in 200..299) {
            removePending(context, callerId, callId)
        }
        // Sinon : le refus reste en file, rejoué par Flutter à la prochaine ouverture.
    }

    /** POST /calls/reject avec le token fourni. Retourne le code HTTP (-1 si échec réseau). */
    private fun doRejectPost(apiBase: String, token: String, callerId: String, callId: String?): Int {
        val url = URL("${apiBase.trimEnd('/')}/calls/reject")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 8000
            readTimeout = 8000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
        return try {
            val body = JSONObject()
            body.put("callerId", callerId.toIntOrNull() ?: callerId)
            if (!callId.isNullOrBlank()) body.put("callId", callId)
            OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
            conn.responseCode
        } catch (e: Exception) {
            Log.e(TAG, "doRejectPost failed", e)
            -1
        } finally {
            conn.disconnect()
        }
    }

    /**
     * Rafraîchit l'access token via POST /auth/refresh. L'endpoint est stateless
     * (il ne périme pas le refresh token) : rafraîchir côté natif ne désynchronise
     * pas Flutter. Met à jour le cache prefs et retourne le nouvel access token,
     * ou null si indisponible / refresh expiré.
     */
    private fun refreshAccessToken(context: Context, apiBase: String): String? {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val refresh = prefs.getString(KEY_REFRESH, null)
        if (refresh.isNullOrBlank()) {
            Log.w(TAG, "refresh token manquant — refus en file pour Flutter")
            return null
        }
        val url = URL("${apiBase.trimEnd('/')}/auth/refresh")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 8000
            readTimeout = 8000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }
        return try {
            OutputStreamWriter(conn.outputStream).use {
                it.write(JSONObject().put("refreshToken", refresh).toString())
            }
            val code = conn.responseCode
            if (code !in 200..299) {
                Log.w(TAG, "refresh → HTTP $code (refus en file)")
                return null
            }
            val resp = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(resp)
            val newAccess = json.optString("accessToken", "")
            val newRefresh = json.optString("refreshToken", "")
            if (newAccess.isBlank()) return null
            prefs.edit().apply {
                putString(KEY_TOKEN, newAccess)
                if (newRefresh.isNotBlank()) putString(KEY_REFRESH, newRefresh)
            }.apply()
            Log.i(TAG, "access token rafraîchi (natif)")
            newAccess
        } catch (e: Exception) {
            Log.e(TAG, "refreshAccessToken failed", e)
            null
        } finally {
            conn.disconnect()
        }
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
