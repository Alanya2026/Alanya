# Plan : correction du marquage erroné "non lu → lu"

## Contexte

Dans Talky, une conversation ouverte doit être traitée comme « tout lue »
(contrat actuel : `conversation ouverte = tout marqué lu`). Le bug : **certains
messages entrants sont marqués comme lus sans l'avoir été réellement**, leur
`unreadCount` est effacé et l'accusé de lecture n'est pas correctement émis.

### Cause racine (race condition)

Dans `lib/screens/chats/chat_detail_screen.dart`, `_attachToConversation`
(lignes 168-192) exécute, dans cet ordre :

1. `syncMessages(convId)` — **fire-and-forget sans await** (ligne 181)
2. `joinConversation` socket (ligne 189) — le serveur commence à pousser les messages
3. `setActiveConversation(convId)` — pose `_activeConversationID` (ligne 190)
4. `markAsRead(convId)` — reset `unreadCount=0` (ligne 191)

Tout événement `message:received` arrivant **entre la ligne 189 et la ligne 190**
voit `_activeConversationID == 0` → `_onMessageReceived` (`chat_repository.dart:1441`)
calcule `isActive = false` → il **incrémente `unreadCount`** (ligne 1709), sans
appeler `markConversationRead`. Puis la ligne 191 `markAsRead` remet `unreadCount=0`,
effaçant le message du compteur sans accusé correct. C'est la fuite « non lu → lu ».

### Décision design (validée par l'utilisateur)

- On **garde** « conversation ouverte = tout marqué lu » (pas de lecture au scroll).
- Le **delta-sync de reconnexion** (`resyncActiveConversation`) doit marquer les
  messages lus si la conversation est active (cohérent avec le design actuel).

## Changements

### 1. Poser `setActiveConversation` AVANT le déclenchement des messages
`lib/screens/chats/chat_detail_screen.dart` — `_attachToConversation`

Réordonner pour que `_activeConversationID` soit posé **avant** `syncMessages`
et `joinConversation` :

```dart
Future<void> _attachToConversation(int convId) async {
  final voice = context.read<VoicePlaybackService>();
  voice
    ..setChatContext(...)
    ..enterChat(convId);

  // 1) Poser la conversation active AVANT tout flux entrant, pour que
  //    tout message reçu pendant la sync/join soit vu comme actif.
  _chat.repository.setActiveConversation(convId);

  // 2) Rejoindre la room puis synchroniser l'historique.
  _apiClient.sendSocketEvent(
    SocketEvents.joinConversation, {'conversationID': convId});
  unawaited(_chat.repository.syncMessages(convId));
  unawaited(_chat.repository.reconcileVoiceLocalPaths(convId));

  // 3) Marquer comme lu (idempotent : ne fait rien si déjà lu).
  _chat.repository.markAsRead(convId);
}
```

Cela élimine la fenêtre où un message entrant voit `isActive=false`.

### 2. Rendre le delta-sync cohérent avec l'état actif
`lib/core/services/chat_repository.dart` — `resyncActiveConversation` (ligne 1292)

Cette méthode est appelée depuis **3 sites** (pas seulement la reconnexion) :
- `_onAuthVerified` (chat_repository.dart:96)
- `chat_provider._onSocketReady` (chat_provider.dart:134)
- `realtime_sync_service.catchUp` (realtime_sync_service.dart:24)

Dans `chat_provider._onSocketReady`, l'ordre est (lignes 129-135) :
`flushOutbox()` → `refreshConversations()` (re-pull serveur `unreadCount`, peut
revenir > 0 → flicker de badge) → `resyncActiveConversation()` → `rejoinActiveRoom()`.
Notre reset `unread=0` **après** le refresh serveur renforce le commentaire
existant (lignes 129-131) : on ré-écrase unread=0 pour la conv active après le
pull, évitant le flicker. Cohérent.

Après `syncMessages(..., delta: true)`, si la conversation est toujours active,
marquer les messages comme lus (comme le ferait `_onMessageReceived` pour un
message actif). Évite qu'après reconnexion les messages reçus pendant la coupure
restent dans un état incohérent (ni unread, ni lus) :

```dart
Future<void> resyncActiveConversation() async {
  if (_activeConversationID == 0) return;
  // GARDE CRITIQUE : markConversationRead fait m.senderID.equals(_myId).not().
  // Si _myId == 0 (appelé avant bind / en course avec auth), il marquerait
  // TOUS les messages (y compris les miens) comme lus et zéroerait unread
  // d'une conv qui n'est peut-être pas la mienne. Refuser dans ce cas.
  if (_myId == 0) return;
  final convID = _activeConversationID;
  await syncMessages(convID, delta: true);
  // La conversation est ouverte : tout message recu pendant la coupure
  // est marqué lu (cohérent avec « ouvert = lu »).
  await _dao.markConversationRead(convID, _myId);
  await _dao.setUnread(convID, 0);
  try {
    _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': convID});
  } catch (_) {
    _pendingReadsRetry[convID] = (_pendingReadsRetry[convID] ?? 0);
  }
}
```

Note : `syncMessages` → `_upsertServerMsg` n'incrémente pas `unreadCount` (le
chemin `fromOther=false` de `_bumpConversationSummary` n'incrémente pas). Donc
pas de risque d'effacer un vrai unread ici ; on garantit seulement la
cohérence « lu ».

#### 2b. Cohérence `flushOutbox` / double émission `messageRead`
`flushOutbox` (ligne 1063-1070) rejoue déjà `_pendingReads` (accusés hors-ligne)
via un émet socket `messageRead` **par conversation**. Notre émission `messageRead`
dans `resyncActiveConversation` (étape 2) cible `_activeConversationID`. Le
serveur gère idempotement un double `messageRead` pour la même conversation →
pas de corruption de statut côté expéditeur. Risque accepté (pas de dédoublonnage
local nécessaire). À noter comme non-régression.

### 3. Sécuriser `_onMessageReceived` (défense en profondeur)
`lib/core/services/chat_repository.dart` — `_onMessageReceived` (lignes 1441-1449)

Le code existant est déjà correct quand `_activeConversationID` est posé à temps
(`isActive` → `markConversationRead` + `setUnread(0)`). Aucun changement
fonctionnel requis, mais le réordonnancement de l'étape 1 rend ce chemin fiable.
Pas de modification ici sauf si des tests révèlent une autre fenêtre.

## Décisions de conception (réfutations des alternatives proposées)

### Alternative « await syncMessages » (rejetée)
`await`-er `syncMessages` (au lieu de `unawaited`) ne ferme PAS la race : la
race vient de `joinConversation` (socket, ligne 189), indépendant de la requête
HTTP de `syncMessages`. Pis : `syncMessages` est un appel réseau lent qui
**retarderait** `setActiveConversation` (ligne 190), élargissant la fenêtre où
`_activeConversationID == 0`. On garde `unawaited`. La fermeture réelle est le
réordonnancement (étape 1) : `setActiveConversation` AVANT `joinConversation`.

### Alternative « capturer `_activeConversationID` au début » (non applicable)
Au moment de `_attachToConversation` (appelé depuis `_init`, ligne 164),
`_activeConversationID` vaut **déjà 0** — aucune conversation n'est active
avant l'ouverture de l'écran. Il n'y a donc rien à capturer ni à restaurer.
Suggestion écartée (le message reçu était tronqué, pas de comportement concret
à implémenter).

## Fichiers touchés

- `lib/screens/chats/chat_detail_screen.dart` — réordonner `_attachToConversation`.
- `lib/core/services/chat_repository.dart` — `resyncActiveConversation`.

## Validation

- `flutter analyze` et `flutter test` passent (la suite existe : `test/chat_dao_test.dart`).
- Scénario manuel :
  1. Ouvrir une conversation avec des messages non lus → le badge disparaît,
     l'accusé ✓✓ bleu est émis côté expéditeur.
  2. Avec un second device, envoyer un message **exactement** à l'ouverture de
     la conversation sur le premier → il doit apparaître lu (pas de badge fantôme),
     et l'expéditeur doit voir ✓✓ bleu.
  3. Couper/rétablir le réseau pendant que la conversation est ouverte, puis
     envoyer depuis l'autre device → après reconnexion, le message est marqué lu.
  4. Vérifier qu'une conversation **fermée** reçoit bien un badge non lu (pas
     d'effacement intempestif).
- Non-régression (multi-appelants de `resyncActiveConversation`) :
  5. Reconnexion socket après coupure réseau longue → `_onSocketReady`
     (chat_provider.dart:134) puis `catchUp` (realtime_sync_service:24) se
     déclenchent : vérifier qu'aucun message de conversation **fermée** n'est
     marqué lu et qu'aucun badge fermé n'est zéroé.
  6. Race auth/bind : forcer un `resyncActiveConversation` alors que `_myId == 0`
     (ou avant `bind`) → la garde `_myId == 0` doit court-circuiter : AUCUN
     message ne doit être marqué lu, AUCUN `unreadCount` ne doit changer.

## Risques / ouverts

- `syncMessages` reste fire-and-forget : si l'insertion est lente, un message
  du delta pourrait être affiché après `markAsRead`. Comme `syncMessages` n'incrémente
  pas `unreadCount` et que la conv est active, aucun unread fantôme n'est créé ;
  le pire cas est un message affiché sans accusé immédiat, corrigé au prochain
  `resyncActiveConversation` / `markAsRead`. Acceptable.
- `markAsRead` (étape 1, appelé depuis `_attachToConversation` après `bind`) et
  `markConversationReadAtomic` utilisent aussi `_myId`. Ici `_myId` est garanti
  non-nul (écran ouvert post-login), mais une garde défensive `if (_myId == 0)
  return;` pourrait être ajoutée par cohérence. **Ouvert** : à décider à
  l'implémentation (recommandé : ajouter la garde, coût nul).
- Pas de migration DB (seulement réordonnancement + logique de marquage).
