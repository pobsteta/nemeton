# Tutorial 02 : LiDAR — Familles C, P, E, A (C1, C2, P1, P2, P3, E1, E2, A1, A2)

## Description

Ce tutoriel traite les données LiDAR HD pour extraire **9 indicateurs** appartenant à **4 familles** nemeton.

## Indicateurs Calculés

| Famille | Code | Indicateur | Métrique LiDAR | Description |
|---------|------|------------|----------------|-------------|
| **C** (Carbone) | C1 | Stock carbone aérien | zmax, zmean | Biomasse estimée via hauteur |
| **C** (Carbone) | C2 | Vitalité NDVI | NDVI/BD Forêt | Indice de végétation normalisé |
| **P** (Production) | P1 | Volume sur pied | zq95, zmean, pzabove2 | Potentiel productif |
| **P** (Production) | P2 | Productivité forestière | zmean, pzabove2, zq95, zq25 | Productivité annuelle |
| **P** (Production) | P3 | Qualité structurale | zentropy, zsd, zmean | Régularité du peuplement |
| **E** (Énergie) | E1 | Potentiel bois-énergie | pzabove2, zmean | Production énergétique (tep/ha) |
| **E** (Énergie) | E2 | Évitement carbone | E1 × substitution | tCO₂ évitées par substitution |
| **A** (Air) | A1 | Occupation du sol | OSO + pzabove2 | % couverture forestière |
| **A** (Air) | A2 | Qualité air | - | Score qualité air (pollution) |

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
├── oso.tif           # OSO Theia/CESBIO (téléchargé automatiquement)
└── lidar_hd/         # Dalles LiDAR HD
    └── *.copc.laz
```

> **OSO** : L'Occupation du Sol (OSO) est produite par Theia/CESBIO à 10m de résolution.
> Téléchargement : https://entrepot.recherche.data.gouv.fr/dataset.xhtml?persistentId=doi:10.57745/UZ2NJ7

## Données de Sortie

```
~/nemeton_tutorial_data/
├── mnh.tif                                # Modèle Numérique de Hauteur (1m)
├── metriques_lidar.gpkg                   # Métriques LiDAR interpolées
├── metriques_stock_carbone_c1.gpkg        # Stock carbone aérien (C1)
├── metriques_vitalite_c2.gpkg              # Vitalité NDVI (C2)
├── metriques_volume_bois_p1.gpkg          # Volume bois sur pied (P1)
├── metriques_productivite_p2.gpkg         # Productivité forestière (P2)
├── metriques_qualite_structurale_p3.gpkg  # Qualité structurale (P3)
├── metriques_couverture_forestiere_a1.gpkg # Couverture forestière (A1)
├── metriques_qualite_air_a2.gpkg          # Qualité air (A2)
├── metriques_bois_energie_e1.gpkg         # Potentiel bois-énergie (E1)
├── metriques_evitement_carbone_e2.gpkg    # Évitement carbone (E2)
├── indicateurs_lidar.gpkg                 # Consolidation (tous indicateurs)
└── parcelles.gpkg                         # Parcelles enrichies (tous indicateurs)
```

## Sections

1. Introduction au LiDAR forestier
2. Chargement et filtrage du nuage de points
3. Normalisation des hauteurs (MNT → hauteurs relatives)
4. Génération du MNH (Modèle Numérique de Hauteur)
5. Calcul des métriques par parcelle
6. Export des métriques LiDAR
7. Indicateurs Carbone, Production et Air (C1, P1, P2, P3, A1)
8. Indicateurs Énergie (E1, E2)
9. Indicateurs Vitalité et Air (C2, A2)
10. Export et synthèse
    - 10.1 Famille C (Carbone)
    - 10.2 Famille P (Production)
    - 10.3 Famille E (Énergie)
    - 10.4 Famille A (Air)
    - 10.5 Synthèse finale
11. Quiz final

## Métriques LiDAR → Indicateurs

| Métrique | Description | Formule Indicateur |
|----------|-------------|-------------------|
| zmax | Hauteur maximale (m) | C1 = AGB × 0.47 |
| zmean | Hauteur moyenne (m) | P2 = k × zmean × couvert × vigueur |
| zsd | Écart-type hauteurs (m) | P3 = 100 - (entropy + CV) |
| zq95 | Percentile 95 (m) | P1 = k × couvert × zmean × zq95 |
| zentropy | Entropie verticale | P3 = f(zentropy, zsd) |
| pzabove2 | % couverture > 2m | A1 = 0.7×OSO + 0.3×pzabove2, E1 = f(pzabove2, zmean) |
| E1 | Potentiel bois-énergie | E2 = E1 × f_substitution × η |

## Lancement

```r
learnr::run_tutorial("02-lidar", package = "nemeton")
```

## Connexion avec nemeton

Fonctions principales utilisées :
- `indicator_carbon_stock()` → C1
- `indicator_carbon_vitality()` → C2 (NDVI)
- `indicator_production_volume()` → P1
- `indicator_production_productivity()` → P2
- `indicator_production_quality()` → P3
- `indicator_energy_fuelwood()` → E1
- `indicator_energy_avoidance()` → E2
- `indicator_air_cover()` → A1
- `indicator_air_quality()` → A2

## Tutoriel Suivant

→ **Tutorial 03** : Terrain — Familles W, R, S, F (12 indicateurs)
