# Rapport d'implémentation — Notifications v2

Date : 2026-07-22  
Branches : `feat/notifications-v2-whatsapp-like` (Talky + Alanya-Backend)

## Branches et SHAs (état au rapport)

| Dépôt | Branche | HEAD |
|-------|---------|------|
| Talky | `feat/notifications-v2-whatsapp-like` | `ee80d23` |
| Alanya-Backend | `feat/notifications-v2-whatsapp-like` | `182cbd2` |

Base : Talky `149d146` / Backend `5204e08` (main)

## Statut des 26 itérations

| Itération | Description | Statut |
|-----------|-------------|--------|
| **0.1** | Contrat payload v2 backend + parseur Flutter | ✅ Complet |
| **0.2** | Logs structurés + NotificationDiagnostics | ✅ Complet |
| **1.1** | Retrait skipIfDeviceOnline messages | ✅ Complet |
| **1.2** | NotificationDedupStore persistant | ✅ Complet |
| **1.3** | IDs stables, annulation, message_read_sync | ✅ Complet |
| **2.1** | Migration `user_push_devices` | ✅ Complet |
| **2.2** | API register/state/delete + PushDeviceCoordinator | ✅ Complet |
| **2.3** | Routage multi-appareil sendToUserDevices | ✅ Complet |
| **3.1** | unreadTotal + LauncherBadgeService | ⚠️ Partiel (sync à la lecture ; pas encore à chaque réception) |
| **3.2** | Préférences globales + status_view off | ⚠️ Backend filter ; pas d'UI |
| **3.3** | Mute conversation | ⚠️ Backend filter ; migration colonnes commentée ; pas d'UI |
| **3.4** | Confidentialité preview + buffer | ⚠️ Backend applyPreviewPolicy ; buffer SharedPreferences conservé |
| **4.1** | Couche Android native | ⚠️ Scaffold `TalkyFirebaseMessagingService` (désactivé) |
| **4.2** | MessagingStyle natif Person/Shortcut | ❌ Non implémenté |
| **4.3** | Quick reply RemoteInput | ❌ Non implémenté |
| **4.4** | Mark as read natif + summary | ❌ Non implémenté |
| **5.1** | aps-environment + thread-id/badge APNs | ⚠️ Backend APNs enrichi ; entitlements development ajoutés |
| **5.2** | UNNotificationCategory REPLY/MARK_READ | ❌ Non implémenté |
| **5.3** | Notification Service Extension avatar | ❌ Non implémenté |
| **6.1** | PushKit registration | ⚠️ Scaffold AppDelegate (env IOS_VOIP_V2=1) |
| **6.2** | Provider APNs VoIP backend | ❌ Non implémenté |
| **6.3** | Cycle CallKit iOS complet | ❌ Non implémenté |
| **6.4** | Durcissement appels Android 13–15 | ⚠️ Existant préservé ; pas de tests OEM |
| **7.1** | Tests charge/mock | ⚠️ Tests unitaires notifications uniquement |
| **7.2** | Matrice E2E | ❌ Non exécutée sur appareil |
| **7.3** | Feature flags rollout | ⚠️ Backend `notificationFlags.js` ; pas de doc déploiement complète |

## Migrations SQL

| Fichier | Description |
|---------|-------------|
| `migrations/020_user_push_devices.sql` | Registre multi-appareil |
| `migrations/021_notification_prefs_mute.sql` | Préférences + mute (colonnes mute en commentaire — appliquer manuellement si absentes) |

**Exécution** : appliquer manuellement sur la base de dev/staging. Non exécuté automatiquement dans ce chantier.

## Variables d'environnement

| Variable | Défaut | Rôle |
|----------|--------|------|
| `ALWAYS_PUSH_MESSAGES` | `true` | Toujours FCM messages |
| `DEVICE_REGISTRY_V2` | `true` | Routage multi-appareil |
| `NOTIFICATION_ANDROID_NATIVE_V2` | `false` | Couche Android native |
| `IOS_CATEGORIES_V2` | `false` | Catégories iOS interactives |
| `IOS_VOIP_V2` | `false` | PushKit (build iOS : env Xcode) |
| `PUSH_HEARTBEAT_FRESH_MS` | `90000` | Fraîcheur skip foreground |
| `FIREBASE_SERVICE_ACCOUNT` | — | Firebase Admin (existant) |

## Feature flags

Backend : `src/notifications/notificationFlags.js`  
Android natif : `TalkyFirebaseMessagingService.NATIVE_V2_ENABLED = false`  
iOS VoIP : `IOS_VOIP_V2=1` dans l'environnement de build Xcode

## Tests exécutés

### Backend
```bash
npm run test:notifications
```
- notificationContract.test.js ✅
- notificationLogger.test.js ✅
- notificationPolicy.test.js ✅
- pushDeviceRegistry.test.js ✅
- `node --check` sur fichiers modifiés ✅

### Flutter
```bash
flutter test test/notifications/
flutter test test/local_notification_helper_test.dart
flutter analyze (fichiers modifiés)
```
✅ Tous les tests notifications passent.

### Non exécutés (environnement / credentials)
- Push FCM/APNs réels
- PushKit sur appareil iOS
- Archive IPA signée / `codesign --entitlements`
- `adb shell dumpsys notification` annulation FCM vs locale
- Build Android debug complet (`./gradlew assembleDebug`)
- Build iOS / `pod install` (macOS non disponible ou non exécuté)
- Tests OEM Samsung/Xiaomi
- Migration SQL sur base MySQL live

## Configuration manuelle requise

### Firebase
- Vérifier `FIREBASE_SERVICE_ACCOUNT` sur le backend
- Canaux Android `talky_messages` / `talky_meetings` déjà déclarés côté client

### Apple
- Activer **Push Notifications** dans Xcode Signing & Capabilities
- Remplacer `aps-environment: development` par `production` pour Release
- Activer **Background Modes** : Remote notifications, Voice over IP
- Créer certificat/clé APNs VoIP pour Phase 6 (aucun secret committé)
- Notification Service Extension (Phase 5.3) : créer target Xcode manuellement

### Google Play / Android
- `POST_NOTIFICATIONS` runtime Android 13+
- Full-screen intent permission Android 14+ (paramètres utilisateur)

## Risques résiduels

1. **Annulation FCM auto vs locale** — IDs/tags alignés côté Flutter ; notifications FCM système Android peuvent subsister (vérifier via `adb dumpsys notification`).
2. **MessagingStyle background** — toujours dépendant FCM `notification` block tant que native v2 désactivé.
3. **PushKit** — scaffold seulement ; appels iOS app tuée non garantis.
4. **Mute UI** — filtre backend actif si colonnes DB présentes ; pas de UI pour configurer.
5. **Multi-appareil** — nécessite migration 020 appliquée + clients à jour pour register push-devices.

## Procédure de rollback

1. Backend : `git revert` commits notifications ou désactiver flags :
   - `DEVICE_REGISTRY_V2=false`
   - `NOTIFICATION_ANDROID_NATIVE_V2=false`
2. Réactiver temporairement skip socket (non recommandé) : restaurer `skipIfDeviceOnline: true` dans une hotfix branch.
3. Flutter : déployer build précédent ; les anciens clients ignorent les champs v2.
4. DB : ne pas supprimer `user_push_devices` ; table inerte si rollback code seulement.

## Checklist déploiement

- [ ] Appliquer migration 020 sur staging/prod
- [ ] Appliquer migration 021 (+ colonnes mute si absentes)
- [ ] Vérifier entitlements APNs sur IPA signée
- [ ] Tester message foreground/autre écran/background sur 2 appareils
- [ ] Valider badge launcher iOS/Android
- [ ] Valider status_view silencieux par défaut
- [ ] Planifier Phase 4 native Android avant promesse « WhatsApp-like » UI

---

*Généré dans le cadre du chantier notifications v2 — Talky / Alanya-Backend.*
