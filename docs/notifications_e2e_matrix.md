# Matrice E2E — Notifications Talky v2 (Android staging)

Date de création : 2026-07-22  
Environnement cible : **staging + Android** (iOS / flags avancés = différé)  
Critères globaux : voir [plan_notifications_composer.md](../plan_notifications_composer.md) §4 (14 points).

## Prérequis

- Backend staging redémarré (`DEVICE_REGISTRY_V2=true`, défaut).
- Migrations **020–022** appliquées (voir [notifications_rollout.md](notifications_rollout.md)).
- 2 comptes test + au moins 1 APK Android (idéal : 2 appareils pour #7).
- Flags avancés **désactivés** pour cette passe (comportement FCM + Flutter).

```bash
# Vérif notifs Android
adb shell dumpsys notification --noredact | rg "conv_|talky_"

# Logs backend utiles
rg "notification_sent|notification_skipped|PushDevice skip|NotifTrace" /var/log/alanya.log
```

## Scénarios Android prioritaires

| # | Scénario | Prérequis | Étapes | Résultat attendu | Commande vérif | Statut | Date | Notes |
|---|----------|-----------|--------|------------------|----------------|--------|------|-------|
| 1 | Message direct, foreground chat ouvert | Conv ouverte au 1er plan | B envoie message à A | Pas de notif / pas de son | UI + dumpsys : pas de nouveau `conv_*` | ⬜ À exécuter | | |
| 2 | Message, foreground autre écran | A sur liste chats / profil | B envoie message | 1 notif max, tag `conv_<id>` | `adb dumpsys … \| rg conv_` | ⬜ | | |
| 3 | Message, background (socket actif) | Home → bouton Home | B envoie message | 1 notif, badge +1 | dumpsys + badge launcher | ⬜ | | |
| 4 | Message, app tuée | Swipe tâches | B envoie message | FCM affiche notif | dumpsys + tap ouvre chat | ⬜ | | |
| 5 | Écran verrouillé | Lock screen | B envoie message | Notif visible ; tap ouvre conversation | UI lockscreen | ⬜ | | |
| 6 | Offline → online | Mode avion puis off | Messages pendant offline | Pas de doublon à la reconnexion | UI + logs `notification_sent` | ⬜ | | |
| 7 | 2 appareils même compte | 2 APK / émulateur | Lu sur A | Notif disparaît sur B (`message_read_sync`) | dumpsys B | ⬜ | | |
| 8 | Conversation mute | Mute 8h / forever | B envoie message | Pas de son / skip push backend | logs `conversation_muted` | ⬜ | | |
| 9 | Preview privée | Prefs `previewMode=generic` | Message en lockscreen | Corps générique « Nouveau message » | UI lockscreen | ⬜ | | |
| 10 | Appel entrant app tuée | App tuée, perms FSI API 34+ | A appelle B | CallKit/FGS ; plein écran si autorisé | UI appel | ⬜ | | |
| 11 | call_ended | Sonnerie active | A raccroche | UI appel disparaît en moins de 5 s | UI | ⬜ | | |

**Objectif Phase 7** : ≥ **9/11** OK. Les 2 restants documentés si bloqués (OEM, matériel).

### Checklist d’exécution (à cocher manuellement)

```text
[ ] #1 foreground chat
[ ] #2 foreground autre écran
[ ] #3 background
[ ] #4 app tuée
[ ] #5 lockscreen
[ ] #6 offline/online
[ ] #7 multi-appareil
[ ] #8 mute
[ ] #9 preview privée
[ ] #10 appel tuée
[ ] #11 call_ended
```

Captures optionnelles : `docs/e2e_evidence/` (gitignored).

---

## Scénarios différés (doc seulement)

| Sujet | Flag / prérequis | Pourquoi différé |
|-------|------------------|------------------|
| Reply / Mark read iOS | Phase 5.2 + appareil iOS | Hors scope Android staging |
| PushKit app tuée | `IOS_VOIP_V2=true` + clé APNs `.p8` | iOS + secrets |
| Android natif MessagingStyle | `NOTIFICATION_ANDROID_NATIVE_V2=true` + Gradle placeholders | Activation progressive (7.3) |
| NSE avatars | Target Xcode + `IOS_RICH_NSE` | Manuel Xcode |

### Activation Android natif v2 (quand prêt)

Backend :

```bash
NOTIFICATION_ANDROID_NATIVE_V2=true
```

App ([android/app/build.gradle.kts](../android/app/build.gradle.kts)) :

```kotlin
manifestPlaceholders["talkyNotificationNativeV2"] = "true"
manifestPlaceholders["talkyFlutterFcmEnabled"] = "false"
```

Puis rejouer #2–#5 et vérifier MessagingStyle + actions reply/read.

---

## Mapping critères globaux (plan §4)

| Critère | Scénarios |
|---------|-----------|
| 1 notif / appareil | #2 #3 #4 #6 |
| Pas de perte socket online | #3 |
| Pas de son chat ouvert | #1 |
| Lu → pas de réapparition | #7 |
| Badge | #3 |
| Mute / confidentialité | #8 #9 |
| Quick reply idempotent | Différé (natif) / tests unitaires backend |
| Multi-token | #7 |
| Groupes | Étendre #2 avec groupe |
| Appels tuée / fin | #10 #11 |

---

*Phase 7.2 — Talky / Alanya-Backend.*
