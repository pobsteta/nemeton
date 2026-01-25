# Data Model: MVP nemeton v0.1.0

**Date**: 2026-01-04
**Branch**: 001-mvp-v0.1.0

## Overview

Ce document décrit les structures de données (classes S3) et entités du package nemeton MVP. Toutes les classes héritent ou utilisent les objets R spatiaux standard (`sf`, `SpatRaster` de terra).

---

## Class 1: `nemeton_units`

### Description
Représente les unités spatiales d'analyse (parcelles, îlots forestiers, grilles). Hérite de `sf` (Simple Features).

### Structure

```r
nemeton_units <- sf::st_sf(
  nemeton_id = character(),      # Identifiant unique
  geometry = sf::st_sfc(),       # Géométries POLYGON ou MULTIPOLYGON
  ...,                           # Autres attributs utilisateur (optionnels)
  class = c("nemeton_units", "sf", "data.frame")
)

# Attribut metadata
attr(nemeton_units, "metadata") <- list(
  site_name = character(),       # Nom du site/massif
  year = integer(),              # Année de référence
  crs = sf::st_crs(),            # Système de coordonnées
  n_units = integer(),           # Nombre d'unités
  area_total = units::set_units(), # Surface totale (avec unités)
  created_at = POSIXct(),        # Timestamp création
  source = character(),          # Source des données
  description = character()      # Description optionnelle
)
```

### Validation Rules

- **Geometry**: DOIT être `POLYGON` ou `MULTIPOLYGON`
- **CRS**: DOIT être défini (pas `NA`)
- **Validity**: Géométries DOIVENT être valides (`sf::st_is_valid()`)
- **ID**: Si `nemeton_id` absent, généré automatiquement (format: `unit_001`, `unit_002`, ...)
- **Empty**: Géométries DOIVENT être non vides

### Relationships

- Utilisé par: `nemeton_compute()`, `nemeton_index()`, `nemeton_map()`, `nemeton_radar()`
- Retourné par: `nemeton_units()`, `nemeton_compute()` (enrichi avec indicateurs)

### Methods

- `print.nemeton_units()`: Affichage formaté (sf + metadata)
- `summary.nemeton_units()`: Statistiques + metadata
- `plot.nemeton_units()`: Visualisation rapide des unités

---

## Class 2: `nemeton_layers`

### Description
Catalogue des couches spatiales (rasters et vecteurs) avec chargement lazy. Liste S3 structurée.

### Structure

```r
nemeton_layers <- structure(
  list(
    rasters = list(
      layer_name = list(
        path = character(),          # Chemin absolu vers fichier
        loaded = FALSE,              # Est-ce chargé en mémoire ?
        object = NULL,               # SpatRaster si loaded = TRUE
        metadata = list(
          crs = sf::st_crs(),
          extent = terra::ext(),
          resolution = numeric(),
          ncells = integer(),
          nlayers = integer()
        )
      )
    ),
    vectors = list(
      layer_name = list(
        path = character(),
        loaded = FALSE,
        object = NULL,               # sf si loaded = TRUE
        metadata = list(
          crs = sf::st_crs(),
          extent = sf::st_bbox(),
          nfeatures = integer(),
          geometry_type = character()
        )
      )
    ),
    metadata = list(
      created_at = POSIXct(),
      n_rasters = integer(),
      n_vectors = integer(),
      validated = logical()          # Tous les chemins existent ?
    )
  ),
  class = "nemeton_layers"
)
```

### Validation Rules

- **Paths**: Tous les chemins DOIVENT exister au moment de la création (sauf si `validate = FALSE`)
- **Names**: Noms de couches DOIVENT être uniques au sein de rasters et vectors
- **Lazy loading**: `object` est `NULL` jusqu'à premier accès

### Relationships

- Utilisé par: `nemeton_compute()`, fonctions de preprocessing
- Créé par: `nemeton_layers()`, `add_raster()`, `add_vector()`

### Methods

- `print.nemeton_layers()`: Liste des couches disponibles avec status loaded
- `summary.nemeton_layers()`: Détails metadata par couche

---

## Class 3: Indicator Functions (Pattern)

### Description
Pas une classe S3 formelle, mais un pattern de signature standard pour toutes les fonctions d'indicateurs.

### Signature Standard

```r
indicator_<name> <- function(
  units,                   # nemeton_units ou sf
  layers,                  # nemeton_layers
  layer_name = NULL,       # Nom de la couche à utiliser (ou détecté auto)
  method = "default",      # Méthode de calcul
  fun = "mean",           # Fonction d'agrégation ("mean", "median", "sum", "sd")
  na.rm = TRUE,           # Gérer les NA ?
  ...                     # Paramètres spécifiques à l'indicateur
) {
  # Validation
  # Chargement couches nécessaires
  # Extraction/calcul
  # Return: numeric vector (length = nrow(units))
}
```

### Return Value

Vecteur numérique de longueur `nrow(units)` avec valeurs de l'indicateur pour chaque unité.

### Example Implementations

**indicator_carbon()**:
```r
indicator_carbon <- function(
  units,
  layers,
  biomass_layer = "biomass",    # Raster de biomasse (t/ha)
  method = c("above_ground", "total"),
  fun = "sum",
  na.rm = TRUE
) {
  # Extraction zonale
  values <- exactextractr::exact_extract(
    x = layers$rasters[[biomass_layer]]$object,
    y = units,
    fun = fun,
    progress = FALSE
  )
  return(values)
}
```

**indicator_biodiversity()**:
```r
indicator_biodiversity <- function(
  units,
  layers,
  species_layer = "species_richness",
  method = c("richness", "shannon", "simpson"),
  fun = "mean",
  na.rm = TRUE
) {
  method <- match.arg(method)
  # Logique selon method
  # Return numeric vector
}
```

---

## Entity: Indicator Results (Enriched sf)

### Description
Résultat de `nemeton_compute()` : objet `sf` identique à `units` avec colonnes additionnelles pour chaque indicateur.

### Structure

```r
# Input units
units <- nemeton_units(...)  # 3 colonnes: nemeton_id, area, geometry

# After nemeton_compute()
results <- nemeton_compute(units, layers, indicators = c("carbon", "biodiversity"))

# Output structure
# sf [100 × 5]
# nemeton_id | area | carbon | biodiversity | geometry
# <chr>      | <dbl> | <dbl> | <dbl>       | <POLYGON>
# unit_001   | 25.3  | 120.5 | 0.82        | ...
# unit_002   | 18.7  | 95.2  | 0.76        | ...
```

### Validation

- Toutes les colonnes originales de `units` DOIVENT être préservées
- Colonnes d'indicateurs DOIVENT avoir type `numeric` (ou `NA` si erreur de calcul)
- Géométrie DOIT rester inchangée

---

## Entity: Normalized Indices (Enriched sf)

### Description
Résultat de `nemeton_index()` : sf avec indicateurs normalisés + indices composites.

### Structure

```r
# Input results (raw indicators)
results <- nemeton_compute(...)

# After normalization
indices <- nemeton_index(
  results,
  method = "weighted",
  weights = c(carbon = 0.4, biodiversity = 0.6),
  normalize = TRUE,
  normalize_method = "minmax"
)

# Output structure
# sf [100 × 8]
# nemeton_id | carbon | biodiversity | carbon_norm | biodiversity_norm | nemeton_index | geometry
# <chr>      | <dbl>  | <dbl>       | <dbl>       | <dbl>            | <dbl>        | <POLYGON>
# unit_001   | 120.5  | 0.82        | 85.3        | 92.1             | 89.4         | ...
```

### Validation

- Valeurs normalisées DOIVENT être dans [0, 100] si méthode = minmax
- `nemeton_index` DOIT être calculé comme moyenne pondérée des indicateurs normalisés
- Poids DOIVENT sommer à 1 (normalisés automatiquement si pas le cas)

---

## Entity: Metadata Tracking

### Description
Chaque objet `nemeton_units` et résultats de calculs stockent métadonnées pour traçabilité.

### Metadata Structure

```r
metadata <- list(
  # Metadata originales (nemeton_units)
  site_name = "Forêt de Fontainebleau",
  year = 2024,
  source = "IGN BD Forêt v2",

  # Metadata ajoutées par nemeton_compute()
  computed_at = as.POSIXct("2024-06-15 14:32:10"),
  indicators_computed = c("carbon", "biodiversity", "water"),
  layers_used = c("biomass.tif", "species.tif", "dem.tif"),

  # Metadata ajoutées par nemeton_index()
  normalized_at = as.POSIXct("2024-06-15 14:35:22"),
  normalization_method = "minmax",
  aggregation_method = "weighted",
  weights = c(carbon = 0.4, biodiversity = 0.6)
)

# Accès
attr(results, "metadata")
```

---

## State Transitions

### Workflow Standard

```
1. Raw Units (nemeton_units)
   ↓ [nemeton_compute()]
2. Results with Indicators (sf + indicator columns)
   ↓ [nemeton_index()]
3. Normalized Indices (sf + norm columns + indices)
   ↓ [nemeton_map() / nemeton_radar()]
4. Visualizations (ggplot objects)
```

### State Properties

- **Immutabilité**: Chaque fonction retourne un nouvel objet, ne modifie pas l'input
- **Composition**: Output d'une fonction = input valide de la suivante
- **Traçabilité**: Métadonnées cumulatives (chaque étape ajoute, ne supprime pas)

---

## Validation Summary

### Validation Levels

1. **Creation** (`nemeton_units()`, `nemeton_layers()`):
   - Géométries valides, CRS défini
   - Fichiers existent

2. **Computation** (`nemeton_compute()`):
   - Couches requises présentes
   - CRS compatibles (ou reprojection si `preprocess = TRUE`)

3. **Aggregation** (`nemeton_index()`):
   - Indicateurs existent dans data
   - Poids valides (numériques positifs)

### Error Handling Strategy

- **Validation précoce**: Fail fast avec messages explicites (`cli::cli_abort()`)
- **Graceful degradation**: Si un indicateur échoue, émettre warning et continuer avec autres
- **Informative messages**: Toujours indiquer quelle validation a échoué et pourquoi

---

## Example Data Flows

### Flow 1: Simple Analysis

```r
# 1. Create units
polygons <- sf::st_read("parcelles.gpkg")
units <- nemeton_units(polygons, metadata = list(site = "Test Forest"))
# Class: nemeton_units (inherits sf)
# Attributes: 50 rows, geometry, metadata

# 2. Load layers
layers <- nemeton_layers(
  rasters = list(biomass = "biomass.tif"),
  vectors = list(roads = "roads.gpkg")
)
# Class: nemeton_layers
# Contents: 1 raster, 1 vector (not loaded yet)

# 3. Compute indicators
results <- nemeton_compute(units, layers, indicators = c("carbon", "accessibility"))
# Class: sf (nemeton_units dropped after enrichment)
# Columns: original + carbon + accessibility
# Metadata: updated with computation info

# 4. Normalize and index
indices <- nemeton_index(results)
# Class: sf
# Columns: original + indicators + normalized + nemeton_index
# Metadata: updated with normalization info
```

---

## Summary Table

| Entity | Type | Key Attributes | Created By | Used By |
|--------|------|----------------|------------|---------|
| `nemeton_units` | S3 class (sf) | geometry, nemeton_id, metadata | `nemeton_units()` | `nemeton_compute()` |
| `nemeton_layers` | S3 list | rasters, vectors, paths, metadata | `nemeton_layers()` | `nemeton_compute()`, preprocessing |
| Indicator results | sf | original cols + indicator cols | `nemeton_compute()` | `nemeton_index()`, viz |
| Normalized indices | sf | indicators + normalized + index | `nemeton_index()` | Visualizations, export |

---

**Phase 1 (Data Model) Complete** ✅ - Structures de données définies, validations spécifiées, flux de données documentés.
