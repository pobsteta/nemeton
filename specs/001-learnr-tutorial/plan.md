# Implementation Plan: Tutoriels Interactifs nemeton

**Branch**: `001-learnr-tutorial` | **Date**: 2026-01-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-learnr-tutorial/spec.md`

## Summary

Série de 6 tutoriels interactifs learnr pour le package R nemeton, permettant aux apprenants de maîtriser progressivement le workflow complet d'analyse écosystémique forestière : depuis l'acquisition des données géographiques (cadastre, MNT, BD Forêt, LiDAR HD) jusqu'au calcul et à l'analyse des 12 familles d'indicateurs écosystémiques.

## Technical Context

**Language/Version**: R >= 4.1.0 (compatible nemeton v0.4.0+)
**Primary Dependencies**:
- Core: sf, terra, ggplot2, dplyr
- Tutorial: learnr (>= 0.11.0), gradethis (>= 0.2.0)
- Acquisition: happign (>= 0.2.0), lidarHD
- LiDAR: lidR (>= 4.0.0), lidaRtRee
- Visualisation: leaflet, patchwork, corrplot
- Cache: rappdirs

**Storage**:
- GeoPackage (.gpkg) pour données vectorielles
- GeoTIFF (.tif) pour rasters
- Cache local: `rappdirs::user_data_dir("nemeton")`

**Testing**: testthat (>= 3.0.0), gradethis pour validation exercices

**Target Platform**: Cross-platform (Windows, macOS, Linux) via RStudio/R console

**Project Type**: R Package avec tutoriels learnr intégrés

**Performance Goals**:
- Chargement données cache < 10 secondes
- Calcul indicateurs (50 parcelles) < 30 secondes
- Génération rapport HTML < 30 secondes

**Constraints**:
- RAM: 4 GB minimum (traitement LiDAR)
- Disque: 2 GB pour cache données
- Internet: requis pour téléchargement initial

**Scale/Scope**:
- 6 tutoriels × 7-10 sections chacun
- Zone d'étude: 20-100 parcelles (Vercors)
- 12 familles × 2-3 indicateurs = 40+ indicateurs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Statut | Notes |
|----------|--------|-------|
| Package R standard | ✅ Pass | Structure `inst/tutorials/` conforme |
| Tests unitaires | ✅ Pass | testthat pour fonctions, gradethis pour exercices |
| Documentation | ✅ Pass | roxygen2 + vignettes + tutoriels |
| Simplicité | ✅ Pass | Un tutoriel = un fichier .Rmd |
| Dépendances optionnelles | ✅ Pass | Tous packages dans Suggests |

**Gate Status**: PASS - Aucune violation détectée

## Project Structure

### Documentation (this feature)

```text
specs/001-learnr-tutorial/
├── spec.md              # Spécification complète
├── plan.md              # Ce fichier
├── research.md          # Phase 0: Recherche technique
├── data-model.md        # Phase 1: Modèle de données
├── quickstart.md        # Phase 1: Guide démarrage rapide
├── contracts/           # Phase 1: Contrats API
│   └── indicators.yaml  # Schéma indicateurs
├── checklists/
│   └── requirements.md  # Checklist qualité
└── tasks.md             # Phase 2: Tâches (via /speckit.tasks)
```

### Source Code (repository root)

```text
nemeton/
├── R/
│   ├── indicators-*.R          # Fonctions indicateurs (existant)
│   ├── normalization.R         # Normalisation (existant)
│   ├── analysis-correlation.R  # Analyse (existant)
│   └── tutorial-helpers.R      # Helpers tutoriels (à créer si besoin)
│
├── inst/
│   └── tutorials/
│       ├── 01-acquisition/     # ✅ Complété (~95%)
│       │   └── 01-acquisition.Rmd
│       ├── 02-lidar/           # 🔲 À créer
│       │   └── 02-lidar.Rmd
│       ├── 03-terrain/         # 🔲 À créer
│       │   └── 03-terrain.Rmd
│       ├── 04-ecological/      # 🔲 À créer
│       │   └── 04-ecological.Rmd
│       ├── 05-complete/        # 🔲 À créer
│       │   └── 05-complete.Rmd
│       └── 06-analysis/        # 🔲 À créer
│           └── 06-analysis.Rmd
│
├── tests/
│   └── testthat/
│       ├── test-tutorial-01.R  # Tests tutoriel acquisition
│       ├── test-tutorial-02.R  # Tests tutoriel LiDAR
│       └── ...
│
└── vignettes/
    └── tutorial-guide.Rmd      # Guide d'utilisation tutoriels
```

**Structure Decision**: Structure package R standard avec tutoriels dans `inst/tutorials/`. Chaque tutoriel est un document Rmd autonome utilisant le framework learnr.

## Complexity Tracking

> Aucune violation de la constitution détectée - section non applicable.

---

## Phase 0: Research Summary

### Recherches Requises

| Topic | Question | Priorité |
|-------|----------|----------|
| LiDAR Processing | Meilleur workflow lidR pour métriques par parcelle | Haute |
| Cache Strategy | Pattern optimal pour cache cross-platform | Haute |
| INPN WFS | Endpoints et paramètres pour zones protégées | Moyenne |
| gradethis | Patterns de validation pour exercices géospatiaux | Moyenne |

### Décisions Techniques Anticipées

1. **Cache**: Utiliser `rappdirs::user_data_dir()` avec fallback `~/nemeton_tutorial_data/`
2. **CRS**: Lambert-93 (EPSG:2154) comme référence, conversion WGS84 pour APIs
3. **Format**: GeoPackage pour multi-couches, GeoTIFF pour rasters
4. **LiDAR**: Workflow lidR::readLAS → normalize_height → pixel_metrics

---

## Phase 1: Design Artifacts

### Data Model

Voir [data-model.md](./data-model.md) pour le modèle complet.

Entités principales:
- **ZoneEtude**: Emprise géographique, placettes
- **Parcelle**: Unité d'analyse avec indicateurs
- **Indicateur**: Valeur, famille, méthode calcul
- **MetriquesLiDAR**: zmax, zmean, zsd, zq95, pzabove2, zentropy

### API Contracts

Voir [contracts/](./contracts/) pour les schémas.

Fonctions principales par tutoriel:
- T01: `st_read()`, `get_wfs()`, `load_classified_ta()`
- T02: `readLAS()`, `normalize_height()`, `pixel_metrics()`
- T03: `indicator_water_*()`, `indicator_risk_*()`, `indicator_social_*()`
- T04: `indicator_biodiversity_*()`, `indicator_landscape_*()`, `indicator_naturalness_*()`
- T05: `normalize_indicators()`, `create_family_index()`, `create_composite_index()`
- T06: `nemeton_radar()`, `identify_hotspots()`, `identify_pareto_optimal()`

### Quickstart

Voir [quickstart.md](./quickstart.md) pour le guide de démarrage rapide.

---

## Implementation Order

### Priorité 1: Finaliser Tutorial 01

1. Vérifier et corriger exercice 5.2 (LiDAR) ✅
2. Ajouter tests automatiques gradethis
3. Tester end-to-end le tutoriel complet

### Priorité 2: Tutorial 02 (LiDAR)

1. Créer structure fichier 02-lidar.Rmd
2. Implémenter sections 1-4 (chargement, normalisation, MNH)
3. Implémenter sections 5-7 (métriques, export, quiz)
4. Ajouter tests

### Priorité 3: Tutorials 03-04 (Terrain + Écologique)

1. Tutoriel 03: indicateurs terrain (W, R, S, P2)
2. Tutoriel 04: indicateurs écologiques (B, L, T, A, F, N)

### Priorité 4: Tutorials 05-06 (Complet + Analyse)

1. Tutoriel 05: assemblage et normalisation
2. Tutoriel 06: analyse multi-critères et export

---

## Risk Assessment

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| API IGN indisponible | Haut | Faible | Données démo pré-téléchargées |
| LiDAR trop volumineux | Moyen | Moyen | Sous-échantillonnage, zone réduite |
| Packages non installés | Moyen | Moyen | Vérification gracieuse + instructions |
| Timeout exercices | Faible | Moyen | exercise.timelimit=600 |

---

## Next Steps

1. Exécuter `/speckit.tasks` pour générer les tâches détaillées
2. Commencer par la finalisation du Tutorial 01
3. Développer les tutoriels séquentiellement (02 → 06)
