# Implementation Plan: MVP Package nemeton v0.1.0

**Branch**: `001-mvp-v0.1.0` | **Date**: 2026-01-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-mvp-v0.1.0/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Créer le MVP du package R **nemeton** pour l'analyse forestière systémique selon la méthode Néméton. Le package permet aux forestiers, écologues et gestionnaires de territoires de calculer des indicateurs biophysiques (carbone, biodiversité, eau, fragmentation, accessibilité) à partir de données spatiales ouvertes, de les normaliser en indices composites, et de visualiser les résultats via cartes et diagrammes radar.

**Approche technique**: Package R standard utilisant `sf` pour les vecteurs, `terra` pour les rasters, `exactextractr` pour l'extraction zonale performante, et `ggplot2` pour les visualisations. Architecture modulaire avec séparation claire entre acquisition de données, calcul d'indicateurs, normalisation/agrégation, et visualisation. Test-Driven Development avec fixtures pour garantir la stabilité scientifique des calculs.

## Technical Context

**Language/Version**: R >= 4.1.0
**Primary Dependencies**:
- `sf` >= 1.0-0 (manipulation vecteurs)
- `terra` >= 1.7-0 (manipulation rasters)
- `exactextractr` >= 0.9.0 (extraction zonale performante)
- `dplyr` >= 1.1.0 (manipulation de données)
- `ggplot2` >= 3.4.0 (visualisations)
- `rlang` >= 1.1.0 (métaprogrammation)
- `cli` >= 3.6.0 (messages formatés)

**Storage**: Fichiers (GeoTIFF, GeoPackage, shapefile) - pas de base de données pour MVP
**Testing**: `testthat` >= 3.0.0, fixtures `.rds` pour tests de régression, `covr` pour couverture
**Target Platform**: Multi-plateforme (Linux, macOS, Windows) via R standard
**Project Type**: Package R scientifique (single project)
**Performance Goals**:
- Support >= 100 unités avec 5 indicateurs en < 2 minutes sur laptop standard
- Extraction zonale optimisée via `exactextractr` (10x+ rapide que `raster::extract`)
- MVP sans calcul parallèle (v0.4.0+)

**Constraints**:
- Couverture de tests >= 70% (objectif MVP, 90% pour v1.0)
- `devtools::check()` doit passer sans erreurs/warnings
- Package size < 10 Mo (données d'exemple < 5 Mo)
- Documentation roxygen2 obligatoire pour toutes fonctions exportées
- Compatibilité tidyverse (pipe `%>%` et `|>`)

**Scale/Scope**:
- MVP: ~10-15 fonctions exportées
- 5 indicateurs biophysiques
- 2 types de visualisations
- 2 vignettes minimum
- Dataset d'exemple: 50 parcelles + 3-4 rasters fictifs
- ~2000-3000 LOC (sans tests)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Core Principles Compliance

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Open Data First** | ✅ PASS | Tous les exemples utiliseront données ouvertes/synthétiques. Indicateurs supportent IGN, Copernicus, OSM |
| **II. Interopérabilité R Spatial** | ✅ PASS | Support obligatoire `sf` et `terra`. Pas de `raster` ni `sp` legacy. Export GeoPackage/shapefile |
| **III. Modularité** | ✅ PASS | Architecture modulaire: 6 modules distincts (units, layers, preprocessing, indicators, normalization, visualization) |
| **IV. Test-First** | ✅ PASS | TDD strict, couverture >= 70% MVP (80% constitution), fixtures .rds pour régression |
| **V. Transparence** | ✅ PASS | Métadonnées obligatoires, messages `cli`, paramètres explicites |
| **VI. Extensibilité** | ⚠️ PARTIAL | API extensibilité (indicateurs custom) prévu mais implémentation simplifiée pour MVP. Complet en v0.3.0 |
| **VII. Simplicité** | ✅ PASS | MVP minimal: 5 indicateurs, 2 visualisations, pas de calcul parallèle, pas d'optimisations prématurées |

### ✅ Technical Constraints Compliance

| Constraint | Status | Notes |
|------------|--------|-------|
| **Stack obligatoire** | ✅ PASS | R >= 4.1.0, sf, terra, exactextractr, dplyr, ggplot2, rlang, cli |
| **Stack interdit** | ✅ PASS | Pas de `raster`, pas de `sp`, pas de dépendances propriétaires |
| **Paradigme fonctionnel** | ✅ PASS | Fonctions pures, classes S3, pipe-friendly |
| **Nommage** | ✅ PASS | Préfixes `nemeton_` et `indicator_`, snake_case, fichiers avec tirets |
| **Gestion erreurs** | ✅ PASS | Validation précoce, messages via `cli::cli_abort()`/`cli::cli_warn()` |

### ✅ Quality Standards Compliance

| Standard | Status | Notes |
|----------|--------|-------|
| **Documentation** | ✅ PASS | roxygen2 obligatoire, 2 vignettes minimum, README, exemples reproductibles |
| **Style** | ✅ PASS | Tidyverse style guide, lintr, styler, <= 80 caractères |
| **Performance** | ✅ PASS | Support >= 100 unités (constitution: >= 1000, mais MVP acceptable), lazy loading |
| **Versioning** | ✅ PASS | v0.1.0 (pre-release sémantique), API peut changer avant v1.0 |

### ⚠️ Partial Compliance (Acceptable for MVP)

| Item | MVP Status | Target for v1.0 |
|------|------------|-----------------|
| **Couverture tests** | 70% | 80% (constitution), 90% (objectif) |
| **Performance** | 100 unités | 1000 unités |
| **Extensibilité** | API simplifiée | `register_indicator()` complet |

**GATE STATUS**: ✅ **PASS** - Conformité suffisante pour MVP. Les écarts sont documentés et alignés avec principe VII (Simplicité/YAGNI).

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-v0.1.0/
├── spec.md              # Feature specification (user stories, requirements)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: décisions techniques, alternatives considérées
├── data-model.md        # Phase 1: classes S3, structures de données
├── quickstart.md        # Phase 1: guide démarrage rapide pour développeurs
├── contracts/           # Phase 1: signatures de fonctions, contrats d'API
│   ├── api-core.md      # Fonctions principales (nemeton_units, nemeton_layers, nemeton_compute)
│   ├── api-indicators.md # Fonctions d'indicateurs (indicator_*)
│   ├── api-normalization.md # Fonctions de normalisation (nemeton_index, normalize_*)
│   └── api-visualization.md # Fonctions de visualisation (nemeton_map, nemeton_radar)
└── tasks.md             # Phase 2: tâches d'implémentation (/speckit.tasks - NOT by this plan)
```

### Source Code (repository root)

```text
nemeton/                    # Package R standard
├── DESCRIPTION             # Métadonnées du package, dépendances
├── NAMESPACE               # Exports (généré par roxygen2)
├── LICENSE                 # Licence open source
├── README.md               # Introduction, installation, exemple rapide
├── NEWS.md                 # Changelog
│
├── R/                      # Code source R
│   ├── nemeton-package.R   # Documentation du package (@keywords internal)
│   ├── nemeton-class.R     # Définitions classes S3 (nemeton_units, nemeton_layers)
│   ├── data-units.R        # Gestion unités spatiales (nemeton_units, validate_units)
│   ├── data-layers.R       # Gestion couches (nemeton_layers, add_raster, add_vector)
│   ├── data-preprocessing.R # Harmonisation (harmonize_crs, crop_to_units, mask_to_units)
│   ├── indicators-core.R   # Moteur calcul (nemeton_compute, compute_indicator)
│   ├── indicators-biophysical.R # 5 indicateurs MVP (carbon, biodiversity, water, fragmentation, accessibility)
│   ├── normalization.R     # Normalisation et indices (nemeton_index, normalize_indicators)
│   ├── visualization.R     # Visualisations (nemeton_map, nemeton_radar)
│   ├── utils.R             # Utilitaires internes (check_crs, validate_sf, message_nemeton)
│   └── zzz.R               # Hooks .onLoad/.onAttach
│
├── man/                    # Documentation générée par roxygen2
│
├── data/                   # Datasets d'exemple exportés
│   └── massif_demo.rda     # Dataset d'exemple (50 parcelles + métadonnées)
│
├── data-raw/               # Scripts de préparation des datasets
│   └── massif_demo.R       # Script génération massif_demo.rda
│
├── inst/                   # Fichiers installés avec le package
│   ├── extdata/            # Données externes (rasters d'exemple)
│   │   ├── demo_ndvi.tif   # Raster NDVI fictif
│   │   ├── demo_dem.tif    # MNT fictif
│   │   └── demo_hydro.gpkg # Réseau hydro fictif
│   └── CITATION            # Citation du package
│
├── tests/                  # Tests
│   ├── testthat.R          # Configuration testthat
│   └── testthat/
│       ├── fixtures/       # Données de test
│       │   ├── demo_units.gpkg         # 10 polygones de test
│       │   ├── demo_raster_small.tif   # Petit raster de test
│       │   └── expected_carbon.rds     # Valeurs attendues pour tests régression
│       ├── test-units.R               # Tests module data-units
│       ├── test-layers.R              # Tests module data-layers
│       ├── test-preprocessing.R       # Tests module preprocessing
│       ├── test-indicators.R          # Tests des 5 indicateurs
│       ├── test-normalization.R       # Tests normalisation/indices
│       ├── test-visualization.R       # Tests visualisations
│       └── test-workflow.R            # Tests d'intégration (workflow complet)
│
└── vignettes/              # Documentation longue
    ├── intro-nemeton.Rmd   # Introduction à la méthode et au package
    └── workflow-basic.Rmd  # Workflow complet de A à Z
```

**Structure Decision**: Structure standard d'un package R scientifique (single project). Suit les conventions R Packages (Hadley Wickham) avec séparation claire entre code source (`R/`), tests (`tests/testthat/`), documentation (`man/`, `vignettes/`), et données (`data/`, `inst/extdata/`). Organisation modulaire du code source pour respecter le principe de séparation des responsabilités.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**N/A** - Aucune violation de la constitution nécessitant justification. Les écarts (couverture tests 70% vs 80%, performance 100 vs 1000 unités) sont acceptables pour un MVP selon principe VII (Simplicité/YAGNI) et seront corrigés dans versions ultérieures.
