# Talky — Guide de reprise (UI/UX, mode sombre, i18n, validation)

> **Pour le développeur qui reprend le projet.** Ce document est auto-suffisant :
> il explique ce qui a été fait, **comment** c'est fait (conventions + exemples de
> code), la **recette exacte** pour continuer écran par écran, l'inventaire précis
> de ce qui reste, les pièges à éviter, et trois chantiers additionnels (mode
> sombre, i18n, validation des formulaires). Aucune connaissance préalable de l'app
> n'est supposée.

---

## 0. Prise en main (5 min)

```bash
# Pré-requis : Flutter 3.44+ (stable), un appareil Android (ou émulateur).
cd /chemin/vers/Talky
flutter pub get
flutter devices              # repérer l'ID de l'appareil
flutter run -d <deviceId>    # lance l'app (hot reload : 'r', hot restart : 'R')
flutter analyze              # analyse statique (voir §8 pour la "référence")
dart format lib/             # formatage
```

- L'app démarre sur l'écran de connexion (`AuthWrapper` dans `lib/main.dart`).
  Les écrans principaux ne sont visibles qu'**après connexion**.
- Backend : dépôt séparé `Alanya-Backend` (Node/Express + MySQL + socket.io).
  L'app pointe vers `http://158.220.107.211` (cf. `lib/talky_api_client.dart`).

---

## 1. Contexte & objectif

Talky est une app Flutter (messagerie / appels / réunions / statuts / admin).
Le problème de départ : **aucun design system**. ≈1 100 couleurs codées en dur,
**4 indigos concurrents**, rayons d'angle et tailles de police incohérents,
`TextStyle` 100 % inline, patterns dupliqués (avatars, list tiles, bottom sheets…).

**Objectif** : app **cohérente et professionnelle**, sans casser les
fonctionnalités. Méthode : un **socle de tokens + composants partagés** (déjà
posé), puis migration des écrans **par vagues**, du plus visible au moins visible.

**Décisions déjà prises (à respecter) :**
- **Couleur de marque** : indigo Material **`#3F51B5`** (`AppColors.brandPrimary`).
  Ne pas réintroduire d'autres indigos.
- **Mode sombre** : architecture prête, **à finaliser** (chantier §6).
- **i18n** et **validation des formulaires** : **socle posé** (ARB FR/EN, `validators.dart`, auth + bannières offline/outbox + nav) — migration progressive du reste des écrans (§8.2 / §8.3).
- **Chiffrement** : **reporté**. Voir Annexe A (seule réserve : le TLS).

---

## 2. Plan du dépôt (où vivent les choses)

```
lib/
├─ main.dart                       # MaterialApp : theme/darkTheme/themeMode
├─ core/theme/                     # ◀ LE SOCLE (à connaître par cœur)
│  ├─ app_colors.dart             # palette brute (const) — source unique
│  ├─ app_dimens.dart             # AppSpacing / AppRadius / AppIconSize / AppSizes / AppShadows / AppDurations
│  └─ app_theme.dart              # ThemeData clair+sombre, TextTheme, thèmes composants,
│                                 #   AppSemanticColors + extensions context.colors/text/semantic
├─ widgets/
│  ├─ common/                      # ◀ COMPOSANTS PARTAGÉS (réutiliser en priorité)
│  │  ├─ common.dart              # barrel : `import '.../widgets/common/common.dart';`
│  │  ├─ app_avatar.dart          # AppAvatar (image + fallback initiales)
│  │  ├─ app_bottom_sheet.dart    # AppBottomSheet + showAppBottomSheet + SheetDragHandle
│  │  ├─ app_search_field.dart    # AppSearchField
│  │  ├─ empty_state.dart         # EmptyState + LoadingState
│  │  ├─ app_badge.dart           # CountBadge + PresenceDot
│  │  └─ status_chip.dart         # StatusChip (tones)
│  └─ *.dart                       # widgets historiques (certains migrés, cf. §5)
├─ screens/                        # écrans, regroupés par feature (cf. §5)
├─ providers/                      # état (Provider) — NE PAS MODIFIER pour l'UI
├─ core/services/                  # réseau, DB, push, webrtc — NE PAS MODIFIER pour l'UI
└─ talky_api_client.dart, talky_models.dart
```

---

## 3. Design system — cheat-sheet (à garder ouvert pendant la migration)

### 3.1 Accès au thème depuis un widget
Des extensions sur `BuildContext` (définies dans `app_theme.dart`) rendent tout ergonomique :

```dart
context.colors    // ColorScheme  → primary, onPrimary, surface, onSurface,
                  //   onSurfaceVariant, error, outline, primaryContainer, ...
context.text      // TextTheme     → headlineLarge, titleMedium, bodyLarge, labelSmall, ...
context.semantic  // AppSemanticColors → success, warning, info, online,
                  //   brandContainer, surfaceMuted, immersiveBackground, ...
```

### 3.2 Couleurs — quoi remplacer par quoi

| Avant (en dur) | Après |
|---|---|
| `Colors.indigo`, `Color(0xFF1E66D8)`, `Color(0xFF3949AB)` | `context.colors.primary` |
| `Colors.white` (surface/carte) | `context.colors.surface` |
| `Colors.black` / `Colors.black87` (texte) | `context.colors.onSurface` |
| `Colors.black54/45`, `Colors.grey.shade500/600` (texte secondaire) | `context.colors.onSurfaceVariant` |
| `Colors.grey.shade100/200` (fond discret) | `context.semantic.surfaceMuted` |
| `Colors.grey.shade300` (bordure/séparateur) | `context.colors.outline` / `outlineVariant` |
| `Colors.green` (présence / succès) | `context.semantic.online` / `context.semantic.success` |
| `Colors.red`, `Colors.redAccent` (erreur) | `context.colors.error` |
| `Colors.orange` (warning) | `context.semantic.warning` |
| fond d'appel/vidéo sombre | `AppColors.immersiveBackground` / `context.semantic.immersiveBackground` |

> **Contextes `const`** (ex. `const SnackBar(backgroundColor: …)`) : on ne peut pas
> utiliser `context.*`. Utiliser alors les constantes statiques `AppColors.error`,
> `AppColors.white`, etc. (cf. `app_colors.dart`).

### 3.3 Espacements, rayons, tailles

```dart
AppSpacing.xs/sm/md/lg/xl/xxl/xxxl   // 4 / 8 / 12 / 16 / 20 / 24 / 32
AppSpacing.vGapMd, AppSpacing.hGapSm // SizedBox prêts à l'emploi (vertical / horizontal)
AppSpacing.screenH                   // EdgeInsets horizontal d'écran (16)
AppRadius.sm/md/lg/pill              // 12 / 16 / 20 / 28  (+ brSm/brMd/brLg/brPill, sheetTop)
AppIconSize.sm/md/lg/xl              // 20 / 24 / 28 / 44
AppSizes.buttonHeight (48), avatarSm/Md/Lg/Xl (40/48/56/72)
AppShadows.subtle / medium / strong  // ombres normalisées
AppDurations.fast/normal/slow        // 150 / 250 / 350 ms
```

### 3.4 Typographie — fini les `TextStyle(fontSize: …)` inline

```dart
Text('Discussions', style: context.text.headlineLarge);   // gros titre d'écran
Text(name,           style: context.text.titleMedium);     // titre de tuile
Text(message,        style: context.text.bodyMedium);      // texte secondaire
Text(time,           style: context.text.labelSmall);      // horodatage / petit label
// Adapter une couleur : context.text.titleMedium?.copyWith(color: context.colors.primary)
```
Échelle : `headlineLarge`(30) `headlineMedium`(26) `headlineSmall`(22)
`titleLarge`(20) `titleMedium`(16) `titleSmall`(14) `bodyLarge`(15) `bodyMedium`(14)
`bodySmall`(12) `labelLarge`(15) `labelMedium`(13) `labelSmall`(11).

### 3.5 Composants partagés (réutiliser avant de réinventer)

```dart
import '../../widgets/common/common.dart';

// Avatar (image réseau/locale + fallback initiales ou icône groupe)
AppAvatar(imageUrl: url, name: 'Awa', size: AppSizes.avatarLg, isGroup: false);
// (ProfileAvatar = AppAvatar + ouverture du modal de profil au tap.
//  ⚠ son paramètre `borderRadius` = rayon : passer size/2 pour un cercle.)

// État vide / chargement (pour toute liste ou écran async)
const LoadingState();
EmptyState(icon: Icons.chat_bubble_outline_rounded,
           title: 'Aucune discussion',
           message: 'Démarrez une discussion avec le bouton +.');

// Badge de comptage + point de présence
CountBadge(count: conv.unreadCount);
const PresenceDot(online: true, size: 14);

// Chip d'état (réunions : en cours / à venir / terminé)
StatusChip(label: 'En cours', tone: StatusChipTone.success);

// Bottom sheet stylé (poignée + coins arrondis cohérents)
showAppBottomSheet(context: context, builder: (ctx) => AppBottomSheet(
  child: Column(mainAxisSize: MainAxisSize.min, children: [ /* ... */ ]),
));

// Champ de recherche unifié
AppSearchField(controller: ctrl, onChanged: (v) => ..., onClear: () => ...);
```

Les **boutons** n'ont (presque) plus besoin de style : `FilledButton`,
`ElevatedButton`, `OutlinedButton`, `TextButton` sont déjà thémés (hauteur 48,
rayon `sm`, couleurs de marque). De même AppBar, inputs, dialogs, snackbars, chips,
tabs : leur thème est dans `app_theme.dart`.

---

## 4. Recette de migration d'un écran (à appliquer mécaniquement)

1. **Imports** : ajouter
   `import '../../core/theme/app_dimens.dart';`,
   `import '../../core/theme/app_theme.dart';`,
   et si besoin `import '../../widgets/common/common.dart';` /
   `import '../../core/theme/app_colors.dart';` (pour les contextes const).
2. **Scaffold / AppBar** : retirer `backgroundColor: Colors.white`,
   `elevation`, couleurs d'icônes en dur (le thème s'en charge). Titre d'écran →
   `style: context.text.headlineLarge`.
3. **Couleurs** : remplacer chaque `Colors.*` / `Color(0x…)` selon le tableau §3.2.
4. **Espacements / rayons / icônes** : remplacer les nombres bruts par les tokens §3.3.
5. **Typo** : remplacer les `TextStyle(fontSize: …)` par `context.text.*` (§3.4).
6. **États** : `CircularProgressIndicator` isolé → `LoadingState` ; `Center(Text('Aucun…'))`
   → `EmptyState(...)`.
7. **Bottom sheets / modaux** : `showModalBottomSheet(...)` maison →
   `showAppBottomSheet(...)` + `AppBottomSheet`.
8. **Vérifier** : `flutter analyze <fichier>` → 0 nouveau warning ; relire que la
   **logique n'a pas bougé** (callbacks, navigation, providers). Smoke test à l'écran.

### Exemple avant / après (extrait réel de `chats_screen.dart`)

```dart
// AVANT
appBar: AppBar(
  backgroundColor: Colors.white, elevation: 0,
  title: const Text('Discussions',
      style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)),
),
// ... plus bas, badge non-lus :
Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
  child: Text('${conv.unreadCount}',
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
)

// APRÈS
appBar: AppBar(
  title: Text('Discussions', style: context.text.headlineLarge),
),
// ...
if (hasUnread) CountBadge(count: conv.unreadCount),
```

---

## 5. Inventaire & vagues (état au moment de la reprise)

`✅` = migré vers les tokens · `⬜` = à faire. Lignes indicatives.

### Déjà fait
| Fichier | Lignes | |
|---|---|---|
| `core/theme/{app_colors,app_dimens,app_theme}.dart` | — | ✅ socle |
| `widgets/common/*` (6 composants) | — | ✅ |
| `widgets/{section_card,contact_action_button,quick_action_button,profile_avatar,animated_search_bar}.dart` | — | ✅ |
| `screens/home/{home_screen,glass_nav_bar}.dart` | 350 / 175 | ✅ |
| `screens/chats/chats_screen.dart` | 504 | ✅ |
| `screens/chats/chat_detail_screen.dart` | 1426 | ✅ (intégral) |
| `screens/calls/calls_screen.dart` | 373 | ✅ |
| `screens/calls/keypad_screen.dart` | 268 | ✅ |

### Reste à faire — par vague (ordre conseillé)

**Vague 2 — Appels (finir)**
| Écran | Lignes | Note |
|---|---|---|
| `calls/call_detail_screen.dart` | 300 | standard |
| `calls/select_contact_screen.dart` | 468 | liste + recherche (réutiliser `AppSearchField`, `AppAvatar`) |
| `calls/group_participants_picker_screen.dart` | 175 | multi-sélection |
| `calls/incoming_call_screen.dart` | 338 | ⚠ **immersif** (fond sombre, appel live) |
| `calls/ongoing_call_screen.dart` | 651 | ⚠ **immersif WebRTC** (rendus vidéo) |

**Vague 3 — Statuts & Réunions**
| Écran | Lignes | Note |
|---|---|---|
| `status/statuses_screen.dart` | 420 | liste (réutiliser `status_ring_avatar`) |
| `status/status_views_screen.dart` | 102 | liste simple |
| `status/status_create_screen.dart` | 813 | ⚠ caméra/édition |
| `status/status_viewer_screen.dart` | 801 | ⚠ **immersif** (stories plein écran) |
| `meetings/meets_screen.dart` | 686 | onglets + `StatusChip` (en cours/à venir) |
| `meetings/meeting_detail_screen.dart` | 570 | |
| `meetings/meeting_lobby_screen.dart` | 313 | |
| `meetings/join_meet_screen.dart` | 148 | formulaire |
| `meetings/participant_picker_screen.dart` | 485 | multi-sélection |
| `meetings/ongoing_meet_screen.dart` | 743 | ⚠ **immersif WebRTC** |
| `shared/schedule_screen.dart` | 532 | formulaire (cf. chantier validation §8) |

**Vague 4 — Onboarding & compte**
| Écran | Lignes | Note |
|---|---|---|
| `authentification/login_screen.dart` | 217 | validation + i18n |
| `authentification/signup_screen.dart` | 229 | validation + i18n (« Créer un compte ») |
| `authentification/forgot_password_screen.dart` | 333 | étapes OTP + validation + i18n |
| `profile/profile_screen.dart` | 787 | |
| `profile/settings_screen.dart` | 240 | **y mettre le sélecteur de thème (§6)** |
| `profile/edit_profile_screen.dart` | 388 | validation Form |
| `profile/preferred_contacts_screen.dart` | 180 | flux contacts réel |
| ~~`contacts/contacts_screen.dart`~~ | — | **supprimé** (orphelin / données factices) |
| `chats/new_chat_screen.dart` | 387 | |
| `chats/create_group_screen.dart` | 243 | + validation |
| `chats/group_detail_screen.dart` | 844 | |
| `chats/select_members_screen.dart` | 271 | multi-sélection |
| `chats/contact_detail_screen.dart` | 1065 | gros |
| `chats/conversation_media_screen.dart` | 530 | onglets média |
| `chats/media_viewer_screen.dart` | 92 | ⚠ **immersif** |
| `chats/fullscreen_profile_image_viewer.dart` | 68 | ⚠ **immersif** |
| `chats/voice_message_bubble.dart` | 136 | widget de bulle vocale |

**Vague 5 — Admin (en dernier)**
| Écran | Lignes |
|---|---|
| `admin/admin_dashboard_screen.dart` | 841 |
| `admin/admin_user_detail_screen.dart` | 721 |

**Widgets historiques restant à passer aux tokens** :
`widgets/add_contact_sheet.dart` (293), `widgets/country_picker_sheet.dart` (120),
`widgets/profile_image_modal.dart` (378), `widgets/status_ring_avatar.dart` (174).

---

## 6. Pièges & règles d'or (lus dans le sang du projet)

- **NE PAS toucher à la logique** : providers, services, appels réseau, navigation,
  callbacks, noms d'événements socket. La migration est **purement présentationnelle**.
- **`ProfileAvatar.borderRadius` = rayon de coin**. Les appelants passent
  `borderRadius: size/2` pour obtenir un **cercle**. Conserver ce calcul.
- **Écrans immersifs** (`ongoing_call`, `incoming_call`, `ongoing_meet`,
  `status_viewer`, `media_viewer`, `fullscreen_profile_image_viewer`) : fonds
  **volontairement sombres**. Utiliser `AppColors.immersiveBackground` /
  `immersiveSurface` + blanc sur sombre. Ce sont des écrans **WebRTC / vidéo /
  caméra sensibles** : après migration, **vérifier qu'un appel/une story marche
  encore**.
- **`AnimatedSearchBar`** est partagé (chats + calls) : déjà migré, ne pas
  dupliquer.
- **`kGlassNavBarSpace`** (`glass_nav_bar.dart`) : espace réservé en bas pour la
  nav flottante. Les listes ajoutent `padding: EdgeInsets.only(bottom: kGlassNavBarSpace)`.
- **Bulles de chat** : pattern `_bubbleText(isMe)` / `_bubbleMuted(isMe)` dans
  `chat_detail_screen.dart` — s'en inspirer pour toute UI « sur fond coloré ».
- **`const` + couleur** : impossible d'utiliser `context.*` dans un widget `const`.
  Soit retirer le `const`, soit utiliser `AppColors.*`.

---

## 7. Definition of Done (par écran)

Un écran est « fait » quand :
- [ ] `grep -n "Colors\.[a-z]\|Color(0x" <fichier>` ne renvoie **que** des
      `AppColors.*` dans des contextes `const` (idéalement plus rien).
- [ ] La typo passe par `context.text.*` (plus de `fontSize` inline, sauf gros
      affichage volontaire).
- [ ] Espacements / rayons / icônes via tokens.
- [ ] États **vide / chargement** présents pour toute liste ou contenu async.
- [ ] `flutter analyze <fichier>` : **aucun nouveau** warning.
- [ ] Smoke test : l'écran s'ouvre et **se comporte comme avant**.

---

## 8. Chantiers additionnels

### 8.1 Mode sombre (architecture déjà prête)

`AppTheme.dark`, `_darkScheme`, `AppSemanticColors.dart` existent déjà.
**Pré-requis** : il faut d'abord avoir migré les écrans (vagues 2→5), sinon les
`Colors.white/black` en dur cassent le rendu sombre.

Étapes :
1. **Contrôleur de thème** (léger) :
```dart
// lib/core/theme/theme_controller.dart
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _mode = ThemeMode.values[p.getInt('theme_mode') ?? ThemeMode.light.index];
    notifyListeners();
  }
  Future<void> set(ThemeMode m) async {
    _mode = m; notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_mode', m.index);
  }
}
```
2. **Brancher** dans `main.dart` : fournir le `ThemeController` (Provider) et lire
   `themeMode: context.watch<ThemeController>().mode` dans `MaterialApp`.
3. **Sélecteur** Clair / Sombre / Système dans `profile/settings_screen.dart`.
4. **Finaliser `_darkScheme`** (tons indigo sombres posés en stub : `#9FA8DA` /
   `#283593`) et **QA chaque écran** en sombre (contrastes, surfaces immersives).

### 8.2 i18n (internationalisation)

**État : livré (FR/EN).** Socle ARB + `LocaleController` (fr | en | system,
SharedPreferences, miroir `ThemeController`) + sélecteur dans Paramètres.
`MaterialApp.locale` via `Consumer2` (plus de locale figée `fr`). Extension
`context.l10n`. Clés orphelines branchées (`appTitle`, `status*`, nav…).
Chaînes UI migrées vers `app_fr.arb` / `app_en.arb` ; `flutter gen-l10n`.

Restes volontaires : libellés de permissions OS (Info.plist / manifeste),
noms de dossiers album `Alanya`, sentinelle DB aperçu message supprimé
(comparaison locale stable).

### 8.3 Validation des formulaires

Constat : validation surtout à la soumission, peu de feedback live.

1. **Helper** réutilisable :
```dart
// lib/core/utils/validators.dart
class Validators {
  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ requis' : null;
  static String? email(String? v) =>
      (v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v))
          ? null : 'Email invalide';
  static String? minLen(String? v, int n) =>
      (v != null && v.length >= n) ? null : 'Au moins $n caractères';
}
```
2. **Écrans cibles** : `login`, `signup`, `forgot_password` (OTP 6 chiffres),
   `edit_profile`, `create_group`, `schedule_screen`.
3. **Approche** : `Form(key: _formKey)` + `TextFormField(validator: …)` +
   `autovalidateMode: AutovalidateMode.onUserInteraction` (feedback live). Les
   erreurs s'affichent automatiquement via l'`inputDecorationTheme` déjà stylé
   (bord rouge `error`).
4. **i18n** : messages de validation via les ARB (§8.2).

---

## 9. Vérification (à chaque lot)

- **Statique** : `flutter analyze`. Au moment de la reprise, le projet a ~18
  *issues préexistantes* (warnings `use_build_context_synchronously`,
  `use_key_in_widget_constructors` dans des fichiers non migrés). **Règle : ne pas
  en ajouter de nouveaux.** Ce nombre peut bouger légèrement quand un fichier
  change — l'important est qu'aucun warning ne provienne de tes éditions.
- **Format** : `dart format lib/`.
- **Visuel** : `flutter run` sur appareil, parcourir les écrans migrés (clair puis
  sombre une fois §8.1 fait).
- **Non-régression** : dérouler les parcours clés — envoyer un message, passer/
  recevoir un appel, créer un statut, planifier une réunion, login/signup.

---

## Annexe A — Note de sécurité (signalée, NON planifiée ici)

Le chiffrement applicatif est **reporté** à la demande du porteur. **Une seule
réserve à garder en tête**, et ce n'est pas du chiffrement applicatif mais une
config serveur :

- **Transport en clair (HTTP)** : `talky_api_client.dart` cible
  `http://158.220.107.211` (API **et** socket) et Android force
  `usesCleartextTraffic="true"`. → mot de passe, **token JWT** et contenu des
  messages circulent **en clair**. Un attaquant réseau peut lire les conversations
  et **voler le token** pour usurper le compte.
- **Correctif (ops, pas du code app)** : servir le backend en **HTTPS/WSS**
  (reverse proxy + certificat Let's Encrypt sur un domaine), passer
  `baseUrl`/`socketUrl` en `https://`/`wss://`, retirer `usesCleartextTraffic`.
- Le backend est par ailleurs correctement durci (bcrypt, `express-rate-limit`,
  `express-validator`, JWT). La lacune est surtout le transport.

## Annexe B — Autres points détectés (hors périmètre, pour mémoire)

- Chiffrement **au repos** de la base locale `drift` (SQLCipher) — messages cachés
  en clair sur l'appareil (`core/db/app_database.dart` : `NativeDatabase` simple).
- **Hygiène des logs** : ≈284 `debugPrint/print` à gater en debug uniquement.
- **Tests** : couverture quasi nulle (2 fichiers `test/`).
- **Durcissement backend** résiduel : `cors: { origin: '*' }`, `JWT_SECRET` avec
  valeur par défaut, pas de `helmet`, vérifier que `serviceAccountKey.json` / `.env`
  sont bien gitignorés.
