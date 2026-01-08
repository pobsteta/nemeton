# Research: Tutoriels Interactifs nemeton

**Date**: 2026-01-07
**Feature**: 001-learnr-tutorial

## 1. LiDAR Processing Workflow

### Decision
Utiliser le workflow lidR standard: readLAS → normalize_height → pixel_metrics/cloud_metrics

### Rationale
- lidR est le package R de référence pour le traitement LiDAR
- Workflow bien documenté et testé
- Compatible avec les formats COPC/LAZ de l'IGN
- Fonctions pixel_metrics et cloud_metrics permettent extraction par parcelle

### Alternatives Considered
- **lasR**: Plus rapide mais moins mature, documentation limitée
- **rLiDAR**: Abandonné, non maintenu
- **lidaRtRee**: Utilisé pour données démo, mais lidR pour traitement brut

### Implementation Pattern

```r
# 1. Chargement
las <- readLAS(fichier, filter = "-drop_z_below 0")

# 2. Normalisation
las_norm <- normalize_height(las, tin())  # ou knnidw()

# 3. Métriques par pixel (raster)
metrics_raster <- pixel_metrics(las_norm, ~list(
  zmax = max(Z),
  zmean = mean(Z),
  zsd = sd(Z),
  zq95 = quantile(Z, 0.95),
  pzabove2 = sum(Z > 2) / length(Z) * 100
), res = 10)

# 4. Métriques par parcelle
parcelles_metrics <- exact_extract(metrics_raster, parcelles, fun = "mean")
```

---

## 2. Cache Strategy

### Decision
`rappdirs::user_data_dir("nemeton")` avec fallback `~/nemeton_tutorial_data/`

### Rationale
- rappdirs suit les conventions XDG sur Linux, AppData sur Windows, ~/Library sur macOS
- Fallback assure compatibilité si rappdirs non installé
- Cache persistant entre sessions R

### Alternatives Considered
- **tempdir()**: Non persistant, perdu à chaque session
- **tools::R_user_dir()**: R >= 4.0 uniquement, moins flexible
- **here::here()**: Relatif au projet, pas au système

### Implementation Pattern

```r
get_cache_dir <- function() {
  if (requireNamespace("rappdirs", quietly = TRUE)) {
    dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
  } else {
    dir <- file.path(path.expand("~"), "nemeton_tutorial_data")
  }
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  dir
}
```

---

## 3. INPN WFS Endpoints

### Decision
Utiliser le Géoportail de l'environnement pour ZNIEFF et Natura 2000

### Rationale
- Service WFS officiel, données à jour
- Compatible avec happign ou requêtes httr directes
- Licence ouverte pour usage éducatif

### Endpoints Identifiés

| Couche | URL WFS | Layer Name |
|--------|---------|------------|
| ZNIEFF Type 1 | wxs.ign.fr/environnement | PROTECTEDAREAS.ZNIEFF1 |
| ZNIEFF Type 2 | wxs.ign.fr/environnement | PROTECTEDAREAS.ZNIEFF2 |
| Natura 2000 SIC | wxs.ign.fr/environnement | PROTECTEDAREAS.SIC |
| Natura 2000 ZPS | wxs.ign.fr/environnement | PROTECTEDAREAS.ZPS |

### Implementation Pattern

```r
# Via happign
zones_protegees <- get_wfs(
  x = zone_etude,
  layer = "PROTECTEDAREAS.ZNIEFF1",
  apikey = "environnement"
)

# Fallback direct si happign échoue
url <- "https://wxs.ign.fr/environnement/geoportail/wfs"
query <- list(
  service = "WFS",
  version = "2.0.0",
  request = "GetFeature",
  typeName = "PROTECTEDAREAS.ZNIEFF1",
  outputFormat = "application/json",
  bbox = paste(st_bbox(zone_etude), collapse = ",")
)
```

---

## 4. gradethis Patterns for Geospatial

### Decision
Validation basée sur structure (classe, CRS, colonnes) plutôt que valeurs exactes

### Rationale
- Les valeurs géospatiales peuvent varier légèrement selon l'ordre de traitement
- La structure (sf, SpatRaster) et les métadonnées (CRS) sont déterministes
- Permet validation robuste sans données de référence exactes

### Patterns de Validation

```r
# Validation sf object
grade_this({
  if (!inherits(.result, "sf")) {
    fail("Le résultat doit être un objet sf")
  }
  if (st_crs(.result)$epsg != 2154) {
    fail("Le CRS doit être EPSG:2154 (Lambert-93)")
  }
  if (!"B1" %in% names(.result)) {
    fail("La colonne B1 (indicateur biodiversité) est manquante")
  }
  if (any(.result$B1 < 0 | .result$B1 > 100, na.rm = TRUE)) {
    fail("B1 doit être entre 0 et 100")
  }
  pass("Excellent ! Indicateur B1 calculé correctement")
})

# Validation SpatRaster
grade_this({
  if (!inherits(.result, "SpatRaster")) {
    fail("Le résultat doit être un SpatRaster (terra)")
  }
  if (res(.result)[1] != 5) {
    fail("La résolution doit être de 5 mètres")
  }
  pass("MNT chargé correctement")
})
```

---

## 5. Tutorial Sections Structure

### Decision
Structure standardisée pour chaque tutoriel avec setup-exercise-solution-check

### Rationale
- Cohérence entre tutoriels
- Pattern learnr reconnu
- Facilite maintenance et tests

### Standard Section Template

```rmd
## Section N : [Titre]

### Introduction

[Explication du concept, 2-3 paragraphes]

### Exercice N.1 : [Titre exercice]

[Instructions pour l'apprenant]

```{r ex-N-1-setup}
# Code de préparation (invisible)
```

```{r ex-N-1, exercise=TRUE, exercise.lines=20}
# Code pré-rempli ou commentaires guidant
```

```{r ex-N-1-solution}
# Solution complète
```

```{r ex-N-1-check}
grade_this({
  # Validation
})
```

### Quiz

```{r quiz-N}
question("Question ?",
  answer("Réponse A", correct = TRUE),
  answer("Réponse B"),
  allow_retry = TRUE
)
```
```

---

## Summary

Toutes les questions techniques ont été résolues. Le projet peut passer à la Phase 1 (Design & Contracts).

| Topic | Décision | Confiance |
|-------|----------|-----------|
| LiDAR Workflow | lidR standard | Haute |
| Cache Strategy | rappdirs + fallback | Haute |
| INPN WFS | Géoportail environnement | Moyenne |
| gradethis | Validation structure | Haute |
| Section Template | Setup-Exercise-Solution-Check | Haute |
