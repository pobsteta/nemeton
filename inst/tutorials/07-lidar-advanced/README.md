# Tutorial 07 : LiDAR Avancé — LAScatalog, lasR et BABA

## Description

Ce tutoriel avancé enseigne le traitement de gros jeux de données LiDAR avec des outils professionnels : LAScatalog pour le traitement multi-tuiles, pipelines lasR haute performance, segmentation d'arbres individuels avec lidaRtRee, et approche BABA (Buffered Area-Based) pour cartographie haute résolution.

**Source** : Basé sur les workflows de production de l'ONF et de l'INRAE

## Durée estimée

**90-120 minutes (1h30 à 2h)**

## Prérequis

- Tutorial 01 (Acquisition) - données LiDAR HD IGN
- Tutorial 02 (LiDAR de base) - concepts fondamentaux lidR
- 8 GB RAM minimum (traitement multi-tuiles)

## Packages requis

```r
# Core LiDAR
install.packages("lidR")
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")
install.packages("lidaRtRee")

# Spatial
install.packages(c("sf", "terra"))

# Parallélisation
install.packages(c("future", "future.apply"))

# Tutoriel
install.packages(c("learnr", "gradethis"))
```

## Structure

| Section | Durée | Contenu |
|---------|-------|---------|
| Bienvenue | 5 min | Objectifs, comparaison avec T02 |
| 1 | 15 min | LAScatalog - traitement multi-tuiles |
| 2 | 15 min | Pipelines lasR haute performance |
| 3 | 15 min | Segmentation d'arbres individuels (ITD) |
| 4 | 10 min | Détection trouées et lisières |
| 5 | 10 min | Métriques de structure forestière |
| 6 | 15 min | Approche ABA - préparation données |
| 7 | 15 min | ABA - calibration modèles |
| 8 | 10 min | ABA - cartographie wall-to-wall |
| 9 | 10 min | Approche BABA exploratoire |
| 10 | 5 min | Quiz final |
| Synthèse | 5 min | Récapitulatif et bonnes pratiques |

## Données utilisées

Le tutoriel combine deux sources de données :

**Tutorial 01 (cache nemeton)** :
- 18 dalles LiDAR HD IGN (42 km², ~10 pts/m²)
- Zone d'étude du massif des Quatre Montagnes (Vercors)

**Package lidaRtRee** :
- 96 placettes terrain de 15m de rayon (projet Newfor)
- 28 placettes couvertes par le LiDAR du T01

## Lancer le tutoriel

```r
learnr::run_tutorial("07-lidar-advanced", package = "nemeton")
```

## Produits générés

| Fichier | Description |
|---------|-------------|
| `chm_complet.tif` | CHM haute résolution (1m) |
| `crowns_complet.gpkg` | Couronnes segmentées |
| `tree_metrics_complet.gpkg` | Métriques par arbre |
| `gaps_complet.gpkg` | Trouées forestières |
| `aba_model.rds` | Modèle ABA calibré |
| `baba_predictions.tif` | Cartographie BABA 10m |

## Quiz

Quiz intégrés dans chaque section avec ~20 questions au total couvrant :

1. **LAScatalog** - Chunking, options, retile
2. **lasR** - Pipelines, stages, performance
3. **Segmentation** - ITD, watershed, paramètres
4. **Structure** - Métriques, trouées, lisières
5. **ABA/BABA** - Calibration, validation, résolution

## Comparaison avec Tutorial 02

| Aspect | Tutorial 02 | Tutorial 07 |
|--------|-------------|-------------|
| Package principal | lidR | lidR + lasR + lidaRtRee |
| Traitement | Fichier unique | LAScatalog (multi-tuiles) |
| Performance | Standard | Haute performance |
| Résolution sortie | 20-30m | 10m (BABA) |
| Segmentation | Non | Arbres individuels |
| Calibration | Non | Oui (ABA/BABA) |

## Lien avec les autres tutoriels

- **Tutorial 01** : Fournit les données LiDAR HD
- **Tutorial 08** : Utilise les couronnes pour coregistration
- **Tutorial 10** : Utilise les couronnes pour classification d'essences

## Ressources

- [lidR book](https://r-lidar.github.io/lidRbook/)
- [lasR documentation](https://r-lidar.github.io/lasR/)
- [lidaRtRee vignettes](https://lidar.pages-forge.inrae.fr/lidaRtRee/)
- [Méthode ABA - Monnet (2011)](https://hal.inrae.fr/hal-02596706)
