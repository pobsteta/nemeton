# 🌳 Nemeton — Guide couverture automatique avec Claude Code

## TL;DR

```bash
cd nemeton
chmod +x nemeton-coverage-loop.sh
./nemeton-coverage-loop.sh
# ☕ allez prendre un café, revenez dans 1-2h
```

## Prérequis

### 1. Claude Code CLI
```bash
npm install -g @anthropic-ai/claude-code
export ANTHROPIC_API_KEY="sk-ant-..."
```

### 2. R + packages de test
```bash
Rscript -e 'install.packages(c("testthat","covr","shinytest2","chromote","devtools","withr"), repos="https://cloud.r-project.org")'
```

### 3. Chrome/Chromium (pour shinytest2 E2E)
```bash
# Linux
sudo apt-get install -y chromium-browser
# macOS
brew install --cask chromium
```

### 4. Outils système
```bash
sudo apt-get install -y bc  # calculatrice (Linux)
```

## Installation

```bash
git clone https://github.com/pobsteta/nemeton.git
cd nemeton

# Copier les fichiers
cp /chemin/vers/nemeton-coverage-loop.sh .
chmod +x nemeton-coverage-loop.sh

# Fusionner le contenu de CLAUDE-tests-addendum.md dans le CLAUDE.md existant
cat /chemin/vers/CLAUDE-tests-addendum.md >> CLAUDE.md
```

## Lancement

### Option A — Direct (recommandé pour commencer)

```bash
./nemeton-coverage-loop.sh
```

### Option B — tmux (production, session persistante)

```bash
tmux new -s coverage
./nemeton-coverage-loop.sh
# Détacher : Ctrl+B puis D
# Réattacher : tmux attach -t coverage
```

### Option C — Docker (isolation maximale)

```dockerfile
FROM rocker/r-ver:4.4.0

RUN apt-get update && apt-get install -y \
    git bc curl nodejs npm chromium \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libudunits2-dev libgdal-dev libgeos-dev libproj-dev \
    && npm install -g @anthropic-ai/claude-code

RUN Rscript -e 'install.packages(c( \
    "testthat","covr","shinytest2","chromote","devtools","withr", \
    "shiny","sf","terra","ggplot2","remotes" \
  ), repos="https://cloud.r-project.org")'

ENV CHROMOTE_CHROME=/usr/bin/chromium
WORKDIR /app
COPY . .
CMD ["./nemeton-coverage-loop.sh"]
```

```bash
docker build -t nemeton-coverage .
docker run -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -v $(pwd):/app nemeton-coverage
```

## Configuration

Éditez le haut du script :

| Variable | Défaut | Description |
|---|---|---|
| `TARGET_COVERAGE` | `80` | Taux cible (%) |
| `MAX_ITERATIONS` | `60` | Nombre max de boucles |
| `MAX_TURNS_PER_ITER` | `50` | Tours Claude Code par itération |
| `SLEEP_BETWEEN` | `10` | Pause entre itérations (sec) |
| `MAX_STAGNATION` | `3` | Itérations sans progrès avant de changer de cible |

## Comment ça marche

```
┌──────────────────────────────────────────────────┐
│  Boucle principale (bash)                        │
│                                                  │
│  1. Mesure couverture via covr::package_coverage │
│  2. Collecte détails par fichier + zero_coverage │
│  3. Détecte les fichiers Shiny (moduleServer...) │
│  4. Envoie tout le contexte à Claude Code        │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Claude Code (une itération)               │  │
│  │                                            │  │
│  │  • Lit le fichier le moins couvert         │  │
│  │  • Écrit des tests testthat                │  │
│  │  • Pour les modules Shiny :                │  │
│  │    - testServer() → contribue à covr ✅    │  │
│  │    - AppDriver (E2E) → intégration 🔗      │  │
│  │  • Lance devtools::test()                  │  │
│  │  • Corrige si tests échouent               │  │
│  │  • Vérifie la couverture                   │  │
│  │  • git commit                              │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  5. Remesure la couverture                       │
│  6. Si < cible → reboucle                        │
│  7. Détecte stagnation → change de fichier cible │
└──────────────────────────────────────────────────┘
```

## Point important : covr et Shiny

| Méthode de test | Contribue à covr ? | Quand l'utiliser |
|---|---|---|
| `test_that()` + fonctions R | ✅ Oui | Toujours — fonctions pures |
| `testServer()` | ✅ Oui | Toujours — logique serveur des modules |
| `shinytest2::AppDriver` | ❌ Non* | Tests E2E, intégration, interactions UI |

\* AppDriver lance l'app dans un processus séparé, hors instrumentation covr.
Le script privilégie `testServer()` pour maximiser la couverture mesurée.

## Suivi en temps réel

```bash
# Log en direct
tail -f coverage-loop.log

# Couverture manuelle
Rscript -e 'cat(covr::percent_coverage(covr::package_coverage(quiet=TRUE)))'

# Rapport HTML
Rscript -e 'covr::report(covr::package_coverage())'
```

## Après exécution

```bash
# 1. Voir les changements
git log --oneline feat/auto-coverage-boost
git diff main..feat/auto-coverage-boost --stat

# 2. Vérifier que tout passe
Rscript -e 'devtools::test()'

# 3. Inspecter la couverture
Rscript -e 'covr::report(covr::package_coverage())'

# 4. Merge si satisfait
git checkout main
git merge feat/auto-coverage-boost
```

## Coûts estimés (API Claude)

| Départ | Cible | Itérations estimées | Coût API approx. |
|---|---|---|---|
| 40% | 80% | 20-40 | $20 - $80 |
| 50% | 80% | 15-25 | $15 - $50 |
| 60% | 80% | 8-15 | $8 - $30 |

> Avec un plan Max Claude Code, tout est inclus dans l'abonnement.

## Dépannage

| Problème | Solution |
|---|---|
| `covr::package_coverage()` échoue | `Rscript -e 'devtools::check()'` pour voir les erreurs |
| shinytest2 : "Chrome not found" | `export CHROMOTE_CHROME=/usr/bin/chromium` |
| Tests existants cassés | Le script ne devrait jamais modifier R/ — vérifier |
| Stagnation prolongée | Le script change automatiquement de cible |
| Rate limiting Claude | Augmenter `SLEEP_BETWEEN` à 30-60 |
| Couverture ne bouge pas | Vérifier que les tests sont dans `tests/testthat/` |
| `testServer()` échoue sur un module | Le module a peut-être des dépendances non mockées |

## Fichiers fournis

| Fichier | Destination | Rôle |
|---|---|---|
| `nemeton-coverage-loop.sh` | Racine du projet | Boucle autonome principale |
| `CLAUDE-tests-addendum.md` | Fusionner dans `CLAUDE.md` | Conventions de test R/Shiny pour Claude Code |
| `README-coverage.md` | Pour vous (référence) | Ce guide |
