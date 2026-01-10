# Tutorial 03 : Terrain — Familles W, R, S, F (W1-3, R1-4, S1-3, F1-2)

## Description

Ce tutoriel calcule **12 indicateurs** terrain dérivés du MNT et de la BD TOPO, appartenant à **4 familles** nemeton.

## Indicateurs Calculés

| Famille | Code | Indicateur | Source | Description |
|---------|------|------------|--------|-------------|
| **W** (Eau) | W1 | Densité réseau hydro | BD TOPO | m linéaires / ha |
| **W** (Eau) | W2 | Zones humides | MNT (TWI) | % surface TWI > seuil |
| **W** (Eau) | W3 | TWI moyen | MNT | Indice topographique d'humidité |
| **R** (Risques) | R1 | Risque incendie | BD Forêt + exposition | Score 0-100 |
| **R** (Risques) | R2 | Risque tempête | Exposition + altitude | Score 0-100 |
| **R** (Risques) | R3 | Risque sécheresse | Pente + TWI | Score 0-100 |
| **R** (Risques) | R4 | Pression gibier | data.gouv.fr + BD Forêt | Score 0-100 |
| **S** (Social) | S1 | Distance routes | BD TOPO | Accessibilité (m) |
| **S** (Social) | S2 | Distance bâtiments | BD TOPO | Éloignement habitat (m) |
| **S** (Social) | S3 | Densité sentiers | OSM | Fréquentation potentielle |
| **F** (Sol) | F1 | Risque érosion | Pente + ruissellement | Score RUSLE simplifié |
| **F** (Sol) | F2 | Fertilité sol | TWI + pente | Score 0-100 |

### Détail R4 (Pression gibier)

| Composante | Poids | Source |
|------------|-------|--------|
| Palatabilité essence | 35% | BD Forêt (type peuplement) |
| Vulnérabilité peuplement | 30% | LiDAR (hauteur) |
| Effet lisière | 20% | Géométrie parcelle |
| Densité gibier | 15% | Tableaux de chasse (data.gouv.fr) |

## Prérequis

- Tutorial 01 complété (données en cache)
- Packages de base: sf, terra

```r
install.packages(c("sf", "terra", "whitebox"))
```

### Fichiers requis du Tutorial 01

```
~/nemeton_tutorial_data/
├── mnt.tif           # MNT RGE Alti 5m
├── parcelles.gpkg    # Parcelles cadastrales
├── bd_foret.gpkg     # BD Forêt IGN
└── bd_topo.gpkg      # BD TOPO (routes, hydro, bâtiments)
```

## Données de Sortie

```
~/nemeton_tutorial_data/
├── pente.tif                    # Pente (degrés)
├── exposition.tif               # Exposition (degrés)
├── twi.tif                      # Topographic Wetness Index
├── distance_routes.tif          # Distance euclidienne routes
├── distance_batiments.tif       # Distance euclidienne bâtiments
└── indicateurs_terrain.gpkg     # Parcelles + 12 indicateurs
    └── Colonnes: W1, W2, W3, R1, R2, R3, R4, S1, S2, S3, F1, F2
```

## Sections

1. Introduction aux indicateurs terrain
2. Calcul de la pente et exposition
3. Calcul du TWI (Topographic Wetness Index)
4. Famille W : Indicateurs Eau (W1, W2, W3)
5. Famille R : Indicateurs Risques (R1, R2, R3, R4)
6. Famille S : Indicateurs Sociaux (S1, S2, S3)
7. Famille F : Indicateurs Sol (F1, F2)
8. Export GeoPackage
9. Quiz final

## Lancement

```r
learnr::run_tutorial("03-terrain", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `indicator_water_network()` → W1
- `indicator_water_wetlands()` → W2
- `indicator_water_twi()` → W3
- `indicator_risk_fire()` → R1
- `indicator_risk_storm()` → R2
- `indicator_risk_drought()` → R3
- `indicator_risk_browsing()` → R4
- `indicator_social_roads()` → S1
- `indicator_social_buildings()` → S2
- `indicator_social_trails()` → S3
- `indicator_soil_erosion()` → F1
- `indicator_soil_fertility()` → F2

## Tutoriel Suivant

→ **Tutorial 04** : Écologie — Familles B, L, T, N (11 indicateurs)
