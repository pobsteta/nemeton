# Spécification: Tutorial 10 - Classification d'Essences au Niveau Couronne

**Version**: 1.0.0
**Date**: 2026-01-24
**Statut**: Draft
**Durée estimée**: 3h30 (210 minutes)

## Résumé

Tutorial interactif learnr pour réaliser une classification supervisée d'essences forestières au niveau couronne individuelle, en fusionnant des features LiDAR HD (~10 pts/m²) et des indices spectraux IRC (orthophotos IGN). Ce tutoriel couvre l'ensemble du pipeline depuis la préparation des données jusqu'à la cartographie des prédictions avec gestion de l'incertitude.

## Objectifs pédagogiques

À la fin de ce tutoriel, l'apprenant sera capable de :

1. Comprendre le pipeline de classification d'essences multi-sources (LiDAR + IRC)
2. Préparer et valider les données d'entrée (couronnes, labels terrain, rasters)
3. Calculer des features LiDAR par couronne (métriques de hauteur, densité, forme)
4. Calculer des features spectrales IRC par couronne (NDVI, ratios, statistiques)
5. Assembler un dataset d'apprentissage avec contrôles qualité
6. Mettre en place une validation spatiale (blockCV) pour éviter la fuite spatiale
7. Entraîner et comparer des modèles (Random Forest, XGBoost)
8. Évaluer les performances avec métriques adaptées (accuracy, F1 macro, matrice confusion)
9. Cartographier les prédictions avec indicateur d'incertitude

## Prérequis

- Tutorial 01 (Acquisition) - pattern cache, téléchargement données
- Tutorial 02 (LiDAR) - métriques LiDAR de base
- Tutorial 07 (LiDAR avancé) - segmentation couronnes avec lidaRtRee
- Connaissances de base en machine learning supervisé

## Contexte métier

### Objectif final

Produire une carte d'essences forestières au niveau couronne individuelle pour :
- Inventaire forestier à fine échelle
- Suivi de la composition des peuplements
- Cartographie de la biodiversité spécifique
- Aide à la gestion forestière multifonctionnelle

### Limites du tutoriel

Ce tutoriel **n'est pas** :
- Un benchmark exhaustif de méthodes deep learning
- Une segmentation universelle applicable partout
- Un workflow de production industriel
- Une comparaison multi-capteurs (Sentinel-2, drone, etc.)

## Données d'entrée

### Réutilisées depuis le cache des tutoriels précédents

| Donnée | Source | Format | Description |
|--------|--------|--------|-------------|
| Zone d'étude | Tutorial 01 | sf POLYGON | `zone_etude.gpkg` |
| MNH | Tutorial 02/07 | terra SpatRaster | Modèle numérique de hauteur |
| Couronnes segmentées | Tutorial 07 | sf POLYGON | `arbres_segmentes.gpkg` avec ID unique |
| Métriques LiDAR parcelle | Tutorial 02 | sf POLYGON | `metriques_lidar.gpkg` |
| Nuages de points normalisés | Tutorial 07 | LAScatalog | `plots.norm.laz/` ou `tiles.norm.laz/` |

### Données terrain (fournies)

| Donnée | Format | Description |
|--------|--------|-------------|
| Inventaire arbres | CSV | `Verc-XX-Y_ArbresTerrain.csv` avec essence (PIAB, FASY, ABAL, TABA) |
| Placettes coregistrées | sf POINT | `treesCoregistration.rda` (54 arbres avec espèce) |
| Table correspondance essences | data.frame | Codes IFN → noms français/scientifiques |

### À télécharger (ou mode offline)

| Donnée | Source | Format | Description |
|--------|--------|--------|-------------|
| Orthophoto IRC | IGN via happign | GeoTIFF 3 bandes | NIR-Red-Green 20cm |
| Alternative offline | Fourni | RDS | Raster exemple recadré |

## Structure du tutoriel

### Bienvenue (5 min)

```markdown
## Bienvenue dans le Tutorial 10 !

Ce tutoriel vous guidera dans la création d'une carte d'essences forestières
au niveau de la couronne individuelle, en combinant :
- **LiDAR HD** : structure 3D, hauteur, densité
- **Orthophoto IRC** : signature spectrale infrarouge

### Schéma du pipeline

┌─────────────────────────────────────────────────────────────────────┐
│  ENTRÉES                                                             │
│  ───────                                                             │
│  Couronnes segmentées (Tutorial 07)                                  │
│  + Orthophoto IRC (IGN)                                             │
│  + Labels terrain (essences)                                         │
│  + Métriques LiDAR (Tutorial 02/07)                                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  FEATURE ENGINEERING                                                 │
│  ───────────────────                                                 │
│  Features LiDAR par couronne (hauteur, forme, densité)              │
│  + Features IRC par couronne (NDVI, ratios, textures optionnelles)  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  VALIDATION SPATIALE (blockCV)                                       │
│  ─────────────────────────────                                       │
│  Éviter la fuite spatiale → estimations réalistes                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  MODÉLISATION                                                        │
│  ────────────                                                        │
│  Random Forest (ranger) vs XGBoost                                   │
│  Tuning, importance variables, incertitude                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CARTOGRAPHIE                                                        │
│  ────────────                                                        │
│  Classe prédite + probabilité max + flag "incertain"                │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Section 1 : Prérequis et environnement (15 min)

#### 1.1 Packages requis

```r
# Obligatoires
library(sf)            # Vecteurs
library(terra)         # Rasters
library(exactextractr) # Extraction zonale rapide
library(lidR)          # LiDAR (optionnel si métriques déjà calculées)
library(dplyr)         # Manipulation données
library(tidyr)         # Mise en forme
library(ggplot2)       # Visualisation

# Modélisation
library(ranger)        # Random Forest
library(xgboost)       # Gradient boosting

# Validation spatiale
library(blockCV)       # Spatial cross-validation

# Optionnels
library(lidaRtRee)     # Si segmentation à refaire
library(caret)         # Métriques alternatives
library(patchwork)     # Assemblage figures
library(units)         # Unités SI
```

#### 1.2 Vérification des versions

```r
# Vérifier les versions minimales
check_versions <- function() {
  versions <- list(
    sf = "1.0.0",
    terra = "1.7.0",
    ranger = "0.14.0",
    xgboost = "1.7.0",
    blockCV = "3.0.0"
  )

  for (pkg in names(versions)) {
    installed <- packageVersion(pkg)
    required <- versions[[pkg]]
    status <- if (installed >= required) "OK" else "ATTENTION"
    cat(sprintf("%s: %s (requis: %s) [%s]\n", pkg, installed, required, status))
  }
}

check_versions()
sessionInfo()
```

#### 1.3 Fonctions utilitaires

```r
# Vérification CRS
check_crs <- function(x, expected_crs = 2154) {
  actual_crs <- st_crs(x)$epsg


  if (is.na(actual_crs) || actual_crs != expected_crs) {
    stop(sprintf("CRS invalide: attendu EPSG:%d, obtenu EPSG:%s",
                 expected_crs, actual_crs))
  }
  invisible(TRUE)
}

# Vérification colonnes requises
assert_columns <- function(df, required_cols) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Colonnes manquantes: %s", paste(missing, collapse = ", ")))
  }
  invisible(TRUE)
}

# Lecture LAS sécurisée
safe_read_las <- function(path, ...) {
  if (!file.exists(path)) {
    stop(sprintf("Fichier LAS introuvable: %s", path))
  }
  tryCatch(
    readLAS(path, ...),
    error = function(e) stop(sprintf("Erreur lecture LAS: %s", e$message))
  )
}

# Sauvegarde checkpoint
save_checkpoint <- function(obj, name, cache_dir) {
  path <- file.path(cache_dir, paste0(name, ".rds"))
  saveRDS(obj, path)
  cat(sprintf("Checkpoint sauvegardé: %s\n", path))
  invisible(path)
}

# Chargement checkpoint
load_checkpoint <- function(name, cache_dir) {
  path <- file.path(cache_dir, paste0(name, ".rds"))
  if (!file.exists(path)) {
    return(NULL)
  }
  cat(sprintf("Checkpoint chargé: %s\n", path))
  readRDS(path)
}
```

#### Quiz 1 : Environnement (3 questions)

---

### Section 2 : Chargement des données (20 min)

#### 2.1 Configuration du cache

```r
# Répertoire cache nemeton
if (requireNamespace("rappdirs", quietly = TRUE)) {
  data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
} else {
  data_dir <- file.path(path.expand("~"), ".local", "share", "nemeton", "tutorial_data")
}
data_dir <- normalizePath(data_dir, mustWork = FALSE)
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# Répertoire spécifique tutorial 10
tuto10_dir <- file.path(data_dir, "result_classification")
dir.create(tuto10_dir, showWarnings = FALSE, recursive = TRUE)

cat("Cache tutorial 10:", tuto10_dir, "\n")
```

#### 2.2 Chargement des couronnes segmentées (Tutorial 07)

```r
# Option A : Charger depuis le cache Tutorial 07
crowns_file <- file.path(data_dir, "arbres_segmentes.gpkg")

if (file.exists(crowns_file)) {
  crowns <- st_read(crowns_file, quiet = TRUE)
  cat(sprintf("Couronnes chargées: %d polygones\n", nrow(crowns)))
} else {
  # Option B : Utiliser les données de coregistration
  data("treesCoregistration", package = "nemeton")
  crowns <- treesCoregistration
  cat("Attention: utilisation des données de coregistration (54 arbres)\n")
}

# Vérification
check_crs(crowns)
```

#### 2.3 Chargement des labels terrain

```r
# Données terrain depuis le package
trees_dir <- system.file("extdata", "aba.model", "field", package = "nemeton")

# Lire tous les fichiers d'arbres terrain
tree_files <- list.files(trees_dir, pattern = "_ArbresTerrain\\.csv$", full.names = TRUE)

trees_terrain <- purrr::map_dfr(tree_files, function(f) {
  df <- read.csv(f, stringsAsFactors = FALSE)
  df$source_file <- basename(f)
  df
})

# Correspondance codes essences
species_lookup <- data.frame(
  code = c("PIAB", "ABAL", "FASY", "TABA", "PISY", "LADE"),
  nom_fr = c("Épicéa", "Sapin", "Hêtre", "Frêne", "Pin sylvestre", "Mélèze"),
  nom_latin = c("Picea abies", "Abies alba", "Fagus sylvatica",
                "Fraxinus excelsior", "Pinus sylvestris", "Larix decidua"),
  groupe = c("Résineux", "Résineux", "Feuillu", "Feuillu", "Résineux", "Résineux")
)

cat(sprintf("Arbres terrain chargés: %d observations\n", nrow(trees_terrain)))
table(trees_terrain$ess)
```

#### 2.4 Téléchargement ou chargement orthophoto IRC

```r
# Vérifier si IRC existe dans le cache
irc_file <- file.path(data_dir, "orthophoto_irc.tif")

if (file.exists(irc_file)) {
  # Mode cache
  irc <- rast(irc_file)
  cat("Orthophoto IRC chargée depuis le cache\n")

} else if (requireNamespace("happign", quietly = TRUE) &&
           curl::has_internet()) {
  # Mode téléchargement
  cat("Téléchargement orthophoto IRC depuis IGN...\n")

  # Récupérer l'emprise de la zone d'étude
  zone_file <- file.path(data_dir, "zone_etude.gpkg")
  if (file.exists(zone_file)) {
    zone <- st_read(zone_file, layer = "zone_etude", quiet = TRUE)
    bbox_zone <- st_bbox(zone)
  } else {
    # Utiliser les coordonnées du Vercors par défaut
    bbox_zone <- c(xmin = 899000, ymin = 6447000, xmax = 901000, ymax = 6449000)
  }

  irc <- happign::get_wms_raster(
    bbox = bbox_zone,
    layer = "ORTHOIMAGERY.ORTHOPHOTOS.IRC",
    resolution = 0.5,  # 50cm
    crs = 2154
  )

  writeRaster(irc, irc_file)
  cat("Orthophoto IRC sauvegardée\n")

} else {
  # Mode offline : générer données synthétiques
  cat("Mode offline: génération de données IRC synthétiques\n")

  # Créer un raster synthétique basé sur l'emprise des couronnes
  ext_crowns <- ext(crowns)

  # Générer 3 bandes (NIR, Red, Green) avec valeurs réalistes
  set.seed(2024)
  nir <- rast(ext_crowns, resolution = 0.5, crs = "EPSG:2154")
  values(nir) <- runif(ncell(nir), 100, 255)

  red <- rast(ext_crowns, resolution = 0.5, crs = "EPSG:2154")
  values(red) <- runif(ncell(red), 30, 150)

  green <- rast(ext_crowns, resolution = 0.5, crs = "EPSG:2154")
  values(green) <- runif(ncell(green), 40, 160)

  irc <- c(nir, red, green)
  names(irc) <- c("NIR", "Red", "Green")

  cat("Attention: données IRC synthétiques générées\n")
}

print(irc)
```

#### 2.5 Calcul du NDVI

```r
# NDVI = (NIR - Red) / (NIR + Red)
ndvi <- (irc[[1]] - irc[[2]]) / (irc[[1]] + irc[[2]])
names(ndvi) <- "NDVI"

# Vérifier les valeurs
cat(sprintf("NDVI: min=%.2f, max=%.2f, mean=%.2f\n",
            global(ndvi, "min", na.rm = TRUE)[[1]],
            global(ndvi, "max", na.rm = TRUE)[[1]],
            global(ndvi, "mean", na.rm = TRUE)[[1]]))

# Visualisation rapide
plot(ndvi, main = "NDVI", col = colorRampPalette(c("brown", "yellow", "darkgreen"))(100))
```

#### Exercice 2.1 : Vérifier la cohérence des données

#### Quiz 2 : Données d'entrée (3 questions)

---

### Section 3 : Segmentation des couronnes (optionnel) (15 min)

#### 3.1 Option A : Couronnes déjà disponibles

```r
# Si les couronnes sont déjà segmentées (Tutorial 07)
if (exists("crowns") && nrow(crowns) > 0) {
  cat(sprintf("Utilisation des %d couronnes existantes\n", nrow(crowns)))

  # Vérifier les colonnes requises
  required_cols <- c("treeID")  # Au minimum un identifiant unique
  if (!"treeID" %in% names(crowns)) {
    crowns$treeID <- seq_len(nrow(crowns))
  }
}
```

#### 3.2 Option B : Segmentation avec lidaRtRee

```r
# Si besoin de segmenter (exemple avec lidaRtRee)
segment_crowns_lidartree <- function(las_file, mnh_file = NULL) {
  library(lidaRtRee)

  # Charger le nuage de points normalisé
  las <- readLAS(las_file)

  # Générer le MNH si non fourni
  if (is.null(mnh_file)) {
    chm <- rasterize_canopy(las, res = 0.5, algorithm = p2r())
  } else {
    chm <- rast(mnh_file)
  }

  # Détection des cimes
  ttops <- locate_trees(las, algorithm = lmf(ws = 5))

  # Segmentation des couronnes
  crowns <- segment_trees(las, algorithm = dalponte2016(chm, ttops))

  # Convertir en polygones
  crown_polygons <- crown_metrics(crowns, func = NULL, geom = "convex")

  return(crown_polygons)
}
```

#### 3.3 Diagnostics de qualité des couronnes

```r
# Diagnostics simples de segmentation
diagnose_crowns <- function(crowns) {
  # Calculer métriques de forme
  crowns$area_m2 <- as.numeric(st_area(crowns))
  crowns$perimeter_m <- as.numeric(st_length(st_cast(crowns, "MULTILINESTRING")))
  crowns$compactness <- 4 * pi * crowns$area_m2 / (crowns$perimeter_m^2)

  # Identifier problèmes potentiels
  diagnostics <- list(
    n_total = nrow(crowns),
    n_too_small = sum(crowns$area_m2 < 1),           # < 1m²
    n_too_large = sum(crowns$area_m2 > 500),         # > 500m² (fusion probable)
    n_elongated = sum(crowns$compactness < 0.2),     # Très allongées
    area_median = median(crowns$area_m2),
    area_mean = mean(crowns$area_m2)
  )

  cat("=== Diagnostics segmentation ===\n")
  cat(sprintf("Total couronnes: %d\n", diagnostics$n_total))
  cat(sprintf("Trop petites (<1m²): %d (%.1f%%)\n",
              diagnostics$n_too_small,
              100 * diagnostics$n_too_small / diagnostics$n_total))
  cat(sprintf("Trop grandes (>500m²): %d (%.1f%%)\n",
              diagnostics$n_too_large,
              100 * diagnostics$n_too_large / diagnostics$n_total))
  cat(sprintf("Surface médiane: %.1f m²\n", diagnostics$area_median))

  return(diagnostics)
}

diag <- diagnose_crowns(crowns)
```

#### Exercice 3.1 : Filtrer les couronnes aberrantes

---

### Section 4 : Feature engineering LiDAR (30 min)

#### 4.1 Définition des métriques LiDAR

```r
# Set minimal de features LiDAR
lidar_metrics_minimal <- function(z) {
  list(
    z_max = max(z, na.rm = TRUE),
    z_mean = mean(z, na.rm = TRUE),
    z_sd = sd(z, na.rm = TRUE),
    z_p25 = quantile(z, 0.25, na.rm = TRUE),
    z_p50 = quantile(z, 0.50, na.rm = TRUE),
    z_p95 = quantile(z, 0.95, na.rm = TRUE)
  )
}

# Set recommandé (complet)
lidar_metrics_full <- function(z, i = NULL) {
  n <- length(z)
  z_above2 <- z[z > 2]

  metrics <- list(
    # Hauteurs
    z_max = max(z, na.rm = TRUE),
    z_mean = mean(z, na.rm = TRUE),
    z_sd = sd(z, na.rm = TRUE),
    z_cv = sd(z, na.rm = TRUE) / mean(z, na.rm = TRUE),
    z_p10 = quantile(z, 0.10, na.rm = TRUE),
    z_p25 = quantile(z, 0.25, na.rm = TRUE),
    z_p50 = quantile(z, 0.50, na.rm = TRUE),
    z_p75 = quantile(z, 0.75, na.rm = TRUE),
    z_p95 = quantile(z, 0.95, na.rm = TRUE),
    z_p99 = quantile(z, 0.99, na.rm = TRUE),

    # Densités verticales par strates
    d_0_2 = sum(z <= 2) / n,           # Sous-étage
    d_2_5 = sum(z > 2 & z <= 5) / n,   # Étage arbustif
    d_5_10 = sum(z > 5 & z <= 10) / n, # Étage intermédiaire
    d_10_20 = sum(z > 10 & z <= 20) / n, # Canopée basse
    d_above20 = sum(z > 20) / n,        # Canopée haute

    # Couverture
    cover_above2 = length(z_above2) / n
  )

  # Intensité (optionnelle, avec prudence)
  if (!is.null(i) && length(i) > 0) {
    metrics$i_mean <- mean(i, na.rm = TRUE)
    metrics$i_sd <- sd(i, na.rm = TRUE)
  }

  return(metrics)
}
```

#### 4.2 Extraction des métriques par couronne

```r
# Extraire métriques LiDAR pour chaque couronne
extract_lidar_features <- function(crowns, las_catalog, use_intensity = FALSE) {

  # Fonction d'extraction par couronne
  extract_crown <- function(crown_geom, las) {
    # Clipper le nuage de points à la couronne
    pts <- clip_roi(las, crown_geom)

    if (is.empty(pts) || npoints(pts) < 10) {
      return(NULL)
    }

    z <- pts$Z
    i <- if (use_intensity && "Intensity" %in% names(pts)) pts$Intensity else NULL

    return(lidar_metrics_full(z, i))
  }

  # Traitement (utiliser future pour paralléliser si gros jeu de données)
  if (nrow(crowns) > 100 && requireNamespace("future.apply", quietly = TRUE)) {
    library(future)
    library(future.apply)
    plan(multisession, workers = parallel::detectCores() - 1)

    metrics_list <- future_lapply(seq_len(nrow(crowns)), function(i) {
      las <- readLAS(las_catalog, filter = sf::st_bbox(crowns[i, ]))
      extract_crown(crowns[i, ], las)
    }, future.seed = TRUE)

    plan(sequential)
  } else {
    # Traitement séquentiel
    metrics_list <- lapply(seq_len(nrow(crowns)), function(i) {
      # Placeholder - en pratique charger le LAS approprié
      NULL
    })
  }

  # Convertir en data.frame
  metrics_df <- do.call(rbind, lapply(metrics_list, function(m) {
    if (is.null(m)) {
      return(data.frame(matrix(NA, nrow = 1, ncol = length(lidar_metrics_full(1:10)))))
    }
    as.data.frame(m)
  }))

  return(metrics_df)
}
```

#### 4.3 Métriques de forme de couronne

```r
# Calculer métriques géométriques de la couronne
calculate_crown_geometry <- function(crowns) {
  crowns <- crowns |>
    mutate(
      # Surface
      area_m2 = as.numeric(st_area(geometry)),

      # Périmètre
      perimeter_m = as.numeric(st_length(st_cast(geometry, "MULTILINESTRING"))),

      # Compacité (1 = cercle parfait)
      compactness = 4 * pi * area_m2 / (perimeter_m^2),

      # Rayon équivalent (si cercle de même surface)
      radius_eq = sqrt(area_m2 / pi),

      # Centroïde
      centroid = st_centroid(geometry)
    )

  # Si hauteur disponible, calculer ratio H/rayon
  if ("z_max" %in% names(crowns)) {
    crowns <- crowns |>
      mutate(
        ratio_h_radius = z_max / radius_eq
      )
  }

  return(crowns)
}

crowns <- calculate_crown_geometry(crowns)
```

#### 4.4 Note sur l'intensité LiDAR

```markdown
**Attention à l'intensité LiDAR**

L'intensité des retours LiDAR dépend de nombreux facteurs :
- Type de capteur
- Altitude de vol
- Conditions atmosphériques
- Calibration du système

Pour ce tutoriel, nous proposons une **option "sans intensité"** plus robuste.
Si vous souhaitez utiliser l'intensité :
1. Vérifiez que les données sont calibrées (même campagne)
2. Normalisez par l'angle de scan ou la distance
3. Interprétez les résultats avec prudence
```

#### Exercice 4.1 : Calculer les métriques LiDAR

#### Quiz 4 : Features LiDAR (3 questions)

---

### Section 5 : Feature engineering IRC (25 min)

#### 5.1 Explication IRC (NIR-Red-Green)

```markdown
### Orthophotos Infrarouge Couleur (IRC)

Les orthophotos IRC de l'IGN contiennent 3 bandes :
- **Bande 1 : NIR** (Proche Infrarouge) - forte réflectance végétation saine
- **Bande 2 : Red** (Rouge) - absorbé par la chlorophylle
- **Bande 3 : Green** (Vert) - réflectance intermédiaire

### Indices spectraux utiles

| Indice | Formule | Interprétation |
|--------|---------|----------------|
| NDVI | (NIR - Red) / (NIR + Red) | Vigueur végétation [-1, 1] |
| GNDVI | (NIR - Green) / (NIR + Green) | Sensible à la chlorophylle |
| RVI | NIR / Red | Simple Ratio Vegetation Index |
| NGRDI | (Green - Red) / (Green + Red) | Verdeur visible |
```

#### 5.2 Calcul des indices spectraux

```r
# Calcul des indices spectraux
calculate_spectral_indices <- function(irc) {
  nir <- irc[[1]]
  red <- irc[[2]]
  green <- irc[[3]]

  indices <- c(
    # Indices classiques
    NDVI = (nir - red) / (nir + red),
    GNDVI = (nir - green) / (nir + green),
    RVI = nir / red,
    NGRDI = (green - red) / (green + red),

    # Ratios simples
    NIR_Red = nir / red,
    NIR_Green = nir / green,
    Red_Green = red / green
  )

  return(indices)
}

spectral_stack <- calculate_spectral_indices(irc)
print(spectral_stack)
```

#### 5.3 Extraction par couronne avec exactextractr

```r
# Extraction des statistiques spectrales par couronne
extract_irc_features <- function(crowns, irc, ndvi, spectral_stack) {

  # Statistiques à extraire
  stats <- c("mean", "median", "stdev", "quantile")

  # Extraction NIR
  nir_stats <- exact_extract(irc[[1]], crowns,
                              fun = c("mean", "median", "stdev",
                                     "quantile", "quantile"),
                              quantiles = c(0.1, 0.9))
  names(nir_stats) <- paste0("nir_", c("mean", "median", "sd", "p10", "p90"))

  # Extraction Red
  red_stats <- exact_extract(irc[[2]], crowns,
                              fun = c("mean", "median", "stdev",
                                     "quantile", "quantile"),
                              quantiles = c(0.1, 0.9))
  names(red_stats) <- paste0("red_", c("mean", "median", "sd", "p10", "p90"))

  # Extraction Green
  green_stats <- exact_extract(irc[[3]], crowns,
                                fun = c("mean", "median", "stdev",
                                       "quantile", "quantile"),
                                quantiles = c(0.1, 0.9))
  names(green_stats) <- paste0("green_", c("mean", "median", "sd", "p10", "p90"))

  # Extraction NDVI
  ndvi_stats <- exact_extract(ndvi, crowns,
                               fun = c("mean", "median", "stdev",
                                      "quantile", "quantile"),
                               quantiles = c(0.1, 0.9))
  names(ndvi_stats) <- paste0("ndvi_", c("mean", "median", "sd", "p10", "p90"))

  # Combiner
  irc_features <- cbind(nir_stats, red_stats, green_stats, ndvi_stats)

  return(irc_features)
}

irc_features <- extract_irc_features(crowns, irc, ndvi, spectral_stack)
cat(sprintf("Features IRC extraites: %d variables\n", ncol(irc_features)))
```

#### 5.4 Option textures (bonus)

```r
# Option : calcul de textures GLCM (si package disponible)
# Cette section est optionnelle car les textures ajoutent de la complexité

if (requireNamespace("glcm", quietly = TRUE)) {
  library(glcm)

  # Calcul GLCM sur la bande NIR
  texture_nir <- glcm(irc[[1]],
                      window = c(3, 3),
                      statistics = c("mean", "variance", "homogeneity", "contrast"))

  # Extraction par couronne
  texture_stats <- exact_extract(texture_nir, crowns, fun = "mean")
  names(texture_stats) <- paste0("texture_", names(texture_nir))

} else {
  cat("Package glcm non disponible - textures ignorées\n")
  cat("Pour installer: install.packages('glcm')\n")
}
```

#### Exercice 5.1 : Extraire les features IRC

#### Quiz 5 : Features spectrales (3 questions)

---

### Section 6 : Assemblage du dataset d'apprentissage (25 min)

#### 6.1 Jointure features LiDAR + IRC + labels

```r
# Assembler le dataset complet
assemble_training_data <- function(crowns, lidar_features, irc_features,
                                    terrain_labels, species_lookup) {

  # Ajouter les features LiDAR
  crowns_features <- cbind(crowns, lidar_features)

  # Ajouter les features IRC
  crowns_features <- cbind(crowns_features, irc_features)

  # Joindre les labels terrain
  # Jointure spatiale si les labels sont des points
  if (inherits(terrain_labels, "sf")) {
    labels_joined <- st_join(crowns_features, terrain_labels,
                              join = st_contains)
  } else {
    # Jointure par ID si table
    labels_joined <- left_join(crowns_features, terrain_labels,
                                by = "treeID")
  }

  # Traduire les codes essences
  labels_joined <- labels_joined |>
    left_join(species_lookup, by = c("ess" = "code")) |>
    rename(species = nom_fr)

  return(labels_joined)
}

training_data <- assemble_training_data(
  crowns = crowns,
  lidar_features = lidar_features,
  irc_features = irc_features,
  terrain_labels = trees_terrain,
  species_lookup = species_lookup
)
```

#### 6.2 Nettoyage des données

```r
# Nettoyage et contrôle qualité
clean_training_data <- function(data, min_samples_per_class = 10) {

  n_initial <- nrow(data)

  # 1. Supprimer les lignes sans label
  data <- data |> filter(!is.na(species))
  cat(sprintf("Après filtrage NA espèce: %d lignes\n", nrow(data)))

  # 2. Supprimer les lignes avec trop de NA dans les features
  feature_cols <- grep("^(z_|nir_|red_|green_|ndvi_|d_|cover_)",
                        names(data), value = TRUE)
  data$na_count <- rowSums(is.na(data[, feature_cols]))
  data <- data |> filter(na_count < length(feature_cols) * 0.5)
  cat(sprintf("Après filtrage NA features: %d lignes\n", nrow(data)))

  # 3. Détecter outliers simples (méthode IQR)
  detect_outliers <- function(x) {
    q1 <- quantile(x, 0.25, na.rm = TRUE)
    q3 <- quantile(x, 0.75, na.rm = TRUE)
    iqr <- q3 - q1
    x < (q1 - 3 * iqr) | x > (q3 + 3 * iqr)
  }

  # Marquer les outliers (sans les supprimer automatiquement)
  for (col in feature_cols[1:min(5, length(feature_cols))]) {
    data[[paste0(col, "_outlier")]] <- detect_outliers(data[[col]])
  }

  # 4. Vérifier taille échantillons par classe
  class_counts <- data |>
    st_drop_geometry() |>
    count(species) |>
    arrange(n)

  cat("\n=== Échantillons par classe ===\n")
  print(class_counts)

  # 5. Regrouper ou supprimer classes rares
  rare_classes <- class_counts$species[class_counts$n < min_samples_per_class]

  if (length(rare_classes) > 0) {
    cat(sprintf("\nClasses avec < %d échantillons: %s\n",
                min_samples_per_class, paste(rare_classes, collapse = ", ")))

    # Option: regrouper en "Autre" ou supprimer
    data <- data |>
      mutate(species = ifelse(species %in% rare_classes, "Autre", species))
  }

  # 6. Encodage facteur
  data$species <- as.factor(data$species)

  cat(sprintf("\nDataset final: %d lignes, %d classes\n",
              nrow(data), nlevels(data$species)))

  return(data)
}

training_data <- clean_training_data(training_data, min_samples_per_class = 10)
```

#### 6.3 Sélection des features finales

```r
# Sélectionner les features pour la modélisation
select_features <- function(data) {

  # Features LiDAR
  lidar_cols <- c("z_max", "z_mean", "z_sd", "z_cv",
                   "z_p25", "z_p50", "z_p75", "z_p95",
                   "d_0_2", "d_2_5", "d_5_10", "d_10_20", "d_above20",
                   "cover_above2")

  # Features géométrie couronne
  geom_cols <- c("area_m2", "compactness", "radius_eq", "ratio_h_radius")

 # Features IRC
  irc_cols <- c("nir_mean", "nir_sd", "nir_p10", "nir_p90",
                 "red_mean", "red_sd",
                 "green_mean",
                 "ndvi_mean", "ndvi_sd", "ndvi_p10", "ndvi_p90")

  # Combiner
  feature_cols <- c(lidar_cols, geom_cols, irc_cols)

  # Garder seulement les colonnes existantes
  feature_cols <- intersect(feature_cols, names(data))

  cat(sprintf("Features sélectionnées: %d\n", length(feature_cols)))

  return(feature_cols)
}

feature_cols <- select_features(training_data)
```

#### 6.4 Checkpoint

```r
# Sauvegarder le dataset d'apprentissage
save_checkpoint(training_data, "training_data", tuto10_dir)
save_checkpoint(feature_cols, "feature_cols", tuto10_dir)
```

#### Exercice 6.1 : Assembler le dataset

#### Quiz 6 : Dataset d'apprentissage (3 questions)

---

### Section 7 : Validation spatiale avec blockCV (25 min)

#### 7.1 Problème de la fuite spatiale

```markdown
### Pourquoi la CV classique surestime les performances ?

En classification d'objets spatiaux (couronnes, placettes, pixels),
les observations proches sont souvent **autocorrélées** :
- Mêmes conditions environnementales
- Même peuplement forestier
- Mêmes erreurs de mesure

Une validation croisée classique (random k-fold) mélange train et test
géographiquement proches → **estimation optimiste** des performances.

**Solution** : Validation croisée spatiale par blocs (blockCV)
- Séparer train/test par blocs spatiaux
- Aucun bloc n'est à cheval entre train et test
- Estimation **réaliste** de la performance en production
```

#### 7.2 Détermination de la taille des blocs

```r
library(blockCV)

# Règle heuristique pour la taille des blocs
# Basée sur l'autocorrélation spatiale des features ou du résidu

# Option 1 : Basée sur la distance moyenne entre observations
estimate_block_size <- function(data) {
  # Calculer les distances entre points
  coords <- st_coordinates(st_centroid(data))

  # Distance médiane au plus proche voisin
  nn_dist <- FNN::knn.dist(coords, k = 1)
  median_nn <- median(nn_dist)

  # Taille de bloc suggérée = 10x la distance médiane au voisin
  block_size <- 10 * median_nn

  cat(sprintf("Distance médiane au voisin: %.0f m\n", median_nn))
  cat(sprintf("Taille de bloc suggérée: %.0f m\n", block_size))

  return(block_size)
}

block_size <- estimate_block_size(training_data)

# Option 2 : Utiliser cv_spatial_autocor de blockCV
# (calcule l'autocorrélation spatiale empirique)
if (nrow(training_data) > 50) {
  sac <- cv_spatial_autocor(
    x = training_data,
    column = feature_cols[1],  # Feature principale
    plot = TRUE
  )
  cat(sprintf("Range d'autocorrélation estimé: %.0f m\n", sac$range))
}
```

#### 7.3 Création des blocs spatiaux

```r
# Créer les folds spatiaux avec blockCV
create_spatial_folds <- function(data, block_size, k = 5) {

  # Créer les blocs
  sb <- cv_spatial(
    x = data,
    column = "species",          # Variable cible pour stratification
    size = block_size,           # Taille des blocs
    k = k,                       # Nombre de folds
    hexagon = TRUE,              # Blocs hexagonaux
    selection = "random",        # Attribution aléatoire
    iteration = 100,             # Itérations pour équilibrer
    seed = 2024
  )

  # Visualiser les blocs
  cv_plot(sb, x = data)

  return(sb)
}

spatial_folds <- create_spatial_folds(training_data, block_size, k = 5)

# Extraire les indices train/test pour chaque fold
fold_indices <- spatial_folds$folds_list
```

#### 7.4 Comparaison CV standard vs blockCV

```r
# Exercice : Comparer accuracy CV standard vs blockCV
compare_cv_methods <- function(data, feature_cols, target_col = "species") {

  # Préparer les données
  X <- st_drop_geometry(data)[, feature_cols]
  X <- X[complete.cases(X), ]
  y <- data[[target_col]][complete.cases(st_drop_geometry(data)[, feature_cols])]

  # CV standard (random 5-fold)
  set.seed(2024)
  random_folds <- sample(rep(1:5, length.out = length(y)))

  acc_random <- sapply(1:5, function(fold) {
    train_idx <- which(random_folds != fold)
    test_idx <- which(random_folds == fold)

    model <- ranger(x = X[train_idx, ], y = y[train_idx], num.trees = 100)
    pred <- predict(model, X[test_idx, ])$predictions
    mean(pred == y[test_idx])
  })

  # CV spatiale (blockCV)
  acc_spatial <- sapply(seq_along(fold_indices), function(i) {
    train_idx <- fold_indices[[i]]$train
    test_idx <- fold_indices[[i]]$test

    # Filtrer les indices valides
    train_idx <- train_idx[train_idx <= nrow(X)]
    test_idx <- test_idx[test_idx <= nrow(X)]

    if (length(train_idx) < 10 || length(test_idx) < 5) return(NA)

    model <- ranger(x = X[train_idx, ], y = y[train_idx], num.trees = 100)
    pred <- predict(model, X[test_idx, ])$predictions
    mean(pred == y[test_idx])
  })

  cat("=== Comparaison méthodes CV ===\n")
  cat(sprintf("CV Random : %.1f%% (+/- %.1f%%)\n",
              100 * mean(acc_random), 100 * sd(acc_random)))
  cat(sprintf("CV Spatiale: %.1f%% (+/- %.1f%%)\n",
              100 * mean(acc_spatial, na.rm = TRUE),
              100 * sd(acc_spatial, na.rm = TRUE)))

  return(list(random = acc_random, spatial = acc_spatial))
}

cv_comparison <- compare_cv_methods(training_data, feature_cols)
```

#### Exercice 7.1 : Interpréter la différence CV

#### Quiz 7 : Validation spatiale (3 questions)

---

### Section 8 : Modélisation (35 min)

#### 8.1 Baseline : Random Forest avec ranger

```r
library(ranger)

# Préparer données
prepare_model_data <- function(data, feature_cols, target_col = "species") {
  df <- st_drop_geometry(data)[, c(feature_cols, target_col)]
  df <- df[complete.cases(df), ]
  df[[target_col]] <- as.factor(df[[target_col]])
  return(df)
}

model_data <- prepare_model_data(training_data, feature_cols)

# Diviser train/test (utiliser le premier fold spatial)
train_idx <- spatial_folds$folds_list[[1]]$train
test_idx <- spatial_folds$folds_list[[1]]$test
train_idx <- train_idx[train_idx <= nrow(model_data)]
test_idx <- test_idx[test_idx <= nrow(model_data)]

train_data <- model_data[train_idx, ]
test_data <- model_data[test_idx, ]

# Entraîner Random Forest baseline
rf_baseline <- ranger(
  species ~ .,
  data = train_data,
  num.trees = 500,
  importance = "permutation",
  probability = TRUE,
  seed = 2024
)

print(rf_baseline)
```

#### 8.2 Tuning Random Forest

```r
# Grid search simple pour mtry et min.node.size
tune_ranger <- function(train_data, feature_cols, n_folds = 3) {

  # Grille de paramètres
  param_grid <- expand.grid(
    mtry = c(floor(sqrt(length(feature_cols))),
             floor(length(feature_cols) / 3),
             floor(length(feature_cols) / 2)),
    min.node.size = c(1, 5, 10)
  )

  # Validation croisée interne
  set.seed(2024)
  folds <- sample(rep(1:n_folds, length.out = nrow(train_data)))

  results <- apply(param_grid, 1, function(params) {
    acc <- sapply(1:n_folds, function(fold) {
      train_fold <- train_data[folds != fold, ]
      valid_fold <- train_data[folds == fold, ]

      model <- ranger(
        species ~ .,
        data = train_fold,
        num.trees = 200,
        mtry = params["mtry"],
        min.node.size = params["min.node.size"],
        probability = TRUE
      )

      pred <- predict(model, valid_fold)$predictions
      pred_class <- colnames(pred)[apply(pred, 1, which.max)]
      mean(pred_class == valid_fold$species)
    })

    mean(acc)
  })

  best_idx <- which.max(results)
  best_params <- param_grid[best_idx, ]

  cat("=== Meilleurs paramètres Random Forest ===\n")
  cat(sprintf("mtry: %d\n", best_params$mtry))
  cat(sprintf("min.node.size: %d\n", best_params$min.node.size))
  cat(sprintf("Accuracy CV: %.1f%%\n", 100 * results[best_idx]))

  return(best_params)
}

best_rf_params <- tune_ranger(train_data, feature_cols)

# Entraîner modèle final avec meilleurs paramètres
rf_final <- ranger(
  species ~ .,
  data = train_data,
  num.trees = 500,
  mtry = best_rf_params$mtry,
  min.node.size = best_rf_params$min.node.size,
  importance = "permutation",
  probability = TRUE,
  seed = 2024
)
```

#### 8.3 Challenger : XGBoost

```r
library(xgboost)

# Préparer données pour XGBoost
prepare_xgb_data <- function(train_data, test_data, feature_cols) {

  # Encoder les labels
  labels <- levels(train_data$species)
  train_y <- as.integer(train_data$species) - 1
  test_y <- as.integer(test_data$species) - 1

  # Matrices
  train_x <- as.matrix(train_data[, feature_cols])
  test_x <- as.matrix(test_data[, feature_cols])

  # DMatrix
  dtrain <- xgb.DMatrix(data = train_x, label = train_y)
  dtest <- xgb.DMatrix(data = test_x, label = test_y)

  return(list(
    dtrain = dtrain,
    dtest = dtest,
    labels = labels,
    train_y = train_y,
    test_y = test_y
  ))
}

xgb_data <- prepare_xgb_data(train_data, test_data, feature_cols)

# Paramètres XGBoost
xgb_params <- list(
  objective = "multi:softprob",
  num_class = length(xgb_data$labels),
  eta = 0.1,
  max_depth = 6,
  subsample = 0.8,
  colsample_bytree = 0.8,
  eval_metric = "mlogloss"
)

# Entraînement avec early stopping
xgb_model <- xgb.train(
  params = xgb_params,
  data = xgb_data$dtrain,
  nrounds = 500,
  watchlist = list(train = xgb_data$dtrain, test = xgb_data$dtest),
  early_stopping_rounds = 20,
  print_every_n = 50,
  verbose = 1
)

cat(sprintf("Meilleur nrounds: %d\n", xgb_model$best_iteration))
```

#### 8.4 Évaluation des modèles

```r
# Fonction d'évaluation multi-classe
evaluate_model <- function(pred_probs, true_labels, class_names) {

  # Classe prédite
  pred_class <- class_names[apply(pred_probs, 1, which.max)]

  # Probabilité max (confiance)
  prob_max <- apply(pred_probs, 1, max)

  # Accuracy globale
  accuracy <- mean(pred_class == true_labels)

  # Matrice de confusion
  conf_matrix <- table(Prédit = pred_class, Réel = true_labels)

  # Métriques par classe
  classes <- levels(as.factor(true_labels))
  metrics_per_class <- sapply(classes, function(cls) {
    tp <- sum(pred_class == cls & true_labels == cls)
    fp <- sum(pred_class == cls & true_labels != cls)
    fn <- sum(pred_class != cls & true_labels == cls)

    precision <- ifelse(tp + fp > 0, tp / (tp + fp), 0)
    recall <- ifelse(tp + fn > 0, tp / (tp + fn), 0)
    f1 <- ifelse(precision + recall > 0,
                 2 * precision * recall / (precision + recall), 0)

    c(precision = precision, recall = recall, f1 = f1)
  })

  # F1 macro (moyenne non pondérée)
  f1_macro <- mean(metrics_per_class["f1", ])

  # Balanced accuracy
  recall_per_class <- metrics_per_class["recall", ]
  balanced_acc <- mean(recall_per_class)

  # Kappa de Cohen
  n <- length(true_labels)
  p_o <- accuracy
  p_e <- sum(table(pred_class) * table(true_labels)) / n^2
  kappa <- (p_o - p_e) / (1 - p_e)

  cat("=== Métriques d'évaluation ===\n")
  cat(sprintf("Accuracy: %.1f%%\n", 100 * accuracy))
  cat(sprintf("Balanced Accuracy: %.1f%%\n", 100 * balanced_acc))
  cat(sprintf("F1 Macro: %.3f\n", f1_macro))
  cat(sprintf("Kappa: %.3f\n", kappa))
  cat("\nMatrice de confusion:\n")
  print(conf_matrix)

  return(list(
    accuracy = accuracy,
    balanced_accuracy = balanced_acc,
    f1_macro = f1_macro,
    kappa = kappa,
    confusion_matrix = conf_matrix,
    prob_max = prob_max
  ))
}

# Évaluer Random Forest
rf_pred <- predict(rf_final, test_data)$predictions
rf_eval <- evaluate_model(rf_pred, test_data$species, levels(test_data$species))

# Évaluer XGBoost
xgb_pred_raw <- predict(xgb_model, xgb_data$dtest)
xgb_pred <- matrix(xgb_pred_raw, ncol = length(xgb_data$labels), byrow = TRUE)
xgb_eval <- evaluate_model(xgb_pred, xgb_data$labels[xgb_data$test_y + 1], xgb_data$labels)
```

#### 8.5 Importance des variables

```r
# Random Forest
rf_importance <- data.frame(
  variable = names(rf_final$variable.importance),
  importance = rf_final$variable.importance
) |>
  arrange(desc(importance)) |>
  head(15)

ggplot(rf_importance, aes(x = reorder(variable, importance), y = importance)) +
  geom_col(fill = "forestgreen") +
  coord_flip() +
  labs(title = "Importance des variables (Random Forest)",
       x = "", y = "Importance (permutation)") +
  theme_minimal()

# XGBoost
xgb_importance <- xgb.importance(model = xgb_model) |>
  head(15)

xgb.plot.importance(xgb_importance, main = "Importance des variables (XGBoost)")
```

#### 8.6 Gestion de l'incertitude

```r
# Définir un seuil de confiance pour marquer "unknown"
add_uncertainty_flag <- function(predictions, prob_max, threshold = 0.5) {
  predictions_with_flag <- data.frame(
    pred_class = predictions,
    prob_max = prob_max,
    uncertain = prob_max < threshold
  )

  predictions_with_flag$final_class <- ifelse(
    predictions_with_flag$uncertain,
    "Incertain",
    as.character(predictions_with_flag$pred_class)
  )

  cat(sprintf("Couronnes incertaines (proba < %.0f%%): %d (%.1f%%)\n",
              100 * threshold,
              sum(predictions_with_flag$uncertain),
              100 * mean(predictions_with_flag$uncertain)))

  return(predictions_with_flag)
}

# Appliquer sur Random Forest
rf_pred_class <- levels(test_data$species)[apply(rf_pred, 1, which.max)]
rf_pred_uncertain <- add_uncertainty_flag(rf_pred_class, rf_eval$prob_max, threshold = 0.5)
```

#### Exercice 8.1 : Comparer Random Forest vs XGBoost

#### Quiz 8 : Modélisation (3 questions)

---

### Section 9 : Cartographie des résultats (20 min)

#### 9.1 Prédiction sur toutes les couronnes

```r
# Prédire sur toutes les couronnes (pas seulement celles avec labels)
predict_all_crowns <- function(crowns, model, feature_cols) {

  # Extraire les features
  features <- st_drop_geometry(crowns)[, feature_cols]

  # Identifier couronnes avec features complètes
  complete_idx <- complete.cases(features)

  # Prédire
  pred <- predict(model, features[complete_idx, ])

  # Initialiser résultats
  crowns$pred_class <- NA
  crowns$pred_prob <- NA

  # Remplir les prédictions
  if (inherits(pred, "ranger.prediction")) {
    pred_probs <- pred$predictions
    crowns$pred_class[complete_idx] <- colnames(pred_probs)[apply(pred_probs, 1, which.max)]
    crowns$pred_prob[complete_idx] <- apply(pred_probs, 1, max)
  }

  # Marquer incertains
  crowns$uncertain <- crowns$pred_prob < 0.5
  crowns$final_class <- ifelse(crowns$uncertain, "Incertain", crowns$pred_class)

  return(crowns)
}

crowns_predicted <- predict_all_crowns(crowns, rf_final, feature_cols)
```

#### 9.2 Carte des classes prédites

```r
# Palette de couleurs par essence
species_colors <- c(
  "Épicéa" = "#1b9e77",
  "Sapin" = "#d95f02",
  "Hêtre" = "#7570b3",
  "Frêne" = "#e7298a",
  "Autre" = "#66a61e",
  "Incertain" = "grey70"
)

# Carte des classes
ggplot() +
  geom_sf(data = crowns_predicted,
          aes(fill = final_class),
          color = "white", linewidth = 0.1) +
  scale_fill_manual(values = species_colors, name = "Essence") +
  labs(title = "Classification des essences par couronne",
       subtitle = sprintf("n = %d couronnes", nrow(crowns_predicted))) +
  theme_minimal() +
  theme(legend.position = "right")
```

#### 9.3 Carte des probabilités

```r
# Carte des probabilités max (confiance)
ggplot() +
  geom_sf(data = crowns_predicted,
          aes(fill = pred_prob),
          color = NA) +
  scale_fill_viridis_c(
    name = "Probabilité",
    option = "plasma",
    limits = c(0, 1),
    na.value = "grey90"
  ) +
  labs(title = "Confiance de la classification",
       subtitle = "Probabilité de la classe prédite") +
  theme_minimal()
```

#### 9.4 Carte des zones incertaines

```r
# Carte binaire incertain/confiant
ggplot() +
  geom_sf(data = crowns_predicted,
          aes(fill = uncertain),
          color = "white", linewidth = 0.1) +
  scale_fill_manual(
    values = c("FALSE" = "forestgreen", "TRUE" = "red"),
    labels = c("Confiant (>50%)", "Incertain (<50%)"),
    name = "Confiance"
  ) +
  labs(title = "Zones de confiance de la classification") +
  theme_minimal()
```

#### 9.5 Contrôle visuel

```r
# Superposer avec l'orthophoto IRC pour vérification visuelle
if (exists("irc")) {
  # Convertir IRC en RGB pour affichage
  irc_rgb <- irc

  # Carte avec fond IRC
  par(mfrow = c(1, 2))

  # IRC seul
  plotRGB(irc_rgb, r = 1, g = 2, b = 3, stretch = "lin",
          main = "Orthophoto IRC")

  # IRC + couronnes
  plotRGB(irc_rgb, r = 1, g = 2, b = 3, stretch = "lin",
          main = "IRC + Classification")
  plot(st_geometry(crowns_predicted),
       col = adjustcolor(species_colors[crowns_predicted$final_class], alpha = 0.5),
       border = "white", lwd = 0.5, add = TRUE)

  par(mfrow = c(1, 1))
}
```

#### 9.6 Export des résultats

```r
# Export GeoPackage
output_file <- file.path(tuto10_dir, "crowns_classified.gpkg")
st_write(crowns_predicted, output_file, delete_dsn = TRUE)
cat(sprintf("Résultats exportés: %s\n", output_file))

# Export modèle
model_file <- file.path(tuto10_dir, "rf_model.rds")
saveRDS(rf_final, model_file)
cat(sprintf("Modèle sauvegardé: %s\n", model_file))

# Statistiques de résumé
summary_stats <- crowns_predicted |>
  st_drop_geometry() |>
  group_by(final_class) |>
  summarise(
    n = n(),
    pct = n() / nrow(crowns_predicted) * 100,
    prob_mean = mean(pred_prob, na.rm = TRUE),
    prob_sd = sd(pred_prob, na.rm = TRUE)
  ) |>
  arrange(desc(n))

cat("\n=== Résumé classification ===\n")
print(summary_stats)
```

#### Exercice 9.1 : Identifier les erreurs potentielles

---

### Synthèse (15 min)

#### Workflow complet

```
┌─────────────────────────────────────────────────────────────────────┐
│              WORKFLOW CLASSIFICATION D'ESSENCES                     │
└─────────────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. DONNÉES D'ENTRÉE                                              │
  │   - Couronnes segmentées (Tutorial 07)                           │
  │   - Orthophoto IRC (IGN ou happign)                              │
  │   - Labels terrain (inventaire forestier)                        │
  │   - Nuages de points LiDAR normalisés                            │
  └─────────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────────────┐
  │ 2. FEATURE ENGINEERING                                           │
  │   - LiDAR : hauteurs, densités, strates, forme couronne          │
  │   - IRC : NDVI, ratios spectraux, statistiques zonales           │
  │   - Fusion des features (30-40 variables)                        │
  └─────────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────────────┐
  │ 3. VALIDATION SPATIALE                                           │
  │   - blockCV pour éviter fuite spatiale                           │
  │   - Estimation réaliste des performances                         │
  │   - Comparaison CV random vs spatial                             │
  └─────────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────────────┐
  │ 4. MODÉLISATION                                                  │
  │   - Baseline : Random Forest (ranger)                            │
  │   - Challenger : XGBoost                                         │
  │   - Tuning hyperparamètres                                       │
  │   - Importance variables                                         │
  └─────────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────────────┐
  │ 5. ÉVALUATION                                                    │
  │   - Accuracy, Balanced Accuracy, F1 macro, Kappa                 │
  │   - Matrice de confusion                                         │
  │   - Gestion incertitude (seuil probabilité)                      │
  └─────────────────────────────────────────────────────────────────┘
                          │
  ┌─────────────────────────────────────────────────────────────────┐
  │ 6. CARTOGRAPHIE                                                  │
  │   - Carte classes prédites                                       │
  │   - Carte probabilités (confiance)                               │
  │   - Export GeoPackage + modèle                                   │
  └─────────────────────────────────────────────────────────────────┘
```

#### Produits générés

| Fichier | Description | Usage |
|---------|-------------|-------|
| `result_classification/training_data.rds` | Dataset d'apprentissage | Checkpoint |
| `result_classification/rf_model.rds` | Modèle Random Forest entraîné | Prédiction |
| `result_classification/crowns_classified.gpkg` | Couronnes classifiées | SIG/QGIS |
| `result_classification/feature_cols.rds` | Liste des features | Prédiction |

#### Indicateurs nemeton concernés

| Indicateur | Lien avec classification |
|------------|--------------------------|
| B1, B3 | Richesse spécifique, composition |
| C1 | Biomasse par essence |
| P1, P3 | Volume, qualité bois par essence |
| T1 | Composition et âge par essence |

#### Recommandations pour aller plus loin

1. **Améliorer la segmentation**
   - Tester différents paramètres lidaRtRee
   - Post-traitement des sur/sous-segmentations

2. **Enrichir les features**
   - Ajouter Sentinel-2 red-edge
   - Utiliser la phénologie (multi-date)
   - Textures GLCM

3. **Améliorer les données terrain**
   - Plus de placettes de référence
   - Validation terrain des prédictions
   - Classes plus fines

4. **Modèles avancés**
   - Deep learning sur images (CNN)
   - Fusion multimodale
   - Semi-supervisé avec pseudo-labels

5. **Production**
   - Pipeline automatisé
   - Validation continue
   - Versioning des modèles

#### Check-list production

- [ ] Pipeline reproductible (set.seed, config)
- [ ] Validation spatiale utilisée
- [ ] Métriques réalistes (pas de fuite spatiale)
- [ ] Seuil d'incertitude défini et documenté
- [ ] Modèle sauvegardé (.rds)
- [ ] Export GeoPackage avec métadonnées
- [ ] Documentation des features utilisées
- [ ] Rapport de performance inclus

#### Quiz final (3 questions)

---

## Durée estimée

| Section | Durée |
|---------|-------|
| Bienvenue | 5 min |
| 1. Prérequis et environnement | 15 min |
| 2. Chargement des données | 20 min |
| 3. Segmentation couronnes | 15 min |
| 4. Feature engineering LiDAR | 30 min |
| 5. Feature engineering IRC | 25 min |
| 6. Assemblage dataset | 25 min |
| 7. Validation spatiale | 25 min |
| 8. Modélisation | 35 min |
| 9. Cartographie | 20 min |
| Synthèse | 15 min |
| **Total** | **~230 min (3h50)** |

## Dépendances packages

```r
# Obligatoires
library(sf)            # >= 1.0.0
library(terra)         # >= 1.7.0
library(exactextractr) # >= 0.8.0
library(dplyr)         # >= 1.1.0
library(tidyr)         # >= 1.3.0
library(ggplot2)       # >= 3.4.0
library(ranger)        # >= 0.14.0
library(xgboost)       # >= 1.7.0
library(blockCV)       # >= 3.0.0

# Optionnels
library(lidR)          # >= 4.0.0 (si segmentation)
library(lidaRtRee)     # >= 4.0.0 (si segmentation)
library(caret)         # Métriques alternatives
library(patchwork)     # Assemblage figures
library(happign)       # Téléchargement IGN
library(glcm)          # Textures (bonus)
library(FNN)           # k-NN pour blockCV
library(learnr)        # Framework tutoriel
library(gradethis)     # Validation exercices
```

## Critères d'acceptation

- [ ] Pipeline reproductible (set.seed, config, checkpoints)
- [ ] Mode offline fonctionnel (données synthétiques si pas de connexion)
- [ ] Contrôles qualité à chaque étape (CRS, NA, tailles échantillons)
- [ ] Comparaison CV standard vs blockCV documentée
- [ ] Au moins 2 modèles comparés (RF, XGBoost)
- [ ] Métriques multi-classes calculées (accuracy, F1 macro, kappa)
- [ ] Gestion de l'incertitude avec seuil documenté
- [ ] Export GeoPackage avec classes, probabilités, flag incertain
- [ ] Tous les quiz (9) et exercices fonctionnels
- [ ] Synthèse avec workflow, produits, recommandations

## Hors périmètre

- Deep learning / CNN sur images
- Classification multi-temporelle (phénologie)
- Segmentation sémantique pixel-wise
- Interface web / dashboard Shiny
- Benchmark exhaustif de méthodes
- Calibration intensité LiDAR
- Support multi-capteurs (drone, Sentinel-2)

## Notes d'implémentation

1. Forcer CRS projeté (EPSG:2154) dès l'entrée
2. Utiliser exactextractr pour toutes les extractions zonales (performant)
3. Gérer les erreurs avec tryCatch et messages explicites
4. Documenter chaque checkpoint pour reprise
5. Proposer mode "sans intensité" par défaut (plus robuste)
6. Privilégier ranger sur randomForest (plus rapide, probabilités)
7. Utiliser blockCV pour toute estimation de performance
