package com.alanya237.alanya

/**
 * Classification du code HTTP d'une action de notification : que faire de
 * l'entrée en file ? Pur, testable en JVM.
 */
object NativeHttpPolicy {
    enum class Outcome { PURGE, PURGE_NOTIFY, KEEP }

    /**
     * - 2xx : fait.
     * - 400 / 404 : définitivement impossible (corps invalide, plus
     *   participant) — rejouer ne réussira jamais, on purge en silence.
     * - 403 : refus métier (mode annonce, blocage). Terminal aussi, mais pour
     *   une réponse il faut le DIRE à l'utilisateur : la bulle optimiste
     *   affichée dans la notification mentirait sinon.
     * - 401 (donc après l'échec du refresh) / 5xx / −1 réseau : transitoire,
     *   l'entrée reste en file et Flutter rejouera.
     */
    fun classify(kind: String, code: Int): Outcome = when {
        code in 200..299 -> Outcome.PURGE
        code == 400 || code == 404 -> Outcome.PURGE
        code == 403 ->
            if (kind == NotificationActionQueue.KIND_REPLY) Outcome.PURGE_NOTIFY
            else Outcome.PURGE
        else -> Outcome.KEEP
    }
}
