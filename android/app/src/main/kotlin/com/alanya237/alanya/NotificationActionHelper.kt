package com.alanya237.alanya

import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * HTTP natif pour les actions de notification (réponse rapide, marquer lu).
 *
 * Contrat avec [NotificationActionReceiver] : l'entrée est DÉJÀ en file
 * ([NotificationActionQueue]) quand [postAsync] est appelé. Ici on tente
 * l'envoi ; selon le code HTTP on purge, on purge en prévenant l'utilisateur,
 * ou on laisse l'entrée pour le rejeu Dart ([NativeHttpPolicy]).
 *
 * Sur 401, refresh via [NativeAuth] puis UN seul retry — même patron que
 * DeliveryAckHelper / CallRejectHelper. L'ancienne version n'avait ni refresh
 * ni file relue : token périmé (15 min de durée de vie) ⇒ action perdue en
 * silence.
 */
object NotificationActionHelper {
    private const val TAG = "NotifActionHelper"
    private val executor = Executors.newSingleThreadExecutor()

    /**
     * Tente l'envoi sur un thread dédié. [onDone] est appelé quoi qu'il arrive —
     * le receiver s'en sert pour libérer son `goAsync()`.
     */
    fun postAsync(
        context: Context,
        kind: String,
        conversationId: Int,
        text: String?,
        clientId: String?,
        onDone: () -> Unit,
    ) {
        // applicationContext : le Context du receiver meurt au retour de
        // onReceive, l'utiliser ensuite est un comportement non défini.
        val app = context.applicationContext
        executor.execute {
            try {
                post(app, kind, conversationId, text, clientId)
            } catch (e: Exception) {
                Log.e(TAG, "post $kind failed conv=$conversationId", e)
            } finally {
                onDone()
            }
        }
    }

    private fun post(context: Context, kind: String, conversationId: Int, text: String?, clientId: String?) {
        val creds = NativeAuth.read(context)
        if (creds == null) {
            // L'entrée reste en file : Flutter la rejouera une fois connecté.
            // (L'ancien code sortait AVANT tout enfilage : action perdue.)
            Log.w(TAG, "credentials manquantes — $kind conv=$conversationId en file pour Flutter")
            return
        }

        var token = creds.token
        var code = doPost(creds.apiBase, token, kind, conversationId, text, clientId)
        if (code == 401) {
            val fresh = NativeAuth.refresh(context, creds.apiBase)
            if (!fresh.isNullOrBlank()) {
                token = fresh
                code = doPost(creds.apiBase, token, kind, conversationId, text, clientId)
            }
        }

        Log.i(TAG, "$kind conv=$conversationId → HTTP $code")
        when (NativeHttpPolicy.classify(kind, code)) {
            NativeHttpPolicy.Outcome.PURGE ->
                NotificationActionQueue.remove(context, kind, conversationId, clientId)
            NativeHttpPolicy.Outcome.PURGE_NOTIFY -> {
                NotificationActionQueue.remove(context, kind, conversationId, clientId)
                postReplyFailureNotification(context, conversationId)
            }
            NativeHttpPolicy.Outcome.KEEP ->
                NotificationActionQueue.bumpAttempts(context, kind, conversationId, clientId)
        }
    }

    /** Retourne le code HTTP, −1 en cas d'échec réseau. */
    private fun doPost(
        apiBase: String,
        token: String,
        kind: String,
        conversationId: Int,
        text: String?,
        clientId: String?,
    ): Int {
        val base = apiBase.trimEnd('/')
        val url = if (kind == NotificationActionQueue.KIND_READ) {
            URL("$base/conversations/$conversationId/read")
        } else {
            URL("$base/conversations/$conversationId/messages")
        }
        // Timeouts courts : le budget total du broadcast est ~10 s et il doit
        // contenir POST + refresh + retry (watchdog du receiver à 8,5 s).
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 3_000
            readTimeout = 4_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
        return try {
            if (kind == NotificationActionQueue.KIND_REPLY) {
                val body = JSONObject()
                body.put("content", text ?: "")
                body.put("type", 0)
                // Le clientId est la clé d'idempotence serveur (index unique
                // senderID+clientID) : le rejeu Dart réutilise LE MÊME, jamais
                // deux messages pour une réponse.
                body.put("clientId", clientId ?: "")
                OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
            }
            conn.responseCode
        } catch (e: Exception) {
            Log.e(TAG, "doPost $kind failed", e)
            -1
        } finally {
            conn.disconnect()
        }
    }

    /**
     * Échec terminal d'une réponse (403 : mode annonce, blocage). La bulle
     * optimiste est déjà affichée dans le fil de la notification : sans ce
     * signal, elle mentirait définitivement.
     */
    private fun postReplyFailureNotification(context: Context, conversationId: Int) {
        try {
            val notifId = MessageNotificationHelper.notificationIdForConversation(conversationId)
            val builder = NotificationCompat.Builder(context, MessageNotificationHelper.CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_notification)
                .setContentTitle("Réponse non envoyée")
                .setContentText("Votre réponse n'a pas pu être envoyée dans cette conversation.")
                .setCategory(NotificationCompat.CATEGORY_ERROR)
                .setAutoCancel(true)
            NotificationManagerCompat.from(context)
                .notify("conv_fail_$conversationId", notifId, builder.build())
        } catch (e: Exception) {
            Log.w(TAG, "failure notif conv=$conversationId", e)
        }
    }
}
