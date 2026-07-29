package com.alanya237.alanya

import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Logique pure de la file d'actions. Le format JSON testé ici est un contrat
 * inter-langages : `PendingNotificationActionStore` (Dart) lit exactement ces
 * champs — `kind`, `conversationId`, `text`, `clientId`, `ts`, `attempts`.
 */
class NotificationActionQueueTest {

    private val now = 1_700_000_000_000L

    private fun entries(raw: String) = JSONArray(raw)

    @Test
    fun `enqueue pose tous les champs du contrat`() {
        val raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_REPLY, 42, "salut", "notif_1_42", now,
        )
        val arr = entries(raw)
        assertEquals(1, arr.length())
        val o = arr.getJSONObject(0)
        assertEquals("reply", o.getString("kind"))
        assertEquals(42, o.getInt("conversationId"))
        assertEquals("salut", o.getString("text"))
        assertEquals("notif_1_42", o.getString("clientId"))
        assertEquals(now, o.getLong("ts"))
        assertEquals(0, o.getInt("attempts"))
    }

    @Test
    fun `un seul read par conversation`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_READ, 7, null, null, now,
        )
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_READ, 7, null, null, now + 1000,
        )
        assertEquals(1, entries(raw).length())
        // Une autre conversation cohabite.
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_READ, 8, null, null, now + 2000,
        )
        assertEquals(2, entries(raw).length())
    }

    @Test
    fun `deux replies distincts sont conserves`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_REPLY, 7, "premier", "cid_a", now,
        )
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_REPLY, 7, "second", "cid_b", now + 1,
        )
        assertEquals(2, entries(raw).length())
    }

    @Test
    fun `meme clientId remplace l'entree, pas de doublon`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_REPLY, 7, "texte", "cid_a", now,
        )
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_REPLY, 7, "texte", "cid_a", now + 1,
        )
        assertEquals(1, entries(raw).length())
    }

    @Test
    fun `un reply ne deduplique pas un read de la meme conversation`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_READ, 7, null, null, now,
        )
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_REPLY, 7, "texte", "cid_a", now + 1,
        )
        assertEquals(2, entries(raw).length())
    }

    @Test
    fun `les entrees perimees sont purgees a l'enqueue`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_REPLY, 7, "vieux", "cid_old", now,
        )
        val later = now + NotificationActionQueue.MAX_AGE_MS + 1
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_REPLY, 8, "neuf", "cid_new", later,
        )
        val arr = entries(raw)
        assertEquals(1, arr.length())
        assertEquals("cid_new", arr.getJSONObject(0).getString("clientId"))
    }

    @Test
    fun `plafond MAX_PENDING, les plus anciennes tombent`() {
        var raw: String? = null
        for (i in 1..NotificationActionQueue.MAX_PENDING + 5) {
            raw = NotificationActionQueue.enqueueJson(
                raw, NotificationActionQueue.KIND_REPLY, i, "m$i", "cid_$i", now + i,
            )
        }
        val arr = entries(raw!!)
        assertEquals(NotificationActionQueue.MAX_PENDING, arr.length())
        // La première conservée n'est plus cid_1.
        assertEquals("cid_6", arr.getJSONObject(0).getString("clientId"))
    }

    @Test
    fun `remove reply par clientId, read par conversation`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_REPLY, 7, "a", "cid_a", now,
        )
        raw = NotificationActionQueue.enqueueJson(
            raw, NotificationActionQueue.KIND_READ, 7, null, null, now + 1,
        )
        raw = NotificationActionQueue.removeJson(
            raw, NotificationActionQueue.KIND_REPLY, 7, "cid_a",
        )
        var arr = entries(raw)
        assertEquals(1, arr.length())
        assertEquals("read", arr.getJSONObject(0).getString("kind"))
        raw = NotificationActionQueue.removeJson(
            raw, NotificationActionQueue.KIND_READ, 7, null,
        )
        arr = entries(raw)
        assertEquals(0, arr.length())
    }

    @Test
    fun `bumpAttempts incremente puis abandonne au-dela du plafond`() {
        var raw = NotificationActionQueue.enqueueJson(
            null, NotificationActionQueue.KIND_REPLY, 7, "a", "cid_a", now,
        )
        for (i in 1..NotificationActionQueue.MAX_ATTEMPTS) {
            raw = NotificationActionQueue.bumpAttemptsJson(
                raw, NotificationActionQueue.KIND_REPLY, 7, "cid_a",
            )
            val arr = entries(raw)
            assertEquals("tentative $i conservée", 1, arr.length())
            assertEquals(i, arr.getJSONObject(0).getInt("attempts"))
        }
        raw = NotificationActionQueue.bumpAttemptsJson(
            raw, NotificationActionQueue.KIND_REPLY, 7, "cid_a",
        )
        assertEquals(0, entries(raw).length())
    }

    @Test
    fun `json illisible = file vide, pas d'exception`() {
        val raw = NotificationActionQueue.enqueueJson(
            "{pas du json[", NotificationActionQueue.KIND_READ, 7, null, null, now,
        )
        assertEquals(1, entries(raw).length())
        assertTrue(
            NotificationActionQueue.removeJson("garbage", NotificationActionQueue.KIND_READ, 7, null)
                .let { entries(it).length() == 0 },
        )
    }
}
