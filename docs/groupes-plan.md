# Groupes enrichis (rôles, gestion des membres, @mentions) — Plan d'implémentation

> Statut : **implémenté** — 21 commits (8 backend, 13 Talky).
>
> **Seconde passe** (audit + retours d'usage) : la migration 024 était
> inapplicable — le filet placé en tête l'interrompait dès sa première
> instruction sur toute base où la 022 était passée ; l'invariant du
> propriétaire était cassé par trois sorties de groupe préexistantes ; les
> mentions reçues n'étaient jamais hydratées côté client, ce qui tuait en
> silence le bouton « @ », le saut, la bulle teintée et le surlignage ; la
> garde de réordonnancement rejetait les trames de même horodatage. Ajouts :
> ouverture au premier message non lu avec séparateur (toutes discussions),
> description à la création, photo de groupe éditable.
> Périmètre : Talky (Flutter) + Alanya-Backend (Node/Express/MySQL)
> Dernière mise à jour : 2026-07-26
>
> Réalise l'item **#2 de [PLAN-PARITE.md](PLAN-PARITE.md)** (« Gestion de groupe »).
> Migration SQL **024**, schéma Drift **14 → 15**. Le plan « listes de contacts »
> a été renuméroté en conséquence (025 / Drift v16).

---

## 1. Contexte & objectif

Les groupes sont aujourd'hui **squelettiques**. La base ne connaît que
`conversation(isGroup, GroupName, groupPhoto)` et une table de liaison
`conv_participants` **sans aucune métadonnée de rôle** :

| Couche | Existant |
|---|---|
| MySQL | `conversation.isGroup / GroupName / groupPhoto` ; `conv_participants(conversID, alanyaID, unreadCount, isPinned, isArchived, joinedAt, mutedUntil, muteForever, mentionsOnly)` |
| API | `POST /conversations/group`, `POST /:id/participants`, `POST /:id/leave` |
| Flutter | `create_group_screen.dart`, `group_detail_screen.dart` (liste plate + ajouter + quitter) |

Manquent : rôles admin, retrait d'un membre, édition du nom/photo après création,
description, @mentions, et toute trace des changements d'appartenance dans le fil.

Trois **failles d'autorisation** ont par ailleurs été trouvées dans la zone touchée
et sont corrigées ici (§2.4).

### Décisions produit validées

| Sujet | Décision |
|---|---|
| Rôles | `conv_participants.role` : 0=membre, 1=admin, 2=propriétaire. Un seul propriétaire. |
| Promotion / rétrogradation | **Propriétaire uniquement**. Un admin ne crée pas d'admin. |
| Retrait (kick) | Admin ou propriétaire ; jamais un rôle ≥ au sien ; le propriétaire est inexpulsable. |
| Édition des infos | Tous les membres par défaut ; réservée aux admins si `onlyAdminsCanEditInfo = 1`. |
| Mode annonce | `onlyAdminsCanSend = 1` ⇒ seuls `role >= 1` peuvent envoyer. **Serveur d'abord**, UI ensuite. |
| Messages système | `message.type = 6`, **payload JSON machine-lisible**, jamais une phrase pré-rendue. |
| Mentions | Colonne `message.mentions JSON`, **pas de nouvelle table**. Le client envoie des ids, le serveur les intersecte avec les participants réels. |
| `@Tous` | **Ouvert à tous les membres**, aucune règle de rôle. Déplié côté serveur. Perce « uniquement les mentions ». |
| Bulle où je suis mentionné | **Fond teinté seul, sans liseré.** |
| Aperçu de liste | Un `@` indigo **précède le texte réel** du message. |
| Messages système & non-lus | `lastMessage` mis à jour, **`unreadCount` jamais incrémenté**, **aucune push**. |
| Hors scope v1 | Transfert explicite de propriété (hors succession automatique), appels de groupe. |

**Maquettes validées** : <https://claude.ai/code/artifact/f315a0c3-1952-4ee0-9f28-478fbcf6e1ff>
— cinq surfaces (saisie, fil, bouton de saut, liste, notification) × clair/sombre,
avec les tokens réels de `lib/core/theme/app_colors.dart`.

---

## 2. Backend — Alanya-Backend

Contexte : MySQL 8 + `mysql2/promise`, **SQL brut inline dans les contrôleurs**,
aucun ORM, aucun `src/models`.

### 2.1 Migration SQL — `migrations/024_groups_roles_mentions.sql` *(nouveau)*

`ALTER TABLE` idempotents à la main (convention des migrations 022/023 :
réexécution = ignorer les « Duplicate column »).

```sql
ALTER TABLE conv_participants
  ADD COLUMN role TINYINT NOT NULL DEFAULT 0
      COMMENT '0=membre 1=admin 2=proprietaire';

ALTER TABLE conversation
  ADD COLUMN description           VARCHAR(512) NULL,
  ADD COLUMN createdBy             INT          NULL,
  ADD COLUMN createdAt             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN updatedAt             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                ON UPDATE CURRENT_TIMESTAMP,
  ADD COLUMN onlyAdminsCanSend     TINYINT      NOT NULL DEFAULT 0,
  ADD COLUMN onlyAdminsCanEditInfo TINYINT      NOT NULL DEFAULT 0;

ALTER TABLE conversation
  ADD CONSTRAINT fk_conv_created_by FOREIGN KEY (createdBy)
    REFERENCES users(alanyaID) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE message
  ADD COLUMN mentions JSON NULL
      COMMENT 'ids des membres mentionnes dans ce message';

ALTER TABLE message MODIFY COLUMN type SMALLINT NULL DEFAULT 0
  COMMENT '0=text 1=image 2=video 3=audio 4=file 5=location 6=system 7=contact';
```

#### Backfill — obligatoire

Sans lui, **tous les groupes existants sont sans propriétaire**, donc définitivement
ingérables.

1. `conversation.createdAt` ← `MIN(cp.joinedAt)` par conversation (heuristique déjà
   employée par `src/controllers/admin/groups.js:21`).
2. `conversation.createdBy` ← `alanyaID` de la ligne `conv_participants` de
   **`MIN(id)`**, et non `MIN(joinedAt)` : `createGroup` insère toujours le créateur
   en premier, alors que `joinedAt` est à la seconde près et produit des ex æquo.
3. `conv_participants.role = 2` pour ce `createdBy`, sur les `isGroup = 1`.
4. Requête de contrôle : aucun `isGroup = 1` sans participant `role = 2`.

Si le créateur a déjà quitté, `MIN(id)` désigne le plus ancien membre restant —
propriétaire par défaut raisonnable, et le groupe redevient administrable.

### 2.2 Mentions : colonne JSON, pas de table

`message.mentions JSON NULL`, format `[45, 46]`.

Le précédent existe déjà dans ce schéma : **`message.reactions JSON NULL`**
(`migrations/019_message_reactions.sql`), avec les helpers `_parseReactionsColumn` /
`_serializeReactionsColumn` (`messageController.js:371-398`) à recopier tels quels.
Et `MSG_SELECT` fait `SELECT m.*` (`socket/handlers/chat/messageSend.js:10-16`) :
la colonne arrive **gratuitement** dans tous les payloads (`message:received`,
`getMessages`, `POST /messages/sync`), sans toucher une seule projection — une table
aurait exigé une jointure supplémentaire dans chacune. Enfin, la suppression d'un
message emporte ses mentions puisque c'est la même ligne.

Seul renoncement : une « inbox de mentions » globale exigerait un `JSON_CONTAINS`
non indexé. Hors périmètre v1, et MySQL 8 sait indexer un tableau JSON
(`CAST(mentions AS UNSIGNED ARRAY)`) si le besoin apparaît.

### 2.3 Middleware — `src/middleware/groupAuth.js` *(nouveau)*

Il n'existe aucun middleware d'autorisation participant : chaque contrôleur refait
un `SELECT 1 FROM conv_participants`. On l'introduit, mais **uniquement sur les
routes nouvelles ou corrigées** — pas de refactor des contrôleurs existants, pour ne
pas mélanger correction de faille et churn.

Une seule requête (`JOIN conversation`), exposée dans `req.membership`
(`{ conversID, isGroup, role, createdBy, onlyAdminsCanSend, onlyAdminsCanEditInfo }`)
et réutilisée par le handler.

| Export | Comportement |
|---|---|
| `requireParticipant` | 404 si non membre — jamais 403, pour ne pas révéler l'existence |
| `requireGroup` | 400 si `isGroup = 0` |
| `requireGroupAdmin` | + `role >= 1`, sinon 403 `GROUP_ADMIN_REQUIRED` |
| `requireGroupOwner` | + `role === 2`, sinon 403 `GROUP_OWNER_REQUIRED` |

### 2.4 Failles corrigées

| Faille | Fichier | Correction |
|---|---|---|
| `updateConversation` **sans contrôle d'appartenance** : tout compte authentifié peut renommer / rephotographier n'importe quel groupe | `conversationController.js:267-300` | `PUT /:id` ne gère plus que `isPinned`/`isArchived` (per-user), sous `requireParticipant`. `GroupName`/`groupPhoto` → 400 pointant vers `PATCH /:id/group`. Aucun client n'envoie ces champs (`lib/api/chat_api.dart:116-131`) ⇒ zéro régression. |
| `join_conversation` : ni authentification ni appartenance | `socket/handlers/chat/messageSend.js:85-95` | `if (!socket.authenticated) return;` + vérif d'appartenance avant `socket.join`. Sinon n'importe quelle socket écoute `message:updated` / typing d'un groupe. |
| `message:send` : **aucune vérification d'appartenance** (seul `evaluateDirectMessageSend` tourne, et il ne couvre que le 1-1) | `messageSend.js:98` + `messageController.js` | Nouveau `src/utils/groupSendPolicy.js` → `assertCanSendToConversation()`, appelé **avant l'INSERT** dans les deux chemins. Renvoie `{ok}` ou `{code:'NOT_A_MEMBER'\|'GROUP_ADMINS_ONLY'}`. |

### 2.5 Contrôleur & routes — `conversationController.js` / `routes/conversations.js`

| Méthode + chemin | Corps | Autorisation | Effets |
|---|---|---|---|
| `PATCH /:id/group` *(nouveau)* | `{ GroupName?, groupPhoto?, description? }` (≥1 clé ; nom 1-255, description ≤512) | `requireParticipant` + `requireGroup` + (`role>=1` ou `onlyAdminsCanEditInfo=0`) sinon 403 `GROUP_INFO_LOCKED` | 1 message système **par champ réellement modifié** ; `conversation:updated` |
| `PATCH /:id/settings` *(nouveau)* | `{ onlyAdminsCanSend?, onlyAdminsCanEditInfo? }` | `requireGroupAdmin` | `settings_changed` par verrou basculé ; `conversation:updated` |
| `DELETE /:id/participants/:userId` *(nouveau)* | — | `requireGroupAdmin` + `target.role < my.role` + cible ≠ moi (400 → `/leave`) ; propriétaire inexpulsable (403 `CANNOT_REMOVE_OWNER`) | `member_removed` ; `group:participant:removed` ; `conversation:updated` |
| `PATCH /:id/participants/:userId/role` *(nouveau)* | `{ role: 0\|1 }` | `requireGroupOwner`, cible ≠ moi | `role_changed` si la valeur change ; `conversation:updated` |
| `POST /:id/participants` *(existant)* | inchangé | + si `onlyAdminsCanEditInfo=1` alors `role>=1` | `member_added` si `toAdd.length>0` ; `conversation:created` **aux nouveaux seulement**, `conversation:updated` aux anciens |
| `POST /:id/leave` *(existant)* | — | `requireParticipant` | succession si propriétaire (§6) ; `member_left` ; `group:participant:removed` ; `conversation:updated` |
| `POST /group` *(existant)* | `+ description?` | inchangée | `createdBy = moi`, `role=2` pour moi / `0` pour les autres ; `group_created` |
| `PUT /:id` *(existant)* | `{ isPinned?, isArchived? }` **uniquement** | `requireParticipant` | — |

**Pourquoi `PATCH /:id/group` et non `PATCH /:id`** (l'esquisse de PLAN-PARITE
proposait ce dernier) : `PUT /:id` porte déjà une sémantique **par utilisateur**
(pin/archive, autorisation « je suis membre »). Coller sur le même chemin une
sémantique **groupe** avec une autorisation « je suis admin » est exactement le
mélange qui a produit la faille corrigée en §2.4.

**Le `role` doit circuler dans toutes les projections** — ajouter `cp.role, cp.joinedAt` à :

- `attachParticipants` (`conversationController.js:18-56`) — sert `GET /:id` et les
  réponses de mutation ;
- `attachParticipantsBatch` (`src/utils/conversationParticipantsBatch.js:24-31`) —
  **c'est ce chemin qui sert `GET /conversations`** ; l'oublier ferait apparaître le
  rôle en fiche groupe mais pas en liste ;
- `getConversations` / `getConversationById` : `c.*` couvre les colonnes neuves ;
  ajouter `cp.role AS myRole, cp.mutedUntil, cp.muteForever, cp.mentionsOnly` ;
- `src/controllers/admin/groups.js` : lire les vrais `createdBy`/`createdAt` au lieu
  de `MIN(cp.joinedAt)` et `members[0]`, et exposer `cp.role`.

### 2.6 Messages système — `src/utils/systemMessage.js` *(nouveau)*

`postSystemMessage({ conversationID, actorID, event, payload, io, notifyExtra })` :

1. `content = JSON.stringify({ e, by, byName, ...payload })`
2. `INSERT INTO message (senderID = actorID, type = 6, status = 1, clientID = NULL, …)`
   — `clientID` NULL est déjà admis, et l'index unique MySQL tolère plusieurs NULL.
3. `UPDATE conversation SET lastMessage/lastMessageAt/lastMessageType=6/…`
   — **aucun `UPDATE conv_participants SET unreadCount`**.
4. Relecture via `MSG_SELECT`, puis `io.to('user_<id>').emit('message:received', …)`
   pour chaque participant **plus `notifyExtra`** (l'exclu, qui n'est plus en table).
5. **Aucun appel à `notifyNewMessage`** : pas d'unread ⇒ pas de push. Un client hors
   ligne les récupère par le delta `POST /messages/sync`.

`senderID = acteur` : la jointure `JOIN users u ON m.senderID` de `getMessages` et de
`MSG_SELECT` reste valide, aucune colonne nullable à ajouter.

**Encodage** (précédent `type 5` / `type 7` : JSON dans `content`) :

```json
{"e":"member_added","by":12,"byName":"Chris","ids":[45],"names":["Marc"]}
```

| `e` | Champs | Rendu attendu |
|---|---|---|
| `group_created` | `value` | X a créé le groupe « … » |
| `member_added` | `ids[]`, `names[]` | X a ajouté Y |
| `member_removed` | `ids[]`, `names[]` | X a retiré Y |
| `member_left` | — | X a quitté le groupe |
| `group_renamed` | `value` | X a renommé le groupe en « … » |
| `group_photo_changed` | — | X a changé la photo |
| `group_description_changed` | `value` | X a modifié la description |
| `role_changed` | `ids[]`, `names[]`, `role` | X a nommé Y administrateur |
| `settings_changed` | `lock`, `on` | X a réservé l'envoi aux administrateurs |

`byName` / `names[]` sont **dénormalisés à l'écriture** : sans cela, le nom d'un
membre exclu n'est plus résoluble (il ne figure plus dans `participants`) et le fil
afficherait « a retiré (inconnu) ». Même raisonnement que `message.replyToContent`.

`src/utils/messagePreview.js` : ajouter `systemPreviewFromContent()` et un
court-circuit `if (t === 6)` **avant** le traitement générique (comme `t === 5`
ligne 133 et `t === 7` ligne 139) — ne jamais exposer le JSON brut. Le libellé produit
est en français ; il ne sert que d'amorce pour `conversation.lastMessage`, le client
re-dérive un aperçu localisé. Même compromis que `ConversationMerge.deletedPreview`.

### 2.7 Mentions — `src/utils/mentions.js` *(nouveau)*

Calqué sur les helpers `reactions` de `messageController.js:371-398` :

- `sanitizeMentions(conversationID, senderID, rawIds, { all })` — si `all`, **déplie**
  en « tous les participants sauf l'expéditeur » ; sinon `INT`ifie, déduplique, retire
  l'expéditeur, **intersecte avec `conv_participants`**, plafonne à 32.
  L'intersection serveur rend la mention **non falsifiable** : c'est ce qui permet de
  faire confiance au client pour l'extraction des ids (le serveur ne peut pas
  re-parser « @Jean Dupont » de façon fiable, les noms contiennent des espaces).
- `serializeMentionsColumn(ids)` / `parseMentionsColumn(raw)`.

**Écriture dans l'`INSERT` lui-même**, pas en `UPDATE` séparé : les deux chemins
d'envoi `sanitize` **avant** l'INSERT et passent la valeur en paramètre.
L'idempotence est alors gratuite — un replay d'un `clientID` déjà connu ne réécrit
rien, il n'y a pas de seconde écriture à conditionner.

**`@Tous`** — le client envoie `mentionsAll: true`. Le dépliage est **serveur** et le
résultat va dans la même colonne : rien en aval ne connaît `@Tous`, donc le ciblage
push, `mentionsOnly` et le compteur de saut fonctionnent tels quels. Au-delà de
**256 membres**, on stocke le marqueur seul et le fan-out lit `conv_participants`.

### 2.8 Ciblage des notifications

`notifyNewMessage` (`src/services/notificationService.js:413-488`) : `mentionedIds`
vient de `fields.mentions` (déjà présent dans la ligne message chargée par les
appelants — **aucune requête**), parsé **une fois hors de la boucle** en `Set` ;
ajouter `mentioned: '0'|'1'` au payload (`notificationContract.js:63-97`) et passer
`isMentioned` à `evaluateMessagePush`.

`evaluateMessagePush` (`src/notifications/notificationFilter.js:11-52`) — nouvelle
précédence, après les garde-fous `messagesEnabled` / `groupMessagesEnabled` :

```js
const mute = await loadConversationMute(conversationId, alanyaID);
const muted = isConversationMuted(mute);
const mentionsOnly = !!mute.mentionsOnly;

// En sourdine : la mention perce, sauf si « mentions uniquement » est désactivé.
if (muted && !(mentionsOnly && isMentioned))            return silence('conversation_muted');
// Pas en sourdine mais « mentions uniquement » : on filtre le bruit.
if (!muted && mentionsOnly && isGroup && !isMentioned)  return silence('mentions_only');
```

> ⚠️ **Contrainte non négociable** : `silence()` reste `silence()` — push data-only,
> titre/corps retirés, `silent:'1'`. **Jamais un `continue`.** Sans ce réveil, un
> terminal fermé ne peut pas émettre son accusé de remise et l'expéditeur reste
> bloqué sur une seule coche (cf. le commentaire `notificationFilter.js:13-19`).

`isConversationMuted` reste inchangé : c'est le filtre qui compose mute +
`mentionsOnly`, pas la fonction de mute.

### 2.9 Événements socket

| Événement | Room | Charge |
|---|---|---|
| `conversation:created` | `user_<id>` | **Réservé au cas « je n'avais pas cette conversation »** : 1-1, création de groupe, nouveau membre ajouté. Cesse d'être un upsert générique. |
| `conversation:updated` *(nouveau)* | `user_<id>` de chaque membre courant | conversation enrichie **sans les champs par-utilisateur** (`unreadCount`, `isPinned`, `isArchived`, `lastMessage*`) + `updatedAt` |
| `group:participant:removed` *(nouveau)* | `user_<id>` de chaque membre du **snapshot pris AVANT le DELETE**, l'exclu inclus | `{ conversID, alanyaID, removedBy, reason: 'kicked'\|'left', updatedAt }` |

`group:role:changed` (proposé par PLAN-PARITE) est **volontairement abandonné** : le
rôle voyage déjà dans `participants[]` de `conversation:updated`, un second porteur de
la même vérité crée un risque d'incohérence sans rien apporter.
`group:participant:removed` est en revanche **indispensable** : l'exclu n'est plus
dans la liste de diffusion de `conversation:updated` et n'apprendrait jamais son
exclusion.

Room `user_<id>` et non `conversation_<id>` : cette dernière n'est rejointe qu'à
l'ouverture de l'écran de discussion, un membre posé sur la liste des chats
manquerait tout. `user_<id>` est rejointe à l'authentification
(`socket/handlers/auth.js:66`), multi-appareils, robuste aux reconnexions.

---

## 3. Frontend — couche données

### 3.1 Modèles — `lib/talky_models.dart`

Nouvelle classe **`Participant { User user; int role; String? joinedAt; }`** avec
`isAdmin` / `isOwner`. `Conversation.participants` passe de `List<User>` à
`List<Participant>`.

*Pourquoi pas `role` sur `User`* : `User` est partagé par les contacts, l'admin, les
appels et les meetings ; un `role` de groupe y vaudrait 0 partout ailleurs et se
confondrait avec `typeCompte` / `AdminProvider.isAdmin` (`admin_provider.dart:245`).
Rayon d'impact du changement de type : **6 lignes, toutes dans
`group_detail_screen.dart`** (106, 176, 292, 301, 688, 726).

Nouveaux champs sur `Conversation` : `description`, `createdBy`, `createdAt`,
`updatedAt`, `onlyAdminsCanSend`, `onlyAdminsCanEditInfo`, `myRole`, `mutedUntil`,
`muteForever`, `mentionsOnly`. `Message.displayContent` gagne une branche `type == 6`.
`class SocketEvents` gagne `conversationUpdated` et `groupParticipantRemoved`.

### 3.2 Cache Drift — `lib/core/db/app_database.dart` (schemaVersion **14 → 15**)

**Le `role` n'a besoin d'aucune colonne** : `participantsJson` stocke les objets
participants serveur bruts ; dès que `attachParticipants` renvoie `role`, il est en
cache. `decodeParticipants` (`chat_dao.dart:896`) rend des `Map`, les appelants lisent
`p['role']`.

Colonnes réellement nécessaires (états consultables **hors ligne**) :

```dart
// LocalConversations
TextColumn     get description           => text().nullable()();
IntColumn      get createdBy             => integer().nullable()();
DateTimeColumn get metaUpdatedAt         => dateTime().nullable()();
BoolColumn     get onlyAdminsCanSend     => boolean().withDefault(const Constant(false))();
BoolColumn     get onlyAdminsCanEditInfo => boolean().withDefault(const Constant(false))();
IntColumn      get myRole                => integer().withDefault(const Constant(0))();
DateTimeColumn get mutedUntil            => dateTime().nullable()();
BoolColumn     get muteForever           => boolean().withDefault(const Constant(false))();
BoolColumn     get mentionsOnly          => boolean().withDefault(const Constant(false))();

// LocalMessages
TextColumn     get mentionsJson          => text().nullable()();
```

`mentionsJson` est **obligatoire** : `flushOutbox` reconstruit l'emit depuis la ligne
Drift (`message_sender.dart:564, 604`) ; sans persistance, une mention envoyée hors
ligne perdrait sa notification au rejeu. Elle mappe 1:1 la colonne serveur.

Puis `if (from < 15) { … addColumn … }` et
`dart run build_runner build --delete-conflicting-outputs`.

> ⚠️ **Régression à corriger dans le même commit** : `ChatDao.countUnread`
> (`chat_dao.dart:64`) compte **tout** message entrant `status < 3`. Un message
> système émis par un tiers gonflerait le badge. Ajouter
> `& db.localMessages.type.equals(6).not()`.

### 3.3 Client API — `lib/api/chat_api.dart`

Nouvelles méthodes : `updateGroupInfo`, `updateGroupSettings`, `removeParticipant`,
`setParticipantRole`. `sendMessage` gagne `List<int>? mentions` et `bool mentionsAll`.
`updateConversation` est documentée comme per-user uniquement.

L'interface abstraite `lib/core/services/chat/chat_api.dart` n'a **aucune** méthode
groupe aujourd'hui — ajouter `getConversation`, `updateGroupInfo`,
`updateGroupSettings`, `addParticipants`, `removeParticipant`, `setParticipantRole`,
`leaveGroup`, `updateConversationMute`. Répercuter dans `talky_chat_api.dart`
(passe-plats) et `test/fakes/fake_chat_api.dart`.

### 3.4 Repository — `lib/core/services/chat/chat_repository.dart`

**Les opérations groupe passent désormais par le repository**, plus par
`Provider.of<TalkyApiClient>` depuis les écrans (comme aujourd'hui
`group_detail_screen.dart:170, 236`). Trois raisons : chaque mutation renvoie la
conversation enrichie qui doit atterrir en Drift (seule source lue par la liste, la
fiche groupe **et** le verrou du composeur) ; les handlers socket vivent déjà dans le
repository, donc deux chemins d'écriture concurrents sur la même ligne seraient une
course garantie ; et c'est la seule façon de tester avec `ChatTestHarness`.

Nouvelles méthodes (chacune : HTTP → `upsertConversation` → `_recomputeSummary`) :
`refreshConversation`, `updateGroupInfo`, `updateGroupSettings`, `addParticipants`,
`removeParticipant`, `setParticipantRole`, `leaveGroup`, `setMentionsOnly`.

Nouveaux handlers, enregistrés dans `bind` **et retirés dans `unbind`** :

- `_onConversationUpdated` — companion **partiel** (`Value.absent()` sur
  `unreadCount`/`isPinned`/`isArchived`/`lastMessage*`, contrairement à
  `_onConversationCreated` qui écrit tout : une trame tardive remettrait un badge
  fantôme) ; ignore la trame si `updatedAt <= local.metaUpdatedAt`.
- `_onGroupParticipantRemoved` — si `alanyaID == _myId` →
  `_dao.deleteConversation(conversID)` ; sinon no-op (le `conversation:updated` qui
  l'accompagne porte déjà la nouvelle liste).

`ConversationMerge.previewForMedia` gagne une branche `type == 6` et un paramètre
`int myId = 0` — le reducer l'a déjà en portée, c'est ce qui permet d'écrire
« Vous avez ajouté Marc » dans la liste.

### 3.5 Utilitaires purs *(nouveaux — les seams testables)*

- `lib/core/utils/system_event_payload.dart` — `SystemEventPayload.tryParse(content)`
  calqué sur `LocationPayload` : `null` si JSON invalide **ou événement inconnu**
  (compatibilité ascendante), `String label(int myId, AppLocalizations l10n)`.
- `lib/core/utils/mention_parser.dart` — `extractMentionQuery(text, caret)`,
  `resolveMentions(text, members)` (correspondance la plus longue d'abord, insensible
  casse/accents).
- `lib/core/utils/group_permissions.dart` — `canEditInfo`, `canRemove`,
  `canChangeRole`, `canSend`. **L'UI n'appelle que ça** : le gating devient testable
  sans widget, et le serveur reste l'autorité.

---

## 4. Frontend — UI

### 4.1 `lib/screens/chats/group_detail_screen.dart`

`_loadGroup` (:56) **supprimé** au profit d'un `StreamBuilder` sur
`repo.watchConversation(id)` + `unawaited(repo.refreshConversation(id))` au
`initState`. Cela règle d'un coup l'absence actuelle d'appel HTTP `getConversation`,
la fraîcheur après chaque mutation, et le cas « je viens d'être exclu » (le stream
émet `null` → `pop`).

- **`_Header`** : lit la conversation streamée (`widget.groupName` ne sert plus que de
  placeholder première frame — sinon le titre resterait figé après renommage). Photo
  tappable → picker → `uploadImage` → `updateGroupInfo` ; crayon → renommage ; bloc
  description éditable. Masqués si `!canEditInfo`.
- **`_MembersCard`** (:683) : tri propriétaire → admins → membres, puce de rôle,
  `PopupMenuButton` par membre gaté par `group_permissions.dart` (retirer / nommer
  admin / retirer les droits / voir le profil), confirmation avant retrait.
- **`_SettingsCard`** *(nouveau, `myRole >= 1`)* : deux `SwitchListTile` →
  `updateGroupSettings`.
- À côté de `ConversationMuteListTile` : `SwitchListTile` « Uniquement les mentions »
  (groupes seulement) → `repo.setMentionsOnly`. C'est ce qui rend enfin utile le
  paramètre `mentionsOnly` de `lib/api/chat_api.dart:140`, qu'aucun appelant ne passe.
- **`_DangerCard`** : pour le propriétaire, le dialogue explique la succession.

### 4.2 `lib/screens/chats/create_group_screen.dart`

Champ description optionnel. `_create()` passe par le repository, **conserve la
conversation créée** (aujourd'hui jetée, ligne 85) et fait un `pushReplacement` vers
`ChatDetailScreen` au lieu de `popUntil(isFirst)`.

### 4.3 Mode annonce — `chat_detail_screen.dart` / `chat/chat_input.dart`

`_inputBlocked` (`chat_detail_screen.dart:538`) vaut `!widget.isGroup && _isBlocked` et
masque tout le composeur. **Ne pas surcharger ce booléen** avec une seconde
sémantique : introduire `enum ComposerLock { none, blocked, adminsOnly }`.
`_buildBlockedBanner` gagne la variante « Seuls les administrateurs peuvent envoyer
des messages » ; `_sendMessage` (`chat_actions.dart:219`) teste le verrou.

Le verrou UI n'est qu'une politesse — le serveur rejette avec `GROUP_ADMINS_ONLY`.
`SocketMessageHandlers.onMessageSendFailed` (`socket_message_handlers.dart:257-267`)
marque aujourd'hui *tout* échec en `failed`, offrant un « réessayer » qui échouera
indéfiniment : ajouter une liste de codes **terminaux** (`GROUP_ADMINS_ONLY`,
`NOT_A_MEMBER`, `BLOCKED_BY_SENDER`) → failed **sans** retry.

### 4.4 Messages système & mentions — `chat/chat_bubbles.dart`

`_buildMessageBubble` (:128) : **première ligne**
`if (msg.type == 6) return _buildSystemMessage(msg);`.

`_buildSystemMessage` est calqué sur `_buildDateSeparator` (:325) — `Container`
centré, `surfaceMuted`, `labelSmall`, `maxWidth ~80%`. Pas d'avatar, pas de ligne
d'expéditeur, **pas d'alignement `isMe`** (le `senderID` est celui de l'acteur : sans
le court-circuit, mes propres actions s'aligneraient à droite dans une bulle bleue),
pas de réactions, pas de long-press, pas de swipe. `_isSelectableMessage`
(`chat_actions.dart:10`) et `_previewOf` (:258) excluent le type 6.

**Bulle où je suis mentionné** : fond teinté (`primaryContainer` clair / `#232842`
sombre), **sans liseré**. Condition : `msg.mentions` me contient. Ne s'applique qu'aux
bulles **entrantes** (une bulle sortante est déjà indigo).

**Surlignage** : `parseRichSpans` (`rich_text_parser.dart:143`) gagne un paramètre
`Set<String> mentionNames`, propagé dans `_appendWithLinks` (:90) qui découpe chaque
segment en URL / mention / texte.

*Pourquoi surligner par correspondance de nom et non par offsets stockés* : le contenu
reste « une simple String stockée telle quelle » (philosophie affirmée
`rich_text_parser.dart:3-6`), aucun format de fil à faire évoluer, dégradation
gracieuse sur les messages anciens. La **liste faisant autorité** (notifications,
`mentionsOnly`, compteur) reste la colonne serveur, jamais ce scan.

Dans une bulle **sortante** (fond indigo), l'indigo de la mention serait invisible :
variante `onPrimary` gras + souligné.

`@Tous` est **rendu tel quel**, sans dépliage — un message affichant 40 noms serait
illisible.

**Tap sur une mention** — le `TextSpan` porte un `TapGestureRecognizer` :

| Mention | Destination |
|---|---|
| Un autre membre | `ContactDetailScreen(userId:, conversationId:, initialName:, initialAvatar:)` — les champs `initial*` évitent l'écran vide pendant le chargement |
| **Moi-même** | `ProfileScreen`, **pas** `ContactDetailScreen` : cet écran propose bloquer / signaler, absurdes sur soi, et charge un `blockStatus` avec soi-même comme pair |
| **`@Tous`** | `GroupDetailScreen` — la liste des membres, seule réponse utile à « qui est concerné » |

Le `TapGestureRecognizer` doit être **libéré dans `dispose`**, sinon chaque
reconstruction de bulle en fuit un dans une liste qui défile. Les mentions d'un membre
**parti** restent surlignées mais ne sont plus tappables.

### 4.5 Overlay de saisie — `chat/chat_input.dart`

`_onTextChanged` (branché ligne 384) appelle `extractMentionQuery` ; si
`widget.isGroup` et match, filtrer les participants et rendre l'overlay **dans la
`Column` existante** de `chat_detail_screen.dart:728-730`, à côté de
`_buildReplyBanner` / `_buildFormatBar` — un vrai `OverlayEntry` se battrait avec le
clavier.

Sélection → remplace la plage `@requête` par `@${nom} `. À l'envoi, on ne conserve que
les ids dont `@nom` figure encore dans le texte final.

**`@Tous` est épinglé en tête**, séparé par un filet, visible tant que la requête est
un préfixe de « tous » ; il pose `mentionsAll = true` au lieu d'un id.

### 4.6 Bouton de saut aux mentions — `chat/chat_actions.dart`

Second bouton flottant **au-dessus** du `_buildScrollToBottomButton` existant
(ligne 1261) : même gabarit 40 px / `Material elevation 3` / `CircleBorder`, glyphe
`@` en `colors.primary`, pastille de compteur en `colors.error`. Visible seulement si
le compteur > 0 ; le bouton « aller en bas » reste indépendant.

- **Décompte** — dérivé en local par le DAO : messages dont `mentionsJson` me contient,
  `status < 3`, non supprimés. Aucun champ serveur, aucune requête réseau. Même
  famille que `countUnread`, dans le même fichier.
- **Saut** — de la **plus ancienne vers la plus récente** (sens de lecture), en
  réutilisant `_ensureMessageLoaded` + le corps de `_scrollToReply` (ligne 1288), qui
  gèrent déjà le chargement d'un message hors page.
- **Décrément** — le compteur suit `countUnread` : il tombe quand les messages passent
  en lu, pas au moment du saut. Pas de compteur « visité » à maintenir.

### 4.7 Aperçu marqué — `conversation_summary_reducer.dart`

Un `@` en `colors.primary` précède l'aperçu quand une mention non lue m'attend,
**suivi du texte réel du message**. Dérivé à côté du calcul de non-lus existant.

Cas qui porte la fonctionnalité : **groupe en sourdine** → pastille grise
(`onSurfaceVariant`) mais `@` indigo, ce qui rend « uniquement les mentions » visible
sans ouvrir la conversation.

### 4.8 Localisation — `lib/l10n/app_fr.arb` (template) + `app_en.arb`

**Messages système : deux clés par événement** (`…` et `…ByMe`). En anglais la
substitution `{actor}` → « You » suffirait, mais **en français elle casse la
conjugaison** (« Vous a ajouté »), et le français est le template.

UI : `groupOwner`, `groupAdmin`, `removeFromGroup`, `makeAdmin`, `dismissAdmin`,
`groupDescription`, `renameGroup`, `groupSettings`, `onlyAdminsCanSend`(+`Subtitle`),
`onlyAdminsCanEditInfo`(+`Subtitle`), `mentionsOnlyLabel`(+`Subtitle`),
`youWereRemovedFromGroup`, `ownershipTransferredTo`.

Mentions : `mentionAll` (**`@Tous`** / `@All` — le libellé lui-même),
`mentionAllSubtitle`, `mentionYou`, `jumpToMention`.

> ⚠️ **Piège de localisation** : `mentionAll` sert de *marqueur textuel* dans le
> contenu du message. Un message écrit en français (`@Tous`) lu par un client anglais
> doit surligner `@Tous`, pas `@All`. Le surlignage teste donc **les deux libellés** —
> la vérité reste de toute façon la colonne `mentions`.

---

## 5. Récapitulatif des fichiers

**Backend — nouveaux** : `migrations/024_groups_roles_mentions.sql`,
`src/middleware/groupAuth.js`, `src/utils/systemMessage.js`, `src/utils/mentions.js`,
`src/utils/groupSendPolicy.js`.

**Backend — modifiés** : `src/controllers/conversationController.js`,
`src/utils/conversationParticipantsBatch.js`, `src/routes/conversations.js`,
`src/socket/handlers/chat/messageSend.js`, `src/controllers/messageController.js`,
`src/utils/messagePreview.js`, `src/services/notificationService.js`,
`src/notifications/notificationFilter.js`, `src/notifications/notificationContract.js`,
`src/controllers/admin/groups.js`.

**Frontend — nouveaux** : `lib/core/utils/system_event_payload.dart`,
`lib/core/utils/mention_parser.dart`, `lib/core/utils/group_permissions.dart`.

**Frontend — modifiés** : `lib/talky_models.dart`, `lib/api/chat_api.dart`,
`lib/core/services/chat/{chat_api,talky_chat_api,chat_repository,conversation_merge,conversation_summary_reducer,message_sender,socket_message_handlers}.dart`,
`lib/core/db/{app_database,chat_dao}.dart` (+ `app_database.g.dart` régénéré),
`lib/core/utils/rich_text_parser.dart`,
`lib/screens/chats/{group_detail_screen,create_group_screen,chat_detail_screen}.dart`,
`lib/screens/chats/chat/{chat_input,chat_actions,chat_bubbles}.dart`,
`lib/l10n/app_{fr,en}.arb`.

---

## 6. Cas limites (règle `.cursor/rules/modifications-cas-limites.mdc`)

1. **Hors ligne** — toutes les mutations groupe sont **online-only, sans outbox** :
   erreur réseau → snackbar, **aucune écriture locale optimiste**. Un kick appliqué
   localement puis refusé par le serveur (j'ai perdu mon rôle entre-temps) est pire
   qu'un spinner. Les **lectures** restent offline-first depuis Drift, rôles compris.
2. **Socket non prêt** — la réponse HTTP suffit à l'appareil qui agit ; les autres
   rattrapent au prochain `syncConversations` (retour premier plan).
3. **Arrière-plan / kill** — aucune push pour les messages système ; le delta
   `POST /messages/sync` les ramène, ce sont des lignes `message` ordinaires.
4. **Courses** — `conversation:updated` et le sync HTTP écrivent la même ligne via
   `upsertConversation` ; la charge socket omet les champs par-utilisateur, et la garde
   `updatedAt > metaUpdatedAt` neutralise le réordonnancement des trames. Message en
   vol au moment où le mode annonce s'active → rejet serveur, failed sans retry.
   `markAsRead` vs message système : le type 6 est exclu de `countUnread`.
5. **Idempotence** — promotion vers un rôle déjà en place → 200 **sans message
   système** ; kick d'un membre déjà parti → **200 `{alreadyGone:true}`** et non 404 ;
   `addParticipants` filtre déjà les doublons ; les mentions étant écrites **dans
   l'INSERT**, un replay du même `clientID` ne peut ni les dupliquer ni les perdre.
6. **Mentions et appartenance** — `@Tous` est déplié **à l'envoi** : un membre ajouté
   ensuite n'est pas mentionné rétroactivement. Une mention d'un membre parti reste
   surlignée mais n'est plus tappable. Le compteur de saut se dérive, il ne se
   décrémente pas — il ne peut donc pas devenir négatif.
7. **Fuite du `TapGestureRecognizer`** — un recognizer par span de mention, libéré dans
   le `dispose` du widget de bulle.
8. **Départ du propriétaire** — si `role === 2`, promouvoir l'admin restant le plus
   ancien (`ORDER BY joinedAt ASC, id ASC`), à défaut le membre le plus ancien ; mettre
   à jour `createdBy` ; poster `member_left` **et** `role_changed`. Un propriétaire
   existe donc toujours par construction ⇒ « plus aucun admin » est impossible. S'il
   ne reste personne, la purge existante supprime le groupe.
9. **Exclu pendant que l'écran est ouvert** — `group:participant:removed` → suppression
   locale → `watchConversation` émet `null` → `pop` + snackbar ; composeur et emits
   typing coupés. Hors ligne, le filet est `deleteConversationsNotIn(serverIds)`
   (`conversation_sync.dart:115`) au prochain sync.
10. **Autorité serveur** — chaque règle est appliquée côté serveur (middleware +
    `groupSendPolicy`) ; `group_permissions.dart` ne fait que masquer des boutons.
11. **Régressions à revérifier** — envoi/accusés 1-1 et groupe, badge non-lus
    (`countUnread`), aperçu de liste, épinglage/archivage (`PUT /:id` restreint), mute
    existant, albums (`groupMessagesForDisplay`), citations, `conversation:created`
    en 1-1.

---

## 7. Tests

Style maison : dart pur, **noms de tests en phrases françaises**, fakes écrits à la
main (pas de package de mocking). `ChatTestHarness` gagne un `seedGroupConversation`
**opt-in** — les tests existants restent intacts.

| Fichier | Exemples |
|---|---|
| `test/group_permissions_test.dart` *(nouveau)* | `'propriétaire peut retirer un admin'`, `'admin ne peut pas retirer un autre admin'`, `'mode annonce : membre bloqué, admin autorisé'`, `'on ne peut jamais se retirer soi-même'` |
| `test/system_message_payload_test.dart` *(nouveau)* | `'payload member_added → libellé avec les noms'`, `'acteur = moi → formulation à la première personne'`, `'événement inconnu → null (compat ascendante)'` |
| `test/mention_parser_test.dart` *(nouveau)* | `'curseur après @ma → requête « ma »'`, `'adresse e-mail a@b → aucune mention'`, `'deux membres de même préfixe → correspondance la plus longue'`, `'@Tous reconnu quelle que soit la locale de lecture'` |
| `test/mention_counter_test.dart` *(nouveau)* | `'compteur = mentions non lues me ciblant'`, `'message lu → compteur décrémenté'`, `'mention dans mon propre message → non comptée'`, `'compteur à zéro → bouton masqué'` |
| `test/group_socket_events_test.dart` *(nouveau)* | `'conversation:updated → nom mis à jour sans écraser unread ni isPinned'`, `'trame plus ancienne que le local → ignorée'`, `'group:participant:removed sur moi → conversation supprimée localement'` |
| `test/chat_characterization_test.dart` *(étendu)* | `'message système (type 6) → aperçu mis à jour, unread inchangé'`, `'mention persistée → rejouée au flush de l'outbox'` |

Backend : pas de runner de tests dans le dépôt ⇒ vérification par Swagger/curl avec
JWT.

---

## 8. Séquencement des commits

> Tous livrés. Le découpage réel a différé du plan sur deux points, tous deux
> assumés : le commit 6 s'est scindé en trois (endpoints / repository / UI), et
> le 8b a été précédé d'un commit « envoi » sans lequel le ciblage serveur
> restait du code mort — aucun client n'envoyait de mentions, et l'interrupteur
> « uniquement les mentions » aurait rendu un groupe totalement muet.

| # | Commit | Pourquoi rien n'est cassé entre deux |
|---|---|---|
| 1 | `feat(chat): rôles, réglages et mentions en base (migration 024 + backfill)` | SQL seul, migration unique. Colonnes nullables ou à défaut neutre ; personne ne les lit encore. |
| 2 | `fix(chat): autorisations manquantes sur groupe, join_conversation et message:send` | Correctif de sécurité pur, **livrable tôt et indépendamment**. Le client n'envoie jamais `GroupName` via `PUT /:id` ⇒ aucun changement app requis. |
| 3 | `feat(chat): exposer le rôle des participants dans l'API` | Le client ignore le champ (`participantsJson` opaque) ⇒ risque nul. |
| 4 | `feat(app): schéma local v15, modèle Participant, interface ChatApi groupe` | Drift + modèles + fakes + tests. Aucune UI, aucun appel réseau nouveau. |
| 5a | `feat(app): rendu des messages système (type 6)` | **Le client sait rendre le type 6 AVANT que le serveur n'en émette.** |
| 5b | `feat(chat): émission des messages système de groupe` | Backend, derrière `GROUP_SYSTEM_MESSAGES=1` pendant un cycle de release, pour que les versions app en circulation n'affichent jamais de JSON brut. |
| 6 | `feat(chat): gestion des membres et infos de groupe` | Endpoints + socket + repository + `group_detail_screen` + l10n + tests. |
| 7 | `feat(chat): verrous de groupe (mode annonce, édition réservée)` | `/settings` + application dans les deux chemins d'envoi + verrou composeur. |
| 8a | `feat(chat): mentions @ — envoi, ciblage push et mentionsOnly` | Colonne déjà en place (commit 1) : persistance à l'INSERT, dépliage `@Tous`, `mentioned` au payload, overlay de saisie, interrupteur de mute. |
| 8b | `feat(app): mentions @ — rendu, tap et navigation` | Surlignage, bulle teintée, tap, bouton de saut, `@` dans l'aperçu. Purement client. |
| 9 | `docs(chat): marquer PLAN-PARITE #2 comme fait` | — |

---

## 9. Vérification (test de bout en bout)

1. Appliquer `024` **+ le backfill** sur MySQL ; exécuter la requête de contrôle
   « groupe sans propriétaire » → **0 ligne**.
2. Swagger/curl : renommer sans être membre → 404 ; renommer en tant que membre avec
   `onlyAdminsCanEditInfo=1` → 403 ; retirer le propriétaire → 403 ; promouvoir en tant
   qu'admin non propriétaire → 403 ; envoyer en mode annonce en tant que membre → 403.
3. `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` →
   `flutter analyze` → `flutter test` → `flutter run`.
4. **Scénario 3 appareils** : A (propriétaire) promeut B ; B retire C. Vérifier que C
   reçoit `group:participant:removed`, que son écran se ferme, que la conversation
   disparaît de sa liste, et que A et B voient « B a retiré C » centré dans le fil,
   **sans badge non-lu**.
5. Migration v14 → v15 sur un appareil déjà installé : conversations et messages en
   cache **non vidés**.
6. Mentions : muter le groupe + activer « uniquement les mentions » → message normal =
   push silencieuse (l'expéditeur voit toujours les deux coches) ; message mentionnant
   = alerte complète ; `@Tous` perce de la même façon.
7. Bouton de saut : 3 mentions non lues loin dans l'historique → pastille à 3, chaque
   appui saute à la **plus ancienne restante**, le message atteint est teinté, le
   bouton disparaît une fois la conversation lue. Vérifier le cas où la mention est
   hors de la page chargée (`_ensureMessageLoaded` doit la rapatrier).
8. Tap sur une mention : autre membre → fiche contact ; moi-même → mon profil (**pas**
   la fiche contact) ; `@Tous` → fiche du groupe.
9. Locale : envoyer `@Tous` depuis un client français, lire depuis un client anglais →
   le texte reste `@Tous` et **doit rester surligné**.
10. Hors ligne : la fiche groupe reste consultable (rôles compris) ; toute mutation
    affiche une erreur explicite et ne modifie rien localement. Une mention envoyée
    hors ligne conserve sa cible au flush de l'outbox.

---

## 10. Notes & points ouverts

- Migrations backend **appliquées à la main** (pas de runner dans `package.json`) —
  confirmer la procédure de prod, surtout pour le backfill.
- Déviations assumées vs `PLAN-PARITE` §2 : `PATCH /:id/group` au lieu de
  `PATCH /:id` ; abandon de `group:role:changed` au profit de `conversation:updated`.
- Deux points de design ouverts, non bloquants : le plafond d'affichage de la pastille
  de saut au-delà de 99, et l'utilité de la pastille « Vous êtes mentionné » en
  notification alors que le `@Vous` est déjà visible dans le corps.
- `conversation.updatedAt` avec `ON UPDATE CURRENT_TIMESTAMP` bouge à chaque message
  envoyé (bruyant mais monotone) — suffisant pour la garde anti-réordonnancement.
- Les appels de groupe (`group_detail_screen.dart:100`, UI commentée lignes 260-274)
  restent hors scope.
