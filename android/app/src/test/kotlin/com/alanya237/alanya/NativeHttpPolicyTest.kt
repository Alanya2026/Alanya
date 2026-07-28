package com.alanya237.alanya

import com.alanya237.alanya.NativeHttpPolicy.Outcome
import org.junit.Assert.assertEquals
import org.junit.Test

class NativeHttpPolicyTest {

    private val reply = NotificationActionQueue.KIND_REPLY
    private val read = NotificationActionQueue.KIND_READ

    @Test
    fun `2xx purge`() {
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(reply, 200))
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(read, 200))
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(reply, 201))
    }

    @Test
    fun `400 et 404 sont terminaux, purge silencieuse`() {
        // 400 : corps invalide — rejouer ne réussira jamais.
        // 404 : plus participant (requireParticipant) — idem.
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(reply, 400))
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(read, 400))
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(reply, 404))
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(read, 404))
    }

    @Test
    fun `403 terminal mais l'utilisateur doit etre prevenu pour un reply`() {
        // Mode annonce / blocage : la bulle optimiste mentirait sinon.
        assertEquals(Outcome.PURGE_NOTIFY, NativeHttpPolicy.classify(reply, 403))
        // Un « lu » refusé n'a rien à dire à l'utilisateur.
        assertEquals(Outcome.PURGE, NativeHttpPolicy.classify(read, 403))
    }

    @Test
    fun `401 apres refresh rate = conserver pour le rejeu Dart`() {
        assertEquals(Outcome.KEEP, NativeHttpPolicy.classify(reply, 401))
        assertEquals(Outcome.KEEP, NativeHttpPolicy.classify(read, 401))
    }

    @Test
    fun `5xx et echec reseau sont transitoires`() {
        assertEquals(Outcome.KEEP, NativeHttpPolicy.classify(reply, 500))
        assertEquals(Outcome.KEEP, NativeHttpPolicy.classify(read, 503))
        assertEquals(Outcome.KEEP, NativeHttpPolicy.classify(reply, -1))
    }
}
