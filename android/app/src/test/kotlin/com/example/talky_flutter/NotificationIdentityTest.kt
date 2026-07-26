package com.example.talky_flutter

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Verrouille le hash FNV-1a 31 bits contre son pendant Dart
 * (`NotificationIdentity.notificationIdForConversation`,
 * `test/notifications/notification_identity_test.dart` porte les MÊMES
 * vecteurs). Si les deux divergent, l'annulation croisée des notifications
 * (tag + id) entre le natif et Flutter casse en silence.
 */
class NotificationIdentityTest {

    @Test
    fun `vecteurs partages avec Dart`() {
        assertEquals(873_244_444, MessageNotificationHelper.notificationIdForConversation(1))
        assertEquals(923_577_301, MessageNotificationHelper.notificationIdForConversation(2))
        assertEquals(132_351_363, MessageNotificationHelper.notificationIdForConversation(42))
        assertEquals(352_233_207, MessageNotificationHelper.notificationIdForConversation(99))
        assertEquals(429_242_026, MessageNotificationHelper.notificationIdForConversation(123456))
    }

    @Test
    fun `id invalide = 0`() {
        assertEquals(0, MessageNotificationHelper.notificationIdForConversation(0))
        assertEquals(0, MessageNotificationHelper.notificationIdForConversation(-5))
    }

    @Test
    fun `toujours positif sur 31 bits`() {
        for (id in intArrayOf(1, 7, 1000, Int.MAX_VALUE)) {
            val hash = MessageNotificationHelper.notificationIdForConversation(id)
            assertEquals(0, hash and Int.MIN_VALUE)
        }
    }
}
