# Ajouter à l'appel — spécification d'implémentation

Transfert assisté sur appel 1-à-1 : un participant fait entrer un tiers, puis peut se retirer
en laissant les deux autres continuer.

- **Libellé utilisateur** : « Ajouter à l'appel ». **Nom technique** : transfert assisté.
- Conception visuelle et maquettes : voir l'artifact de conception associé.

## Règles

| Règle | Détail |
|---|---|
| Taille | 3 participants maximum. Ce n'est **pas** un appel de groupe. |
| Un seul ajout | Un appel donne droit à **un** ajout. Le premier des deux participants qui s'en sert le consomme définitivement. |
| Aucune coupure | La connexion entre les deux participants d'origine n'est ni fermée ni renégociée. |
| Pas de validation | L'autre participant est notifié, son accord n'est pas demandé. |
| Raccrocher = partir | Le bouton rouge ne retire que celui qui appuie. L'appel se termine quand il ne reste qu'une personne. |
| Blocage | Ajout refusé si un blocage existe entre l'invité et **l'un ou l'autre** des présents. Message neutre. |
| Historique | Une ligne `callHistory` par paire connectée, reliées par une colonne `sessionID`. |

## Le droit d'ajout

```
DISPONIBLE ──1er appui──> VERROUILLÉ ──invité entre──> CONSOMMÉ (définitif)
     ^                         │
     └──── échec / annulation ──┘
```

- `CONSOMMÉ` est définitif : le bouton ne réapparaît pas après un départ, ni quand il ne reste
  que deux personnes.
- Tout échec (refus, occupé, sans réponse, annulation) rend le droit à `DISPONIBLE`, **pour les
  deux participants**. Sans cela un simple refus condamnerait l'appel.

> **Le verrou est posé de façon synchrone, dès l'entrée du handler `call_add_participant`,
> avant tout `await`.** C'est ce qui arbitre deux appuis simultanés : la boucle Node étant
> mono-thread, le premier message traité gagne. Poser le verrou après une requête DB rouvre la
> fenêtre de course.

## Maillage WebRTC

Trois liens. Celui entre les deux participants d'origine est **conservé tel quel** et devient le
premier lien du maillage — d'où l'absence de coupure, et le fait qu'au départ du troisième les
deux autres n'ont rien à reconstruire.

Règle anti-collision d'offres : **les présents offrent, l'arrivant répond.** Les deux présents
émettent chacun une offre vers l'invité, qui répond aux deux.

Le transport média est repris sans modification : `group_offer`, `group_answer` et
`group_ice_candidate` sont de purs relais adressés par identifiant d'utilisateur
(`src/socket/handlers/calls.js:770-825`). **Aucun nouveau code média côté serveur.**

## Contrat d'événements

### Client → serveur

| Événement | Charge | Rôle |
|---|---|---|
| `call_add_participant` | `{ targetUserId, callerName?, callerPhoto? }` | Demande d'ajout. Pose le verrou. |
| `call_add_cancel` | `{}` | Annule l'invitation en cours. Réservé à son auteur. |
| `call_conf_join` | `{}` | L'invité accepte. |
| `call_conf_reject` | `{}` | L'invité refuse. |
| `end_call` *(étendu)* | `{ targetUserId?, mode? }` | Signifie « je pars » quand la session compte 3 participants. |

Les trois derniers ne portent aucune charge : le serveur retrouve la session par
l'identifiant de la socket authentifiée. C'est ce qui rend l'acceptation robuste
au démarrage à froid — un invité réveillé par notification n'a rien à mémoriser.

### Serveur → client

| Événement | Destinataire | Charge | Rôle |
|---|---|---|---|
| `call_add_pending` | les 2 présents | `{ sessionId, callId, invitee, byUserId }` | Affiche la tuile en sonnerie, éteint le bouton. |
| `call_conf_invite` | invité | `{ sessionId, callId, from, peers, isVideo }` | Fait sonner. Doublé d'un FCM. |
| `call_conf_joined` | présents | `{ sessionId, user }` | Déclenche l'offre de chaque présent vers l'invité. |
| `call_conf_peers` | invité | `{ sessionId, isVideo, peers }` | Liste qui va lui offrir. |
| `call_conf_failed` | présents | `{ sessionId, userId, reason }` | Retire la tuile, rend le droit. `reason` : `declined` \| `busy` \| `offline` \| `no_answer` \| `cancelled`. |
| `call_conf_left` | restants | `{ sessionId, userId, remaining }` | Un participant s'est retiré. `remaining` permet de repasser à l'affichage à deux. |
| `call_add_rejected` | demandeur | `{ code }` | `ADD_ALREADY_USED` \| `TARGET_BUSY` \| `TARGET_BLOCKED` \| `NOT_IN_CALL` \| `TARGET_SELF` \| `TARGET_ALREADY_IN_CALL` \| `INVALID` \| `INTERNAL`. |

Expiration de l'invitation : **45 s**, aligné sur `NO_ANSWER_MS` existant.

## Reprises dans l'existant

Le code des appels suppose partout exactement deux participants. C'est là qu'est le travail.

1. **`src/socket/state/callState.js`** — le registre associe à chaque utilisateur un unique
   `peerId`. Lui adjoindre la notion de session (présents, invité en attente, état du droit)
   tout en gardant `peerId` renseigné pour ne pas casser les chemins actuels.
2. **`endActiveCallForUser` (`calls.js:182`)** — la déconnexion termine l'appel des deux côtés.
   À trois, doit devenir « retirer ce participant ». Le délai de grâce de reconnexion existant
   s'applique inchangé.
3. **Marquage occupé** — les appels de groupe actuels n'inscrivent pas leurs participants au
   registre d'état : on peut recevoir un appel en pleine réunion. **Ne pas hériter de ce défaut** :
   les 3 participants doivent être marqués `in_call`, sinon un 4ᵉ appelant fait sonner quelqu'un
   qui parle déjà.
4. **Blocage** — `isBlockedEitherWay` n'est appelé que dans `call_user` (`calls.js:277`), pas dans
   le chemin groupe. L'ajout doit le refaire sur **les deux paires** : invité↔invitant et
   invité↔autre participant.
5. **`callHistory`** — table binaire (`idCaller`, `idReceiver`). Ajouter `sessionID` nullable,
   écrire une ligne par paire connectée. Migration additive et rétrocompatible : les lignes
   existantes gardent `sessionID = NULL`.

### Fichiers Flutter concernés

- `lib/core/services/call_service.dart` — état de session, droit d'ajout.
- `lib/core/services/call/call_signaling.dart` — nouveaux listeners.
- `lib/core/services/call/call_one_to_one.dart` — versement de la connexion existante dans le maillage.
- `lib/core/services/call/call_group.dart` — réutilisation du maillage, règle d'offre.
- `lib/widgets/calls/call_control_bar.dart` — bouton `person_add_alt_1`.
- `lib/screens/calls/ongoing_call_screen.dart` — grille à 3, retour à l'affichage 1-1.
- `lib/screens/calls/select_contact_screen.dart` — feuille de sélection unique.
- `lib/screens/calls/incoming_call_screen.dart` — motif de l'invitation.

## Interface

**Le bouton** (`person_add_alt_1`, entre haut-parleur et bouton rouge) apparaît si et seulement si :
l'appel est `connected`, il compte exactement 2 participants, et le droit est `DISPONIBLE`.
Sinon il est **absent**, pas grisé — un bouton grisé invite à demander pourquoi, et il n'y a pas
d'action de rattrapage à proposer. Sa place dans la barre est fixe : le bouton rouge ne doit pas
se déplacer sous le doigt.

**La feuille de sélection** : modale ~60 % de hauteur par-dessus l'appel qui reste actif.
Sélection unique, un appui lance l'invitation et referme. Soi-même et l'autre participant exclus ;
les contacts en appel restent visibles, annotés « en appel » — l'état peut changer entre
l'affichage et l'appui, c'est le serveur qui tranche.

**La grille** apparaît à 3 (audio comme vidéo). La tuile de l'invité préexiste à sa réponse :
bordure pointillée ambre, avatar désaturé, « Sonnerie… », annulable par son auteur seul.
Retour à l'affichage plein écran à deux quand on retombe à 2.

**Bandeaux** (4 s, haut de l'écran) :

| Situation | Chez l'invitant | Chez l'autre |
|---|---|---|
| Invitation lancée | Nadia est en train d'être ajoutée | Chris ajoute Nadia |
| Invité entré | Nadia a rejoint l'appel | idem |
| Refus | Nadia a refusé de rejoindre | Nadia n'a pas rejoint l'appel |
| Occupé | Nadia est déjà en appel | Nadia n'a pas rejoint l'appel |
| Sans réponse | Nadia n'a pas répondu | Nadia n'a pas rejoint l'appel |
| Course perdue | Awa vient d'ajouter quelqu'un | — |
| Départ | Chris a quitté l'appel | idem |

L'autre participant reçoit une version neutre des échecs : il n'a pas lancé l'invitation.

**Côté invité** : écran d'appel entrant standard, sous-titre « vous ajoute à un appel avec Awa ».
Même charge FCM qu'un appel ordinaire, augmentée de l'identifiant de session et des présents —
la couche native Android n'a rien à apprendre, seul le libellé change. L'invité n'a aucun droit
particulier : il ne peut pas ajouter, il peut partir.

## Cas limites

| Situation | Comportement |
|---|---|
| Appuis simultanés | Le premier message traité gagne. L'autre reçoit `ADD_ALREADY_USED`. |
| Invité déjà en appel | Refus immédiat, droit rendu, aucune sonnerie. |
| Invité app fermée | FCM + CallKit, comme un appel entrant ordinaire. |
| Invité ne répond pas | Expiration 45 s, tuile retirée, droit rendu. |
| Invité refuse / invitant annule | Tuile retirée, droit rendu. |
| L'autre raccroche pendant la sonnerie | L'invitation tient. Si l'invité accepte → appel à 2 avec l'invitant. Droit reste consommé. |
| L'invitant raccroche pendant la sonnerie | Invitation annulée, appel terminé. |
| Perte réseau à 3 | Délai de grâce habituel. Les deux autres continuent. |
| Blocage invité ↔ un présent | Refus avant toute sonnerie, quel que soit le sens et la paire. |
| Un 4ᵉ appelle l'un des 3 | Occupé — à condition d'avoir corrigé le marquage d'état (point 3). |
| Il ne reste qu'une personne | L'appel se termine automatiquement. |
| Appel vidéo à 3 | Autorisé (limite vidéo de l'app : 4). |

## Ordre d'implémentation

| Lot | Contenu | Vérification |
|---|---|---|
| **L1** | Socle serveur : session à 3 dans `callState`, droit d'ajout + verrou, `end_call` étendu, déconnexion corrigée. | Un appel à 2 se comporte exactement comme avant. |
| **L2** | Signalisation : nouveaux événements, blocage 2 paires, occupé, expiration 45 s, FCM/CallKit invité. | L'invité sonne et entre, sans interface dédiée. |
| **L3** | Maillage Flutter : versement de la connexion existante, règle d'offre, roster à 3, départ. | 3 personnes s'entendent ; le départ de l'une n'interrompt pas les autres. |
| **L4** | Interface : bouton, feuille, grille, tuile en sonnerie, bandeaux, retour à 2. | Parcours complet. |
| **L5** | Historique : migration `sessionID`, écriture par paire, regroupement. | Chacun des 3 retrouve l'appel dans son journal. |

## État d'avancement

Les cinq lots sont implémentés (03/08/2026).

- La branche backend `Alfred` a été remise à niveau sur `main` par avance rapide
  (`3fa8196` → `6f08289`) : elle n'avait aucun commit en propre. La migration porte
  donc le numéro **`036_call_session.sql`**. Le frontend, lui, était déjà à jour.
- **Vérifié** : tests unitaires backend (`callSessions.test.js`, `callSessionLeave.test.js`)
  et non-régression (`callBusyReclaim.test.js`) au vert ; `flutter analyze` sans erreur
  ni avertissement nouveau.
- **Non vérifié** : aucun essai de bout en bout avec trois appareils réels. La migration
  `036` n'a pas été appliquée. Le maillage à trois, la sonnerie de l'invité et le
  démarrage à froid par notification restent à éprouver sur le terrain.

### Fichiers ajoutés

- `backend/src/socket/state/callSessions.js` — sessions et droit d'ajout (+ tests)
- `backend/src/socket/handlers/callSessionLeave.test.js` — départs et solde d'invitation
- `backend/migrations/036_call_session.sql`
- `frontend/lib/core/services/call/call_conference.dart` — bascule 1-à-1 → maillage
- `frontend/lib/widgets/calls/add_to_call_sheet.dart` — feuille de sélection
