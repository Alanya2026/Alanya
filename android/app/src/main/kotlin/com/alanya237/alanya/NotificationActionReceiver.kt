package com.alanya237.alanya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.app.RemoteInput
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Actions notification : réponse rapide et marquer comme lu (Phase 4.3–4.4).
 *
 * Ordre impératif dans chaque branche :
 *  1. enfiler dans [NotificationActionQueue], de façon SYNCHRONE (`.commit()`) —
 *     si le process meurt à la seconde suivante, Flutter rejouera ;
 *  2. retour visuel immédiat (bulle optimiste / annulation de la notif) ;
 *  3. POST sous `goAsync()` : sans lui, le process — démarré pour ce seul
 *     broadcast quand l'app est tuée, LE cas d'usage — passait en état
 *     « empty » dès le retour de onReceive et pouvait être tué avant la fin
 *     du POST.
 */
class NotificationActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val convId = intent.getIntExtra(MessageNotificationHelper.EXTRA_CONVERSATION_ID, 0)
        if (convId <= 0) return
        val app = context.applicationContext

        when (intent.action) {
            MessageNotificationHelper.ACTION_MARK_READ -> {
                NotificationActionQueue.enqueue(
                    app, NotificationActionQueue.KIND_READ, convId, null, null,
                )
                MessageNotificationHelper.cancelConversation(app, convId)
                postWithReceiverAlive(app, NotificationActionQueue.KIND_READ, convId, null, null)
            }
            MessageNotificationHelper.ACTION_REPLY -> {
                val results = RemoteInput.getResultsFromIntent(intent)
                val text = results
                    ?.getCharSequence(MessageNotificationHelper.KEY_REPLY_TEXT)
                    ?.toString()
                    ?.trim()
                if (text.isNullOrEmpty()) return
                // Clé d'idempotence serveur : persistée avec l'entrée, le rejeu
                // Dart réutilise LA MÊME — jamais deux messages pour une réponse.
                val clientId = "notif_${System.currentTimeMillis()}_$convId"
                NotificationActionQueue.enqueue(
                    app, NotificationActionQueue.KIND_REPLY, convId, text, clientId,
                )
                // Mise à jour optimiste du fil de notification. Les extras posés
                // par buildReplyAction étaient ignorés : sans eux, le titre
                // devenait « Moi » et un groupe perdait son nom.
                MessageNotificationHelper.appendOutgoing(
                    app,
                    convId,
                    text,
                    isGroup = intent.getBooleanExtra(MessageNotificationHelper.EXTRA_IS_GROUP, false),
                    groupName = intent.getStringExtra(MessageNotificationHelper.EXTRA_GROUP_NAME) ?: "",
                    senderName = intent.getStringExtra(MessageNotificationHelper.EXTRA_SENDER_NAME) ?: "",
                )
                postWithReceiverAlive(app, NotificationActionQueue.KIND_REPLY, convId, text, clientId)
            }
        }
    }

    /**
     * Maintient le process en importance RECEIVER pendant le POST.
     *
     * Watchdog à 8,5 s : le budget d'un broadcast est borné (~10 s, ANR
     * au-delà) et le pire cas réseau — POST 7 s, refresh, retry — le dépasse.
     * Si le watchdog coupe avant la fin, l'entrée est déjà en file : rien
     * n'est perdu, Flutter rejouera.
     */
    private fun postWithReceiverAlive(
        app: Context,
        kind: String,
        convId: Int,
        text: String?,
        clientId: String?,
    ) {
        val pending = goAsync()
        val finished = AtomicBoolean(false)
        val finishOnce: () -> Unit = {
            if (finished.compareAndSet(false, true)) {
                try {
                    pending.finish()
                } catch (_: Exception) {
                }
            }
        }
        Handler(Looper.getMainLooper()).postDelayed({ finishOnce() }, 8_500)
        NotificationActionHelper.postAsync(app, kind, convId, text, clientId) { finishOnce() }
    }
}
