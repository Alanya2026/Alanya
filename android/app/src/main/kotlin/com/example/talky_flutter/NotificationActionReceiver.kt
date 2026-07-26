package com.example.talky_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

/**
 * Actions notification : réponse rapide et marquer comme lu (Phase 4.3–4.4).
 */
class NotificationActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val convId = intent.getIntExtra(MessageNotificationHelper.EXTRA_CONVERSATION_ID, 0)
        if (convId <= 0) return

        when (intent.action) {
            MessageNotificationHelper.ACTION_MARK_READ -> {
                NotificationActionHelper.enqueueMarkRead(context, convId)
                MessageNotificationHelper.cancelConversation(context, convId)
            }
            MessageNotificationHelper.ACTION_REPLY -> {
                val results = RemoteInput.getResultsFromIntent(intent)
                val text = results
                    ?.getCharSequence(MessageNotificationHelper.KEY_REPLY_TEXT)
                    ?.toString()
                    ?.trim()
                if (text.isNullOrEmpty()) return
                val clientId = "notif_${System.currentTimeMillis()}_$convId"
                NotificationActionHelper.enqueueReply(context, convId, text, clientId)
                // Mise à jour optimiste du fil de notification. Les extras posés
                // par buildReplyAction étaient ignorés : sans eux, le titre
                // devenait « Moi » et un groupe perdait son nom.
                MessageNotificationHelper.appendOutgoing(
                    context,
                    convId,
                    text,
                    isGroup = intent.getBooleanExtra(MessageNotificationHelper.EXTRA_IS_GROUP, false),
                    groupName = intent.getStringExtra(MessageNotificationHelper.EXTRA_GROUP_NAME) ?: "",
                    senderName = intent.getStringExtra(MessageNotificationHelper.EXTRA_SENDER_NAME) ?: "",
                )
            }
        }
    }
}
