# Plan — Chiffrement de bout en bout (E2EE) des messages

> Rédigé le 8 octobre 2026. Ce plan s'appuie sur l'état du code (`main` des trois dépôts,
> branches `chiffrement-messages` et `feat/chiffrement-e2e`) et sur des recherches externes,
> dont les sources sont listées à la fin.
>
> Objectif fixé : chiffrer de bout en bout **sans qu'aucune fonction existante ne cesse de
> marcher**, ni pendant la transition, ni après.

---

## 0. Résumé en dix lignes

1. **Ne pas écrire le protocole nous-mêmes.** Le backend `feat/chiffrement-e2e` prévoit un
   X3DH + cliquet maison. C'est la cause n°1 de failles dans ce domaine. On garde son
   modèle de données (corps chiffré une fois + enveloppes par appareil), qui est bon, mais
   la cryptographie doit venir d'une bibliothèque auditée.
2. **La licence élimine les deux options « Signal » en Dart.** `libsignal` (et son
   binding `libsignal_dart`) est sous AGPL-3.0, et `libsignal_protocol_dart` (celui de
   l'ancienne branche) sous GPL-3.0. Les deux obligent à publier le code source de
   l'application.
3. **Recommandation : vodozemac** (Olm pour les échanges 1-à-1 par appareil, Megolm pour
   les groupes). C'est l'implémentation Rust de Matrix : licence Apache-2.0, auditée par
   Least Authority, utilisée en production par Element. On écrit notre propre binding
   `flutter_rust_bridge`, parce que le binding Dart de Famedly est sous AGPL.
4. **Point bloquant juridique.** Les articles 50 et 58 de la loi camerounaise 2010/012
   imposent de fournir les interceptions « en clair » et de remettre « les conventions
   permettant le déchiffrement ». Un véritable E2EE rend cela impossible. Il faut l'avis
   d'un juriste **avant** d'ouvrir l'E2EE au public.
5. **Les sauvegardes actuelles contredisent l'E2EE**, puisque le serveur peut dériver leur
   clé. Il faut soit l'assumer et l'écrire clairement, soit proposer une sauvegarde à clé
   détenue par l'utilisateur.
6. **Neuf fonctions serveur lisent `message.content`** et doivent être déplacées côté
   client (§3).
7. **Garantie de continuité** : `enc_version` par message, lecture du clair toujours
   possible, activation par conversation seulement quand tous les appareils sont prêts,
   interrupteur d'urgence côté serveur, accusés de « déchiffrement impossible » avec
   renvoi automatique, déploiement progressif mesuré (§5).
8. **Faille spécifique au multi-appareil** : sans liste d'appareils signée, le serveur peut
   ajouter un appareil fantôme et lire tout le trafic. Il faut une clé d'identité de
   compte qui signe chaque appareil lié (§4.3).
9. Notifications push : contenu déchiffré dans le téléphone (gestionnaire en
   arrière-plan sur Android, `NotificationServiceExtension` sur iOS, déjà présente).
10. **Audit externe obligatoire** avant l'ouverture à tous.

---

## 1. Point de départ

### 1.1 Ce qui existe déjà

| Élément | État | Verdict |
|---|---|---|
| Branche `chiffrement-messages` (app + backend, juillet 2026) | Code fusionné dans la branche, mis en pause. Utilise `libsignal_protocol_dart` (Sender Keys) et `cryptography` (X25519/AES-GCM) avec un X3DH partiellement fait main. Coffre d'historique dérivé du mot de passe (Argon2id). | **À ne pas reprendre** : licence GPL-3.0, cryptographie maison, conçu pour un client React. Seuls les écrans (`key_verification_screen.dart`) et l'expérience sur les médias peuvent servir de référence. |
| Table `message_crypto` (migration 064) | Lignes de l'ancienne branche, illisibles. | Compter, puis supprimer (`DROP`) après décision. |
| Branche backend `feat/chiffrement-e2e` (2 octobre 2026) | Migrations 090-092 : clés publiques **par appareil**, prekeys à usage unique, `message_e2ee` (corps) + `message_envelope` (clé par appareil), `enc_version`, purge des enveloppes, signalement avec extrait. Routage par socket. **Aucune partie client.** | **Bonne base de modèle de données.** Il faut adapter le format des clés et des en-têtes à la bibliothèque retenue (§2) et ajouter la signature de la liste d'appareils (§4.3). |
| Admin `feat/chiffrement-e2e` | Fiche groupe sans aperçu, modération par extrait. | À garder. |

### 1.2 Atouts déjà en place

- **Multi-appareil réel** : table `appareils`, enrôlement par QR, `appareilId` dans le JWT.
  Le chiffrement par appareil s'y greffe naturellement.
- **Traduction sur le téléphone** (`google_mlkit_translation`) : elle reste compatible
  avec l'E2EE sans modification.
- **`NotificationServiceExtension` iOS** et `onBackgroundMessage` Android déjà présents.
- **Aucun traitement de média côté serveur** (pas de `sharp` ni de `ffmpeg`) : chiffrer les
  fichiers ne casse rien sur le serveur.
- **Appels** : WebRTC en maillage (P2P) avec DTLS-SRTP. Les médias des appels sont déjà
  chiffrés de bout en bout, sous réserve du §4.6.
- **Base locale drift** : la recherche se fait déjà sur le téléphone.

---

## 2. Décision n°1 : la bibliothèque

### 2.1 Comparatif

| Option | Licence | Audit | PQ* | Maturité Dart | Verdict |
|---|---|---|---|---|---|
| `libsignal` via `libsignal_dart` (FFI) | **AGPL-3.0** (exception App Store) | libsignal oui, binding non | Oui (PQXDH, SPQR) | 1 mainteneur, 9 étoiles | ❌ Oblige à publier tout le code de l'app sous AGPL |
| `libsignal_protocol_dart` (Dart pur, Mixin) | **GPL-3.0** | Non | Non | 0.8.2, 66 likes | ❌ Licence + non audité + pas de post-quantique |
| **vodozemac** (Olm/Megolm, Rust) + **binding maison** | **Apache-2.0** (le crate Rust) | Least Authority 2022, analyse formelle 2024, réponse aux signalements de février 2026 | Non (Olm v2 expérimental) | Utilisé à grande échelle par Element/Matrix ; binding Famedly sous AGPL, donc à réécrire | ✅ **Recommandé** |
| OpenMLS (RFC 9420) via `openmls` Dart | MIT | OpenMLS en cours d'audit ; le binding n'est pas audité | Suites PQ expérimentales | 3.2.1, 1 mainteneur, 9 étoiles | 🟡 Standard IETF, excellent pour les grands groupes, mais exige un serveur qui ordonne les « commits », donc une refonte plus lourde |
| Cryptographie maison avec `cryptography` (plan actuel du backend) | — | — | — | — | ❌ Jamais |

\* PQ = résistance aux ordinateurs quantiques (« enregistrer aujourd'hui, déchiffrer
demain »).

### 2.2 Pourquoi vodozemac

- **Licence permissive**, donc compatible avec une application fermée. À confirmer par un
  juriste, en vérifiant aussi les dépendances transitives avec `cargo-deny`.
- **Correspond au modèle déjà conçu** : Olm = session 1-à-1 **par appareil**, Megolm = une
  chaîne d'expéditeur partagée par groupe, ce qui correspond exactement aux enveloppes
  `env_type` 1/2/3 de la migration 091.
- **Éprouvé en production** sur des millions de comptes Matrix, avec un format de
  sérialisation (« pickle ») chiffré pour stocker les sessions.
- **Limites connues, à accepter en connaissance de cause** :
  - Megolm a une sécurité après compromission (post-compromise security) plus faible que
    les Sender Keys de Signal. On compense par une **rotation de la session de groupe**
    tous les N messages, à chaque départ de membre et chaque semaine.
  - Olm v1 tronque ses MAC à 64 bits (relevé par l'audit, sans exploit connu).
  - Pas de post-quantique pour l'instant. À réévaluer, ou migrer vers MLS plus tard (§8).
  - Plafond de 40 clés de messages sautés (`MAX_MESSAGE_KEYS`), ce qui limite le
    désordre tolérable : le serveur doit livrer **dans l'ordre**, par appareil.
- **Le binding maison est petit** : création de compte et de clés, sessions
  entrantes/sortantes, chiffrer/déchiffrer, sessions de groupe, export/import de
  « pickle ». C'est à générer avec `flutter_rust_bridge`, avec des binaires précompilés en
  CI pour Android (arm64/armv7/x64) et iOS. Pour le futur client web React, vodozemac se
  compile aussi en WASM.

### 2.3 Plan B

Si l'avis juridique ou un test de faisabilité invalide vodozemac, l'option suivante est
**OpenMLS** (licence MIT). Une licence commerciale de libsignal auprès de la Signal
Foundation est théoriquement possible (CLA), mais incertaine.

### 2.4 Premier livrable : un test de faisabilité (1 à 2 semaines)

Avant tout chantier, prouver sur **un vrai Android d'entrée de gamme et un iPhone** :

1. Le binding se compile et l'app grossit d'un poids acceptable (mesurer en Mo).
2. 1 000 chiffrements/déchiffrements Olm et Megolm se font en moins de X ms.
3. Une session « picklée » est rechargée depuis drift **et depuis la
   NotificationServiceExtension iOS** (processus séparé).
4. Arrêt brutal de l'app au milieu d'un déchiffrement : la session n'est pas corrompue.

---

## 3. Inventaire : ce qui casse si le serveur ne voit plus le contenu

| # | Fonction | Fichier(s) | Ce qui change |
|---|---|---|---|
| 1 | **Corps des notifications push** | `notificationContract.js:158`, `notificationService.js` | Le serveur n'envoie plus le texte, seulement une **notification de données** contenant l'enveloppe chiffrée (< 4 Ko) ou un simple signal de réveil. Déchiffrement dans `firebaseMessagingBackgroundHandler` (Android) et `NotificationService.swift` (iOS). Si le déchiffrement échoue : afficher « Nouveau message ». |
| 2 | **Aperçu du dernier message** (liste des conversations) | `messagePreview.js`, `messageSend.js:371` | Le serveur stocke un aperçu générique (« 💬 Message », « 📷 Photo » selon `type`). Le vrai aperçu est calculé sur le téléphone depuis la base locale. |
| 3 | **Citation de réponse** `replyToContent` | `messageInsert.js`, `resolveReplyToID.js` | Le texte cité passe dans le corps chiffré. `replyToID` reste en clair. |
| 4 | **Vignettes** `mediaThumb` (base64 en base) | `message_thumb` (migration 060) | Elles passent dans le corps chiffré. La table n'est plus alimentée pour les messages v1. |
| 5 | **Fichiers médias** (Backblaze) | `mediaStorage.js`, `upload.js` | Chiffrés sur le téléphone avant l'envoi (AES-256-GCM par blocs, ou AES-CBC + HMAC comme WhatsApp), avec une clé aléatoire par fichier. La clé et le SHA-256 voyagent dans le corps chiffré. Quotas et rétention s'appliquent à la taille chiffrée : aucun changement serveur. Les URL signées restent. |
| 6 | **Albums** (`__talky_album__` dans `content`) | `messagePreview.js`, `mediaAlbum.js` | Le marqueur passe dans le corps. Le serveur garde seulement les comptes (photos/vidéos) en métadonnées s'il en a besoin pour l'aperçu générique. |
| 7 | **Mentions** | `messageSend.js` (intersection serveur) | Les **ID mentionnés** restent en clair (métadonnée) pour les notifications « vous a mentionné ». Le texte reste chiffré. C'est une fuite de métadonnées assumée et documentée. |
| 8 | **Modération / signalements** | `admin/reports.js:74` (`m.content LIKE`), `reportService.js` | Déjà traité par la branche (`092_report_extrait`) : le **signaleur** joint l'extrait déchiffré. À ajouter en phase 2 : le *message franking* (§4.5), sinon un signaleur peut inventer l'extrait. |
| 9 | **Admin : aperçus de groupe** | `admin/groups.js` | Déjà retiré dans `alanya-admin` `feat/chiffrement-e2e`. |
| 10 | **Modification de message** | `messageController.js` (`isEdited`) | Une modification devient un nouveau corps chiffré qui référence `msgID`. |
| 11 | **Messages composés par le serveur** : système (type 6), bienvenue, diffusions, trajets, traces d'appel | `systemMessage.js`, `welcomeService.js`, `broadcastService.js`, `tripService.js` | **Restent en clair** (`enc_version = 0`). L'interface doit les distinguer visuellement (style « message système » ou badge du compte officiel) pour qu'on ne les confonde pas avec un message chiffré. |
| 12 | **Statuts / stories** | `routes/status.js` | **Hors périmètre v1.** À chiffrer plus tard, sur le modèle d'une liste de diffusion avec une clé par statut. |
| 13 | **Messages vocaux / répondeur** | `voicemail*` | Si l'annonce est déposée par le serveur : clair. Si un correspondant laisse un vocal : c'est un média, donc ligne 5. |
| 14 | **Sauvegardes** | `backupKeyService.js` | Voir §4.4 : c'est une décision de produit. |

Ne changent pas : la traduction (ML Kit sur le téléphone), la recherche (base locale), les
accusés de remise et de lecture (métadonnées), les appels, la facturation, les quotas.

---

## 4. Conception cible

### 4.1 Modèle (on garde celui des migrations 090/091)

```
Expéditeur (appareil A1)
  ├─ clé de contenu K aléatoire (32 o) ── AES-256-GCM ──▶ message_e2ee.body  (1 fois)
  └─ K scellée pour chaque appareil :
        • 1-à-1 : session Olm(A1 → B1), Olm(A1 → B2), Olm(A1 → A2)   ─▶ message_envelope
        • groupe : K dérivée de la session Megolm de A1 ; enveloppe = en-tête seul
```

Le serveur stocke : métadonnées en clair (expéditeur, conversation, type, dates, statut,
`replyToID`, ID mentionnés, URL du média chiffré, taille) + blobs opaques.

**Corps chiffré (JSON avant chiffrement)** : `{ v, text, replyTo:{id,excerpt},
media:{url,key,sha256,mime,name,size,duration,thumb}, album, edits, linkPreview }`.
Un champ `v` à l'intérieur permet de faire évoluer le format sans migration serveur.

### 4.2 Adaptations du schéma de la branche `feat/chiffrement-e2e`

- `e2ee_device_keys` : Olm utilise une clé d'identité Curve25519 + une clé Ed25519 de
  signature. Les colonnes `identity_key_dh` / `identity_key_sign` correspondent déjà.
  Remplacer `signed_prekey*` par la **fallback key** d'Olm, et les `one_time_prekeys` par
  les one-time keys d'Olm (même principe, même table).
- `message_envelope.header` : contient le message Olm (type 0 = pré-clé, 1 = normal) ou
  l'index Megolm. Agrandir `wrapped_key` si nécessaire.
- **Nouvelle table `e2ee_group_sessions_shared`** (ou réutiliser les enveloppes) : la
  distribution d'une session Megolm passe par des messages Olm 1-à-1 adressés à chaque
  appareil membre.
- **Nouvelle table `e2ee_account_identity`** (§4.3).

### 4.3 Multi-appareil : empêcher l'appareil fantôme

**Le risque** : dans le schéma actuel, le serveur publie la liste des appareils d'un
compte. Un serveur compromis, ou contraint, ajoute un appareil dont il détient la clé, et
tous les correspondants lui chiffrent leurs messages sans le savoir. C'est la principale
faiblesse de tout E2EE multi-appareil.

**La parade** (celle de WhatsApp) :

- Le **premier appareil** génère une **clé d'identité de compte** (Ed25519), gardée dans
  le trousseau sécurisé.
- Chaque appareil lié (QR) reçoit une **signature de cette clé** sur sa propre clé
  d'identité, faite **sur l'appareil principal**, au moment du scan.
- Les clients refusent tout appareil dont la signature ne remonte pas à la clé de compte
  connue.
- Si la clé de compte change (réinstallation sans restauration) : avertissement « le code
  de sécurité de X a changé », comme sur WhatsApp et Signal.
- **Écran de vérification** : QR code + numéro de sécurité de 60 chiffres, calculés sur
  la clé de **compte** (l'écran `key_verification_screen.dart` de l'ancienne branche peut
  servir de base).
- Plus tard : **transparence des clés** (Auditable Key Directory de WhatsApp, `akd` en
  Rust) pour automatiser cette vérification.

**Point produit** : la connexion « mot de passe sur un second téléphone » et la
« réinscription de secours » (`login_method`, migrations 026/083) ne peuvent pas être
signées par un appareil existant. Il faut traiter un tel appareil comme **une nouvelle
identité** : avertissement chez tous les correspondants, et pas d'historique sauf via la
sauvegarde.

### 4.4 Sauvegardes et historique

Aujourd'hui la clé de sauvegarde est dérivée sur le serveur. Une fois l'E2EE en place,
**toute conversation sauvegardée redevient lisible par Alanya**. Trois options :

| Option | Sécurité | Risque produit |
|---|---|---|
| A. Garder tel quel et l'écrire clairement (« Messages chiffrés de bout en bout. Les sauvegardes sont chiffrées, Alanya peut les restaurer pour vous. ») | E2EE en transit uniquement pour qui sauvegarde | Faible, mais promesse affaiblie |
| B. **Option « sauvegarde chiffrée de bout en bout »** avec une clé de 64 caractères ou un mot de passe choisi par l'utilisateur, clé dérivée sur le téléphone (Argon2id) | Réel | Mot de passe oublié = sauvegarde perdue (le premier motif de support, comme l'indique `backupKeyService.js`) |
| C. Coffre HSM + OPAQUE (le modèle WhatsApp/Messenger) | Réel + récupérable | Très coûteux, hors de portée à court terme |

**Recommandation : A au lancement, B en option dans la phase 3.** WhatsApp a fonctionné
ainsi pendant cinq ans (sauvegardes Google Drive non chiffrées de bout en bout jusqu'en
2021).

Changement de téléphone : l'historique revient **par la sauvegarde** uniquement, comme le
prévoit déjà la branche. Un appareil lié par QR peut recevoir un transfert d'historique
direct d'appareil à appareil, chiffré par la session Olm (phase 3).

### 4.5 Modération

- **v1** : signalement avec extrait déchiffré joint par le signaleur (déjà codé).
- **Phase 2** : *message franking*. L'expéditeur calcule un HMAC du clair avec une clé
  aléatoire placée dans le corps chiffré. Le serveur contre-signe ce tag à la réception.
  Lors d'un signalement, le signaleur révèle le clair + la clé, et le serveur vérifie que
  le message a bien été envoyé tel quel par cet expéditeur. C'est le schéma de Messenger,
  qui empêche les faux signalements.

### 4.6 Appels

Les médias sont déjà chiffrés (DTLS-SRTP, maillage P2P, TURN qui relaie du chiffré).
Mais l'**empreinte DTLS** circule dans le SDP **via le serveur**, qui pourrait donc
s'interposer. Correctif (phase 3) : envoyer l'empreinte DTLS **dans le canal chiffré Olm**
ou la signer avec la clé d'identité de l'appareil, puis vérifier avant d'accepter le
média. Si un SFU est introduit un jour pour les grands groupes : SFrame (RFC 9605).

### 4.7 Stockage local

Les messages déchiffrés sont en clair dans drift. Recommandation : passer à **SQLCipher**
(`sqlcipher_flutter_libs` à la place de `sqlite3_flutter_libs`), avec la clé dans le
Keystore/Keychain. Les sessions Olm/Megolm sont stockées en « pickle » chiffré, avec une
clé dans `flutter_secure_storage`, **dans la même transaction** que le message déchiffré.
C'est indispensable : un crash entre « session avancée » et « message enregistré »
perdrait le message pour toujours.

### 4.8 Cadre juridique (bloquant)

Loi n° 2010/012 du 21 décembre 2010 :

- **Art. 50** : si un fournisseur de services de communications électroniques chiffre les
  données transmises, « les interceptions correspondantes sont fournies en clair ».
- **Art. 58** : les fournisseurs de « prestations de cryptographie visant à assurer une
  fonction de confidentialité » doivent remettre aux OPJ « les conventions permettant le
  déchiffrement des données ».

Avec un vrai E2EE, Alanya **ne peut pas** satisfaire ces obligations pour le contenu, mais
seulement pour les métadonnées. Il faut faire valider par un juriste camerounais, **avant
la phase 2** :

- la qualification d'Alanya (fournisseur de services, prestataire de cryptographie ?) ;
- une éventuelle déclaration ou autorisation auprès de l'ANTIC pour les moyens de
  cryptographie ;
- la réponse type aux réquisitions (on fournit les métadonnées, et l'on explique
  l'impossibilité technique pour le contenu) ;
- la mise à jour de la politique de confidentialité (`legalController.js`).

C'est un point de décision, pas un détail : le résultat peut conduire à garder l'E2EE
facultatif (« conversations secrètes ») plutôt qu'activé par défaut.

---

## 5. Garantir que tout continue de fonctionner

C'est l'exigence principale. Voici les mécanismes, du plus important au moins important.

### 5.1 Coexistence clair / chiffré, permanente

- `message.enc_version` : 0 = clair, 1 = E2EE. **Tous les clients savent lire les deux,
  pour toujours.** L'historique antérieur reste en clair et lisible ; on ne re-chiffre
  rien rétroactivement.
- Le serveur accepte les deux formats sur `message:send` et la route HTTP de réponse
  rapide (déjà fait dans la branche).

### 5.2 Activation par conversation, seulement quand tout le monde est prêt

Une conversation passe en E2EE si **chaque appareil actif de chaque participant** a publié
ses clés **et** tourne avec une version d'app compatible. Sinon, l'envoi reste en clair.

**Règle anti-rétrogradation** : une fois qu'une conversation est passée en E2EE, elle ne
revient **jamais** silencieusement en clair. Si un nouvel appareil sans clés apparaît, il
ne reçoit pas les messages (ou reçoit « mettez à jour Alanya pour lire ce message »), et
l'expéditeur voit un avertissement. Sans cette règle, un attaquant pourrait forcer le
retour au clair.

### 5.3 Interrupteur d'urgence côté serveur

Un drapeau dans le registre des fonctionnalités (comme `requireFeature`) :

- `e2ee.send` : on/off/pourcentage. Sur « off », les clients **envoient** à nouveau en
  clair pour les conversations qui ne sont pas encore verrouillées en E2EE. Ils lisent
  toujours le v1 déjà reçu.
- `e2ee.enrol` : les clients publient leurs clés, ou non.

Sert à couper instantanément en cas de bogue massif, sans mise à jour de l'app.

### 5.4 Déchiffrement impossible : récupération automatique

C'est **le** mécanisme qui fait que « ça marche toujours » en pratique (WhatsApp et Signal
l'appellent *retry receipt*) :

1. Le destinataire n'arrive pas à déchiffrer (session perdue, réinstallation, bogue).
2. Il envoie au serveur un **accusé d'échec** (`message:decrypt_failed {msgID, raison}`).
3. L'appareil de l'expéditeur **recrée une session neuve** et **re-chiffre ce message**
   pour cet appareil seulement (une nouvelle enveloppe, le corps ne change pas).
4. Entre-temps, la bulle affiche « En attente de ce message… », jamais du charabia.
5. Après N échecs, ou si l'expéditeur est hors ligne depuis plus de 30 jours : « Ce
   message n'a pas pu être déchiffré ».

Il faut donc **garder K** (la clé de contenu) côté expéditeur pendant 30 jours, dans le
stockage chiffré.

### 5.5 Ordre et unicité de livraison

- Livraison **ordonnée par appareil** (Olm et Megolm tolèrent mal le désordre au-delà de
  40 messages) : la file `message_envelope` est lue par `(appareil_id, msgID)`.
- **Idempotence** : le `clientID` existe déjà. Un message déchiffré deux fois ne doit
  rien casser (Megolm refuse un index rejoué, ce qu'il faut traiter comme « déjà reçu »,
  pas comme une erreur).

### 5.6 Versions d'application

- Version minimale imposée côté serveur (mise à jour forcée) **avant** de dépasser 50 %
  de déploiement, sinon les vieilles versions ralentissent la bascule de tout le monde
  (§5.2).
- Les anciennes versions qui reçoivent un v1 affichent « Mettez à jour Alanya pour lire
  ce message ». C'est à livrer **dès maintenant**, dans une version qui précède
  l'E2EE (« version de préparation »).

### 5.7 Observabilité (sans contenu)

Le client remonte des compteurs anonymes : chiffrements, déchiffrements réussis, échecs
par cause (`no_session`, `bad_mac`, `unknown_index`, `missing_envelope`, `duplicate`),
durée du déchiffrement en notification, stock de one-time keys. Ces données sont
affichées dans `alanya-admin` (page santé).

**Critère de passage à l'étape suivante du déploiement : taux d'échec définitif < 0,01 %
des messages.**

### 5.8 Tests

| Niveau | Contenu |
|---|---|
| Unitaires Dart | Format du corps, enveloppes, sérialisation, règles de §5.2. |
| Unitaires Rust (binding) | Vecteurs de test vodozemac, aller-retour pickle. |
| Simulation multi-appareils (Dart, sans réseau) | 3 comptes × 3 appareils. Scénarios : réinstallation, appareil révoqué, appareil ajouté en cours de conversation, stock de one-time keys épuisé, hors ligne 31 jours, messages dans le désordre et en double, membre retiré d'un groupe (il ne doit plus lire), crash au milieu d'un déchiffrement. |
| Backend (`node --test`, déjà en place) | Routage des enveloppes, consommation atomique des clés, purge, accusé d'échec. |
| Appareils réels | Notification reçue téléphone verrouillé, app tuée (Android et iOS) ; changement de téléphone avec restauration ; QR de liaison. |
| Charge | Groupe de 200 membres × 2 appareils : temps d'envoi, taille des enveloppes. |
| **Audit externe** | Avant la phase 4, par un cabinet spécialisé (Least Authority, NCC Group, Trail of Bits, Quarkslab, Cure53…). Périmètre : binding, gestion des sessions, liste d'appareils, franking. |

---

## 6. Phases

Les durées sont des ordres de grandeur pour un développeur à plein temps. Elles sont à
recalibrer après la phase 0.

| Phase | Contenu | Sortie | Ordre de grandeur |
|---|---|---|---|
| **0. Cadrage** | Avis juridique (§4.8), licences (`cargo-deny`), test de faisabilité vodozemac (§2.4), décision sur les sauvegardes (§4.4). | Go / No-go écrit | 2-3 sem. |
| **1. Préparation, sans chiffrer** | Version d'app « préparation » : lecture de `enc_version`, bulle « mettez à jour », aperçus calculés sur le téléphone, notifications de données déchiffrées localement (encore en clair), SQLCipher, télémétrie. Côté serveur : migrations adaptées, interrupteurs, aperçu générique. | En production, rien de visible ne change | 3-4 sem. |
| **2. 1-à-1 texte** | Binding, clés de compte et d'appareil, liste d'appareils signée, Olm, enveloppes, accusé d'échec et renvoi, écran de vérification. Activé pour l'équipe seulement. | Messages 1-à-1 E2EE en interne | 5-7 sem. |
| **3. Médias, groupes, réponses, modifications** | Médias chiffrés, Megolm avec rotation, mentions, albums, franking, empreinte DTLS des appels, option de sauvegarde E2EE. | Couverture fonctionnelle complète | 6-8 sem. |
| **4. Déploiement** | Audit externe → bêta testeurs → 1 % → 10 % → 50 % (mise à jour forcée) → 100 %. Une semaine minimum par palier, avec le critère de §5.7. | E2EE par défaut | 6-10 sem. |
| **5. Ensuite** | Statuts, client web (vodozemac en WASM), transparence des clés, post-quantique ou MLS. | — | — |

---

## 7. Décisions à prendre maintenant

1. **Bibliothèque** : vodozemac + binding maison (recommandé), ou OpenMLS ?
2. **Juridique** : qui consulter, et peut-on lancer la phase 1 en parallèle (elle ne
   chiffre rien, donc oui) ?
3. **Sauvegardes** : option A au lancement, B ensuite ?
4. **E2EE par défaut, ou « conversations secrètes » facultatives** ? Cela dépend du point 2.
5. **Branches existantes** : on archive `chiffrement-messages` (app et backend) et on
   repart de `feat/chiffrement-e2e` (backend + admin) en adaptant le format des clés ?

---

## 8. Évolutions à garder en tête

- **Post-quantique** : Signal a ajouté PQXDH (2023) puis SPQR / Triple Ratchet (2025,
  ML-KEM 768). vodozemac n'en a pas. Si cela devient une exigence, la voie la plus
  probable est MLS avec une suite PQ, une fois standardisée.
- **MLS** : si les groupes dépassent quelques centaines de membres, MLS passe mieux à
  l'échelle que Megolm (TreeKEM, coût logarithmique par changement de membres).

---

## Sources

- libsignal en Dart : [djx-y-z/libsignal_dart](https://github.com/djx-y-z/libsignal_dart) (AGPL-3.0) ·
  [libsignal_protocol_dart sur pub.dev](https://pub.dev/packages/libsignal_protocol_dart) (GPL-3.0) ·
  [Signal — License update](https://signal.org/blog/license-update/)
- vodozemac : [matrix-org/vodozemac](https://github.com/matrix-org/vodozemac) (Apache-2.0) ·
  [Audit Least Authority (2022)](https://matrix.org/blog/2022/05/16/independent-public-audit-of-vodozemac-a-native-rust-reference-implementation-of-matrix-end-to-end-encryption/) ·
  [Rapport d'audit PDF](https://leastauthority.com/static/publications/LeastAuthority-Matrix_vodozemac_Final_Audit_Report.pdf) ·
  [Analyse des problèmes signalés (février 2026)](https://matrix.org/blog/2026/02/analysis-of-reported-issues-in-vodozemac/) ·
  [Analyse formelle de la suite Matrix](https://arxiv.org/pdf/2408.12743) ·
  [Binding Dart Famedly (AGPL)](https://pub.dev/packages/vodozemac)
- MLS : [openmls sur pub.dev](https://pub.dev/packages/openmls) · [djx-y-z/openmls_dart](https://github.com/djx-y-z/openmls_dart) ·
  [openmls/openmls](https://github.com/openmls/openmls)
- Post-quantique Signal : [Signal — SPQR](https://signal.org/blog/spqr/) ·
  [Quarkslab — Triple ratchet](https://blog.quarkslab.com/triple-threat-signals-ratchet-goes-post-quantum.html)
- Multi-appareil WhatsApp : [Engineering at Meta — WhatsApp multi-device](https://engineering.fb.com/2021/07/14/security/whatsapp-multi-device/) ·
  [WhatsApp Security Whitepaper](https://www.whatsapp.com/security/WhatsApp-Security-Whitepaper.pdf) (médias : AES-256-CBC + HMAC-SHA256, clé éphémère par pièce jointe)
- Transparence des clés : [WhatsApp — Key Transparency](https://tech.facebook.com/2024/7/strengthening-whatsapp-end-to-end-encryption-key-transparency) ·
  [Cloudflare — Key transparency](https://blog.cloudflare.com/en-us/key-transparency)
- Sauvegardes : [Meta — HSM-based Backup Key Vault (2026)](https://engineering.fb.com/2026/05/01/security/meta-strengthening-end-to-end-encrypted-backups/)
- Bascule de Messenger (plus de 100 fonctions refaites côté client) : [The Hacker News](https://thehackernews.com/2023/12/meta-launches-default-end-to-end.html) ·
  [Labyrinth 1.1](https://engineering.fb.com/2026/05/11/security/labyrinth-1-1/)
- Modération : [Message franking — IACR 2019/016](https://eprint.iacr.org/2019/016)
- Notifications : [FCM — chiffrement de bout en bout](https://firebase.google.com/docs/cloud-messaging/encryption) ·
  [Threema — notifications](https://threema.com/en/faq/privacy-push)
- Appels : [RFC 9605 SFrame](https://www.rfc-editor.org/rfc/rfc9605.html) ·
  [WebRTC Encoded Transform](https://www.w3.org/TR/webrtc-encoded-transform) ·
  [Nabto — WebRTC baseline security](https://docs.nabto.com/developer/webrtc/guides/security/baseline.html)
- Droit camerounais : [Loi n° 2010/012 (texte)](https://opencamer.blogspot.com/2013/08/loi-n-2010012-du-21-decembre-2010.html) ·
  [Version PDF AFAPDP](https://www.afapdp.org/wp-content/uploads/2018/05/Cameroun-Loi-relative-a-la-cybersecurite-et-a-la-cybercriminalite-du-21-decembre-2010.pdf) ·
  [Profil juridique Conseil de l'Europe](https://rm.coe.int/octocom-legal-profile-cameroun-fr/1680a713cb)
