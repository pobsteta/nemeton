# nemeton <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/pobsteta/nemeton/actions/workflows/r.yml/badge.svg)](https://github.com/pobsteta/nemeton/actions/workflows/r.yml)
[![Version](https://img.shields.io/badge/version-0.14.0-blue.svg?logo=github)](https://github.com/pobsteta/nemeton/releases/tag/v0.14.0)
[![pkgdown](https://github.com/pobsteta/nemeton/actions/workflows/pkgdown.yaml/badge.svg)](https://pobsteta.github.io/nemeton/)
[![Tests](https://img.shields.io/badge/tests-9000%2B%20passing-success.svg?logo=github-actions)](https://github.com/pobsteta/nemeton)
[![codecov](https://codecov.io/gh/pobsteta/nemeton/branch/main/graph/badge.svg)](https://codecov.io/gh/pobsteta/nemeton)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?logo=opensourceinitiative)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

> **Analyse systémique de territoires forestiers selon la méthode Nemeton**

`nemeton` est un package R pour l'analyse intégrée d'écosystèmes forestiers. Il calcule, normalise et visualise des **indicateurs biophysiques multi-famille** pour la gestion forestière durable.

## Fonctionnalités

**12 familles d'indicateurs** avec 29 sous-indicateurs :

| Famille | Description | Indicateurs |
|---------|-------------|-------------|
| **C** | Carbone & Vitalité | C1-C2 |
| **B** | Biodiversité | B1-B3 |
| **W** | Eau & Régulation | W1-W3 |
| **A** | Air & Microclimat | A1-A2 |
| **F** | Fertilité Sols | F1-F2 |
| **L** | Paysage | L1-L2 |
| **T** | Temporel | T1-T2 |
| **R** | Risques & Résilience | R1-R3 |
| **S** | Social & Usages | S1-S3 |
| **P** | Production & Économie | P1-P3 |
| **E** | Énergie & Climat | E1-E2 |
| **N** | Naturalité | N1-N3 |

**Outils d'analyse** : Pareto, clustering, trade-offs, radar 12-axes, corrélations.

## Installation

```r
# install.packages("remotes")
remotes::install_github("pobsteta/nemeton")
```

**Prérequis** : R >= 4.1.0, `sf`, `terra`, `ggplot2`

## Quick Start

```r
library(nemeton)

# Charger le dataset de démonstration (20 parcelles, 12 familles)
data(massif_demo_units)

# Visualiser le profil radar d'une parcelle
nemeton_radar(massif_demo_units, unit_id = 1, mode = "family")
```

<img src="man/figures/readme-radar.png" width="100%" />

```r
# Identifier les parcelles Pareto-optimales
pareto <- identify_pareto_optimal(
  massif_demo_units,
  objectives = c("family_C", "family_B"),
  maximize = c(TRUE, TRUE)
)

# Trade-offs avec frontière de Pareto
plot_tradeoff(pareto, x = "family_C", y = "family_B", pareto_frontier = TRUE)
```

<img src="man/figures/readme-tradeoff.png" width="100%" />

## Application Interactive (nemetonApp)

Pour une utilisation sans code, lancez l'application Shiny :

```r
library(nemeton)
run_app()
```

L'application permet de :

- Rechercher et sélectionner des parcelles cadastrales par commune
- Calculer automatiquement les 29 indicateurs (12 familles)
- Visualiser les résultats (radar, cartes, histogrammes)
- Exporter en PDF ou GeoPackage (auto-sauvegarde dans `exports/`)
- Commenter chaque famille avec assistance IA (ellmer)
- Consulter les profils d'experts personnalisables (YAML)

<img src="man/figures/readme-app.png" width="100%" />

## Workflow avec vos données

```r
library(nemeton)
library(sf)

# 1. Créer les unités d'analyse
units <- nemeton_units("parcelles.gpkg")

# 2. Cataloguer les couches spatiales
layers <- nemeton_layers(
  rasters = list(biomass = "biomass.tif", dem = "dem.tif"),
  vectors = list(roads = "roads.gpkg", water = "water.gpkg")
)

# 3. Calculer les indicateurs
results <- nemeton_compute(units, layers, indicators = "all")

# 4. Normaliser (échelle 0-100)
normalized <- normalize_indicators(results, method = "minmax")

# 5. Créer un indice composite
health <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  name = "ecosystem_health"
)

# 6. Visualiser
plot_indicators_map(health, indicators = "ecosystem_health", palette = "RdYlGn")
```

## Nouveautés v0.13.0

### Interface utilisateur
- **Popovers explicatifs** sur le radar et le score global pour guider l'utilisateur
- **Singulier/pluriel** automatique pour le compteur de parcelles
- **Gestion des profils experts** externalisés en YAML (`inst/experts/`), personnalisables dans `~/.nemeton/experts/`

### Export PDF
- Rendu Markdown complet (gras, italique, listes, tableaux) avec pagination
- Correction des chevauchements de texte et dimensionnement des colonnes
- Sauvegarde automatique dans le dossier `exports/` du projet

### Commentaires & Synthese
- Persistance fiable des commentaires IA (tryCatch, variable locale)
- Reset automatique lors du changement de projet
- Serialisation correcte des sorties ellmer

### Tests & Couverture
- **8000+ tests** sur 76 fichiers couvrant 47 fichiers source
- Tests `testServer()` pour les modules Shiny (contribuent a covr)
- Script de couverture parallele (`nemeton-coverage-loop.sh`) : N agents Claude simultanement, un par fichier

### Performance
- Chargement paresseux (lazy loading) des modules famille
- Assets minifies

## Documentation

```r
# Vignettes
vignette("getting-started_fr", package = "nemeton")
vignette("nemetonapp-guide_fr", package = "nemeton")
vignette("indicator-families_fr", package = "nemeton")
vignette("temporal-analysis_fr", package = "nemeton")

# Aide
?nemeton_compute
?create_family_index
?run_app
```

## Licence

MIT - Voir [LICENSE](LICENSE)

## Citation

```
Obstetar, P. (2026). nemeton: Systemic Forest Analysis Using the Nemeton Method.
R package version 0.13.0. https://github.com/pobsteta/nemeton
```

---

**Developpe avec** ❤️ **et** [Claude Code](https://claude.com/claude-code)
