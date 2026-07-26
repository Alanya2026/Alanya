package com.example.talky_flutter

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Credentials natives partagées entre les helpers qui postent hors app vivante
 * (actions de notification, accusés de remise, refus d'appel).
 *
 * Source de vérité : le trio `flutter.call_reject_*`, écrit par Flutter au
 * login, à chaque refresh ET à chaque démarrage à froid (`auth_provider`,
 * `_hydrateTokensFromStorage`). L'ancien miroir `notif_action_*` n'était écrit
 * qu'app vivante : au réveil, son access token (15 min de durée de vie) était
 * périmé depuis des heures — cause première du « rien ne se passe » des
 * actions de notification.
 *
 * TODO(sécurité) : ces prefs portent un access token 15 min et un refresh token
 * 30 j en clair. Un BroadcastReceiver en process froid ne peut pas lire
 * flutter_secure_storage sans démarrer un moteur Flutter. Le correctif propre
 * est un token d'action dédié côté backend — audience limitée à
 * `/conversations/:id/read` et `/conversations/:id/messages`, révocable,
 * rafraîchi à chaque démarrage — lot backend + client à part.
 */
object NativeAuth {
    private const val TAG = "NativeAuth"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_TOKEN = "flutter.call_reject_access_token"
    private const val KEY_REFRESH = "flutter.call_reject_refresh_token"
    private const val KEY_API_BASE = "flutter.call_reject_api_base"

    // Ancien miroir des actions de notification : lu en repli le temps d'une
    // release, pour un parc mis à jour dont Flutter n'a pas encore réécrit le
    // trio partagé.
    private const val LEGACY_KEY_TOKEN = "flutter.notif_action_access_token"
    private const val LEGACY_KEY_API_BASE = "flutter.notif_action_api_base"

    data class Creds(val token: String, val refreshToken: String?, val apiBase: String)

    fun read(context: Context): Creds? {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)
            ?: prefs.getString(LEGACY_KEY_TOKEN, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)
            ?: prefs.getString(LEGACY_KEY_API_BASE, null)
        if (token.isNullOrBlank() || apiBase.isNullOrBlank()) {
            Log.w(TAG, "token/apiBase manquants")
            return null
        }
        return Creds(token, prefs.getString(KEY_REFRESH, null), apiBase)
    }

    /**
     * Rafraîchit l'access token via POST /auth/refresh. Endpoint stateless
     * (simple jwt.verify côté serveur) : rafraîchir ici ne périme pas le
     * refresh token conservé par Flutter. Retourne le nouvel access token, ou
     * null — l'appelant laisse alors son entrée en file, Flutter rejouera
     * après relogin.
     */
    fun refresh(context: Context, apiBase: String): String? {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val refreshToken = prefs.getString(KEY_REFRESH, null)
        if (refreshToken.isNullOrBlank()) {
            Log.w(TAG, "refresh token manquant")
            return null
        }
        val url = URL("${apiBase.trimEnd('/')}/auth/refresh")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 3_000
            readTimeout = 4_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }
        return try {
            OutputStreamWriter(conn.outputStream).use {
                it.write(JSONObject().put("refreshToken", refreshToken).toString())
            }
            val code = conn.responseCode
            if (code !in 200..299) {
                Log.w(TAG, "refresh → HTTP $code")
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
            Log.e(TAG, "refresh failed", e)
            null
        } finally {
            conn.disconnect()
        }
    }
}
