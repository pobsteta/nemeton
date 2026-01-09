# Tutorial 02 : LiDAR — Familles C, P, B, E, A (C1, P1, P3, B2, E1, E2, A1)

## Description

Ce tutoriel traite les données LiDAR HD pour extraire **7 indicateurs** appartenant à **5 familles** nemeton.

## Indicateurs Calculés

| Famille | Code | Indicateur | Métrique LiDAR | Description |
|---------|------|------------|----------------|-------------|
| **C** (Carbone) | C1 | Stock carbone aérien | zmax, zmean | Biomasse estimée via hauteur |
| **P** (Production) | P1 | Hauteur dominante | zq95, zmax | Potentiel productif |
| **P** (Production) | P3 | Volume sur pied | zmean × couvert | Volume bois estimé |
| **B** (Biodiversité) | B2 | Complexité structurale | zsd | Diversité des strates |
| **E** (Énergie) | E1 | Potentiel bois-énergie | pzabove2, zmean | Production énergétique (tep/ha) |
| **E** (Énergie) | E2 | Évitement carbone | E1 × substitution | tCO₂ évitées par substitution |
| **A** (Air) | A1 | Interception pluies | pzabove2 | Régulation hydrologique |

## Prérequis

- Tutorial 01 complété (données en cache)
- Package lidR installé

```r
install.packages("lidR")
```

## Données d'Entrée

```
~/nemeton_tutorial_data/
├── mnt.tif           # MNT RGE Alti 5m
├── parcelles.gpkg    # Parcelles cadastrales
└── lidar_hd/         # Dalles LiDAR HD
    └── *.copc.laz
```

## Données de Sortie

```
~/nemeton_tutorial_data/
├── mnh.tif                  # Modèle Numérique de Hauteur (1m)
└── metriques_lidar.gpkg     # Parcelles + indicateurs LiDAR
    └── Colonnes: C1, P1, P3, B2, E1, E2, A1, zmax, zmean, zsd, zq95, pzabove2
```

## Sections

1. Introduction au LiDAR forestier
2. Chargement et filtrage du nuage de points
3. Normalisation des hauteurs (MNT → hauteurs relatives)
4. Génération du MNH (Modèle Numérique de Hauteur)
5. Calcul des métriques par parcelle
6. Export des résultats
7. Indicateurs Énergie (E1, E2)
8. Quiz final

## Métriques LiDAR → Indicateurs

| Métrique | Description | Formule Indicateur |
|----------|-------------|-------------------|
| zmax | Hauteur maximale (m) | C1 = f(zmax, zmean) |
| zmean | Hauteur moyenne (m) | P3 = zmean × pzabove2, E1 = f(pzabove2, zmean) |
| zsd | Écart-type hauteurs (m) | B2 = zsd / zmean |
| zq95 | Percentile 95 (m) | P1 = zq95 |
| pzabove2 | % couverture > 2m | A1, E1 = f(pzabove2) |
| E1 | Potentiel bois-énergie | E2 = E1 × f_substitution × η |

## Lancement

```r
learnr::run_tutorial("02-lidar", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `indicator_carbon_stock()` → C1
- `indicator_production_height()` → P1
- `indicator_production_volume()` → P3
- `indicator_biodiversity_structure()` → B2
- `indicator_energy_fuelwood()` → E1
- `indicator_energy_avoidance()` → E2
- `indicator_air_interception()` → A1

## Tutoriel Suivant

→ **Tutorial 03** : Terrain — Familles W, R, S, P, F (W1-3, R1-3, S1-3, P2, F1)
