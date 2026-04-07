# nemeton <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/pobsteta/nemeton/actions/workflows/r.yml/badge.svg)](https://github.com/pobsteta/nemeton/actions/workflows/r.yml)
[![Version](https://img.shields.io/badge/version-0.15.0-blue.svg?logo=github)](https://github.com/pobsteta/nemeton)
[![pkgdown](https://github.com/pobsteta/nemeton/actions/workflows/pkgdown.yaml/badge.svg)](https://pobsteta.github.io/nemeton/)
[![codecov](https://codecov.io/gh/pobsteta/nemeton/graph/badge.svg)](https://codecov.io/gh/pobsteta/nemeton)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?logo=opensourceinitiative)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

> **Analyse systemique de territoires forestiers selon la methode Nemeton**

`nemeton` est le package R coeur pour l'analyse integree d'ecosystemes forestiers. Il calcule, normalise et visualise des **indicateurs biophysiques multi-famille** pour la gestion forestiere durable.

## Architecture (ADR-009)

```
nemeton (ce repo)       -> Package coeur R (MIT). 31 indicateurs, 12 familles, NDP, radar.
nemetonShiny            -> Application Shiny (EUPL v1.2). Interface web interactive.
tree_sat_nemeton        -> Classification d'essences Sentinel-1/2. NDP 0. MIT.
maestro_nemeton         -> Classification MAESTRO ViT (ortho+MNT). NDP 1+. MIT.
```

## Fonctionnalites

**12 familles d'indicateurs** avec 31 sous-indicateurs (convention NMT) :

| Code | Famille | Indicateurs |
|------|---------|-------------|
| **B** | Biodiversite | indicateur_b1_protection, b2_structure, b3_connectivite |
| **C** | Carbone & Vitalite | indicateur_c1_biomasse, c2_ndvi |
| **W** | Eau & Regulation | indicateur_w1_reseau, w2_zones_humides, w3_humidite |
| **A** | Air & Microclimat | indicateur_a1_couverture, a2_qualite_air |
| **F** | Fertilite Sols | indicateur_f1_fertilite, f2_erosion |
| **L** | Paysage | indicateur_l1_sylvosphere, l2_fragmentation |
| **T** | Temporel | indicateur_t1_anciennete, t2_changement |
| **R** | Risques & Resilience | indicateur_r1_feu, r2_tempete, r3_secheresse, r4_abroutissement |
| **S** | Social & Usages | indicateur_s1_routes, s2_bati, s3_population |
| **P** | Production & Economie | indicateur_p1_volume, p2_station, p3_qualite_bois |
| **E** | Energie & Climat | indicateur_e1_bois_energie, e2_evitement |
| **N** | Naturalite | indicateur_n1_distance, n2_continuite, n3_naturalite |

**Systeme NDP** (Niveau De Precision) : ponderation Fibonacci (1,1,2,3,5), confiance phi.

**11 essences forestieres** par region biogeographique (BFC, EU).

**Outils d'analyse** : Pareto, clustering, trade-offs, radar 12-axes, correlations.

## Installation

```r
# install.packages("remotes")
remotes::install_github("pobsteta/nemeton")
```

**Prerequis** : R >= 4.1.0, `sf`, `terra`, `ggplot2`

## Quick Start

```r
library(nemeton)

# Charger le dataset de demonstration (20 parcelles, 12 familles)
data(massif_demo_units)

# Visualiser le profil radar d'une parcelle
nemeton_radar(massif_demo_units, unit_id = 1, mode = "family")

# Systeme NDP
ndp_table()                        # 5 niveaux de precision
get_ndp_confidence(1)              # 16.7% pour NDP 1 (Observation)

# Configuration des essences
list_species_classes("BFC")        # 11 classes pour la BFC
map_bdforet_essence("Hetre")       # "essence_hetraie"

# Sources de donnees par pays
get_data_source("dem", "FR")       # config MNT IGN
list_countries()                   # c("EU", "FR")
```

## Application Interactive (nemetonShiny)

L'application Shiny est dans un package separe :

```r
# Installer l'application
remotes::install_github("pobsteta/nemeton_shiny")

# Lancer
nemetonShiny::run_app(language = "fr")
```

L'application permet de :

- Rechercher et selectionner des parcelles cadastrales par commune
- Calculer automatiquement les 31 indicateurs (12 familles)
- Visualiser les resultats (radar avec NDP, cartes, tableaux)
- Generer des perspectives IA par profil d'acteur (18 profils)
- Exporter en PDF ou GeoPackage
- Synchroniser avec PostGIS (Clever Cloud)
- S'authentifier via OAuth2/OIDC (Keycloak, AgentConnect)

Repository : [pobsteta/nemeton_shiny](https://github.com/pobsteta/nemeton_shiny)

## Workflow avec vos donnees

```r
library(nemeton)
library(sf)

# 1. Creer les unites d'analyse
units <- nemeton_units("parcelles.gpkg")

# 2. Cataloguer les couches spatiales
layers <- nemeton_layers(
  rasters = list(biomass = "biomass.tif", dem = "dem.tif"),
  vectors = list(roads = "roads.gpkg", water = "water.gpkg")
)

# 3. Calculer les indicateurs
results <- nemeton_compute(units, layers, indicators = "all")

# 4. Normaliser (echelle 0-100)
normalized <- normalize_indicators(results, method = "minmax")

# 5. Creer les indices par famille
families <- create_family_index(normalized, method = "mean")

# 6. Visualiser le radar
nemeton_radar(families, mode = "family")
```

## Documentation

Site pkgdown : [pobsteta.github.io/nemeton](https://pobsteta.github.io/nemeton/)

```r
?nemeton_compute
?create_family_index
?ndp_table
?get_species_config
```

## Licence

MIT - Voir [LICENSE](LICENSE)

L'application Shiny ([nemetonShiny](https://github.com/pobsteta/nemeton_shiny)) est sous EUPL v1.2.

## Citation

```
Obstetar, P. (2026). nemeton: Systemic Forest Analysis Using the Nemeton Method.
R package version 0.15.0. https://github.com/pobsteta/nemeton
```

---

**Developpe avec** [Claude Code](https://claude.com/claude-code)
