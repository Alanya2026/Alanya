# Plan Web — client navigateur Alanya

## Contexte

Décision : ouvrir Alanya au navigateur, sur **le même backend**, sans fork ni duplication
de serveur. Le besoin est celui d'un **client compagnon** (type WhatsApp Web) : l'utilisateur
garde son téléphone comme appareil principal et retrouve ses conversations dans un onglet,
au clavier, sur grand écran.

Deux questions à trancher : **quelle stack**, et **quelles modifications backend**. Ce
document répond aux deux, avec les constats vérifiés dans le code, puis détaille le
phasage.

---

## Décision de stack : React / Next.js, **pas** Flutter Web

### Pourquoi pas Flutter Web

L'app *semble* déjà à moitié prête pour le web — il existe un [web/](../web/) avec manifest
PWA, icônes, splash et un service worker FCM écrit à la main. C'est trompeur.

| Constat | Détail |
|---|---|
| **54 fichiers importent `dart:io`** | Tout le pipeline média repose sur `File` : pick → staging temp → thumbnail → upload multipart → cache disque → lecture depuis un chemin. Dans un navigateur, ni `File` ni système de fichiers. |
| **13 plugins sans implémentation web** | `path_provider` (12 sites d'appel), `sqlite3_flutter_libs` (ouverture native de Drift, [app_database.dart](../lib/core/db/app_database.dart#L445)), `flutter_local_notifications`, `flutter_callkit_incoming`, `screen_protector`, `gal`, `open_filex`, `receive_sharing_intent`, `audio_waveforms`, `video_thumbnail`, `flutter_ringtone_player`, `vibration`, `app_badge_plus`. |
| **Zéro import conditionnel n'existe** | Aucune paire `_web.dart` / `_io.dart`. Les 50 `kIsWeb` sont tous des gardes défensives `if (kIsWeb) return;` — [local_notification_helper.dart](../lib/core/services/notifications/local_notification_helper.dart) est un no-op complet. Les fonctionnalités ne dégradent pas, elles disparaissent. |
| **Les 62 écrans sont de forme mobile** | Nav bottom 5 onglets, navigation full-screen, une colonne. Un messager web veut 2-3 panneaux, hover, raccourcis clavier, drag&drop, coller-pour-envoyer, clic droit, sélection de texte native, bouton retour navigateur. |

Le dernier point est décisif : re-maquetter 62 écrans pour desktop coûte à peu près autant
que les écrire en web-natif, tout en héritant des ~2,5–4 Mo de CanvasKit au chargement et
d'un rendu texte/scroll non natif — dans un onglet laissé ouvert toute la journée. Aucun
messager grand public ne livre en Flutter Web (WhatsApp Web, Telegram Web, Signal Desktop
sont tous web-natifs).

### Ce qu'on renonce à réutiliser — et pourquoi ce n'est pas grave

Logique métier, modèles, l10n, thème, encodeurs de payload : réels, mais réécrits une fois.
En revanche, une grande part de la machinerie mobile (outbox à backoff, ack watchdog, file
d'acks native Android, restauration d'appel au *cold start*) existe **parce que l'OS tue
l'app**. Un onglet, non. Porter [chat_repository.dart](../lib/core/services/chat/chat_repository.dart)
(1613 lignes) reviendrait à payer un moteur dont le web n'a pas besoin.

### Coût assumé

**Deux bases de code à vie.** Chacun des cinq dossiers de conception (socle compte, listes,
diffusion, business, certification) sera à construire deux fois côté client. On le maîtrise
en posant que le **web est un client compagnon qui a le droit d'être en retard** sur le
mobile, et en partageant le *contrat*, pas le code.

---

## Le backend est déjà multi-appareil

Vérifié dans le code — c'est ce qui rend l'opération viable sans refonte serveur.

| Point | Constat |
|---|---|
| Registre socket | `Map<alanyaID, Set<socketId>>` — plusieurs sockets par compte, par conception (`src/utils/userSocketRegistry.js`) |
| Fan-out | `emitToUser` → `io.to('user_<id>')` : tous les appareils du compte reçoivent |
| Écho expéditeur | `messageSend.js:232-233` : `socket.emit('message:sent')` **et** `socket.to('user_<senderID>').emit('message:sent')` → un message envoyé depuis le téléphone apparaît en direct dans l'onglet web |
| État de lecture | `inbox:sync` émis vers `user_<readerID>` (`receipts.js:48`, `readReceiptUtils.js:32`) — se synchronise entre appareils |
| Présence | `hasForegroundSocket()` agrège sur toute la room, avec un commentaire explicite : « un téléphone qui passe en arrière-plan ne doit pas éteindre la présence si la tablette est encore active » |
| `auth:conflict` | Présent dans le catalogue Dart ([talky_models.dart](../lib/talky_models.dart)) mais **jamais émis par le backend** (grep = 0). Constante morte, aucune éviction de session. |
| CORS | `cors()` nu = `*`, Socket.IO `origin: '*'`, auth par header `Bearer`, zéro cookie → un SPA navigateur fonctionne **aujourd'hui**, sans toucher au backend |
| Rattrapage | `POST /api/messages/sync` avec curseurs par conversation = exactement le catch-up voulu au focus d'onglet |
| Idempotence | Insert `ON DUPLICATE KEY` sur `(senderID, clientID)` → renvois sûrs |

### Les trois vrais manques backend

1. **Web push absent.** `user_push_devices.platform` accepte déjà `'web'`, mais
   `notificationService.js` ne construit que des blocs `android` et `apns` — aucun bloc
   `webpush`, aucun chemin VAPID (grep `webpush|vapid` → seul un test mentionne `'web'`).
   Ajout petit et isolé. La logique de service worker, elle, est **déjà écrite** dans
   [web/firebase-messaging-sw.js](../web/firebase-messaging-sw.js) (actions Accepter/Refuser
   sur appel entrant, deep-links, tags par conversation) — à reprendre telle quelle.
   *À corriger au passage :* l'app ID web de [firebase_options.dart](../lib/firebase_options.dart)
   diffère de celui codé dans le service worker.
2. **CORS `*` à resserrer** en liste blanche dès qu'un client navigateur existe. Rien ne
   casse aujourd'hui (`Bearer` + `*` est compatible), mais `/api` ne doit pas rester
   appelable depuis n'importe quelle origine, et le passage aux cookies l'exigera.
3. **`/uploads` est public, non authentifié, sans signature.** Pratique depuis un navigateur
   (`<img src>` fonctionne directement), mais n'importe qui détenant une URL lit n'importe
   quel média. Décision à prendre avant l'ouverture au web, pas après.

**Plafond à connaître :** pas de Redis adapter ; présence, état d'appel et *pending calls*
vivent en mémoire du process ; un seul PM2. Les clients web doublent le nombre de sockets
par utilisateur. Tenable à l'échelle actuelle, mais c'est le mur.

---

## Architecture du client web

### Stack

Next.js 14 App Router + TypeScript strict + Tailwind + shadcn + TanStack Query, **en
calquant `talky-admin`**. On récupère par copie directe : le client axios et son interceptor
401 → refresh en *single-flight* (`lib/api.ts`), le module auth, les 14 primitives
`components/ui`, les tokens CSS (`--primary` vaut déjà `239 84% 67%`, soit le `#3F51B5` de
[app_colors.dart](../lib/core/theme/app_colors.dart)), le dark mode, le système de skeletons,
et le même schéma de déploiement (PM2 + `basePath`, comme `/admin` sur le port 3002).

*Alternative plus légère :* Vite + React Router, puisqu'un messager 100 % client ne tire
rien du SSR/RSC. On garde Next pour l'effet copier-coller et une seule mécanique de
déploiement.

### Règles d'architecture

- **Ne pas reprendre le `transformResponse` snake→camel de l'admin.** Le messager doit
  parler exactement les clés que parle Flutter (`msgID`, `conversationID`, `mediaUrl`,
  `sendAt`…), sinon les deux clients divergent sur le contrat. Spec de référence :
  [talky_models.dart](../lib/talky_models.dart) — écrire les ~13 interfaces TS en miroir.
- **Couche socket en premier**, c'est le morceau risqué. Reproduire la poignée de main à
  l'identique : `autoConnect: false` → sur `connect`, émettre `auth:login {token, deviceId}`
  → attendre `auth:verified` → **verrouiller tout emit derrière ce flag** → émettre
  `presence:online`. `deviceId` = UUID stable en localStorage. Sur `auth:error` code
  `TOKEN_EXPIRED` → refresh HTTP → ré-émettre `auth:login`. Référence :
  [socket_api.dart](../lib/api/socket_api.dart).
- **Pas de moteur offline.** TanStack Query en mémoire + IndexedDB (Dexie) comme cache tiède
  pour la liste de conversations et les N derniers messages par conversation ; rattrapage par
  `POST /api/messages/sync` au focus d'onglet et à la reconnexion.
- **Liste de messages virtualisée** (react-virtuoso ou TanStack Virtual) — indispensable
  au-delà de quelques milliers de messages.
- **l10n** : les ARB (985 clés FR / 866 EN) se convertissent mécaniquement en JSON pour
  next-intl. Attention : ~119 clés manquent côté EN.

### Sécurité du token — décision à acter

`talky-admin` stocke tout en localStorage. Pour un messager détenant un refresh token de
30 jours, une XSS équivaut à une prise de compte complète. Cible correcte : **access token
en mémoire + refresh en cookie httpOnly** — ce qui impose un changement backend (`Set-Cookie`
sur login/refresh, CORS avec origine explicite et `credentials`). Chemin pragmatique : P0 en
localStorage comme l'admin, durcissement planifié avant ouverture publique.

---

## Phasage

| Phase | Contenu | Dépendance backend |
|---|---|---|
| **P0** | Login, liste de conversations, fil de discussion, envoi/réception texte, accusés, typing, présence, affichage média, upload (drag&drop + coller) | **aucune** |
| **P1** | Web push, notifications desktop, badge `navigator.setAppBadge()`, recherche | bloc `webpush` |
| **P2** | Appels 1-1 audio/vidéo | aucune (`/api/turn/credentials` fonctionne depuis un navigateur) |
| **P3** | Statuts, appels de groupe, réunions (mesh — le plus lourd, le moins rentable en premier passage) | aucune |

P0 seul constitue déjà un produit utilisable.

**Contrat d'appel pour P2** : le commentaire d'en-tête de `src/socket/handlers/calls.js:14-38`
fait autorité (machine à états `idle → ringing → in_call`, timer 45 s, détection *busy*) ;
[call_one_to_one.dart](../lib/core/services/call/call_one_to_one.dart) donne le flux
*offer-first* côté client.

### Hors périmètre, définitivement

- **Protection anti-capture du view-once** — impossible dans un navigateur. Décider si les
  médias view-once sont simplement masqués côté web.
- **CallKit** et l'écran d'appel natif au *cold start*.
- **Ingestion share-sheet** (`receive_sharing_intent`).

---

## Vérification

- **Multi-appareil** : téléphone et onglet web connectés simultanément → envoyer depuis le
  téléphone, le message apparaît en direct dans l'onglet (`message:sent` en écho) ; lire
  depuis le web, le compteur non-lu tombe sur le téléphone (`inbox:sync`) ; mettre le
  téléphone en arrière-plan → la présence reste « en ligne » tant que l'onglet est actif.
- **Reconnexion** : couper le réseau de l'onglet 2 minutes, le rétablir → `auth:login`
  rejoué, `presence:online` ré-émis, `POST /api/messages/sync` rattrape les messages
  manqués sans doublon (idempotence `clientID`).
- **Expiration** : attendre l'expiration de l'access token (15 min) → un appel REST
  déclenche le refresh en single-flight sans déconnecter la socket ; forcer un
  `auth:error TOKEN_EXPIRED` → re-auth socket automatique.
- **Upload** : glisser un fichier de 60 Mo → erreur 413 correctement affichée (plafond
  serveur à 50 Mo) ; coller une image depuis le presse-papier → envoi.
- **Push (P1)** : onglet fermé, recevoir un message → notification système ; clic → ouverture
  sur la bonne conversation.
- **Appels (P2)** : appel web → mobile et mobile → web, en réseau contraint (TURN relay) ;
  vérifier le renouvellement des credentials HMAC via `ttlSec`.
- **Non-régression mobile** : le client web ne doit rien changer au comportement de l'app —
  faire tourner `flutter test` et valider un aller-retour de conversation téléphone-à-téléphone.
