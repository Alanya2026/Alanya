# Rapport d'implémentation — Notifications v2

Date : 2026-07-22  
Dépôts : Talky + Alanya-Backend

## Synthèse par phase

| Phase | Statut |
|-------|--------|
| **0–2** | ✅ Complet (code) |
| **3** | ✅ Badge, prefs, mute, buffer chiffré |
| **4** | 🟡 Android natif livré — **désactivé par défaut** |
| **5** | 🟡 iOS catégories + APNs — NSE template (target Xcode manuel) |
| **6** | 🟡 6.1–6.4 livrés (code) — validation appareil requise |
| **7** | ⚠️ Matrice E2E non faite |

## Phase 6 — Appels (livré code)

### 6.1 PushKit iOS
- Token VoIP → backend (`user_push_devices.voipToken`)
- Push entrant → CallKit natif immédiat

### 6.2 Provider APNs VoIP
- `apnsVoipProvider.js` + `sendCallToUser`
- Fallback FCM si VoIP indisponible

### 6.3 Cycle CallKit
- `actionCallIncoming` → sync état Flutter (`handleIncomingCallKitPreview`)
- Collision : fin de l'appel CallKit précédent avant le suivant
- `call_ended` multi-appareil + push VoIP dismiss iOS (`sendCallEndedToUser`)
- Cold start : repli `activeCalls()` + pending actions (existant, renforcé)

### 6.4 Android 13–15
- `CallPermissionsHelper` : POST_NOTIFICATIONS + full-screen intent (API 34+)
- MethodChannel `com.alanya/call_permissions` → réglages système si refusé
- Manifest : `USE_FULL_SCREEN_INTENT`, `FOREGROUND_SERVICE_PHONE_CALL` (déjà présents)

## Activation

```bash
# Backend VoIP
IOS_VOIP_V2=true
APNS_KEY_ID=... APNS_TEAM_ID=... APNS_BUNDLE_ID=com.example.talkyFlutter

# Android natif messages (Phase 4)
NOTIFICATION_ANDROID_NATIVE_V2=true
```

## Prochaines étapes

1. **Phase 7** : matrice E2E (`docs/notifications_e2e_matrix.md`) + tests charge
2. Validation appareil iOS : PushKit entrant app tuée, accept/refuse/timeout
3. Validation Android 14+ : full-screen intent + appel tuée
4. Target Xcode NSE (Phase 5.3) si avatars lockscreen requis

---

*Chantier notifications v2 — Talky / Alanya-Backend.*
