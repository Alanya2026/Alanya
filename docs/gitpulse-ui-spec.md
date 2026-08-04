# GitPulse — Spécification UI/UX

> Interface CLI inspirée de Claude Code / OpenCode avec ratatui

## 1. Vue d'ensemble

### Philosophie de design
- **Claude Code style** : panels séparés, status bar, input dédié
- **Adaptatif** : s'adapte à la taille du terminal
- **Dark mode** par défaut, thème clair en option
- **Interactif** : input bar, keybindings, menu contextuel

### Framework
- **ratatui** — TUI framework Rust
- **crossterm** — backend terminal (souris, resize, etc.)
- **tokio** — async runtime pour les mises à jour en temps réel

## 2. Grille de colonnes

### Layout adaptatif

```
┌─────────────────────────────────────────────────────────────┐
│  < 80 colonnes : Mode compact                               │
├─────────────────────────────────────────────────────────────┤
│  Status Bar                                                  │
├─────────────────────────────────────────────────────────────┤
│  [Messages]                                                  │
│  [Input]                                                     │
├─────────────────────────────────────────────────────────────┤
│  Status Footer                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  >= 80 colonnes : Mode standard                             │
├──────────────────────────────┬──────────────────────────────┤
│  Status Bar                  │  Stats Bar                    │
├──────────────────────────────┼──────────────────────────────┤
│  [Messages]                  │  [Diff Preview]              │
│                              │                              │
│                              │                              │
├──────────────────────────────┴──────────────────────────────┤
│  [Input Bar]                                                │
├─────────────────────────────────────────────────────────────┤
│  Status Footer                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  >= 120 colonnes : Mode riche                               │
├──────────────────────────────┬──────────────────────────────┤
│  Status Bar                  │  Stats Bar     │ Config Bar  │
├──────────────────────────────┼────────────────┴─────────────┤
│  [Messages]                  │  [Diff Preview]              │
│                              │                              │
│                              │                              │
├──────────────────────────────┼──────────────────────────────┤
│  [Input Bar]                 │  [Scope Selector]            │
├──────────────────────────────┴──────────────────────────────┤
│  Status Footer                                              │
└─────────────────────────────────────────────────────────────┘
```

## 3. Composants détaillés

### 3.1 Status Bar (haut)

```
┌─────────────────────────────────────────────────────────────┐
│  ● GitPulse v0.1.0  │  📁 my-project  │  main  │  3 files  │
└─────────────────────────────────────────────────────────────┘
```

**Éléments :**
- Indicateur de statut (● vert = actif, ● rouge = erreur, ● jaune = en attente)
- Version de GitPulse
- Nom du projet (dernier dossier du path)
- Branche actuelle
- Nombre de fichiers modifiés

**Couleurs :**
- Fond : `#1e1e2e` (catppuccin mocha)
- Texte : `#cdd6f4`
- Accent : `#89b4fa` (bleu)
- Erreur : `#f38ba8` (rouge)
- Succès : `#a6e3a1` (vert)

### 3.2 Stats Bar (optionnel, >= 80 col)

```
┌─────────────────────────────────┐
│  +12  -5  │  ⏱ 2m ago  │  100%  │
└─────────────────────────────────┘
```

**Éléments :**
- Insertions / suppressions (avec couleurs)
- Dernière activité
- Pourcentage de complétion (si en cours)

### 3.3 Messages Panel (principal)

```
┌─────────────────────────────────────────────────────────────┐
│  💬 GitPulse                                               │
│                                                             │
│  Diff analysé : 3 fichiers modifiés                         │
│                                                             │
│  📄 src/main.rs (+15, -3)                                   │
│  📄 src/config.rs (+8, -2)                                  │
│  📄 tests/test_main.rs (+20, -0)                            │
│                                                             │
│  Message proposé :                                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ feat(auth): add OAuth2 authentication flow          │    │
│  │                                                     │    │
│  │ - Implement OAuth2 authorization code flow          │    │
│  │ - Add token refresh logic                          │    │
│  │ - Add comprehensive tests                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  [Entrée] Valider  [e] Éditer  [↑↓] Navigation  [q] Quitter│
└─────────────────────────────────────────────────────────────┘
```

**Éléments :**
- Titre du panel avec icône
- Résumé de l'analyse
- Liste des fichiers avec statistiques
- Message proposé dans un cadre
- Actions disponibles

### 3.4 Diff Preview Panel (>= 80 col)

```
┌─────────────────────────────────────────────────────────────┐
│  📝 Diff Preview                              [Scroll: ↑↓]  │
├─────────────────────────────────────────────────────────────┤
│  @@ -10,6 +10,12 @@ pub fn main() {                         │
│                                                             │
│  + use oauth2::{Client, Scope};                            │
│  + use reqwest::Client as HttpClient;                       │
│                                                             │
│    fn main() {                                              │
│  -     println!("Hello");                                   │
│  +     let client = Client::new(                            │
│  +         ClientId::new("client_id".to_string()),          │
│  +         Some(ClientSecret::new("secret".to_string())),   │
│  +     );                                                   │
│  +     println!("OAuth2 initialized");                      │
│    }                                                        │
└─────────────────────────────────────────────────────────────┘
```

**Éléments :**
- Titre avec indicateur de scroll
- Diff avec syntax highlighting
- Lignes ajoutées en vert, supprimées en rouge
- Hunks avec numéros de ligne
- Scroll horizontal/vertical

**Couleurs syntax :**
- Ajout : `#a6e3a1` (vert)
- Suppression : `#f38ba8` (rouge)
- Hunk header : `#cba6f7` (mauve)
- Numéro de ligne : `#585b70` (gris)

### 3.5 Input Bar

```
┌─────────────────────────────────────────────────────────────┐
│  ▸ Entrez un message ou tapez une commande...              │
└─────────────────────────────────────────────────────────────┘
```

**États :**
- **Placeholder** : texte grisé, disparaît au focus
- **Focus** : curseur clignotant, texte blanc
- **Validation** : brièvement vert puis reset
- **Erreur** : brièvement rouge puis reset

**Commandes supportées :**
- Texte libre → édite le message
- `/commit` → valide et commit
- `/push` → commit + push
- `/edit` → ouvre l'éditeur système
- `/scope <name>` → change le scope
- `/type <type>` → change le type (feat, fix, etc.)
- `/help` → affiche l'aide
- `/quit` → quitte

### 3.6 Scope Selector (>= 120 col)

```
┌─────────────────────────────────┐
│  Scope: [api] [ui] [test] [docs]│
│         ▲                       │
│         └─ sélectionné          │
└─────────────────────────────────┘
```

**Éléments :**
- Liste des scopes définis dans la config
- Scope actuellement sélectionné (highlight)
- Navigation avec ← →
- Scope personnalisé avec `/scope <name>`

### 3.7 Status Footer

```
┌─────────────────────────────────────────────────────────────┐
│  [?] Aide  [Tab] Switch panel  [Ctrl+C] Annuler  [Enter] OK│
└─────────────────────────────────────────────────────────────┘
```

**Éléments :**
- Raccourcis clavier contextuels
- Aide rapide
- Séparateur visuel

## 4. Schéma de couleurs

### Thème Dark (défaut) — Catppuccin Mocha

```rust
pub struct Theme {
    // Fond
    pub bg: Color,           // #1e1e2e
    pub bg_dark: Color,      // #181825
    pub bg_light: Color,     // #313244
    
    // Texte
    pub text: Color,         // #cdd6f4
    pub text_dim: Color,     // #a6adc8
    pub text_muted: Color,   // #585b70
    
    // Accents
    pub accent: Color,       // #89b4fa (bleu)
    pub accent2: Color,      // #cba6f7 (mauve)
    pub accent3: Color,      // #f9e2af (jaune)
    
    // Sémantique
    pub success: Color,      // #a6e3a1 (vert)
    pub error: Color,        // #f38ba8 (rouge)
    pub warning: Color,      // #fab387 (orange)
    pub info: Color,         // #89dceb (cyan)
    
    // Diff
    pub diff_add: Color,     // #a6e3a1 (vert)
    pub diff_del: Color,     // #f38ba8 (rouge)
    pub diff_hunk: Color,    // #cba6f7 (mauve)
    
    // UI
    pub border: Color,       // #45475a
    pub border_focus: Color, // #89b4fa
    pub selection: Color,    // #45475a
}
```

### Thème Light (optionnel) — Catppuccin Latte

```rust
pub struct LightTheme {
    pub bg: Color,           // #eff1f5
    pub bg_dark: Color,      // #e6e9ef
    pub bg_light: Color,     // #ccd0da
    pub text: Color,         // #4c4f69
    pub text_dim: Color,     // #5c5f77
    pub text_muted: Color,   // #7c7f93
    pub accent: Color,       // #1e66f5
    pub accent2: Color,      // #8839ef
    pub success: Color,      // #40a02b
    pub error: Color,        // #d20f39
    pub warning: Color,      // #df8e1d
    pub info: Color,         // #04a5e5
    pub diff_add: Color,     // #40a02b
    pub diff_del: Color,     // #d20f39
    pub diff_hunk: Color,    // #8839ef
    pub border: Color,       // #ccd0da
    pub border_focus: Color, // #1e66f5
}
```

## 5. Keybindings

### Global

| Touche | Action |
|--------|--------|
| `Ctrl+C` | Annuler / Quitter |
| `Ctrl+D` | Quitter |
| `?` | Afficher l'aide |
| `Escape` | Retour / Fermer |

### Navigation

| Touche | Action |
|--------|--------|
| `Tab` | Switch panel suivant |
| `Shift+Tab` | Switch panel précédent |
| `↑` / `k` | Monter dans la liste |
| `↓` / `j` | Descendre dans la liste |
| `←` / `h` | Scope précédent |
| `→` / `l` | Scope suivant |
| `Page Up` | Scroll haut |
| `Page Down` | Scroll bas |
| `Home` | Premier élément |
| `End` | Dernier élément |

### Input

| Touche | Action |
|--------|--------|
| `Enter` | Valider / Envoyer |
| `Ctrl+A` | Début de ligne |
| `Ctrl+E` | Fin de ligne |
| `Ctrl+K` | Effacer jusqu'à la fin |
| `Ctrl+U` | Effacer jusqu'au début |
| `Ctrl+W` | Effacer le mot précédent |
| `Ctrl+Y` | Coller (yank) |
| `Ctrl+Z` | Annuler (undo) |

### Actions rapides

| Touche | Action |
|--------|--------|
| `c` | Commit |
| `p` | Push |
| `e` | Éditer le message |
| `s` | Changer le scope |
| `t` | Changer le type |
| `d` | Toggle affichage diff |
| `r` | Régénérer le message |
| `a` | Abort (annuler le commit) |

## 6. États et transitions

### Diagramme d'états

```
                    ┌─────────────┐
                    │   Loading   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
            ┌───── │    Idle     │ ◄─────────────┐
            │      └──────┬──────┘               │
            │             │                      │
            │      ┌──────▼──────┐               │
            │      │  Analyzing  │               │
            │      └──────┬──────┘               │
            │             │                      │
            │      ┌──────▼──────┐               │
            │      │  Proposing  │               │
            │      └──────┬──────┘               │
            │             │                      │
            │      ┌──────▼──────┐               │
            │      │  Editing    │               │
            │      └──────┬──────┘               │
            │             │                      │
            │      ┌──────▼──────┐               │
            │      │  Committing │               │
            │      └──────┬──────┘               │
            │             │                      │
            │      ┌──────▼──────┐               │
            └────► │  Pushing    │ ──────────────┘
                   └─────────────┘
                         │
                   ┌─────▼──────┐
                   │  Complete  │
                   └────────────┘
```

### Description des états

| État | Description | UI |
|------|-------------|-----|
| `Loading` | Chargement initial | Spinner + "Chargement..." |
| `Idle` | En attente d'input | Input bar active |
| `Analyzing` | Analyse du diff en cours | Barre de progression |
| `Proposing` | Message proposé | Message + actions |
| `Editing` | Édition du message | Input pré-rempli |
| `Committing` | Commit en cours | Spinner + "Commit en cours..." |
| `Pushing` | Push en cours | Barre de progression |
| `Complete` | Opération terminée | Message de succès |
| `Error` | Erreur survenue | Message d'erreur + détails |

## 7. Notifications

### Notifications desktop (notify-rust)

```rust
pub struct Notification {
    pub title: String,        // "GitPulse"
    pub body: String,         // "3 fichiers commités: feat(auth)..."
    pub sound: Option<Sound>, // Optionnel
    pub timeout: Duration,    // 5 secondes par défaut
}

pub enum Sound {
    Default,
    Custom(PathBuf),
}
```

### Notifications in-app

```
┌─────────────────────────────────────────────────────────────┐
│  🔔 Notification                                    [x] Fermer│
├─────────────────────────────────────────────────────────────┤
│  Commit proposé :                                          │
│  feat(auth): add OAuth2 authentication flow                │
│                                                             │
│  [Valider]  [Éditer]  [Rejeter]                             │
└─────────────────────────────────────────────────────────────┘
```

### Notifications toast (en bas)

```
┌─────────────────────────────────────────────────────────────┐
│  ✅ Commit créé avec succès : feat(auth): add OAuth2...    │
└─────────────────────────────────────────────────────────────┘
```

## 8. Modes d'affichage

### Mode Draft (défaut)

```
┌─────────────────────────────────────────────────────────────┐
│  ● GitPulse v0.1.0  │  📁 my-project  │  main  │  3 files  │
├──────────────────────────────────┬──────────────────────────┤
│  💬 Messages                     │  📝 Diff Preview         │
├──────────────────────────────────┼──────────────────────────┤
│  Diff analysé : 3 fichiers       │  @@ -10,6 +10,12 @@     │
│                                  │  + use oauth2::...       │
│  📄 src/main.rs (+15, -3)        │  + fn main() {           │
│  📄 src/config.rs (+8, -2)       │  -   println!("Hello");  │
│  📄 tests/test_main.rs (+20, -0) │  +   println!("OAuth");  │
│                                  │                          │
│  Message proposé :               │                          │
│  ┌────────────────────────────┐  │                          │
│  │ feat(auth): add OAuth2...  │  │                          │
│  └────────────────────────────┘  │                          │
├──────────────────────────────────┴──────────────────────────┤
│  ▸ Entrez un message ou tapez une commande...              │
├─────────────────────────────────────────────────────────────┤
│  [c] Commit  [e] Éditer  [s] Scope  [?] Aide  [q] Quitter │
└─────────────────────────────────────────────────────────────┘
```

### Mode Watch

```
┌─────────────────────────────────────────────────────────────┐
│  ● GitPulse v0.1.0  │  📁 my-project  │  main  │  👁 Watch │
├─────────────────────────────────────────────────────────────┤
│  👁 Mode Watch actif                                       │
│                                                             │
│  Surveille : ~/projects/my-project                         │
│  Dernière vérification : il y a 30s                        │
│  Prochaine vérification : dans 30s                         │
│                                                             │
│  Historique récent :                                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 14:32  feat(auth): add OAuth2...                    │   │
│  │ 14:28  fix(api): handle null response                │   │
│  │ 14:15  docs: update README                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [p] Pause  [r] Resume  [l] Logs  [q] Quitter              │
├─────────────────────────────────────────────────────────────┤
│  ● Watch actif │ 3 commits aujourd'hui │ 12h 34m sans      │
└─────────────────────────────────────────────────────────────┘
```

### Mode Compact (< 80 col)

```
┌──────────────────────────────────┐
│  ● GitPulse │ my-project │ main │
├──────────────────────────────────┤
│  Diff: 3 files (+15, -3)        │
│  feat(auth): add OAuth2...      │
├──────────────────────────────────┤
│  ▸ Message...                   │
├──────────────────────────────────┤
│  [Enter] OK  [e] Edit  [q] Quit │
└──────────────────────────────────┘
```

## 9. Animations et transitions

### Transitions d'état

```rust
// Transition fluide entre états
pub enum Transition {
    Instant,           // Changement immédiat
    Fade(Duration),    // Fondu en ou/fermeture
    Slide(Direction),  // Glissement
    Spin(Duration),    // Rotation (spinner)
}

pub enum Direction {
    Up, Down, Left, Right,
}
```

### Éléments animés

| Élément | Animation | Durée |
|---------|-----------|-------|
| Spinner | Rotation continue | 100ms/frame |
| Barre de progression | Remplissage | Variable |
| Changement d'état | Fondu | 150ms |
| Apparition message | Slide up | 200ms |
| Notification toast | Slide in/out | 300ms |
| Highlight scope | Pulse | 500ms |

### Éasing

```rust
pub enum Easing {
    Linear,
    EaseIn,
    EaseOut,
    EaseInOut,
    CubicBezier(f64, f64, f64, f64),
}
```

## 10. Accessibilité

### Support

- **Screen reader** : labels ARIA pour les composants
- **Contraste** : WCAG AA minimum (4.5:1 pour texte normal)
- **Taille texte** : adaptatif à la taille du terminal
- **Clavier** : 100% navigable au clavier
- **Couleurs** : pas d'information portée uniquement par la couleur

### Modes alternatives

```bash
# Mode texte pur (pas de TUI)
gitpulse draft --text-only

# Mode JSON (pour scripts)
gitpulse draft --json

# Mode verbose (logs détaillés)
gitpulse draft --verbose
```

## 11. Stack technique UI

```toml
# crates/gitpulse-cli/Cargo.toml
[dependencies]
ratatui = "0.26"
crossterm = { version = "0.27", features = ["event-stream"] }
tokio = { version = "1", features = ["full"] }
notify-rust = "4"
syntect = "5"              # Syntax highlighting pour les diffs
unicode-width = "0.1"      # Largeur des caractères Unicode
```

## 12. Responsive breakpoints

| Largeur | Mode | Composants visibles |
|---------|------|---------------------|
| < 60 col | Minimal | Messages + Input uniquement |
| 60-79 col | Compact | Messages + Input + Footer |
| 80-119 col | Standard | + Diff Preview |
| >= 120 col | Riche | + Scope Selector + Config Bar |

## 13. Thèmes personnalisables

### Fichier de thème

```yaml
# ~/.config/gitpulse/theme.yml
name: "mon-theme"
dark: true

colors:
  bg: "#1e1e2e"
  bg_dark: "#181825"
  bg_light: "#313244"
  text: "#cdd6f4"
  text_dim: "#a6adc8"
  text_muted: "#585b70"
  accent: "#89b4fa"
  accent2: "#cba6f7"
  success: "#a6e3a1"
  error: "#f38ba8"
  warning: "#fab387"
  info: "#89dceb"

borders:
  style: "rounded"  # rounded | square | double | thick
  color: "#45475a"

animations:
  enabled: true
  speed: 1.0  # Multiplicateur de vitesse
```

### Thèmes prédéfinis

- `catppuccin-mocha` (défaut)
- `catppuccin-latte` (clair)
- `dracula`
- `tokyo-night`
- `gruvbox`
- `nord`
- `rose-pine`
- `custom` (depuis fichier)
