# GitPulse — Plan MVP (Phase 1 + 2)

> Détail technique pour la CLI Rust + mode Watch

## 1. Arborescence du projet

```
gitpulse/
├── Cargo.toml                    # Workspace root
├── .gitignore
├── README.md
├── LICENSE
├── .github/
│   └── workflows/
│       ├── ci.yml               # Tests + lint + build
│       ├── release.yml          # Release binaries
│       └── model-train.yml      # Pipeline d'entraînement ML
├── crates/
│   ├── gitpulse-cli/            # Binaire CLI (point d'entrée)
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── commands/
│   │       │   ├── mod.rs
│   │       │   ├── draft.rs
│   │       │   ├── watch.rs
│   │       │   ├── config.rs
│   │       │   ├── log.rs
│   │       │   └── stats.rs
│   │       └── ui/
│   │           ├── mod.rs
│   │           ├── prompt.rs    # Input interactif
│   │           ├── progress.rs  # Barres de progression
│   │           └── notification.rs  # Notifications desktop
│   ├── gitpulse-core/           # Logique métier
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── diff/
│   │       │   ├── mod.rs
│   │       │   ├── analyzer.rs  # Analyse de diff
│   │       │   ├── filter.rs    # Filtre des fichiers
│   │       │   └── history.rs   # Historique git
│   │       ├── message/
│   │       │   ├── mod.rs
│   │       │   ├── generator.rs # Génération heuristique
│   │       │   ├── conventional.rs  # Format conventionnel
│   │       │   └── template.rs  # Templates de messages
│   │       ├── config/
│   │       │   ├── mod.rs
│   │       │   ├── schema.rs    # Schema de config
│   │       │   ├── loader.rs    # Chargement hiérarchique
│   │       │   └── defaults.rs  # Valeurs par défaut
│   │       ├── git/
│   │       │   ├── mod.rs
│   │       │   ├── repo.rs      # Opérations git
│   │       │   ├── commit.rs    # Création de commits
│   │       │   └── remote.rs    # Push/pull
│   │       └── error.rs         # Types d'erreur
│   ├── gitpulse-watch/          # Daemon
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── watcher.rs       # Surveillance fichiers
│   │       ├── scheduler.rs     # Planification commits
│   │       └── notify.rs        # Notifications
│   └── gitpulse-model/          # ML (Phase 2)
│       ├── Cargo.toml
│       └── src/
│           ├── lib.rs
│           ├── inference.rs     # Inférence ONNX
│           ├── features.rs      # Extraction features
│           └── fallback.rs      # Mode heuristique
├── config/
│   └── gitpulse.yml             # Config par défaut
├── models/
│   └── .gitkeep                 # Modèles ONNX (Phase 2)
└── tests/
    ├── integration/
    │   ├── draft_test.rs
    │   ├── watch_test.rs
    │   └── config_test.rs
    └── fixtures/
        ├── repos/
        │   ├── simple-repo/     # Repo test basique
        │   └── monorepo/        # Repo complexe
        └── diffs/
            ├── feat.diff
            ├── fix.diff
            └── refactor.diff
```

## 2. Modules core et responsabilités

### gitpulse-core

#### diff/analyzer.rs
```rust
/// Analyse un diff git et extrait les informations utiles
pub struct DiffAnalyzer {
    repo: Repository,
}

pub struct DiffInfo {
    pub files: Vec<FileChange>,
    pub stats: DiffStats,
    pub context: DiffContext,
}

pub struct FileChange {
    pub path: PathBuf,
    pub change_type: ChangeType,  // Added, Modified, Deleted, Renamed
    pub hunks: Vec<Hunk>,
    pub language: Option<String>, // Détection du langage
}

pub struct DiffStats {
    pub files_changed: usize,
    pub insertions: usize,
    pub deletions: usize,
}

pub struct DiffContext {
    pub is_feature: bool,    // Nouveau fichier/fonction
    pub is_fix: bool,        // Correction d'erreur
    pub is_refactor: bool,   // Restructuration
    pub is_test: bool,       // Ajout/modif de tests
    pub is_docs: bool,       // Documentation
    pub is_chore: bool,      // Config, dépendances, etc.
    pub is_perf: bool,       // Optimisation de performance
    pub is_style: bool,      // Formattage, lint
    pub is_ci: bool,         // CI/CD
    pub is_build: bool,      // Build system
    pub is_revert: bool,     // Annulation
}
```

#### diff/filter.rs
```rust
/// Filtre les fichiers selon .gitignore + config
pub struct FileFilter {
    gitignore_patterns: Vec<Pattern>,
    config_patterns: Vec<Pattern>,
}

impl FileFilter {
    pub fn should_include(&self, path: &Path) -> bool;
    pub fn get_relevant_files(&self, files: Vec<FileChange>) -> Vec<FileChange>;
}
```

#### message/generator.rs
```rust
/// Génère des messages de commit heuristiques
pub struct MessageGenerator {
    config: CommitConfig,
}

pub struct GeneratedMessage {
    pub r#type: String,      // feat, fix, chore, etc.
    pub scope: Option<String>,
    pub description: String,
    pub body: Option<String>,
    pub breaking: bool,
}

impl MessageGenerator {
    pub fn generate(&self, diff: &DiffInfo) -> GeneratedMessage;
    pub fn detect_type(&self, diff: &DiffInfo) -> String;
    pub fn detect_scope(&self, files: &[FileChange]) -> Option<String>;
    pub fn generate_description(&self, diff: &DiffInfo) -> String;
}
```

#### config/schema.rs
```rust
/// Schema de configuration GitPulse
#[derive(Deserialize, Serialize)]
pub struct GitPulseConfig {
    pub version: String,
    pub commit: CommitConfig,
    pub scope_rules: ScopeRules,
    pub ignore: IgnoreConfig,
    pub mode: Mode,
    pub watch: WatchConfig,
    pub model: ModelConfig,
}

#[derive(Deserialize, Serialize)]
pub struct CommitConfig {
    pub format: CommitFormat,  // conventional | angular | simple | custom
    pub language: Language,    // fr | en | auto
    pub scope: bool,
    pub emoji: bool,
    pub types: Vec<String>,    // Types autorisés
}

#[derive(Deserialize, Serialize)]
pub struct ScopeRules {
    pub patterns: Vec<ScopePattern>,
}

#[derive(Deserialize, Serialize)]
pub struct ScopePattern {
    pub match_pattern: String,
    pub scope: String,
}
```

### gitpulse-cli

#### commands/draft.rs
```rust
/// Commande `gitpulse draft`
pub struct DraftCommand {
    auto: bool,
    push: bool,
    dry_run: bool,
}

impl DraftCommand {
    pub async fn execute(&self) -> Result<()> {
        // 1. Charger la config
        // 2. Obtenir le diff staged
        // 3. Analyser le diff
        // 4. Générer le message
        // 5. Afficher le preview
        // 6. Demander validation
        // 7. Commit (+ push si demandé)
    }
}
```

#### commands/watch.rs
```rust
/// Commande `gitpulse watch`
pub struct WatchCommand {
    dry_run: bool,
    interval: Duration,
    auto: bool,
}

impl WatchCommand {
    pub async fn execute(&self) -> Result<()> {
        // 1. Charger la config
        // 2. Initialiser le watcher
        // 3. Boucle principale :
        //    - Surveiller les changements
        //    - Détecter l'inactivité
        //    - Générer le message
        //    - Notifier / Commit / Push
    }
}
```

### gitpulse-watch

#### watcher.rs
```rust
/// Surveillance des changements de fichiers
pub struct FileWatcher {
    watcher: RecommendedWatcher,
    debounce: Duration,
}

impl FileWatcher {
    pub fn new(config: &WatchConfig) -> Result<Self>;
    pub async fn wait_for_idle(&self) -> Result<Vec<PathBuf>>;
    pub fn get_changed_files(&self) -> Vec<PathBuf>;
}
```

#### scheduler.rs
```rust
/// Planification des commits
pub struct CommitScheduler {
    watcher: FileWatcher,
    generator: MessageGenerator,
    config: WatchConfig,
}

impl CommitScheduler {
    pub async fn run(&self) -> Result<()> {
        // Boucle :
        // 1. Attendre changements
        // 2. Attendre inactivité (idle_threshold)
        // 3. Regrouper les changements logiques
        // 4. Générer message
        // 5. [draft] Notifier et attendre
        // 6. [auto] Commit + push
    }
}
```

## 3. Dépendances Cargo

```toml
# crates/gitpulse-cli/Cargo.toml
[dependencies]
gitpulse-core = { path = "../gitpulse-core" }
gitpulse-watch = { path = "../gitpulse-watch" }
clap = { version = "4", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
console = "0.15"           # Terminal styling
dialoguer = "0.11"         # Input interactif
indicatif = "0.17"         # Barres de progression
notify-rust = "4"          # Notifications desktop
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
anyhow = "1"
thiserror = "1"
```

```toml
# crates/gitpulse-core/Cargo.toml
[dependencies]
git2 = "0.18"              # bindings Git
regex = "1"
once_cell = "1"
glob = "0.3"
ignore = "0.4"             # .gitignore parsing
chrono = "0.4"
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
dirs = "5"                 # Config globale
anyhow = "1"
thiserror = "1"
```

```toml
# crates/gitpulse-watch/Cargo.toml
[dependencies]
gitpulse-core = { path = "../gitpulse-core" }
notify = "6"               # File system watcher
tokio = { version = "1", features = ["full"] }
notify-rust = "4"
anyhow = "1"
```

```toml
# crates/gitpulse-model/Cargo.toml (Phase 2)
[dependencies]
ort = "2"                  # ONNX Runtime bindings
tokenizers = "0.15"
serde = { version = "1", features = ["derive"] }
anyhow = "1"
```

## 4. Plan de tests

### Tests unitaires

| Module | Tests | Priorité |
|--------|-------|----------|
| diff/analyzer.rs | Détection de type de changement | Haute |
| diff/filter.rs | Filtrage .gitignore + config | Haute |
| message/generator.rs | Génération de messages | Haute |
| message/conventional.rs | Format conventionnel | Haute |
| config/loader.rs | Chargement hiérarchique | Moyenne |
| git/repo.rs | Opérations git basiques | Haute |

### Tests d'intégration

```rust
// tests/integration/draft_test.rs
#[test]
fn test_draft_generates_conventional_message() {
    // 1. Créer un repo test avec un fichier modifié
    // 2. Lancer gitpulse draft --dry-run
    // 3. Vérifier que le message est au format conventionnel
    // 4. Vérifier que le type est correct (feat, fix, etc.)
}

#[test]
fn test_draft_respects_config() {
    // 1. Créer un repo avec .gitpulse.yml custom
    // 2. Lancer gitpulse draft --dry-run
    // 3. Vérifier que la config est respectée
}

#[test]
fn test_draft_handles_empty_diff() {
    // 1. Créer un repo sans modifications
    // 2. Lancer gitpulse draft
    // 3. Vérifier le message d'erreur
}
```

### Fixtures de test

```
tests/fixtures/
├── repos/
│   ├── simple-repo/          # Repo Git basique
│   │   ├── .git/
│   │   └── src/
│   │       └── main.rs
│   ├── monorepo/             # Repo avec scopes multiples
│   │   ├── .git/
│   │   ├── src/
│   │   │   ├── api/
│   │   │   └── ui/
│   │   └── tests/
│   └── with-config/          # Repo avec .gitpulse.yml
│       ├── .git/
│       ├── .gitpulse.yml
│       └── src/
├── diffs/
│   ├── feat.diff             # Ajout de fonctionnalité
│   ├── fix.diff              # Correction de bug
│   ├── refactor.diff         # Restructuration
│   ├── test.diff             # Ajout de tests
│   └── chore.diff            # Maintenance
└── configs/
    ├── default.yml           # Config par défaut
    ├── custom.yml            # Config personnalisée
    └── minimal.yml           # Config minimale
```

## 5. CI/CD GitHub Actions

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always
  RUST_BACKTRACE: 1

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      
      - name: Install dependencies
        run: sudo apt-get update && sudo apt-get install -y libgit2-dev
      
      - name: Run tests
        run: cargo test --all-features
      
      - name: Run clippy
        run: cargo clippy --all-targets --all-features -- -D warnings
      
      - name: Check formatting
        run: cargo fmt --check

  build:
    name: Build (${{ matrix.os }})
    needs: test
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      
      - name: Build release
        run: cargo build --release
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: gitpulse-${{ matrix.os }}
          path: target/release/gitpulse
```

### .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      
      - name: Build for all platforms
        run: |
          cargo build --release --target x86_64-unknown-linux-gnu
          cargo build --release --target x86_64-apple-darwin
          cargo build --release --target x86_64-pc-windows-msvc
      
      - name: Create release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            target/x86_64-unknown-linux-gnu/release/gitpulse
            target/x86_64-apple-darwin/release/gitpulse
            target/x86_64-pc-windows-msvc/release/gitpulse.exe
```

## 6. Commandes CLI

```bash
# Installation
cargo install gitpulse

# Mode draft
gitpulse draft                    # Analyse le diff staged, propose un message
gitpulse draft --auto             # Propose et commit si OK
gitpulse draft --push             # Propose, commit, et push
gitpulse draft --dry-run          # Simule sans rien faire

# Mode watch (daemon)
gitpulse watch                    # Active le daemon
gitpulse watch --dry-run          # Simule sans rien faire
gitpulse watch --interval 30s     # Intervalle de check
gitpulse watch --auto             # Mode automatique

# Configuration
gitpulse config init              # Génère .gitpulse.yml
gitpulse config show              # Affiche la config actuelle
gitpulse config set commit.format conventional
gitpulse config set commit.language fr
gitpulse config set commit.scope true

# Historique et stats
gitpulse log                      # Historique formaté
gitpulse log --oneline            # Format court
gitpulse stats                    # Stats de productivité
gitpulse stats --week             # Cette semaine
gitpulse stats --month            # Ce mois

# Version
gitpulse --version
gitpulse --help
```

## 7. Livrables MVP

### Phase 1 — Core CLI (4 semaines)

| Semaine | Tâches | Livrable |
|---------|--------|----------|
| S1 | Setup projet, structure crates, config schema | Binaire qui compile |
| S2 | Diff analyzer, file filter | Analyse de diff fonctionnelle |
| S3 | Message generator, conventional commits | Génération heuristique |
| S4 | Commande draft, UI interactive | `gitpulse draft` fonctionnel |

### Phase 2 — Watch + ML (7 semaines)

| Semaine | Tâches | Livrable |
|---------|--------|----------|
| S5-S6 | File watcher, scheduler | `gitpulse watch` fonctionnel |
| S7 | Notifications, daemon systemd | Notifications desktop |
| S8-S9 | Pipeline entraînement ML | Modèle entraîné |
| S10 | Export ONNX, intégration Rust | Modèle local |
| S11 | Tests d'intégration, docs | Release v0.1.0 |

## 8. Critères de succès MVP

- [ ] `gitpulse draft` génère des messages conventionnels corrects
- [ ] `gitpulse watch` commit automatiquement après inactivité
- [ ] Notifications desktop fonctionnelles
- [ ] Config hiérarchique (globale + par repo)
- [ ] Support fr/en
- [ ] Tests unitaires > 80% couverture
- [ ] CI/CD fonctionnel
- [ ] Binaires pour Linux, macOS, Windows
- [ ] README complet avec exemples
