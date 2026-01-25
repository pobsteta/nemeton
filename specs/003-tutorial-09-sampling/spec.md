# Spécification: Tutorial 09 - Échantillonnage de calibration LiDAR HD + TSP

**Version**: 1.0.0
**Date**: 2026-01-23
**Statut**: Draft
**Durée estimée**: 3h00 (180 minutes)

## Résumé

Tutorial interactif learnr pour concevoir un plan d'échantillonnage optimal de placettes de calibration LiDAR HD et calculer le parcours terrain le plus efficace (problème du voyageur de commerce - TSP). Ce tutoriel couvre l'ensemble du workflow depuis la construction d'une "sampling frame" jusqu'à l'export GPX pour la navigation terrain.

## Objectifs pédagogiques

À la fin de ce tutoriel, l'apprenant sera capable de :

1. Construire une "sampling frame" de centres de placettes candidats
2. Appliquer des contraintes terrain (pente, couverture forestière, accessibilité)
3. Extraire des variables auxiliaires LiDAR et topographiques
4. Stratifier la zone d'étude selon des gradients structurels
5. Réaliser un tirage GRTS spatialement équilibré
6. Diagnostiquer la représentativité de l'échantillon
7. Construire un réseau de chemins depuis OSM
8. Résoudre le problème TSP pour optimiser le parcours terrain
9. Exporter les résultats en GeoPackage et GPX

## Prérequis

- Tutorial 01 (Acquisition) - pattern cache, téléchargement données
- Tutorial 02 (LiDAR) - manipulation nuages de points, dérivées
- Tutorial 03 (Terrain) - MNT, pente, TWI, TPI
- Tutorial 07 (LiDAR avancé) - lasR, traitement grandes surfaces

## Contexte métier

### Objectif final

Calibrer des modèles LiDAR pour estimer les caractéristiques forestières :
- Nombre de tiges par hectare (N/ha)
- Surface terrière (G en m²/ha)
- Composition / essence dominante

### Contraintes terrain

- **Rayon placettes** : 15 m (surface ≈ 706.9 m²)
- **Zone d'étude** : ~100 ha
- **Échantillon cible** : 40 placettes principales + 12 remplacements (30%)

## Données d'entrée

### Obligatoires

| Donnée | Format | Description |
|--------|--------|-------------|
| Zone d'étude | sf POLYGON | Limite de la zone (GeoPackage) |
| BD Forêt v2 | sf POLYGON | Types peuplements, essences |
| Dérivées LiDAR | terra SpatRaster | MNH (mean, p95, sd, CV, cover) |
| Dérivées DTM | terra SpatRaster | Pente, exposition, TWI, TPI, altitude |

### Optionnelles

| Donnée | Format | Description |
|--------|--------|-------------|
| Réseau chemins | sf LINESTRING | Chemins/pistes OSM topo |
| Extrait OSM | .pbf | Alternative pour chemins |

## Structure du tutoriel

### Section 1 : Introduction et configuration (15 min)

#### 1.1 Contexte de l'échantillonnage de calibration
- Pourquoi calibrer les modèles LiDAR ?
- Représentativité vs accessibilité
- Compromis taille échantillon / coût terrain

#### 1.2 Configuration de l'environnement

```r
# Configuration par défaut
config <- list(
  # Placettes
  plot_radius = 15,           # m
  grid_step = 20,             # m (génération candidats)

  # Contraintes
  min_forest_cover = 0.95,    # 95% couvert forestier
  max_slope = 60,             # % pente maximale
  max_distance_path = NULL,   # m (optionnel)

  # Échantillonnage
  n_main = 40,                # placettes principales
  n_replacement = 12,         # remplacements (30%)
  min_per_stratum = 2,        # minimum par strate

  # TSP
  walk_speed_kmh = 2,         # km/h hors chemin
  offpath_penalty = 3,        # multiplicateur temps hors-chemin

  # CRS
  crs = 2154,                 # Lambert 93

  # Seed

  seed = 2024
)
```

#### Quiz 1 : Concepts d'échantillonnage (3 questions)

---

### Section 2 : Chargement et préparation des données (20 min)

#### 2.1 Chargement zone d'étude et BD Forêt

```r
# Zone d'étude
study_area <- st_read("zone_etude.gpkg")

# BD Forêt v2
bd_foret <- st_read("bd_foret_v2.gpkg") |>
  st_transform(config$crs)
```

#### 2.2 Chargement des dérivées LiDAR

```r
# Stack des métriques LiDAR
lidar_stack <- rast(c(
  "mnh_mean.tif",
  "mnh_p95.tif",
  "mnh_sd.tif",
  "mnh_cv.tif",
  "canopy_cover.tif"
))

# Stack topographique
topo_stack <- rast(c(
  "slope.tif",
  "aspect.tif",
  "twi.tif",
  "tpi.tif",
  "altitude.tif"
))
```

#### 2.3 Visualisation exploratoire

#### Exercice 2.1 : Vérifier les CRS et emprises

---

### Section 3 : Construction de la sampling frame (30 min)

#### 3.1 Génération de la grille de candidats

```r
# Grille régulière de points candidats
candidates <- st_make_grid(
  study_area,
  cellsize = config$grid_step,
  what = "centers"
) |>
  st_as_sf() |>
  st_filter(study_area)
```

#### 3.2 Application des contraintes terrain

```r
# Fonction de validation d'un candidat
validate_candidate <- function(point, plot_radius, bd_foret, slope_raster,
                                min_forest_cover, max_slope) {
  # Buffer de la placette

  buffer <- st_buffer(point, plot_radius)


  # Contrainte 1 : Couverture forestière >= 95%
  forest_cover <- calculate_forest_cover(buffer, bd_foret)

  # Contrainte 2 : Pente moyenne <= 60%
  mean_slope <- exact_extract(slope_raster, buffer, "mean")

  # Validation
  valid <- forest_cover >= min_forest_cover & mean_slope <= max_slope

  return(list(
    valid = valid,
    forest_cover = forest_cover,
    mean_slope = mean_slope
  ))
}
```

#### 3.3 Extraction des variables auxiliaires

Variables extraites sur le buffer 15m (pas au pixel central) :

**LiDAR** :
- `mnh_mean`, `mnh_p95`, `mnh_sd`, `mnh_cv`
- `canopy_cover`

**Topographie** :
- `slope_mean`
- `aspect_sin`, `aspect_cos` (codage circulaire)
- `twi_mean`, `tpi_mean`
- `altitude_mean`

**BD Forêt** :
- `forest_type_dominant` (classe majoritaire)
- `forest_type_proportions` (proportions par classe)

#### Exercice 3.1 : Implémenter l'extraction des variables

#### Quiz 3 : Sampling frame (3 questions)

---

### Section 4 : Stratification et tirage GRTS (35 min)

#### 4.1 Définition des strates

Stratification par défaut (16 strates) :

| Variable | Classes | Seuils |
|----------|---------|--------|
| MNH_p95 (hauteur) | 4 | Quartiles |
| Canopy cover | 2 | Médiane |
| Pente | 2 | Médiane |

```r
# Création des strates
frame <- frame |>
  mutate(
    strat_height = cut(mnh_p95, breaks = quantile(mnh_p95, probs = 0:4/4),
                       labels = c("H1", "H2", "H3", "H4"), include.lowest = TRUE),
    strat_cover = ifelse(canopy_cover >= median(canopy_cover), "C_high", "C_low"),
    strat_slope = ifelse(slope_mean >= median(slope_mean), "S_high", "S_low"),
    stratum = paste(strat_height, strat_cover, strat_slope, sep = "_")
  )
```

#### 4.2 Allocation proportionnelle

```r
# Calcul de l'allocation par strate
allocation <- frame |>
  st_drop_geometry() |>
  group_by(stratum) |>
  summarise(n_candidates = n()) |>
  mutate(
    proportion = n_candidates / sum(n_candidates),
    n_allocated = pmax(config$min_per_stratum,
                       round(proportion * config$n_main))
  )
```

#### 4.3 Tirage GRTS avec spsurvey

```r
library(spsurvey)

# Tirage GRTS stratifié
sample_grts <- grts(
  sframe = frame,
  n_base = allocation$n_allocated,
  stratum_var = "stratum",
  n_over = config$n_replacement,
  seltype = "proportional"
)
```

#### 4.4 Placettes de remplacement (oversample)

#### Exercice 4.1 : Réaliser le tirage GRTS

---

### Section 5 : Diagnostics de l'échantillon (25 min)

#### 5.1 Comparaison des distributions

```r
# Comparaison frame vs échantillon
compare_distributions <- function(frame, sample, variables) {
  plots <- map(variables, function(var) {
    bind_rows(
      frame |> mutate(source = "Frame"),
      sample |> mutate(source = "Échantillon")
    ) |>
      ggplot(aes(x = .data[[var]], fill = source)) +
      geom_density(alpha = 0.5) +
      labs(title = var)
  })
  wrap_plots(plots)
}
```

#### 5.2 Couverture de l'espace PCA

```r
# ACP sur les variables auxiliaires
pca_diagnostic <- function(frame, sample, variables) {
  # PCA sur la frame
  pca <- prcomp(frame |> st_drop_geometry() |> select(all_of(variables)),
                scale. = TRUE)

  # Projection de l'échantillon
  # Visualisation PC1 vs PC2
}
```

#### 5.3 Distances inter-placettes

#### 5.4 Représentation des types forestiers

#### Exercice 5.1 : Interpréter les diagnostics

#### Quiz 5 : Diagnostics (3 questions)

---

### Section 6 : Construction du réseau de chemins (20 min)

#### 6.1 Chargement des chemins OSM

```r
library(osmdata)

# Téléchargement des chemins depuis OSM
paths <- opq(bbox = st_bbox(study_area)) |>
  add_osm_feature(key = "highway",
                  value = c("track", "path", "footway", "cycleway")) |>
  osmdata_sf()

paths_lines <- paths$osm_lines |>
  st_transform(config$crs)
```

#### 6.2 Construction du réseau avec sfnetworks

```r
library(sfnetworks)
library(tidygraph)

# Créer le réseau
network <- as_sfnetwork(paths_lines, directed = FALSE) |>
  activate("edges") |>
  mutate(weight = edge_length())
```

#### 6.3 Snap des placettes au réseau

```r
# Point d'accès le plus proche pour chaque placette
sample <- sample |>
  mutate(
    nearest_path_point = st_nearest_points(geometry, paths_lines),
    distance_to_path = st_length(nearest_path_point)
  )
```

#### Exercice 6.1 : Construire le réseau de chemins

---

### Section 7 : Optimisation du parcours TSP (25 min)

#### 7.1 Matrice de coûts

```r
library(TSP)

# Matrice de distances/temps sur le réseau
cost_matrix <- calculate_cost_matrix(
  points = sample,
  network = network,
  walk_speed = config$walk_speed_kmh,
  offpath_penalty = config$offpath_penalty
)
```

#### 7.2 Résolution TSP

```r
# Créer l'objet TSP
tsp <- TSP(cost_matrix)

# Résoudre (plusieurs méthodes disponibles)
tour <- solve_TSP(tsp, method = "nearest_insertion")

# Extraire l'ordre de visite
visit_order <- as.integer(tour)
```

#### 7.3 Visualisation du parcours

```r
# Carte du parcours optimisé
plot_tour <- function(sample, tour, network) {
  sample_ordered <- sample[tour, ] |>
    mutate(visit_order = row_number())

  ggplot() +
    geom_sf(data = study_area, fill = "lightgreen", alpha = 0.3) +
    geom_sf(data = paths_lines, color = "brown", alpha = 0.5) +
    geom_sf(data = sample_ordered, aes(color = visit_order), size = 3) +
    geom_path(data = st_coordinates(sample_ordered) |> as.data.frame(),
              aes(X, Y), linetype = "dashed") +
    scale_color_viridis_c() +
    labs(title = "Parcours TSP optimisé")
}
```

#### Exercice 7.1 : Résoudre le TSP

#### Quiz 7 : Optimisation TSP (3 questions)

---

### Section 8 : Export et synthèse (10 min)

#### 8.1 Export GeoPackage

```r
# Créer le répertoire de sortie
dir.create("result_inventaire", showWarnings = FALSE)

# Export frame candidats
st_write(frame, "result_inventaire/frame_candidats.gpkg", delete_layer = TRUE)

# Export échantillon avec ordre de visite
st_write(sample_with_order, "result_inventaire/placettes_echantillon.gpkg",
         delete_layer = TRUE)

# Export route TSP
st_write(route_tsp, "result_inventaire/route_tsp.gpkg", delete_layer = TRUE)
```

#### 8.2 Export GPX pour navigation terrain

```r
# Conversion et export GPX
sample_wgs84 <- sample_with_order |>
  st_transform(4326) |>
  select(id, visit_order, stratum, replacement)

st_write(sample_wgs84, "result_inventaire/route_tsp.gpx",
         driver = "GPX", delete_dsn = TRUE)
```

#### 8.3 Rapport de synthèse

```r
# Générer le rapport
report <- generate_sampling_report(
  frame = frame,
  sample = sample_with_order,
  tour = tour,
  config = config
)

cat(report)
```

---

## Livrables

| Fichier | Description |
|---------|-------------|
| `result_inventaire/frame_candidats.gpkg` | Centres candidats + buffers + variables |
| `result_inventaire/placettes_echantillon.gpkg` | Placettes principales + remplacements |
| `result_inventaire/route_tsp.gpkg` | Ordre de visite, points snappés, lignes |
| `result_inventaire/route_tsp.gpx` | Export GPX pour GPS terrain |
| `result_inventaire/diagnostics/` | Graphiques de diagnostic |

## Stack technique

### Packages obligatoires

| Package | Usage |
|---------|-------|
| sf | Manipulation vecteurs |
| terra | Manipulation rasters |
| exactextractr | Statistiques zonales |
| spsurvey | Tirage GRTS |
| sfnetworks | Réseau de chemins |
| TSP | Optimisation parcours |
| ggplot2 | Visualisation |

### Packages optionnels

| Package | Usage |
|---------|-------|
| BalancedSampling | Cube sampling |
| SamplingStrata | Stratification optimale |
| osmdata | Téléchargement OSM |
| dodgr | Routage alternatif |

## Critères d'acceptation

- [ ] Pipeline reproductible (set.seed, config)
- [ ] 40 placettes principales + 12 remplacements générés
- [ ] Toutes les contraintes terrain vérifiées (forêt ≥95%, pente ≤60%)
- [ ] Diagnostics produits automatiquement
- [ ] TSP résolu avec ordre de visite explicite
- [ ] Exports dans /result_inventaire avec nomenclature claire
- [ ] Tous les quiz et exercices fonctionnels

## Hors périmètre

- Calcul de plus court chemin raster hors-chemin (coûteux)
- Interface web (scripts uniquement)
- Téléchargement automatique des données LiDAR (données fournies)

## Notes d'implémentation

1. Forcer CRS projeté (EPSG:2154) dès l'entrée
2. Éviter conversion massive raster → data.frame
3. Prioriser exactextractr pour statistiques zonales
4. Gérer erreurs (couches manquantes, CRS incohérents)
5. Documenter chaque étape pour audit scientifique
