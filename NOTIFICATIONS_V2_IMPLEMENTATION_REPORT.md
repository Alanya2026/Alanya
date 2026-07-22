# Rapport d'implémentation — Notifications v2

Date : 2026-07-22  
Dépôts : Talky + Alanya-Backend (`main`, non commité)

## Synthèse par phase

| Phase | Statut |
|-------|--------|
| **0–2** | ✅ Complet (code) |
| **3** | ✅ Badge, prefs, mute, buffer chiffré |
| **4** | 🟡 Android natif livré — **désactivé par défaut** |
| **5** | 🟡 iOS catégories + APNs — NSE template (target Xcode manuel) |
| **6** | 🟡 6.1–6.2 livrés — CallKit cycle complet / Android 13–15 à valider |
| **7** | ⚠️ Matrice E2E non faite |

## Phase 6 — Appels iOS PushKit (livré)

### 6.1 Enregistrement PushKit iOS
- `AppDelegate.swift` : `PKPushRegistry` + intégration `flutter_callkit_incoming`
- Token VoIP → plugin → event Dart → `PushDeviceCoordinator.registerVoipToken` → `user_push_devices.voipToken`
- Push VoIP entrant → `showCallkitIncoming(fromPushKit: true)` (exigence Apple)
- Re-sync token au login via `PushService.syncTokenWithBackend()`

### 6.2 Provider APNs VoIP backend
- `src/notifications/apnsVoipProvider.js` (HTTP/2 + JWT `.p8`)
- `sendCallToUser` : iOS + `IOS_VOIP_V2=true` + token VoIP → APNs VoIP ; sinon FCM data-only (fallback)
- Variables : `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_P8` ou `APNS_KEY_PATH`, `APNS_BUNDLE_ID`, `APNS_PRODUCTION`

### 6.3–6.4 (reste)
- Cycle CallKit cold start complet (collision, timeout, groupe)
- Matrice Android 13–15 OEM (full-screen intent, FGS)

## Phase 5 — iOS messages (rappel)

- Catégories `ALANYA_MESSAGE` + actions REPLY / MARK_AS_READ
- NSE template : `ios/NotificationServiceExtension/` (target Xcode manuel)
- `IOS_RICH_NSE=true` → `mutable-content`

## Phase 4 — Android (rappel activation)

```kotlin
manifestPlaceholders["talkyNotificationNativeV2"] = "true"
manifestPlaceholders["talkyFlutterFcmEnabled"] = "false"
```

```bash
NOTIFICATION_ANDROID_NATIVE_V2=true
```

## Variables d'environnement

| Variable | Défaut | Rôle |
|----------|--------|------|
| `NOTIFICATION_ANDROID_NATIVE_V2` | `false` | FCM data-only Android + Kotlin |
| `IOS_RICH_NSE` | `false` | `mutable-content` APNs avatars |
| `IOS_VOIP_V2` | `false` | Envoi appels via APNs VoIP |
| `APNS_BUNDLE_ID` | — | ex. `com.example.talkyFlutter` |
| `APNS_PRODUCTION` | `false` | `true` en prod Release |
| `DEVICE_REGISTRY_V2` | `true` | Multi-appareil |

## Migrations SQL

020 `user_push_devices` · 021 `user_notification_prefs` · 022 `conv_participants_mute`

## Tests

```bash
cd Alanya-Backend && npm run test:notifications
cd Talky && flutter test test/notifications/
```

## Prochaines étapes

1. Committer Phases 3–6 (Talky + Backend).
2. Appliquer migrations 020–022 sur staging.
3. Configurer clé APNs `.p8` sur staging + `IOS_VOIP_V2=true`.
4. Test iOS appareil : appel entrant app tuée via PushKit.
5. Phase 7 : matrice E2E + rollout progressif.

---

*Chantier notifications v2 — Talky / Alanya-Backend.*
