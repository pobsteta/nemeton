# Guide des Tutoriels Interactifs nemeton

## Introduction

Le package **nemeton** propose une série de 7 tutoriels interactifs
basés sur [learnr](https://rstudio.github.io/learnr/) pour apprendre à
calculer les 32 indicateurs forestiers des 12 familles nemeton.

## Prérequis

### Installation des packages

``` r
# Packages de base
install.packages(c("sf", "terra", "ggplot2", "dplyr"))

# Packages tutoriels
install.packages(c("learnr", "gradethis", "rappdirs"))

# Packages acquisition IGN
install.packages("happign")

# Packages LiDAR (Tutorial 02)
install.packages("lidR")

# Packages LiDAR avancé (Tutorial 07)
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")
install.packages("lidaRtRee")
install.packages(c("future", "future.apply"))

# Packages visualisation (Tutorial 06)
install.packages(c("leaflet", "corrplot", "patchwork", "fmsb"))

# Package nemeton
remotes::install_github("pobsteta/nemeton")
```

## Les 8 Tutoriels

### Vue d’ensemble

| \#  | Tutoriel            | Durée   | Indicateurs                            | Description                                        |
|-----|---------------------|---------|----------------------------------------|----------------------------------------------------|
| 1   | `01-acquisition`    | 45 min  | \-                                     | Acquisition des données géographiques (IGN, LiDAR) |
| 2   | `02-lidar`          | 60 min  | C1, P1, P3, A1, E1, E2                 | Traitement LiDAR et métriques forestières          |
| 3   | `03-terrain`        | 40 min  | W1-W3, R1-R4, S1-S3, P2, F1            | Indicateurs terrain (12)                           |
| 4   | `04-ecological`     | 40 min  | B1-B3, L1-L3, C2, T1-T2, A2, F2, N1-N3 | Indicateurs écologiques (14)                       |
| 5   | `05-complete`       | 40 min  | \-                                     | Assemblage, normalisation, I_nemeton               |
| 6   | `06-analysis`       | 50 min  | \-                                     | Analyse multi-critères et export                   |
| 7   | `07-lidar-advanced` | 90 min  | \-                                     | LiDAR avancé (LAScatalog, lasR, lidaRtRee, ABA)    |
| 8   | `08-coregistration` | 130 min | \-                                     | Recalage placettes terrain/LiDAR                   |

**Durée totale estimée** : 8-9 heures

### Lancer un tutoriel

``` r
# Lister les tutoriels disponibles
learnr::available_tutorials("nemeton")

# Lancer un tutoriel spécifique
learnr::run_tutorial("01-acquisition", package = "nemeton")
```

## Détail des Tutoriels

### Tutorial 01 : Acquisition des Données

**Objectif** : Télécharger et préparer les données nécessaires pour les
tutoriels suivants.

**Données acquises** : - Zone d’étude (emprise géographique) - Parcelles
cadastrales (GeoPackage) - MNT (Modèle Numérique de Terrain) - Dalles
LiDAR HD - BD TOPO (routes, bâtiments, cours d’eau) - BD Forêt V2

**Sortie** : `~/nemeton_tutorial_data/` contenant toutes les données
brutes.

### Tutorial 02 : Traitement LiDAR

**Objectif** : Extraire des métriques forestières à partir des nuages de
points LiDAR.

**Indicateurs calculés** (6) : - **C1** : Stock de biomasse aérienne -
**P1** : Volume de bois sur pied - **P3** : Proportion bois d’oeuvre -
**A1** : Couverture forestière - **E1** : Potentiel bois-énergie -
**E2** : Évitement d’émissions carbone

**Sortie** : `indicateurs_lidar.gpkg`

### Tutorial 03 : Indicateurs Terrain

**Objectif** : Calculer les indicateurs dérivés du MNT et de la BD TOPO.

**Indicateurs calculés** (12) : - **W1-W3** : Famille Eau (TWI, réseau
hydro, zones humides) - **R1-R4** : Famille Résilience (risques feu,
tempête, sécheresse, gibier) - **S1-S3** : Famille Santé (sentiers,
accessibilité, proximité) - **P2** : Productivité forestière - **F1** :
Fertilité du sol

**Sortie** : `indicateurs_terrain.gpkg`

### Tutorial 04 : Indicateurs Écologiques

**Objectif** : Calculer les indicateurs de biodiversité, paysage et
naturalité.

**Indicateurs calculés** (14) : - **B1-B3** : Famille Biodiversité
(protection, structure, connectivité) - **L1-L3** : Famille Paysage
(lisière, fragmentation, TVB) - **C2** : Vitalité NDVI - **T1-T2** :
Famille Trame (ancienneté, changement) - **A2** : Qualité de l’air -
**F2** : Risque d’érosion - **N1-N3** : Famille Naturalité (distance,
continuité, composite)

**Sortie** : `indicateurs_ecologiques.gpkg`

### Tutorial 05 : Calcul Complet

**Objectif** : Assembler tous les indicateurs, normaliser et créer
l’indice composite.

**Étapes** : 1. Jointure des 32 indicateurs 2. Normalisation Min-Max
\[0-1\] 3. Inversion des indicateurs négatifs 4. Calcul des scores par
famille (12 familles) 5. Calcul de l’indice composite I_nemeton

**Sortie** : `parcelles.gpkg` avec 32 indicateurs + 12 scores famille +
I_nemeton

### Tutorial 06 : Analyse Multi-Critères

**Objectif** : Visualiser, analyser et exporter les résultats.

**Analyses** : - Cartes thématiques par famille - Diagrammes radar
(profils parcelles) - Matrice de corrélation (synergies/compromis) -
Identification des hotspots - Front de Pareto - Clustering des
parcelles - Export GeoPackage, CSV, carte Leaflet

**Sortie** : Fichiers d’analyse et carte interactive

### Tutorial 07 : LiDAR Avancé

**Objectif** : Maîtriser le traitement LiDAR avancé avec LAScatalog,
lasR et lidaRtRee.

**Méthodes** : - **LAScatalog** : Gestion de gros volumes LiDAR
multi-tuiles - **lasR** : Pipelines C++ ultra-performants
(normalisation, DTM, CHM) - **Segmentation ITD** : Détection et
segmentation d’arbres individuels - **Trouées et lisières** : Analyse de
la structure forestière - **ABA** : Calibration et prédiction
wall-to-wall avec placettes terrain - **BABA** : Exploration rapide sans
calibration

**Produits** : - `result_itd/` : Segmentation arbres (CHM, crowns,
seeds, arbres.gpkg) - `rasters_aba/` : Métriques points, arbres, terrain
(VRT) - `prediction_G_m2_ha.tif` : Carte surface terrière avec masque
OSO - `result_baba/` : Métriques LiDAR brutes (exploration)

**Note** : Ce tutoriel est complémentaire au Tutorial 02. Il utilise les
données LiDAR téléchargées dans le Tutorial 01.

### Tutorial 08 : Coregistration LiDAR/Terrain

**Objectif** : Recaler les positions des placettes d’inventaire
forestier sur les données LiDAR.

**Problématique** : Le GPS sous couvert forestier a une précision de
2-10 m, ce qui biaise la calibration ABA.

**Méthode** : - Corrélation croisée entre MNH LiDAR et positions des
arbres mesurés - Recherche de la translation (dx, dy) qui maximise la
corrélation - Référence : Monnet & Mermin (2014)

**Workflow** : 1. Génération MNH (CHM) avec lasR ou lidR 2. Création
masque placette (positions arbres pondérées par diamètre) 3. Calcul
corrélation avec `coregistration()` de lidaRtRee 4. Traitement parallèle
avec `future_lapply()` 5. Analyse statistique et export

**Produits** : - `placettes_coregistrees.csv` : Coordonnées corrigées -
`placettes_coregistrees.gpkg` : GeoPackage pour SIG

**Note** : Ce tutoriel utilise les données incluses dans le package
nemeton (`inst/extdata/coregistration/`) : 10 placettes d’inventaire
avec arbres et nuages LiDAR.

## Structure du Cache

Les données sont stockées dans un répertoire persistant :

``` r
# Localisation du cache
rappdirs::user_data_dir("nemeton")
```

- **Linux** : `~/.local/share/nemeton/tutorial_data/`
- **macOS** : `~/Library/Application Support/nemeton/tutorial_data/`
- **Windows** : `%LOCALAPPDATA%/nemeton/nemeton/tutorial_data/`

### Nettoyer le cache

``` r
cache_dir <- rappdirs::user_data_dir("nemeton")
unlink(file.path(cache_dir, "tutorial_data"), recursive = TRUE)
```

## Les 12 Familles d’Indicateurs

| Code | Famille      | Indicateurs                                          |
|------|--------------|------------------------------------------------------|
| C    | Carbone      | C1 (biomasse), C2 (NDVI)                             |
| B    | Biodiversité | B1 (protection), B2 (structure), B3 (connectivité)   |
| W    | Water (Eau)  | W1 (TWI), W2 (réseau hydro), W3 (zones humides)      |
| A    | Air          | A1 (couverture), A2 (qualité)                        |
| F    | Fertilité    | F1 (sol), F2 (érosion)                               |
| L    | Landscape    | L1 (lisière), L2 (fragmentation), L3 (TVB)           |
| T    | Trame        | T1 (ancienneté), T2 (changement)                     |
| R    | Résilience   | R1 (feu), R2 (tempête), R3 (sécheresse), R4 (gibier) |
| S    | Santé        | S1 (sentiers), S2 (accessibilité), S3 (proximité)    |
| P    | Production   | P1 (volume), P2 (productivité), P3 (qualité)         |
| E    | Énergie      | E1 (bois-énergie), E2 (évitement)                    |
| N    | Naturalité   | N1 (distance), N2 (continuité), N3 (composite)       |

## Dépannage

### “Tutorial not found”

``` r
# Vérifier l'installation
packageVersion("nemeton")

# Réinstaller
remotes::install_github("pobsteta/nemeton", force = TRUE)
```

### “Cannot download data”

Les APIs IGN peuvent être temporairement indisponibles. Le tutoriel
utilisera les données de démonstration si disponibles.

### “Out of memory” (LiDAR)

``` r
# Augmenter la mémoire
options(future.globals.maxSize = +Inf)
```

### “Exercise timeout”

Les exercices LiDAR ont un timeout de 10 minutes. Relancez l’exercice si
nécessaire (les données sont en cache).

## Ressources

- [Documentation nemeton](https://pobsteta.github.io/nemeton/)
- [GitHub nemeton](https://github.com/pobsteta/nemeton)
- [Référentiel des 12
  familles](https://pobsteta.github.io/nemeton/articles/complete-referential_fr.html)
- [learnr documentation](https://rstudio.github.io/learnr/)
- [lidR documentation](https://r-lidar.github.io/lidRbook/)
- [lasR documentation](https://r-lidar.github.io/lasR/)
- [lidaRtRee
  documentation](https://lidar.pages-forge.inrae.fr/lidaRtRee/)
