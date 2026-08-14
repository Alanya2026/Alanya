package com.alanya237.alanya

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationBodyTest {

    @Test
    fun `retire le prefixe serveur une fois`() {
        assertEquals(
            "Hello team",
            MessageNotificationHelper.stripLeadingSenderPrefix("Bob", "Bob: Hello team"),
        )
    }

    @Test
    fun `retire aussi l ancien double prefixe client`() {
        assertEquals(
            "Hello team",
            MessageNotificationHelper.stripLeadingSenderPrefix("Bob", "Bob: Bob: Hello team"),
        )
    }

    @Test
    fun `ne touche pas un 1-1 sans prefixe`() {
        assertEquals(
            "Salut",
            MessageNotificationHelper.stripLeadingSenderPrefix("Alice", "Salut"),
        )
    }

    @Test
    fun `maxStrips 0 = no-op`() {
        assertEquals(
            "Bob: Hello",
            MessageNotificationHelper.stripLeadingSenderPrefix("Bob", "Bob: Hello", 0),
        )
    }

    @Test
    fun `nom vide = no-op`() {
        assertEquals(
            "Bob: Hello",
            MessageNotificationHelper.stripLeadingSenderPrefix("", "Bob: Hello"),
        )
    }
}
