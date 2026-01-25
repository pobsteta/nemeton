# Feature Specification: Tutoriels Interactifs nemeton - Série Complète

**Feature Branch**: `001-learnr-tutorial`
**Created**: 2026-01-06
**Updated**: 2026-01-07
**Status**: En cours
**Version cible**: nemeton v0.4.1

## Vue d'Ensemble

Cette spécification définit une série de **6 tutoriels interactifs learnr** permettant aux apprenants de maîtriser progressivement le workflow complet nemeton, depuis l'acquisition des données jusqu'au calcul des **12 familles d'indicateurs écosystémiques**.

### Les 12 Familles d'Indicateurs nemeton

| Code | Famille | Indicateurs | Données requises |
|------|---------|-------------|------------------|
| **C** | Carbone | C1-Biomasse, C2-NDVI | LiDAR, Sentinel-2 |
| **B** | Biodiversité | B1-Protection, B2-Structure, B3-Connectivité | LiDAR, INPN, BD Forêt |
| **W** | Eau | W1-TWI, W2-Réseau, W3-Zones humides | MNT, BD TOPO |
| **A** | Air | A1-Couverture, A2-Qualité | LiDAR, BD Forêt |
| **F** | Sol/Fertilité | F1-Érosion, F2-Fertilité | MNT, BD Forêt |
| **L** | Paysage | L1-Lisière, L2-Fragmentation | BD Forêt, Cadastre |
| **T** | Temporel | T1-Âge, T2-Changement | BD Forêt, Séries temporelles |
| **R** | Risques | R1-Feu, R2-Tempête, R3-Sécheresse | MNT, Climat, BD Forêt |
| **S** | Social | S1-Accessibilité, S2-Proximité, S3-Sentiers | BD TOPO, OSM |
| **P** | Production | P1-Volume, P2-Station, P3-Qualité | LiDAR, MNT, BD Forêt |
| **E** | Énergie | E1-Bois-énergie, E2-Évitement | LiDAR, BD Forêt |
| **N** | Naturalité | N1-Continuité, N2-Distance, N3-Composite | BD Forêt, INPN |

### Architecture des Tutoriels

```
┌─────────────────────────────────────────────────────────────────────┐
│  Tutorial 01: Acquisition des Données                               │
│  ─────────────────────────────────────                              │
│  Zone d'étude → Cadastre → MNT → BD Forêt → BD TOPO → LiDAR HD     │
│                                                                     │
│  SORTIE: zone_etude.gpkg (zone, placettes, parcelles, mnt, foret)  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Tutorial 02: Traitement LiDAR et Métriques Forestières            │
│  ──────────────────────────────────────────────────────            │
│  Dalles LiDAR → Normalisation → MNH → Métriques par parcelle       │
│                                                                     │
│  SORTIE: metriques_lidar.gpkg (hauteurs, densité, couverture)      │
│  INDICATEURS: Base pour C1, B2, A1, P1, P3, E1                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Tutorial 03: Indicateurs Terrain (MNT + BD TOPO)                   │
│  ────────────────────────────────────────────────                   │
│  Pente/Exposition → TWI → Réseau hydro → Routes/Sentiers           │
│                                                                     │
│  INDICATEURS: W1, W2, W3, F1, R1, R2, R3, S1, S2, S3, P2           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Tutorial 04: Indicateurs Écologiques (BD Forêt + INPN)            │
│  ──────────────────────────────────────────────────────            │
│  Types peuplement → Zones protégées → Connectivité → Naturalité    │
│                                                                     │
│  INDICATEURS: B1, B3, L1, L2, T1, A2, F2, N1, N2, N3               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Tutorial 05: Calcul Complet et Normalisation                       │
│  ────────────────────────────────────────────                       │
│  Assemblage 12 familles → Normalisation 0-100 → Indices composites │
│                                                                     │
│  SORTIE: indicateurs_complets.gpkg (40+ indicateurs normalisés)    │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Tutorial 06: Analyse Multi-Critères et Export                      │
│  ─────────────────────────────────────────────                      │
│  Radar 12-axes → Corrélations → Hotspots → Trade-offs → Export     │
│                                                                     │
│  SORTIE: Rapports HTML/PDF, GeoPackage final, Cartes interactives  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tutorial 01 : Acquisition des Données Géographiques

**Fichier** : `inst/tutorials/01-acquisition/01-acquisition.Rmd`
**Statut** : ✅ Complété (~95%)
**Durée estimée** : 30-45 minutes

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Créer une zone d'étude géoréférencée à partir de placettes forestières
2. Télécharger les données cadastrales via l'API IGN (happign)
3. Télécharger le MNT RGE Alti 5m
4. Télécharger la BD Forêt V2 et la BD TOPO
5. Télécharger les dalles LiDAR HD (lidarHD)
6. Organiser les données dans un cache local persistant

### Sections Implémentées

| # | Section | Contenu | Données produites |
|---|---------|---------|-------------------|
| 1 | Définir la zone d'étude | Chargement quatre_montagnes, création buffer 500m | `zone_etude.gpkg` (layer: zone_etude, placettes) |
| 2 | Téléchargement cadastre | API happign WFS, filtrage parcelles | `parcelles.gpkg` |
| 3 | Téléchargement MNT | RGE Alti 5m, terra::rast | `mnt.tif` |
| 4 | BD Forêt et BD TOPO | WFS IGN, formations végétales, routes, hydro | `bd_foret.gpkg`, `bd_topo.gpkg` |
| 5 | Données LiDAR HD | lidarHD::load_classified_ta, download_files | `lidar_hd/*.copc.laz` |
| 6 | Synthèse | Récapitulatif, quiz validation | - |

### Pattern Pédagogique

L'apprenant écrit lui-même le code de cache à chaque exercice :

```r
# Définir le répertoire de cache
if (requireNamespace("rappdirs", quietly = TRUE)) {
  data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
} else {
  data_dir <- file.path(path.expand("~"), "nemeton_tutorial_data")
}
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# Pattern cache: vérifier → charger OU télécharger → sauvegarder
fichier <- file.path(data_dir, "donnees.gpkg")
if (file.exists(fichier)) {
  donnees <- st_read(fichier, quiet = TRUE)
} else {
  donnees <- telecharger_donnees(...)
  st_write(donnees, fichier)
}
```

### Points Techniques Clés

- **CRS** : Lambert-93 (EPSG:2154) pour toutes données françaises
- **LiDAR STAC API** : bbox en WGS84 (EPSG:4326) requis pour `load_classified_ta()`
- **Timeout exercices LiDAR** : 600 secondes (10 min)
- **Cache persistant** : `rappdirs::user_data_dir("nemeton")`

### Données de Sortie

```
~/nemeton_tutorial_data/
├── zone_etude.gpkg        # Layers: zone_etude, placettes
├── parcelles.gpkg         # Parcelles cadastrales
├── mnt.tif               # MNT RGE Alti 5m
├── bd_foret.gpkg         # BD Forêt V2
├── bd_topo.gpkg          # Routes, hydro, bâtiments
└── lidar_hd/             # Dalles LiDAR HD .copc.laz
```

---

## Tutorial 02 : Traitement LiDAR et Métriques Forestières

**Fichier** : `inst/tutorials/02-lidar/02-lidar.Rmd`
**Statut** : 🔲 À créer
**Durée estimée** : 45-60 minutes
**Prérequis** : Tutorial 01 complété

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Charger et visualiser un nuage de points LiDAR
2. Comprendre la classification des points (sol, végétation)
3. Normaliser les hauteurs par rapport au MNT
4. Générer un Modèle Numérique de Hauteur (MNH)
5. Calculer des métriques dendrométriques par parcelle

### Sections Prévues

| # | Section | Contenu | Fonctions |
|---|---------|---------|-----------|
| 1 | Introduction LiDAR | Principes, classification des points | - |
| 2 | Chargement nuage de points | lidR::readLAS, visualisation 3D | `lidR::readLAS()`, `lidR::plot()` |
| 3 | Normalisation hauteurs | Soustraction MNT, filtrage négatifs | `lidR::normalize_height()` |
| 4 | Génération MNH | Rasterisation hauteur max | `lidR::rasterize_canopy()` |
| 5 | Métriques par parcelle | Extraction statistiques | `lidR::cloud_metrics()`, `lidR::pixel_metrics()` |
| 6 | Export métriques | Jointure aux parcelles | `exactextractr::exact_extract()` |
| 7 | Quiz validation | Test connaissances LiDAR | - |

### Métriques LiDAR Calculées

| Métrique | Description | Usage indicateurs |
|----------|-------------|-------------------|
| `zmax` | Hauteur maximale (m) | P1-Volume, C1-Biomasse |
| `zmean` | Hauteur moyenne (m) | P3-Qualité |
| `zsd` | Écart-type hauteurs (m) | B2-Structure |
| `zq95` | Percentile 95 hauteur (m) | P1-Volume |
| `pzabove2` | % points > 2m | A1-Couverture, E1-Bois-énergie |
| `zentropy` | Entropie verticale | B2-Structure |
| `Tree_density` | Densité arbres/ha | P1-Volume |

### Données d'Entrée (depuis Tutorial 01)

```r
# Chargement depuis le cache
data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
parcelles <- st_read(file.path(data_dir, "parcelles.gpkg"))
mnt <- rast(file.path(data_dir, "mnt.tif"))
fichiers_laz <- list.files(file.path(data_dir, "lidar_hd"),
                           pattern = "\\.laz$", full.names = TRUE)
```

### Données de Sortie

```
~/nemeton_tutorial_data/
├── ... (données Tutorial 01)
├── mnh.tif                    # Modèle Numérique de Hauteur
└── metriques_lidar.gpkg       # Parcelles avec métriques LiDAR
    └── Colonnes: id_parcelle, zmax, zmean, zsd, zq95, pzabove2, zentropy, density
```

### Indicateurs Préparés

Ce tutoriel prépare les données pour :
- **C1** (Carbone-Biomasse) : via zmax, zmean
- **B2** (Biodiversité-Structure) : via zsd, zentropy
- **A1** (Air-Couverture) : via pzabove2
- **P1** (Production-Volume) : via zmax, zq95, density
- **P3** (Production-Qualité) : via zmean, zsd
- **E1** (Énergie-Bois-énergie) : via volume estimé

---

## Tutorial 03 : Indicateurs Terrain (MNT + BD TOPO)

**Fichier** : `inst/tutorials/03-terrain/03-terrain.Rmd`
**Statut** : 🔲 À créer
**Durée estimée** : 30-40 minutes
**Prérequis** : Tutorials 01-02 complétés

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Calculer pente et exposition depuis le MNT
2. Calculer l'indice topographique d'humidité (TWI)
3. Analyser la proximité au réseau hydrographique
4. Analyser l'accessibilité via le réseau routier
5. Calculer les indicateurs des familles W, R, S, P2

### Sections Prévues

| # | Section | Contenu | Indicateurs |
|---|---------|---------|-------------|
| 1 | Dérivés topographiques | Pente, exposition, courbure | Base pour W1, R, P2 |
| 2 | TWI (Topographic Wetness Index) | Accumulation flux, humidité | **W1** |
| 3 | Réseau hydrographique | Distance cours d'eau, densité | **W2** |
| 4 | Zones humides | Détection via TWI + BD TOPO | **W3** |
| 5 | Risques terrain | Pente feu, exposition tempête | **R1, R2, R3** |
| 6 | Accessibilité | Distance routes, sentiers | **S1, S2, S3** |
| 7 | Station forestière | Fertilité station (pente, expo) | **P2** |
| 8 | Quiz validation | - | - |

### Fonctions nemeton Utilisées

```r
# Famille Eau (W)
indicator_water_twi(parcelles, mnt)           # W1
indicator_water_network(parcelles, hydro)     # W2
indicator_water_wetlands(parcelles, mnt, bd_topo)  # W3

# Famille Risques (R)
indicator_risk_fire(parcelles, mnt, bd_foret)      # R1
indicator_risk_storm(parcelles, mnt)               # R2
indicator_risk_drought(parcelles, climat)          # R3

# Famille Social (S)
indicator_social_accessibility(parcelles, routes)  # S1
indicator_social_proximity(parcelles, batiments)   # S2
indicator_social_trails(parcelles, sentiers)       # S3

# Famille Production (P)
indicator_productive_station(parcelles, mnt)       # P2
```

### Données d'Entrée

```r
data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
parcelles <- st_read(file.path(data_dir, "metriques_lidar.gpkg"))
mnt <- rast(file.path(data_dir, "mnt.tif"))
bd_topo <- st_read(file.path(data_dir, "bd_topo.gpkg"))
```

### Données de Sortie

```
~/nemeton_tutorial_data/
├── ... (données Tutorials 01-02)
├── pente.tif                  # Pente en degrés
├── exposition.tif             # Exposition 0-360°
├── twi.tif                    # Topographic Wetness Index
└── indicateurs_terrain.gpkg   # Parcelles + indicateurs W, R, S, P2
    └── Colonnes ajoutées: W1, W2, W3, R1, R2, R3, S1, S2, S3, P2
```

---

## Tutorial 04 : Indicateurs Écologiques (BD Forêt + INPN)

**Fichier** : `inst/tutorials/04-ecological/04-ecological.Rmd`
**Statut** : 🔲 À créer
**Durée estimée** : 30-40 minutes
**Prérequis** : Tutorials 01-03 complétés

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Exploiter la BD Forêt V2 (types de peuplement, essences)
2. Interroger les zonages de protection INPN (ZNIEFF, Natura 2000)
3. Calculer la connectivité écologique
4. Évaluer les indicateurs de naturalité
5. Calculer les indicateurs des familles B, L, T, A, F, N

### Sections Prévues

| # | Section | Contenu | Indicateurs |
|---|---------|---------|-------------|
| 1 | BD Forêt V2 | Types peuplement, essences, âge | Base pour L, T, F, A |
| 2 | Zonages protection | ZNIEFF, Natura 2000, PNR | **B1** |
| 3 | Structure verticale | Diversité strates (LiDAR + BD Forêt) | **B2** (complément) |
| 4 | Connectivité | Corridors, fragmentation | **B3, L2** |
| 5 | Lisières et paysage | Effet lisière, mosaïque | **L1** |
| 6 | Âge et dynamique | Classes d'âge, succession | **T1, T2** |
| 7 | Qualité air | Couvert forestier, filtration | **A2** |
| 8 | Fertilité sol | Types sol, productivité | **F2** |
| 9 | Naturalité | Distance perturbation, continuité | **N1, N2, N3** |
| 10 | Quiz validation | - | - |

### Fonctions nemeton Utilisées

```r
# Famille Biodiversité (B)
indicator_biodiversity_protection(parcelles, zones_inpn)  # B1
indicator_biodiversity_structure(parcelles, mnh)          # B2
indicator_biodiversity_connectivity(parcelles, bd_foret)  # B3

# Famille Paysage (L)
indicator_landscape_edge(parcelles, bd_foret)             # L1
indicator_landscape_fragmentation(parcelles, bd_foret)    # L2

# Famille Temporel (T)
indicator_temporal_age(parcelles, bd_foret)               # T1
indicator_temporal_change(parcelles, t1, t2)              # T2

# Famille Air (A)
indicator_air_quality(parcelles, bd_foret)                # A2

# Famille Sol/Fertilité (F)
indicator_soil_fertility(parcelles, bd_foret, mnt)        # F2

# Famille Naturalité (N)
indicator_naturalness_continuity(parcelles, bd_foret)     # N1
indicator_naturalness_distance(parcelles, perturbations)  # N2
indicator_naturalness_composite(parcelles)                # N3
```

### Acquisition Données INPN

```r
# Téléchargement zones protégées via WFS INPN
# Pattern de cache identique aux autres données
zones_inpn_file <- file.path(data_dir, "zones_inpn.gpkg")
if (!file.exists(zones_inpn_file)) {
  # happign ou requête WFS directe
  zones_inpn <- get_wfs_data(
    url = "https://wxs.ign.fr/environnement/geoportail/wfs",
    layer = "PROTECTEDAREAS.ZNIEFF1",
    bbox = st_bbox(zone_etude)
  )
  st_write(zones_inpn, zones_inpn_file)
}
```

### Données de Sortie

```
~/nemeton_tutorial_data/
├── ... (données Tutorials 01-03)
├── zones_inpn.gpkg            # ZNIEFF, Natura 2000
└── indicateurs_ecologiques.gpkg  # Parcelles + indicateurs B, L, T, A, F, N
    └── Colonnes ajoutées: B1, B2, B3, L1, L2, T1, T2, A2, F2, N1, N2, N3
```

---

## Tutorial 05 : Calcul Complet et Normalisation

**Fichier** : `inst/tutorials/05-complete/05-complete.Rmd`
**Statut** : 🔲 À créer
**Durée estimée** : 30-40 minutes
**Prérequis** : Tutorials 01-04 complétés

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Assembler tous les indicateurs des 12 familles
2. Calculer les indicateurs manquants (C, P, E)
3. Normaliser tous les indicateurs sur l'échelle 0-100
4. Créer les indices composites par famille
5. Valider la cohérence des résultats

### Sections Prévues

| # | Section | Contenu | Résultat |
|---|---------|---------|----------|
| 1 | Assemblage indicateurs | Jointure tous indicateurs | 1 table unifiée |
| 2 | Indicateurs Carbone | C1-Biomasse (LiDAR), C2-NDVI | **C1, C2** |
| 3 | Indicateurs Production | P1-Volume, P3-Qualité | **P1, P3** |
| 4 | Indicateurs Énergie | E1-Bois-énergie, E2-Évitement | **E1, E2** |
| 5 | Normalisation 0-100 | Min-max, quantile, référence | Tous indicateurs normalisés |
| 6 | Indices de famille | Agrégation pondérée | 12 indices famille |
| 7 | Indice composite global | Combinaison 12 familles | Score global 0-100 |
| 8 | Validation cohérence | Vérification plages, corrélations | Rapport qualité |

### Fonctions nemeton Utilisées

```r
# Famille Carbone (C)
indicator_carbon_biomass(parcelles, metriques_lidar)  # C1
indicator_carbon_ndvi(parcelles, ndvi_raster)         # C2

# Famille Production (P) - compléments
indicator_productive_volume(parcelles, metriques_lidar)  # P1
indicator_productive_quality(parcelles, bd_foret)        # P3

# Famille Énergie (E)
indicator_energy_fuelwood(parcelles, metriques_lidar)    # E1
indicator_energy_avoidance(parcelles, chauffage_fossile) # E2

# Normalisation
normalize_indicators(parcelles, method = "minmax", reference = NULL)

# Indices famille
create_family_index(parcelles, family = "C", weights = c(0.6, 0.4))

# Indice composite
create_composite_index(parcelles, weights = NULL)  # Poids égaux par défaut
```

### Données de Sortie

```
~/nemeton_tutorial_data/
├── ... (données Tutorials 01-04)
└── indicateurs_complets.gpkg  # Table finale avec tous indicateurs
    └── Colonnes:
        - id_parcelle, geometry
        - C1, C2, B1, B2, B3, W1, W2, W3, A1, A2
        - F1, F2, L1, L2, T1, T2, R1, R2, R3
        - S1, S2, S3, P1, P2, P3, E1, E2, N1, N2, N3
        - C1_norm, C2_norm, ... (40+ indicateurs normalisés)
        - idx_C, idx_B, idx_W, ... (12 indices famille)
        - idx_global (indice composite)
```

---

## Tutorial 06 : Analyse Multi-Critères et Export

**Fichier** : `inst/tutorials/06-analysis/06-analysis.Rmd`
**Statut** : 🔲 À créer
**Durée estimée** : 40-50 minutes
**Prérequis** : Tutorials 01-05 complétés

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Créer des cartes thématiques pour chaque famille
2. Générer des graphiques radar 12-axes
3. Analyser les corrélations entre familles
4. Identifier les parcelles hotspots
5. Visualiser les trade-offs et synergies
6. Exporter les résultats dans différents formats

### Sections Prévues

| # | Section | Contenu | Fonction nemeton |
|---|---------|---------|------------------|
| 1 | Cartes thématiques | Une carte par famille | `plot_indicators_map()` |
| 2 | Profils radar | Graphique 12-axes par parcelle | `nemeton_radar()` |
| 3 | Matrice corrélation | Synergies et compromis | `compute_family_correlations()` |
| 4 | Hotspots | Parcelles exceptionnelles | `identify_hotspots()` |
| 5 | Trade-offs 2D | Scatterplots production vs biodiversité | `plot_tradeoff()` |
| 6 | Front Pareto | Parcelles non-dominées | `identify_pareto_optimal()` |
| 7 | Clustering | Groupes homogènes | `cluster_parcels()` |
| 8 | Export GeoPackage | Format SIG | `st_write()` |
| 9 | Export CSV | Format tableur | `write.csv()` |
| 10 | Carte interactive | Leaflet | `leaflet::leaflet()` |
| 11 | Rapport HTML | Synthèse complète | Template Rmd |

### Interprétation des Résultats

```r
# Exemple d'interprétation guidée
# 1. Identifier les parcelles à haute valeur biodiversité
hotspots_B <- identify_hotspots(parcelles, families = "B", threshold = 80)

# 2. Vérifier si ces parcelles sont aussi productives
ggplot(parcelles, aes(x = idx_P, y = idx_B)) +
  geom_point() +
  geom_point(data = hotspots_B, color = "red", size = 3) +
  labs(title = "Trade-off Production vs Biodiversité",
       subtitle = "Points rouges = hotspots biodiversité")

# 3. Identifier les parcelles win-win (bonne production ET biodiversité)
pareto <- identify_pareto_optimal(parcelles, objectives = c("idx_P", "idx_B"))
```

### Données de Sortie

```
~/nemeton_tutorial_data/
├── ... (données Tutorials 01-05)
├── exports/
│   ├── indicateurs_final.gpkg     # GeoPackage complet
│   ├── indicateurs_final.csv      # Tableau attributs
│   ├── carte_interactive.html     # Carte Leaflet
│   └── rapport_synthese.html      # Rapport complet
└── figures/
    ├── carte_idx_C.png            # Carte indice Carbone
    ├── carte_idx_B.png            # Carte indice Biodiversité
    ├── ...
    ├── radar_parcelle_1.png       # Profil radar exemple
    ├── correlation_matrix.png     # Matrice corrélation
    └── pareto_front.png           # Front de Pareto
```

---

## Tutorial 07 : Traitement LiDAR Avancé avec lidR, lasR et LAScatalog

**Fichier** : `inst/tutorials/07-lidar-advanced/07-lidar-advanced.Rmd`
**Statut** : 🔲 À créer
**Durée estimée** : 90-120 minutes
**Prérequis** : Tutorial 01 complété (données LiDAR téléchargées)

### Objectifs d'Apprentissage

À la fin de ce tutoriel, l'apprenant saura :
1. Utiliser LAScatalog pour traiter de gros jeux de données LiDAR par tuiles
2. Créer des pipelines lasR optimisés pour le traitement haute performance
3. Segmenter des arbres individuels avec lidaRtRee
4. Détecter les trouées et lisières forestières
5. Extraire des métriques de structure forestière avancées
6. Appliquer l'approche surfacique (Area-Based Approach) avec calibration
7. Générer tous les produits dérivés nécessaires aux indicateurs nemeton

### Architecture basée sur lidaRtRee

```
┌─────────────────────────────────────────────────────────────────────┐
│  Section 1: Introduction LAScatalog                                  │
│  ─────────────────────────────────────                              │
│  Concept catalogue → Options traitement → Traitement par tuiles     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 2: Pipelines lasR                                          │
│  ─────────────────────────                                          │
│  Pipeline basique → Pipeline complexe → Performance vs lidR         │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 3: Segmentation Arbres Individuels                         │
│  ──────────────────────────────────────────                         │
│  Détection cimes → Segmentation couronnes → Extraction attributs    │
│                                                                     │
│  SORTIE: arbres_segmentes.gpkg (position, hauteur, couronne)        │
│  INDICATEURS: P1, P3, C1 (niveau arbre)                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 4: Trouées et Lisières                                     │
│  ──────────────────────────────                                     │
│  Détection trouées (gaps) → Caractérisation lisières (edges)        │
│                                                                     │
│  SORTIE: gaps.gpkg, edges.gpkg                                      │
│  INDICATEURS: L1 (lisière), B2 (structure)                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 5: Métriques de Structure Forestière                       │
│  ────────────────────────────────────────────                       │
│  Métriques hauteur → Métriques densité → Métriques strates          │
│                                                                     │
│  SORTIE: metriques_structure.tif (rasters), metriques.gpkg          │
│  INDICATEURS: C1, P1, P3, A1, E1, B2                                │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 6: BABA (Buffered Area-Based Approach)                     │
│  ──────────────────────────────────────────────                     │
│  Métriques haute résolution (10m) + fenêtre 20m → Calibration       │
│  → Prédiction spatiale fine avec moving window                      │
│                                                                     │
│  SORTIE: metriques_baba.tif, modeles_calibres.rds, predictions_*.tif│
│  INDICATEURS: Volume (P1), Biomasse (C1) calibrés à 10m résolution  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 7: Coregistration Placettes Terrain                        │
│  ───────────────────────────────────────────                        │
│  Alignement MNH/placettes → Optimisation translation → Validation   │
│                                                                     │
│  SORTIE: placettes_coregistrees.gpkg                                │
│  INDICATEURS: Améliore précision tous indicateurs LiDAR             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Section 8: Produits Dérivés pour Indicateurs nemeton               │
│  ────────────────────────────────────────────────────               │
│  MNT haute résolution → Pente/Exposition → TWI → Export unifié      │
│                                                                     │
│  SORTIE: derivees_lidar.gpkg (toutes métriques pour T03-T06)        │
│  INDICATEURS: W1, R1, R2, F1 (terrain) + C1, P1, P3, A1, E1, B2    │
└─────────────────────────────────────────────────────────────────────┘
```

### Sections Détaillées

| # | Section | Contenu | Fonctions principales |
|---|---------|---------|----------------------|
| 1 | Introduction LAScatalog | Création catalogue, options, traitement tuiles | `lidR::readLAScatalog()`, `lidR::opt_*()` |
| 2 | Pipelines lasR | Pipelines optimisés, chaînage opérations | `lasR::reader_las()`, `lasR::exec_*()` |
| 3 | Segmentation arbres | Détection cimes, segmentation couronnes | `lidaRtRee::tree_segmentation()`, `lidR::segment_trees()` |
| 4 | Trouées et lisières | Détection gaps, caractérisation edges | `lidaRtRee::gap_detection()`, `lidaRtRee::edge_detection()` |
| 5 | Métriques structure | Hauteurs, densité, strates verticales | `lidaRtRee::forest_metrics()`, `lidR::pixel_metrics()` |
| 6 | BABA (Buffered Area-Based) | Préparation, calibration, prédiction haute résolution | `lasR::rasterize(c(res, window))` |
| 7 | Coregistration | Alignement placettes terrain | `lidaRtRee::coregistration()` |
| 8 | Produits dérivés | Export pour workflow nemeton | `terra::terrain()`, export functions |
| 9 | Quiz validation | Test connaissances avancées LiDAR | - |

### Packages Requis

```r
# Packages principaux
install.packages("lidR")                          # >= 4.1.1
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")  # Pipelines
remotes::install_gitlab("lidar/lidaRtRee")        # INRAE GitLab

# Packages complémentaires
install.packages(c("terra", "sf", "future"))      # Rasters, vecteurs, parallélisation
```

### Métriques Extraites pour Indicateurs nemeton

| Métrique | Source | Usage Indicateurs |
|----------|--------|-------------------|
| `P95`, `Pmean`, `Psd` | pixel_metrics | C1, P1, P3 |
| `tree_count`, `tree_height` | tree_segmentation | P1, P3, E1 |
| `gap_area`, `gap_fraction` | gap_detection | B2, L1 |
| `edge_length`, `edge_contrast` | edge_detection | L1 |
| `canopy_cover`, `LAI_proxy` | forest_metrics | A1, C1 |
| `strata_*` | stratification | B2 |
| `slope`, `aspect`, `twi` | terrain (MNT LiDAR) | W1, R1, R2, F1 |

### Données d'Entrée (depuis Tutorial 01)

```r
# Chargement depuis le cache
data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
fichiers_laz <- list.files(file.path(data_dir, "lidar_hd"),
                           pattern = "\\.laz$", full.names = TRUE)

# Création du catalogue
ctg <- readLAScatalog(fichiers_laz)
opt_output_files(ctg) <- file.path(data_dir, "processed/{XLEFT}_{YBOTTOM}")
```

### Données de Sortie

```
~/nemeton_tutorial_data/
├── ... (données Tutorials 01-06)
├── processed/                     # Tuiles traitées
│   └── *.laz
├── mnt_lidar.tif                 # MNT haute résolution (1m)
├── mnh_lidar.tif                 # MNH haute résolution (1m)
├── pente.tif                     # Pente en degrés
├── exposition.tif                # Exposition 0-360°
├── twi_lidar.tif                 # TWI depuis MNT LiDAR
├── arbres_segmentes.gpkg         # Arbres individuels
├── gaps.gpkg                     # Trouées forestières
├── edges.gpkg                    # Lisières
├── metriques_structure.tif       # Raster multi-bandes métriques
├── modeles_aba.rds               # Modèles calibrés ABA
├── predictions_volume.tif        # Carte volume prédite
├── predictions_biomasse.tif      # Carte biomasse prédite
└── derivees_lidar_nemeton.gpkg   # Métriques finales pour T05-T06
    └── Colonnes: id_parcelle, P95, Pmean, tree_count, gap_fraction,
                  canopy_cover, strata_1-4, slope, aspect, twi, ...
```

### Indicateurs nemeton Préparés

Ce tutoriel prépare les données pour :

| Indicateur | Métriques LiDAR utilisées | Section source |
|------------|--------------------------|----------------|
| **C1** (Carbone-Biomasse) | P95, canopy_cover, predictions_biomasse | §5, §6 |
| **P1** (Production-Volume) | tree_height, tree_count, predictions_volume | §3, §6 |
| **P3** (Production-Qualité) | Pmean, Psd, tree_height | §3, §5 |
| **A1** (Air-Couverture) | canopy_cover, LAI_proxy | §5 |
| **E1** (Énergie-Bois) | volume_residus (via P1) | §6 |
| **E2** (Énergie-Évitement) | via E1, P1 | §6 |
| **B2** (Biodiversité-Structure) | strata_*, zentropy, gap_fraction | §4, §5 |
| **L1** (Paysage-Lisière) | edge_length, edge_contrast | §4 |
| **W1** (Eau-TWI) | twi_lidar | §8 |
| **R1** (Risque-Feu) | slope, aspect | §8 |
| **R2** (Risque-Tempête) | aspect, elevation | §8 |
| **F1** (Sol-Érosion) | slope (facteur LS) | §8 |

### Chaîne de Dépendances avec T02

```
Tutorial 01 (Acquisition)
    │
    ├──► Tutorial 02 (LiDAR basique) ──► T03, T04, T05, T06
    │    [lidR simple, métriques de base]
    │
    └──► Tutorial 07 (LiDAR avancé) ──► T05, T06 (remplace/complète T02)
         [LAScatalog, lasR, lidaRtRee]
         [métriques avancées, calibration terrain]
```

**Note** : Tutorial 07 peut être utilisé comme alternative avancée à Tutorial 02, ou en complément pour des analyses plus poussées.

---

## Exigences Fonctionnelles

### FR-001 à FR-010 : Tutorial 01 - Acquisition
- **FR-001** : Le système DOIT permettre de créer une zone d'étude depuis des placettes
- **FR-002** : Le système DOIT télécharger les parcelles cadastrales via happign
- **FR-003** : Le système DOIT télécharger le MNT RGE Alti 5m via happign
- **FR-004** : Le système DOIT télécharger la BD Forêt et BD TOPO via WFS
- **FR-005** : Le système DOIT télécharger les dalles LiDAR HD via lidarHD
- **FR-006** : Le système DOIT persister les données dans un cache local
- **FR-007** : Le système DOIT charger les données depuis le cache si existantes
- **FR-008** : Le système DOIT utiliser EPSG:2154 (Lambert-93) pour toutes données
- **FR-009** : Le système DOIT convertir en WGS84 pour l'API STAC LiDAR
- **FR-010** : Le système DOIT fournir un quiz de validation

### FR-011 à FR-018 : Tutorial 02 - LiDAR
- **FR-011** : Le système DOIT charger des nuages de points LiDAR via lidR
- **FR-012** : Le système DOIT normaliser les hauteurs par rapport au MNT
- **FR-013** : Le système DOIT générer un MNH (Modèle Numérique de Hauteur)
- **FR-014** : Le système DOIT calculer les métriques zmax, zmean, zsd, zq95
- **FR-015** : Le système DOIT calculer pzabove2 et zentropy
- **FR-016** : Le système DOIT extraire les métriques par parcelle
- **FR-017** : Le système DOIT sauvegarder les métriques en GeoPackage
- **FR-018** : Le système DOIT fournir un quiz sur les concepts LiDAR

### FR-019 à FR-028 : Tutorial 03 - Terrain
- **FR-019** : Le système DOIT calculer pente et exposition depuis MNT
- **FR-020** : Le système DOIT calculer l'indice TWI (W1)
- **FR-021** : Le système DOIT calculer la distance au réseau hydro (W2)
- **FR-022** : Le système DOIT identifier les zones humides (W3)
- **FR-023** : Le système DOIT calculer les indicateurs de risque (R1, R2, R3)
- **FR-024** : Le système DOIT calculer l'accessibilité routes (S1)
- **FR-025** : Le système DOIT calculer la proximité bâtiments (S2)
- **FR-026** : Le système DOIT calculer la desserte sentiers (S3)
- **FR-027** : Le système DOIT calculer la fertilité station (P2)
- **FR-028** : Le système DOIT fournir un quiz de validation

### FR-029 à FR-040 : Tutorial 04 - Écologique
- **FR-029** : Le système DOIT interroger les zonages INPN (ZNIEFF, N2000)
- **FR-030** : Le système DOIT calculer le taux de protection (B1)
- **FR-031** : Le système DOIT calculer la structure verticale (B2)
- **FR-032** : Le système DOIT calculer la connectivité (B3)
- **FR-033** : Le système DOIT calculer l'effet lisière (L1)
- **FR-034** : Le système DOIT calculer la fragmentation (L2)
- **FR-035** : Le système DOIT calculer l'âge peuplement (T1)
- **FR-036** : Le système DOIT calculer la dynamique temporelle (T2)
- **FR-037** : Le système DOIT calculer la qualité air (A2)
- **FR-038** : Le système DOIT calculer la fertilité sol (F2)
- **FR-039** : Le système DOIT calculer les indicateurs naturalité (N1, N2, N3)
- **FR-040** : Le système DOIT fournir un quiz de validation

### FR-041 à FR-050 : Tutorial 05 - Calcul Complet
- **FR-041** : Le système DOIT assembler tous les indicateurs en une table
- **FR-042** : Le système DOIT calculer C1 (biomasse) depuis métriques LiDAR
- **FR-043** : Le système DOIT calculer C2 (NDVI) si données disponibles
- **FR-044** : Le système DOIT calculer P1 (volume) depuis métriques LiDAR
- **FR-045** : Le système DOIT calculer E1, E2 (énergie)
- **FR-046** : Le système DOIT normaliser tous les indicateurs 0-100
- **FR-047** : Le système DOIT créer 12 indices de famille
- **FR-048** : Le système DOIT créer un indice composite global
- **FR-049** : Le système DOIT valider la cohérence des résultats
- **FR-050** : Le système DOIT fournir un quiz de validation

### FR-051 à FR-062 : Tutorial 06 - Analyse et Export
- **FR-051** : Le système DOIT créer des cartes thématiques par famille
- **FR-052** : Le système DOIT générer des graphiques radar 12-axes
- **FR-053** : Le système DOIT calculer la matrice de corrélation
- **FR-054** : Le système DOIT identifier les parcelles hotspots
- **FR-055** : Le système DOIT créer des graphiques de trade-off
- **FR-056** : Le système DOIT identifier le front de Pareto
- **FR-057** : Le système DOIT permettre le clustering des parcelles
- **FR-058** : Le système DOIT exporter en GeoPackage
- **FR-059** : Le système DOIT exporter en CSV
- **FR-060** : Le système DOIT créer une carte interactive Leaflet
- **FR-061** : Le système DOIT générer un rapport HTML de synthèse
- **FR-062** : Le système DOIT fournir un quiz final de validation

### FR-063 à FR-078 : Tutorial 07 - LiDAR Avancé
- **FR-063** : Le système DOIT créer un LAScatalog depuis plusieurs fichiers LiDAR
- **FR-064** : Le système DOIT configurer les options de traitement par tuiles (chunk)
- **FR-065** : Le système DOIT créer des pipelines lasR pour traitement optimisé
- **FR-066** : Le système DOIT détecter les cimes d'arbres individuels
- **FR-067** : Le système DOIT segmenter les couronnes d'arbres via lidaRtRee
- **FR-068** : Le système DOIT extraire les attributs par arbre (hauteur, position, surface couronne)
- **FR-069** : Le système DOIT détecter les trouées forestières (gaps)
- **FR-070** : Le système DOIT caractériser les lisières (edges)
- **FR-071** : Le système DOIT calculer les métriques de structure par strates verticales
- **FR-072** : Le système DOIT implémenter l'approche surfacique (ABA) avec calibration
- **FR-073** : Le système DOIT coregistrer les placettes terrain avec le MNH
- **FR-074** : Le système DOIT générer un MNT haute résolution depuis LiDAR sol
- **FR-075** : Le système DOIT calculer pente, exposition et TWI depuis MNT LiDAR
- **FR-076** : Le système DOIT prédire volume et biomasse spatialement
- **FR-077** : Le système DOIT exporter les métriques au format compatible T05-T06
- **FR-078** : Le système DOIT fournir un quiz sur les concepts LiDAR avancés

---

## Critères de Succès

### Mesurables

- **SC-001** : Un apprenant peut compléter le Tutorial 01 en moins de 45 minutes
- **SC-002** : Un apprenant peut compléter la série complète (01-06) en moins de 4 heures
- **SC-003** : 90% des apprenants réussissent les quiz avec score > 70%
- **SC-004** : Le cache local réduit le temps de rechargement à < 10 secondes
- **SC-005** : Les 40+ indicateurs sont calculés pour toutes les parcelles
- **SC-006** : Les exports GeoPackage sont compatibles QGIS/ArcGIS
- **SC-007** : Le rapport HTML se génère en moins de 30 secondes
- **SC-011** : Un apprenant peut compléter le Tutorial 07 en moins de 2 heures
- **SC-012** : Le traitement LAScatalog supporte > 10 tuiles LiDAR simultanément
- **SC-013** : La segmentation détecte > 80% des arbres dominants (validé terrain)
- **SC-014** : Les modèles ABA atteignent R² > 0.7 pour volume/biomasse

### Qualitatifs

- **SC-008** : Les apprenants comprennent le concept des 12 familles d'indicateurs
- **SC-009** : Les apprenants peuvent appliquer le workflow à leur propre zone d'étude
- **SC-010** : Les explications sont accessibles aux non-spécialistes
- **SC-015** : Les apprenants maîtrisent la différence entre lidR, lasR et lidaRtRee
- **SC-016** : Les apprenants comprennent l'approche surfacique (ABA) et ses limites

---

## Hypothèses

### Techniques
- R >= 4.1.0 installé avec environnement de développement
- Connexion internet pour téléchargement initial des données
- 4 GB RAM minimum pour traitement LiDAR basique (T02)
- **8 GB RAM minimum pour traitement LiDAR avancé (T07)**
- 2 GB espace disque pour cache données (T01-T06)
- **5 GB espace disque supplémentaire pour T07** (tuiles, produits dérivés)

### Packages spécifiques Tutorial 07
- lidR >= 4.1.1 (CRAN)
- lasR (r-universe uniquement, pas sur CRAN)
- lidaRtRee >= 4.0.9 (INRAE GitLab forge)
- future (pour parallélisation LAScatalog)

### Données
- Zone d'étude (Vercors - Quatre Montagnes) représentative
- LiDAR HD disponible pour la zone (10+ points/m²)
- APIs IGN (happign) et INPN fonctionnelles
- **Placettes terrain avec mesures dendrométriques** (pour calibration ABA dans T07)

### Utilisateurs
- Connaissances de base en R et SIG
- Compréhension des concepts forestiers de base
- Motivation pour 4 heures d'apprentissage (T01-T06)
- **Motivation pour 2 heures supplémentaires (T07)**
- **Connaissances intermédiaires en R** pour T07 (fonctions, boucles)

---

## Hors Scope (v0.4.1)

- Traduction anglaise des tutoriels
- Dashboard Shiny autonome
- Intégration Google Earth Engine
- Support multi-langue
- Optimisation > 1000 parcelles
- Plugins QGIS/ArcGIS
- **Deep learning pour segmentation arbres** (T07 utilise méthodes classiques)
