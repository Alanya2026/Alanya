# Listes de contacts — rapport d'implémentation

> Statut : **implémenté**, non déployé (migration SQL à appliquer à la main)
> Branche : `listes` (Talky **et** Alanya-Backend)
> Date : 2026-08-05 *(révisé le même jour après la première recette — voir §10)*
> Référence produit : dossier de conception `docs/architecture/liste-contacts.tex`
> (PDF compilé à côté), qui **remplace** [`listes-contacts-plan.md`](listes-contacts-plan.md)
> — conformité détaillée en §11

Ce document décrit ce qui a été **réellement écrit**, fichier par fichier, les
décisions prises en cours de route, et les écarts par rapport à la conception.
Il se lit seul : le dossier de conception reste la référence produit, celui-ci la
référence technique.

---

## 1. Ce que fait la fonctionnalité

L'utilisateur peut ranger ses **contacts préférés** dans des **listes nommées**
(Famille, Amis, Bureau…), pour :

1. **filtrer** l'écran Contacts préférés d'un geste (puces au-dessus de la liste) ;
2. **créer une conversation de groupe** avec toute une liste, nom pré-rempli.

Règles conservées du plan :

| Sujet | Règle |
|---|---|
| Membres | Uniquement des contacts **déjà en favoris** — le backend refuse le reste |
| Retrait des favoris | **Sort le contact de toutes mes listes**, automatiquement (serveur *et* cache) |
| Appartenance | **Many-to-many** : un contact peut être dans plusieurs listes |
| Propriété | Une liste est **privée** à son propriétaire, jamais partagée |
| Action groupée | **Chat de groupe** uniquement (pas d'appel ni de statut restreint) |
| Navigation | **Aucun 6ᵉ onglet** — entrées depuis Profil et depuis les puces |
| Suppression | Supprimer une liste **ne retire aucun contact des favoris** |

---

## 2. Écarts par rapport au plan

Trois écarts, tous imposés par l'état réel des dépôts au moment d'implémenter :

| Plan | Réalité | Raison |
|---|---|---|
| `migrations/025_contact_lists.sql` | **`038_contact_lists.sql`** | 025 → 037 déjà pris (QR, réglages, socle de compte, groupes…) |
| Drift `schemaVersion` 15 → 16 | **19 → 20** | La base locale était déjà en 19 |
| Un écran de création de groupe *ad hoc* | **Réutilisation de `CreateGroupScreen`** via un paramètre `initialName` | Évite de dupliquer photo / description / réglages d'admin |

Le plan a été mis à jour en conséquence (statut, numéros, chemin de migration).

---

## 3. Backend — `Alanya-Backend`

Stack inchangée : Express 4 + `mysql2/promise`, SQL brut, auth JWT
(`src/middleware/auth.js` → `req.user.alanyaID`).

### 3.1 `migrations/038_contact_lists.sql` *(nouveau)*

Deux tables, modelées sur `preferredContact` (migration 001) :

```sql
contact_list(idList PK, alanyaID FK users, name VARCHAR(60), color VARCHAR(9), created_at)
  UNIQUE (alanyaID, name)      -- deux listes du même nom impossibles chez un même utilisateur
  INDEX  (alanyaID)
  ON DELETE CASCADE            -- compte supprimé ⇒ listes supprimées

contact_list_member(idList FK contact_list, idFriend FK users, created_at)
  PRIMARY KEY (idList, idFriend)   -- l'unicité de l'appartenance est structurelle
  INDEX (idFriend)
  ON DELETE CASCADE                -- liste supprimée ⇒ appartenances supprimées
```

`contact_list_member` ne porte **que le lien** : aucun nom, avatar ni téléphone
n'est dupliqué, tout vient de `users` par jointure.

> ⚠️ Les migrations de ce backend sont **appliquées à la main** (aucun runner
> dans `package.json`). Ce fichier doit être exécuté **avant** de déployer le
> code : les contrôleurs nomment ces tables.

### 3.2 `src/controllers/contactListController.js` *(nouveau)*

Style copié de `preferredContactController.js` : `pool.execute`, try/catch par
handler, `console.error('[handler] ERROR:', …)`, réponses JSON plates.

Helpers privés :

- `cleanName(raw)` — trim + coupe à 60 (longueur de colonne). Vide ⇒ 400.
- `cleanColor(raw)` — accepte `#RGB`, `#RRGGBB`, `#RRGGBBAA` ; **toute autre
  valeur devient `null`** plutôt que d'être rejetée (la couleur est cosmétique,
  elle ne doit pas faire échouer une création de liste).
- `parseListId(raw)` — entier > 0 sinon `null` ⇒ 400.
- `findOwnedList(idList, alanyaID)` — **la garde de propriété**, appelée par tous
  les handlers qui touchent une liste existante. Elle ne distingue pas « liste
  inexistante » de « liste d'un autre » : **404 dans les deux cas**, pour ne pas
  révéler l'existence des listes d'autrui.

| Handler | Route | Comportement notable |
|---|---|---|
| `getLists` | `GET /` | `LEFT JOIN … GROUP BY` ⇒ `memberCount` calculé côté SQL, tri par nom |
| `createList` | `POST /` | 400 si nom vide ; **409** sur `ER_DUP_ENTRY` (`uq_list_name`) |
| `updateList` | `PUT /:idList` | `name` et `color` **optionnels indépendamment** (test `hasOwnProperty`) : `color:""` ou `null` efface, `color` absent conserve. 409 possible |
| `deleteList` | `DELETE /:idList` | Le CASCADE emporte les membres ; les favoris ne bougent pas |
| `getListMembers` | `GET /:idList/members` | **Même projection que `getPreferredContacts`** (+ `maskPresenceIfBlocked`, `sanitizeUrl`) ⇒ le client réutilise son modèle `User` |
| `addMember` | `POST /:idList/members/:friendID` | Vérifie la propriété **puis** que `friendID` est un favori du propriétaire (`SELECT … FROM preferredContact`) sinon **403** — requête valide, règle métier qui refuse. `INSERT IGNORE` ⇒ ré-ajout **idempotent** |
| `removeMember` | `DELETE /:idList/members/:friendID` | 404 si le membre n'était pas là |

Le masquage de présence (`maskPresenceIfBlocked`) est appliqué membre par
membre, exactement comme sur les contacts préférés : un contact bloqué ne fuit
pas son `is_online` / `last_seen` par le biais d'une liste.

### 3.3 `src/routes/contactLists.js` *(nouveau)*

Router Express, `auth` sur **chaque** route, blocs `@swagger` complets (tag
`ContactLists`, codes 200/201/400/403/404/409 documentés).

```
GET    /                            → getLists
POST   /                            → createList
PUT    /:idList                     → updateList
DELETE /:idList                     → deleteList
GET    /:idList/members             → getListMembers
POST   /:idList/members/:friendID   → addMember
DELETE /:idList/members/:friendID   → removeMember
```

### 3.4 `server.js` *(modifié)*

```js
const contactListRoutes  = require('./src/routes/contactLists');
…
app.use('/api/contact-lists', contactListRoutes);
```

**Aucun endpoint de groupe n'a été ajouté** : « créer un groupe depuis une
liste » réutilise `POST /api/conversations/group` tel quel.

### 3.5 `src/controllers/preferredContactController.js` *(modifié)*

`removePreferredContact` purge désormais aussi les appartenances :

```sql
DELETE clm FROM contact_list_member clm
  JOIN contact_list cl ON cl.idList = clm.idList
 WHERE cl.alanyaID = ? AND clm.idFriend = ?
```

Être un favori est le **prérequis** pour appartenir à une liste (`addMember` le
vérifie). Sans cette purge, retirer quelqu'un des favoris le laissait en
**membre fantôme** : présent dans la liste, absent des favoris, et impossible à
ré-ajouter proprement. Le `JOIN` restreint la suppression à **mes** listes.

> Ce n'est volontairement pas une contrainte SQL : `contact_list_member` ne peut
> pas référencer `preferredContact` par clé étrangère (la PK y est
> `idPrefContact`, pas le couple propriétaire/ami), et une contrainte aurait de
> toute façon fait échouer le retrait au lieu de le propager.

---

## 4. Frontend — couche données

### 4.1 `lib/api/contact_lists_api.dart` *(nouveau)*

`extension ContactListsApi on TalkyApiClient`, `part of '../talky_api_client.dart'`
(le `part` est déclaré dans `talky_api_client.dart`, juste après `users_api`).
Sept méthodes, toutes via `_handleRequest` / `_headers` : `getContactLists`,
`createContactList`, `updateContactList`, `deleteContactList`, `getListMembers`,
`addListMember`, `removeListMember`.

`updateContactList` n'envoie que les champs non nuls — c'est ce qui permet au
`''` de signifier « efface la couleur » et à l'absence de signifier « n'y touche
pas », en miroir du contrôleur.

### 4.2 `lib/talky_models.dart` *(modifié)*

Modèle `ContactList` (`idList`, `name`, `color`, `memberCount`) avec
`fromJson`/`toJson`, posé à côté de `PreferredContact`. Il ne porte **pas** les
membres : ils se lisent séparément et s'hydratent en `User`.

### 4.3 `lib/core/db/app_database.dart` *(modifié)* + `.g.dart` *(régénéré)*

Deux tables Drift :

- `LocalContactLists` — `idList` (PK), `name`, `color` (nullable), `memberCount`,
  `cachedAt`.
- `LocalContactListMembers` — **PK composite `{idList, idFriend}`**, sur le
  modèle de `LocalMessageReactions`. Aucun champ de profil.

`schemaVersion` **19 → 20**, et dans `onUpgrade` :

```dart
if (from < 20) {
  await m.createTable(localContactLists);
  await m.createTable(localContactListMembers);
}
```

Que des `createTable` : **aucune donnée existante n'est touchée** — la mise à
jour d'un appareil déjà installé ne vide rien.

Régénération faite avec `dart run build_runner build`.

### 4.4 `lib/core/services/local_cache_repository.dart` *(modifié)*

Nouvelle section « LISTES DE CONTACTS », calquée sur `watch/syncPreferredContacts`
(offline-first : l'UI lit le cache, la synchro se fait en tâche de fond).

**Lecture (streams Drift)**

- `watchContactLists()` — les listes, triées par nom.
- `watchListMembers(idList)` — `innerJoin` `LocalContactListMembers` ×
  `LocalUsers`, rendu en `List<User>` via `localUserToUser`.
- `watchListMemberIds(idList)` — juste les `idFriend`, pour filtrer une liste
  déjà streamée sans repayer une jointure sur les profils.
- `watchListsByMember()` — l'appartenance vue **depuis le contact**
  (`alanyaID → listes`), en une seule jointure indexée en mémoire. C'est ce qui
  alimente les puces posées sous chaque contact de l'écran des favoris, et le
  filtrage par liste active.

**Synchronisation**

- `syncContactLists()` — fetch + upsert + **diff-suppression** (`previousIds`
  vs `newIds`). Une liste disparue côté serveur est **réellement supprimée** du
  cache (contrairement aux contacts préférés qu'on se contente de démarquer :
  un contact reste utile comme « auteur connu », une liste orpheline non).
- `syncListMembers(idList)` — upsert des profils en **écriture partielle**
  (`_partialUserToCompanion`, `presenceKnown: true`) pour ne pas écraser une
  fiche déjà complète avec la projection tronquée de l'endpoint, puis
  suppression des appartenances retirées ailleurs.

**Mutations** — online via `TalkyApiClient` puis re-synchro, comme
`addContact`/`removeContact` (pas d'outbox pour les listes) :
`createContactList`, `updateContactList`, `deleteContactList`, `addListMember`,
`addListMembers`, `removeListMember`. Les mutations de membres resynchronisent
**aussi** les listes, pour que `memberCount` (et donc les puces) reste juste.

- `createContactList(name, {color, memberIds})` — accepte les membres initiaux
  et les pose dans la foulée : c'est ce qui permet de créer une liste **déjà
  peuplée** en un seul geste côté UI.
- `addListMembers(idList, ids)` — ajout groupé, **une seule** resynchro pour
  toute la sélection (`addListMember` n'en est plus qu'un cas particulier).

**Retrait des favoris — point d'entrée unique.** `removePreferredContact(id,
{user})` fait l'appel réseau **et** le ménage local ; `forgetPreferredContact`
en est le volet purement local :

1. le contact est démarqué (`isPreferredContact = false`) ;
2. **toutes ses appartenances de liste sont supprimées** en cache ;
3. `syncContactLists()` remet les `memberCount` à jour.

Les cinq écrans qui retiraient un favori appelaient jusque-là
`_api.removeContact` directement — deux d'entre eux (fiche contact, fiche
d'appel) ne touchaient même pas au cache. Ils passent tous par cette méthode :
`preferred_contacts_screen`, `profile_screen`, `contact_detail_screen`,
`call_detail_screen`, `qr_contact_flow`.

`_forgetLists(ids)` centralise l'oubli local (membres puis listes) ; les profils
des membres restent en cache, ils sont partagés avec le reste de l'app.

`clearSession()` vide les deux nouvelles tables avant `localUsers`.

---

## 5. Frontend — UI

### 5.1 `preferred_contacts_screen.dart` *(modifié)* — les puces

La rangée de deux `ChoiceChip` (« Tous » / « Par QR ») devient un `ListView`
horizontal : **Tous · n**, **Par QR · n**, **une puce par liste** (teintée par
`color`, suffixée du nombre de membres), puis une `ActionChip` **« Gérer »** qui
ouvre l'écran dédié.

Sous chaque contact, une rangée de **puces d'appartenance** (`_ListBadge`)
reprend la couleur de ses listes : c'est le seul endroit de l'app où
l'appartenance multiple se voit d'un coup d'œil. Elles viennent d'un unique flux
`watchListsByMember()` — un stream par ligne aurait fait une requête par contact
affiché — qui sert **aussi** au filtrage par liste active.

Trois filtres composables **en ET** : origine QR (`_filtreQr`), liste active
(`_selectedListId`), recherche (`_searchQuery`, appliquée en dernier).

Deux points d'attention traités :

- **Pas de mutation d'état pendant un build.** Le `StreamBuilder` des listes
  enveloppe *toute* la colonne, et l'identifiant réellement appliqué est
  **dérivé** à chaque build (`activeListId`) : si la liste filtrée vient d'être
  supprimée depuis l'écran de gestion, l'affichage retombe sur « Tous » dans la
  même passe, sans `setState` clandestin ni frame fantôme.
- `_buildContactList(scoped, hasQuery, memberships)` factorise liste et états
  vides, pour que la version filtrée par liste et la version non filtrée ne
  divergent pas.

`initState` déclenche un `syncContactLists()` en tâche de fond.

### 5.2 `contact_lists_screen.dart` *(nouveau)* — gestion des listes

- `StreamBuilder` sur `watchContactLists()`, tuiles « pastille colorée + nom +
  n membres », `EmptyState` avec appel à l'action quand il n'y a rien.
- FAB étendu **« Nouvelle liste »** (le padding bas du `ListView` laisse passer
  le FAB sous le dernier élément).
- Sous la dernière tuile, le rappel des deux règles qui surprennent : on ne range
  que des favoris, et un contact peut appartenir à plusieurs listes.
- Menu par liste (icône `⋮` **ou** appui long) : **Renommer** / **Supprimer**.
  La suppression passe par un `AlertDialog` qui rappelle explicitement que
  *les contacts restent dans les favoris*.
- Éditeur partagé `showListEditorSheet()` (création **et** renommage) : champ
  nom (60 max, `autofocus`, validation « non vide »), palette de 8 couleurs
  précédée d'une pastille **« sans couleur »** (icône, pas de libellé), feuille
  remontée au-dessus du clavier (`viewInsets`).
- **En création uniquement**, l'éditeur porte en plus une ligne « Ajouter des
  membres · n membres » qui ouvre la feuille de sélection **avant** que la liste
  n'existe côté serveur. Le `ContactListDraft` renvoyé transporte donc
  `memberIds`, et `createContactList` crée la liste **puis** pose les membres.
  En renommage, la ligne est masquée : les membres se gèrent depuis l'écran
  détail, où ils sont déjà sous les yeux.
- Erreurs : `TalkyException.statusCode == 409` ⇒ « Une liste porte déjà ce
  nom », sinon message générique. Le `l10n` est capturé **avant** l'`await` pour
  ne pas traverser un gap async avec un `BuildContext`.

Le fichier exporte aussi deux utilitaires réutilisés par les puces :
`kContactListColors` (la palette) et `parseListColor(hex)` (`#RRGGBB`/`#RRGGBBAA`
→ `Color`, `null` si illisible ⇒ teinte du thème).

### 5.3 `contact_list_detail_screen.dart` *(nouveau)* — membres d'une liste

**Ajouter et retirer se font au même endroit, sans écran intermédiaire.** La
liste affiche les membres (cochés) *puis* les autres favoris, en retrait
(opacité) et sous-titrés « Favori — pas dans cette liste ». Un appui sur la case
bascule l'appartenance immédiatement.

- Trois flux imbriqués : `watchContactLists()` (le titre suit un renommage en
  direct), `watchListMembers(idList)` et `watchPreferredContacts()` — les
  non-membres se déduisent de la différence.
- Sous-titre des membres : présence réelle — « En ligne », « Vu à 12:04 »,
  « Vu hier à … » — comme dans la maquette.
- `_pending` neutralise la case le temps de l'aller-retour réseau : un double
  appui n'envoie pas deux mutations contradictoires.
- Le tap sur la ligne (hors case) ouvre `ContactDetailScreen`.
- `initState` : `syncListMembers` **et** `syncPreferredContacts` — les
  non-membres proposés viennent des favoris.
- **« Créer un groupe « Famille » »** : bouton pleine largeur en bas, portant le
  nom de la liste, visible dès qu'il y a au moins un membre.

### 5.4 `add_list_members_sheet.dart` *(nouveau)* — sélection de membres

Feuille utilisée **uniquement à la création** — tant que la liste n'existe pas
côté serveur, il n'y a pas d'écran détail où cocher. Multi-sélection par cases à
cocher sur les **contacts préférés**, avec recherche (`filterUsersBySearch`) et
compteur de sélection.

- `alreadyIn` retire du vivier des membres déjà posés ; `initialSelection` permet
  de **rouvrir** la feuille sur la sélection en cours pour décocher ;
  `confirmLabel` laisse l'appelant choisir « Ajouter » ou « Enregistrer ».
- Hauteur fixe à 70 % de l'écran — même patron que
  `share_preferred_contact_sheet.dart` — parce qu'un `Expanded` n'a de sens que
  sous une contrainte bornée.
- Confirmer une sélection vide est permis (c'est ainsi qu'on décoche tout) ;
  l'appelant traite ce cas comme un non-événement.

### 5.5 `create_group_screen.dart` *(modifié)*

Ajout d'un paramètre optionnel `initialName`, injecté dans le contrôleur en
`initState`. C'est tout : le groupe issu d'une liste hérite ainsi de l'écran de
création complet (photo, description, « seuls les admins… », historique masqué),
avec le nom de la liste **pré-rempli et éditable**. Aucun autre appelant n'est
impacté (le paramètre est nullable).

### 5.6 `profile_screen.dart` *(modifié)*

Une entrée **« Listes de contacts »** (icône dossier) est ajoutée dans la carte
de menu, en **2ᵉ position** juste après « Mon compte ». La carte est posée
directement sous la grille des contacts préférés : la proximité fait le lien,
sans encombrer l'en-tête de section.

> Un premier essai plaçait un `TextButton.icon` **dans l'en-tête** de la section
> « Contacts préférés », à côté du raccourci « +N › ». Mauvaise idée : deux
> actions concurrentes dans un même en-tête, un libellé long qui écrasait le
> titre sur écran étroit, et une cible tactile hors du rythme des autres
> entrées. Remplacé par une ligne de menu standard.

### 5.7 Localisation

21 clés ajoutées à `lib/l10n/app_fr.arb` et `app_en.arb`, puis
`flutter gen-l10n` (les trois `app_localizations*.dart` sont régénérés) :

`contactLists`, `contactListsManage`, `createList`, `listName`, `listNameHint`,
`renameList`, `deleteList`, `deleteListConfirm` *(placeholder `name`)*,
`listColor`, `listNameAlreadyExists`, `listSaveFailed`,
`listMembersUpdateFailed`, `listMembersCount` *(pluriel ICU)*, `addToList`,
`removeFromList`, `createGroupFromList`, `noLists`, `noListsHint`,
`noListMembers`, `noContactToAddToList`, `addMembersSelected` *(placeholder
`count`)*.

Toutes sont réellement utilisées : aucune chaîne morte n'a été laissée dans les
`.arb`.

Les libellés génériques existants sont réutilisés : `commonCancel`, `commonSave`,
`commonDelete`, `create`, `add`, `noResults`, `qrContactsFilterAll`,
`qrContactsFilterQr`, `searchByNameUsernameOrPhone`.

---

## 6. Récapitulatif des fichiers

**Backend** — `migrations/038_contact_lists.sql` *(n)*,
`src/controllers/contactListController.js` *(n)*, `src/routes/contactLists.js` *(n)*,
`server.js` *(m)*, `src/controllers/preferredContactController.js` *(m : cascade
du retrait des favoris)*.

**Frontend, données** — `lib/api/contact_lists_api.dart` *(n)*,
`lib/talky_api_client.dart` *(m : `part`)*, `lib/talky_models.dart` *(m)*,
`lib/core/db/app_database.dart` *(m)* + `app_database.g.dart` *(régénéré)*,
`lib/core/services/local_cache_repository.dart` *(m)*,
`lib/core/services/qr_contact_flow.dart` *(m : retrait via le cache)*.

**Frontend, UI** — `lib/screens/profile/contact_lists_screen.dart` *(n)*,
`lib/screens/profile/contact_list_detail_screen.dart` *(n)*,
`lib/screens/profile/add_list_members_sheet.dart` *(n)*,
`lib/screens/profile/preferred_contacts_screen.dart` *(m)*,
`lib/screens/profile/profile_screen.dart` *(m)*,
`lib/screens/chats/create_group_screen.dart` *(m)*,
`lib/screens/chats/contact_detail_screen.dart` *(m : retrait via le cache)*,
`lib/screens/calls/call_detail_screen.dart` *(m : idem)*,
`lib/l10n/app_fr.arb` + `app_en.arb` *(m)* + `app_localizations*.dart` *(régénérés)*.

**Docs** — `docs/listes-contacts-plan.md` *(m : statut + numéros)*,
`docs/listes-contacts-implementation.md` *(n : ce fichier)*.

---

## 7. Ce qui a été vérifié — et ce qui ne l'a pas été

**Vérifié**

- `flutter analyze` : **0 problème** sur l'ensemble des fichiers touchés (les
  ~54 `info` restantes du projet sont préexistantes et situées ailleurs).
- `dart run build_runner build` : `.g.dart` régénéré, tables et managers Drift
  bien présents.
- `flutter gen-l10n` : les 21 clés sont générées en fr et en.
- `flutter test` : 18 échecs, **tous préexistants et sans rapport**
  (`Bad state: LocaleController not ready` dans les tests de formatage,
  assertions `chat_dao` antérieures) — confirmé en isolant un test qui ne touche
  à rien de cette feature.
- `node --check` sur le contrôleur, les routes et `server.js`.

**Non vérifié (impossible sur cette machine)**

- Le SQL `038` **n'a pas été appliqué** : ce backend n'a pas de `.env` ici et
  aucun MySQL n'est joignable. Les endpoints n'ont donc jamais été appelés pour
  de vrai.
- L'application n'a pas été lancée sur appareil/émulateur : les écrans n'ont pas
  été vus à l'écran, seulement analysés.

---

## 8. Déploiement et recette

1. **Appliquer `migrations/038_contact_lists.sql` sur MySQL, avant de déployer
   le code backend.** Les contrôleurs nomment les tables : dans l'autre ordre,
   toute route `/api/contact-lists` renvoie 500.
2. Redémarrer le serveur, puis tester via Swagger (`/api/docs`, tag
   `ContactLists`) avec un JWT valide :
   - créer une liste → **201** ;
   - recréer le même nom → **409** ;
   - ajouter un utilisateur qui n'est **pas** un favori → **403** ;
   - ajouter deux fois le même favori → **201** les deux fois, un seul membre ;
   - `PUT` avec `{"color":""}` → couleur effacée ; sans `color` → inchangée ;
   - toucher la liste d'un autre compte → **404**.
3. Front : `flutter pub get` → `dart run build_runner build` → `flutter run`.
4. Scénario complet : créer « Famille » **en cochant 2-3 favoris dans la feuille
   d'ajout dès l'écran de création** → la puce « Famille · 3 » filtre l'écran
   Contacts préférés → « Créer un groupe » ouvre la création avec les membres et
   le nom pré-remplis.
4 bis. **Cascade du retrait des favoris** : depuis les membres d'une liste,
   ouvrir la fiche d'un membre, le retirer des favoris → il disparaît de la
   liste **et** de toutes les autres où il figurait, et les compteurs des puces
   se mettent à jour. À rejouer depuis la fiche d'appel, qui passe par le même
   chemin.
5. **Migration v19 → v20** : sur un appareil déjà installé, vérifier que les
   conversations, messages et contacts en cache **survivent** à la mise à jour.
6. **Hors ligne** : réseau coupé, listes et membres restent affichés depuis
   Drift ; les mutations échouent proprement avec un `SnackBar`.

---

## 9. Limites connues et suites possibles

- **Mutations online uniquement** : créer/renommer/supprimer une liste ou
  modifier ses membres exige le réseau. C'est le choix du plan (aligné sur
  `addContact`), mais une file d'attente hors ligne serait la suite naturelle.
- **Ajout de membres séquentiel** : `addListMembers` envoie un `POST` par contact
  sélectionné (une seule re-synchro à la fin). Correct et idempotent, mais
  bavard sur une sélection large — un endpoint d'ajout en lot le réglerait. Si
  l'un des `POST` échoue en cours de route, les précédents restent posés.
- **Pas de temps réel** : aucune trame socket sur les listes. Comme elles sont
  privées à un compte, la divergence ne peut venir que d'un second appareil du
  même utilisateur, rattrapée à la prochaine synchro.
- **Extensions faciles, hors scope volontaire** (mêmes tables) : appel de groupe
  depuis une liste, diffusion de statut restreinte à une liste, réordonnancement
  manuel des listes.

---

## 10. Révision après la première recette

Trois retours d'usage, tous traités. Ils ne touchent **ni le schéma SQL ni la
version Drift** : aucune migration supplémentaire.

### 10.1 Position de l'entrée « Listes de contacts » — UI/UX

Le bouton texte glissé dans l'en-tête de la section « Contacts préférés » entrait
en concurrence avec le raccourci « +N › » et sortait du rythme visuel de l'écran.
Il devient une **ligne de menu standard** dans la carte du profil, en 2ᵉ position
après « Mon compte » (§5.6). Les autres points d'entrée sont inchangés : la puce
« Gérer » de l'écran Contacts préférés reste le chemin court.

### 10.2 Ajouter des membres dès la création

Il fallait créer la liste, la rouvrir, puis ajouter les membres. La feuille de
sélection a été **extraite** dans `add_list_members_sheet.dart` (§5.4) et est
maintenant appelée aussi depuis l'éditeur de création : le brouillon transporte
`memberIds`, et `createContactList` crée puis peuple en une seule action. Ajout
et retrait après coup restent évidemment possibles depuis l'écran détail.

### 10.3 Retrait des favoris ⇒ retrait de toutes les listes

Un contact retiré des favoris restait membre des listes où il figurait —
incohérent, puisque être un favori est le prérequis pour y appartenir. Corrigé
**des deux côtés** :

- **serveur** : `removePreferredContact` purge `contact_list_member` pour mes
  listes (§3.5) — la règle tient donc quel que soit le client ;
- **client** : `LocalCacheRepository.removePreferredContact` devient le point
  d'entrée unique des cinq écrans concernés et purge le cache local (§4.4), ce
  qui rafraîchit immédiatement, via les streams Drift, les membres affichés et
  les compteurs des puces.

---

## 11. Conformité au dossier de conception

Relecture point par point du dossier `docs/architecture/liste-contacts.tex`
(« Étape 2 — Listes de contacts »), qui remplace le plan d'origine.

### 11.1 Ce qui a été corrigé pour s'y conformer

| § du dossier | Consigne | Correction apportée |
|---|---|---|
| §2.2 | « Chaque contact affiche les puces des listes auxquelles il appartient » | Puces `_ListBadge` sous chaque contact, alimentées par le nouveau flux `watchListsByMember()` |
| §2.3 | Bouton flottant « Nouvelle liste » | Libellé du FAB corrigé (clé `newList`) ; l'éditeur garde « Créer une liste » comme titre |
| §2.3 | Rappel des règles sous la liste | Note ajoutée sous la dernière tuile (clé `contactListsHint`) |
| §2.4 | « Les membres, **plus les autres favoris en grisé avec une case à cocher** : ajouter et retirer se font au même endroit, sans écran intermédiaire » | Écran détail **entièrement refait** : liste unique membres + non-membres, bascule au clic. La feuille de sélection ne sert plus qu'à la création |
| §2.4 | Sous-titres « En ligne » / « Vu à 12:04 » / « Favori — pas dans cette liste » | Présence réelle pour les membres, mention dédiée pour les non-membres (clé `notInThisList`) |
| §2.4 | Bouton « Créer un groupe **« Famille »** » | Libellé paramétré par le nom de la liste (clé `createGroupNamed`) |
| §4.1, §7.1 | Ajout d'un non-favori → **403** | `addMember` renvoie 403 (et non 400) ; Swagger et recette alignés |
| §3.2, §7.3-1 | Retrait d'un favori : cascade applicative *ou* filtrage à la lecture ? | **Cascade applicative** retenue — celle que le dossier juge « plus propre » — serveur *et* cache (§3.5 et §4.4) |

### 11.2 Écarts assumés

| § | Consigne | Ce qui a été fait | Pourquoi |
|---|---|---|---|
| §3.1 | `migrations/024_contact_lists.sql` | **`038_contact_lists.sql`** | 024 → 037 étaient déjà pris dans le dépôt réel. Le contenu des deux tables est identique au listing 3.1 |
| §5.1 | Drift **v15 → v16** | **v19 → v20** | `schemaVersion` valait 19, pas 14 : le dossier a vieilli sur ce point. La montée reste en `onUpgrade`, sans recréation |
| §2.5-1 | Entrée « Listes de contacts » **à côté de** « Contacts préférés » dans l'en-tête | Ligne de menu dans la carte du profil, juste sous la grille des favoris | Demande explicite en recette : le bouton dans l'en-tête entrait en concurrence avec « +N › » (§10.1). Le point d'entrée « Profil → Listes de contacts » est conservé, seule sa forme change |

### 11.3 Ajouts hors dossier

- **Puce « Par QR »** dans la rangée de filtres : elle préexistait aux listes
  (fonctionnalité QR) ; les puces de listes s'ajoutent à côté et se composent
  avec elle.
- **Sélection des membres dès la création** (§10.2) : demandée en recette, le
  dossier ne décrivait que l'ajout après création.
- **Cascade du retrait des favoris côté cache local** : le dossier ne parle que
  du serveur ; sans le volet local, l'écran gardait des membres fantômes jusqu'à
  la prochaine synchro.

### 11.4 Points restés ouverts (§7.3 du dossier)

- **Limite du nombre de listes** : aucune limite posée. La rangée de puces défile
  horizontalement, donc elle ne casse pas, mais elle se lit mal au-delà d'une
  dizaine de listes.
- **Appel de groupe depuis une liste**, **diffusion de statut restreinte** :
  toujours hors périmètre, faisables sans toucher aux tables.
- **§6 — liste de contacts ≠ audience de diffusion** : arbitrage respecté par
  construction. `contact_list` n'a aucun moteur de critères et ne sert qu'à un
  utilisateur ; rien n'a été mutualisé avec la diffusion.
