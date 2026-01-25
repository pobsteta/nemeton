# API Contract: Core Functions

**Module**: Core (units, layers, compute)
**Date**: 2026-01-04

---

## `nemeton_units()`

### Purpose
Créer un objet nemeton_units à partir de données spatiales.

### Signature
```r
nemeton_units(
  x,
  id_col = NULL,
  metadata = list(),
  validate = TRUE
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `x` | `sf`, `character` | Yes | - | Objet sf ou chemin vers fichier spatial (gpkg, shp) |
| `id_col` | `character` | No | `NULL` | Nom de la colonne d'identifiant. Si NULL, créé automatiquement |
| `metadata` | `list` | No | `list()` | Métadonnées du site (site_name, year, source, etc.) |
| `validate` | `logical` | No | `TRUE` | Valider les géométries ? |

### Returns

**Type**: `nemeton_units` (S3 class inheriting from `sf`)

**Structure**:
```r
# sf with:
# - Column `nemeton_id` (character, unique)
# - Geometry column (POLYGON or MULTIPOLYGON)
# - Original attribute columns preserved
# - Attribute `metadata` (list)
```

### Errors

| Condition | Error Type | Message |
|-----------|-----------|---------|
| `x` is not sf or valid path | `cli::cli_abort()` | "x must be an sf object or path to spatial file" |
| No CRS defined | `cli::cli_abort()` | "Input must have a defined CRS" |
| Invalid geometries and `validate = TRUE` | `cli::cli_abort()` | "Found {n} invalid geometries. Fix with sf::st_make_valid()" |
| Empty geometries | `cli::cli_abort()` | "Found {n} empty geometries" |

### Example
```r
library(sf)
polygons <- st_read("forest_parcels.gpkg")

units <- nemeton_units(
  polygons,
  metadata = list(
    site_name = "Forêt de Fontainebleau",
    year = 2024,
    source = "IGN BD Forêt v2"
  )
)

print(units)
#> nemeton_units object
#> Site: Forêt de Fontainebleau (2024)
#> 50 units, 1250 ha total
#> CRS: EPSG:2154
```

---

## `nemeton_layers()`

### Purpose
Créer un catalogue de couches spatiales (rasters et vecteurs) avec chargement lazy.

### Signature
```r
nemeton_layers(
  rasters = NULL,
  vectors = NULL,
  validate = TRUE
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `rasters` | `named list` | No | `NULL` | Liste nommée de chemins vers rasters (GeoTIFF, etc.) |
| `vectors` | `named list` | No | `NULL` | Liste nommée de chemins vers vecteurs (gpkg, shp) |
| `validate` | `logical` | No | `TRUE` | Vérifier que tous les fichiers existent ? |

### Returns

**Type**: `nemeton_layers` (S3 list)

**Structure**: See `data-model.md`

### Errors

| Condition | Error Type | Message |
|-----------|-----------|---------|
| File not found and `validate = TRUE` | `cli::cli_abort()` | "Layer '{name}': file not found at {path}" |
| Both `rasters` and `vectors` are NULL | `cli::cli_abort()` | "At least one of rasters or vectors must be provided" |
| Duplicate names | `cli::cli_abort()` | "Duplicate layer names found: {duplicates}" |

### Example
```r
layers <- nemeton_layers(
  rasters = list(
    ndvi = "data/sentinel2_ndvi.tif",
    dem = "data/ign_mnt_25m.tif"
  ),
  vectors = list(
    rivers = "data/bdtopo_hydro.gpkg",
    roads = "data/routes.shp"
  )
)

summary(layers)
#> nemeton_layers object
#> Rasters: 2 (ndvi, dem) - not loaded
#> Vectors: 2 (rivers, roads) - not loaded
```

---

## `nemeton_compute()`

### Purpose
Calculer des indicateurs Néméton pour des unités spatiales à partir de couches.

### Signature
```r
nemeton_compute(
  units,
  layers,
  indicators = "all",
  preprocess = TRUE,
  parallel = FALSE,
  progress = TRUE,
  ...
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `nemeton_units` or `sf` | Yes | - | Unités d'analyse |
| `layers` | `nemeton_layers` | Yes | - | Catalogue de couches |
| `indicators` | `character` or `list` | No | `"all"` | Indicateurs à calculer. "all" = tous disponibles |
| `preprocess` | `logical` | No | `TRUE` | Harmoniser CRS/extent automatiquement ? |
| `parallel` | `logical` | No | `FALSE` | Calcul parallèle ? (MVP: non implémenté, erreur si TRUE) |
| `progress` | `logical` | No | `TRUE` | Afficher barre de progression ? |
| `...` | various | No | - | Arguments passés aux fonctions d'indicateurs |

### Returns

**Type**: `sf` (enriched with indicator columns)

**Structure**:
```r
# sf with:
# - All original columns from units
# - One numeric column per indicator calculated
# - Updated metadata attribute
```

### Behavior

1. **Validation**: Vérifie que `units` et `layers` sont valides
2. **Preprocessing** (si `preprocess = TRUE`):
   - Reprojecter couches dans CRS de `units` si nécessaire (message informé)
   - Découper rasters sur extent de `units` (économie mémoire)
3. **Computation**:
   - Pour chaque indicateur:
     - Charger couches nécessaires (lazy)
     - Appeler fonction `indicator_<name>()`
     - Capturer erreurs → warning + continuer avec autres
4. **Return**: sf enrichi avec colonnes d'indicateurs

### Errors

| Condition | Error Type | Message |
|-----------|-----------|---------|
| `units` not sf-like | `cli::cli_abort()` | "units must be sf or nemeton_units" |
| `layers` not nemeton_layers | `cli::cli_abort()` | "layers must be nemeton_layers object" |
| Unknown indicator | `cli::cli_warn()` | "Indicator '{name}' not found, skipping" |
| `parallel = TRUE` (MVP) | `cli::cli_abort()` | "Parallel computing not implemented in v0.1.0 (available in v0.4.0+)" |

### Warnings

| Condition | Warning Message |
|-----------|----------------|
| Missing layer for indicator | "Indicator '{ind}': required layer '{layer}' not found, skipping" |
| CRS reprojection | "Reprojecting layer '{name}' from {crs1} to {crs2}" |
| Indicator calculation error | "Indicator '{ind}' calculation failed: {error}, column set to NA" |

### Example
```r
units <- nemeton_units(st_read("parcels.gpkg"))
layers <- nemeton_layers(
  rasters = list(biomass = "biomass.tif", dem = "dem.tif")
)

# Calculer tous les indicateurs
results <- nemeton_compute(units, layers)

# Calculer seulement certains indicateurs
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon", "accessibility")
)

# Accéder aux résultats
head(results)
#> Simple feature collection with 6 features and 3 fields
#> nemeton_id   carbon  accessibility  geometry
#> unit_001     120.5   0.85          <POLYGON>
```

---

## Helper Functions (Internal)

### `validate_units()`

**Purpose**: Valider un objet nemeton_units

**Signature**:
```r
validate_units(x, strict = TRUE)
```

**Returns**: Invisible `TRUE` or stops with error

---

### `harmonize_crs()`

**Purpose**: Reprojeter couches dans CRS cible

**Signature**:
```r
harmonize_crs(layers, target_crs, verbose = TRUE)
```

**Returns**: `nemeton_layers` with reprojected layers

---

### `crop_to_units()`

**Purpose**: Découper couches sur extent des unités

**Signature**:
```r
crop_to_units(layers, units, buffer = 0)
```

**Returns**: `nemeton_layers` with cropped layers

---

**Contract Status**: ✅ Complete
