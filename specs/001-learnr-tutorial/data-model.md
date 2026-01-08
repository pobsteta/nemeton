# Data Model: Tutoriels Interactifs nemeton

**Date**: 2026-01-07
**Feature**: 001-learnr-tutorial

## Overview

Ce document décrit le modèle de données utilisé à travers les 6 tutoriels nemeton.

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   ZoneEtude     │       │    Parcelle     │       │   Indicateur    │
│─────────────────│       │─────────────────│       │─────────────────│
│ emprise (sfc)   │──1:N──│ id_parcelle     │──1:N──│ code (C1, B1..) │
│ placettes (sf)  │       │ geometry (sfg)  │       │ valeur (numeric)│
│ nom             │       │ surface_ha      │       │ famille (C,B..) │
│ crs (2154)      │       │ indicateurs[]   │       │ normalisé (0-100)│
└─────────────────┘       └─────────────────┘       └─────────────────┘
                                  │
                                  │ 1:1
                                  ▼
                          ┌─────────────────┐
                          │ MetriquesLiDAR  │
                          │─────────────────│
                          │ zmax            │
                          │ zmean           │
                          │ zsd             │
                          │ zq95            │
                          │ pzabove2        │
                          │ zentropy        │
                          │ density         │
                          └─────────────────┘
```

---

## Entities

### ZoneEtude

Représente la zone géographique d'étude.

| Attribut | Type | Description | Exemple |
|----------|------|-------------|---------|
| `emprise` | sfc_POLYGON | Emprise englobante | Buffer 500m autour placettes |
| `placettes` | sf | Points de référence | 28 placettes Quatre Montagnes |
| `nom` | character | Nom de la zone | "Vercors Centre" |
| `crs` | crs | Système de coordonnées | EPSG:2154 |

**Fichier cache**: `zone_etude.gpkg`
- Layer "zone_etude": emprise
- Layer "placettes": points

### Parcelle

Unité spatiale de base pour l'analyse.

| Attribut | Type | Description | Contraintes |
|----------|------|-------------|-------------|
| `id_parcelle` | character | Identifiant unique | PK, format "XXX-YYYY" |
| `geometry` | sfg | Géométrie polygone | POLYGON/MULTIPOLYGON |
| `surface_ha` | numeric | Surface en hectares | > 0 |
| `commune` | character | Code INSEE commune | 5 caractères |
| `section` | character | Section cadastrale | 2 caractères |
| `numero` | character | Numéro parcelle | Variable |

**Fichier cache**: `parcelles.gpkg`

### MetriquesLiDAR

Métriques dérivées du nuage de points LiDAR.

| Attribut | Type | Unité | Description | Plage |
|----------|------|-------|-------------|-------|
| `zmax` | numeric | m | Hauteur maximale | 0-60 |
| `zmean` | numeric | m | Hauteur moyenne | 0-40 |
| `zsd` | numeric | m | Écart-type hauteurs | 0-20 |
| `zq95` | numeric | m | Percentile 95 | 0-55 |
| `pzabove2` | numeric | % | Points > 2m | 0-100 |
| `zentropy` | numeric | - | Entropie verticale | 0-1 |
| `density` | numeric | n/ha | Densité arbres | 0-2000 |

**Fichier cache**: `metriques_lidar.gpkg`

### Indicateur

Valeur calculée pour une parcelle.

| Attribut | Type | Description |
|----------|------|-------------|
| `code` | character | Code indicateur (C1, B1, etc.) |
| `valeur` | numeric | Valeur brute |
| `unite` | character | Unité de mesure |
| `normalise` | numeric | Valeur normalisée 0-100 |
| `famille` | character | Code famille (C, B, W, etc.) |
| `methode` | character | Méthode de calcul |

---

## Indicator Families

### Mapping Indicateurs → Données Sources

| Famille | Code | Indicateur | Données Source |
|---------|------|------------|----------------|
| **C** (Carbone) | C1 | Biomasse | zmax, zmean (LiDAR) |
| | C2 | NDVI tendance | Sentinel-2 |
| **B** (Biodiversité) | B1 | Protection | zones_inpn |
| | B2 | Structure verticale | zsd, zentropy (LiDAR) |
| | B3 | Connectivité | bd_foret |
| **W** (Eau) | W1 | TWI | mnt (pente, accumulation) |
| | W2 | Réseau hydro | bd_topo (cours_eau) |
| | W3 | Zones humides | twi + bd_topo |
| **A** (Air) | A1 | Couverture | pzabove2 (LiDAR) |
| | A2 | Qualité | bd_foret (type_peuplement) |
| **F** (Sol) | F1 | Érosion | mnt (pente) |
| | F2 | Fertilité | bd_foret + mnt |
| **L** (Paysage) | L1 | Lisière | bd_foret (edge) |
| | L2 | Fragmentation | bd_foret (patches) |
| **T** (Temporel) | T1 | Âge | bd_foret (age_peuplement) |
| | T2 | Changement | séries temporelles |
| **R** (Risques) | R1 | Feu | mnt (pente, exposition) |
| | R2 | Tempête | mnt (exposition) |
| | R3 | Sécheresse | climat + mnt |
| **S** (Social) | S1 | Accessibilité | bd_topo (routes) |
| | S2 | Proximité | bd_topo (batiments) |
| | S3 | Sentiers | bd_topo (chemins) |
| **P** (Production) | P1 | Volume | zmax, zq95, density (LiDAR) |
| | P2 | Station | mnt (pente, expo) |
| | P3 | Qualité | zmean, zsd (LiDAR) |
| **E** (Énergie) | E1 | Bois-énergie | volume estimé |
| | E2 | Évitement carbone | volume × facteur |
| **N** (Naturalité) | N1 | Continuité | bd_foret (historique) |
| | N2 | Distance perturb. | routes, bâtiments |
| | N3 | Composite | N1 × N2 |

---

## File Formats

### GeoPackage (.gpkg)

Format principal pour données vectorielles multi-couches.

```
zone_etude.gpkg
├── zone_etude (POLYGON)
└── placettes (POINT)

parcelles.gpkg
└── parcelles (POLYGON)

bd_foret.gpkg
└── formations_vegetales (POLYGON)

bd_topo.gpkg
├── routes (LINESTRING)
├── cours_eau (LINESTRING)
├── batiments (POLYGON)
└── sentiers (LINESTRING)

indicateurs_complets.gpkg
└── parcelles_indicateurs (POLYGON)
    ├── geometry
    ├── id_parcelle
    ├── C1, C2, B1, B2, B3, ... (40+ colonnes)
    ├── C1_norm, C2_norm, ... (normalisés)
    └── idx_C, idx_B, ... (indices famille)
```

### GeoTIFF (.tif)

Format pour données raster.

```
mnt.tif          # Altitude (m), res=5m
mnh.tif          # Hauteur canopée (m), res=5m
pente.tif        # Pente (°), res=5m
exposition.tif   # Exposition (°), res=5m
twi.tif          # TWI (sans unité), res=5m
```

### LiDAR (.laz, .copc.laz)

Format pour nuages de points.

```
lidar_hd/
├── tile_1234.copc.laz
├── tile_1235.copc.laz
└── ...
```

---

## State Transitions

### Parcelle Workflow

```
[Vide] → [Géométrie] → [+Métriques LiDAR] → [+Indicateurs Terrain] 
                                                      ↓
[Export] ← [+Indices Famille] ← [+Normalisation] ← [+Indicateurs Écolo]
```

### Cache State

```
[Non existant] --download--> [Téléchargé] --process--> [Traité]
       ↑                           |
       └───────────────────────────┘
                  (rechargement)
```

---

## Validation Rules

### Parcelle
- `surface_ha > 0`
- `st_is_valid(geometry) == TRUE`
- `st_crs(geometry)$epsg == 2154`

### Indicateur
- `0 <= normalise <= 100`
- `famille %in% c("C","B","W","A","F","L","T","R","S","P","E","N")`

### MetriquesLiDAR
- `zmax >= zmean >= 0`
- `0 <= pzabove2 <= 100`
- `0 <= zentropy <= 1`
