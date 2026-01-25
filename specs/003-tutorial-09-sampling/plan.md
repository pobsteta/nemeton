# Plan d'implémentation: Tutorial 09 - Échantillonnage LiDAR + TSP

**Version**: 1.0.0
**Date**: 2026-01-23

## Vue d'ensemble

### Phases d'implémentation

| Phase | Description | Durée estimée |
|-------|-------------|---------------|
| 1 | Préparation des données démo | 2h |
| 2 | Structure du tutoriel learnr | 1h |
| 3 | Sections 1-2 (Introduction, Chargement) | 2h |
| 4 | Section 3 (Sampling frame) | 3h |
| 5 | Section 4 (Stratification, GRTS) | 3h |
| 6 | Section 5 (Diagnostics) | 2h |
| 7 | Section 6 (Réseau chemins) | 2h |
| 8 | Section 7 (TSP) | 2h |
| 9 | Section 8 (Export, synthèse) | 1h |
| 10 | Tests et validation | 2h |

**Total estimé** : 20h

---

## Phase 1 : Préparation des données démo

### 1.1 Zone d'étude

Créer une zone d'étude synthétique d'environ 100 ha :
- Polygone simple (rectangle ou forme naturelle)
- CRS : EPSG:2154 (Lambert 93)
- Localisation : Massif forestier existant (données nemeton)

### 1.2 BD Forêt v2 simplifiée

Générer ou extraire des polygones forestiers :
- 3-5 types de peuplements (feuillus, résineux, mixtes)
- Attributs : CODE_TFV, TFV, ESSENCE
- Couverture ~90% de la zone d'étude

### 1.3 Dérivées LiDAR

Stack raster (résolution 1m ou 2m) :

```
inst/extdata/tutorial09/
├── study_area.gpkg
├── bd_foret_v2.gpkg
├── lidar/
│   ├── mnh_mean.tif
│   ├── mnh_p95.tif
│   ├── mnh_sd.tif
│   ├── mnh_cv.tif
│   └── canopy_cover.tif
├── topo/
│   ├── slope.tif
│   ├── aspect.tif
│   ├── twi.tif
│   ├── tpi.tif
│   └── altitude.tif
└── osm/
    └── paths.gpkg
```

### 1.4 Réseau de chemins

Extraire ou générer un réseau de chemins :
- ~5-10 km de chemins traversant la zone
- Types : track, path, footway
- Format sf LINESTRING

### 1.5 Script de génération

```r
# data-raw/generate_tutorial09_data.R
# Génère toutes les données pour le tutoriel 09
```

---

## Phase 2 : Structure du tutoriel learnr

### 2.1 Fichier principal

```
inst/tutorials/09-sampling/
├── 09-sampling.Rmd
├── css/
│   └── custom.css
└── images/
    └── (diagrammes)
```

### 2.2 Header YAML

```yaml
---
title: "Tutorial 09 : Échantillonnage de calibration LiDAR HD + TSP"
output:
  learnr::tutorial:
    progressive: true
    allow_skip: true
    language: fr
    css: css/custom.css
runtime: shiny_prerendered
description: "Concevoir un plan d'échantillonnage optimal et calculer le parcours terrain"
---
```

### 2.3 Setup chunk

```r
library(learnr)
library(sf)
library(terra)
library(exactextractr)
library(spsurvey)
library(sfnetworks)
library(TSP)
library(ggplot2)
library(dplyr)
library(purrr)

knitr::opts_chunk$set(
 echo = TRUE,
 warning = FALSE,
 message = FALSE,
 exercise.timelimit = 300
)

# Charger les données
data_dir <- system.file("extdata", "tutorial09", package = "nemeton")
```

---

## Phase 3 : Sections 1-2 (Introduction, Chargement)

### 3.1 Section 1 : Introduction (15 min)

#### Contenu pédagogique

- Schéma conceptuel du workflow
- Compromis représentativité vs accessibilité
- Présentation de la configuration

#### Quiz 1 (3 questions)

1. Pourquoi échantillonner pour calibrer les modèles LiDAR ?
2. Qu'est-ce qu'un tirage GRTS ?
3. Quel est l'intérêt des placettes de remplacement ?

### 3.2 Section 2 : Chargement données (20 min)

#### Exercices

- E2.1 : Charger et vérifier les CRS
- E2.2 : Visualiser la zone d'étude avec BD Forêt
- E2.3 : Explorer le stack raster

---

## Phase 4 : Section 3 (Sampling frame)

### 4.1 Génération grille candidats

```r
generate_candidate_grid <- function(study_area, grid_step = 20) {
  st_make_grid(study_area, cellsize = grid_step, what = "centers") |>
    st_as_sf() |>
    st_filter(study_area) |>
    mutate(candidate_id = row_number())
}
```

### 4.2 Fonction de validation

```r
validate_candidates <- function(candidates, plot_radius, bd_foret,
                                 slope_raster, min_forest_cover, max_slope) {
  # Créer les buffers
  buffers <- st_buffer(candidates, plot_radius)

  # Calcul couverture forestière (vectoriel)
  forest_cover <- calculate_forest_coverage(buffers, bd_foret)

  # Calcul pente moyenne (raster)
  mean_slope <- exact_extract(slope_raster, buffers, "mean")

  # Filtrer les candidats valides
  candidates |>
    mutate(
      forest_cover = forest_cover,
      mean_slope = mean_slope,
      valid = forest_cover >= min_forest_cover & mean_slope <= max_slope
    ) |>
    filter(valid)
}
```

### 4.3 Extraction variables auxiliaires

```r
extract_auxiliary_variables <- function(candidates, plot_radius,
                                         lidar_stack, topo_stack, bd_foret) {
  buffers <- st_buffer(candidates, plot_radius)

  # Variables LiDAR
  lidar_vars <- exact_extract(lidar_stack, buffers, "mean")

  # Variables topo
  topo_vars <- exact_extract(topo_stack, buffers, "mean")

  # Codage aspect circulaire
  aspect_rad <- topo_vars$aspect * pi / 180
  topo_vars$aspect_sin <- sin(aspect_rad)
  topo_vars$aspect_cos <- cos(aspect_rad)

  # Variables BD Forêt (mode)
  forest_type <- extract_dominant_forest_type(buffers, bd_foret)

  # Assembler
  bind_cols(candidates, lidar_vars, topo_vars, forest_type)
}
```

### 4.4 Exercices Section 3

- E3.1 : Générer la grille de candidats
- E3.2 : Appliquer les contraintes
- E3.3 : Extraire les variables auxiliaires

---

## Phase 5 : Section 4 (Stratification, GRTS)

### 5.1 Création des strates

```r
create_strata <- function(frame, height_var = "mnh_p95",
                           cover_var = "canopy_cover",
                           slope_var = "slope_mean") {
  frame |>
    mutate(
      strat_height = cut(.data[[height_var]],
                         breaks = quantile(.data[[height_var]], probs = 0:4/4, na.rm = TRUE),
                         labels = c("H1", "H2", "H3", "H4"),
                         include.lowest = TRUE),
      strat_cover = ifelse(.data[[cover_var]] >= median(.data[[cover_var]], na.rm = TRUE),
                           "C_high", "C_low"),
      strat_slope = ifelse(.data[[slope_var]] >= median(.data[[slope_var]], na.rm = TRUE),
                           "S_high", "S_low"),
      stratum = paste(strat_height, strat_cover, strat_slope, sep = "_")
    )
}
```

### 5.2 Tirage GRTS

```r
perform_grts_sampling <- function(frame, n_main, n_replacement,
                                   min_per_stratum = 2) {
  # Calcul allocation
  allocation <- frame |>
    st_drop_geometry() |>
    count(stratum) |>
    mutate(
      proportion = n / sum(n),
      n_allocated = pmax(min_per_stratum, round(proportion * n_main))
    )

  # Ajuster pour atteindre n_main exact
  allocation <- adjust_allocation(allocation, n_main)

  # Tirage GRTS
  sample <- grts(
    sframe = frame,
    n_base = setNames(allocation$n_allocated, allocation$stratum),
    stratum_var = "stratum",
    n_over = n_replacement
  )

  sample$sites_base |>
    mutate(replacement = FALSE) |>
    bind_rows(
      sample$sites_over |> mutate(replacement = TRUE)
    )
}
```

### 5.3 Exercices Section 4

- E4.1 : Créer les strates
- E4.2 : Calculer l'allocation
- E4.3 : Réaliser le tirage GRTS

---

## Phase 6 : Section 5 (Diagnostics)

### 6.1 Comparaison distributions

```r
plot_distribution_comparison <- function(frame, sample, variables) {
  data_long <- bind_rows(
    frame |> st_drop_geometry() |> mutate(source = "Frame"),
    sample |> st_drop_geometry() |> mutate(source = "Échantillon")
  ) |>
    pivot_longer(cols = all_of(variables), names_to = "variable", values_to = "value")

  ggplot(data_long, aes(x = value, fill = source)) +
    geom_density(alpha = 0.5) +
    facet_wrap(~variable, scales = "free") +
    theme_minimal() +
    labs(title = "Comparaison des distributions")
}
```

### 6.2 Couverture espace PCA

```r
plot_pca_coverage <- function(frame, sample, variables) {
  # PCA sur frame
  pca_data <- frame |> st_drop_geometry() |> select(all_of(variables))
  pca <- prcomp(pca_data, scale. = TRUE)

  # Projections
  frame_pca <- as.data.frame(predict(pca, pca_data)) |>
    mutate(source = "Frame")

  sample_pca <- as.data.frame(predict(pca, sample |> st_drop_geometry() |>
                                        select(all_of(variables)))) |>
    mutate(source = "Échantillon")

  # Plot
  ggplot() +
    geom_point(data = frame_pca, aes(PC1, PC2), alpha = 0.1, color = "gray") +
    geom_point(data = sample_pca, aes(PC1, PC2), color = "red", size = 2) +
    theme_minimal() +
    labs(title = "Couverture de l'espace PCA")
}
```

### 6.3 Distances inter-placettes

### 6.4 Représentation types forestiers

---

## Phase 7 : Section 6 (Réseau chemins)

### 7.1 Chargement OSM

```r
load_osm_paths <- function(study_area, crs = 2154) {
  # Option 1 : Fichier local
  paths_file <- system.file("extdata", "tutorial09", "osm", "paths.gpkg",
                            package = "nemeton")
  if (file.exists(paths_file)) {
    return(st_read(paths_file) |> st_transform(crs))
  }

  # Option 2 : Téléchargement OSM
  if (requireNamespace("osmdata", quietly = TRUE)) {
    paths <- osmdata::opq(bbox = st_bbox(study_area |> st_transform(4326))) |>
      osmdata::add_osm_feature(key = "highway",
                               value = c("track", "path", "footway")) |>
      osmdata::osmdata_sf()
    return(paths$osm_lines |> st_transform(crs))
  }

  stop("Aucune donnée de chemins disponible")
}
```

### 7.2 Construction réseau sfnetworks

```r
build_path_network <- function(paths) {
  network <- as_sfnetwork(paths, directed = FALSE) |>
    activate("edges") |>
    mutate(
      length_m = as.numeric(edge_length()),
      weight = length_m
    )

  # Simplifier le réseau (optionnel)
  network |>
    convert(to_spatial_smooth)
}
```

### 7.3 Snap placettes au réseau

```r
snap_to_network <- function(sample, network) {
  # Extraire les nœuds du réseau
  nodes <- network |>
    activate("nodes") |>
    st_as_sf()

  # Trouver le nœud le plus proche pour chaque placette
  nearest <- st_nearest_feature(sample, nodes)

  sample |>
    mutate(
      snap_node_id = nearest,
      snap_point = nodes$geometry[nearest],
      distance_to_path = as.numeric(st_distance(geometry, snap_point, by_element = TRUE))
    )
}
```

---

## Phase 8 : Section 7 (TSP)

### 8.1 Matrice de coûts

```r
calculate_cost_matrix <- function(sample, network, walk_speed_kmh = 2,
                                   offpath_penalty = 3) {
  n <- nrow(sample)
  cost_matrix <- matrix(0, n, n)

  for (i in 1:(n-1)) {
    for (j in (i+1):n) {
      # Distance sur le réseau
      network_dist <- calculate_network_distance(sample$snap_node_id[i],
                                                  sample$snap_node_id[j],
                                                  network)

      # Pénalité hors-chemin (aller + retour)
      offpath_dist <- sample$distance_to_path[i] + sample$distance_to_path[j]

      # Coût total (en minutes)
      cost <- (network_dist / 1000 / walk_speed_kmh +
               offpath_dist / 1000 / walk_speed_kmh * offpath_penalty) * 60

      cost_matrix[i, j] <- cost
      cost_matrix[j, i] <- cost
    }
  }

  cost_matrix
}
```

### 8.2 Résolution TSP

```r
solve_tour <- function(cost_matrix, method = "nearest_insertion") {
  tsp <- TSP(cost_matrix)
  tour <- solve_TSP(tsp, method = method)

  list(
    tour = tour,
    order = as.integer(tour),
    total_cost = tour_length(tour)
  )
}
```

### 8.3 Visualisation parcours

```r
plot_tour <- function(sample, tour_order, paths, study_area) {
  sample_ordered <- sample[tour_order, ] |>
    mutate(visit_order = row_number())

  # Lignes de connexion (simplifiées)
  coords <- st_coordinates(sample_ordered)
  connections <- data.frame(
    x = coords[-nrow(coords), 1],
    y = coords[-nrow(coords), 2],
    xend = coords[-1, 1],
    yend = coords[-1, 2]
  )

  ggplot() +
    geom_sf(data = study_area, fill = "lightgreen", alpha = 0.3) +
    geom_sf(data = paths, color = "brown", alpha = 0.5) +
    geom_segment(data = connections, aes(x = x, y = y, xend = xend, yend = yend),
                 linetype = "dashed", color = "blue", alpha = 0.7) +
    geom_sf(data = sample_ordered, aes(color = visit_order), size = 3) +
    geom_sf_label(data = sample_ordered, aes(label = visit_order), size = 2) +
    scale_color_viridis_c() +
    theme_minimal() +
    labs(title = "Parcours TSP optimisé",
         subtitle = paste("Temps total estimé:", round(tour_result$total_cost, 0), "min"))
}
```

---

## Phase 9 : Section 8 (Export, synthèse)

### 9.1 Export GeoPackage

### 9.2 Export GPX

### 9.3 Génération rapport

```r
generate_sampling_report <- function(frame, sample, tour, config) {
  glue::glue("
  ═══════════════════════════════════════════════════════════
  RAPPORT D'ÉCHANTILLONNAGE - Tutorial 09
  ═══════════════════════════════════════════════════════════

  1. SAMPLING FRAME
  ─────────────────
  Candidats générés : {nrow(frame)}
  Candidats valides : {sum(frame$valid)}
  Grille : {config$grid_step} m
  Rayon placette : {config$plot_radius} m

  2. CONTRAINTES
  ──────────────

  Couvert forestier min : {config$min_forest_cover * 100}%
  Pente max : {config$max_slope}%

  3. ÉCHANTILLON
  ──────────────
  Placettes principales : {sum(!sample$replacement)}
  Placettes remplacement : {sum(sample$replacement)}
  Strates représentées : {n_distinct(sample$stratum)}

  4. PARCOURS TSP
  ───────────────
  Temps total estimé : {round(tour$total_cost, 0)} minutes
  Distance totale : {round(tour$total_distance / 1000, 1)} km

  ═══════════════════════════════════════════════════════════
  ")
}
```

---

## Phase 10 : Tests et validation

### 10.1 Tests unitaires

- Validation génération grille
- Validation contraintes terrain
- Validation tirage GRTS
- Validation résolution TSP

### 10.2 Tests d'intégration

- Pipeline complet avec données démo
- Reproductibilité (même seed = même résultat)
- Export fichiers

### 10.3 Validation pédagogique

- Tous les exercices ont une solution
- Tous les quiz ont des réponses correctes
- Le tutoriel s'exécute sans erreur

---

## Dépendances

### Packages à ajouter dans DESCRIPTION (Suggests)

```
spsurvey,
sfnetworks,
TSP,
osmdata,
tidygraph,
BalancedSampling
```

### Vérification disponibilité

```r
check_tutorial09_deps <- function() {
  required <- c("sf", "terra", "exactextractr", "spsurvey",
                "sfnetworks", "TSP", "ggplot2")
  missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    stop("Packages manquants: ", paste(missing, collapse = ", "))
  }

  TRUE
}
```

---

## Risques et mitigation

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| spsurvey API change | Moyen | Faible | Vérifier compatibilité, fallback BalancedSampling |
| Données OSM indisponibles | Faible | Moyen | Fournir données locales préchargées |
| TSP lent sur gros échantillon | Faible | Faible | Limiter à 52 placettes (40+12) |
| sfnetworks complexe | Moyen | Moyen | Simplifier le réseau, documentation |
