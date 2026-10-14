# Recherche de messages dans une conversation

## Problème

La fiche d'un contact propose un bouton **« Rechercher »** qui n'affiche que « Recherche à venir » (`contact_detail_screen.dart`, `onSearch: () => _snack(context.l10n.searchComingSoon)`). Des membres du groupe 3GI 2029 l'ont pris pour une panne (bug A17 du rapport `bugs_3GI_2029.tex`). Aucune recherche dans le contenu des messages n'existe dans l'application : la barre de recherche de la liste ne filtre que les noms de conversation.

But : retrouver un message dans une conversation, à deux ou de groupe, comme sur WhatsApp. On tape un mot ; un compteur « 3/12 » s'affiche ; on passe d'un résultat à l'autre avec les flèches ; chaque résultat est amené à l'écran, mis en surbrillance, et le mot y est surligné.

## Décisions

| Sujet | Décision |
|---|---|
| Où l'on cherche | **Sur le téléphone uniquement**, dans la base locale (Drift). Aucun appel serveur, aucun coût d'infrastructure. C'est aussi la seule voie compatible avec le chiffrement de bout en bout : le serveur ne pourra plus lire le contenu. |
| Portée | **Une conversation à la fois**, à deux ou de groupe. La recherche globale, depuis la liste des discussions, est une étape ultérieure (voir *Évolutions*). |
| Contenu cherché | Texte des messages (`type 0`) et légendes des médias (`1` photo, `2` vidéo, `4` fichier). Exclus : messages supprimés, supprimés pour moi, vue unique, albums (`__talky_album__`), contenus JSON (`5` position, `6` événement de groupe, `7` contact, `9` trajet), vocaux et musique. |
| Accents et majuscules | Ignorés : « reunion » trouve « Réunion ». **Sans migration de la base** : la normalisation est faite en Dart (voir *Conception*). L'index plein texte FTS5 viendra plus tard, si le volume l'exige. |
| Longueur minimale | 2 caractères, après normalisation. En dessous, aucune recherche n'est lancée. |
| Ordre | Du plus récent au plus ancien. « 1/12 » est le plus récent ; la flèche ↑ remonte vers les plus anciens. |
| Points d'entrée | Bouton « Rechercher » de la fiche contact (A17) ; entrée « Rechercher » du menu de la barre du haut de la discussion, qui sert aussi pour les groupes. |
| Historique non chargé | On ne trouve que ce qui est en base locale. Quand la conversation a encore un historique plus ancien sur le serveur, la liste se termine par « Charger plus d'historique pour chercher plus loin ». |

## Conception

### Requête et normalisation

SQLite (`LIKE`) ne compare sans casse que l'ASCII, et ne sait rien des accents : « é » ne correspond pas à « e ». Plutôt qu'une colonne normalisée, qui demanderait une migration (schéma 26 → 27), la recherche se fait en deux temps :

1. **SQL** — `ChatDao.searchCandidates(convId, myId)` lit seulement `clientId`, `msgID`, `content`, `type` et `sendAt` des messages cherchables de la conversation, en appliquant les exclusions ci-dessus. On évite ainsi de charger les vignettes, les réactions et le reste.
2. **Dart** — `MessageSearch.filtrer(candidats, requete)` normalise le contenu et la requête (minuscules, accents retirés, apostrophes et espaces unifiés), et garde les messages qui contiennent la requête. Il renvoie les `msgID`, du plus récent au plus ancien.

Au-delà de 5 000 candidats, le filtrage passe dans un isolate (`compute`), pour ne pas geler l'écran. Une conversation de groupe très active atteint ce volume en quelques mois.

La normalisation est une table de correspondance écrite à la main (`à â ä → a`, `é è ê ë → e`, `ç → c`, `œ → oe`, etc.), sans dépendance. Le cas difficile : retirer un accent ne change pas la longueur des lettres simples, mais `œ → oe` l'allonge. La fonction tient donc une table qui ramène chaque position du texte normalisé à sa position dans le texte d'origine. Le surlignage en a besoin (voir plus bas).

### Écran de discussion

`ChatDetailScreen` gagne un **mode recherche**, et un paramètre `openSearch` pour l'ouvrir directement depuis un autre écran.

- **Barre du haut** : en mode recherche, le titre est remplacé par un champ (`autofocus`), suivi du compteur « 3/12 » et des flèches ↑ ↓. Le bouton retour quitte le mode recherche, pas la conversation.
- **Recherche à la frappe**, avec un anti-rebond de 250 ms. Une nouvelle frappe annule la recherche en cours.
- **Aller à un résultat** : on réutilise le saut vers un message existant. `_ensureMessageLoaded` charge l'historique plus ancien jusqu'au message, le défilement l'amène à l'écran, et `_highlightMessage` le met en surbrillance 2 s. C'est le même chemin que le saut vers les mentions (`_jumpToNextMention`).
- **Surlignage du mot** dans la bulle : **après** `parseRichSpans` (`_buildBubbleBody`, `chat_bubbles.dart`). Une fonction pure `surlignerSpans(spans, requete, style)` parcourt les `TextSpan` produits et découpe ceux dont le texte contient la requête normalisée, en gardant le style et le `recognizer` de chaque morceau (liens, mentions). On ne peut pas passer des positions calculées sur le texte brut, car `_parse` retire les marqueurs de mise en forme (`*gras*`, `_italique_`, `~barré~`) : le texte affiché n'a plus la même longueur. Une occurrence à cheval sur deux styles n'est surlignée que partiellement, ce qui est acceptable.
- **Aucun résultat** : le compteur affiche « 0 », et une ligne « Aucun message trouvé » apparaît sous la barre.
- La barre de saisie reste visible, et le brouillon (`ChatDraftStore`) n'est pas touché.

### Points d'entrée

| Depuis | Comportement |
|---|---|
| Menu de la barre du haut de la discussion | Nouvelle entrée « Rechercher » (à côté de « contact », « media », « translation ») → mode recherche. |
| Fiche contact, bouton « Rechercher » | Si la fiche a été ouverte depuis cette même discussion : on revient en arrière avec le résultat `'search'`, et la discussion passe en mode recherche. Sinon : on ouvre la discussion avec `openSearch: true`. |
| Infos du groupe | Pas de bouton « Rechercher » aujourd'hui. Les groupes passent par le menu de la discussion. |

## Fichiers

| Fichier | Rôle |
|---|---|
| `lib/core/utils/search_normalizer.dart` (nouveau) | Normalisation et table de positions vers le texte d'origine |
| `lib/core/services/chat/message_search.dart` (nouveau) | `MessageSearch.filtrer` (pur), passage en isolate, types de résultat |
| `lib/core/db/chat_dao.dart` | `searchCandidates(convId, myId)` |
| `lib/screens/chats/chat_detail_screen.dart` + `chat/chat_search.dart` (nouvelle partie) | Mode recherche, paramètre `openSearch`, navigation entre résultats |
| `lib/core/utils/search_highlight.dart` (nouveau), `chat/chat_bubbles.dart` | `surlignerSpans`, appliqué dans `_buildBubbleBody` quand la recherche est active |
| `lib/screens/chats/contact_detail_screen.dart` | Branchement du bouton « Rechercher » |
| `lib/l10n/app_{fr,en,zh}.arb` | `searchInConversation`, `searchNoResult`, `searchResultCounter`, `searchLoadMoreHistory`, `searchPrevious`, `searchNext` |
| `test/search_normalizer_test.dart`, `test/message_search_test.dart` (nouveaux) | Tests purs |

La clé `searchComingSoon` devient inutile : elle est retirée.

## Étapes

1. **Normalisation et filtre purs**, avec leurs tests. C'est le cœur de la fonctionnalité, testable sans écran.
2. **Requête DAO** `searchCandidates`, plus un test sur base Drift en mémoire (`ChatRepository.forTesting` / `AppDatabase` de test) : exclusions, conversation, `deletedForID`.
3. **Mode recherche** dans `ChatDetailScreen` : champ, compteur, flèches, saut vers les résultats.
4. **Surlignage** dans les bulles.
5. **Points d'entrée** : menu de la discussion, fiche contact ; retrait de `searchComingSoon`.
6. **Traductions**, puis vérification sur téléphone.

Chaque étape est commitée séparément. Les étapes 1 et 2 ne changent rien de visible.

## Tests

- **Normalisation** :
  - « Réunion » → « reunion » ;
  - « Œuvre » → « oeuvre », avec les positions d'origine ;
  - l'apostrophe typographique (’) correspond à l'apostrophe droite (') ;
  - les espaces insécables comptent comme des espaces.
- **Filtre** :
  - plusieurs occurrences dans un même message ;
  - requête trop courte (moins de 2 caractères) ;
  - les résultats sont triés du plus récent au plus ancien ;
  - les types exclus ne remontent jamais.
- **DAO** : les messages supprimés pour moi, ceux d'une autre conversation et ceux en vue unique sont absents.
- **Volume** : 20 000 candidats sont filtrés en moins de 300 ms en isolate, sur un profil desktop. On le mesure, et on note le résultat dans ce document.

## Vérification sur téléphone

- Chercher un mot accentué sans son accent, dans un groupe et dans une discussion à deux.
- Passer d'un résultat à l'autre jusqu'à un message ancien, pas encore chargé à l'ouverture : il doit être chargé, amené à l'écran et surligné.
- Ouvrir la recherche depuis la fiche contact, dans les deux cas (fiche ouverte depuis la discussion, ou depuis ailleurs).
- Vérifier qu'une légende de photo est trouvée, et qu'un vocal ou une position ne l'est jamais.

## Coût

Environ **1,5 à 2,5 jours** de développement, tests compris. Côté serveur : rien, et aucun coût d'infrastructure.

## Évolutions (hors de ce plan)

- **Recherche globale** depuis la liste des discussions : une section « Messages » sous les conversations trouvées, avec l'extrait, l'auteur et la date. Un appui ouvre la discussion sur le message (`ChatDetailScreen(focusMessageId: …)` existe déjà). Environ 1 à 1,5 jour, sur le même `MessageSearch`.
- **Index plein texte FTS5** : une table virtuelle alimentée par déclencheurs, avec le tokenizer `unicode61 remove_diacritics 2`, ce qui demande la migration du schéma 26 → 27. À envisager quand la recherche globale porte sur tous les messages du téléphone, ou si la mesure de volume ci-dessus dépasse le budget. Environ 1 jour.
- **Chiffrement de bout en bout** (branche `feat/chiffrement-e2e`) : la recherche reste possible à condition que le texte déchiffré soit gardé dans la base locale, ou dans une colonne dédiée à la recherche. À vérifier au moment de fusionner les deux chantiers. Les deux touchent `LocalMessages`, et l'index FTS5 devrait être ajouté **après** le chiffrement, pour ne faire qu'une migration.

## Implémenté

Branche `feat/recherche-messages` (partie de `fix/bugs-3gi`), cinq commits locaux.

**Fichiers créés**
- `lib/core/utils/search_normalizer.dart` : `normaliserPourRecherche`, `TexteNormalise` (texte + table `origine`).
- `lib/core/services/chat/message_search.dart` : `kSearchableMessageTypes` = {0, 1, 2, 4}, `kMinSearchQueryLength`, `CandidatRecherche`, `requeteValide`, `filtrerMessages`, `rechercherMessages` (isolate au-delà de 5 000).
- `lib/core/utils/search_highlight.dart` : `surlignerSpans`.
- `lib/screens/chats/chat/chat_search.dart` : mode recherche (partie de `chat_detail_screen.dart`).
- Tests : `search_normalizer_test`, `message_search_test`, `chat_dao_search_test`, `search_highlight_test` (26 tests).

**Fichiers modifiés** : `chat_dao.dart` (`searchCandidates`), `chat_detail_screen.dart` (état, `openSearch`, barre, `PopScope`, menu « ⋮ », deux ouvertures de la fiche), `chat/chat_bubbles.dart` (surlignage), `chat/chat_actions.dart` (la sélection quitte la recherche), `contact_detail_screen.dart` (`openedFromConversation`, `openSearch`), `app_{fr,en,zh}.arb` et `app_localizations*.dart`.

**Mesure de volume** : 20 000 candidats filtrés par `filtrerMessages` en **127 ms** (test sur le fil principal, machine de développement, sans isolate). Le budget de 300 ms est tenu, même sans isolate.

**Écarts par rapport au plan**
- Pas de ligne « Charger plus d'historique pour chercher plus loin » ni de clé `searchLoadMoreHistory` : le brief d'exécution l'écarte (un message absent de la base locale n'est jamais un résultat).
- La clé `searchInConversation` du plan s'appelle `searchInConversationHint`.
- `searchComingSoon` retirée des trois `.arb`.
- Seul le résultat courant est encadré (2 s, par `_scrollToReply`) ; tous les résultats visibles sont surlignés.

**Non vérifié** : tout ce qui demande un téléphone (saut vers un message ancien, rendu du surlignage, bouton retour en mode recherche, ouverture depuis la fiche contact).
