# Rejoindre un appel & transfert — conception

Refonte de « Ajouter à l'appel » (livré le 03/08, jamais éprouvé sur trois appareils)
en trois couches, d'après la conception du collègue (`TRANSFERT_ET_APPEL_A_3.md`),
portée sur le socle Alanya.

Remplace [`ajout_a_l_appel.md`](ajout_a_l_appel.md) une fois livré.

---

## 1. Les trois couches

> **Transférer, c'est inviter — puis partir.** Une seule mécanique, un drapeau de
> différence. On n'implémente pas trois fonctionnalités : on implémente
> « rejoindre », puis on ajoute deux drapeaux.

| | Scénario | Ce qui change |
|---|---|---|
| **C1 — Rejoindre** | Awa parle à Chris. Chris fait entrer Nadia. **Ils sont trois.** Chacun peut partir sans couper les autres. | existe, à réparer |
| **C2 — Transférer** | Chris fait entrer Nadia **et s'éclipse** dès qu'elle est connectée. Awa et Nadia continuent. | drapeau `transfer` |
| **C3 — Transfert masqué** *(audio seul)* | Nadia voit **Awa** (nom, photo, numéro) + la mention « Chris vous transfère l'appel ». **Awa ne voit rien changer** : son écran affiche toujours Chris. Seul Chris sait. | drapeau `masked` |

**Pourquoi audio seulement** : en vidéo le visage de Nadia trahit le transfert
dans la seconde. Mentir au protocole pour rien ajoute du risque sans rien
protéger. `masked = transfer && !isVideo`, arbitré côté client **et** revérifié
côté serveur.

**Ce que le masquage implique, dit franchement** : Awa n'est pas informée du
changement d'interlocuteur ; son journal d'appels ne montrera pas Nadia (§ 6.6).
Nadia, elle, est informée par la mention `transferBy` — c'est l'agent qui a le
droit de savoir d'où vient l'appel, pas l'appelant qui a le droit de savoir qui
décroche. C'est le comportement d'un standard téléphonique, et c'est un choix
produit assumé, pas un effet de bord.

---

## 2. Décisions de conception

| Décision | Retenu | Pourquoi |
|---|---|---|
| **Socle** | On garde `callSessions` + `callState`, l'adressage par **userId**, le droit d'ajout, les vérifications de blocage, l'historique `sessionID`. | Le guide du collègue adresse par numéro de téléphone et n'a ni droit d'ajout, ni blocage, ni historique. Adopter son protocole littéralement nous ferait *perdre* du code déjà juste. On reprend ses **quatre pièges** et ses deux drapeaux, pas son adressage. |
| **Droit d'ajout** | **Rendu** dès qu'on redescend à deux. Le transfert en cascade est possible. | Un vrai standard transfère en chaîne. La règle « un ajout pour la vie de l'appel » interdisait à Nadia de re-transférer. |
| **Masquage** | Audio seul, **et** verrouille le droit d'ajout pour le reste de l'appel (seule exception au point précédent). | Si Nadia ajoutait quelqu'un après un transfert masqué, l'arrivant apparaîtrait sur l'écran d'Awa qui croit parler à Chris. Le mensonge ne tiendrait plus. |
| **Adressage média** | Inchangé : `group_offer` / `group_answer` / `group_ice_candidate`, relais purs par userId. | Rien à écrire côté serveur. |

**Un avantage structurel d'Alanya sur la conception du collègue, à ne pas gâcher :**
comme on adresse par `userId`, Nadia se connecte au **vrai** userId d'Awa. Il n'y
a donc **aucun `from` à réécrire** dans le relais de signalisation — le piège
n° 2 de son guide IVR (§ 6.5) ne nous concerne pas. La seule identité à cacher
est celle de **Chris**, et elle se cache en ne créant simplement jamais le lien
Chris↔Nadia.

**Un piège de son guide qui ne nous concerne pas non plus** : « le transféreur
reste en ligne et devient injoignable » après un redémarrage serveur. Chez nous
l'état d'appel vit **en mémoire** (`callState`), pas dans une colonne
`in_call` : un redémarrage remet tout le monde à zéro. Rien à faire.

---

## 3. Diagnostic — pourquoi l'existant échoue

Vérifié dans le code, pas déduit.

| # | Défaut | Où | Effet |
|---|---|---|---|
| **1** | L'invitation part en FCM via `notifyIncomingCall`, payload **identique à un appel normal**, sans marqueur de session. | `services/notificationService.js:523` | À froid, l'invité décroche par la notification → `acceptIncomingCallFromPush` déroule le chemin 1-à-1, arme `_armAwaitingOfferTimeout` et attend **30 s une offre qui n'arrivera jamais** (ici ce sont les présents qui offrent, *après* `call_conf_join`) → teardown, « Appel échoué ». **L'invité ne peut pas entrer depuis une notification.** C'est le piège n° 1 du guide, à la lettre. |
| **2** | `sendSocketEvent` **abandonne l'événement en silence** quand la socket n'est pas prête — le log dit « différé », rien ne l'est. Or `acceptConferenceInvite` émet `call_conf_join` directement. | [socket_api.dart:379](../lib/api/socket_api.dart) | À froid la socket n'est pas encore authentifiée : **le `call_conf_join` est perdu**. L'invité affiche « connecté » sans un son, et le serveur solde l'invitation 45 s plus tard. `end_call` a une file d'attente, le refus a un magasin persistant — **le join n'a rien**. C'est l'autre moitié du piège n° 1. |
| **3** | L'invitation n'est **pas bufferisée** dans `pendingCalls` (contrairement à `call_user`). | `handlers/calls.js` `addParticipant` | Invité hors-ligne ou en reconnexion → invitation perdue, aucun rejeu à l'authentification. |
| **4** | `pc.onConnectionState` retire le pair sur `Disconnected`, état **transitoire** en WebRTC. | [call_group.dart:286](../lib/core/services/call/call_group.dart) | Un micro-trou réseau éjecte définitivement un participant de l'appel à trois. |
| **5** | `_terminateCall()` déclenché pendant une session vivante. | [call_one_to_one.dart:334](../lib/core/services/call/call_one_to_one.dart) | Le commit `bf4c4b4` y a ajouté une **trace de pile de diagnostic** : la chasse au raccrochage intempestif était ouverte et non close. C'est le piège n° 4. |
| **6** | Les états micro/caméra passent par les salles socket `group_<roomId>`, que la session **ne rejoint jamais** (aucun `join_group_call` sur le chemin session). | `handlers/calls.js` `groupMuteState` | À trois, l'indicateur « micro coupé » d'un participant ne remonte pas. |

Aucun de ces six points n'est un détail : quatre touchent le chemin « app
fermée », qui est le seul chemin réel en production. Les défauts 1 et 2 se
cumulent — **même corrigé côté push, le join serait encore perdu côté socket.**

---

## 4. Couche 1 — Rejoindre, fiabilisé

### 4.1 Piège n° 1 — l'invitation doit emprunter le chemin de livraison d'un appel

Le guide fait sonner l'invité avec `call_user` + `groupAdd: true`, ce qui lui offre
gratuitement le push, la sonnerie native, CallKit et le démarrage à froid. On ne
peut pas le copier tel quel : chez nous `call_user` **transporte l'offre WebRTC**
(`if (!targetID || !offer) return`), et une invitation n'en a pas.

On copie donc son **intention**, pas sa lettre : l'invitation garde son
événement dédié, mais traverse exactement la même tuyauterie de livraison.

**Quatre branchements, tous obligatoires :**

1. **Bufferisation.** `pendingCalls.set(inviteeID, payload, { event: 'call_conf_invite' })`.
   Le rejeu à l'authentification (`handlers/auth.js:108`) émet aujourd'hui
   `incoming_call` en dur : il lira désormais le nom de l'événement dans
   l'entrée. Sa garde autoritaire (`callState` toujours `ringing` pour ce
   callId) fonctionne déjà, l'invité étant marqué `ringing` avec
   `callId = sessionId`.

2. **Le marqueur survit au push.** Le bloc de données FCM n'accepte que des
   **chaînes** — un booléen `true` y devient parfois `null`, c'est exactement là
   que le guide a vu le drapeau se perdre. D'où un champ textuel :

   ```js
   joinKind:   'session',          // '' | 'group' | 'session'
   sessionId:  String(sessionId),
   transferBy: String(nomDeB || ''),
   ```

   Il doit voyager de bout en bout : `notificationService` →
   `TalkyFirebaseMessagingService.kt` / `AppDelegate.swift` →
   `CallIncomingHelper.kt` → canal de méthode → `IncomingCallAction` →
   `acceptIncomingCallFromPush`. **`roomId` traverse déjà cette chaîne sur les
   deux plateformes** : `joinKind` suit le même fil, il n'y a pas de tuyau à
   creuser.

3. **Aucun événement d'appel ne part plus « à l'aveugle ».** `sendSocketEvent`
   jette en silence si la socket n'est pas prête (défaut n° 2). Tout le chemin
   session passe par un `_emitOrQueue` qui met en file et rejoue à
   `auth:verified` — le mécanisme existe déjà pour `end_call`
   (`_pendingEndCalls`), on l'étend. **Sans ce point, le n° 2 seul suffit à faire
   échouer chaque entrée à froid, même avec le reste parfait.**

4. **Au décrochage, l'invité émet `call_conf_join` — jamais `answer_call`.**

   ```dart
   if (action.joinKind == 'session') {
     _confSessionId = action.sessionId;
     _emitOrQueue(SocketEvents.callConfJoin, {});   // file si socket pas prête
     _armSessionJoinTimeout();                      // 20 s : les offres doivent arriver
     // et surtout : PAS de _armAwaitingOfferTimeout — aucune offre 1-à-1 ne viendra
   }
   ```

   **Défense en profondeur côté serveur** : si `answer_call` arrive d'un
   utilisateur qui est l'invité en attente d'une session, on le **réachemine**
   vers le chemin `call_conf_join` au lieu de l'exécuter. Un `answer_call` ne
   toucherait pas `callSessions` : l'invité ne serait jamais promu, le minuteur
   solderait l'invitation 45 s plus tard, et personne ne comprendrait pourquoi.
   Trois lignes qui suppriment toute une classe de bugs — y compris ceux d'un
   client qui n'aurait pas été mis à jour.

### 4.2 Piège n° 2 — qui offre à qui : **déjà correct, à préserver**

> Le nouveau venu n'initie jamais. Chaque présent lui envoie une offre ciblée.

C'est déjà la règle (`call_conf_joined` aux présents → `_createGroupPeerAndOffer`
/ `call_conf_peers` à l'invité → il attend). **Ne rien y toucher.** On l'inscrit
ici pour que la couche 3 ne la casse pas par inadvertance.

### 4.3 Quitter ≠ raccrocher

Le serveur fait déjà la bonne chose (`end_call` → `leaveCallSession` en sortie
anticipée). Mais le client envoie un `end_call { targetUserId }` dont la cible
n'a plus de sens à trois. On ajoute **`call_leave {}`**, sans charge utile — le
serveur retrouve la session par la socket authentifiée. `end_call` conserve son
aiguillage actuel en repli pour les clients non mis à jour.

### 4.4 Piège n° 4 — les compteurs qui raccrochent

Trois sources distinctes, trois parades :

| Source | Parade |
|---|---|
| `pc.onConnectionState == Disconnected` retire le pair (défaut n° 4) | `Disconnected` **arme une grâce de 8 s** au lieu de retirer ; annulée si l'état repasse `Connected`. Seuls `Failed` et `Closed` retirent immédiatement. |
| `_terminateCall()` appelé pendant une session | Entonnoir unique : `_terminateCall` **refuse de s'exécuter** tant que `_confSessionId != null` **et** qu'il reste au moins un pair connecté — il retire ce pair-là. La trace de pile de `bf4c4b4` devient un `assert` : elle ne doit plus jamais se déclencher. |
| Le compteur ignore le pair masqué (couche 3) | `_maskedActivePeer`, § 6.7. |

> **La leçon du guide, et elle vaut bien au-delà du transfert :** quand on masque
> une identité, on relit **tous les garde-fous qui comptent les participants**.
> Un compteur qui ignore le pair masqué prend une situation normale pour une
> panne. Le masquage n'est pas une couche d'affichage : il traverse la pile.

### 4.5 Le droit d'ajout, redéfini

```
        ┌──────────────── invitation soldée (refus/occupé/timeout/annulation)
        │                                                    │
        ▼                                                    │
   DISPONIBLE ──appui──▶ EN VOL ──l'invité entre──▶ PLEIN (3) ┘
        ▲                                              │
        └──────────── quelqu'un part, on retombe à 2 ───┘
```

Le droit n'est plus « consommé définitivement ». Il est **disponible** si et
seulement si :

```
in_call  ET  aucune invitation en vol sur ma session
         ET  participants < 3
         ET  la session n'est pas marquée `masked`
```

Conséquence sur `callSessions.js` : `openWithPending` doit pouvoir **greffer**
une invitation sur une session existante à deux, pas seulement en créer une. Le
verrou reste posé **de façon synchrone, avant tout `await`** — c'est ce qui
arbitre deux appuis simultanés, et c'est la propriété la plus fragile du
fichier : la boucle Node étant mono-thread, le premier message traité gagne.
Poser le verrou après une requête base rouvre la course.

Le client calcule l'affichage du bouton, le serveur tranche (`ADD_ALREADY_USED`).

---

## 5. Couche 2 — Le transfert

Tout est en place. Il reste un drapeau et une question de synchronisation.

**À l'invitation** — `call_add_participant { targetUserId, transfer: true }` →
le serveur mémorise, **dans le verrou synchrone** :

```js
session.transfer = { by: requesterID, target: inviteeID, masked: false };
```

**Quand partir ?** Le guide fait partir Chris dès que la cible *rejoint*. C'est un
peu tôt : entre le `join` et le premier paquet audio, Awa entend un trou. On
attend que Nadia soit **réellement connectée** :

```
Nadia émet call_conf_join
   → les présents lui offrent
   → dès que MA connexion vers Nadia passe `connected`, j'émets :
        call_conf_ready { peerId: <Nadia> }
   → le serveur constate qu'un présent QUI RESTE est connecté à la cible
   → il exécute le départ de Chris
```

Le déclencheur est le `ready` de **celui qui reste** (Awa), jamais celui de Chris
— en masqué Chris n'a aucun lien avec Nadia, et un seul chemin vaut mieux que
deux.

**Le filet.** Si Awa est hors-ligne, ou son `ready` perdu, le transfert resterait
éternellement à trois. Un minuteur serveur de **15 s** armé à la promotion de
l'invité exécute le départ de toute façon. Symétriquement, si Chris est tué à cet
instant précis, le départ est de toute façon exécuté **côté serveur** — jamais
par le client de Chris. Un transfert ne doit pas dépendre de la survie de celui
qui transfère.

**Le départ lui-même** réutilise `leaveCallSession(by)` tel quel : historique
clos pour Chris, `callState` nettoyé, `call_conf_left` aux restants. Chris reçoit
`call_transfer_done { sessionId, to }`, affiche « Appel transféré à Nadia », et
ferme son écran.

**Si Nadia refuse / ne répond pas / est occupée** : chemin d'échec existant
inchangé (`call_conf_failed`), `session.transfer` effacé, Chris reste en ligne
avec Awa, droit rendu. Un transfert raté ne coûte pas l'appel.

**Verrou** : une seule invitation en vol par session (déjà acquis, § 4.5). Sans
lui, deux appuis rapides lancent deux appels pour une seule intention.

---

## 6. Couche 3 — Le transfert masqué

Le serveur ne cache rien à moitié : il raconte à chacun une histoire **complète
et cohérente**, et la maintient jusqu'au bout.

`session.transfer = { by: Chris, target: Nadia, masked: true }`, posé dans le
même verrou synchrone.

### 6.1 Mensonge n° 1 — l'identité présentée à Nadia

Sur `call_conf_invite` **et** sur le FCM, l'identité de l'appelant devient celle
d'Awa — le participant de la session qui n'est **pas** le transféreur :

```js
from        = carte(Awa)          // id, nom, photo : l'identité ENTIÈRE
transferBy  = nom(Chris)          // mention discrète, écran de Nadia SEULEMENT
```

`from.id` porte le **vrai userId d'Awa**, et c'est voulu : Nadia va réellement se
connecter à Awa. C'est ce qui nous dispense de toute réécriture d'identité dans
le relais de signalisation (§ 2).

### 6.2 Mensonge n° 2 — la liste envoyée à Nadia

`call_conf_peers` filtré : **Chris est retiré**. Nadia ne saura jamais qu'il était
là, et n'attendra donc pas d'offre de sa part.

### 6.3 Mensonge n° 3 — l'arrivée de Nadia, invisible pour Awa

Deux conséquences, dans cet ordre :

- **`call_add_pending` n'est PAS envoyé à Awa** (Chris seul le reçoit). Rien ne
  bouge sur son écran, aucune tuile « Sonnerie… », aucune bascule en grille.
- **`call_conf_joined` à Awa porte `masked: true`**. Son client crée la connexion
  vers Nadia et **s'arrête là** : pas d'ajout au roster, pas de bandeau, pas de
  grille.

```dart
if (masked) {
  _maskedActivePeer = userId;        // cf. § 6.7
  await _createGroupPeerAndOffer(userId);
  return;                            // et RIEN d'autre
}
```

Le maillage silencieux existe déjà : `_demoteMeshToOneToOne` maintient des
connexions dans `_groupPeerConnections` avec `_groupRoomId == null` (affichage à
deux), et `activeRemoteStream` sait déjà y puiser. Il suffit qu'il lise
`_maskedActivePeer` en priorité pendant que `_remoteUserId` reste Chris.

**Et Chris ?** Il reçoit `call_conf_joined` **sans** `masked`, mais avec
`offer: false` : en masqué il n'ouvre aucun lien vers Nadia — il s'apprête à
partir. C'est le seul écart avec la règle « les présents offrent » du § 4.2, et il
est explicite.

### 6.4 Mensonge n° 4 — le départ de Chris, invisible lui aussi

`call_conf_left { userId: Chris, masked: true }` chez Awa : elle ferme la
connexion, **n'affiche rien**, garde le nom de Chris à l'écran. Nadia, elle, ne
reçoit rien du tout : Chris n'a jamais existé pour elle.

**Les champs techniques comptent autant que l'écran.** Deux relais trahiraient
l'identité de Nadia si on les oubliait — ce sont précisément ceux que l'interface
n'affiche jamais :

- `group:mute_state` / `group:video_state` : l'`userId` émetteur doit être
  **réécrit Nadia → Chris** avant émission vers Awa. (Ces relais doivent de toute
  façon être refaits par userId plutôt que par salle socket — défaut n° 6.)
- `speakingDetector` : la connexion de Nadia doit être indexée sous la clé de
  Chris côté Awa, sinon l'indicateur « parle » ne s'allume jamais.

### 6.5 Mensonge n° 5 — le refus de Nadia va à Chris, pas à Awa

`call_conf_failed` n'est émis qu'à `session.transfer.by`. Awa ne reçoit rien —
elle n'a jamais su qu'une invitation existait. Et `session.transfer` est effacé :
transfert avorté, droit rendu à Chris.

### 6.6 Le sixième mensonge — le journal d'appels

**Absent de la conception du collègue, parce que son implémentation n'a pas
d'historique.** La nôtre en a un, et il fuite : `openSessionHistory` écrit une
ligne `callHistory` par paire connectée, et `finalizeCallAndNotify` notifie
**les deux** côtés. Sans traitement, Awa verrait apparaître « Appel avec Nadia »
dans son journal à la seconde où l'appel se termine — tout le masquage s'effondre
après coup.

Parade retenue, minimale : colonne `masked TINYINT DEFAULT 0` sur `callHistory`.
La ligne Awa↔Nadia est écrite avec `idCaller = Awa`, `idReceiver = Nadia`,
`masked = 1`, et :

- `finalizeCallAndNotify` ne notifie **pas** `idCaller` pour une ligne masquée ;
- la liste du journal exclut les lignes `masked = 1` **du côté `idCaller`**.

Chris garde sa ligne avec Awa, close à son départ, avec sa durée réelle. Nadia
voit un appel avec Awa — ce qu'elle croit, et ce qui est vrai. Awa voit un seul
appel, avec Chris, de bout en bout. Trois journaux cohérents, chacun avec sa
vérité.

### 6.7 Piège n° 4 — le raccrochage intempestif

> *« Le transfert marche, Nadia décroche… et une seconde plus tard tout
> raccroche. »*

Du point de vue d'Awa : son roster ne contient que Chris (Nadia a été ajoutée en
silence, hors liste) ; Chris s'en va, sa connexion tombe ; le compteur voit
« plus personne » et raccroche. Le mensonge n° 3, qui consistait justement à ne
pas afficher Nadia, se retourne contre nous.

```dart
/// Pair vers lequel l'audio a été SILENCIEUSEMENT rebranché lors d'un transfert
/// masqué. Tant qu'il tient, la perte de l'ANCIEN pair ne doit rien casser.
String? _maskedActivePeer;
```

Il court-circuite **les trois** garde-fous du § 4.4, pas seulement un :
`_guardOriginLinkFailure`, `pc.onConnectionState`, et l'entonnoir
`_terminateCall`. Un seul oubli suffit à reproduire le symptôme.

### 6.8 Fin du masquage

`session.transfer` est effacé dès le départ de Chris consommé, mais la session
garde **`masked: true` jusqu'à la fin de l'appel** : c'est ce qui verrouille le
droit d'ajout (§ 2) et empêche un ajout ultérieur de faire apparaître un inconnu
sur l'écran d'Awa.

---

## 7. Interface

### 7.1 Le bouton — un seul, deux actions

`person_add_alt_1`, en fin de rangée dans la barre de contrôle
(`call_control_bar.dart`, déjà en place). **On n'en ajoute pas un second** : la
barre porte déjà 2 à 4 boutons selon audio/vidéo, et surtout le bouton rouge ne
doit jamais se déplacer sous le doigt. Le choix ajouter/transférer se fait dans
la feuille, où il y a la place de l'expliquer.

Visible si et seulement si le droit est `DISPONIBLE` (§ 4.5). **Absent, jamais
grisé** : un bouton grisé invite à demander pourquoi, et « l'appel est déjà à
trois » n'a aucune action de rattrapage à proposer.

### 7.2 La feuille de sélection

Modale ~60 % de hauteur par-dessus l'appel, qui reste actif et audible derrière.
Un sélecteur de mode en tête, une ligne d'explication qui change avec lui, puis
la liste. Sélection unique, un appui lance l'action et referme.

```
┌────────────────────────────────────────┐
│              ▬▬▬                       │
│  Ajouter à l'appel                  ✕  │
│  ┌──────────────┬───────────────────┐  │
│  │   Ajouter    │    Transférer     │  │  ← « Ajouter » par défaut
│  └──────────────┴───────────────────┘  │
│  Vous resterez dans l'appel.           │  ← change avec le mode
│  ┌──────────────────────────────────┐  │
│  │ 🔍  Rechercher                   │  │
│  └──────────────────────────────────┘  │
│   ●  Nadia Mbala                       │
│   ●  Paul Ntsama                       │
│   ●  Awa Diallo          en appel      │  ← inerte, 40 % d'opacité
└────────────────────────────────────────┘
```

La ligne d'explication est le seul endroit où le masquage se dit, et elle règle
la question du transfert vidéo sans boîte de dialogue :

| Mode | Appel audio | Appel vidéo |
|---|---|---|
| **Ajouter** | « Vous resterez dans l'appel. » | idem |
| **Transférer** | « Vous quitterez l'appel dès que la personne décroche. Elle verra **Awa**, pas vous. » | « Vous quitterez l'appel dès que la personne décroche. **En vidéo, elle verra que le transfert vient de vous.** » |

Les contacts déjà présents restent **visibles mais inertes**, annotés « en
appel » : les masquer laisserait croire à une absence. L'état peut changer entre
l'affichage et l'appui — c'est le serveur qui tranche.

### 7.3 Pendant l'invitation

| | Chris (invitant/transféreur) | Awa (l'autre présent) | Nadia (cible) |
|---|---|---|---|
| **Ajouter** | tuile « Sonnerie… » dans la grille, **annulable** | même tuile, non annulable | écran d'appel entrant, sous-titre « Chris vous ajoute à un appel avec Awa » |
| **Transférer visible** (vidéo) | bandeau « Transfert vers Nadia… » + **Annuler** | tuile « Sonnerie… » | « Chris vous transfère l'appel avec Awa » |
| **Transférer masqué** (audio) | bandeau « Transfert vers Nadia… » + **Annuler** | **rien. Zéro pixel.** | identité d'**Awa** (nom, photo) + mention « Chris vous transfère l'appel » |

La tuile de l'invité **préexiste à sa réponse** : bordure pointillée ambre,
avatar désaturé, « Sonnerie… ». C'est le seul moyen de rendre l'attente lisible.
Annulable par son auteur seul.

### 7.4 Bandeaux (4 s, haut de l'écran)

| Situation | Chris | Awa | Awa si masqué |
|---|---|---|---|
| Nadia entre | « Nadia a rejoint l'appel » | idem | **rien** |
| Transfert consommé | « Appel transféré à Nadia » puis l'écran se ferme | « Chris a quitté l'appel » | **rien** |
| Nadia refuse | « Nadia a refusé de rejoindre » | « Nadia n'a pas rejoint l'appel » | **rien** |
| Nadia occupée | « Nadia est déjà en appel » | « Nadia n'a pas rejoint l'appel » | **rien** |
| Sans réponse | « Nadia n'a pas répondu » | « Nadia n'a pas rejoint l'appel » | **rien** |
| Course perdue | « Awa vient d'ajouter quelqu'un » | — | — |
| Départ ordinaire | « Chris a quitté l'appel » | idem | — |

Awa reçoit une version **neutre** des échecs : elle n'a pas lancé l'invitation,
la raison ne la regarde pas.

### 7.5 La grille

Apparaît à trois, audio comme vidéo. Retour à l'affichage plein écran à deux dès
qu'on retombe à deux — la connexion survivante n'est pas reconstruite, seul
l'affichage change (`_demoteMeshToOneToOne`, déjà écrit).

**En masqué, la grille n'apparaît jamais chez Awa.** C'est la contrainte de
conception la plus dure de tout le lot : son écran doit rester rigoureusement
identique, avant, pendant et après.

### 7.6 Le journal d'appels

Les lignes d'une session sont regroupées par `sessionID`. Les lignes `masked = 1`
sont **absentes du journal de `idCaller`** (§ 6.6). Aucun libellé « transféré »
n'apparaît nulle part côté Awa.

---

## 8. Contrat d'événements

### Client → Serveur

| Événement | Charge | Note |
|---|---|---|
| `call_add_participant` | `{ targetUserId, transfer?, masked?, callerName?, callerPhoto? }` | pose le verrou synchrone |
| `call_add_cancel` | `{}` | auteur de l'invitation seulement |
| `call_conf_join` | `{}` | **jamais `answer_call`**, et **jamais sans file d'attente** |
| `call_conf_reject` | `{}` | |
| `call_conf_ready` | `{ peerId }` | **nouveau** — « ma connexion vers l'arrivant est établie » |
| `call_leave` | `{}` | **nouveau** — je pars, les autres continuent |

Aucune charge sur quatre d'entre eux : le serveur retrouve la session par la
socket authentifiée. C'est ce qui rend l'acceptation robuste au démarrage à
froid — un invité réveillé par notification n'a rien à mémoriser.

### Serveur → Client

| Événement | Destinataire | Charge | Masqué |
|---|---|---|---|
| `call_add_pending` | présents | `{ sessionId, callId, invitee, byUserId, transfer }` | **au transféreur seul** |
| `call_conf_invite` | invité | `{ sessionId, callId, from, peers, isVideo, transferBy? }` | `from` = celui qui reste |
| `call_conf_joined` | présents | `{ sessionId, user, masked?, offer? }` | `masked` chez celui qui reste, `offer:false` chez le transféreur |
| `call_conf_peers` | invité | `{ sessionId, isVideo, peers }` | transféreur filtré |
| `call_conf_failed` | présents | `{ sessionId, userId, reason }` | **au transféreur seul** |
| `call_conf_left` | restants | `{ sessionId, userId, remaining, masked? }` | `masked` chez celui qui reste ; rien à l'arrivant |
| `call_transfer_done` | transféreur | `{ sessionId, to }` | **nouveau** |
| `call_add_rejected` | demandeur | `{ code }` | inchangé |

`reason` : `declined | busy | offline | no_answer | cancelled`.
Expiration de l'invitation : **45 s** (`NO_ANSWER_MS`, inchangé).

### FCM — invitation

Mêmes champs qu'un appel entrant, **plus** (chaînes uniquement) :
`joinKind: 'session'`, `sessionId`, `transferBy`.

---

## 9. Fichiers touchés

**Backend**

| Fichier | Travail |
|---|---|
| `state/callSessions.js` | droit rendu (§ 4.5), greffe sur session existante, `session.transfer`, marque `masked` |
| `state/pendingCalls.js` | nom d'événement stocké avec la charge |
| `handlers/auth.js` | rejeu générique (plus de `incoming_call` en dur) |
| `handlers/calls.js` | bufferisation de l'invitation, réacheminement `answer_call`, `call_conf_ready`, `call_leave`, exécution du transfert + filet 15 s, les six mensonges, relais mute/vidéo par userId |
| `services/notificationService.js` | `joinKind` / `sessionId` / `transferBy`, identité substituée en masqué |
| `migrations/039_call_masked.sql` | `callHistory.masked` |

**Natif** — `TalkyFirebaseMessagingService.kt`, `CallIncomingHelper.kt`,
`AppDelegate.swift` : `joinKind` suit le fil déjà tracé par `roomId`.

**Flutter**

| Fichier | Travail |
|---|---|
| `api/socket_api.dart` | `_emitOrQueue` / rejeu à `auth:verified` (défaut n° 2) |
| `call/call_incoming.dart` | branche `joinKind == 'session'` : `call_conf_join`, pas d'attente d'offre 1-à-1 |
| `call/call_conference.dart` | `transfer` / `masked`, `_maskedActivePeer`, `call_conf_ready`, maillage silencieux |
| `call/call_group.dart` | grâce de 8 s sur `Disconnected` |
| `call/call_one_to_one.dart` | entonnoir `_terminateCall`, `call_leave` |
| `call_service.dart` | `activeRemoteStream` lit `_maskedActivePeer`, `canAddParticipant` recalculé |
| `callkit_service.dart` | `joinKind` sur `IncomingCallAction` |
| `widgets/calls/add_to_call_sheet.dart` | sélecteur de mode + ligne d'explication (§ 7.2) |
| `widgets/calls/call_control_bar.dart` | inchangé (le bouton existe déjà) |
| `screens/calls/incoming_call_screen.dart` | mention `transferBy` |
| `screens/calls/ongoing_call_screen.dart` | bandeaux transfert |

---

## 10. Reste à faire, à vérifier, à tester

### 10.1 À vérifier AVANT d'écrire une ligne — bloquant

- [ ] **La migration `036_call_session.sql` a-t-elle été appliquée ?**
      `SHOW COLUMNS FROM callHistory LIKE 'sessionID'`. La doc du 03/08 dit
      explicitement que non. Sans cette colonne, `openSessionHistory` échoue en
      silence (try/catch + `console.warn`) : **aucune ligne d'historique n'est
      écrite et rien ne le signale**. Inutile de tester le journal avant.
- [ ] **Multi-appareil.** `emitToUser` diffuse à *toutes* les sockets du compte
      (`io.to('user_<id>')`). Si Nadia a deux appareils, les deux sonnent ;
      celui qui rejoint émet `call_conf_join`, l'autre doit être éteint. Regarder
      ce que fait déjà le chemin 1-à-1 (`pendingCalls.markDelivered`,
      `call_ended`) et s'aligner exactement dessus.
- [ ] **iOS.** Les champs personnalisés arrivent-ils dans la charge VoIP PushKit ?
      `roomId` y passe déjà (`AppDelegate.swift:196` et `:232`), donc le fil
      existe — reste à confirmer que l'envoi les inclut.
- [ ] **Web (`kIsWeb`).** Le chemin session court-circuite CallKit et le service
      de premier plan. Décider : parcours cohérent sur web, ou transfert réservé
      au mobile.
- [ ] **Limite vidéo.** `maxParticipants(isVideo)` autorise-t-il bien 3 en vidéo ?

### 10.2 À faire — Lot 1 : fiabiliser « rejoindre »

*Critère de sortie : Nadia, **app tuée**, décroche depuis la notification et
entre dans l'appel.*

**Backend**
- [ ] `pendingCalls.set` stocke le nom d'événement ; `auth.js` rejoue celui-là
- [ ] Bufferiser l'invitation dans `addParticipant`
- [ ] `notifyIncomingCall` : `joinKind` / `sessionId` / `transferBy` (chaînes)
- [ ] `answer_call` d'un invité en attente → réacheminé vers le chemin join
- [ ] `call_leave {}`
- [ ] Relais `group:mute_state` / `group:video_state` par userId pour les sessions (défaut n° 6)
- [ ] `callSessions` : droit rendu, greffe sur session existante (§ 4.5)
- [ ] Tests unitaires à mettre à jour : `callSessions.test.js`, `callSessionLeave.test.js`

**Natif**
- [ ] `joinKind` dans `TalkyFirebaseMessagingService.kt` + `CallIncomingHelper.kt`
- [ ] `joinKind` dans `AppDelegate.swift`

**Flutter**
- [ ] `_emitOrQueue` + rejeu à `auth:verified` (défaut n° 2) — **le plus important**
- [ ] `IncomingCallAction.joinKind`
- [ ] `acceptIncomingCallFromPush` : branche session, pas de `_armAwaitingOfferTimeout`
- [ ] `_armSessionJoinTimeout` (20 s)
- [ ] Grâce de 8 s sur `Disconnected` (défaut n° 4)
- [ ] Entonnoir `_terminateCall` + suppression de la trace de pile de `bf4c4b4`
- [ ] `canAddParticipant` recalculé (droit rendu)
- [ ] `call_leave` au lieu de `end_call` en session

### 10.3 À faire — Lot 2 : le transfert

*Critère de sortie : Chris transfère, disparaît seul, Awa n'entend pas de trou.*

- [ ] `transfer` sur `call_add_participant`, mémorisé dans le verrou synchrone
- [ ] `call_conf_ready { peerId }` — émission client dès `connected`
- [ ] Exécution serveur du départ + filet 15 s
- [ ] `call_transfer_done` → écran de Chris
- [ ] Échec d'invitation : `session.transfer` effacé, Chris reste
- [ ] Feuille : sélecteur de mode + ligne d'explication (§ 7.2)
- [ ] Bandeaux transfert (§ 7.4)

### 10.4 À faire — Lot 3 : le masqué

*Critère de sortie : le tableau du § 10.6, case par case, sur l'appareil concerné.*

- [ ] `masked = transfer && !isVideo`, revérifié serveur
- [ ] Mensonge 1 — identité d'Awa sur `call_conf_invite` **et** sur le FCM
- [ ] Mensonge 2 — Chris filtré de `call_conf_peers`
- [ ] Mensonge 3 — `call_add_pending` au transféreur seul ; `call_conf_joined` marqué `masked` / `offer:false`
- [ ] Mensonge 4 — `call_conf_left` marqué `masked` ; rien à Nadia
- [ ] Mensonge 4bis — `group:mute_state` / `group:video_state` réécrits Nadia → Chris
- [ ] Mensonge 4ter — `speakingDetector` indexé sous la clé de Chris
- [ ] Mensonge 5 — `call_conf_failed` au transféreur seul
- [ ] Mensonge 6 — migration `callHistory.masked` + filtrage du journal (§ 6.6)
- [ ] `_maskedActivePeer` + les **trois** garde-fous (§ 6.7)
- [ ] `activeRemoteStream` lit `_maskedActivePeer`
- [ ] Droit d'ajout verrouillé pour le reste de l'appel (§ 6.8)
- [ ] Mention `transferBy` sur l'écran entrant de Nadia

### 10.5 À tester — trois appareils réels

C'est ce qui a manqué la première fois. Chaque ligne est un essai distinct.

**Lot 1**
- [ ] Nadia **app tuée** : décroche depuis la notification → entre et parle
- [ ] Nadia **app en arrière-plan** : idem
- [ ] Nadia **app ouverte** : idem
- [ ] Les trois s'entendent mutuellement (vérifier les 3 liens, pas 2)
- [ ] Coupure réseau de 5 s chez l'un : personne n'est éjecté, ça reprend
- [ ] Un départ ne coupe pas les deux autres ; retour à l'affichage à deux
- [ ] Retombé à deux, le bouton « ajouter » **revient**
- [ ] Micro coupé par l'un : les deux autres voient l'indicateur (défaut n° 6)
- [ ] Un 4ᵉ appelle l'un des trois → **occupé**
- [ ] Blocage Nadia ↔ Awa → refus **avant** toute sonnerie
- [ ] Deux appuis simultanés sur « ajouter » → un seul appel part

**Lot 2**
- [ ] Transfert audio nominal : Chris disparaît, Awa n'entend pas de trou
- [ ] Transfert vidéo : les trois se croisent, Chris part (comportement conférence)
- [ ] Chris coupe son réseau en plein transfert → **le transfert aboutit quand même** (filet 15 s)
- [ ] Nadia refuse → Chris reste en ligne avec Awa, droit rendu
- [ ] Nadia ne répond pas (45 s) → idem
- [ ] Nadia occupée → refus immédiat, aucune sonnerie
- [ ] Transfert **en cascade** : Awa retransfère à Paul après le premier transfert

**Lot 3** — le tableau du § 10.6

**Après chaque scénario, sans exception**
- [ ] `callState` et `callSessions` vides pour les trois (aucun « occupé » résiduel)
- [ ] Le journal d'appels de chacun est juste, durées comprises

### 10.6 Tableau de recette du masqué

À vérifier **sur l'appareil concerné**, jamais déduit du code.

| Événement | Awa (masquée) | Chris (transféreur) | Nadia (cible) |
|---|---|---|---|
| Chris lance le transfert | **rien** | « Transfert vers Nadia… » | **sonne, voit Awa** + « Chris vous transfère l'appel » |
| Nadia accepte | rebranche l'audio, **écran figé** | « Appel transféré » → part | liste **sans Chris** |
| Chris part | ferme la connexion, **rien à l'écran** | écran fermé | rien |
| Nadia coupe son micro | l'indicateur s'allume **sur la tuile de Chris** | — | — |
| Nadia refuse | **rien** | « Nadia a refusé » | — |
| Chris coupe son réseau en plein transfert | **ne raccroche pas** | — | entre quand même |
| Fin de l'appel | journal : **un appel avec Chris** | journal : appel avec Awa | journal : appel avec Awa |
| Résultat | croit toujours parler à Chris | hors de l'appel | parle à Awa |

---

## 11. Décisions prises par défaut

Faute d'arbitrage explicite, la conception retient ces trois réponses. Elles se
changent sans rien casser d'autre.

1. **Transfert vidéo** → transfert visible, et **on le dit** : la ligne
   d'explication de la feuille change (§ 7.2). Pas de boîte de dialogue.
2. **Un seul bouton** dans la barre de contrôle, deux modes dans la feuille
   (§ 7.1). La barre est déjà chargée et le bouton rouge ne doit pas bouger.
3. **Le masqué est ouvert à tous les comptes** en v1. Le transfert d'appel masqué
   est une fonction téléphonique banale, et le réserver à certains comptes
   (`type_compte` existe en base) demanderait une administration qui n'existe pas
   encore.
