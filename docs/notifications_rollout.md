# Rollout notifications v2 — flags, migrations, rollback

## Ordre d’activation recommandé

| Ordre | Flag / action | Environnement | Rollback |
|------:|---------------|---------------|----------|
| 1 | Migrations SQL **020 → 021 → 022** | staging puis prod | — (idempotentes) |
| 2 | `DEVICE_REGISTRY_V2=true` | déjà défaut | `false` → fallback `users.fcm_token` |
| 3 | `ALWAYS_PUSH_MESSAGES=true` | déjà défaut | `false` (déconseillé) |
| 4 | `NOTIFICATION_ANDROID_NATIVE_V2` | staging Android test | `false` + Gradle `talkyNotificationNativeV2=false` / `talkyFlutterFcmEnabled=true` |
| 5 | `IOS_VOIP_V2` + `APNS_*` | staging iOS (plus tard) | `false` → FCM data-only auto |
| 6 | `IOS_RICH_NSE` | optionnel | `false` |
| 7 | `IOS_CATEGORIES_V2` | optionnel (catégories déjà enregistrées côté app) | `false` |

**Ne pas supprimer** `users.fcm_token` tant que l’adoption `user_push_devices` est insuffisante (seuil cible **> 95 %**).

### Métrique d’adoption (SQL)

```sql
-- Utilisateurs avec au moins un appareil enregistré
SELECT
  (SELECT COUNT(DISTINCT alanyaID) FROM user_push_devices) AS with_devices,
  (SELECT COUNT(*) FROM users WHERE fcm_token IS NOT NULL AND fcm_token != 'INDEFINI') AS with_legacy_token;
```

---

## Appliquer les migrations

Fichiers :

- [migrations/020_user_push_devices.sql](../../Alanya-Backend/migrations/020_user_push_devices.sql)
- [migrations/021_notification_prefs_mute.sql](../../Alanya-Backend/migrations/021_notification_prefs_mute.sql)
- [migrations/022_conv_participants_mute.sql](../../Alanya-Backend/migrations/022_conv_participants_mute.sql)

```bash
cd Alanya-Backend
# Exemple mysql client (adapter host/port/user)
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  < migrations/020_user_push_devices.sql
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  < migrations/021_notification_prefs_mute.sql
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  < migrations/022_conv_participants_mute.sql
```

Puis redémarrer le process Node staging.

> Note agent 2026-07-22 : connexion MySQL staging (`163.123.183.89`) injoignable depuis l’environnement d’implémentation — à exécuter depuis le réseau autorisé / machine de déploiement.

---

## Variables APNs VoIP (quand iOS)

Voir [.env.example](../../Alanya-Backend/.env.example) :

```bash
IOS_VOIP_V2=true
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_BUNDLE_ID=com.example.talkyFlutter
APNS_KEY_PATH=/path/to/AuthKey_XXXX.p8
# ou APNS_KEY_P8=...
APNS_PRODUCTION=false   # true en Release
APNS_VOIP_TTL_SEC=60
```

Aucun secret `.p8` / Firebase JSON dans Git.

---

## Métriques avant / après (logs)

Source : `notificationLogger.js` — préfixe `[NotifTrace]`.

```bash
# Taux sent vs skipped (exemple jq sur fichier JSONL)
rg 'NotifTrace' app.log | jq -r '.event' | sort | uniq -c

# Tokens périmés
rg 'notification_token_stale' app.log | wc -l

# Échecs
rg 'notification_failed' app.log | wc -l
```

Comparer sur une fenêtre 24 h avant/après chaque flag avancé.

---

## Rollback rapide

| Symptôme | Action |
|----------|--------|
| Doublons Android natif | `NOTIFICATION_ANDROID_NATIVE_V2=false` + rebuild Flutter FCM enabled |
| Appels iOS fantômes / crash VoIP | `IOS_VOIP_V2=false` (FCM conserve les appels) |
| Mute / prefs SQL cassés | Feature client ignore colonnes absentes ; pas de rollback schema urgent |
| Registre appareils | `DEVICE_REGISTRY_V2=false` → `sendToUserLegacy` |

---

## Compatibilité anciens clients

- Anciens APK sans `push-devices/register` : token legacy `users.fcm_token` toujours utilisé en fallback.
- Payload v2 rétrocompatible côté Flutter (`notification_payload.dart`).
- Mute / prefs : défauts serveur si table absente ou ligne manquante.

---

## Checklist clôture Phase 7

- [ ] `npm run test:notifications:full` OK
- [ ] `flutter test test/notifications/` OK (machine dev)
- [ ] Migrations 020–022 appliquées staging
- [ ] Matrice Android ≥ 9/11 ([notifications_e2e_matrix.md](notifications_e2e_matrix.md))
- [ ] Rapport final à jour
- [ ] Aucun secret committé

---

*Phase 7.3 — Talky / Alanya-Backend.*
