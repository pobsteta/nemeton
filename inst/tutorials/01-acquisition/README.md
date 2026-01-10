# Tutorial 01 : Acquisition des Données Géographiques

## Description

Ce tutoriel enseigne l'acquisition des données géographiques nécessaires au calcul des **31 indicateurs nemeton** répartis sur les 12 familles.

**Aucun indicateur n'est calculé dans ce tutoriel** - il constitue le prérequis data pour tous les tutoriels suivants.

## Données Acquises

| Source | Données | Usage (Tutoriels) |
|--------|---------|-------------------|
| IGN Cadastre | Parcelles forestières | Base géométrique (T02-T06) |
| IGN RGE Alti | MNT 5m | W1-3, R1-3, F1 (T03) |
| IGN BD Forêt | Formations végétales | B3, L1-3, T1-2, A2, F2 (T04) |
| IGN BD TOPO | Routes, hydro, bâtiments | S1-3, W1, N2 (T03-T04) |
| IGN LiDAR HD | Nuages de points 3D | C1, P1, P3, B2, E1, A1 (T02) |

## Données de Sortie

```
~/nemeton_tutorial_data/    (ou rappdirs::user_data_dir("nemeton")/tutorial_data/)
├── zone_etude.gpkg         # Zone d'étude (layers: zone_etude, placettes)
├── parcelles.gpkg          # Parcelles cadastrales
├── mnt.tif                 # MNT RGE Alti 5m (terra SpatRaster)
├── bd_foret.gpkg           # BD Forêt V2 (formations végétales)
├── bd_topo.gpkg            # BD TOPO (routes, hydro, bâtiments)
└── lidar_hd/               # Dalles LiDAR HD (.copc.laz)
    └── *.copc.laz
```

## Prérequis

```r
# Packages requis
install.packages(c("sf", "terra", "ggplot2", "learnr", "gradethis", "rappdirs"))
install.packages("happign")
remotes::install_github("Jean-Roc/lidarHD")
```

## Lancement

```r
learnr::run_tutorial("01-acquisition", package = "nemeton")
```

## Sections

1. **Définir la zone d'étude** - Chargement données Quatre Montagnes, buffer 500m
2. **Téléchargement cadastre** - API happign WFS
3. **Téléchargement MNT** - RGE Alti 5m
4. **BD Forêt et BD TOPO** - WFS IGN
5. **Données LiDAR HD** - Package lidarHD, STAC API
6. **Synthèse** - Récapitulatif et quiz

## Pattern Cache

Chaque exercice utilise le pattern suivant :

```r
if (requireNamespace("rappdirs", quietly = TRUE)) {
  data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
} else {
  data_dir <- file.path(path.expand("~"), "nemeton_tutorial_data")
}
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
```

## Notes Techniques

- **CRS**: Lambert-93 (EPSG:2154) pour toutes données françaises
- **LiDAR bbox**: Requiert WGS84 (EPSG:4326) pour l'API STAC
- **Timeout LiDAR**: 600 secondes (10 minutes)

## Tutoriel Suivant

→ **Tutorial 02** : LiDAR — Familles C, P, E, A (9 indicateurs : C1, C2, P1, P2, P3, E1, E2, A1, A2)
