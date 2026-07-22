# Plan complet — Notifications Talky « niveau messagerie moderne »

## 1. Objectif et périmètre

Ce plan concerne les deux dépôts :

- **Frontend Flutter** : `Talky`
- **Backend Node.js** : `Alanya-Backend`

L’objectif est d’obtenir un comportement fonctionnel comparable à une messagerie moderne de type WhatsApp, sans reproduire sa marque ni ses éléments propriétaires :

- aucune notification de message perdue ;
- aucune notification en double ;
- aucune notification sonore lorsque la conversation est visible au premier plan ;
- une notification par conversation avec historique récent ;
- titres corrects pour discussions directes et groupes ;
- annulation à la lecture, y compris multi-appareil ;
- badge global non lu ;
- mute et confidentialité ;
- actions « Répondre » et « Marquer comme lu » ;
- tokens par appareil ;
- appels Android fiables ;
- appels iOS via PushKit + CallKit ;
- observabilité, tests de non-régression et documentation d’exploitation.

---

## 2. Définition d’une itération

Une **itération** est une tranche verticale vérifiable qui doit produire :

1. un changement de code limité et cohérent ;
2. une migration idempotente si nécessaire ;
3. des tests automatisés ;
4. les vérifications statiques disponibles ;
5. un commit dédié ;
6. une courte note de résultat et les risques résiduels.

Une itération ne signifie pas nécessairement une journée. Composer doit éviter de regrouper plusieurs risques majeurs dans un même commit.

---

## 3. Vue d’ensemble

| Phase | Sujet | Itérations |
|---|---|---:|
| 0 | Baseline, contrat et instrumentation | 2 |
| 1 | Fiabilité immédiate des messages | 3 |
| 2 | Registre multi-appareil et état par appareil | 3 |
| 3 | Badge, mute et confidentialité | 4 |
| 4 | Notifications Android riches et actions | 4 |
| 5 | Notifications iOS messages | 3 |
| 6 | Appels iOS PushKit + durcissement appels Android | 4 |
| 7 | Performance, charge, matrice E2E et déploiement progressif | 3 |
| **Total** |  | **26 itérations** |

### Ordre impératif

Les phases doivent être réalisées dans cet ordre. En particulier :

- ne pas afficher une notification depuis le socket tout en conservant un FCM automatique sans déduplication ;
- ne pas activer les quick replies avant l’idempotence et l’authentification background ;
- ne pas supprimer l’ancien champ `users.fcm_token` avant migration complète vers les appareils ;
- ne pas basculer les appels iOS sur PushKit sans fallback et instrumentation.

---

# Phase 0 — Baseline, contrat et instrumentation

## But

Créer une base mesurable avant de modifier le comportement. Éviter les régressions invisibles et rendre chaque notification traçable de bout en bout.

## Nombre d’itérations : 2

### Itération 0.1 — Contrat canonique des notifications

#### Backend

Créer un module central de contrat, par exemple :

```text
src/notifications/notificationContract.js
```

Définir les types :

- `message`
- `message_read_sync`
- `call`
- `group_call`
- `call_ended`
- `meeting_invite`
- `meeting_reminder`
- `status_view`

Définir pour un message un payload versionné :

```json
{
  "schemaVersion": "2",
  "eventId": "notif_<uuid>",
  "type": "message",
  "msgID": "123",
  "clientId": "c_...",
  "conversationId": "45",
  "senderId": "10",
  "senderName": "Alice",
  "senderAvatar": "https://...",
  "title": "Alice",
  "body": "Bonjour",
  "msgType": "0",
  "isGroup": "0",
  "groupName": "",
  "groupAvatar": "",
  "sentAt": "ISO-8601",
  "unreadTotal": "5"
}
```

Règles :

- toutes les valeurs FCM `data` doivent être des chaînes ;
- `eventId` identifie l’envoi de notification ;
- `msgID` est la clé de déduplication métier ;
- `conversationId` est la clé de regroupement ;
- aucun token, secret ou contenu non nécessaire dans le payload ;
- preview générique lorsque la confidentialité l’exige.

#### Flutter

Créer un parseur typé et rétrocompatible, par exemple :

```text
lib/core/services/notifications/notification_payload.dart
```

Il doit accepter l’ancien payload et le payload v2, sans exception fatale.

#### Tests

- payload message direct ;
- groupe ;
- média ;
- payload incomplet ;
- ancien format ;
- valeurs numériques converties en chaînes.

#### Critère d’acceptation

Aucun comportement visible ne change encore. Tous les producteurs et consommateurs futurs peuvent utiliser un contrat documenté.

---

### Itération 0.2 — Traçage et métriques

#### Backend

Ajouter des logs structurés sans contenu sensible :

```text
notification_queued
notification_skipped
notification_sent
notification_failed
notification_token_stale
```

Champs minimaux :

- `eventId`
- `type`
- `userId`
- `deviceId` anonymisé ou hashé
- `conversationId`
- `msgID`
- `providerMessageId`
- `reason`
- `durationMs`

Ne jamais logger le token FCM/APNs complet ni le corps intégral d’un message.

#### Flutter

Ajouter des traces :

- push reçu foreground ;
- push reçu background ;
- socket reçu ;
- notification affichée ;
- notification dédupliquée ;
- notification supprimée ;
- tap/action ;
- navigation terminée/échouée.

Créer une petite abstraction `NotificationDiagnostics` désactivable en release ou limitée aux métadonnées.

#### Critère d’acceptation

Un même `eventId/msgID` peut être suivi du backend jusqu’à l’affichage ou la suppression client.

---

# Phase 1 — Fiabilité immédiate des messages

## But

Fermer le trou critique `socket connecté != application visible`, sans introduire de doublon.

## Nombre d’itérations : 3

### Itération 1.1 — Retirer le skip FCM pour les messages uniquement

#### Backend

Dans `notifyNewMessage`, ne plus appeler `sendToUser` avec :

```js
{ io, skipIfDeviceOnline: true }
```

Les appels et réunions gardent leur comportement actuel pour cette itération.

Ne pas encore ajouter de notification locale dans `onMessageReceived`.

#### Flutter

Conserver :

- suppression si conversation visible au premier plan ;
- notification locale dans `PushService` lorsque l’app est au premier plan sur un autre écran ;
- affichage système FCM en arrière-plan/app tuée.

#### Tests

Backend :

- message vers utilisateur avec socket → FCM quand même appelé ;
- appel → comportement inchangé ;
- réunion → comportement inchangé.

Flutter :

- chat visible → pas de notification locale ;
- autre écran foreground → notification ;
- tap → bonne conversation.

#### Critère d’acceptation

Un message ne disparaît plus simplement parce que le destinataire possède un socket connecté.

---

### Itération 1.2 — Déduplication persistante

#### Flutter

Créer `NotificationDedupStore` :

- clé prioritaire `message:<msgID>` ;
- fallback `event:<eventId>` ;
- TTL recommandé : 24 à 48 h ;
- taille bornée, par exemple 1 000 entrées ;
- opérations atomiques autant que possible ;
- compatible isolate background et isolate principal.

Avant tout affichage local :

```text
si déjà affiché/traité → ignorer
sinon réserver la clé → afficher → confirmer
```

Distinguer les états :

- `reserved`
- `shown`
- `read/cancelled`

Éviter qu’une erreur d’affichage bloque définitivement une notification.

#### Backend

Inclure `msgID`, `clientId`, `eventId` dans le push message.

#### Tests

- socket puis FCM ;
- FCM puis socket ;
- deux FCM identiques ;
- redémarrage entre les deux ;
- erreur d’affichage après réservation ;
- deux conversations différentes.

#### Critère d’acceptation

Au maximum une notification visible par message et par appareil.

---

### Itération 1.3 — Propriétaire d’affichage et annulation cohérente

#### Android

Définir une fonction stable pour l’ID de notification par conversation. Ne pas dépendre d’un `hashCode` Dart non contractuel entre exécutions.

Exemple : hash FNV-1a 31 bits documenté ou mapping persistant.

Centraliser :

```text
notificationIdForConversation(conversationId)
notificationTagForConversation(conversationId)
```

Vérifier l’annulation locale et documenter la limite des notifications auto-générées FCM.

#### Flutter

À l’ouverture/lecture :

- annuler la notification ;
- vider le buffer ;
- marquer les `msgID` de la conversation comme lus dans le dedup store ;
- ne pas réafficher un push retardé correspondant.

#### Backend

Ajouter un événement silencieux `message_read_sync` ou enrichir `inbox:sync` afin que les autres appareils puissent supprimer la notification correspondante.

#### Critère d’acceptation

Une notification lue ne réapparaît pas à cause d’un push retardé.

---

# Phase 2 — Registre multi-appareil et état par appareil

## But

Remplacer le token unique par utilisateur par un registre de terminaux, sans migration destructive.

## Nombre d’itérations : 3

### Itération 2.1 — Migration `user_push_devices`

Créer une migration SQL idempotente :

```sql
CREATE TABLE user_push_devices (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  alanyaID INT NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  platform ENUM('android','ios','web','unknown') NOT NULL DEFAULT 'unknown',
  fcmToken VARCHAR(2048) NULL,
  voipToken VARCHAR(2048) NULL,
  locale VARCHAR(16) NULL,
  notificationsEnabled TINYINT NOT NULL DEFAULT 1,
  appState ENUM('foreground','background','unknown') NOT NULL DEFAULT 'unknown',
  activeConversationId BIGINT NULL,
  lastHeartbeatAt DATETIME NULL,
  tokenUpdatedAt DATETIME NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_push_device_user_device (alanyaID, deviceId),
  KEY idx_push_device_user_enabled (alanyaID, notificationsEnabled),
  KEY idx_push_device_token (fcmToken(191)),
  CONSTRAINT fk_push_device_user FOREIGN KEY (alanyaID)
    REFERENCES users(alanyaID) ON DELETE CASCADE
);
```

Adapter si la version MySQL ne supporte pas une syntaxe donnée.

Conserver temporairement `users.fcm_token` et `users.device_ID` comme fallback.

#### Tests

- migration sur base vide ;
- migration sur base existante ;
- réexécution sûre ;
- contraintes d’unicité.

---

### Itération 2.2 — API d’enregistrement et lifecycle par appareil

Créer ou étendre les endpoints authentifiés :

```text
POST /api/auth/push-devices/register
POST /api/auth/push-devices/state
DELETE /api/auth/push-devices/:deviceId
```

`register` fait un upsert de :

- deviceId stable ;
- plateforme ;
- token FCM ;
- locale.

`state` reçoit :

- `foreground/background` ;
- `activeConversationId` ;
- timestamp/heartbeat.

Sécurité : l’utilisateur ne peut modifier que ses propres appareils.

Flutter doit mettre à jour l’état lors de :

- login ;
- refresh token FCM ;
- resumed ;
- paused/hidden/detached ;
- ouverture/fermeture d’une conversation ;
- logout.

Limiter les heartbeats et les écritures avec debounce/throttle.

---

### Itération 2.3 — Routage push multi-appareil

#### Backend

`sendToUser` devient `sendToUserDevices` :

- lire tous les appareils actifs ;
- envoyer en parallèle avec concurrence bornée ou multicast ;
- supprimer/désactiver uniquement le token invalide concerné ;
- fallback vers `users.fcm_token` pendant la transition ;
- ne pas envoyer au terminal qui confirme être `foreground + conversation active + heartbeat récent` ;
- envoyer aux autres terminaux.

Définir « récent », par exemple 60 à 90 secondes, configurable par environnement.

#### Tests

- deux téléphones ;
- téléphone + web ;
- un token invalide ;
- un appareil dans le chat et un autre verrouillé ;
- état foreground périmé ;
- absence de ligne nouvelle avec fallback legacy.

#### Critère d’acceptation

Le dernier login ne prive plus les autres appareils de notifications.

---

# Phase 3 — Badge, mute et confidentialité

## But

Donner à l’utilisateur le contrôle attendu et synchroniser les compteurs.

## Nombre d’itérations : 4

### Itération 3.1 — Total non lu canonique et badge

#### Backend

Définir une source de vérité du total non lu. Ajouter `unreadTotal` dans les pushes et réponses de synchronisation.

Éviter les recalculs coûteux à chaque push si `conv_participants.unreadCount` est déjà fiable :

```sql
SELECT COALESCE(SUM(unreadCount), 0)
FROM conv_participants
WHERE alanyaID = ?;
```

Optimiser/indexer si nécessaire.

#### Flutter

Créer `LauncherBadgeService` :

- iOS : badge numérique explicite ;
- Android : API/plugin compatible avec fallback si le launcher ne supporte pas ;
- mise à jour après réception, lecture, suppression, sync et logout ;
- remise à zéro au logout.

Ne pas confondre badge in-app et badge launcher.

#### Tests

- 0, 1, 99, >99 ;
- lecture locale ;
- lecture autre appareil ;
- cold start ;
- logout.

---

### Itération 3.2 — Préférences globales

Créer une table ou des colonnes dédiées aux préférences :

- messages privés ;
- groupes ;
- appels ;
- réunions ;
- vues de statut ;
- son ;
- vibration ;
- preview.

Valeurs par défaut sûres :

- messages/appels activés ;
- vues de statut désactivées ;
- preview configurable ;
- réunions activées si produit requis.

Ajouter API GET/PATCH et écran Flutter.

---

### Itération 3.3 — Mute par conversation

Étendre `conv_participants` avec une migration :

```text
mutedUntil DATETIME NULL
muteForever TINYINT DEFAULT 0
mentionsOnly TINYINT DEFAULT 0
customSound VARCHAR(...) NULL (optionnel, peut rester réservé)
```

UI :

- 8 heures ;
- 1 semaine ;
- toujours ;
- réactiver ;
- éventuellement mentions uniquement pour groupes.

Backend : filtrer avant FCM. Le message continue à être livré par socket et stocké ; seule l’alerte est supprimée/silencieuse selon la règle.

Une conversation archivée continue à notifier par défaut, sauf mute explicite ou préférence produit documentée.

---

### Itération 3.4 — Confidentialité et écran verrouillé

Modes :

1. nom + contenu ;
2. nom seulement ;
3. texte générique « Nouveau message ».

Backend doit minimiser le payload selon la préférence, car masquer seulement à l’affichage laisse le contenu dans le push.

Android :

- visibilité privée ;
- `publicVersion` générique si disponible ;
- contenu complet uniquement dans la notification privée.

IPhone/iPad : corps APNs générique selon préférence.

Ne plus stocker le buffer de message en clair dans `SharedPreferences` : migrer vers SQLite borné ou stockage approprié. Purger l’ancien buffer.

---

# Phase 4 — Notifications Android riches et actions

## But

Obtenir une notification Android de niveau messagerie avec historique, avatar et actions fiables.

## Nombre d’itérations : 4

### Itération 4.1 — Couche propriétaire Android

Choisir après inspection de la compatibilité des plugins :

- préférence : service Android natif `FirebaseMessagingService` + `NotificationCompat` ;
- alternative acceptable : handler background Flutter uniquement si les tests app tuée/OEM prouvent sa fiabilité.

Éviter deux services FCM concurrents avec `firebase_messaging`. Examiner le manifeste fusionné et documenter l’intégration.

Basculer les messages Android vers `data-only high priority` uniquement lorsque la couche propriétaire est prête et derrière un feature flag backend :

```text
NOTIFICATION_ANDROID_NATIVE_V2
```

Conserver un rollback vers le bloc `notification` FCM.

---

### Itération 4.2 — `MessagingStyle`, personnes et avatars

Implémenter :

- `NotificationCompat.MessagingStyle` ;
- `Person` stable par senderId ;
- historique récent par conversation ;
- `ShortcutInfoCompat` et `shortcutId` ;
- `CATEGORY_MESSAGE` ;
- titre groupe + `sender: message` ;
- avatar contact/groupe téléchargé avec timeout, cache et fallback ;
- petite icône monochrome Alanya ;
- aucune image distante bloquante sur le chemin critique.

Créer les canaux versionnés si leur importance/son doit changer, car un canal Android existant ne peut pas être reconfiguré librement.

---

### Itération 4.3 — Quick reply Android

Ajouter une action `RemoteInput` :

- générer un `clientId` idempotent ;
- envoyer via endpoint HTTP authentifié ;
- afficher temporairement la réponse dans l’historique de notification ;
- retry borné via WorkManager si réseau absent ;
- ne jamais envoyer deux fois ;
- retirer/mettre à jour la notification après confirmation.

Stocker les informations d’authentification background de manière sécurisée. Ne pas ajouter un token en clair dans un nouveau fichier de préférences. Réutiliser ou renforcer le stockage sécurisé existant.

Ajouter un endpoint dédié si l’endpoint actuel ne garantit pas `clientId` et l’idempotence.

---

### Itération 4.4 — « Marquer comme lu », summary et tests Android

Ajouter action « Marquer comme lu » :

- API idempotente ;
- annulation immédiate de la conversation ;
- mise à jour badge ;
- propagation multi-appareil.

Ajouter un résumé Android optionnel lorsque plusieurs conversations ont des notifications, sans écraser les notifications enfants.

Tester :

- Android 8, 12, 13, 14, 15 ;
- écran verrouillé ;
- Doze ;
- notification refusée ;
- réponse offline ;
- plusieurs conversations ;
- groupe ;
- média ;
- lecture depuis un autre appareil.

---

# Phase 5 — Notifications iOS messages

## But

Corriger la signature/capability, le regroupement, le badge et les actions iOS.

## Nombre d’itérations : 3

### Itération 5.1 — Capabilities et APNs

Ajouter et documenter :

- capability Push Notifications ;
- entitlement `aps-environment` géré correctement selon build ;
- Background Modes → Remote notifications ;
- vérification archive avec `codesign`.

Ne jamais committer de certificat `.p12`, clé `.p8` ou secret APNs.

Backend APNs :

- `thread-id: conv_<id>` ;
- `category: ALANYA_MESSAGE` ;
- `badge: unreadTotal` ;
- `sound` selon préférences ;
- `interruption-level` approprié, sans abus de `time-sensitive` ;
- titre groupe correct.

---

### Itération 5.2 — Catégories et actions iOS

Enregistrer `UNNotificationCategory` :

- `REPLY` avec saisie texte ;
- `MARK_AS_READ` ;
- catégorie `ALANYA_MESSAGE`.

Traiter les actions en foreground/background avec idempotence et authentification sûre.

Mettre à jour badge et annuler le thread/contenu lu autant que permis par iOS.

---

### Itération 5.3 — Notification Service Extension et avatars

Si le produit exige des avatars/images riches :

- créer une Notification Service Extension ;
- utiliser `mutable-content: 1` ;
- télécharger l’avatar avec timeout strict ;
- fallback systématique ;
- configurer App Group partagé ;
- vérifier les targets, provisioning et tailles d’extension.

Cette itération peut être désactivée par feature flag si la signature iOS n’est pas disponible dans l’environnement Composer.

---

# Phase 6 — Appels iOS PushKit et durcissement Android

## But

Rendre les appels entrants fiables lorsque l’application iOS est suspendue ou tuée, et valider les restrictions Android récentes.

## Nombre d’itérations : 4

### Itération 6.1 — Enregistrement PushKit iOS

Dans iOS natif :

- `PKPushRegistry` ;
- type `.voIP` ;
- réception/rotation du token VoIP ;
- transmission au backend avec `deviceId` ;
- capability/background mode VoIP ;
- rapport immédiat à CallKit selon les exigences Apple.

Mettre à jour la table `user_push_devices.voipToken`.

---

### Itération 6.2 — Provider APNs VoIP backend

Implémenter un fournisseur APNs VoIP séparé de FCM :

- authentification par clé `.p8` via variables d’environnement ;
- topic `<bundle-id>.voip` ;
- `apns-push-type: voip` ;
- priorité 10 ;
- expiration courte ;
- collapse/apns-id appropriés ;
- nettoyage token invalide ;
- logs structurés.

Fournir `.env.example` sans secret et documentation de configuration.

Conserver un fallback contrôlé tant que le déploiement PushKit n’est pas confirmé.

---

### Itération 6.3 — Cycle CallKit iOS complet

Couvrir :

- affichage entrant ;
- accepter ;
- refuser ;
- timeout ;
- appel terminé avant réponse ;
- appel manqué ;
- groupe ;
- collision de deux appels ;
- cold start ;
- synchronisation Flutter après action native ;
- absence d’appel fantôme.

Utiliser `callId` comme clé d’idempotence et vérifier les délais imposés par iOS.

---

### Itération 6.4 — Android appels Android 13–15

Valider/implémenter :

- permission notifications ;
- full-screen intent Android 14+ ;
- `canUseFullScreenIntent` et écran de réglage si nécessaire ;
- foreground service phone call ;
- écran verrouillé ;
- mode silencieux/DND ;
- refus app tuée ;
- `call_ended` ;
- appel manqué et rappel ;
- OEM Samsung/Xiaomi/Oppo.

Ne pas casser la reprise d’appel sortant auditée séparément.

---

# Phase 7 — Performance, charge, E2E et déploiement progressif

## But

Prouver la fiabilité, prévoir le rollback et éviter les régressions en production.

## Nombre d’itérations : 3

### Itération 7.1 — Tests automatisés et charge backend

Ajouter :

- tests unitaires contrat ;
- tests routage appareils ;
- tests mute/privacy ;
- tests token invalide ;
- tests idempotence reply/read ;
- tests de charge FCM avec mocks ;
- concurrence bornée pour groupes ;
- mesures P50/P95/P99 de mise en file push.

Ne pas appeler réellement FCM/APNs dans les tests standards.

---

### Itération 7.2 — Matrice E2E appareils

Documenter et, autant que possible, automatiser :

- foreground chat ouvert ;
- foreground autre écran ;
- background avec socket ;
- background sans socket ;
- app retirée des tâches ;
- téléphone verrouillé ;
- Doze/économie d’énergie ;
- offline puis retour réseau ;
- deux appareils ;
- groupe ;
- conversation mute ;
- preview privée ;
- reply/read ;
- appel entrant/terminé.

Utiliser `adb shell dumpsys notification --noredact` pour valider IDs/tags/canaux Android.

Pour iOS, valider les entitlements de l’archive signée avec `codesign`.

---

### Itération 7.3 — Feature flags, rollout et nettoyage legacy

Feature flags recommandés :

```text
NOTIFICATION_ALWAYS_PUSH_MESSAGES
NOTIFICATION_DEVICE_REGISTRY_V2
NOTIFICATION_ANDROID_NATIVE_V2
NOTIFICATION_IOS_CATEGORIES_V2
NOTIFICATION_IOS_VOIP_V2
```

Prévoir :

- activation par pourcentage ou environnement ;
- métriques avant/après ;
- rollback ;
- compatibilité anciens clients ;
- suppression du fallback `users.fcm_token` seulement après adoption suffisante ;
- nettoyage des anciens buffers et canaux si possible ;
- documentation finale.

---

# 4. Critères globaux de réussite

Le chantier est terminé lorsque :

1. un message produit au maximum une notification par appareil ;
2. aucun message n’est silencieusement perdu à cause d’un socket connecté ;
3. la conversation visible au premier plan ne produit ni son ni notification ;
4. un message lu ne réapparaît pas ;
5. le badge correspond au total non lu ;
6. mute et confidentialité sont respectés côté backend et client ;
7. quick reply est idempotent ;
8. chaque appareil conserve son propre token ;
9. les groupes affichent groupe + expéditeur correctement ;
10. iOS regroupe via `thread-id` ;
11. les appels iOS app tuée utilisent PushKit ;
12. les appels terminés disparaissent rapidement ;
13. les versions clientes anciennes continuent à fonctionner pendant la migration ;
14. aucun secret Apple/Firebase n’est committé.

---

# 5. Prompt complet pour Composer 2.5

Copier le prompt ci-dessous dans Composer 2.5. Adapter uniquement les chemins si les dépôts ne sont pas frères.

```text
Tu es l’agent principal chargé d’implémenter un chantier complet de notifications dans deux dépôts auxquels tu as accès :

- frontend Flutter : Talky
- backend Node.js/MySQL/Socket.IO : Alanya-Backend

OBJECTIF
Mettre les notifications au niveau fonctionnel d’une messagerie moderne de type WhatsApp, sans copier sa marque ni ses assets : fiabilité foreground/background/app tuée, regroupement par conversation, aucune duplication, badge non lu, mute, confidentialité, actions Répondre/Marquer comme lu, multi-appareil, messages riches Android/iOS, PushKit+CallKit iOS et durcissement des appels Android.

IMPORTANT — COMMENCE PAR INSPECTER
1. Localise les deux racines Git et affiche leur branche, HEAD et état de travail.
2. Lis les fichiers existants avant toute modification, notamment :
   Frontend :
   - lib/core/services/push_service.dart
   - lib/core/services/local_notification_helper.dart
   - lib/core/services/notification_navigation.dart
   - lib/core/services/chat/socket_message_handlers.dart
   - lib/core/services/chat/chat_repository.dart
   - lib/core/services/chat/receipt_service.dart
   - lib/core/services/callkit_service.dart
   - lib/main.dart
   - android/app/src/main/AndroidManifest.xml
   - android/app/src/main/kotlin/**
   - ios/Runner/AppDelegate.swift
   - ios/Runner/Runner.entitlements
   - ios/Runner/Info.plist
   - pubspec.yaml
   Backend :
   - src/services/notificationService.js
   - src/socket/handlers/chat/messageSend.js
   - src/utils/userSocketRegistry.js
   - src/controllers/authCustomController.js
   - src/socket/handlers/calls.js
   - migrations/**
   - src/config/firebase.js
3. Vérifie les versions réelles des plugins et les manifestes fusionnés avant de choisir une intégration native.
4. Ne suppose pas qu’un commentaire décrit le comportement réel.

RÈGLES DE SÉCURITÉ ET DE QUALITÉ
- Ne déploie rien en production.
- Ne modifie ni ne committe aucun secret, certificat, .p8, .p12, token ou credential.
- N’efface aucune donnée ou migration existante.
- Toutes les migrations doivent être idempotentes ou avoir une stratégie d’exécution claire.
- Préserve la compatibilité avec les anciens clients pendant la migration.
- Ne supprime pas immédiatement users.fcm_token/device_ID : garde un fallback jusqu’à la phase finale.
- N’ajoute jamais une notification locale socket et un push automatique sans déduplication.
- Utilise msgID comme clé de déduplication principale, eventId comme clé secondaire.
- Ne journalise jamais le contenu complet des messages ni les tokens complets.
- Quick reply et mark-read doivent être authentifiés et idempotents.
- Ne stocke pas de nouveau token d’accès en clair.
- Ne casse pas les appels, réunions, statuts, synchronisation chat ou reprise d’appel sortant.
- N’édite pas manuellement les fichiers Flutter générés si une commande de génération existe ; régénère-les.
- Si Flutter/Xcode/Android SDK n’est pas disponible, réalise les contrôles statiques possibles et documente exactement les vérifications non exécutées.

MÉTHODE GIT
- Si les worktrees ne sont pas propres, n’écrase aucun changement utilisateur : documente-le et travaille sans perte, ou demande confirmation si conflit bloquant.
- Crée une branche dédiée dans chaque dépôt : feat/notifications-v2-whatsapp-like
- Une itération = un commit cohérent par dépôt concerné.
- Préfixe recommandé : feat(notifications), fix(notifications), test(notifications), docs(notifications).
- Après chaque itération, affiche : fichiers modifiés, tests, résultat, risques résiduels et SHA du commit.
- Ne pousse pas vers un remote sauf instruction explicite.

PLAN IMPÉRATIF — 26 ITÉRATIONS

PHASE 0 — BASELINE ET INSTRUMENTATION (2 itérations)
0.1 Contrat payload v2 : schemaVersion, eventId, msgID, clientId, conversationId, sender, groupe, sentAt, unreadTotal ; parseur Flutter rétrocompatible ; tests.
0.2 Logs structurés backend/client sans données sensibles ; traçage eventId/msgID de queue à affichage/annulation.

PHASE 1 — FIABILITÉ MESSAGES (3 itérations)
1.1 Retire skipIfDeviceOnline uniquement pour notifyNewMessage. N’ajoute pas encore de notification locale dans le handler socket. Préserve appels/réunions. Ajoute tests.
1.2 Ajoute NotificationDedupStore persistant, borné et TTL, compatible isolate principal/background. Inclure msgID/clientId/eventId dans le push. Tests socket→FCM, FCM→socket, doublon et redémarrage.
1.3 Centralise ID/tag de notification par conversation, annulation/lecture, buffer et protection contre push retardé. Ajoute propagation read-sync multi-appareil rétrocompatible.

PHASE 2 — MULTI-APPAREIL (3 itérations)
2.1 Migration user_push_devices avec deviceId, platform, fcmToken long, voipToken, locale, enabled, appState, activeConversationId, heartbeat et indexes. Garde fallback legacy.
2.2 Endpoints register/state/delete authentifiés + Flutter lifecycle/token refresh/conversation active avec throttle.
2.3 Routage à tous les appareils, concurrence bornée/multicast, invalidation token par appareil, skip seulement si même appareil foreground + conversation active + heartbeat récent. Tests multi-device.

PHASE 3 — BADGE, MUTE, CONFIDENTIALITÉ (4 itérations)
3.1 unreadTotal canonique + LauncherBadgeService iOS/Android avec fallback ; sync réception/lecture/logout/multi-device.
3.2 Préférences globales notifications : privé, groupes, appels, réunions, status_view, son, vibration, preview ; API + UI. status_view désactivé par défaut.
3.3 Mute conversation 8h/1 semaine/toujours, mentionsOnly groupe, migrations/API/UI/filtre backend. Archivé continue à notifier par défaut sauf préférence explicite.
3.4 Confidentialité nom+contenu/nom seul/générique ; minimisation payload backend ; lockscreen privé ; migration du buffer SharedPreferences vers stockage borné approprié.

PHASE 4 — ANDROID RICHE (4 itérations)
4.1 Mets en place une couche Android propriétaire fiable. Inspecte les conflits avec firebase_messaging. Préfère FirebaseMessagingService natif si compatible. Bascule data-only derrière NOTIFICATION_ANDROID_NATIVE_V2 avec rollback.
4.2 NotificationCompat.MessagingStyle, Person stable, ShortcutInfoCompat, CATEGORY_MESSAGE, historique par conversation, titre groupe correct, avatar avec cache/timeout/fallback, canaux versionnés.
4.3 Quick reply RemoteInput : clientId idempotent, endpoint authentifié, WorkManager retry borné offline, stockage auth sécurisé, confirmation et absence de doublon.
4.4 Mark as read, badge, annulation, propagation multi-device, summary parent multi-conversations ; tests Android 8/12/13/14/15 et cas lockscreen/Doze.

PHASE 5 — IOS MESSAGES (3 itérations)
5.1 Capabilities Push Notifications + aps-environment correctement géré et documenté ; APNs thread-id, category, badge, sound, interruption level, titres groupe. Aucun secret committé.
5.2 UNNotificationCategory ALANYA_MESSAGE avec REPLY text input et MARK_AS_READ ; handlers sûrs/idempotents ; badge et annulation.
5.3 Notification Service Extension pour avatar si possible, mutable-content, App Group, timeout/fallback. Feature flag si signature indisponible.

PHASE 6 — APPELS (4 itérations)
6.1 iOS PKPushRegistry VoIP, rotation token, enregistrement backend par appareil, capabilities/background voip.
6.2 Provider APNs VoIP backend par variables d’environnement : topic bundle.voip, push-type voip, priorité 10, expiration courte, invalidation token, logs, fallback.
6.3 Cycle CallKit iOS : incoming/accept/decline/timeout/end/missed/group/cold start/collision, callId idempotent, aucun fantôme.
6.4 Android 13–15 : notification permission, full-screen intent, FGS phone call, lockscreen, DND, app tuée, call_ended, missed callback, tests OEM documentés. Préserve la reprise d’appel sortant.

PHASE 7 — HARDENING ET ROLLOUT (3 itérations)
7.1 Tests unitaires/intégration/charge avec providers mockés, concurrence groupe, P50/P95/P99, aucun vrai push en tests standards.
7.2 Matrice E2E foreground/background/socket/app tuée/lockscreen/Doze/offline/multi-device/mute/privacy/reply/read/appels ; scripts et documentation adb/codesign.
7.3 Feature flags et rollout : ALWAYS_PUSH_MESSAGES, DEVICE_REGISTRY_V2, ANDROID_NATIVE_V2, IOS_CATEGORIES_V2, IOS_VOIP_V2 ; rollback, métriques, compatibilité anciens clients et plan de nettoyage legacy.

ARCHITECTURE CIBLE
- Backend : payload versionné, registre appareils, règles mute/privacy, routage par appareil, providers FCM/APNs/VoIP séparés, métriques.
- Flutter commun : parseur payload, dedup store, navigation, badge, préférences, synchronisation read.
- Android : une seule couche propriétaire de l’affichage riche ; IDs/tags déterministes ; actions background.
- iOS : APNs thread/category/badge pour messages ; PushKit+CallKit pour appels.

CRITÈRES D’ACCEPTATION GLOBAUX
1. Maximum une notification visible par message/appareil.
2. Aucun message perdu parce qu’un socket est connecté.
3. Aucun son/bannière pour la conversation visible au premier plan.
4. Lecture locale ou autre appareil supprime et empêche la réapparition.
5. Badge = total non lu.
6. Mute et confidentialité respectés serveur + client.
7. Quick reply idempotent, retry sûr.
8. Tous les appareils enregistrés reçoivent selon leur état.
9. Groupes : nom groupe + expéditeur corrects.
10. iOS : thread-id/category/badge.
11. iOS app tuée : appels via PushKit, pas push background ordinaire.
12. Android : appels conformes restrictions récentes.
13. Anciens clients continuent à fonctionner pendant rollout.
14. Aucun secret committé.

COMMANDES DE VALIDATION À UTILISER SI DISPONIBLES
Frontend :
- flutter pub get
- dart format --set-exit-if-changed . (ou format ciblé avant commit)
- flutter analyze
- flutter test
- ./gradlew lint/test sur Android si configuré
- build debug Android au minimum
- pod install / build iOS sans signature si environnement macOS disponible
Backend :
- npm ci
- node --check sur fichiers modifiés
- npm test si ajouté/configuré
- tests d’intégration avec DB/FCM/APNs mockés
- validation SQL des migrations

RAPPORT FINAL OBLIGATOIRE
À la fin, crée NOTIFICATIONS_V2_IMPLEMENTATION_REPORT.md contenant :
- branches et SHAs ;
- liste des 26 itérations et statut ;
- migrations ;
- variables d’environnement ;
- feature flags ;
- tests exécutés et non exécutés ;
- configuration manuelle Firebase/Apple/Google Play requise ;
- risques résiduels ;
- procédure de rollback ;
- checklist de déploiement.

MODE D’EXÉCUTION
- Exécute les phases dans l’ordre.
- Ne prétends jamais avoir validé un appareil, APNs, PushKit, une archive signée ou un OEM si tu ne l’as pas réellement fait.
- Si une décision d’architecture dépend d’un conflit plugin/manifeste, inspecte d’abord puis choisis l’option la plus sûre et documente la décision.
- Si une étape exige des credentials absents, implémente le code/configuration par variables d’environnement et marque le test réel « bloqué par credentials », sans inventer de résultat.
- Arrête-toi et signale toute migration destructive, conflit utilisateur ou risque de perte de données avant de poursuivre.
- Sinon, poursuis de façon autonome jusqu’au rapport final.
```

---

# 6. Recommandation pratique d’exécution

Même si le prompt autorise l’exécution autonome complète, il est recommandé de faire valider humainement les checkpoints suivants :

1. après la Phase 1 : vérifier qu’aucune notification message n’est perdue ou dupliquée ;
2. après la Phase 2 : vérifier migration et multi-appareil ;
3. après la Phase 4 : tester plusieurs appareils Android réels ;
4. après la Phase 5 : vérifier archive/signature iOS ;
5. après la Phase 6 : validation PushKit/CallKit sur iPhone réel ;
6. avant Phase 7.3 : autorisation explicite de rollout.

Composer peut écrire tout le code sans credentials, mais ne peut pas prouver seul la livraison APNs/FCM réelle, les restrictions OEM ou le comportement d’une archive iOS signée sans appareils et comptes configurés.
