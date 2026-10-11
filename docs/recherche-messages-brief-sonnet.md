# Brief d'exécution — recherche de messages dans une conversation

> Destinataire : un agent de code (Claude Sonnet 5.5, effort moyen), sans contexte préalable.
> Plan de conception : `docs/recherche-messages-plan.md`. **Lis-le en entier avant de commencer.** Ce brief dit COMMENT l'exécuter sans casser quoi que ce soit.

## 0. Mission

Ajouter à l'application Flutter Alanya une recherche de messages **dans une conversation** :
- un mode recherche dans l'écran de discussion, avec un compteur « 3/12 » et des flèches ↑ ↓ ;
- le saut vers chaque résultat, avec le mot surligné ;
- accents et majuscules ignorés ;
- branché sur le bouton « Rechercher » de la fiche contact, aujourd'hui factice (bug A17), et sur le menu « ⋮ » de la discussion.

Recherche **locale uniquement** (base Drift du téléphone). **Aucune modification serveur. Aucune migration de base.**

## 1. Règles absolues

1. **D'autres sessions travaillent en même temps** dans `/home/chris/Projets/Alanya/Alanya`, `Alanya-Backend` et leurs worktrees. N'y fais rien : pas de `checkout`, pas de `stash` nu, pas de `reset`. Ne tue **aucun** processus que tu n'as pas lancé.
2. Travaille **uniquement** dans ton worktree (étape 2.1). N'écris dans aucun autre dossier du projet.
3. **Ne pousse rien.** Ne fusionne rien. Commits locaux uniquement ; l'utilisateur relit et décide.
4. **N'exécute jamais un fichier `*.db.test.js`**, ni rien côté serveur. Tu n'as d'ailleurs rien à faire côté serveur.
5. **Pas de `flutter build apk`, ni de `./gradlew`** : le hook natif de `sqlite3` tente un téléchargement et se bloque sans fin sur cette machine. `flutter analyze` et `flutter test` suffisent.
6. N'ajoute **aucune dépendance** dans `pubspec.yaml`.
7. Si une consigne de ce brief contredit ce que tu lis dans le code, **arrête-toi et signale-le**. N'improvise pas un contournement.

## 2. Environnement

### 2.1 Worktree

La branche de départ est `fix/bugs-3gi`, qui contient des modifications récentes de `chat_detail_screen.dart` et `contact_detail_screen.dart`. Si elle est déjà fusionnée dans `origin/main`, pars de `origin/main`.

```bash
cd /home/chris/Projets/Alanya/Alanya
git fetch -q origin
git branch -r --contains fix/bugs-3gi | grep -q origin/main && BASE=origin/main || BASE=fix/bugs-3gi
git worktree add -b feat/recherche-messages ../Alanya-recherche "$BASE"
cd ../Alanya-recherche
```

### 2.2 Flutter (installé en snap) : pièges connus

- Lance chaque commande `flutter` **hors bac à sable** (`dangerouslyDisableSandbox: true` sur l'outil Bash) et **au premier plan**, avec un long délai (600 000 ms). En arrière-plan, ou dans le bac à sable, elle sort en code 255 sans message.
- **Ne redirige jamais** sa sortie vers un fichier (`> x.log`) : elle sort en 255 sans rien écrire. Passe par un tube : `flutter test … 2>&1 | tail -20`.
- **Une seule commande `flutter` à la fois.** Deux `flutter test` simultanés se disputent un verrou et plantent sur `TimeoutException`.
- Premier lancement dans le worktree : `flutter pub get 2>&1 | tail -3`.
- Après toute modification d'un `.arb` : `flutter gen-l10n 2>&1 | tail -3`, puis commite les `app_localizations*.dart` régénérés.

### 2.3 Suite de tests de référence

Sur `main`, **16 tests échouent déjà** : `alanya_phone_formatter_test`, `chat_dao_test` (`bumpMyMessagesStatus`), `forward_message_test`, et d'autres. Ce n'est pas ton problème. Ton critère est le suivant : **aucun échec nouveau**. Avant toute modification, relève la liste de référence :

```bash
flutter test -r expanded 2>&1 | grep -E "\[E\]$" | sed -E 's#^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: ##; s#^.*/test/##' | sort -u > /tmp/echecs_avant.txt
wc -l /tmp/echecs_avant.txt
```

## 3. Conventions du code (à imiter)

- **Commentaires en français**, qui expliquent **pourquoi**, jamais ce que fait la ligne. Regarde `lib/core/services/translation/translatable_content.dart` : c'est le ton et la densité attendus.
- **Fonctions pures** pour la logique (testables sans écran ni base), séparées de l'UI.
- L'écran de discussion est découpé en `part` : `chat_detail_screen.dart` (l'état) et `chat/*.dart` (`extension _X on _ChatDetailScreenState`). Les états s'y modifient avec `rebuild(() => …)`, et `setState` dans le fichier principal.
- Thème : `context.colors`, `context.text`, `context.semantic`, `context.l10n`. Espacements : `AppSpacing.*` (`lib/core/theme/app_dimens.dart`). **Aucune couleur en dur.**
- Tests : `test/<nom>_test.dart`, `package:talky_flutter/...`, avec un en-tête en commentaire qui dit ce qu'on protège (voir `test/biometric_relock_test.dart`).
- Commits en français, format `type(portée): résumé`, avec un corps qui explique ; chaque message finit par :
  ```
  Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
  ```

## 4. Ce qui existe déjà (réutilise-le, ne le réécris pas)

| Besoin | Existant | Où |
|---|---|---|
| Liste blanche des types qui contiennent de la prose | `kTranslatableMessageTypes`, `translatableTextOf` (modèle à imiter, sans le seuil de 15 caractères) | `lib/core/services/translation/translatable_content.dart` |
| Marqueur d'album à exclure | `albumMarkerPrefix` | `lib/core/utils/media_album.dart` |
| Aller à un message, même ancien | `_scrollToReply(msgID, silent: …, highlight: …)` : charge l'historique, défile, encadre 2 s | `lib/screens/chats/chat/chat_actions.dart` |
| Le même saut, utilisé pour les mentions | `_jumpToNextMention` (garde anti double appui `_mentionJumpInFlight`) | même fichier |
| Lecture des messages d'une conversation | `ChatDao.watchMessages(convId, myId)` (exclut `deletedForID == moi`) | `lib/core/db/chat_dao.dart` |
| Mise en forme du texte des bulles | `parseRichSpans(...)` → `List<InlineSpan>` | `lib/core/utils/rich_text_parser.dart` ; appelé dans `_buildBubbleBody` (`chat/chat_bubbles.dart`) |
| Menu « ⋮ » de la discussion | `PopupMenuButton<String>` avec les valeurs `'contact'`, `'media'`, `'translation'` | `_buildChatAppBar`, `chat_detail_screen.dart` |
| Ouverture de la discussion depuis la fiche contact | `_openChat()` pousse `ChatDetailScreen(...)` | `contact_detail_screen.dart` |
| Bouton factice à remplacer | `onSearch: () => _snack(context.l10n.searchComingSoon)` | `contact_detail_screen.dart` |
| Ouvrir la discussion sur un message | paramètre `focusMessageId` de `ChatDetailScreen` | `chat_detail_screen.dart` |

Colonnes utiles de `LocalMessages` (`lib/core/db/app_database.dart`) : `msgID` (0 tant que le serveur n'a pas confirmé), `conversationID`, `content`, `type`, `sendAt`, `isDeleted`, `deletedForID`, `isViewOnce`, `viewedAt`.

## 5. Étapes

Chaque étape se termine par :
- `flutter analyze` **sur les fichiers touchés**, sans aucune erreur ni avertissement nouveaux ;
- les tests de l'étape, qui passent ;
- **un commit**.

Ne passe pas à l'étape suivante tant que la précédente n'est pas verte.

### Étape 1 — Normalisation (pure)

Fichier `lib/core/utils/search_normalizer.dart` :

```dart
/// Texte normalisé + correspondance de chaque position vers le texte d'origine.
class TexteNormalise {
  final String texte;
  final List<int> origine; // origine[i] = index dans le texte source du caractère normalisé i
}
TexteNormalise normaliserPourRecherche(String source);
```

- Minuscules ; accents retirés (table écrite à la main, couvrant au moins à á â ä ã å, ç, è é ê ë, ì í î ï, ñ, ò ó ô ö õ, ù ú û ü, ý ÿ, en minuscules et en capitales).
- `œ → oe` et `æ → ae` : les **deux** caractères produits pointent vers la même position d'origine.
- Apostrophe typographique `’` et accent aigu isolé `´` → `'`.
- Espace insécable (U+00A0) et espace fine insécable (U+202F) → espace.
- Teste au minimum : « Réunion » → « reunion » ; « Œuvre » → « oeuvre », avec `origine` == [0,0,1,2,3,4] ; l'apostrophe ; l'espace insécable ; une chaîne vide.

Commit : `feat(recherche): normalisation sans accents, positions conservées`.

### Étape 2 — Filtre (pur) et requête DAO

1. `lib/core/services/chat/message_search.dart` :
   - `const kSearchableMessageTypes = {0, 1, 2, 4};` — liste blanche **volontaire**, à commenter comme `kTranslatableMessageTypes`. Le type 3 (audio) est exclu : son contenu est un nom de fichier, pas de la prose.
   - `const kMinSearchQueryLength = 2;`
   - Un type léger `CandidatRecherche { int msgID; String content; DateTime sendAt; }`, pour ne pas faire transiter de `LocalMessage` vers un isolate.
   - `List<int> filtrerMessages(List<CandidatRecherche> candidats, String requete)` : normalise la requête, puis renvoie les `msgID` dont le contenu normalisé la contient, **du plus récent au plus ancien**. Liste vide si la requête normalisée et nettoyée des espaces fait moins de 2 caractères.
   - `Future<List<int>> rechercherMessages(List<CandidatRecherche> c, String requete)` : appelle `filtrerMessages` directement sous 5 000 candidats, et via `compute()` au-delà.
2. `ChatDao.searchCandidates(int conversationID, int myId)` dans `lib/core/db/chat_dao.dart` : une requête Drift qui ne garde que :
   - `conversationID` égal ;
   - `msgID > 0` ;
   - `isDeleted == false` ;
   - `deletedForID` nul ou différent de `myId` ;
   - `type` dans `kSearchableMessageTypes` ;
   - pas de vue unique non consultée (`isViewOnce == false OR viewedAt IS NOT NULL`, comme `translatableTextOf`) ;
   - `content` non nul.

   Exclus en Dart les contenus qui commencent par `albumMarkerPrefix`. Renvoie des `CandidatRecherche`.
3. Tests :
   - `test/message_search_test.dart` (pur) : tri, accents, plusieurs résultats, requête trop courte, requête faite d'espaces.
   - Pour le DAO, regarde comment `test/chat_dao_test.dart` construit sa base en mémoire (`AppDatabase.forTesting(NativeDatabase.memory())`), et ajoute un test qui vérifie chaque exclusion. Si ce fichier ne se compile pas, à cause des échecs préexistants, crée `test/chat_dao_search_test.dart` sur le même modèle.

Commit : `feat(recherche): filtre local des messages, accents ignorés`.

### Étape 3 — Mode recherche dans la discussion

Nouvelle partie `lib/screens/chats/chat/chat_search.dart` (`part of '../chat_detail_screen.dart';`), et dans `chat_detail_screen.dart` :

- Paramètre `final bool openSearch;` (défaut `false`) dans `ChatDetailScreen`. Quand il vaut vrai, on entre en mode recherche dès que `_convId` est connu, c'est-à-dire dans `_attachToConversation`, après la restauration du brouillon.
- **État** :
  - `bool _searchMode` ;
  - `TextEditingController _searchController` et `FocusNode _searchFocus`, tous deux libérés dans `dispose` ;
  - `List<int> _searchResults` ;
  - `int _searchIndex` ;
  - `Timer? _searchDebounce` ;
  - un jeton de requête (`int _searchToken`), pour ignorer le résultat d'une recherche dépassée.
- **Barre du haut** : quand `_searchMode` est vrai, `appBar` reçoit un `_buildSearchAppBar()`, à brancher comme `_selectionMode` le fait (`appBar: _selectionMode ? … : …`). Elle contient :
  - un `leading` « retour », qui sort du mode recherche ;
  - un `TextField` en `autofocus`, avec `textInputAction: TextInputAction.search` ;
  - le compteur `« {index}/{total} »` (« 0 » s'il n'y a rien) ;
  - deux `IconButton` ↑ (plus ancien) et ↓ (plus récent), désactivés aux extrémités, chacun avec son `tooltip` traduit.
- **Recherche** : anti-rebond de 250 ms sur la frappe, puis `ChatDao.searchCandidates`, puis `rechercherMessages`. Si le jeton a changé entre-temps, on ignore le résultat. Le premier résultat (le plus récent) est sélectionné et atteint automatiquement.
- **Aller à un résultat** : `_scrollToReply(msgID, silent: true)`, protégé contre un double appui comme `_jumpToNextMention` (`_searchJumpInFlight`).
- **Sortie du mode recherche** : on vide l'état, on retire le surlignage, on rend le focus à la barre de saisie. **Le bouton retour du système** doit d'abord sortir du mode recherche, sans quitter la discussion : utilise le `PopScope` qui existe déjà dans `build`, ne crée pas de deuxième `PopScope`.
- **Aucun résultat** : affiche « Aucun message trouvé » sous la barre, dans un bandeau discret, pas dans une SnackBar.
- La barre de saisie, le brouillon (`ChatDraftStore`) et la sélection de messages ne sont **pas** modifiés. Entrer en mode sélection quitte le mode recherche.

Commit : `feat(recherche): mode recherche dans la discussion`.

### Étape 4 — Surlignage

1. `lib/core/utils/search_highlight.dart`, une fonction pure :
   ```dart
   List<InlineSpan> surlignerSpans(List<InlineSpan> spans, String requete, TextStyle Function(TextStyle) surligne);
   ```
   Elle parcourt **récursivement** les `TextSpan` (`text` et `children`) ; dans chaque `text`, elle cherche la requête via `normaliserPourRecherche` et sa table `origine`, et découpe en morceaux.
   - Chaque morceau garde **le `style` et le `recognizer` du span d'origine** : un lien ou une mention restent cliquables.
   - Les `WidgetSpan` sont renvoyés tels quels.

   **Pourquoi après coup :** `_parse` retire les marqueurs `*gras*`, `_italique_` et `~barré~`. Des positions calculées sur le texte brut seraient donc fausses dans le texte affiché.
2. Dans `_buildBubbleBody` (`chat/chat_bubbles.dart`) : si `_searchMode` est vrai et que la requête est valide, applique `surlignerSpans` aux `spans`, **avant** de construire le `Text.rich`. Style du surlignage : fond `context.colors.primaryContainer`, texte `context.colors.onPrimaryContainer`, `FontWeight.w700`. Toutes les bulles visibles sont surlignées, pas seulement le résultat courant ; le résultat courant a déjà l'encadré de `_scrollToReply`.
3. Tests (`test/search_highlight_test.dart`) :
   - une occurrence au milieu d'un texte ;
   - deux occurrences ;
   - une occurrence accentuée (« reunion » trouve « Réunion ») ;
   - un span avec `recognizer` conservé après découpe ;
   - un `WidgetSpan` intact ;
   - une requête absente, qui renvoie les mêmes spans.

Commit : `feat(recherche): mot recherché surligné dans les bulles`.

### Étape 5 — Points d'entrée (corrige A17)

1. **Menu « ⋮ »** de `_buildChatAppBar` : nouvelle entrée `'search'`, avec l'icône `Icons.search` et le libellé `context.l10n.commonSearch` (qui existe déjà). Place-la **en premier**. Elle sert aux discussions à deux comme aux groupes.
2. **Fiche contact** (`contact_detail_screen.dart`) :
   - ajoute le paramètre `final bool openedFromConversation;` (défaut `false`) ;
   - `onSearch` : si `openedFromConversation` est vrai, `Navigator.pop(context, 'search')` ; sinon, ouvre la discussion comme `_openChat()`, mais avec `openSearch: true`. Factorise plutôt que de dupliquer `_openChat`.
3. Dans `chat_detail_screen.dart`, les **deux** endroits qui ouvrent `ContactDetailScreen` pour l'interlocuteur (le tap sur l'en-tête de `_buildChatAppBar`, et le cas `'contact'` du menu) passent `openedFromConversation: true`, attendent le résultat (`await Navigator.push<String>`) et, s'il vaut `'search'`, entrent en mode recherche. Ne touche pas aux ouvertures depuis `chat_bubbles.dart` (mention d'un autre membre) : ce n'est pas cette conversation.
4. Retire la clé `searchComingSoon` des trois `.arb` si elle n'est plus utilisée nulle part : vérifie-le avec `grep -rn searchComingSoon lib`.

Commit : `fix(recherche): le bouton Rechercher de la fiche contact fonctionne (A17)`.

### Étape 6 — Traductions

Clés à ajouter dans `lib/l10n/app_fr.arb` (avec les métadonnées `@` et `placeholders` pour les nombres, sur le modèle de `selfChatTitle`), `app_en.arb` et `app_zh.arb` :

| Clé | fr | en | zh |
|---|---|---|---|
| `searchInConversationHint` | Rechercher dans la discussion | Search this chat | 在聊天中搜索 |
| `searchNoResult` | Aucun message trouvé | No messages found | 未找到消息 |
| `searchResultCounter` | {index}/{total} | {index}/{total} | {index}/{total} |
| `searchPrevious` | Résultat précédent | Previous result | 上一个结果 |
| `searchNext` | Résultat suivant | Next result | 下一个结果 |
| `searchExit` | Fermer la recherche | Close search | 关闭搜索 |

Puis `flutter gen-l10n`. Ajoute une clé seulement si un écran l'utilise vraiment. En pratique, fais cette étape en même temps que l'étape 3, dans le même commit, pour ne jamais commiter un écran qui ne compile pas.

### Étape 7 — Vérification finale

1. `flutter analyze` **sur tout `lib/` et `test/`**, puis compare avec `main` : aucune erreur, et aucun avertissement nouveau dans les fichiers que tu as touchés.
2. Suite complète, puis comparaison avec la liste de référence :
   ```bash
   flutter test -r expanded 2>&1 | grep -E "\[E\]$" | sed -E 's#^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: ##; s#^.*/test/##' | sort -u > /tmp/echecs_apres.txt
   comm -13 /tmp/echecs_avant.txt /tmp/echecs_apres.txt   # doit être VIDE
   ```
3. Mesure de volume : un test qui fabrique 20 000 `CandidatRecherche` et chronomètre `filtrerMessages`. Note la durée dans le compte rendu. Ne la mets pas en assertion stricte, la machine de test varie.
4. Mets à jour `docs/recherche-messages-plan.md` : ajoute une section « Implémenté » qui liste les fichiers, la mesure de volume et les écarts éventuels par rapport au plan.

## 6. Pièges connus

- `msgID == 0` : message pas encore confirmé par le serveur. `_scrollToReply` l'ignore, donc la requête DAO doit l'exclure.
- `watchMessages` est un `Stream` : pour la recherche, utilise une requête `get()` ponctuelle (`searchCandidates`), pas le flux.
- Le saut charge l'historique **plus ancien** page par page (`_ensureMessageLoaded`, au plus 50 pages). Un message absent de la base locale n'est jamais un résultat, donc il n'y a rien à charger pour la recherche elle-même.
- `_mentionRecognizers` collecte les recognizers pour les libérer. `surlignerSpans` **réutilise** ceux des spans d'origine et n'en crée pas : aucune fuite.
- Le compteur affiche la position **en partant du plus récent** : 1/12 est le plus récent, et la flèche ↑ va vers les plus anciens.
- Le compilateur Dart voit les `part` comme un seul fichier : un nom privé (`_x`) déclaré dans `chat_search.dart` est visible partout dans `chat_detail_screen.dart`. Choisis des noms qui ne collent à rien d'existant ; vérifie avec `grep -rn "_searchMode\|_searchResults" lib/screens/chats` avant de les créer.
- Ne modifie pas `parseRichSpans` ni `_parse`.

## 7. Compte rendu attendu (à la fin, en français)

1. La liste des commits (`git log --oneline <base>..HEAD`).
2. Les fichiers créés et modifiés.
3. Les résultats : `flutter analyze`, le nombre de tests ajoutés et passés, le contenu de `comm -13` (vide attendu), et la mesure de volume.
4. Ce qui reste **non vérifié** : tout ce qui demande un téléphone, en particulier le saut vers un message ancien, le surlignage visuel, et le bouton retour en mode recherche.
5. Tout écart par rapport à ce brief, et pourquoi.

Ne pousse pas. Ne fusionne pas. Laisse le worktree en place.
