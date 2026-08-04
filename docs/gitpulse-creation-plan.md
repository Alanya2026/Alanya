# GitPulse — Plan de création complet

> Tous les fichiers à créer pour le projet GitPulse

## Résumé

| Composant | Fichiers | Priorité |
|-----------|----------|----------|
| Workspace Rust | 12 | Haute |
| CLI Rust | 10 | Haute |
| Daemon Watch | 4 | Haute |
| Modèle ML | 4 | Moyenne |
| Extension VS Code | 8 | Moyenne |
| Backend SaaS | 10 | Moyenne |
| Pipeline ML Python | 6 | Moyenne |
| Frontend Web | 8 | Basse |
| CI/CD | 3 | Moyenne |
| Configs/fixtures | 6 | Moyenne |
| Documentation | 2 | Moyenne |
| **Total** | **73** | |

## Structure du projet

```
gitpulse/
├── Cargo.toml
├── README.md
├── LICENSE
├── .gitignore
├── .gitpulse.yml
├── crates/
│   ├── gitpulse-core/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── error.rs
│   │       ├── diff/
│   │       │   ├── mod.rs
│   │       │   ├── analyzer.rs
│   │       │   ├── filter.rs
│   │       │   └── history.rs
│   │       ├── message/
│   │       │   ├── mod.rs
│   │       │   ├── generator.rs
│   │       │   └── conventional.rs
│   │       ├── config/
│   │       │   ├── mod.rs
│   │       │   ├── schema.rs
│   │       │   └── loader.rs
│   │       └── git/
│   │           ├── mod.rs
│   │           └── repo.rs
│   ├── gitpulse-cli/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── commands/
│   │       │   ├── mod.rs
│   │       │   ├── draft.rs
│   │       │   ├── watch.rs
│   │       │   └── config.rs
│   │       └── ui/
│   │           ├── mod.rs
│   │           ├── theme.rs
│   │           ├── panels.rs
│   │           ├── input.rs
│   │           └── app.rs
│   ├── gitpulse-watch/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── watcher.rs
│   │       └── scheduler.rs
│   └── gitpulse-model/
│       ├── Cargo.toml
│       └── src/
│           ├── lib.rs
│           ├── inference.rs
│           └── fallback.rs
├── extension/
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── extension.ts
│   │   ├── gitpulse.ts
│   │   ├── panels/
│   │   │   └── sidebar.ts
│   │   └── commands/
│   │       └── commit.ts
│   └── webview/
│       ├── index.html
│       └── main.ts
├── backend/
│   ├── Cargo.toml
│   ├── Dockerfile
│   └── src/
│       ├── main.rs
│       ├── config.rs
│       ├── routes/
│       │   ├── mod.rs
│       │   ├── auth.rs
│       │   └── stats.rs
│       ├── models/
│       │   └── mod.rs
│       ├── db/
│       │   └── mod.rs
│       └── middleware/
│           └── auth.rs
├── ml/
│   ├── pyproject.toml
│   └── src/
│       ├── collect.py
│       ├── preprocess.py
│       ├── train.py
│       ├── evaluate.py
│       └── export.py
├── web/
│   ├── package.json
│   ├── next.config.js
│   └── src/
│       └── app/
│           ├── layout.tsx
│           ├── page.tsx
│           └── dashboard/
│               └── page.tsx
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── release.yml
│       └── model-train.yml
├── config/
│   └── default-theme.yml
└── tests/
    └── fixtures/
        ├── repos/
        │   └── simple/
        │       └── .gitkeep
        └── diffs/
            ├── feat.diff
            └── fix.diff
```

---

## Phase 1 : Workspace + gitpulse-core

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 1 | `Cargo.toml` | Workspace racine avec les 4 crates |
| 2 | `crates/gitpulse-core/Cargo.toml` | Dépendances core (git2, serde, regex, etc.) |
| 3 | `crates/gitpulse-core/src/lib.rs` | Module public + exports |
| 4 | `crates/gitpulse-core/src/error.rs` | Type `GitPulseError` avec thiserror |
| 5 | `crates/gitpulse-core/src/diff/mod.rs` | Module diff |
| 6 | `crates/gitpulse-core/src/diff/analyzer.rs` | `DiffAnalyzer`, `DiffInfo`, `FileChange` |
| 7 | `crates/gitpulse-core/src/diff/filter.rs` | `FileFilter` avec .gitignore + config |
| 8 | `crates/gitpulse-core/src/diff/history.rs` | Extraction historique git |
| 9 | `crates/gitpulse-core/src/message/mod.rs` | Module message |
| 10 | `crates/gitpulse-core/src/message/generator.rs` | `MessageGenerator` heuristique |
| 11 | `crates/gitpulse-core/src/message/conventional.rs` | Format conventional commits |
| 12 | `crates/gitpulse-core/src/config/mod.rs` | Module config |
| 13 | `crates/gitpulse-core/src/config/schema.rs` | `GitPulseConfig` (serde) |
| 14 | `crates/gitpulse-core/src/config/loader.rs` | Chargement hiérarchique |
| 15 | `crates/gitpulse-core/src/git/mod.rs` | Module git |
| 16 | `crates/gitpulse-core/src/git/repo.rs` | Opérations git (commit, push, diff) |

### Dépendances gitpulse-core

```toml
[dependencies]
git2 = "0.18"
regex = "1"
once_cell = "1"
glob = "0.3"
ignore = "0.4"
chrono = "0.4"
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
dirs = "5"
anyhow = "1"
thiserror = "1"
```

---

## Phase 2 : gitpulse-cli + UI TUI

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 17 | `crates/gitpulse-cli/Cargo.toml` | Dépendances CLI (ratatui, crossterm, clap) |
| 18 | `crates/gitpulse-cli/src/main.rs` | Point d'entrée + parsing args |
| 19 | `crates/gitpulse-cli/src/commands/mod.rs` | Module commands |
| 20 | `crates/gitpulse-cli/src/commands/draft.rs` | Commande `draft` |
| 21 | `crates/gitpulse-cli/src/commands/watch.rs` | Commande `watch` |
| 22 | `crates/gitpulse-cli/src/commands/config.rs` | Commande `config` |
| 23 | `crates/gitpulse-cli/src/ui/mod.rs` | Module UI |
| 24 | `crates/gitpulse-cli/src/ui/theme.rs` | Thèmes (catppuccin mocha/latte) |
| 25 | `crates/gitpulse-cli/src/ui/panels.rs` | Panels (status, messages, diff) |
| 26 | `crates/gitpulse-cli/src/ui/input.rs` | Input bar avec keybindings |
| 27 | `crates/gitpulse-cli/src/ui/app.rs` | Application TUI (state machine) |

### Dépendances gitpulse-cli

```toml
[dependencies]
gitpulse-core = { path = "../gitpulse-core" }
gitpulse-watch = { path = "../gitpulse-watch" }
clap = { version = "4", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
ratatui = "0.26"
crossterm = { version = "0.27", features = ["event-stream"] }
console = "0.15"
dialoguer = "0.11"
indicatif = "0.17"
notify-rust = "4"
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
anyhow = "1"
thiserror = "1"
syntect = "5"
unicode-width = "0.1"
```

---

## Phase 3 : gitpulse-watch (daemon)

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 28 | `crates/gitpulse-watch/Cargo.toml` | Dépendances daemon |
| 29 | `crates/gitpulse-watch/src/lib.rs` | Module daemon |
| 30 | `crates/gitpulse-watch/src/watcher.rs` | `FileWatcher` (notify crate) |
| 31 | `crates/gitpulse-watch/src/scheduler.rs` | `CommitScheduler` |

### Dépendances gitpulse-watch

```toml
[dependencies]
gitpulse-core = { path = "../gitpulse-core" }
notify = "6"
tokio = { version = "1", features = ["full"] }
notify-rust = "4"
anyhow = "1"
```

---

## Phase 4 : gitpulse-model (ML)

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 32 | `crates/gitpulse-model/Cargo.toml` | Dépendances ML |
| 33 | `crates/gitpulse-model/src/lib.rs` | Module ML |
| 34 | `crates/gitpulse-model/src/inference.rs` | Inférence ONNX |
| 35 | `crates/gitpulse-model/src/fallback.rs` | Mode heuristique |

### Dépendances gitpulse-model

```toml
[dependencies]
ort = "2"
tokenizers = "0.15"
serde = { version = "1", features = ["derive"] }
anyhow = "1"
```

---

## Phase 5 : Extension VS Code

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 36 | `extension/package.json` | Manifeste VS Code |
| 37 | `extension/tsconfig.json` | Config TypeScript |
| 38 | `extension/src/extension.ts` | Point d'entrée extension |
| 39 | `extension/src/gitpulse.ts` | Client GitPulse CLI |
| 40 | `extension/src/panels/sidebar.ts` | Panel latéral |
| 41 | `extension/src/commands/commit.ts` | Commande commit |
| 42 | `extension/webview/index.html` | UI webview |
| 43 | `extension/webview/main.ts` | Script webview |

---

## Phase 6 : Backend SaaS

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 44 | `backend/Cargo.toml` | Dépendances backend |
| 45 | `backend/Dockerfile` | Container Docker |
| 46 | `backend/src/main.rs` | Serveur Axum |
| 47 | `backend/src/config.rs` | Config backend |
| 48 | `backend/src/routes/mod.rs` | Routes |
| 49 | `backend/src/routes/auth.rs` | Auth GitHub/GitLab |
| 50 | `backend/src/routes/stats.rs` | Stats productivité |
| 51 | `backend/src/models/mod.rs` | Modèles DB |
| 52 | `backend/src/db/mod.rs` | Connexion DB |
| 53 | `backend/src/middleware/auth.rs` | Auth middleware |

### Dépendances backend

```toml
[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sqlx = { version = "0.7", features = ["runtime-tokio", "postgres"] }
redis = { version = "0.24", features = ["tokio-comp"] }
tower-http = { version = "0.5", features = ["cors"] }
jsonwebtoken = "9"
oauth2 = "4"
reqwest = { version = "0.11", features = ["json"] }
anyhow = "1"
```

---

## Phase 7 : Pipeline ML Python

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 54 | `ml/pyproject.toml` | Config Python (poetry/uv) |
| 55 | `ml/src/collect.py` | Collecte commits depuis git |
| 56 | `ml/src/preprocess.py` | Tokenisation + prétraitement |
| 57 | `ml/src/train.py` | Fine-tuning CodeT5 |
| 58 | `ml/src/evaluate.py` | Évaluation BLEU/ROUGE |
| 59 | `ml/src/export.py` | Export modèle ONNX |

---

## Phase 8 : Frontend Web

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 60 | `web/package.json` | Dépendances Next.js |
| 61 | `web/next.config.js` | Config Next.js |
| 62 | `web/src/app/layout.tsx` | Layout principal |
| 63 | `web/src/app/page.tsx` | Page d'accueil |
| 64 | `web/src/app/dashboard/page.tsx` | Dashboard |
| 65 | `web/src/components/StatsCard.tsx` | Carte stats |
| 66 | `web/src/components/CommitHistory.tsx` | Historique commits |
| 67 | `web/src/lib/api.ts` | Client API |

---

## Phase 9 : CI/CD + Configs

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 68 | `.github/workflows/ci.yml` | Tests + lint + build |
| 69 | `.github/workflows/release.yml` | Release binaries |
| 70 | `.github/workflows/model-train.yml` | Entraînement ML |
| 71 | `.gitpulse.yml` | Config par défaut |
| 72 | `.gitignore` | Git ignore |
| 73 | `config/default-theme.yml` | Thème catppuccin |

---

## Phase 10 : Tests + Documentation

### Fichiers à créer

| # | Fichier | Description |
|---|---------|-------------|
| 74 | `tests/fixtures/repos/simple/.gitkeep` | Repo test basique |
| 75 | `tests/fixtures/diffs/feat.diff` | Diff feat |
| 76 | `tests/fixtures/diffs/fix.diff` | Diff fix |
| 77 | `README.md` | Documentation principale |
| 78 | `LICENSE` | MIT License |

---

## Ordre de création recommandé

```
1. Workspace + gitpulse-core (fichiers 1-16)
   └─ Priorité absolue, tout le reste en dépend

2. gitpulse-cli + UI (fichiers 17-27)
   └─ Le produit visible, le plus important pour le portfolio

3. gitpulse-watch (fichiers 28-31)
   └─ Complète la CLI

4. gitpulse-model (fichiers 32-35)
   └─ Optionnel pour le MVP, peut attendre

5. Extension VS Code (fichiers 36-43)
   └─ Bonus portfolio, pas critique

6. Backend SaaS (fichiers 44-53)
   └─ Phase 2 du produit

7. Pipeline ML (fichiers 54-59)
   └─ Nécessaire pour entraîner le modèle

8. Frontend Web (fichiers 60-67)
   └─ Dashboard pour le SaaS

9. CI/CD (fichiers 68-73)
   └─ Important mais peut être ajouté après

10. Tests + Docs (fichiers 74-78)
    └─ Continu tout au long du développement
```

---

## Critères de validation par phase

### Phase 1 ✅
- [ ] `cargo build` passe sans erreur
- [ ] Les modules core sont testables
- [ ] Config YAML se charge correctement

### Phase 2 ✅
- [ ] `gitpulse draft` affiche un message
- [ ] L'interface TUI s'affiche
- [ ] Les keybindings fonctionnent

### Phase 3 ✅
- [ ] `gitpulse watch` détecte les changements
- [ ] Les notifications s'affichent
- [ ] Le commit automatique fonctionne

### Phase 4 ✅
- [ ] Le modèle ONNX se charge
- [ ] L'inférence retourne un message
- [ ] Le fallback heuristique fonctionne

### Phase 5 ✅
- [ ] L'extension se charge dans VS Code
- [ ] Le panel latéral affiche les infos
- [ ] Le bouton commit fonctionne

### Phase 6 ✅
- [ ] Le serveur démarre
- [ ] L'auth GitHub fonctionne
- [ ] Les stats sont retournées

### Phase 7 ✅
- [ ] La collecte de commits fonctionne
- [ ] Le modèle s'entraîne
- [ ] L'export ONNX fonctionne

### Phase 8 ✅
- [ ] Le dashboard s'affiche
- [ ] Les données sont chargées
- [ ] La navigation fonctionne

### Phase 9 ✅
- [ ] La CI passe sur chaque PR
- [ ] La release crée les binaires
- [ ] Le modèle s'entraîne automatiquement

### Phase 10 ✅
- [ ] Les tests passent
- [ ] Le README est complet
- [ ] La license est présente
