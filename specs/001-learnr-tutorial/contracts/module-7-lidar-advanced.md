# Contract: Module 7 - Traitement LiDAR Avancé

**Version**: 1.0
**Created**: 2026-01-11
**Status**: Draft

## Vue d'Ensemble

Ce module enseigne le traitement avancé de données LiDAR forestières en utilisant les packages `lidR`, `lasR` et `lidaRtRee`. Il s'appuie sur les tutoriels développés par l'INRAE (Jean-Matthieu Monnet) disponibles sur https://lidar.pages-forge.inrae.fr/lidaRtRee.

## Dépendances

### Packages R requis

```r
# Core LiDAR processing
lidR >= 4.1.1          # CRAN - traitement standard
lasR                   # r-universe - pipelines haute performance
lidaRtRee >= 4.0.9     # INRAE GitLab - fonctions forestières

# Support
terra >= 1.7.0         # Rasters
sf >= 1.0.0            # Vecteurs
future >= 1.33.0       # Parallélisation
```

### Installation

```r
# lidR (CRAN)
install.packages("lidR")

# lasR (r-universe only)
install.packages("lasR", repos = "https://r-lidar.r-universe.dev")

# lidaRtRee (INRAE GitLab)
remotes::install_gitlab("lidar/lidaRtRee", host = "forge.inrae.fr")
```

### Données d'entrée

Depuis Tutorial 01 :
- Fichiers LiDAR HD (.laz ou .copc.laz) dans `data_dir/lidar_hd/`
- Zone d'étude (`zone_etude.gpkg`)
- Parcelles (`parcelles.gpkg`)

Données supplémentaires (fournies ou téléchargées) :
- Placettes terrain avec mesures dendrométriques (pour calibration ABA)

## Section 1: Introduction LAScatalog

### Objectifs
- Comprendre le concept de catalogue LiDAR
- Configurer les options de traitement par tuiles
- Gérer les buffers pour éviter les effets de bord

### Fonctions principales

```r
# Création catalogue
ctg <- lidR::readLAScatalog(folder)

# Options de traitement
lidR::opt_chunk_size(ctg) <- 500        # Taille tuiles (m)
lidR::opt_chunk_buffer(ctg) <- 30       # Buffer (m)
lidR::opt_output_files(ctg) <- template # Template sortie
lidR::opt_laz_compression(ctg) <- TRUE  # Compression
lidR::opt_progress(ctg) <- TRUE         # Barre progression

# Parallélisation
future::plan(future::multisession, workers = 4)
lidR::opt_parallel_strategy(ctg) <- "multisession"
```

### Exercice type

```r
# Créer un catalogue et configurer les options
data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
fichiers_laz <- list.files(file.path(data_dir, "lidar_hd"),
                           pattern = "\\.laz$", full.names = TRUE)

ctg <- readLAScatalog(fichiers_laz)
opt_chunk_size(ctg) <- 500
opt_chunk_buffer(ctg) <- 30
opt_output_files(ctg) <- file.path(data_dir, "processed/{XLEFT}_{YBOTTOM}")

# Afficher les infos du catalogue
print(ctg)
plot(ctg)
```

## Section 2: Pipelines lasR

### Objectifs
- Créer des pipelines de traitement optimisés
- Chaîner plusieurs opérations efficacement
- Comparer performances lidR vs lasR

### Fonctions principales

```r
# Création pipeline
pipeline <- lasR::reader_las(filter = "-drop_z_below 0") +
  lasR::triangulate(filter = lasR::keep_ground()) +
  lasR::rasterize(res = 1, operators = "max") +
  lasR::write_las()

# Exécution
lasR::exec(pipeline, on = fichiers_laz, ncores = 4)
```

### Exercice type

```r
# Pipeline complet: MNT + MNH + Métriques
pipeline <- lasR::reader_las() +
  # MNT depuis points sol
  lasR::triangulate(filter = lasR::keep_ground()) +
  lasR::rasterize(res = 1, file = file.path(data_dir, "mnt_lidar.tif")) +
  # MNH
  lasR::normalize() +
  lasR::rasterize(res = 1, operators = "max",
                  file = file.path(data_dir, "mnh_lidar.tif")) +
  # Métriques
  lasR::rasterize(res = 30, operators = c("max", "mean", "sd", "p95"),
                  file = file.path(data_dir, "metriques_30m.tif"))

lasR::exec(pipeline, on = fichiers_laz, ncores = 4)
```

## Section 3: Segmentation Arbres Individuels

### Objectifs
- Détecter les cimes d'arbres
- Segmenter les couronnes
- Extraire les attributs individuels

### Principe

La **segmentation d'arbres individuels** (ITD - Individual Tree Detection) permet d'identifier et caractériser chaque arbre à partir du nuage de points LiDAR. Avec **lasR**, le traitement se fait via un pipeline optimisé qui inclut une étape critique de **normalisation** :

1. **Triangulation sol** : maillage TIN des points sol (`triangulate(keep_ground())`)
2. **Rasterisation DTM** : génération du MNT (`rasterize()`)
3. **Normalisation** : conversion altitude → hauteur (`transform_with(dtm_tri)`)
4. **Triangulation premiers retours** : maillage TIN normalisé (`triangulate(keep_first())`)
5. **Rasterisation CHM** : génération du MNH haute résolution (`rasterize()`)
6. **Remplissage des puits** : correction des artefacts (`pit_fill()`)
7. **Détection des maxima locaux** : identification des cimes (`local_maximum_raster()`)
8. **Croissance de région** : délimitation des houppiers (`region_growing()`)

```
                    Pipeline ITD lasR avec Normalisation

  Nuage LiDAR ──► triangulate(ground) ──► rasterize() ──► DTM (altitude sol)
  (Z=altitude)          (TIN sol)            (1m)              │
                                                               │
                        transform_with(dtm_tri) ◄──────────────┘
                         (Z = Z - DTM = hauteur)
                                  │
                                  ▼
                    triangulate(first) ──► rasterize() ──► pit_fill()
                      (TIN normalisé)        (0.5m)        (CHM lissé)
                                                               │
                                                               ▼
                   region_growing() ◄── local_maximum_raster()
                     (houppiers)              (cimes)
                          │                      │
                          ▼                      ▼
                    crowns_*.tif           seeds_*.gpkg
```

**Point clé - Normalisation TIN vs Raster** :
- La normalisation utilise la **triangulation TIN** (`transform_with(dtm_tri)`) et non le raster DTM
- Avantage : interpolation exacte pour chaque point, pas d'artefacts de discrétisation
- Après normalisation : Z représente la **hauteur** (ex: 25m) et non l'**altitude** (ex: 1200m)

**Gestion des effets de bord** :
- Les arbres à la frontière entre tuiles sont mal segmentés sans buffer
- Solution : `buffer = 20` mètres (diamètre max des houppiers)
- lasR déduplique automatiquement les résultats dans les zones de recouvrement

### Fonctions principales

```r
# Pipeline lasR avec normalisation (recommandé pour gros volumes)
library(lasR)
dtm_tri <- triangulate(filter = keep_ground())
dtm <- rasterize(1, dtm_tri, ofile = "dtm_*.tif")
normalize <- transform_with(dtm_tri)  # Utilise TIN, pas raster
chm_tri <- triangulate(filter = keep_first())
chm <- rasterize(0.5, chm_tri, ofile = "chm_*.tif")
chm_filled <- pit_fill(chm, ofile = "chm_filled_*.tif")
seeds <- local_maximum_raster(chm_filled, ws = 3, min_height = 5)
tree <- region_growing(chm_filled, seeds, ofile = "crowns_*.tif")

pipeline <- reader_las() + dtm_tri + dtm + normalize +
            chm_tri + chm + chm_filled + seeds + tree
exec(pipeline, on = ctg, buffer = 20, ncores = concurrent_files(4))

# Alternative lidR (pour petits jeux de données)
ttops <- lidR::locate_trees(las, algorithm = lidR::lmf(ws = 5))
las_seg <- lidR::segment_trees(las, algorithm = lidR::dalponte2016(chm, ttops))
```

### Exercice type

```r
# Pipeline lasR complet avec normalisation
library(lasR)

# 1. DTM via triangulation sol
dtm_tri <- triangulate(filter = keep_ground())
dtm <- rasterize(1, dtm_tri, ofile = file.path(result_itd, "dtm_*.tif"))

# 2. Normalisation (Z altitude → Z hauteur) via TIN
normalize <- transform_with(dtm_tri)

# 3. CHM via triangulation premiers retours normalisés
chm_tri <- triangulate(filter = keep_first())
chm <- rasterize(0.5, chm_tri, ofile = file.path(result_itd, "chm_*.tif"))
chm_filled <- pit_fill(chm, ofile = file.path(result_itd, "chm_filled_*.tif"))

# 4. Détection et segmentation
seeds <- local_maximum_raster(chm_filled, ws = 3, min_height = 5,
                              ofile = file.path(result_itd, "seeds_*.gpkg"))
tree <- region_growing(chm_filled, seeds,
                       ofile = file.path(result_itd, "crowns_*.tif"))

# Pipeline complet
pipeline <- reader_las() + dtm_tri + dtm + normalize +
            chm_tri + chm + chm_filled + seeds + tree

# Exécution avec buffer pour effets de bord
exec(pipeline, on = ctg, buffer = 20, ncores = concurrent_files(4))
```

### Métriques extraites

| Métrique | Description | Usage |
|----------|-------------|-------|
| `treeID` | Identifiant arbre | - |
| `X`, `Y` | Position cime | Cartographie |
| `Z` | Hauteur totale | P1, C1 |
| `npoints` | Nombre points | Qualité |
| `convhull_area` | Surface couronne | P3 |

## Section 4: Trouées et Lisières

### Objectifs
- Détecter les trouées forestières (gaps)
- Caractériser les lisières (edges)
- Quantifier la structure horizontale

### Fonctions principales (lidaRtRee)

```r
# Détection trouées
gaps <- lidaRtRee::gap_detection(
  chm,
  height_threshold = 2,
  min_area = 25
)

# Détection lisières
edges <- lidaRtRee::edge_detection(
  chm,
  forest_threshold = 5,
  edge_width = 15
)
```

### Exercice type

```r
# Charger MNH
mnh <- rast(file.path(data_dir, "mnh_lidar.tif"))

# Détecter les trouées (zones < 2m de hauteur, > 25m²)
gaps <- gap_detection(mnh, height_threshold = 2, min_area = 25)

# Calculer métriques par trouée
gap_metrics <- data.frame(
  gap_id = gaps$gap_id,
  area_m2 = gaps$area,
  perimeter_m = gaps$perimeter,
  shape_index = gaps$perimeter / (2 * sqrt(pi * gaps$area))
)

# Détecter les lisières
edges <- edge_detection(mnh, forest_threshold = 5, edge_width = 15)

# Exporter
st_write(gaps, file.path(data_dir, "gaps.gpkg"))
st_write(edges, file.path(data_dir, "edges.gpkg"))
```

### Métriques pour indicateurs

| Produit | Métrique | Indicateur nemeton |
|---------|----------|-------------------|
| Gaps | `gap_fraction` (% surface) | B2 (structure) |
| Gaps | `gap_density` (n/ha) | B2 (hétérogénéité) |
| Edges | `edge_length` (m/ha) | L1 (lisière) |
| Edges | `edge_contrast` | L1 (intensité) |

## Section 5: Métriques de Structure Forestière

### Objectifs
- Calculer les métriques de hauteur avancées
- Extraire les métriques par strates verticales
- Générer des rasters multi-bandes

### Fonctions principales

```r
# Métriques standard (lidR)
metrics <- lidR::pixel_metrics(las, func = .stdmetrics, res = 30)

# Métriques forestières (lidaRtRee)
forest_metrics <- lidaRtRee::forest_metrics(
  las,
  res = 30,
  metrics = c("height", "density", "strata", "cover")
)
```

### Métriques calculées

| Groupe | Métriques | Description |
|--------|-----------|-------------|
| Hauteur | `zmax`, `zmean`, `zsd`, `zq25/50/75/95` | Statistiques hauteurs |
| Densité | `n`, `n_above2m`, `pzabove2` | Points et couverture |
| Strates | `strata_0_2`, `strata_2_5`, `strata_5_15`, `strata_15+` | % par strate |
| Structure | `zentropy`, `zskew`, `zkurt` | Forme distribution |

### Exercice type

```r
# Métriques complètes par parcelle
my_metrics <- function(z, rn, i) {
  list(
    # Hauteurs
    zmax = max(z), zmean = mean(z), zsd = sd(z),
    zq25 = quantile(z, 0.25), zq50 = quantile(z, 0.50),
    zq75 = quantile(z, 0.75), zq95 = quantile(z, 0.95),
    # Couverture
    n = length(z), pzabove2 = sum(z > 2) / length(z),
    # Strates
    strata_0_2 = sum(z <= 2) / length(z),
    strata_2_5 = sum(z > 2 & z <= 5) / length(z),
    strata_5_15 = sum(z > 5 & z <= 15) / length(z),
    strata_15_plus = sum(z > 15) / length(z),
    # Structure
    zentropy = -sum(table(cut(z, breaks = seq(0, max(z)+1, by = 1))) /
                    length(z) * log(table(cut(z, breaks = seq(0, max(z)+1, by = 1))) /
                    length(z) + 0.001))
  )
}

metrics_raster <- pixel_metrics(las, ~my_metrics(Z, ReturnNumber, Intensity), res = 30)
writeRaster(metrics_raster, file.path(data_dir, "metriques_structure.tif"))
```

## Section 6: BABA (Buffered Area-Based Approach)

### Objectifs
- Comprendre la différence entre ABA classique et BABA
- Générer des métriques haute résolution avec fenêtre glissante
- Calibrer des modèles prédictifs compatibles placettes terrain
- Produire des cartes de volume/biomasse à résolution fine (10m)

### Concept BABA vs ABA classique

**Problème de l'ABA classique** :
- Résolution de sortie = taille de fenêtre (ex: 20m)
- Impossible d'avoir une cartographie fine sans perdre la validité des métriques

**Solution BABA** :
- Dissocie résolution de sortie et taille de fenêtre
- Utilise une fenêtre glissante (moving window) avec recouvrement
- Résolution fine (10m) + fenêtre compatible placettes (20m = 400m²)

```
ABA classique:     BABA:
┌───┬───┬───┐      ┌─┬─┬─┬─┬─┬─┐
│   │   │   │      ├─┼─┼─┼─┼─┼─┤  Résolution 10m
│20m│20m│20m│  vs  ├─┼─┼─┼─┼─┼─┤  mais fenêtre 20m
│   │   │   │      ├─┼─┼─┼─┼─┼─┤  avec recouvrement
└───┴───┴───┘      └─┴─┴─┴─┴─┴─┘
```

### Workflow BABA (3 étapes)

#### 6.1 Génération métriques BABA avec lasR

```r
# Pipeline BABA avec lasR
# Résolution sortie: 10m, Fenêtre calcul: 20m
pipeline_baba <- lasR::reader_las() +
  lasR::rasterize(
    res = c(10, 20),  # c(résolution_sortie, taille_fenêtre)
    operators = c("max", "mean", "sd", "p95", "above2")
  )

# Exécution sur catalogue
lasR::exec(pipeline_baba,
           on = fichiers_laz,
           ncores = 4,
           output = file.path(data_dir, "metriques_baba.tif"))
```

**Paramètres clés** :
- `res = c(10, 20)` : sortie 10m, fenêtre 20×20m (400m²)
- Les fenêtres se chevauchent → effet moving window
- Métriques comparables aux placettes terrain IFN

#### 6.2 Extraction sur placettes et calibration

```r
# Charger métriques BABA
metriques_baba <- rast(file.path(data_dir, "metriques_baba.tif"))
placettes <- st_read(file.path(data_dir, "placettes_terrain.gpkg"))

# Extraire métriques sur placettes (buffer = rayon placette)
metrics_placettes <- exactextractr::exact_extract(
  metriques_baba,
  st_buffer(placettes, 10),  # Buffer 10m = 20m diamètre
  fun = "mean"
)

# Joindre données terrain
training_data <- cbind(placettes, metrics_placettes)

# Modèle volume (régression log)
model_volume <- lm(log(volume_ha) ~ zq95 + pzabove2 + zsd,
                   data = training_data)

# Modèle biomasse
model_biomasse <- lm(log(biomasse_ha) ~ zq95 + zmean + pzabove2,
                     data = training_data)

# Validation croisée (10-fold)
library(caret)
cv_ctrl <- trainControl(method = "cv", number = 10)
cv_volume <- train(log(volume_ha) ~ zq95 + pzabove2 + zsd,
                   data = training_data,
                   method = "lm",
                   trControl = cv_ctrl)
cat("R² validation croisée:", round(cv_volume$results$Rsquared, 3), "\n")
```

#### 6.3 Prédiction spatiale haute résolution

```r
# Charger raster métriques BABA (10m résolution)
metriques_baba <- rast(file.path(data_dir, "metriques_baba.tif"))
names(metriques_baba) <- c("zmax", "zmean", "zsd", "zq95", "pzabove2")

# Prédiction volume (back-transform depuis log)
pred_volume <- terra::predict(metriques_baba, model_volume,
                              fun = function(model, newdata) {
                                exp(predict(model, newdata))
                              })

# Prédiction biomasse
pred_biomasse <- terra::predict(metriques_baba, model_biomasse,
                                fun = function(model, newdata) {
                                  exp(predict(model, newdata))
                                })

# Sauvegarder (résolution 10m!)
writeRaster(pred_volume,
            file.path(data_dir, "predictions_volume_10m.tif"),
            overwrite = TRUE)
writeRaster(pred_biomasse,
            file.path(data_dir, "predictions_biomasse_10m.tif"),
            overwrite = TRUE)

# Visualisation
plot(pred_volume, main = "Volume prédit (m³/ha) - BABA 10m")
```

### Avantages BABA pour nemeton

| Aspect | ABA classique | BABA |
|--------|--------------|------|
| Résolution sortie | 20m | **10m** |
| Fenêtre calcul | 20m | 20m |
| Compatibilité placettes | ✓ | ✓ |
| Détail cartographique | Faible | **Élevé** |
| Indicateurs nemeton | OK | **Meilleur** |

### Métriques BABA pour indicateurs nemeton

```r
# Pipeline BABA complet pour nemeton
pipeline_nemeton <- lasR::reader_las() +
  # Métriques hauteur (C1, P1, P3)
  lasR::rasterize(c(10, 20), c("max", "mean", "sd", "p95"),
                  ofile = "height_metrics.tif") +
  # Couverture canopée (A1)
  lasR::rasterize(c(10, 20), "above2",
                  ofile = "canopy_cover.tif") +
  # Densité points (qualité données)
  lasR::rasterize(c(10, 20), "count",
                  ofile = "point_density.tif")

lasR::exec(pipeline_nemeton, on = fichiers_laz, ncores = 4)
```

## Section 7: Coregistration Placettes Terrain

### Objectifs
- Aligner les placettes terrain avec le MNH
- Optimiser la translation XY
- Valider l'alignement

### Fonctions principales (lidaRtRee)

```r
# Coregistration automatique
result <- lidaRtRee::coregistration(
  plots = placettes,
  chm = mnh,
  method = "correlation",
  search_radius = 20
)

# Appliquer correction
placettes_corr <- st_set_geometry(
  placettes,
  st_geometry(placettes) + c(result$dx, result$dy)
)
```

### Exercice type

```r
# Charger données
placettes <- st_read(file.path(data_dir, "placettes_terrain.gpkg"))
mnh <- rast(file.path(data_dir, "mnh_lidar.tif"))

# Coregistration
coreg <- coregistration(placettes, mnh, method = "correlation", search_radius = 20)

# Afficher résultats
cat("Translation optimale: dx =", coreg$dx, "m, dy =", coreg$dy, "m\n")
cat("Corrélation avant:", coreg$cor_before, "\n")
cat("Corrélation après:", coreg$cor_after, "\n")

# Appliquer et sauvegarder
placettes_corr <- st_set_geometry(placettes, st_geometry(placettes) + c(coreg$dx, coreg$dy))
st_write(placettes_corr, file.path(data_dir, "placettes_coregistrees.gpkg"))
```

## Section 8: Produits Dérivés pour Indicateurs nemeton

### Objectifs
- Générer MNT haute résolution depuis LiDAR sol
- Calculer pente, exposition, TWI
- Exporter métriques au format compatible T05-T06

### Produits terrain depuis MNT LiDAR

```r
# Charger MNT LiDAR
mnt <- rast(file.path(data_dir, "mnt_lidar.tif"))

# Calculs topographiques
pente <- terra::terrain(mnt, v = "slope", unit = "degrees")
exposition <- terra::terrain(mnt, v = "aspect", unit = "degrees")

# TWI (Topographic Wetness Index)
flow_acc <- terra::terrain(mnt, v = "flowdir")
# ... calcul TWI simplifié
twi <- log((flow_acc + 1) / tan(pente * pi / 180 + 0.001))

# Sauvegarder
writeRaster(pente, file.path(data_dir, "pente.tif"), overwrite = TRUE)
writeRaster(exposition, file.path(data_dir, "exposition.tif"), overwrite = TRUE)
writeRaster(twi, file.path(data_dir, "twi_lidar.tif"), overwrite = TRUE)
```

### Export unifié pour nemeton

```r
# Charger parcelles
parcelles <- st_read(file.path(data_dir, "parcelles.gpkg"))

# Extraire toutes les métriques par parcelle
extract_nemeton_metrics <- function(parcelles) {
  # Métriques LiDAR
  metrics_lidar <- exactextractr::exact_extract(
    rast(file.path(data_dir, "metriques_structure.tif")),
    parcelles, fun = "mean"
  )

  # Métriques terrain
  metrics_terrain <- data.frame(
    slope_mean = exactextractr::exact_extract(pente, parcelles, "mean"),
    aspect_mean = exactextractr::exact_extract(exposition, parcelles, "mean"),
    twi_mean = exactextractr::exact_extract(twi, parcelles, "mean")
  )

  # Métriques arbres
  arbres <- st_read(file.path(data_dir, "arbres_segmentes.gpkg"))
  tree_stats <- arbres %>%
    st_join(parcelles) %>%
    group_by(id_parcelle) %>%
    summarise(
      tree_count = n(),
      tree_height_mean = mean(Z),
      tree_height_max = max(Z)
    )

  # Assembler
  cbind(parcelles, metrics_lidar, metrics_terrain) %>%
    left_join(st_drop_geometry(tree_stats), by = "id_parcelle")
}

result <- extract_nemeton_metrics(parcelles)
st_write(result, file.path(data_dir, "derivees_lidar_nemeton.gpkg"))
```

### Mapping vers indicateurs nemeton

| Colonne export | Indicateur | Formule/Usage |
|----------------|------------|---------------|
| `zq95` | C1, P1 | Hauteur dominante |
| `pzabove2` | A1 | Couverture canopée |
| `tree_count` | P1, E1 | Densité tiges |
| `strata_*` | B2 | Structure verticale |
| `gap_fraction` | B2, L1 | Hétérogénéité |
| `slope_mean` | W1, R1, F1 | Pente moyenne |
| `aspect_mean` | R2 | Exposition |
| `twi_mean` | W1 | Humidité topographique |
| `pred_volume` | P1 | Volume calibré ABA |
| `pred_biomasse` | C1 | Biomasse calibrée ABA |

## Validation

### Tests unitaires

```r
# Test création catalogue
test_that("LAScatalog creation works", {
  ctg <- readLAScatalog(test_files)
  expect_s4_class(ctg, "LAScatalog")
  expect_gt(length(ctg), 0)
})

# Test segmentation arbres
test_that("Tree segmentation works", {
  trees <- tree_segmentation(test_las)
  expect_s3_class(trees, "sf")
  expect_true("Z" %in% names(trees))
})
```

### Métriques de succès

- LAScatalog traite > 10 tuiles sans erreur
- Segmentation détecte arbres avec hauteur > 2m
- Modèles ABA : R² > 0.7 en validation croisée
- Export compatible avec T05-T06

## Références

- lidaRtRee documentation: https://lidar.pages-forge.inrae.fr/lidaRtRee
- lidR book: https://r-lidar.github.io/lidRbook/
- lasR documentation: https://r-lidar.github.io/lasR/
- Monnet, J.-M. (2023). lidaRtRee: Forest analysis with airborne LiDAR. INRAE.
