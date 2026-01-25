# Research & Technical Decisions: MVP nemeton v0.1.0

**Date**: 2026-01-04
**Branch**: 001-mvp-v0.1.0

## Overview

Ce document consolide les décisions techniques prises pour le MVP du package nemeton, les alternatives considérées, et les justifications basées sur la constitution et les best practices R.

---

## Decision 1: sf vs sp pour les vecteurs

**Decision**: Utiliser `sf` (Simple Features)

**Rationale**:
- `sf` est le standard moderne R spatial (depuis 2016)
- Meilleure intégration avec tidyverse (compatibilité dplyr, ggplot2)
- Performance supérieure (binding C++ GDAL/GEOS)
- `sp` est déprécié et non maintenu activement
- Constitution interdit explicitement `sp`

**Alternatives considered**:
- `sp`: Rejeté - legacy, performances inférieures, non compatible tidyverse
- Ré-implémentation custom: Rejeté - sur-ingénierie, principe "pas de réinvention"

**References**:
- https://r-spatial.github.io/sf/
- Pebesma, E. (2018). Simple Features for R. The R Journal.

---

## Decision 2: terra vs raster pour les rasters

**Decision**: Utiliser `terra`

**Rationale**:
- `raster` est déprécié (maintenu par même auteur qui recommande `terra`)
- `terra` est 10-50x plus rapide (backend C++)
- Meilleure gestion mémoire (chunking automatique)
- API plus cohérente et moderne
- Constitution interdit explicitement `raster`

**Alternatives considered**:
- `raster`: Rejeté - déprécié, performances inférieures
- `stars`: Considéré pour futur (datacubes multi-dimensionnels), mais plus complexe pour MVP

**References**:
- https://rspatial.org/terra/
- Hijmans, R. (2024). terra: Spatial Data Analysis.

---

## Decision 3: exactextractr vs terra::extract pour extraction zonale

**Decision**: Utiliser `exactextractr` comme moteur principal

**Rationale**:
- 10-100x plus rapide que `terra::extract` sur polygones complexes
- Calculs exacts (pondération par surface de pixel) vs approximations
- Essentiel pour performance avec grands territoires
- Standard pour analyse spatiale scientifique

**Alternatives considered**:
- `terra::extract`: Rejeté - trop lent pour larges territoires (mais utilisable en fallback)
- `velox`: Rejeté - abandonné, non compatible terra

**References**:
- https://github.com/isciences/exactextractr
- Baston, D. (2020). exactextractr: Fast extraction from raster datasets.

---

## Decision 4: Classes S3 vs S4 vs R6

**Decision**: Classes S3

**Rationale**:
- Simplicité (MVP principe VII)
- Compatibilité native avec tidyverse
- Suffisant pour besoins MVP (héritage simple de `sf`)
- Constitution impose S3 (S4/R6 seulement si justification forte)

**Alternatives considered**:
- S4: Rejeté - trop complexe pour MVP, validation formelle non nécessaire
- R6: Rejeté - orienté objet mutant (contre principe fonctionnel)

**References**:
- Advanced R (Wickham): "Use S3 unless you have compelling reason not to"

---

## Decision 5: Méthode de normalisation par défaut

**Decision**: Min-max (0-100) comme défaut, avec options z-score et quantiles

**Rationale**:
- Min-max intuitive pour utilisateurs non statisticiens (0 = pire, 100 = meilleur)
- Facile à communiquer auprès de décideurs
- Permet agrégation directe en indices
- z-score disponible pour utilisateurs avancés (outliers, distributions non normales)

**Alternatives considered**:
- z-score seul: Rejeté - moins intuitif pour public cible (forestiers, gestionnaires)
- Ranking: Rejeté - perd information quantitative

**References**:
- Nardo et al. (2008). Handbook on Constructing Composite Indicators (OECD/JRC)

---

## Decision 6: Gestion de la polarité des indicateurs

**Decision**: Paramètre `polarity` dans `nemeton_index()` permettant de spécifier direction souhaitée (+1 ou -1 par indicateur)

**Rationale**:
- Certains indicateurs sont "mieux si haut" (biodiversité, carbone)
- D'autres "mieux si bas" (fragmentation, risques)
- Nécessaire pour agrégation cohérente en indice composite
- Transparence: utilisateur spécifie explicitement

**Alternatives considered**:
- Polarité hardcodée: Rejeté - pas transparent, pas flexible
- Inversion manuelle par utilisateur: Rejeté - source d'erreurs

**References**:
- Freudenberg, M. (2003). Composite indicators of country performance (OECD).

---

## Decision 7: Structure des indicateurs (functions vs registry)

**Decision**: MVP = fonctions simples (`indicator_carbon()`, etc.). Registry (`register_indicator()`) reporté à v0.3.0

**Rationale**:
- Principe VII (Simplicité/YAGNI): registry non nécessaire pour 5 indicateurs
- Fonctions simples plus faciles à tester et documenter
- Registry utile quand > 10 indicateurs ou contributions externes

**Alternatives considered**:
- Registry dès MVP: Rejeté - sur-ingénierie, complexité prématurée
- Factory pattern: Rejeté - même raison

**References**:
- Martin, R. (2008). Clean Code: "Make it work, make it right, make it fast"

---

## Decision 8: Calcul parallèle pour MVP

**Decision**: Pas de parallélisation dans MVP. Feature v0.4.0+

**Rationale**:
- MVP cible: 100 unités, 5 indicateurs = < 2 min sur laptop (acceptable)
- Parallélisation ajoute complexité (gestion backend, dépendances OS)
- Principe VII (Simplicité): optimiser seulement si bottleneck prouvé
- `future` backend facile à ajouter plus tard sans breaking change

**Alternatives considered**:
- `parallel::mclapply`: Rejeté - non portable Windows
- `future`: Reporté à v0.4.0 après profiling

**References**:
- Bengtsson, H. (2021). A Unifying Framework for Parallel and Distributed Processing in R using Futures.

---

## Decision 9: Format de données d'exemple

**Decision**: GeoPackage (.gpkg) pour vecteurs, GeoTIFF (.tif) pour rasters

**Rationale**:
- GeoPackage: standard OGC, mono-fichier, supporte métadonnées, meilleur que shapefile
- GeoTIFF: standard universel, compression, métadonnées intégrées
- Interopérabilité maximale (QGIS, ArcGIS, Python, Julia, etc.)

**Alternatives considered**:
- Shapefile: Rejeté - multi-fichiers, limitations (noms colonnes, taille)
- RDS: Rejeté - format propriétaire R, pas d'interopérabilité

**References**:
- OGC GeoPackage Encoding Standard (2014)

---

## Decision 10: Diagrammes radar (ggradar vs custom)

**Decision**: Implémentation custom basée sur coord_polar() de ggplot2

**Rationale**:
- `ggradar` peu maintenu, dépendances obsolètes
- Contrôle total sur apparence et paramètres
- < 50 lignes de code (transformation coordonnées + coord_polar)
- Cohérence visuelle avec reste du package

**Alternatives considered**:
- `ggradar`: Rejeté - maintenance, limitations customisation
- `fmsb::radarchart`: Rejeté - base graphics (pas ggplot2, pas pipe-friendly)

**References**:
- https://www.r-graph-gallery.com/radar-chart.html

---

## Decision 11: Messages utilisateur (print vs cli)

**Decision**: Package `cli` pour tous les messages, warnings, erreurs

**Rationale**:
- Messages formatés, couleurs, unicode (meilleure UX)
- Standard tidyverse/rstudio
- Fonctions: `cli_alert_*`, `cli_warn`, `cli_abort`
- Constitution l'impose

**Alternatives considered**:
- `message()`/`warning()`/`stop()`: Rejeté - pas de formatage, moins informatif

**References**:
- https://cli.r-lib.org/

---

## Decision 12: Vignettes: Rmarkdown vs Quarto

**Decision**: Rmarkdown pour MVP, Quarto considéré pour v1.0

**Rationale**:
- Rmarkdown standard R packages depuis > 10 ans
- Meilleure compatibilité CRAN
- Quarto excellent mais plus récent, dépendances externes
- Migration facile Rmd → Quarto plus tard

**Alternatives considered**:
- Quarto: Reporté - excellente technologie mais pas nécessaire MVP

**References**:
- Xie, Y. et al. (2018). R Markdown: The Definitive Guide.

---

## Decision 13: Calcul carbone - méthode par défaut

**Decision**: Biomasse aérienne (AGB) via régression allométrique simple pour MVP

**Rationale**:
- Méthode standard et documentée (IPCC, IGN)
- Données NDVI / hauteur facilement accessibles (Sentinel, LiDAR)
- Carbone sol reporté à v0.2 (besoin données pédologiques rares)

**Alternatives considered**:
- Carbone total (aérien + sol + litière): Rejeté pour MVP - complexité, données
- Modèles processuels: Rejeté - hors scope package statistique

**References**:
- IPCC (2006). Guidelines for National Greenhouse Gas Inventories, Volume 4.
- Chave et al. (2014). Improved allometric models to estimate AGB. Global Change Biology.

---

## Decision 14: Biodiversité - indices à implémenter

**Decision**: Shannon, Simpson, et Richesse spécifique pour MVP

**Rationale**:
- Indices standard en écologie (faciles à interpréter)
- Calculables depuis couches de présence/abondance
- Shannon capte diversité + équitabilité
- Simpson moins sensible aux espèces rares
- Richesse = compte simple (baseline)

**Alternatives considered**:
- Phylogenetic diversity: Reporté - besoin données phylogénétiques
- Beta diversity: Reporté - nécessite comparaisons inter-unités

**References**:
- Magurran, A.E. (2004). Measuring Biological Diversity.

---

## Decision 15: Tests - framework testthat vs autres

**Decision**: `testthat` >= 3.0 (édition 3)

**Rationale**:
- Standard de facto packages R (> 90% packages CRAN)
- Intégration native devtools/RStudio
- Edition 3: `test_that()` moderne, `snapshot testing`
- Constitution n'impose pas mais fortement conseillé

**Alternatives considered**:
- `RUnit`: Rejeté - legacy, moins d'intégration
- `tinytest`: Considéré, mais testthat plus standard

**References**:
- Wickham, H. (2011). testthat: Get Started with Testing. The R Journal.

---

## Outstanding Questions

**Q1**: Quelle licence open source choisir ?
**A**: MIT ou GPL-3 - à décider avec stakeholders. MIT plus permissive, GPL-3 garantit ouverture dérivés.

**Q2**: Où héberger la documentation (pkgdown) ?
**A**: GitHub Pages (standard, gratuit, intégration CI/CD facile).

**Q3**: Stratégie CI/CD ?
**A**: GitHub Actions avec workflow R-CMD-check standard (check sur Linux/Mac/Windows).

---

## Summary of Key Technologies

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| Vecteurs | sf | >= 1.0-0 | Standard moderne, tidyverse compatible |
| Rasters | terra | >= 1.7-0 | Performance, gestion mémoire |
| Extraction zonale | exactextractr | >= 0.9.0 | Vitesse, précision |
| Data manipulation | dplyr | >= 1.1.0 | Tidyverse, expressivité |
| Visualisation | ggplot2 | >= 3.4.0 | Standard, customisable |
| Messages | cli | >= 3.6.0 | UX, formatage |
| Tests | testthat | >= 3.0.0 | Standard, intégration devtools |
| Classes | S3 | - | Simplicité, tidyverse |
| Normalisation | Min-max (0-100) | - | Intuitivité utilisateurs |
| Documentation | roxygen2 + Rmarkdown | - | Standard R packages |

---

**Phase 0 Complete** ✅ - Toutes les décisions techniques majeures sont documentées et justifiées. Prêt pour Phase 1 (Data Model & Contracts).
