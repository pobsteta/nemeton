# Tutorial 08 : Coregistration LiDAR/Terrain

## Description

Ce tutoriel interactif enseigne le recalage (coregistration) des positions de placettes d'inventaire forestier sur les données LiDAR aéroporté.

**Source** : Adapté de l'article [lidaRtRee Coregistration](https://lidar.pages-forge.inrae.fr/lidaRtRee/articles/coregistration.html)

**Référence** : Monnet, J.-M., & Mermin, É. (2014). Cross-correlation of diameter measures for the co-registration of forest inventory plots with airborne laser scanning data. *Forests*, 5(9), 2307-2326.

## Durée estimée

**130 minutes (2h10)**

## Prérequis

- Tutorial 07 (LiDAR avancé) - lasR, lidaRtRee, parallélisation
- Connaissances de base en inventaire forestier

## Packages requis

```r
# Obligatoires
install.packages(c("lidR", "terra", "sf", "ggplot2"))
install.packages("lidaRtRee")

# Optimisation (recommandés)
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")
install.packages(c("future", "future.apply"))

# Tutoriel
install.packages(c("learnr", "gradethis"))
```

## Structure

| Section | Durée | Contenu |
|---------|-------|---------|
| 1 | 10 min | Introduction, contexte GPS sous forêt |
| 2 | 15 min | Chargement données (placettes, arbres, LiDAR) |
| 3 | 20 min | Génération MNH (lasR + lidR) |
| 4 | 15 min | Création masque placette |
| 5 | 20 min | Calcul corrélation |
| 6 | 25 min | Traitement parallèle par lot |
| 7 | 15 min | Analyse statistique des résultats |
| 8 | 10 min | Synthèse et bonnes pratiques |

## Données utilisées

Le tutoriel utilise les données incluses dans le package **lidaRtRee** :

- `chm_chablais3` : CHM (Modèle Numérique de Hauteur)
- `quatre_montagnes` : 96 placettes d'inventaire avec coordonnées
- `tree_inventory_chablais3` : 110 arbres avec positions et diamètres

## Lancer le tutoriel

```r
learnr::run_tutorial("08-coregistration", package = "nemeton")
```

## Produits générés

| Fichier | Description |
|---------|-------------|
| `coregistration_results.rds` | Cache résultats R |
| `placettes_coregistrees.csv` | Coordonnées corrigées |
| `placettes_coregistrees.gpkg` | GeoPackage pour SIG |

## Quiz

4 quiz avec 12 questions au total :

1. **Introduction** (3 questions) - Problématique GPS, principe corrélation
2. **Génération MNH** (3 questions) - Seuillage, lasR vs lidR, filtre médian
3. **Corrélation** (3 questions) - dx/dy, ratio, buffer
4. **Analyse** (3 questions) - Statistiques, p-value, export

## Lien avec Tutorial 07

Ce tutoriel complète le Tutorial 07 (LiDAR avancé) :

- **Tutorial 07** : Calibration ABA avec placettes
- **Tutorial 08** : Recalage des placettes avant calibration

Les placettes recalées produisent des modèles ABA plus précis.

## Ressources

- [lidaRtRee Coregistration](https://lidar.pages-forge.inrae.fr/lidaRtRee/articles/coregistration.html)
- [Monnet & Mermin (2014)](https://doi.org/10.3390/rs6087628)
- [lasR documentation](https://r-lidar.github.io/lasR/)
- [lidR book](https://r-lidar.github.io/lidRbook/)
