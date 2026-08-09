/// Checklist E2E manuelle — fiabilité appels (lots A0–B / A3).
///
/// Exécuter après build debug sur appareils réels (Samsung + OEM agressif).
///
/// ## Reconnexion 1–1
/// - [ ] Wi‑Fi ↔ 4G mid-call : UI « Reconnexion… », audio revient, pas de raccrochage immédiat
/// - [ ] Seul le caller envoie call_rejoin / ICE restart (callee attend)
/// - [ ] Disconnected < 4 s puis Connected : aucun end_call, aucun ICE restart
/// - [ ] Timeout ~45 s sans reprise : end_call reçu backend + peer call_ended
/// - [ ] endCall volontaire pendant reconnecting : pas de restart tardif
///
/// ## Resume / multi-device
/// - [ ] Kill app owner + relance : call_resume → ack + rejoin + CallSessionGuard/FGS
/// - [ ] Device secondaire : ne reçoit pas call_resume (ou ignore) ; reject n’arrête pas B1
/// - [ ] Owner absent (ownership vide) : pas de broadcast resume ; fin après RESUME_OWNER_MISSING
///
/// ## Audio / veille
/// - [ ] Lockscreen 2 min audio : micro audible côté pair
/// - [ ] Mute + lockscreen : reste muet
/// - [ ] Appel audio : FGS types MICROPHONE seul (logcat CallMediaFGS)
/// - [ ] Appel vidéo : FGS MICROPHONE|CAMERA ; iOS vidéo figée OK si audio continue
///
/// ## Groupe / transfert
/// - [ ] Mesh 3 : perte seul lien A↔C → B↔C continue ; A ne leave pas C
/// - [ ] Transfert timeouts 10 s / 25 s inchangés
///
/// ## ICE génération
/// - [ ] Après restart : candidats gen ancienne ignorés (logs « gen périmée »)
