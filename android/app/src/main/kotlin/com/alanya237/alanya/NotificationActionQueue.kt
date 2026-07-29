package com.alanya237.alanya

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * File persistante des actions de notification (réponse rapide, marquer lu).
 *
 * Écrite AVANT toute tentative réseau : si le process est tué pendant le POST —
 * app fermée, c'est LE cas d'usage — Flutter rejoue à la prochaine ouverture
 * via `PendingNotificationActionStore`. Le format JSON est un contrat
 * inter-langages avec ce store Dart, verrouillé par les tests des deux côtés :
 * `{kind, conversationId, text?, clientId?, ts, attempts}`.
 *
 * Remplace `talky_notif_pending` et sa clé unique `"last"`, qu'aucun code du
 * dépôt ne relisait : une action échouée y était perdue définitivement.
 *
 * La logique est en fonctions pures sur la chaîne JSON, testables en JVM ;
 * les wrappers SharedPreferences sont en bas.
 */
object NotificationActionQueue {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    const val KEY_PENDING = "flutter.pending_notif_actions_v1"

    const val KIND_REPLY = "reply"
    const val KIND_READ = "read"

    /** Au-delà, l'action n'a plus de sens : l'app aura resynchronisé avant. */
    const val MAX_AGE_MS = 24L * 60 * 60 * 1000
    const val MAX_PENDING = 50

    /** Tentatives au-delà desquelles une entrée est abandonnée (natif + Dart). */
    const val MAX_ATTEMPTS = 5

    // ---------------------------------------------------------------- pur ---

    /**
     * Ajoute une entrée. Purge les périmées au passage. Déduplication :
     * un seul `read` par conversation (le serveur marque toute la conversation
     * d'un coup) ; les `reply` ne se dédupliquent QUE par [clientId] — deux
     * réponses distinctes sont deux messages.
     */
    fun enqueueJson(
        raw: String?,
        kind: String,
        conversationId: Int,
        text: String?,
        clientId: String?,
        nowMs: Long,
    ): String {
        val next = JSONArray()
        val cutoff = nowMs - MAX_AGE_MS
        val arr = parse(raw)
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (o.optLong("ts", 0L) < cutoff) continue
            if (kind == KIND_READ &&
                o.optString("kind") == KIND_READ &&
                o.optInt("conversationId") == conversationId
            ) continue
            if (kind == KIND_REPLY &&
                !clientId.isNullOrEmpty() &&
                o.optString("clientId") == clientId
            ) continue
            next.put(o)
        }
        val entry = JSONObject()
        entry.put("kind", kind)
        entry.put("conversationId", conversationId)
        if (!text.isNullOrEmpty()) entry.put("text", text)
        if (!clientId.isNullOrEmpty()) entry.put("clientId", clientId)
        entry.put("ts", nowMs)
        entry.put("attempts", 0)
        next.put(entry)
        while (next.length() > MAX_PENDING) next.remove(0)
        return next.toString()
    }

    fun removeJson(raw: String?, kind: String, conversationId: Int, clientId: String?): String {
        val next = JSONArray()
        val arr = parse(raw)
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (matches(o, kind, conversationId, clientId)) continue
            next.put(o)
        }
        return next.toString()
    }

    /** Incrémente `attempts` ; l'entrée est abandonnée au-delà de [MAX_ATTEMPTS]. */
    fun bumpAttemptsJson(raw: String?, kind: String, conversationId: Int, clientId: String?): String {
        val next = JSONArray()
        val arr = parse(raw)
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (matches(o, kind, conversationId, clientId)) {
                val attempts = o.optInt("attempts", 0) + 1
                if (attempts > MAX_ATTEMPTS) continue
                o.put("attempts", attempts)
            }
            next.put(o)
        }
        return next.toString()
    }

    private fun matches(o: JSONObject, kind: String, conversationId: Int, clientId: String?): Boolean {
        if (o.optString("kind") != kind) return false
        return if (kind == KIND_REPLY && !clientId.isNullOrEmpty()) {
            o.optString("clientId") == clientId
        } else {
            o.optInt("conversationId") == conversationId
        }
    }

    private fun parse(raw: String?): JSONArray =
        if (raw.isNullOrBlank()) JSONArray() else try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }

    // ------------------------------------------------- SharedPreferences ---

    /** `.commit()` : le process peut mourir dans la seconde qui suit. */
    fun enqueue(context: Context, kind: String, conversationId: Int, text: String?, clientId: String?) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val updated = enqueueJson(
            prefs.getString(KEY_PENDING, null),
            kind, conversationId, text, clientId,
            System.currentTimeMillis(),
        )
        prefs.edit().putString(KEY_PENDING, updated).commit()
    }

    fun remove(context: Context, kind: String, conversationId: Int, clientId: String?) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val updated = removeJson(prefs.getString(KEY_PENDING, null), kind, conversationId, clientId)
        prefs.edit().putString(KEY_PENDING, updated).commit()
    }

    fun bumpAttempts(context: Context, kind: String, conversationId: Int, clientId: String?) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val updated = bumpAttemptsJson(prefs.getString(KEY_PENDING, null), kind, conversationId, clientId)
        prefs.edit().putString(KEY_PENDING, updated).commit()
    }
}
