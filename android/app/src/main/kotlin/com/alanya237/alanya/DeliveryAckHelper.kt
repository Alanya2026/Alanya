package com.alanya237.alanya

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Accusé de REMISE émis depuis la notification push, app fermée.
 *
 * Sans lui, un message n'est marqué « remis » (2 coches grises) que lorsque le
 * destinataire rouvre l'app et que son socket se reconnecte : l'expéditeur
 * reste bloqué sur une seule coche alors que le terminal a bel et bien reçu la
 * notification. `TalkyFirebaseMessagingService` tourne même processus tué, donc
 * c'est le seul endroit où l'accusé peut partir à temps.
 *
 * Clés SharedPreferences partagées avec [CallRejectHelper] / PendingCallRejectStore :
 * ce sont les seules à porter un refresh token, indispensable quand l'access
 * token a expiré pendant que l'app dormait.
 */
object DeliveryAckHelper {
    private const val TAG = "DeliveryAckHelper"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_PENDING = "flutter.pending_delivery_acks_v1"
    private const val KEY_TOKEN = "flutter.call_reject_access_token"
    private const val KEY_REFRESH = "flutter.call_reject_refresh_token"
    private const val KEY_API_BASE = "flutter.call_reject_api_base"

    /** Au-delà, l'accusé n'a plus d'intérêt : l'app aura resynchronisé avant. */
    private const val MAX_AGE_MS = 24L * 60 * 60 * 1000
    private const val MAX_PENDING = 50

    private val executor = Executors.newSingleThreadExecutor()

    /**
     * Enfile puis tente d'envoyer l'accusé. L'enfilage précède le POST pour que
     * rien ne soit perdu si le processus est tué pendant la requête.
     */
    fun enqueueAndPost(context: Context, conversationId: String?, msgID: String?) {
        val convId = conversationId?.trim().orEmpty()
        if (convId.isEmpty()) return
        enqueuePending(context, convId, msgID)
        executor.execute {
            try {
                postDelivered(context, convId, msgID)
            } catch (e: Exception) {
                Log.e(TAG, "postDelivered failed", e)
            }
        }
    }

    fun enqueuePending(context: Context, conversationId: String, msgID: String?) {
        try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, null)
            val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
            val next = JSONArray()
            val cutoff = System.currentTimeMillis() - MAX_AGE_MS
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                // Un seul accusé par conversation : le serveur marque toute la
                // conversation d'un coup, un second appel ne changerait rien.
                if (obj.optString("conversationId") == conversationId) continue
                if (obj.optLong("ts", 0L) < cutoff) continue
                next.put(obj)
            }
            val entry = JSONObject()
            entry.put("conversationId", conversationId)
            if (!msgID.isNullOrBlank()) entry.put("msgID", msgID)
            entry.put("ts", System.currentTimeMillis())
            next.put(entry)
            while (next.length() > MAX_PENDING) next.remove(0)
            prefs.edit().putString(KEY_PENDING, next.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "enqueuePending failed", e)
        }
    }

    private fun postDelivered(context: Context, conversationId: String, msgID: String?) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        var token = prefs.getString(KEY_TOKEN, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)
        if (token.isNullOrBlank() || apiBase.isNullOrBlank()) {
            Log.w(TAG, "token/apiBase manquants — accusé en file pour Flutter")
            return
        }

        var code = doDeliveredPost(apiBase, token, conversationId, msgID)

        // Access token expiré pendant le sommeil de l'app : rafraîchir via
        // l'endpoint stateless (il ne périme pas le refresh stocké par Flutter)
        // puis réessayer UNE fois.
        if (code == 401) {
            val newToken = refreshAccessToken(context, apiBase)
            if (!newToken.isNullOrBlank()) {
                token = newToken
                code = doDeliveredPost(apiBase, token, conversationId, msgID)
            }
        }

        Log.i(TAG, "POST /messages/delivered conv=$conversationId → HTTP $code")
        // 404 = conversation inconnue ou plus participant : inutile de rejouer.
        if (code in 200..299 || code == 404) {
            removePending(context, conversationId)
        }
        // Sinon : l'accusé reste en file, rejoué par Flutter à la prochaine ouverture.
    }

    /** Retourne le code HTTP, -1 en cas d'échec réseau. */
    private fun doDeliveredPost(
        apiBase: String,
        token: String,
        conversationId: String,
        msgID: String?,
    ): Int {
        val url = URL("${apiBase.trimEnd('/')}/messages/delivered")
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
            body.put("conversationId", conversationId.toLongOrNull() ?: conversationId)
            if (!msgID.isNullOrBlank()) {
                body.put("msgID", msgID.toLongOrNull() ?: msgID)
            }
            OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
            conn.responseCode
        } catch (e: Exception) {
            Log.e(TAG, "doDeliveredPost failed", e)
            -1
        } finally {
            conn.disconnect()
        }
    }

    /**
     * Rafraîchit l'access token via POST /auth/refresh. Même endpoint stateless
     * que [CallRejectHelper] : rafraîchir côté natif ne désynchronise pas Flutter.
     */
    private fun refreshAccessToken(context: Context, apiBase: String): String? {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val refresh = prefs.getString(KEY_REFRESH, null)
        if (refresh.isNullOrBlank()) {
            Log.w(TAG, "refresh token manquant — accusé en file pour Flutter")
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
                Log.w(TAG, "refresh → HTTP $code (accusé en file)")
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

    private fun removePending(context: Context, conversationId: String) {
        try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, null) ?: return
            val arr = JSONArray(raw)
            val next = JSONArray()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                if (obj.optString("conversationId") == conversationId) continue
                next.put(obj)
            }
            prefs.edit().putString(KEY_PENDING, next.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "removePending failed", e)
        }
    }
}
