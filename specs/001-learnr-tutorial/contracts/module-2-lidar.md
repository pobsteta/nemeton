# Module 2 API Contract: Acquisition et Traitement LiDAR HD

**Module**: Tutorial Module 2 - Acquisition et Traitement LiDAR HD
**Feature**: 001-learnr-tutorial
**User Story**: US2 (P1)

## Overview

Ce module enseigne l'acquisition et le traitement des données LiDAR HD IGN pour extraire des métriques dendrométriques forestières :
- Téléchargement dalles LiDAR HD via lidarHD
- Chargement et visualisation nuages de points (lidR)
- Normalisation hauteurs (MNT)
- Extraction métriques par parcelle (P95, densité, couvert)
- Génération Modèle Numérique de Hauteur (MNH)

**Pédagogie** : Workflow LiDAR complet avec exercices progressifs et validation automatique.

---

## Exercice 2.1 : Téléchargement LiDAR HD

### Objectif Pédagogique
L'utilisateur apprend à télécharger les dalles LiDAR HD IGN pour l'emprise de ses parcelles.

### Inputs de l'exercice
- `parcelles` : objet sf des parcelles (Module 1)
- `output_dir` : répertoire de sortie (optionnel)

### Code attendu de l'utilisateur
```r
# Télécharger dalles LiDAR HD pour emprise parcelles
lidar_files <- tutorial_download_lidar(
  parcels = parcelles,
  output_dir = "data/lidar"
)

# Afficher dalles téléchargées
print(lidar_files)
```

### Outputs attendus
- `lidar_files` : vecteur de chemins vers fichiers LAZ téléchargés
- Format : LAZ (compressé)
- Emprise : couvre toutes les parcelles
- Nombre de dalles : dépend de la zone (typiquement 5-15 pour CIRON)

### Validation gradethis
```r
grade_result(
  pass_if(~ is.character(.result) && length(.result) > 0,
          "Excellent ! Dalles LiDAR HD téléchargées."),
  fail_if(~ !is.character(.result),
          "Le résultat doit être un vecteur de chemins de fichiers."),
  pass_if(~ all(file.exists(.result)),
          "Tous les fichiers LAZ existent."),
  fail_if(~ !all(file.exists(.result)),
          "Certains fichiers LAZ sont manquants. Vérifiez le téléchargement."),
  pass_if(~ all(grepl("\\.laz$", .result, ignore.case = TRUE)),
          "Format LAZ correct.")
)
```

### Fallback si API échoue
Si `tutorial_download_lidar()` échoue, bascule sur données demo :
```r
cli::cli_alert_warning("LiDAR HD indisponible, chargement données demo CIRON")
load_demo_lidar()
```

### Concepts enseignés
- LiDAR HD IGN (Lidar Haute Densité)
- Format LAZ (compression LASzip)
- Dalles et tuiles LiDAR
- Couverture spatiale

---

## Exercice 2.2 : Chargement et Visualisation Nuage de Points

### Objectif Pédagogique
L'utilisateur apprend à charger et visualiser un nuage de points LiDAR avec lidR.

### Inputs de l'exercice
- `lidar_files` : chemins vers fichiers LAZ (exercice 2.1)
- `parcelles` : objet sf des parcelles (pour découpe)

### Code attendu de l'utilisateur
```r
# Charger catalogue LiDAR
ctg <- lidR::readLAScatalog(lidar_files)

# Découper sur emprise parcelles
las <- lidR::clip_roi(ctg, parcelles)

# Visualiser nuage de points
lidR::plot(las, color = "Z", bg = "white")

# Statistiques
print(las)
summary(las$Z)  # Distribution hauteurs
```

### Outputs attendus
- `las` : objet `LAS` (classe lidR)
- Champs minimaux : X, Y, Z, Classification
- Emprise : couvre les parcelles
- Points : plusieurs millions selon zone

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "LAS"),
          "Parfait ! Nuage de points chargé."),
  fail_if(~ !inherits(.result, "LAS"),
          "Le résultat doit être un objet LAS (package lidR)."),
  pass_if(~ length(.result@data$Z) > 1000,
          "Nombre de points suffisant."),
  fail_if(~ length(.result@data$Z) < 1000,
          "Trop peu de points. Vérifiez l'emprise et le chargement."),
  pass_if(~ all(c("X", "Y", "Z") %in% names(.result@data)),
          "Coordonnées X, Y, Z présentes.")
)
```

### Concepts enseignés
- Objet LAS (lidR)
- Catalogue LAScatalog (gestion multi-dalles)
- Classification LiDAR (sol, végétation)
- Visualisation 3D nuage de points

---

## Exercice 2.3 : Normalisation Hauteurs avec MNT

### Objectif Pédagogique
L'utilisateur apprend à normaliser les hauteurs LiDAR par rapport au sol (MNT) pour obtenir les hauteurs arbres.

### Inputs de l'exercice
- `las` : objet LAS (exercice 2.2)
- `mnt` : SpatRaster MNT (Module 1)

### Code attendu de l'utilisateur
```r
# Normaliser hauteurs en utilisant le MNT
las_norm <- lidR::normalize_height(las, algorithm = lidR::tin())

# Filtrer points végétation (hauteur > 2m)
las_veg <- lidR::filter_poi(las_norm, Z >= 2)

# Visualiser hauteurs normalisées
lidR::plot(las_norm, color = "Z", bg = "white")

# Distribution hauteurs
hist(las_norm$Z, breaks = 50, main = "Distribution hauteurs normalisées",
     xlab = "Hauteur (m)", col = "forestgreen")
```

### Outputs attendus
- `las_norm` : objet LAS avec hauteurs normalisées
- Valeurs Z : hauteurs au-dessus du sol (0 = sol)
- `las_veg` : sous-ensemble végétation (Z >= 2m)

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "LAS"),
          "Super ! Hauteurs normalisées."),
  pass_if(~ min(.result@data$Z, na.rm = TRUE) >= 0,
          "Normalisation correcte : hauteurs >= 0."),
  fail_if(~ min(.result@data$Z, na.rm = TRUE) < -5,
          "Erreur normalisation : hauteurs négatives. Vérifiez le MNT."),
  pass_if(~ max(.result@data$Z, na.rm = TRUE) < 100,
          "Hauteurs réalistes (< 100m)."),
  fail_if(~ max(.result@data$Z, na.rm = TRUE) > 100,
          "Hauteurs aberrantes. Vérifiez la normalisation.")
)
```

### Concepts enseignés
- Normalisation hauteurs (MNH = MNS - MNT)
- Algorithme TIN (Triangulated Irregular Network)
- Filtrage points végétation
- Hauteurs relatives vs absolues

---

## Exercice 2.4 : Extraction Métriques par Parcelle

### Objectif Pédagogique
L'utilisateur apprend à extraire des métriques dendrométriques par parcelle forestière (P95, densité, couvert).

### Inputs de l'exercice
- `las_norm` : objet LAS normalisé (exercice 2.3)
- `parcelles` : objet sf des parcelles (Module 1)

### Code attendu de l'utilisateur
```r
# Extraire métriques par parcelle
metriques <- lidR::pixel_metrics(
  las = las_norm,
  func = ~list(
    P95 = quantile(Z, 0.95, na.rm = TRUE),    # Percentile 95 hauteur
    density = length(Z) / (30*30),             # Densité points/m²
    cover = sum(Z > 2) / length(Z)             # Couvert végétal
  ),
  res = 30
)

# Agréger par parcelle
parcelles_metrics <- exactextractr::exact_extract(
  metriques,
  parcelles,
  fun = "mean",
  append_cols = "id_parcel"
)

# Visualiser
plot(metriques$P95, main = "Hauteur dominante (P95) - CIRON")
plot(st_geometry(parcelles), add = TRUE, border = "red")
```

### Outputs attendus
- `metriques` : SpatRaster avec 3 couches (P95, density, cover)
- Résolution : 30m x 30m (ou 10m selon exercice)
- `parcelles_metrics` : data.frame avec métriques moyennes par parcelle
- Colonnes : `id_parcel`, `mean.P95`, `mean.density`, `mean.cover`

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "data.frame"),
          "Excellent ! Métriques extraites par parcelle."),
  pass_if(~ "mean.P95" %in% names(.result),
          "Métrique P95 présente."),
  fail_if(~ !"mean.P95" %in% names(.result),
          "Métrique P95 manquante. Vérifiez pixel_metrics()."),
  pass_if(~ all(.result$mean.P95 > 0 & .result$mean.P95 < 50),
          "Hauteurs P95 réalistes (0-50m)."),
  fail_if(~ any(.result$mean.P95 < 0 | .result$mean.P95 > 50),
          "Hauteurs P95 aberrantes. Vérifiez la normalisation."),
  pass_if(~ all(.result$mean.cover >= 0 & .result$mean.cover <= 1),
          "Couvert végétal réaliste (0-1).")
)
```

### Concepts enseignés
- Métriques dendrométriques (P95, densité, couvert)
- Percentile 95 (hauteur dominante)
- Agrégation zonale (pixel_metrics + exact_extract)
- Résolution spatiale pour métriques

---

## Exercice 2.5 : Génération Modèle Numérique de Hauteur (MNH)

### Objectif Pédagogique
L'utilisateur apprend à générer un MNH haute résolution à partir du nuage de points LiDAR.

### Inputs de l'exercice
- `las_norm` : objet LAS normalisé (exercice 2.3)

### Code attendu de l'utilisateur
```r
# Générer MNH résolution 1m
mnh <- lidR::rasterize_canopy(
  las = las_norm,
  res = 1,
  algorithm = lidR::p2r(subcircle = 0.2)  # Point-to-raster
)

# Visualiser MNH
terra::plot(mnh, main = "Modèle Numérique de Hauteur - CIRON",
            col = terrain.colors(50))
plot(st_geometry(parcelles), add = TRUE, border = "red", lwd = 2)

# Statistiques
summary(terra::values(mnh))
```

### Outputs attendus
- `mnh` : SpatRaster hauteur canopée
- Résolution : 1m x 1m
- Valeurs : hauteurs végétation (0-50m)
- Valeurs NA : zones sans végétation

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "SpatRaster"),
          "Parfait ! MNH généré."),
  pass_if(~ terra::res(.result)[1] == 1,
          "Résolution 1m correcte."),
  fail_if(~ terra::res(.result)[1] != 1,
          "Résolution incorrecte. Utilisez res = 1."),
  pass_if(~ max(terra::values(.result), na.rm = TRUE) < 50,
          "Hauteurs MNH réalistes."),
  pass_if(~ terra::global(.result, "notNA")[1,1] > 0,
          "MNH avec données valides.")
)
```

### Concepts enseignés
- MNH (Modèle Numérique de Hauteur)
- Algorithme point-to-raster
- Résolution spatiale (1m vs 5m)
- Rasterisation nuage de points

---

## Quiz de Validation Module 2

### Question 1 : Format LAZ
**Question** : Quel est l'avantage principal du format LAZ par rapport au format LAS ?

- A) Meilleure précision des coordonnées
- B) Compression lossless (sans perte) ✓
- C) Support de plus de classes
- D) Lecture plus rapide

**Feedback** : LAZ offre une compression 5-10:1 sans perte de données, réduisant la taille de stockage.

### Question 2 : Normalisation Hauteurs
**Question** : Pourquoi normaliser les hauteurs LiDAR par rapport au sol ?

- A) Pour réduire la taille des fichiers
- B) Pour obtenir les hauteurs de végétation au-dessus du sol ✓
- C) Pour corriger les erreurs GPS
- D) Pour filtrer le bruit

**Feedback** : La normalisation (Z_norm = Z_abs - Z_sol) donne les hauteurs arbres.

### Question 3 : Percentile P95
**Question** : Que représente le percentile P95 en dendrométrie forestière ?

- A) L'âge moyen des arbres
- B) La hauteur dominante de la parcelle ✓
- C) La densité de points LiDAR
- D) Le couvert végétal

**Feedback** : P95 = hauteur en-dessous de laquelle se trouvent 95% des points (hauteur dominante robuste).

---

## Résumé des Fonctions Utilisées

### Fonctions tutorial helpers
- `tutorial_download_lidar(parcels, output_dir, timeout, verbose)`
- `load_demo_lidar()` (fallback)

### Fonctions lidR principales
- `readLAScatalog()`, `clip_roi()`
- `normalize_height(las, algorithm = tin())`
- `filter_poi(las, condition)`
- `pixel_metrics(las, func, res)`
- `rasterize_canopy(las, res, algorithm = p2r())`
- `plot.LAS()`

### Fonctions auxiliaires
- `exactextractr::exact_extract()` (agrégation zonale)
- `terra::crop()`, `terra::mask()`, `terra::plot()`

### Validation
- `validate_lidar_metrics(parcelles_metrics)` (vérifie P95, densité, couvert)

---

## Tests Attendus (Post-Exercices)

### Test 1 : Téléchargement LiDAR
```r
testthat::test_that("Dalles LiDAR HD téléchargées", {
  parcelles <- load_demo_cadastre()
  lidar_files <- tutorial_download_lidar(parcelles)

  expect_true(is.character(lidar_files))
  expect_gt(length(lidar_files), 0)
  expect_true(all(file.exists(lidar_files)))
  expect_true(all(grepl("\\.laz$", lidar_files, ignore.case = TRUE)))
})
```

### Test 2 : Chargement nuage de points
```r
testthat::test_that("Nuage de points LiDAR chargé", {
  lidar_files <- load_demo_lidar()
  las <- lidR::readLAS(lidar_files[1])

  expect_s4_class(las, "LAS")
  expect_true(all(c("X", "Y", "Z") %in% names(las@data)))
  expect_gt(length(las@data$Z), 1000)
})
```

### Test 3 : Normalisation hauteurs
```r
testthat::test_that("Normalisation hauteurs correcte", {
  las <- lidR::readLAS(load_demo_lidar()[1])
  las_norm <- lidR::normalize_height(las, algorithm = lidR::tin())

  expect_s4_class(las_norm, "LAS")
  expect_gte(min(las_norm@data$Z, na.rm = TRUE), 0)
  expect_lt(max(las_norm@data$Z, na.rm = TRUE), 100)
})
```

### Test 4 : Métriques par parcelle
```r
testthat::test_that("Métriques dendrométriques extraites", {
  las_norm <- lidR::readLAS(load_demo_lidar()[1])
  parcelles <- load_demo_cadastre()

  metriques <- lidR::pixel_metrics(
    las_norm,
    ~list(P95 = quantile(Z, 0.95, na.rm = TRUE)),
    res = 30
  )

  parcelles_metrics <- exactextractr::exact_extract(
    metriques, parcelles, fun = "mean"
  )

  expect_s3_class(parcelles_metrics, "data.frame")
  expect_gt(nrow(parcelles_metrics), 0)
  expect_true("mean.P95" %in% names(parcelles_metrics))
})
```

### Test 5 : Génération MNH
```r
testthat::test_that("MNH généré correctement", {
  las_norm <- lidR::readLAS(load_demo_lidar()[1])
  mnh <- lidR::rasterize_canopy(las_norm, res = 1, algorithm = lidR::p2r())

  expect_s4_class(mnh, "SpatRaster")
  expect_equal(terra::res(mnh)[1], 1, tolerance = 0.01)
  expect_lt(max(terra::values(mnh), na.rm = TRUE), 50)
})
```

---

## Dépendances

### Packages R requis
- **lidarHD** >= 0.1.0 (téléchargement LiDAR HD IGN)
- **lidR** >= 4.0.0 (traitement LiDAR)
- **terra** >= 1.7-0 (rasters)
- **sf** >= 1.0-0 (vecteurs)
- **exactextractr** >= 0.9.0 (agrégation zonale)
- **learnr** >= 0.11.0, **gradethis** >= 0.2.0

### Données
- Données demo: `inst/extdata/tutorial_data/ciron_lidar/*.laz`
- API IGN: LiDAR HD (service lidarHD)

### Modules précédents
- **Module 1** : Fournit `parcelles` (objet sf) et `mnt` (SpatRaster)

### Modules suivants
- **Module 3** (Calcul 12 familles) utilisera `parcelles_metrics` (métriques dendrométriques)
