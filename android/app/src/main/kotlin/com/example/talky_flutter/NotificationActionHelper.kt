package com.example.talky_flutter

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * HTTP natif pour actions notification (aligné sur [CallRejectHelper]).
 */
object NotificationActionHelper {
    private const val TAG = "NotifActionHelper"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_TOKEN = "flutter.notif_action_access_token"
    private const val KEY_API_BASE = "flutter.notif_action_api_base"
    private const val PREFS_PENDING = "talky_notif_pending"
    private val executor = Executors.newSingleThreadExecutor()

    fun enqueueMarkRead(context: Context, conversationId: Int) {
        executor.execute {
            try {
                postMarkRead(context, conversationId)
            } catch (e: Exception) {
                Log.e(TAG, "markRead failed conv=$conversationId", e)
                savePending(context, "read", conversationId, null, null)
            }
        }
    }

    fun enqueueReply(
        context: Context,
        conversationId: Int,
        text: String,
        clientId: String,
    ) {
        executor.execute {
            try {
                postReply(context, conversationId, text, clientId)
            } catch (e: Exception) {
                Log.e(TAG, "reply failed conv=$conversationId", e)
                savePending(context, "reply", conversationId, text, clientId)
            }
        }
    }

    private fun postMarkRead(context: Context, conversationId: Int) {
        val creds = readCredentials(context) ?: return
        val url = URL("${creds.apiBase.trimEnd('/')}/conversations/$conversationId/read")
        val conn = openPost(url, creds.token)
        val code = conn.responseCode
        conn.disconnect()
        if (code in 200..299) {
            Log.i(TAG, "markRead OK conv=$conversationId")
        } else {
            throw IllegalStateException("markRead HTTP $code")
        }
    }

    private fun postReply(
        context: Context,
        conversationId: Int,
        text: String,
        clientId: String,
    ) {
        val creds = readCredentials(context) ?: return
        val url = URL("${creds.apiBase.trimEnd('/')}/conversations/$conversationId/messages")
        val conn = openPost(url, creds.token)
        val body = JSONObject()
        body.put("content", text)
        body.put("type", 0)
        body.put("clientId", clientId)
        OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
        val code = conn.responseCode
        conn.disconnect()
        if (code in 200..299) {
            Log.i(TAG, "reply OK conv=$conversationId clientId=$clientId")
        } else {
            throw IllegalStateException("reply HTTP $code")
        }
    }

    private data class Creds(val token: String, val apiBase: String)

    private fun readCredentials(context: Context): Creds? {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)
        if (token.isNullOrBlank() || apiBase.isNullOrBlank()) {
            Log.w(TAG, "credentials manquantes — action en attente Flutter")
            return null
        }
        return Creds(token, apiBase)
    }

    private fun openPost(url: URL, token: String): HttpURLConnection {
        return (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10_000
            readTimeout = 10_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
    }

    private fun savePending(
        context: Context,
        kind: String,
        conversationId: Int,
        text: String?,
        clientId: String?,
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_PENDING, Context.MODE_PRIVATE)
            val o = JSONObject()
            o.put("kind", kind)
            o.put("conversationId", conversationId)
            if (text != null) o.put("text", text)
            if (clientId != null) o.put("clientId", clientId)
            o.put("ts", System.currentTimeMillis())
            prefs.edit().putString("last", o.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "savePending failed", e)
        }
    }
}
