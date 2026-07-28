package com.alanya237.alanya

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import android.util.Log
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

    private const val TAG = "TalkyNativeNotif"
    private const val PREFS = "talky_native_notif"
    private const val KEY_BUFFER_PREFIX = "buf_"
    private const val KEY_OPEN_PREFIX = "open_"
    private const val MAX_BUFFER = 7
    private const val LOCAL_USER_NAME = "Moi"

    private val bufferLock = Any()

    // v3 : introduit un son de notification. Les canaux Android étant
    // immuables une fois créés, on change d'ID (et on supprime l'ancien) pour
    // que le son s'applique sans réinstallation.
    const val CHANNEL_ID = "talky_messages_v3"
    private const val LEGACY_CHANNEL_ID = "talky_messages_v2"
    const val ACTION_REPLY = "com.alanya237.alanya.NOTIF_REPLY"
    const val ACTION_MARK_READ = "com.alanya237.alanya.NOTIF_MARK_READ"
    const val EXTRA_CONVERSATION_ID = "conversationId"
    const val EXTRA_SENDER_NAME = "senderName"
    const val EXTRA_IS_GROUP = "isGroup"
    const val EXTRA_GROUP_NAME = "groupName"
    const val KEY_REPLY_TEXT = "key_reply_text"

    fun shouldSuppress(context: Context, data: Map<String, String>): Boolean {
        val convId = data["conversationId"]?.toIntOrNull() ?: return false
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val active = FlutterSharedPreferencesCompat.readInt(prefs, "push_active_conv_id")
        return active != null && active == convId
    }

    fun showMessage(context: Context, data: Map<String, String>) {
        val convId = data["conversationId"]?.toIntOrNull() ?: return
        val msgID = data["msgID"]?.toIntOrNull() ?: 0
        val eventId = data["eventId"]?.trim().orEmpty()

        if (NotificationDedupHelper.isAlreadyHandled(context, msgID, eventId)) {
            Log.d(TAG, "skip duplicate msgID=$msgID eventId=$eventId")
            return
        }
        if (!NotificationDedupHelper.tryReserve(context, msgID, eventId)) {
            Log.d(TAG, "skip reserved msgID=$msgID eventId=$eventId")
            return
        }

        val senderName = data["senderName"] ?: data["title"] ?: "Alanya"
        val body = data["body"] ?: ""
        val isGroup = data["isGroup"] == "1"
        val groupName = data["groupName"] ?: ""

        val displayBody = if (isGroup) "$senderName: $body" else body
        val buffer = appendBuffer(context, convId, senderName, displayBody, msgID)
        val openExtras = mapOf(
            "type" to (data["type"] ?: "message"),
            EXTRA_CONVERSATION_ID to convId.toString(),
            "title" to (data["title"] ?: senderName),
            "senderName" to senderName,
            "isGroup" to if (isGroup) "1" else "0",
            "groupName" to groupName,
            "msgID" to (data["msgID"] ?: ""),
            "senderId" to (data["senderId"] ?: ""),
        )
        // Conservés pour qu'une réécriture après réponse rapide n'appauvrisse pas
        // les extras du PendingIntent de contenu.
        persistOpenExtras(context, convId, openExtras)
        postNotification(
            context,
            convId,
            isGroup,
            groupName,
            senderName,
            displayBody,
            buffer,
            openExtras,
        )
        NotificationDedupHelper.markShown(context, msgID, eventId)
    }

    /**
     * Réécrit la notification après MA réponse rapide.
     *
     * [isGroup], [groupName] et [senderName] viennent des extras du PendingIntent
     * de l'action : sans eux, le titre devenait « Moi » et un groupe perdait son
     * nom. Les extras d'ouverture sont relus depuis le disque pour que le tap
     * navigue toujours correctement — le PendingIntent est en FLAG_UPDATE_CURRENT,
     * donc des extras appauvris écraseraient les bons.
     */
    fun appendOutgoing(
        context: Context,
        convId: Int,
        text: String,
        isGroup: Boolean,
        groupName: String,
        senderName: String,
    ) {
        val buffer = appendBuffer(context, convId, LOCAL_USER_NAME, text, isOutgoing = true)
        postNotification(
            context,
            convId,
            isGroup,
            groupName,
            senderName,
            text,
            buffer,
            readOpenExtras(context, convId, isGroup, groupName, senderName),
            alertOnce = true,
        )
    }

    fun cancelConversation(context: Context, conversationId: Int) {
        val tag = "conv_$conversationId"
        val notifId = notificationIdForConversation(conversationId)
        NotificationManagerCompat.from(context).cancel(tag, notifId)
        synchronized(bufferLock) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_BUFFER_PREFIX + conversationId)
                .remove(KEY_OPEN_PREFIX + conversationId)
                .commit()
        }
    }

    private fun postNotification(
        context: Context,
        convId: Int,
        isGroup: Boolean,
        groupName: String,
        senderName: String,
        latestLine: String,
        buffer: List<BufferEntry>,
        openExtras: Map<String, String> = emptyMap(),
        alertOnce: Boolean = false,
    ) {
        ensureChannel(context)
        val notifId = notificationIdForConversation(convId)
        val tag = "conv_$convId"

        val selfPerson = Person.Builder().setName(LOCAL_USER_NAME).build()
        val style = NotificationCompat.MessagingStyle(selfPerson)
            .setGroupConversation(isGroup)
            .setConversationTitle(if (isGroup && groupName.isNotEmpty()) groupName else null)

        for (entry in buffer) {
            // Person null = « c'est moi » pour MessagingStyle. Un Person portant
            // le nom « Moi » n'est pas reconnu comme le selfPerson (il faudrait
            // une clé stable), et ma réponse rapide s'affichait donc comme un
            // message reçu.
            val person = if (entry.isOutgoing) {
                null
            } else {
                Person.Builder().setName(entry.sender).build()
            }
            style.addMessage(entry.body, entry.timestamp, person)
        }

        val title = if (isGroup && groupName.isNotEmpty()) groupName else senderName

        // Intent explicite MainActivity : Flutter lit les extras au tap
        // (getLaunchIntentForPackage ne suffit pas pour la navigation).
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_NOTIFICATION_OPEN, true)
            putExtra(EXTRA_CONVERSATION_ID, convId)
            putExtra("type", openExtras["type"] ?: "message")
            for ((k, v) in openExtras) {
                if (k != EXTRA_CONVERSATION_ID) putExtra(k, v)
            }
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
            // Réécriture après MA réponse rapide : ne pas re-sonner ni relever un
            // heads-up pour mon propre message. Reste à false pour un message
            // entrant, qui doit alerter.
            .setOnlyAlertOnce(alertOnce)
            // Pas de setGroup : évite le bundle Android qui n'affiche que le dernier message.
            .addAction(buildReplyAction(context, convId, isGroup, groupName, senderName))
            .addAction(buildMarkReadAction(context, convId))

        // exceptId : sans lui, on annulait la notification qu'on s'apprête à
        // réécrire, et un cancel suivi d'un notify est un NOUVEAU post pour le
        // système — donc une ré-alerte, même avec setOnlyAlertOnce.
        cancelNotificationsWithTag(context, tag, exceptId = notifId)
        NotificationManagerCompat.from(context).notify(tag, notifId, builder.build())
        Log.d(TAG, "posted conv=$convId messages=${buffer.size} tag=$tag id=$notifId alertOnce=$alertOnce")
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
        // Nettoie l'ancien canal silencieux (best-effort).
        try {
            mgr.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        } catch (_: Exception) {}
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Messages Alanya"
            enableVibration(true)
            // Son de notification par défaut du téléphone (canal notification).
            val attrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
            setSound(Settings.System.DEFAULT_NOTIFICATION_URI, attrs)
        }
        mgr.createNotificationChannel(channel)
    }

    private data class BufferEntry(
        val sender: String,
        val body: String,
        val timestamp: Long,
        val msgID: Int = 0,
        /** Ma propre réponse rapide : rendue sans Person, donc alignée à droite. */
        val isOutgoing: Boolean = false,
    )

    private fun appendBuffer(
        context: Context,
        convId: Int,
        sender: String,
        body: String,
        msgID: Int = 0,
        isOutgoing: Boolean = false,
    ): List<BufferEntry> {
        synchronized(bufferLock) {
            val list = readBufferUnlocked(context, convId).toMutableList()
            if (msgID > 0 && list.any { it.msgID == msgID }) {
                Log.d(TAG, "buffer skip duplicate msgID=$msgID conv=$convId")
                return list
            }
            list.add(BufferEntry(sender, body, System.currentTimeMillis(), msgID, isOutgoing))
            val deduped = dedupeBufferEntries(list)
            val trimmed = if (deduped.size > MAX_BUFFER) deduped.takeLast(MAX_BUFFER) else deduped
            persistBufferUnlocked(context, convId, trimmed)
            Log.d(TAG, "buffer conv=$convId size=${trimmed.size}")
            return trimmed
        }
    }

    /** Retire les doublons (ex. ancienne fusion notif active + buffer). */
    private fun dedupeBufferEntries(entries: List<BufferEntry>): List<BufferEntry> {
        if (entries.size < 2) return entries
        val result = mutableListOf<BufferEntry>()
        for (entry in entries) {
            val duplicate = result.any { existing ->
                (entry.msgID > 0 && existing.msgID == entry.msgID) ||
                    (existing.sender == entry.sender &&
                        existing.body == entry.body &&
                        kotlin.math.abs(existing.timestamp - entry.timestamp) < 5000L)
            }
            if (!duplicate) result.add(entry)
        }
        return result
    }

    /**
     * Purge les notifications du même tag restées sur un ancien id (le hash a pu
     * changer). [exceptId] préserve celle qu'on est en train de réécrire.
     */
    private fun cancelNotificationsWithTag(context: Context, tag: String, exceptId: Int = 0) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        for (sbn in nm.activeNotifications) {
            if (sbn.tag == tag && sbn.id != exceptId) {
                NotificationManagerCompat.from(context).cancel(sbn.tag, sbn.id)
            }
        }
    }

    private fun persistOpenExtras(context: Context, convId: Int, extras: Map<String, String>) {
        try {
            val o = JSONObject()
            for ((k, v) in extras) o.put(k, v)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_OPEN_PREFIX + convId, o.toString())
                .apply()
        } catch (e: Exception) {
            Log.w(TAG, "persistOpenExtras failed conv=$convId", e)
        }
    }

    /**
     * Extras d'ouverture mémorisés au dernier message reçu. Repli sur le strict
     * nécessaire si rien n'a été mémorisé (buffer purgé, ancienne version).
     */
    private fun readOpenExtras(
        context: Context,
        convId: Int,
        isGroup: Boolean,
        groupName: String,
        senderName: String,
    ): Map<String, String> {
        val fallback = mapOf(
            "type" to "message",
            EXTRA_CONVERSATION_ID to convId.toString(),
            "title" to (if (isGroup && groupName.isNotEmpty()) groupName else senderName),
            EXTRA_SENDER_NAME to senderName,
            EXTRA_IS_GROUP to if (isGroup) "1" else "0",
            EXTRA_GROUP_NAME to groupName,
        )
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_OPEN_PREFIX + convId, null) ?: return fallback
        return try {
            val o = JSONObject(raw)
            buildMap {
                for (key in o.keys()) put(key, o.optString(key, ""))
                if (isEmpty()) putAll(fallback)
            }
        } catch (_: Exception) {
            fallback
        }
    }

    private fun persistBufferUnlocked(
        context: Context,
        convId: Int,
        entries: List<BufferEntry>,
    ) {
        val arr = JSONArray()
        for (e in entries) {
            val o = JSONObject()
            o.put("sender", e.sender)
            o.put("body", e.body)
            o.put("ts", e.timestamp)
            if (e.msgID > 0) o.put("msgID", e.msgID)
            if (e.isOutgoing) o.put("out", true)
            arr.put(o)
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_BUFFER_PREFIX + convId, arr.toString())
            .commit()
    }

    private fun readBufferUnlocked(context: Context, convId: Int): List<BufferEntry> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_BUFFER_PREFIX + convId, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            val parsed = buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    add(
                        BufferEntry(
                            sender = o.optString("sender", ""),
                            body = o.optString("body", ""),
                            timestamp = o.optLong("ts", System.currentTimeMillis()),
                            msgID = o.optInt("msgID", 0),
                            isOutgoing = o.optBoolean("out", false),
                        ),
                    )
                }
            }
            dedupeBufferEntries(parsed)
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
