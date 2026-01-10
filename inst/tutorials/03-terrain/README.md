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
├── pente.tif                              # Pente (degrés)
├── exposition.tif                         # Exposition (degrés)
├── twi.tif                                # Topographic Wetness Index
├── erosion_f1.tif                         # Raster érosion RUSLE
├── distance_routes.tif                    # Distance euclidienne routes
├── distance_batiments.tif                 # Distance euclidienne bâtiments
├── metriques_erosion_f1.gpkg              # Érosion (F1)
├── metriques_fertilite_sol_f2.gpkg        # Fertilité sol (F2)
├── metriques_twi_w3.gpkg                  # TWI (W3)
├── metriques_densite_hydro_w1.gpkg        # Densité hydro (W1)
├── metriques_couverture_zone_humide_w2.gpkg # Zones humides (W2)
├── metriques_exposition_feu_r1.gpkg       # Risque feu (R1)
├── metriques_exposition_tempete_r2.gpkg   # Risque tempête (R2)
├── metriques_risque_secheresse_r3.gpkg    # Risque sécheresse (R3)
├── metriques_pression_gibier_r4.gpkg      # Pression gibier (R4)
├── metriques_access_route_s1.gpkg         # Accessibilité route (S1)
├── metriques_distance_batiment_s2.gpkg    # Distance bâtiments (S2)
├── metriques_densite_sentiers_s3.gpkg     # Densité sentiers (S3)
└── indicateurs_terrain.gpkg               # Consolidation (tous indicateurs)
```

## Sections

1. Dérivés topographiques et érosion (F1)
2. TWI et Fertilité (W3, F2)
3. Réseau hydrographique (W1, W2)
4. Indicateurs de risque (R1, R2, R3, R4)
5. Accessibilité (S1, S2, S3)
6. Export et synthèse
   - 6.1 Famille W (Eau)
   - 6.2 Famille R (Risques)
   - 6.3 Famille S (Social)
   - 6.4 Famille F (Sol)
   - 6.5 Synthèse finale
7. Quiz final

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

→ **Tutorial 04** : Écologie — Familles B, L, T, F, N (12 indicateurs)
