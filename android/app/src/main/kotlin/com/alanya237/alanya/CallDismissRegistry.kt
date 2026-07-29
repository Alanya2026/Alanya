package com.alanya237.alanya

import java.util.Collections

/**
 * CallIds retirés de CallKit par Flutter (migration foreground, anti-doublon),
 * pas par un refus utilisateur — ne pas POST /calls/reject dans ce cas.
 */
object CallDismissRegistry {
    private val programmaticIds =
        Collections.synchronizedSet(mutableSetOf<String>())

    fun markProgrammaticDismiss(callId: String) {
        val id = callId.trim()
        if (id.isNotEmpty()) programmaticIds.add(id)
    }

    fun consumeIfProgrammatic(callId: String): Boolean {
        val id = callId.trim()
        if (id.isEmpty()) return false
        return programmaticIds.remove(id)
    }
}
