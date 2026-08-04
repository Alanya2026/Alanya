# GitPulse — Concept Affiné

> Assistant git intelligent qui comprend ton workflow, génère des messages conventionnels, et automatise ton cycle git.

## Vision

GitPulse est un **assistant git intelligent** qui :
1. **Comprend** ton code et tes patterns de travail
2. **Génère** des messages de commit conventionnels contextuels
3. **Respecte** tes règles de commit configurables
4. **Automatise** le cycle commit/push selon tes préférences
5. **S'apprend** de toi — plus tu l'utilises, plus il est précis

## Problèmes résolus

| Problème | Impact | Solution GitPulse |
|----------|--------|-------------------|
| Messages "fix", "update", "wip" | Historique illisible | Génération de messages conventionnels (feat, fix, chore, test, refactor, deploy, docs, style, perf, ci, build...) |
| Oublier de push/commit | Perte de travail | Mode daemon configurable |
| Temps perdu à formuler des messages | Interruption du flow | Validation en 1 clic ou full auto |
| Pas de visibilité sur sa productivité | Difficile de s'améliorer | Dashboard et stats |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    GitPulse                          │
├─────────────┬──────────────┬────────────────────────┤
│   CLI       │   Daemon     │   VS Code Extension    │
│  (Rust)     │   (Rust)     │   (TypeScript)         │
├─────────────┴──────────────┴────────────────────────┤
│                    Core Engine (Rust)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ Diff Analyzer│  │   Message    │  │  Config   │  │
│  │  + History   │  │  Generator   │  │  Manager  │  │
│  └──────────────┘  └──────────────┘  └───────────┘  │
├─────────────────────────────────────────────────────┤
│              ML Layer                                │
│  ┌──────────────┐  ┌──────────────┐                  │
│  │ ONNX Runtime │  │  Training    │                  │
│  │  (local)     │  │  Pipeline    │                  │
│  └──────────────┘  └──────────────┘                  │
├─────────────────────────────────────────────────────┤
│           Backend SaaS (Rust - Axum)                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │   Auth   │  │  Stats   │  │  Model Serving   │   │
│  └──────────┘  └──────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Les 3 interfaces

### 1. CLI (Rust)
```bash
# Mode draft — analyse et propose
gitpulse draft              # Analyse les diffs, propose un message
gitpulse draft --auto       # Propose et commit si OK
gitpulse draft --push       # Propose, commit, et push

# Mode watch — daemon en arrière-plan
gitpulse watch              # Commit automatique intelligent
gitpulse watch --dry-run    # Simule sans rien faire
gitpulse watch --interval 5m # Intervalle de check

# Configuration
gitpulse config init        # Génère .gitpulse.yml
gitpulse config show        # Affiche la config actuelle
gitpulse config set key val # Modifie un paramètre

# Historique et stats
gitpulse log                # Historique formaté
gitpulse stats              # Stats de productivité
gitpulse stats --week       # Cette semaine
```

### 2. Daemon (Rust)
- Tourne en arrière-plan via systemd/launchd
- Surveille les changements dans les repos configurés
- Commit intelligemment (regroupe les changements logiques)
- **Notifications desktop** : alerte quand un commit est prêt
- **Propositions de commits** : message suggéré avec preview du diff
- Mode draft : notifie et attend validation (clic ou commande)
- Mode auto : commit + push selon les règles

### 3. VS Code Extension (TypeScript)
- **Panel latéral** avec preview du commit à venir
- Bouton "Commit & Push" en 1 clic
- Éditeur de message inline
- Historique des commits récents
- Stats de productivité intégrées
- **Notifications** : alertes desktop quand un commit est proposé
- **Propositions** : suggestions de commits en temps réel via le daemon

## Configuration flexible

### Hiérarchie des configs

```
1. Defaults (built-in)          ← conventional commits par défaut
         ↓
2. Globale (~/.gitpulse.yml)    ← tes préférences perso
         ↓
3. Par repo (.gitpulse.yml)     ← overrides par projet
         ↓
4. Extension (settings.json)    ← overrides dans VS Code
```

### Fichier de config

```yaml
# .gitpulse.yml
version: "1"

# Format de commit
commit:
  format: conventional  # conventional | angular | simple | custom
  language: fr          # fr | en | auto (détection)
  scope: true           # Ajouter le scope automatiquement
  emoji: false          # Ajouter des emojis
  # Types supportés (conventional commits) :
  # feat, fix, chore, test, refactor, deploy, docs, style, perf, ci, build, revert

# Scope rules
scope_rules:
  # Map les patterns de fichiers aux scopes
  patterns:
    - match: "src/api/**"
      scope: "api"
    - match: "src/ui/**"
      scope: "ui"
    - match: "tests/**"
      scope: "test"
    - match: "docs/**"
      scope: "docs"
    - match: "*.md"
      scope: "docs"
    - match: "package.json"
      scope: "deps"

# Fichiers à ignorer (en plus de .gitignore)
ignore:
  patterns:
    - "*.lock"
    - "*.log"
    - ".env*"
    - "node_modules/**"
    - "target/**"

# Mode de fonctionnement
mode: draft  # draft | auto | watch

# Watch settings
watch:
  interval: 30s           # Intervalle de check
  idle_threshold: 60s     # Temps d'inactivité avant commit
  auto_push: false        # Push automatique après commit

# Modèle ML
model:
  source: local           # local | cloud | hybrid
  language: auto          # Détection automatique de la langue
```

## Le modèle de génération de messages

### Approche : Fine-tuning sur l'histoire git

**3 niveaux de fonctionnement :**

```
Niveau 1 : Heuristique (pas de modèle)
├─ Analyse les noms de fichiers modifiés
├─ Détecte le type (feat, fix, refactor...)
├─ Génère un message basique
└─ Fonctionne sans GPU ni internet

Niveau 2 : Modèle local (~50MB)
├─ CodeT5 fine-tuné sur les commits
├─ Tourne via ONNX Runtime (pas de Python)
├─ Message contextuel basé sur le diff
└─ Fonctionne offline

Niveau 3 : Modèle cloud (optionnel)
├─ Modèle plus gros + historique étendu
├─ Meilleure compréhension sémantique
├─ API REST avec auth
└─ Requiert internet
```

### Pipeline d'entraînement

```
1. Collecte
   └─ Extraire les commits d'un repo (hash, message, diffs)
   └─ Filtrer les messages de mauvaise qualité
   └─ Extraire les patterns de l'utilisateur

2. Prétraitement
   └─ Tokeniser les diffs (fichier + hunks)
   └─ Associer chaque diff au message correspondant
   └─ Augmenter : reformulations, traductions
   └─ Ajouter les scopes depuis les patterns configurés

3. Entraînement
   └─ Modèle de base : CodeT5 (pré-entraîné sur du code)
   └─ Fine-tuning sur les commits de l'utilisateur
   └─ Évaluation : BLEU, ROUGE, scoring humain

4. Export
   └─ Export en ONNX (~50MB)
   └─ Intégré dans le binaire Rust
   └─ Mise à jour via `gitpulse model update`
```

## Les 3 modes de fonctionnement

### Mode Draft (recommandé)
```
Utilisateur fait des modifs
         │
         ▼
   gitpulse draft
         │
         ▼
  ┌─────────────────┐
  │ Analyse le diff  │
  │ + historique     │
  │ Génère message   │
  │ [conventional]   │
  │ Affiche preview  │
  └─────────────────┘
         │
    [Valider] ou [Modifier]
         │
         ▼
   git commit + push
```

### Mode Watch (daemon)
```
gitpulse watch
         │
         ▼
  ┌─────────────────────┐
  │ Surveille les repos  │
  │ Détecte changements  │
  │ Attend inactivité    │
  └─────────────────────┘
         │
    [changement détecté]
         │
         ▼
  ┌─────────────────────┐
  │ Regroupe logiquement │
  │ Génère message       │
  │ [auto | draft]       │
  └─────────────────────┘
```

### Mode Auto (pour les confiants)
```
gitpulse watch --auto
         │
         ▼
  Changement détecté → inactivité 60s
         │
         ▼
  git add → git commit → git push
         │
         ▼
  Notification : "3 fichiers commités: feat(auth): add OAuth2 flow"
```

## Backend SaaS

### Fonctionnalités
- **Auth** : GitHub/GitLab OAuth
- **Dashboard web** : historique, stats, configuration
- **Model serving** : modèle cloud pour les users Pro
- **Team features** : standards de commit partagés
- **Pricing**
  - Free : CLI locale, heuristiques, mode draft
  - Pro ($8/mois) : modèle entraîné, mode daemon, stats
  - Team ($15/mois) : standards partagés, dashboard équipe

### Tech stack backend
- **Runtime** : Rust (Axum)
- **DB** : PostgreSQL + Redis
- **ML Serving** : ONNX Runtime
- **Deploy** : Docker + Fly.io

## Différenciation

| Concurrent | GitPulse |
|-----------|----------|
| git-auto-commit | Messages intelligents + conventionnels |
| commitizen | Apprend de toi, pas juste des templates |
| husky + lint-staged | Multi-langage, pas limité à Node.js |
| GitHub Copilot commit | Fonctionne en local, open-source |
| aicommits | Règles configurables + modes multiples |

## Roadmap MVP

### Phase 1 — Core CLI (4 semaines)
- [ ] CLI Rust avec structure modulaire
- [ ] Commande `draft` avec analyse de diff
- [ ] Messages heuristiques (conventional commits)
- [ ] Fichier `.gitpulse.yml` avec config de base
- [ ] Scope rules basiques
- [ ] Tests unitaires

### Phase 2 — Watch + Config (3 semaines)
- [ ] Commande `watch` (daemon simple)
- [ ] Détection d'inactivité
- [ ] Config globale + par repo
- [ ] Support multilingue (fr/en)
- [ ] Commande `config` interactive

### Phase 3 — ML Local (4 semaines)
- [ ] Pipeline d'entraînement Python
- [ ] Fine-tuning de CodeT5
- [ ] Export ONNX
- [ ] Intégration ONNX Runtime dans Rust
- [ ] Mode hybrid (local + cloud fallback)

### Phase 4 — Extension VS Code (2 semaines)
- [ ] Panel latéral avec preview
- [ ] Éditeur de message
- [ ] Bouton commit rapide
- [ ] Intégration avec le daemon

### Phase 5 — Backend SaaS (4 semaines)
- [ ] Auth + dashboard web
- [ ] Model serving cloud
- [ ] Stats et analytics
- [ ] Pricing

## Stack technique résumée

| Composant | Technologie |
|-----------|-------------|
| CLI + Daemon | Rust (clap, tokio, notify) |
| Extension VS Code | TypeScript |
| ML Training | Python (PyTorch, transformers) |
| ML Inference | ONNX Runtime (Rust binding) |
| Backend API | Rust (Axum) |
| Database | PostgreSQL |
| Cache | Redis |
| Frontend web | React/Next.js |
| Deploy | Docker + Fly.io |
