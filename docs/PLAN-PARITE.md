# Roadmap Parité — Talky messager grand public

## Contexte

Décision produit : positionner Talky comme **messager grand public généraliste**
(concurrence frontale WhatsApp / Telegram), avec une stratégie **« parité d'abord »** —
combler les manques *table-stakes* qui empêchent aujourd'hui l'app d'être un choix
crédible, **avant** d'ajouter des différenciateurs (la traduction invisible inline reste
envisagée en horizon 2).

État actuel : l'app est **déjà mature** — offline-first (Drift/SQLite), réactions / reply /
forward / edit / pin, voice notes, view-once, stories complètes, appels WebRTC 1:1 +
groupe, réunions planifiées, CallKit / TURN / push VoIP. Les manques sont **ciblés**, pas
structurels. Ce document liste ces manques, les priorise, et détaille la première brique.

## Roadmap priorisée

| # | Fonctionnalité | Impact | Effort | Pourquoi |
|---|---|---|---|---|
| **1** | **Recherche dans les messages** | Très élevé | M | Aucun moyen de retrouver un ancien message aujourd'hui. Attendu par tous. Joue sur la force Drift existante. |
| **2** | **Gestion de groupe** (rôles admin, retrait membre, renommage/photo, @mentions) | Élevé | M–L | Les groupes sont un usage central d'un messager généraliste ; actuellement squelettiques. |
| **3** | **Contrôles de confidentialité** (toggle accusés de lecture, vu à / en ligne, visibilité photo) | Élevé | M | Attendu ; écran actuellement *stub*. Enjeu de confiance grand public. |
| 4 | Messages étoilés / favoris | Moyen | S | Fréquent, faible coût. |
| 5 | Messages éphémères minutés (TTL) | Moyen | M | Aujourd'hui seul le view-once existe. |
| 6 | GIF (Tenor) + stickers | Moyen | M / L | Table-stakes jeune public ; GIF simple, packs de stickers plus lourds. |

**Ordre recommandé :** 1 → 3 → 2 → 4 → 5 → 6. (La confidentialité passe avant les groupes :
effort moindre, gain de confiance immédiat, et l'écran existe déjà en stub.)

### Piste séparée (lourde) — Chiffrement E2E

Impact élevé (confiance) mais **effort XL et risqué**. Il casse la recherche côté serveur,
les broadcasts admin, et le relais offline actuels ; il impose une gestion de clés
multi-appareils, une sauvegarde de clés, et une vérification de sécurité sérieuse. À
traiter comme un **chantier stratégique dédié**, pas une brique de parité rapide. Ne pas le
mélanger à cette roadmap.

---

## #1 — Recherche dans les messages (détaillé)

### Approche : FTS5 **local** (SQLite via Drift), pas d'endpoint serveur

Les messages sont **déjà tous mis en cache localement** dans `LocalMessages`
([app_database.dart](../lib/core/db/app_database.dart#L33)). Une recherche full-text locale est
donc instantanée, hors ligne, et sans coût backend — parfaitement alignée avec l'archi
offline-first. `sqlite3_flutter_libs` embarque FTS5. Un search serveur ne serait utile que
pour retrouver des messages *jamais* synchronisés localement (rare) → à ajouter en
*fallback* plus tard, pas maintenant.

### Implémentation

**Base de données** ([app_database.dart](../lib/core/db/app_database.dart))
- Créer une table virtuelle FTS5 `message_search(content)` liée à `LocalMessages`
  (via `customStatement` dans une nouvelle migration, ou une `VirtualTable` Drift).
- Contenu indexé : messages texte (`type == 0`), captions média, `mediaName` (docs).
  Exclure `isDeleted` et les messages soft-deleted pour moi (`deletedForID`).
- **Sync de l'index** : triggers SQL `AFTER INSERT/UPDATE/DELETE` sur `LocalMessages`
  (robuste vs. maintenance manuelle). Alternative : maintenir l'index dans le DAO, qui
  centralise déjà les écritures (`upsert*`, `deleteConversation` dans
  [chat_dao.dart](../lib/core/db/chat_dao.dart#L42-L54)).
- **Migration** : bump `schemaVersion`, créer table FTS + triggers, *backfill* des messages
  déjà en cache. Régénérer le code : `dart run build_runner build`.

**DAO** ([chat_dao.dart](../lib/core/db/chat_dao.dart)) — nouvelles méthodes, en réutilisant les
patterns `selectOnly` / `where` / `customSelect` déjà présents :
- `Future<List<MessageSearchResult>> searchMessages(String query, {int? conversationId})`
  — global si `conversationId == null`, sinon dans une conversation.
- Requête : `... FROM message_search JOIN local_messages ... WHERE message_search MATCH ?
  ORDER BY rank`, avec `snippet()` de FTS5 pour l'extrait surligné.
- Modèle `MessageSearchResult { msgID, conversationID, senderNom, snippet, sendAt }`.

**UI**
- **Recherche globale** : la barre de recherche de
  [chats_screen.dart](../lib/screens/chats/chats_screen.dart) filtre aujourd'hui seulement la *liste
  de conversations*. Ajouter un mode/onglet « Messages » qui appelle `searchMessages(query)`
  et affiche les résultats groupés par conversation → nouveau
  `lib/screens/chats/message_search_screen.dart` + widget
  `lib/widgets/chat/search_result_tile.dart`.
- **Recherche in-conversation** : icône loupe dans l'AppBar de
  [chat_detail_screen.dart](../lib/screens/chats/chat_detail_screen.dart) → barre de recherche,
  navigation précédent/suivant entre occurrences, surlignage.
- **Jump-to-message** : réutiliser (ou ajouter) le *scroll-to-message* déjà nécessaire pour
  sauter vers un message épinglé / cité, en s'appuyant sur l'index du message dans la liste
  fournie par `ChatProvider.watchMessages`.

---

## #2 — Gestion de groupe (esquisse actionnable)

Aujourd'hui [group_detail_screen.dart](../lib/screens/chats/group_detail_screen.dart) n'offre que :
liste de membres à plat, « ajouter des participants », « quitter ». Manquent : rôles admin,
retrait/expulsion, renommage & photo après création, @mentions.

**Backend** ([Alanya-Backend/src/routes](../../Alanya-Backend/src/routes))
- SQL : ajouter `role` (0=member, 1=admin, 2=owner) sur la table de liaison
  conversation/participants ; le créateur = owner.
- Routes Express : `PATCH /api/conversations/:id` (rename + photo, owner/admin),
  `DELETE /api/conversations/:id/participants/:userId` (kick, admin),
  `PATCH /api/conversations/:id/participants/:userId/role` (promote/demote, owner).
- Socket.IO : events `group:updated`, `group:participant:removed`, `group:role:changed`
  pour propager en temps réel.
- @mentions : stocker les mentions d'un message (colonne JSON ou table
  `message_mentions`) et déclencher une notif ciblée via le moteur existant
  ([Alanya-Backend/src/notifications](../../Alanya-Backend/src/notifications)).

**Flutter**
- [talky_models.dart](../lib/talky_models.dart) : `role` sur le participant.
- [chat_api.dart](../lib/api/chat_api.dart) : `renameGroup`, `updateGroupPhoto`,
  `removeParticipant`, `setParticipantRole`.
- [group_detail_screen.dart](../lib/screens/chats/group_detail_screen.dart) : menu contextuel par
  membre (retirer / promouvoir) visible si je suis admin ; header éditable (renommer /
  photo) ; **réactiver les appels de groupe déjà codés mais commentés** (lignes ~260-274).
- @mentions : dans [chat_input.dart](../lib/screens/chats/chat/chat_input.dart), détecter « @ » →
  overlay de suggestions des participants → insertion ; rendu surligné dans
  [chat_bubbles.dart](../lib/screens/chats/chat/chat_bubbles.dart) ; brancher l'option de mute
  `mentionsOnly` déjà présente.

---

## #3 — Contrôles de confidentialité (esquisse actionnable)

L'écran [privacy_screen.dart](../lib/screens/profile/privacy_screen.dart) est un *stub* (ne fait que
lister les contacts bloqués). Accusés de lecture et présence sont **toujours actifs** sans
option.

**Backend**
- SQL `users` : `privacyReadReceipts`, `privacyLastSeen`, `privacyProfilePhoto`
  (0=tout le monde, 1=mes contacts, 2=personne).
- Route `PATCH /api/users/me/privacy`.
- **Enforcement serveur** (avec réciprocité, comme WhatsApp) :
  - accusés désactivés → le serveur n'émet pas *mes* accusés **et** ne me montre pas ceux
    des autres ;
  - last-seen / online → filtrer `isOnline` / `lastSeen` dans les payloads users & présence
    selon la préférence + réciprocité ;
  - photo → filtrer `avatarUrl` selon la relation.

**Flutter**
- [privacy_screen.dart](../lib/screens/profile/privacy_screen.dart) : ajouter les entrées → sous-écrans
  « Tout le monde / Mes contacts / Personne », en réutilisant le pattern de
  [settings_screen.dart](../lib/screens/profile/settings_screen.dart) et
  [notification_settings_screen.dart](../lib/screens/profile/notification_settings_screen.dart).
- [receipt_service.dart](../lib/core/services/chat/receipt_service.dart) : ne pas émettre d'accusé si
  désactivé localement.
- Présence : le header de `chat_detail_screen.dart` (`_presenceLabel`) respecte
  automatiquement la valeur déjà filtrée par le serveur.

---

## Vérification

- **Recherche** : tests DAO (`searchMessages` renvoie les bons résultats, respecte
  `isDeleted` / `deletedForID`) ; test de migration FTS (backfill correct) ; manuel — chercher
  un mot présent dans plusieurs conversations → tap → jump surligné ; **en mode avion**
  (doit fonctionner hors ligne).
- **Groupe** : créer un groupe, promouvoir / rétrograder, retirer un membre (changement
  visible en live des deux côtés), renommer, @mention → le membre reçoit une notif ciblée.
- **Confidentialité** : désactiver les accusés → l'autre ne voit plus les ✓✓ bleus **et**
  réciproquement ; last-seen masqué ; relancer l'app → persistance OK.
- **Build** : `flutter analyze`, `flutter test`, et `dart run build_runner build` après tout
  changement de schéma Drift.
