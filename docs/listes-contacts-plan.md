# Listes de contacts (Famille / Amis / Bureau…) — Plan d'implémentation

> Statut : **implémenté** (branche `listes`)
> Périmètre : Talky (Flutter) + Alanya-Backend (Node/Express/MySQL)
> Dernière mise à jour : 2026-08-05
>
> ⚠️ Migration renumérotée **023 → 038** : 025 à 037 étaient déjà pris au moment
> de l'implémentation (socle de compte, groupes enrichis, QR, réglages…).
> Le bump Drift devient **19 → 20** pour la même raison.

---

## 1. Contexte & objectif

Aujourd'hui Talky n'a **aucune notion de listes ou de groupes de contacts**. La
seule organisation existante est la liste plate des **contacts préférés**
(favoris), implémentée de bout en bout :

| Couche | Existant (contacts préférés) |
|---|---|
| Base MySQL | table `preferredContact (alanyaID owner, idFriend)` |
| API backend | `GET/POST/DELETE /api/contacts`, contrôleur `preferredContactController.js` |
| Cache local | flag Drift `LocalUsers.isPreferredContact` |
| Sync | `LocalCacheRepository.watch/syncPreferredContacts()` (offline-first) |
| UI | `PreferredContactsScreen` |

> ⚠️ Le mot « groupe » dans le code actuel désigne uniquement les
> **conversations de groupe** (table `conversation.isGroup`) — c'est **distinct**
> des listes de contacts.

**Objectif** : permettre à l'utilisateur de **ranger ses contacts préférés dans
des listes nommées** (Famille, Amis, Bureau…) pour les **filtrer**, et de **créer
une conversation de groupe avec toute une liste en un geste**.

### Décisions produit validées

| Sujet | Décision |
|---|---|
| **Membres** | Uniquement des contacts déjà en **favoris** (préférés) |
| **Appartenance** | **Many-to-many** — un contact peut appartenir à plusieurs listes |
| **Action groupée** | **Chat de groupe** depuis une liste (uniquement — pas d'appel de groupe ni de diffusion de statut pour l'instant) |
| **Emplacement UI** | **Puces de filtre** dans l'écran Contacts préférés **ET** un **écran dédié** de gestion |
| **Barre de navigation** | **Aucun 6e onglet** (`GlassNavBar` est codé en dur à 5 onglets) |

**Stratégie directrice** : calquer exactement le pattern « contacts préférés » sur
les 3 couches.

---

## 2. Backend — Alanya-Backend

Stack : Node.js + Express 4 + MySQL (SQL brut via `mysql2/promise`, pas d'ORM).
Auth : middleware JWT `src/middleware/auth.js` (`req.user.alanyaID`).

### 2.1 Migration SQL — `migrations/038_contact_lists.sql` *(nouveau)*

Sur le modèle de `preferredContact` / `conv_participants`
(`migrations/001_initial_schema.sql`).

```sql
-- 038_contact_lists.sql — listes de contacts + membres (many-to-many)

CREATE TABLE IF NOT EXISTS contact_list (
  idList     BIGINT       NOT NULL AUTO_INCREMENT,
  alanyaID   INT          NOT NULL,               -- propriétaire de la liste
  name       VARCHAR(60)  NOT NULL,
  color      VARCHAR(9)   NULL,                    -- ex #RRGGBB pour la puce
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idList),
  UNIQUE KEY uq_list_name (alanyaID, name),
  KEY idx_list_owner (alanyaID),
  CONSTRAINT fk_list_owner FOREIGN KEY (alanyaID)
    REFERENCES users(alanyaID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS contact_list_member (
  idList     BIGINT   NOT NULL,
  idFriend   INT      NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idList, idFriend),
  KEY idx_clm_friend (idFriend),
  CONSTRAINT fk_clm_list   FOREIGN KEY (idList)
    REFERENCES contact_list(idList) ON DELETE CASCADE,
  CONSTRAINT fk_clm_friend FOREIGN KEY (idFriend)
    REFERENCES users(alanyaID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> ⚠️ **Les migrations sont appliquées à la main** sur ce backend (pas de runner
> dans `package.json`). Ce SQL doit être exécuté manuellement sur la base.

### 2.2 Contrôleur — `src/controllers/contactListController.js` *(nouveau)*

Style copié de `preferredContactController.js` : scoping `req.user.alanyaID`,
`parseInt(req.params.id, 10)`, `pool.execute(...)`, codes HTTP 400/404/409,
helpers `sanitizeUrl` + `maskPresenceIfBlocked` (`src/utils/blockUtils.js`).

| Handler | Rôle | Notes |
|---|---|---|
| `getLists` | Listes du propriétaire + `member_count` | `LEFT JOIN contact_list_member ... GROUP BY` |
| `createList` | `{ name, color }` | 409 si `uq_list_name` violé |
| `updateList` | `PUT /:idList` `{ name?, color? }` | Renommer / recolorer, contrôle de propriété |
| `deleteList` | `DELETE /:idList` | Le CASCADE supprime les membres |
| `getListMembers` | `GET /:idList/members` | JOIN `contact_list_member` → `users`, même projection que `getPreferredContacts` |
| `addMember` | `POST /:idList/members/:friendID` | Vérifie propriété **ET** que `friendID` est un contact préféré du propriétaire (`SELECT ... FROM preferredContact`) → sinon 400/403 |
| `removeMember` | `DELETE /:idList/members/:friendID` | — |

### 2.3 Routes — `src/routes/contactLists.js` *(nouveau)*

Router Express avec `auth` sur **chaque** route + blocs Swagger `@swagger`
(comme `src/routes/contacts.js`).

```
GET    /                            → getLists
POST   /                            → createList
PUT    /:idList                     → updateList
DELETE /:idList                     → deleteList
GET    /:idList/members             → getListMembers
POST   /:idList/members/:friendID   → addMember
DELETE /:idList/members/:friendID   → removeMember
```

### 2.4 Enregistrement — `server.js`

```js
const contactListRoutes = require('./src/routes/contactLists');
app.use('/api/contact-lists', contactListRoutes);
```

> Pour l'action « chat de groupe depuis une liste » : **aucun** nouvel endpoint —
> on réutilise `POST /api/conversations/group` déjà en place.

---

## 3. Frontend — couche données (Talky/Flutter)

### 3.1 Client API — `lib/api/contact_lists_api.dart` *(nouveau)*

Extension `ContactListsApi on TalkyApiClient`, `part of '../talky_api_client.dart'`,
sur le modèle de `lib/api/users_api.dart` (`_handleRequest`, `_headers`,
`TalkyApiClient.baseUrl`). Déclarer le `part` dans `talky_api_client.dart`.

Méthodes : `getContactLists()`, `createContactList(name, color)`,
`updateContactList(id, {name, color})`, `deleteContactList(id)`,
`getListMembers(id)`, `addListMember(id, friendID)`, `removeListMember(id, friendID)`.

### 3.2 Modèle — `lib/talky_models.dart`

Ajouter `ContactList` (`idList`, `name`, `color`, `memberCount`,
`fromJson`/`toJson`) à côté de `PreferredContact`.

### 3.3 Cache Drift — `lib/core/db/app_database.dart`

Deux nouvelles tables (modèle `LocalUsers` / `LocalMessageReactions`) :

- `LocalContactLists` : `idList` (PK), `name`, `color` (nullable), `memberCount`
  (défaut 0), `cachedAt`.
- `LocalContactListMembers` : `idList` + `idFriend`, **PK composite**
  `{idList, idFriend}`.

Puis :
1. Les ajouter au `@DriftDatabase(tables: [...])`.
2. **Bumper `schemaVersion` 19 → 20**.
3. Dans `onUpgrade` :
   ```dart
   if (from < 20) {
     await m.createTable(localContactLists);
     await m.createTable(localContactListMembers);
   }
   ```
4. **Régénérer** : `dart run build_runner build --delete-conflicting-outputs`.

### 3.4 Repository — `lib/core/services/local_cache_repository.dart`

Nouvelle section « LISTES DE CONTACTS », calquée sur
`watch/syncPreferredContacts` :

- `watchContactLists()` — stream Drift (offline-first).
- `syncContactLists()` — `_api.getContactLists()` + upsert + diff-suppression
  (même logique `previousIds/newIds`).
- `watchListMembers(idList)` — jointure membres → `LocalUsers`, renvoie des
  `User` (réutiliser `localUserToUser`).
- `syncListMembers(idList)` — upsert des membres.
- Mutations (create/update/delete/addMember/removeMember) : **online** via
  `TalkyApiClient` puis re-sync (comme `addContact`/`removeContact`).
- Ajouter les 2 tables au `clearSession()`.

---

## 4. Frontend — UI

### 4.1 Puces de filtre dans `PreferredContactsScreen`

`lib/screens/profile/preferred_contacts_screen.dart` — ajouter au-dessus de la
liste une rangée horizontale de puces réutilisant le pattern `_buildFilterChip`
de `lib/screens/chats/chats_screen.dart` (l.539-569) :

- Puce **« Tous »** + une puce par liste (`watchContactLists()`) + une puce
  **« ＋ Gérer »** ouvrant l'écran dédié.
- État `_selectedListId` (null = Tous). Liste active ⇒ filtrer les contacts
  préférés streamés par les `idFriend` membres (`watchListMembers`), combiné avec
  la recherche existante (`filterUsersBySearch`).

### 4.2 Écran dédié — `lib/screens/profile/contact_lists_screen.dart` *(nouveau)*

Gestion CRUD des listes (créer / renommer / recolorer / supprimer). Chaque liste
→ écran détail `contact_list_detail_screen.dart` *(nouveau)* affichant ses membres
avec ajout / retrait.

- **Réutiliser** : `AppAvatar`, `AppSearchField`, `EmptyState`, `AppBottomSheet`,
  tokens `AppSpacing` / `AppRadius` / `context.colors` / `context.l10n`.
- **Ajout de membres** : feuille multi-sélection sur les **contacts préférés
  uniquement** (réutiliser le pattern multi-sélect en commentaire dans
  `select_contact_screen.dart` : `_selecting` / `_selectedIds`).
- **Bouton « Créer un groupe »** → `createGroup(participantIDs: membres,
  groupName: <nom de la liste>, ...)` (`lib/api/chat_api.dart` l.27), nom
  pré-rempli et éditable, puis navigation vers la nouvelle conversation.

### 4.3 Points d'entrée

- **Profil** : entrée « Listes de contacts » à côté de « Contacts préférés »
  (`lib/screens/profile/profile_screen.dart` l.70-73).
- La puce « ＋ Gérer » (§4.1) mène au même écran dédié.

### 4.4 Localisation

Chaînes dans `lib/l10n/app_localizations.dart` (abstrait), `_fr.dart`, `_en.dart`
(+ `.arb` si présent) : `contactLists`, `createList`, `listName`, `renameList`,
`deleteList`, `addToList`, `removeFromList`, `createGroupFromList`, `noLists`, …

---

## 5. Récapitulatif des fichiers

**Backend** *(nouveaux sauf mention)* :
`migrations/038_contact_lists.sql`, `src/controllers/contactListController.js`,
`src/routes/contactLists.js`, `server.js` *(modif : enregistrement)*.

**Frontend — données** :
`lib/api/contact_lists_api.dart` *(nouveau)* + `talky_api_client.dart` *(part)*,
`lib/talky_models.dart` *(modèle)*, `lib/core/db/app_database.dart`
*(+ `app_database.g.dart` régénéré)*, `lib/core/services/local_cache_repository.dart`.

**Frontend — UI** :
`lib/screens/profile/preferred_contacts_screen.dart` *(puces)*,
`lib/screens/profile/contact_lists_screen.dart` *(nouveau)*,
`lib/screens/profile/contact_list_detail_screen.dart` *(nouveau)*,
`lib/screens/profile/profile_screen.dart` *(entrée)*, `lib/l10n/*`.

---

## 6. Vérification (test de bout en bout)

1. **Backend** — appliquer `038_contact_lists.sql` sur MySQL, redémarrer le
   serveur, tester chaque endpoint via Swagger/curl avec un JWT valide :
   créer liste → 201 ; doublon de nom → 409 ; ajouter un non-favori → 400/403 ;
   lister membres ; supprimer.
2. **Frontend** — `flutter pub get` →
   `dart run build_runner build --delete-conflicting-outputs` → `flutter run`.
3. **Scénario complet** — créer « Famille », y ajouter 2-3 contacts préférés →
   la puce « Famille » filtre la liste → « Créer un groupe » ouvre une
   conversation de groupe avec ces membres et le nom pré-rempli.
4. **Migration v19 → v20** — sur un appareil déjà installé, vérifier que la mise
   à jour **ne vide pas** les données existantes (upgrade path, pas recreate).
5. **Offline** — réseau coupé : listes + membres restent visibles depuis le cache
   Drift ; les mutations affichent un état hors-ligne cohérent.

---

## 7. Notes & points ouverts

- Migrations backend **appliquées manuellement** — confirmer la procédure de
  déploiement SQL en prod avant mise en ligne.
- `color` par liste (optionnel) sert à colorer la puce ; une icône pourrait
  s'ajouter plus tard.
- Extensions futures faciles (mêmes tables, volontairement hors scope) : appel de
  groupe depuis une liste, diffusion de statut restreinte à une liste.
