# Tutorial 04 : Écologie — Familles B, L, C, T, A, F, N (14 indicateurs)

## Description

Ce tutoriel calcule **14 indicateurs** écologiques appartenant à **7 familles** nemeton, en utilisant la BD Forêt, l'INPN et des données Sentinel-2.

## Indicateurs Calculés

| Famille | Code | Indicateur | Source | Description |
|---------|------|------------|--------|-------------|
| **B** (Biodiversité) | B1 | Zones protégées | INPN WFS | Overlap ZNIEFF, Natura 2000 |
| **B** (Biodiversité) | B2 | Diversité structurale | LiDAR (T02) | Hétérogénéité verticale |
| **B** (Biodiversité) | B3 | Connectivité écologique | BD Forêt | Continuité massifs |
| **L** (Paysage) | L1 | Fragmentation | BD Forêt | Indice de morcellement |
| **L** (Paysage) | L2 | Effet lisière | BD Forêt | Périmètre/Surface |
| **L** (Paysage) | L3 | Trame Verte et Bleue | WFS TVB | Corridors écologiques |
| **C** (Carbone) | C2 | NDVI (vitalité) | Sentinel-2 / BD Forêt | Indice de végétation |
| **T** (Temporel) | T1 | Âge peuplement | BD Forêt | Classe d'âge estimée |
| **T** (Temporel) | T2 | Ancienneté forestière | Cartes historiques | Forêt ancienne (>150 ans) |
| **A** (Air) | A2 | Stockage carbone sol | Type essence | CO₂ séquestré sol |
| **F** (Sol) | F2 | Qualité sol forestier | Pédologie + essence | Fertilité écologique |
| **N** (Naturalité) | N1 | Degré naturalité | Multi-sources | Indice synthétique |
| **N** (Naturalité) | N2 | Distance infrastructures | BD TOPO | Éloignement anthropique |
| **N** (Naturalité) | N3 | Pression anthropique | Multi-sources | Impact humain cumulé |

## Prérequis

- Tutorials 01-03 complétés (données en cache)
- Packages: sf, terra, happign

```r
install.packages(c("sf", "terra", "happign"))
```

### Fichiers requis des Tutorials précédents

```
~/nemeton_tutorial_data/
├── parcelles.gpkg              # T01: Parcelles cadastrales
├── bd_foret.gpkg               # T01: BD Forêt IGN
├── bd_topo.gpkg                # T01: BD TOPO
├── metriques_lidar.gpkg        # T02: Métriques LiDAR (B2)
└── indicateurs_terrain.gpkg    # T03: Indicateurs terrain
```

## Données de Sortie

```
~/nemeton_tutorial_data/
└── indicateurs_ecologiques.gpkg
    └── Colonnes: B1, B2, B3, L1, L2, L3, C2, T1, T2, A2, F2, N1, N2, N3
```

## Sections

1. Introduction aux indicateurs écologiques
2. Famille B : Biodiversité (B1, B2, B3)
3. Famille L : Paysage (L1, L2)
4. Indicateurs L3 (TVB) et C2 (NDVI)
5. Famille T : Temporel (T1, T2)
6. Export par famille d'indicateurs
   - 6.1 Famille B (Biodiversité)
   - 6.2 Famille L (Paysage)
   - 6.3 Famille T (Temporel)
   - 6.4 Familles A/F (Air/Fertilité)
   - 6.5 Famille N (Naturalité) + Synthèse
7. Quiz final

## Sources de Données Externes

| Source | API | Indicateurs |
|--------|-----|-------------|
| INPN | WFS Géoplateforme | B1 (zones protégées) |
| IGN BD Forêt | happign | B3, L1, L2, T1, A2, F2 |
| Cartes Cassini | Raster historique | T2 |
| Trame Verte Bleue | WFS Géoplateforme | L3 |
| Sentinel-2 (proxy) | BD Forêt | C2 (NDVI estimé) |

## Lancement

```r
learnr::run_tutorial("04-ecological", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `indicator_biodiversity_protection()` → B1
- `indicator_biodiversity_connectivity()` → B3
- `indicator_landscape_fragmentation()` → L1
- `indicator_landscape_edge()` → L2
- `indicator_landscape_tvb()` → L3
- `indicator_carbon_ndvi()` → C2
- `indicator_temporal_age()` → T1
- `indicator_temporal_ancient()` → T2
- `indicator_air_soil_carbon()` → A2
- `indicator_soil_quality()` → F2
- `indicator_naturalness_index()` → N1, N2, N3

## Tutoriel Suivant

→ **Tutorial 05** : Assemblage — Famille E (E2) + Indice Composite I_nemeton
