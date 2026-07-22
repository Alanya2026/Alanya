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
| **7** | 🟡 Livré (tests + docs) — **E2E Android à cocher manuellement** |

## Phase 7 — Performance, E2E, rollout

### 7.1 Tests automatisés

**Backend** (`npm run test:notifications:full`) :

- Suite existante + `notificationCallRouting`, `notificationIdempotence`, `notificationTokenStale`
- `test:calls` (glare / stale ringing)
- Bench mock : `scripts/bench/push-queue-bench.js` (P50/P95/P99)

**Flutter** (`test/notifications/`) :

- Suppression foreground, prefs cache, glare client (`call_glare_test.dart`, `foreground_suppression_test.dart`)
- Exécution locale : `flutter test test/notifications/` (bloquée ici : snap/root + téléchargement sqlite3)

### 7.2 Matrice E2E Android

- Document : [docs/notifications_e2e_matrix.md](docs/notifications_e2e_matrix.md)
- 11 scénarios Android staging ; iOS / flags avancés en section différée
- Statut exécution : **à cocher sur appareil** (environnement agent sans téléphone)

### 7.3 Rollout

- Guide : [docs/notifications_rollout.md](docs/notifications_rollout.md)
- Ordre flags, SQL migrations, métriques logs, rollback
- Migrations staging : **à appliquer depuis le réseau autorisé** (MySQL distant injoignable depuis l’agent)

## Phase 6 — rappel

- PushKit + APNs VoIP + CallKit glare / collision
- `call_ended` multi-appareil + dismiss VoIP
- Full-screen intent Android 14+

## Flags (état)

| Variable | Défaut | Staging | Prod |
|----------|--------|---------|------|
| `DEVICE_REGISTRY_V2` | `true` | à confirmer | à confirmer |
| `NOTIFICATION_ANDROID_NATIVE_V2` | `false` | off jusqu’à E2E #2–5 | off |
| `IOS_VOIP_V2` | `false` | off (iOS différé) | off |
| `IOS_RICH_NSE` | `false` | off | off |

## Migrations SQL

020 `user_push_devices` · 021 `user_notification_prefs` · 022 `conv_participants_mute`

## Risques résiduels

- E2E Android non encore coché sur téléphone réel
- iOS PushKit / NSE non validés
- OEM (Xiaomi/Samsung) non couverts
- Commit Backend Phase 6.3–7 partiel si `.git` non inscriptible depuis l’agent — vérifier `git status` sur Alanya-Backend

## Commandes

```bash
cd Alanya-Backend && npm run test:notifications:full
cd Talky && flutter test test/notifications/
```

---

*Chantier notifications v2 — Talky / Alanya-Backend.*
