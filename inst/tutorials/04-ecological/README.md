# Tutorial 04 : Écologie — Familles B, L, T, N (11 indicateurs)

## Description

Ce tutoriel calcule **11 indicateurs** écologiques appartenant à **4 familles** nemeton, en utilisant la BD Forêt, l'INPN et des données géographiques.

## Indicateurs Calculés

| Famille | Code | Indicateur | Source | Description |
|---------|------|------------|--------|-------------|
| **B** (Biodiversité) | B1 | Zones protégées | INPN WFS | Overlap ZNIEFF, Natura 2000 |
| **B** (Biodiversité) | B2 | Diversité structurale | LiDAR (T02) | Hétérogénéité verticale |
| **B** (Biodiversité) | B3 | Connectivité écologique | BD Forêt | Continuité massifs |
| **L** (Paysage) | L1 | Effet lisière | BD Forêt | Géométrie + contraste + exposition |
| **L** (Paysage) | L2 | Fragmentation | BD Forêt | Indice de morcellement |
| **L** (Paysage) | L3 | Trame Verte et Bleue | WFS TVB | Corridors écologiques |
| **T** (Temporel) | T1 | Âge peuplement | BD Forêt | Classe d'âge estimée |
| **T** (Temporel) | T2 | Ancienneté forestière | Cartes historiques | Forêt ancienne (>150 ans) |
| **N** (Naturalité) | N1 | Distance infrastructures | BD TOPO | Éloignement anthropique |
| **N** (Naturalité) | N2 | Continuité forestière | Cartes historiques | Forêt ancienne vs récente |
| **N** (Naturalité) | N3 | Naturalité composite | Multi-sources | Indice synthétique |

> **Note :** Les indicateurs **C2** (NDVI Vitalité) et **A2** (Qualité air) sont calculés dans le **Tutorial 02 (LiDAR)**. L'indicateur **F2** (Fertilité sol) est calculé dans le **Tutorial 03 (Terrain)**.

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
    └── Colonnes: B1, B2, B3, L1, L2, L3, T1, T2, N1, N2, N3
```

## Sections

1. BD Forêt V2 (exploration)
2. Zonages de protection (B1)
3. Structure et Connectivité (B2, B3)
4. Paysage (L1, L2, L3)
5. Naturalité (N1, N2, N3)
6. Indicateurs complémentaires (T1, T2)
7. Export et synthèse
   - 7.1 Famille B (Biodiversité)
   - 7.2 Famille L (Paysage)
   - 7.3 Famille T (Temporel)
   - 7.4 Famille N (Naturalité)
   - 7.5 Synthèse finale
8. Quiz final

## Sources de Données Externes

| Source | API | Indicateurs |
|--------|-----|-------------|
| INPN | WFS Géoplateforme | B1 (zones protégées) |
| IGN BD Forêt | happign | B3, L1, L2, T1 |
| Cartes Cassini | Raster historique | T2, N2 |
| Trame Verte Bleue | WFS Géoplateforme | L3 |

## Lancement

```r
learnr::run_tutorial("04-ecological", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `indicator_biodiversity_protection()` → B1
- `indicator_biodiversity_structure()` → B2
- `indicator_biodiversity_connectivity()` → B3
- `indicator_landscape_edge()` → L1
- `indicator_landscape_fragmentation()` → L2
- `indicator_landscape_tvb()` → L3
- `indicator_temporal_age()` → T1
- `indicator_temporal_ancient()` → T2
- `indicator_naturalness_index()` → N1, N2, N3

## Tutoriel Suivant

→ **Tutorial 05** : Assemblage — Famille E (E2) + Indice Composite I_nemeton
