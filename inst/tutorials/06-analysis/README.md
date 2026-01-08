# Tutorial 06 : Analyse Multi-Critères — 12 Familles + Export

## Description

Ce tutoriel final **visualise, analyse et exporte** les résultats des 32 indicateurs et de l'indice composite I_nemeton.

**Aucun nouvel indicateur n'est calculé** — ce tutoriel exploite les données produites par T01-T05.

## Analyses Disponibles

| Analyse | Outil | Description |
|---------|-------|-------------|
| Cartes thématiques | ggplot2 + sf | Cartes par famille et indice composite |
| Profils radar | fmsb | Diagramme radar 12 axes |
| Corrélations | corrplot | Matrice synergies/compromis |
| Hotspots | quantile | Parcelles top 10% I_nemeton |
| Front de Pareto | ggplot2 | Trade-offs multi-objectifs |
| Clustering | hclust | Regroupement par profil similaire |
| Carte interactive | leaflet | Export HTML interactif |

## Prérequis

- Tutorials 01-05 complétés (indicateurs_complets.gpkg)
- Packages de base: sf, terra, ggplot2
- Packages visualisation: fmsb, corrplot, patchwork, leaflet

```r
install.packages(c("fmsb", "corrplot", "patchwork", "leaflet"))
```

### Fichiers requis du Tutorial 05

```
~/nemeton_tutorial_data/
└── indicateurs_complets.gpkg
    ├── 32 indicateurs normalisés (*_norm)
    ├── 12 moyennes par famille (moy_C, moy_B, ...)
    └── Indice composite (I_nemeton)
```

## Sections

| Section | Contenu | Outils |
|---------|---------|--------|
| 1 | Cartes thématiques | ggplot2, sf |
| 2 | Profils radar | fmsb |
| 3 | Matrice corrélation | corrplot |
| 4 | Hotspots | quantile, ggplot2 |
| 5 | Trade-offs Pareto | ggplot2 |
| 6 | Clustering | hclust, cutree |
| 7 | Export GeoPackage/CSV | sf, write.csv |
| 8 | Carte interactive | leaflet |
| 9 | Quiz final | - |

## Visualisations Produites

### Cartes Thématiques
- Cartes par famille d'indicateurs (12 cartes)
- Panneau multi-cartes (facet_wrap)
- Carte de l'indice composite I_nemeton

### Profils Radar
- Diagramme radar 12 axes (une famille par axe)
- Comparaison multi-parcelles
- Identification des forces/faiblesses

### Corrélations
- Matrice de corrélation entre familles
- Identification synergies (r > 0.5)
- Identification compromis (r < -0.5)

### Hotspots
- Identification parcelles top 10%
- Cartographie des zones prioritaires
- Statistiques par hotspot

### Front de Pareto
- Visualisation trade-offs 2D (ex: Production vs Biodiversité)
- Identification solutions optimales
- Analyse multi-objectif

### Clustering
- Regroupement par profil similaire
- Dendrogramme hiérarchique
- Cartographie des clusters

## Données de Sortie

```
~/nemeton_tutorial_data/
├── analyse_finale.gpkg     # Données enrichies (clusters, hotspots)
├── indicateurs_nemeton.csv # Attributs tabulaires pour tableur
└── carte_interactive.html  # Carte Leaflet (optionnel)
```

## Lancement

```r
learnr::run_tutorial("06-analysis", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `identify_hotspots()` — Identification des parcelles prioritaires
- `compute_family_correlations()` — Matrice de corrélation
- `cluster_parcels()` — Clustering des profils
- `nemeton_radar()` — Diagramme radar

## Fin de la Série

Ce tutoriel conclut la série des **6 tutoriels nemeton** :

| Tutorial | Titre | Indicateurs |
|----------|-------|-------------|
| 01 | Acquisition des Données | Données sources |
| 02 | LiDAR — Familles C, P, B, E, A | 6 indicateurs |
| 03 | Terrain — Familles W, R, S, P, F | 12 indicateurs |
| 04 | Écologie — Familles B, L, C, T, A, F, N | 14 indicateurs |
| 05 | Assemblage — Famille E (E2) | 1 indicateur + I_nemeton |
| 06 | Analyse Multi-Critères | Visualisation + Export |

**Total : 32 indicateurs couvrant les 12 familles nemeton**
