package com.example.talky_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import org.json.JSONArray
import org.json.JSONObject

/**
 * Notifications messages Android natives — MessagingStyle, actions reply / mark read.
 */
object MessageNotificationHelper {

    private const val PREFS = "talky_native_notif"
    private const val KEY_BUFFER_PREFIX = "buf_"
    private const val MAX_BUFFER = 7

    const val CHANNEL_ID = "talky_messages_v2"
    const val ACTION_REPLY = "com.example.talky_flutter.NOTIF_REPLY"
    const val ACTION_MARK_READ = "com.example.talky_flutter.NOTIF_MARK_READ"
    const val EXTRA_CONVERSATION_ID = "conversationId"
    const val EXTRA_SENDER_NAME = "senderName"
    const val EXTRA_IS_GROUP = "isGroup"
    const val EXTRA_GROUP_NAME = "groupName"
    const val KEY_REPLY_TEXT = "key_reply_text"

    fun shouldSuppress(context: Context, data: Map<String, String>): Boolean {
        val convId = data["conversationId"]?.toIntOrNull() ?: return false
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val active = prefs.getString("flutter.push_active_conv_id", null)?.toIntOrNull()
        return active != null && active == convId
    }

    fun showMessage(context: Context, data: Map<String, String>) {
        val convId = data["conversationId"]?.toIntOrNull() ?: return
        val senderName = data["senderName"] ?: data["title"] ?: "Alanya"
        val body = data["body"] ?: ""
        val isGroup = data["isGroup"] == "1"
        val groupName = data["groupName"] ?: ""

        val displayBody = if (isGroup) "$senderName: $body" else body
        appendBuffer(context, convId, senderName, displayBody)
        postNotification(context, convId, isGroup, groupName, senderName, displayBody)
    }

    fun appendOutgoing(context: Context, convId: Int, text: String) {
        appendBuffer(context, convId, "Moi", text)
        postNotification(context, convId, false, "", "Moi", text)
    }

    fun cancelConversation(context: Context, conversationId: Int) {
        val tag = "conv_$conversationId"
        val notifId = notificationIdForConversation(conversationId)
        NotificationManagerCompat.from(context).cancel(tag, notifId)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_BUFFER_PREFIX + conversationId)
            .apply()
    }

    private fun postNotification(
        context: Context,
        convId: Int,
        isGroup: Boolean,
        groupName: String,
        senderName: String,
        latestLine: String,
    ) {
        ensureChannel(context)
        val notifId = notificationIdForConversation(convId)
        val tag = "conv_$convId"
        val buffer = readBuffer(context, convId)

        val selfPerson = Person.Builder().setName("Moi").build()
        val style = NotificationCompat.MessagingStyle(selfPerson)
            .setConversationTitle(if (isGroup && groupName.isNotEmpty()) groupName else null)

        for (entry in buffer) {
            val person = Person.Builder().setName(entry.sender).build()
            style.addMessage(entry.body, entry.timestamp, person)
        }

        val title = if (isGroup && groupName.isNotEmpty()) groupName else senderName

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_CONVERSATION_ID, convId)
            }

        val contentPending = PendingIntent.getActivity(
            context,
            convId,
            launchIntent,
            pendingFlags(),
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(0xFF114B86.toInt())
            .setContentTitle(title)
            .setContentText(latestLine)
            .setStyle(style)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .setGroup("talky_messages")
            .addAction(buildReplyAction(context, convId, isGroup, groupName, senderName))
            .addAction(buildMarkReadAction(context, convId))

        NotificationManagerCompat.from(context).notify(tag, notifId, builder.build())
    }

    private fun buildReplyAction(
        context: Context,
        convId: Int,
        isGroup: Boolean,
        groupName: String,
        senderName: String,
    ): NotificationCompat.Action {
        val remoteInput = RemoteInput.Builder(KEY_REPLY_TEXT)
            .setLabel("Répondre")
            .build()

        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_REPLY
            putExtra(EXTRA_CONVERSATION_ID, convId)
            putExtra(EXTRA_IS_GROUP, isGroup)
            putExtra(EXTRA_GROUP_NAME, groupName)
            putExtra(EXTRA_SENDER_NAME, senderName)
        }

        val pending = PendingIntent.getBroadcast(
            context,
            convId + 10_000,
            intent,
            pendingFlags(mutable = true),
        )

        return NotificationCompat.Action.Builder(
            R.drawable.ic_stat_notification,
            "Répondre",
            pending,
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()
    }

    private fun buildMarkReadAction(context: Context, convId: Int): NotificationCompat.Action {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_MARK_READ
            putExtra(EXTRA_CONVERSATION_ID, convId)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            convId + 20_000,
            intent,
            pendingFlags(),
        )
        return NotificationCompat.Action.Builder(
            R.drawable.ic_stat_notification,
            "Lu",
            pending,
        ).build()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Messages Alanya (v2)"
            enableVibration(true)
        }
        mgr.createNotificationChannel(channel)
    }

    private data class BufferEntry(
        val sender: String,
        val body: String,
        val timestamp: Long,
    )

    private fun appendBuffer(
        context: Context,
        convId: Int,
        sender: String,
        body: String,
    ) {
        val list = readBuffer(context, convId).toMutableList()
        list.add(BufferEntry(sender, body, System.currentTimeMillis()))
        val trimmed = if (list.size > MAX_BUFFER) list.takeLast(MAX_BUFFER) else list
        val arr = JSONArray()
        for (e in trimmed) {
            val o = JSONObject()
            o.put("sender", e.sender)
            o.put("body", e.body)
            o.put("ts", e.timestamp)
            arr.put(o)
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_BUFFER_PREFIX + convId, arr.toString())
            .apply()
    }

    private fun readBuffer(context: Context, convId: Int): List<BufferEntry> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_BUFFER_PREFIX + convId, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    add(
                        BufferEntry(
                            sender = o.optString("sender", ""),
                            body = o.optString("body", ""),
                            timestamp = o.optLong("ts", System.currentTimeMillis()),
                        ),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Aligné sur NotificationIdentity Flutter (FNV-1a 31 bits). */
    fun notificationIdForConversation(conversationId: Int): Int {
        if (conversationId <= 0) return 0
        var hash = 0x811c9dc5.toInt()
        for (ch in conversationId.toString()) {
            hash = hash xor ch.code
            hash = (hash * 0x01000193) and 0xffffffff.toInt()
        }
        return hash and 0x7fffffff
    }

    private fun pendingFlags(mutable: Boolean = false): Int {
        val base = PendingIntent.FLAG_UPDATE_CURRENT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            base or if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE
        } else {
            base
        }
    }
}
