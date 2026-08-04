# Audit des appels — RCA « appels entrants app tuée » et correctifs (29/07/2026)

Symptômes : app tuée → aucune notification d'appel ; ouvrir l'app pendant la sonnerie →
parfois OK, parfois l'appel est coupé aussitôt ; écran d'appel fantôme à la réouverture.
App au premier plan : tout fonctionne (socket, backend, WebRTC sains).

Le commit `b834040` (« essai de résolution du bug de l'appel ») n'était **pas** la cause
principale : il ne touche que le flux post-acceptation, or le symptôme dominant se produit
en amont. Quatre causes superposées formaient un cercle vicieux.

## Root Cause Analysis

### C1 — Le push d'appel n'est jamais affiché (cause primaire)
Le renommage du paquet (`02aa181`) a changé de projet Firebase (`talky-2026` →
`alanya-9233f`). Tout token d'une installation antérieure est invalide pour le nouvel
expéditeur (`SENDER_ID_MISMATCH`). Or le backend ne purgeait les tokens morts que dans
`users.fcm_token`, jamais dans `user_push_devices` — la table lue **en priorité** pour les
appels (`resolveCallPushTargets`). Un token mort y restait ciblé à chaque appel, en échec
silencieux (erreurs avalées, ni retry ni log visible). Le premier plan passe par le socket,
donc rien n'alertait.

À vérifier aussi côté appareil (H2) : nouvelle app = `POST_NOTIFICATIONS`, full-screen
intent (Android 14+) et exemption batterie à re-consentir ; un test via « Forcer l'arrêt »
(paramètres) bloque les FCM par design Android (stopped state) — tuer par swipe des récents.

### C2 — Crash du foreground service à l'acceptation app tuée (le crash historique)
Au tap « Accepter », le plugin démarrait `CallkitNotificationService` via
`startForegroundService`, mais le service capture son `CallkitNotificationManager` **à la
construction** depuis `FlutterCallkitIncomingPlugin.getInstance()` — null sans engine
Flutter. `startForeground()` n'était jamais appelé →
`ForegroundServiceDidNotStartInTimeException` ~10 s après l'acceptation → process tué en
plein appel, entrée `ACTIVE_CALLS` `isAccepted=true` résiduelle.

### C3 — b834040 : correctif inopérant
Son broadcast `ACTION_CALL_START` retombait sur la **même instance** du service, au champ
manager déjà figé à null — le « filet de sécurité » ne pouvait mécaniquement pas rattraper
le `startForeground` manquant.

### C4 — Le nettoyage cold-start tuait l'appel vivant (l'intermittence observée)
Les débris `ACTIVE_CALLS` nettoyés au démarrage par `CallKitService.endAll()` n'étaient pas
marqués « programmatiques » → `TalkyApplication` les prenait pour des refus utilisateur →
`POST /calls/reject` natif avec un *vieux* callId → côté backend, `processRejectCall`
faisait `callState.clear` de la paire **sans vérifier le callId** → l'appel qui sonnait
était rejeté. Variante : débris `isAccepted=true` → auto-réponse fantôme au boot.

## Correctifs appliqués

### Backend (Alanya-Backend)
| Fichier | Changement |
|---|---|
| `src/services/notificationService.js` | Détection élargie des tokens morts (`mismatched-credential` / SenderId mismatch) ; purge **aussi** dans `user_push_devices` ; `console.error` explicite (code inclus) sur tout échec FCM de type appel ; TTL des pushs d'appel 60 s → 45 s (aligné sur `NO_ANSWER_MS`). |
| `src/socket/handlers/calls.js` | Garde anti-fratricide dans `processRejectCall` : un refus dont le `callIdHint` diffère de l'appel courant de la paire ne touche plus `callState`/`pendingCalls` (mise à jour DB du vieil appel uniquement, `status=0` → 2). |
| `src/socket/state/callState.js` + `chat/presence.js` | Grâce courte (10 s, `scheduleRingingDisconnectGrace`) quand une socket tombe **pendant la sonnerie**, au lieu d'une fin immédiate — nécessaire pour l'accept cold-start dont la première socket peut être instable. Annulée par `auth:login` et toute transition d'état. |

### Natif Android (Talky)
| Fichier | Changement |
|---|---|
| `CallIncomingHelper.kt` | `EXTRA_CALLKIT_CALLING_SHOW=false` dans le bundle d'entrant : le tap « Accepter » ne démarre plus un FGS intenable (branche plugin `startService` + `stopSelf`, sans contrat `startForeground`) → **supprime le crash C2**. `endCall` marque les retraits comme programmatiques (push `call_ended` ≠ refus). `shownAt` (epoch ms) ajouté à l'extra pour la fraîcheur au cold start. Durée de sonnerie 30 s → 40 s. Nouveau `clearIncomingNotification` pour l'acceptation. |
| `TalkyApplication.kt` | À la transition `isAccepted` d'une entrée, efface la notification entrante (la branche ACCEPT du plugin ne peut plus le faire). |
| `CallNativeBridge.kt` | Nouvelle méthode `markProgrammaticDismiss(callIds)` exposée à Flutter. |

### Flutter (Talky)
| Fichier | Changement |
|---|---|
| `callkit_service.dart` | `showIncoming` : `callingNotification: showNotification=false` (même contrat que le natif), durée 40 s, `shownAt` dans l'extra. `endCall`/`endAll` : marquage programmatique natif **avant** le retrait (endAll marque toutes les entrées). `_handleEvent` : pending **ou** stream, jamais les deux (fin du double dispatch). `getActiveCall` : sélection par fraîcheur (`shownAt`), débris ignorés (non accepté > 90 s, accepté > 3 min). Nouveau `purgeStaleActiveCalls()`. |
| `main.dart` | Bootstrap : purge silencieuse des débris quand `getActiveCall` ne retourne rien de plausible. **Latence de l'accept** : le dispatch des actions CallKit (et le repli `getActiveCall`) passe AVANT `PushService.init` — ce dernier fait du réseau (`getToken` FCM) et des dialogues de permission, et retardait de plusieurs secondes l'écran d'appel après le tap « Accepter » (spinner → home → appel). Le chemin critique se limite désormais à : boot engine → restauration session locale → bind providers → dispatch. |
| `call_one_to_one.dart` | `answerCall` : `startCallKit: true` explicite — c'est désormais **le seul** point de démarrage du FGS Android, une fois l'engine prêt (l'intention de b834040, rendue correcte par le flag CALLING_SHOW). |
| `call_incoming.dart` | Garde d'idempotence dans `acceptIncomingCallFromPush` (double événement / double clic / repli activeCalls → no-op si l'appel est déjà en cours de réponse). |

## Vérification (Étape 0 — avant/après déploiement)

Audit SQL des tokens du compte de test (remplacer `<ID>`) :
```sql
SELECT deviceId, LEFT(fcmToken,20) AS tok, platform, notificationsEnabled, lastHeartbeatAt
FROM user_push_devices WHERE alanyaID = <ID>;
SELECT LEFT(fcm_token,20) AS tok, device_ID FROM users WHERE alanyaID = <ID>;
```
Toute ligne dont le token date d'avant le renommage du paquet est morte ; après déploiement
du correctif, le premier appel la passera à `INDEFINI` (visible dans les logs
`notification_token_stale`).

Logcat pendant un appel app-tuée :
```bash
adb logcat -s TalkyFCM:V TalkyCallIncoming:V TalkyApplication:V ActivityManager:E AndroidRuntime:E
```
Attendu : `onMessageReceived` → `showIncoming callId=…` → (accept) → transition
`isAccepted` → boot Flutter → `answer_call` — et **zéro**
`ForegroundServiceDidNotStartInTimeException`.

Logs backend : `[FCM][CALL] échec envoi …` (nouveau) signale tout push d'appel raté avec le
code d'erreur exact ; `[processRejectCall] refus tardif ignoré…` signale un reject
fratricide neutralisé.

## Matrice de test (2 appareils, dont un Android 14+)
1. App tuée (swipe) → appel : notification + sonnerie, Accepter → écran d'appel en ~1-2 s
   (plus de spinner prolongé ni de passage visible par l'accueil), appel stable > 60 s.
2. App tuée → Refuser depuis la notification → l'appelant voit le refus.
3. App tuée → tap sur le corps de la notification → écran entrant, sonnerie continue.
4. App en arrière-plan : mêmes trois scénarios.
5. Premier plan : écran entrant direct, pas de notification.
6. Écran verrouillé : full-screen intent, décrocher depuis l'écran verrouillé.
7. Ouvrir l'app pendant la sonnerie → l'appel continue, jamais coupé.
8. Appelant raccroche avant réponse → notification retirée, pas de reject parasite en DB.
9. Ne pas répondre → notif expire à 40 s, serveur classe « sans réponse » à 45 s (status 3).
10. Deux appels successifs rapides → jamais deux écrans/notifications simultanés.
11. Après un échec quelconque, rouvrir l'app → aucun appel fantôme, débris purgés.

Limite connue (non corrigée, mineure) : un timeout de notification côté client est envoyé
comme un refus (`status=2`) s'il précède le timeout serveur ; les statuts « manqué » (3)
ne sont garantis que quand le serveur tranche. À traiter si les logs d'appels doivent être
exacts au refus près.
