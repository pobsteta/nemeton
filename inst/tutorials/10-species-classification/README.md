# Tutorial 10 : Classification d'Essences au Niveau Couronne

## Description

Ce tutoriel enseigne la classification supervisée d'essences forestières au niveau de la couronne individuelle en fusionnant des données LiDAR HD et des orthophotos IRC (Infrarouge Couleur).

**Objectif** : Prédire l'essence de chaque arbre segmenté en combinant des features de structure 3D (LiDAR) et spectrales (IRC).

## Durée estimée

**210 minutes (3h30)**

## Prérequis

- Tutorial 01 (Acquisition) - zone d'étude et données IGN
- Tutorial 02 (LiDAR) - métriques LiDAR de base
- Tutorial 07 (LiDAR avancé) - segmentation des couronnes

## Packages requis

```r
# Spatial
install.packages(c("sf", "terra", "exactextractr"))

# Machine Learning
install.packages("ranger")       # Random Forest
install.packages("xgboost")      # Gradient Boosting
install.packages("blockCV")      # Validation spatiale

# Data manipulation
install.packages(c("dplyr", "tidyr", "purrr"))

# Visualisation
install.packages(c("ggplot2", "patchwork"))

# Tutoriel
install.packages(c("learnr", "gradethis"))

# Optionnel - IRC IGN
install.packages("happign")
```

## Structure

| Section | Durée | Contenu |
|---------|-------|---------|
| Bienvenue | 10 min | Objectifs, workflow, essences cibles |
| 1 | 15 min | Prérequis et environnement |
| 2 | 25 min | Chargement des données (couronnes, IRC, labels) |
| 3 | 30 min | Feature Engineering LiDAR |
| 4 | 25 min | Feature Engineering IRC |
| 5 | 20 min | Assemblage du Dataset |
| 6 | 25 min | Validation Spatiale (blockCV) |
| 7 | 35 min | Modélisation (Random Forest + XGBoost) |
| 8 | 20 min | Cartographie des résultats |
| Synthèse | 5 min | Récapitulatif et bonnes pratiques |

## Données utilisées

**Cache nemeton (Tutorials 01-07)** :
- `crowns_complet.gpkg` : Couronnes segmentées (T07)
- `tree_metrics_complet.gpkg` : Métriques LiDAR par arbre
- `zone_etude.gpkg` : Périmètre de la zone

**Données terrain (lidaRtRee)** :
- Inventaires avec essences (PIAB, ABAL, FASY, TABA)
- Positions GPS des arbres référencés

**IRC (téléchargé ou synthétique)** :
- Orthophoto IRC IGN (via happign) ou généré synthétiquement

## Lancer le tutoriel

```r
learnr::run_tutorial("10-species-classification", package = "nemeton")
```

## Produits générés

| Fichier | Description |
|---------|-------------|
| `features_lidar.rds` | Features LiDAR par couronne |
| `features_irc.rds` | Features spectrales par couronne |
| `training_dataset.rds` | Dataset complet avec labels |
| `model_rf.rds` | Modèle Random Forest entraîné |
| `model_xgb.rds` | Modèle XGBoost entraîné |
| `crowns_classified.gpkg` | Couronnes avec prédictions |
| `classification_report.html` | Rapport de performance |

## Quiz

8 quiz avec ~24 questions au total :

1. **Prérequis** (3 questions) - Packages, données, workflow
2. **Données** (3 questions) - Couronnes, IRC, labels
3. **Features LiDAR** (3 questions) - Hauteur, densité, forme
4. **Features IRC** (3 questions) - NDVI, ratios, textures
5. **Dataset** (3 questions) - Jointures, NA, outliers
6. **Validation** (3 questions) - blockCV, autocorrélation spatiale
7. **Modélisation** (3 questions) - RF vs XGBoost, tuning
8. **Synthèse** (3 questions) - Incertitude, production

## Features extraites

### Features LiDAR (20+)

| Catégorie | Features |
|-----------|----------|
| Hauteur | Hmax, Hmean, Hstd, Hcv, percentiles |
| Densité | Ratio returns, gap fraction |
| Forme | Surface, périmètre, compacité |
| Structure | Rugosité, stratification verticale |

### Features IRC (8+)

| Indice | Formule | Interprétation |
|--------|---------|----------------|
| NDVI | (NIR-R)/(NIR+R) | Vigueur végétation |
| GNDVI | (NIR-G)/(NIR+G) | Chlorophylle |
| RVI | NIR/R | Biomasse |
| NGRDI | (G-R)/(G+R) | Stress hydrique |

## Essences cibles

| Code | Nom français | Groupe |
|------|--------------|--------|
| PIAB | Épicéa | Résineux |
| ABAL | Sapin | Résineux |
| FASY | Hêtre | Feuillu |
| TABA | Frêne | Feuillu |

## Lien avec les autres tutoriels

- **Tutorial 07** : Fournit les couronnes segmentées
- **Tutorial 08** : Coregistration améliore la précision des labels
- **Tutorial 09** : Placettes échantillonnées pour labels terrain

## Ressources

- [ranger - Fast Random Forest](https://cran.r-project.org/package=ranger)
- [blockCV - Spatial CV](https://cran.r-project.org/package=blockCV)
- [exactextractr - Zonal statistics](https://cran.r-project.org/package=exactextractr)
- [Fassnacht et al. (2016) - Review tree species classification](https://doi.org/10.1016/j.rse.2016.08.013)
