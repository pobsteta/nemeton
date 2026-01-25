# Module 1 API Contract: Acquisition Cadastre et MNT

**Module**: Tutorial Module 1 - Acquisition Données Cadastrales et MNT
**Feature**: 001-learnr-tutorial
**User Story**: US1 (P1)

## Overview

Ce module enseigne l'acquisition de données géographiques de base via les APIs IGN (happign) :
- Parcelles cadastrales (BD Parcellaire)
- Modèle Numérique de Terrain (RGE Alti 5m)

**Pédagogie** : Introduction progressive avec exercices interactifs et correction automatique.

## Exercice 1.1 : Téléchargement Cadastre

### Objectif Pédagogique
L'utilisateur apprend à télécharger les parcelles cadastrales pour une commune via l'API IGN.

### Inputs de l'exercice
- `commune` : Code INSEE ou nom de commune (ex: "CIRON" ou "36053")
- `output_dir` : Répertoire de sortie (optionnel, défaut tempdir)

### Code attendu de l'utilisateur
```r
# Télécharger parcelles cadastrales pour CIRON
parcelles <- tutorial_download_cadastre(
  commune = "36053",
  output_dir = "data/cadastre"
)

# Vérifier la structure
print(parcelles)
st_crs(parcelles)
```

### Outputs attendus
- `parcelles` : objet `sf` avec géométries MULTIPOLYGON
- CRS : EPSG:2154 (Lambert-93)
- Colonnes minimales : `id_parcel`, `commune`, `section`, `numero`, `contenance`, `geometry`

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "sf"),
          "Excellent ! Vous avez chargé les parcelles cadastrales."),
  fail_if(~ !inherits(.result, "sf"),
          "Le résultat doit être un objet sf. Vérifiez l'appel à tutorial_download_cadastre()."),
  pass_if(~ st_crs(.result) == st_crs(2154),
          "CRS Lambert-93 correct !"),
  fail_if(~ st_crs(.result) != st_crs(2154),
          "CRS incorrect. Les données IGN doivent être en Lambert-93 (EPSG:2154)."),
  pass_if(~ nrow(.result) > 0,
          "Parcelles téléchargées avec succès."),
  fail_if(~ nrow(.result) == 0,
          "Aucune parcelle trouvée. Vérifiez le code commune.")
)
```

### Fallback si API échoue
Si `tutorial_download_cadastre()` échoue (timeout, API indisponible), la fonction bascule automatiquement sur les données démo pré-téléchargées :
```r
cli::cli_alert_warning("API IGN indisponible, chargement données demo CIRON")
load_demo_cadastre()
```

### Concepts enseignés
- API IGN via happign
- Format sf (Simple Features)
- CRS Lambert-93 (EPSG:2154)
- Métadonnées cadastrales

---

## Exercice 1.2 : Téléchargement MNT

### Objectif Pédagogique
L'utilisateur apprend à télécharger le Modèle Numérique de Terrain (MNT) via l'API IGN pour l'emprise des parcelles.

### Inputs de l'exercice
- `parcelles` : objet sf des parcelles (de l'exercice 1.1)
- `resolution` : résolution MNT en mètres (5 ou 1, défaut 5)
- `output_dir` : répertoire de sortie (optionnel)

### Code attendu de l'utilisateur
```r
# Extraire l'emprise des parcelles
bbox_parcelles <- st_bbox(parcelles)

# Télécharger MNT 5m pour cette emprise
mnt <- tutorial_download_mnt(
  bbox = bbox_parcelles,
  resolution = 5,
  output_dir = "data/mnt"
)

# Visualiser le MNT
terra::plot(mnt, main = "MNT RGE Alti 5m - CIRON")
```

### Outputs attendus
- `mnt` : objet `SpatRaster` (package terra)
- CRS : EPSG:2154 (Lambert-93)
- Résolution : 5m x 5m (ou 1m si demandé)
- Valeurs : altitudes en mètres
- Emprise : couvre complètement `bbox_parcelles`

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "SpatRaster"),
          "Parfait ! Vous avez chargé le MNT."),
  fail_if(~ !inherits(.result, "SpatRaster"),
          "Le résultat doit être un SpatRaster (package terra). Utilisez tutorial_download_mnt()."),
  pass_if(~ st_crs(.result) == st_crs(2154),
          "CRS Lambert-93 correct !"),
  pass_if(~ abs(terra::res(.result)[1] - 5) < 1,
          "Résolution 5m correcte."),
  fail_if(~ abs(terra::res(.result)[1] - 5) >= 1,
          "Résolution incorrecte. Vérifiez le paramètre resolution = 5."),
  pass_if(~ terra::global(.result, "notNA")[1,1] > 0,
          "MNT téléchargé avec succès, données valides.")
)
```

### Fallback si API échoue
Si `tutorial_download_mnt()` échoue, bascule sur données demo :
```r
cli::cli_alert_warning("API IGN indisponible, chargement MNT demo CIRON")
load_demo_mnt()
```

### Concepts enseignés
- MNT (Modèle Numérique de Terrain)
- Format raster (SpatRaster)
- Résolution spatiale (5m vs 1m)
- Emprise géographique (bbox)

---

## Exercice 1.3 : Reprojection et Découpe

### Objectif Pédagogique
L'utilisateur apprend à harmoniser les CRS et découper le MNT sur l'emprise exacte des parcelles.

### Inputs de l'exercice
- `parcelles` : objet sf (exercice 1.1)
- `mnt` : SpatRaster (exercice 1.2)

### Code attendu de l'utilisateur
```r
# Vérifier que parcelles et MNT ont le même CRS
if (st_crs(parcelles) != st_crs(mnt)) {
  parcelles <- st_transform(parcelles, st_crs(mnt))
}

# Découper MNT sur emprise des parcelles (avec buffer 100m)
parcelles_buffer <- st_buffer(parcelles, 100)
mnt_cropped <- terra::crop(mnt, terra::vect(parcelles_buffer))

# Masquer hors parcelles
mnt_masked <- terra::mask(mnt_cropped, terra::vect(parcelles_buffer))

# Visualiser résultat
plot(mnt_masked, main = "MNT découpé sur parcelles CIRON")
plot(st_geometry(parcelles), add = TRUE, border = "red", lwd = 2)
```

### Outputs attendus
- `mnt_cropped` : SpatRaster découpé sur emprise parcelles + buffer
- `mnt_masked` : SpatRaster masqué hors parcelles
- CRS : EPSG:2154 (harmonisé)
- Valeurs NA hors de l'emprise

### Validation gradethis
```r
grade_result(
  pass_if(~ inherits(.result, "SpatRaster"),
          "Super ! MNT découpé correctement."),
  pass_if(~ st_crs(parcelles) == st_crs(.result),
          "CRS harmonisé avec les parcelles."),
  pass_if(~ terra::global(.result, "notNA")[1,1] > 0,
          "MNT masqué avec données valides."),
  fail_if(~ terra::global(.result, "notNA")[1,1] == 0,
          "Erreur : MNT entièrement masqué. Vérifiez le CRS et l'emprise.")
)
```

### Concepts enseignés
- Reprojection CRS (`st_transform`)
- Découpe raster (`terra::crop`, `terra::mask`)
- Buffer spatial (`st_buffer`)
- Harmonisation données vectorielles/raster

---

## Quiz de Validation Module 1

### Question 1 : CRS Lambert-93
**Question** : Quel est le code EPSG du système de coordonnées Lambert-93 utilisé en France métropolitaine ?

- A) EPSG:4326 (WGS84)
- B) EPSG:2154 (Lambert-93) ✓
- C) EPSG:3857 (Web Mercator)
- D) EPSG:27572 (Lambert II étendu)

**Feedback** : EPSG:2154 est le CRS officiel pour les données IGN en France métropolitaine.

### Question 2 : Résolution MNT
**Question** : Quelle est la résolution spatiale du RGE Alti utilisé dans ce tutorial ?

- A) 1 mètre
- B) 5 mètres ✓
- C) 25 mètres
- D) 100 mètres

**Feedback** : Le RGE Alti 5m offre un bon compromis précision/taille pour l'analyse forestière.

### Question 3 : Fallback API
**Question** : Que se passe-t-il si l'API IGN est indisponible pendant l'exercice ?

- A) Le tutorial s'arrête avec une erreur
- B) L'utilisateur doit télécharger manuellement les données
- C) Le tutorial bascule automatiquement sur les données demo ✓
- D) Le tutorial saute cet exercice

**Feedback** : Le fallback automatique garantit que le tutorial fonctionne même sans connexion API.

---

## Résumé des Fonctions Utilisées

### Fonctions tutorial helpers
- `tutorial_download_cadastre(commune, output_dir, timeout, verbose)`
- `tutorial_download_mnt(bbox, resolution, output_dir, timeout, verbose)`
- `load_demo_cadastre()` (fallback)
- `load_demo_mnt()` (fallback)

### Fonctions sf/terra standard
- `st_read()`, `st_crs()`, `st_transform()`, `st_buffer()`, `st_bbox()`
- `terra::rast()`, `terra::crop()`, `terra::mask()`, `terra::plot()`

### Validation
- `validate_parcels(parcelles)` (vérifie structure sf, CRS, colonnes)

---

## Tests Attendus (Post-Exercices)

### Test 1 : Parcelles chargées
```r
testthat::test_that("Parcelles CIRON chargées correctement", {
  parcelles <- tutorial_download_cadastre("36053")

  expect_s3_class(parcelles, "sf")
  expect_equal(st_crs(parcelles), st_crs(2154))
  expect_gt(nrow(parcelles), 0)
  expect_true(all(c("id_parcel", "geometry") %in% names(parcelles)))
})
```

### Test 2 : MNT téléchargé
```r
testthat::test_that("MNT CIRON téléchargé correctement", {
  parcelles <- load_demo_cadastre()
  bbox <- st_bbox(parcelles)
  mnt <- tutorial_download_mnt(bbox, resolution = 5)

  expect_s4_class(mnt, "SpatRaster")
  expect_equal(st_crs(mnt), st_crs(2154))
  expect_equal(terra::res(mnt)[1], 5, tolerance = 0.1)
})
```

### Test 3 : Découpe MNT
```r
testthat::test_that("MNT découpé sur parcelles", {
  parcelles <- load_demo_cadastre()
  mnt <- load_demo_mnt()

  mnt_cropped <- terra::crop(mnt, terra::vect(parcelles))

  expect_s4_class(mnt_cropped, "SpatRaster")
  expect_true(terra::global(mnt_cropped, "notNA")[1,1] > 0)
})
```

---

## Dépendances

### Packages R requis
- **happign** >= 0.2.0 (API IGN)
- **sf** >= 1.0-0 (vecteurs)
- **terra** >= 1.7-0 (rasters)
- **learnr** >= 0.11.0 (framework tutorial)
- **gradethis** >= 0.2.0 (correction automatique)

### Données
- Données demo: `inst/extdata/tutorial_data/ciron_parcelles.gpkg`, `ciron_mnt.tif`
- API IGN: BD Parcellaire, RGE Alti 5m

### Modules précédents
Aucun (Module 1 est le point d'entrée du tutorial)

### Modules suivants
- Module 2 (Traitement LiDAR) dépend de `parcelles` de ce module
