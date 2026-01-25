# API Contract: Indicator Functions

**Module**: Indicators (biophysical)
**Date**: 2026-01-04

---

## Standard Indicator Pattern

Toutes les fonctions d'indicateurs suivent cette signature standard :

```r
indicator_<name>(
  units,
  layers,
  layer_name = NULL,
  method = "default",
  fun = "mean",
  na.rm = TRUE,
  ...
)
```

### Standard Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `units` | `sf` | - | Unités spatiales |
| `layers` | `nemeton_layers` | - | Catalogue de couches |
| `layer_name` | `character` | `NULL` | Nom de couche spécifique (auto-détecté si NULL) |
| `method` | `character` | varies | Méthode de calcul (spécifique à chaque indicateur) |
| `fun` | `character` | `"mean"` | Fonction d'agrégation: "mean", "median", "sum", "sd", "min", "max" |
| `na.rm` | `logical` | `TRUE` | Ignorer les NA dans agrégation ? |

### Standard Return

**Type**: `numeric` vector of length `nrow(units)`

---

## `indicator_carbon()`

### Purpose
Calculer le stock de carbone (biomasse aérienne) par unité.

### Signature
```r
indicator_carbon(
  units,
  layers,
  biomass_layer = "biomass",
  method = c("sum", "mean"),
  fun = "sum",
  na.rm = TRUE,
  conversion_factor = 0.47
)
```

### Parameters (Specific)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `biomass_layer` | `character` | `"biomass"` | Nom du raster de biomasse (t/ha) |
| `method` | `character` | `"sum"` | "sum" = total par unité, "mean" = densité moyenne |
| `conversion_factor` | `numeric` | `0.47` | Facteur conversion biomasse → carbone (IPCC default) |

### Expected Layer Format

- **Type**: Raster (terra::SpatRaster)
- **Units**: tonnes/hectare de biomasse aérienne
- **Values**: Positives, NA pour non-forêt
- **CRS**: Any (reprojeté automatiquement si preprocess = TRUE)

### Calculation

```r
# Pseudo-code
biomass_values <- exactextractr::exact_extract(
  x = biomass_raster,
  y = units,
  fun = fun
)
carbon <- biomass_values * conversion_factor
return(carbon)
```

### Returns

- **Units**: tonnes de carbone par unité (si method = "sum")
- **Units**: tonnes/ha de carbone (si method = "mean")
- **NA**: Si unité hors extent du raster ou toutes valeurs NA

### Example
```r
carbon <- indicator_carbon(
  units = my_units,
  layers = my_layers,
  biomass_layer = "agb_sentinel",
  method = "sum"
)

# Résultat: [120.5, 95.3, 150.2, ...] tonnes C
```

---

## `indicator_biodiversity()`

### Purpose
Calculer un indice de biodiversité basé sur richesse ou diversité spécifique.

### Signature
```r
indicator_biodiversity(
  units,
  layers,
  species_layer = "species_richness",
  method = c("richness", "shannon", "simpson"),
  fun = "mean",
  na.rm = TRUE
)
```

### Parameters (Specific)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `species_layer` | `character` | `"species_richness"` | Raster de richesse spécifique ou abondances |
| `method` | `character` | `"richness"` | Type d'indice: richness (nb espèces), shannon (H'), simpson (D) |

### Expected Layer Format

- **richness**: Raster avec nombre d'espèces par pixel (integer)
- **shannon/simpson**: Raster multi-bandes avec abondances par espèce, ou raster pré-calculé d'indice

### Calculation

**Richness**:
```r
richness <- exactextractr::exact_extract(species_raster, units, fun = fun)
```

**Shannon** (H = -Σ(pi * ln(pi))):
```r
# Si raster d'abondances multi-bandes
# Calculer H' par pixel, puis agréger par unité
```

**Simpson** (D = 1 - Σ(pi²)):
```r
# Similaire Shannon
```

### Returns

- **richness**: Nombre moyen d'espèces
- **shannon**: Indice de Shannon (0 = faible diversité, >3 = haute)
- **simpson**: Indice de Simpson (0 = faible, 1 = haute)

### Example
```r
biodiv <- indicator_biodiversity(
  units, layers,
  species_layer = "ign_biodiv",
  method = "shannon"
)

# Résultat: [2.3, 1.8, 2.9, ...] (Shannon index)
```

---

## `indicator_water()`

### Purpose
Calculer un indicateur de régulation hydrique (Topographic Wetness Index ou proximité réseau hydro).

### Signature
```r
indicator_water(
  units,
  layers,
  method = c("twi", "proximity", "combined"),
  dem_layer = "dem",
  hydro_layer = "rivers",
  fun = "mean",
  na.rm = TRUE,
  buffer_dist = 100
)
```

### Parameters (Specific)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `method` | `character` | `"twi"` | "twi" (Topographic Wetness Index), "proximity" (distance réseau hydro), "combined" |
| `dem_layer` | `character` | `"dem"` | Raster MNT (requis pour TWI) |
| `hydro_layer` | `character` | `"rivers"` | Vecteur réseau hydrographique (requis pour proximity) |
| `buffer_dist` | `numeric` | `100` | Distance max pour proximity (mètres) |

### Expected Layer Format

- **DEM**: Raster, mètres d'altitude
- **Hydro**: Vecteur (LINESTRING), réseau hydrographique

### Calculation

**TWI** (Topographic Wetness Index):
```r
# TWI = ln(a / tan(β))
# a = upslope contributing area
# β = slope
# Utilise terra::terrain() pour slope
```

**Proximity**:
```r
# Distance euclidienne au réseau hydro
# Normalisée par buffer_dist (0 = très proche, 1 = loin)
proximity_score <- 1 - (distance / buffer_dist)
proximity_score <- pmax(proximity_score, 0)  # Clip à 0
```

**Combined**:
```r
combined <- 0.5 * twi_normalized + 0.5 * proximity_score
```

### Returns

- **TWI**: Valeur TWI moyenne (higher = plus humide)
- **proximity**: Score 0-1 (1 = très proche eau)
- **combined**: Moyenne des deux normalisés

### Example
```r
water <- indicator_water(
  units, layers,
  method = "twi",
  dem_layer = "ign_mnt"
)

# Résultat: [8.5, 6.2, 12.3, ...] (TWI values)
```

---

## `indicator_fragmentation()`

### Purpose
Calculer un indice de fragmentation forestière (nombre de patches, connectivité).

### Signature
```r
indicator_fragmentation(
  units,
  layers,
  landcover_layer = "landcover",
  forest_classes = c(1, 2, 3),
  method = c("n_patches", "edge_density", "connectivity"),
  fun = "mean",
  na.rm = TRUE
)
```

### Parameters (Specific)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `landcover_layer` | `character` | `"landcover"` | Raster occupation du sol |
| `forest_classes` | `numeric` | `c(1,2,3)` | Codes des classes forestières dans raster |
| `method` | `character` | `"n_patches"` | Type de métrique: n_patches, edge_density, connectivity |

### Expected Layer Format

- **Landcover**: Raster catégoriel (integer), codes d'occupation du sol

### Calculation

**n_patches**:
```r
# Pour chaque unité:
# 1. Masquer forêt (values in forest_classes)
# 2. Compter nb de patches contigus
# Moins de patches = moins fragmenté (score inversé)
```

**edge_density**:
```r
# Longueur totale des bordures forêt/non-forêt / surface
# Higher = plus fragmenté (score inversé)
```

**connectivity**:
```r
# Basé sur proximité entre patches
# Utilise landscapemetrics si disponible, sinon méthode simple
```

### Returns

- **n_patches**: Nombre de patches (inversé: 1/n pour scoring)
- **edge_density**: Densité de bordure km/km²
- **connectivity**: Score 0-1 (1 = connecté)

### Example
```r
frag <- indicator_fragmentation(
  units, layers,
  landcover_layer = "corine",
  forest_classes = c(311, 312, 313),  # Codes Corine
  method = "n_patches"
)

# Résultat: [3, 1, 7, ...] patches par unité
```

---

## `indicator_accessibility()`

### Purpose
Calculer l'accessibilité (distance aux routes et sentiers).

### Signature
```r
indicator_accessibility(
  units,
  layers,
  roads_layer = "roads",
  trails_layer = NULL,
  method = c("proximity", "density"),
  max_distance = 1000,
  decay_function = c("linear", "exponential"),
  fun = "mean",
  na.rm = TRUE
)
```

### Parameters (Specific)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `roads_layer` | `character` | `"roads"` | Vecteur routes (LINESTRING) |
| `trails_layer` | `character` | `NULL` | Vecteur sentiers (optionnel) |
| `method` | `character` | `"proximity"` | "proximity" (distance), "density" (longueur routes/surface) |
| `max_distance` | `numeric` | `1000` | Distance max considérée (mètres) |
| `decay_function` | `character` | `"linear"` | Fonction de décroissance pour proximity |

### Expected Layer Format

- **Roads/Trails**: Vecteur LINESTRING

### Calculation

**Proximity**:
```r
# Distance euclidienne minimum au réseau
# Score = 1 - (distance / max_distance)  # linear
# ou Score = exp(-distance / max_distance)  # exponential
```

**Density**:
```r
# Pour chaque unité:
# Longueur totale routes intersectées / surface unité
# Normalisé (higher = plus accessible)
```

### Returns

- **proximity**: Score 0-1 (1 = très accessible)
- **density**: km de routes/km² d'unité

### Example
```r
access <- indicator_accessibility(
  units, layers,
  roads_layer = "osm_roads",
  method = "proximity",
  max_distance = 500
)

# Résultat: [0.85, 0.32, 0.91, ...] (accessibility score)
```

---

## Error Handling (All Indicators)

### Common Errors

| Condition | Action |
|-----------|--------|
| Required layer missing | Return vector of `NA` + warning |
| Layer wrong type (raster vs vector) | Abort with error |
| No intersection units/layer | Return vector of `NA` + warning |
| Calculation error (e.g., slope on flat DEM) | Return `NA` for affected units + warning |

### Standard Error Message Format

```r
cli::cli_warn(c(
  "!" = "indicator_{name}(): calculation issue",
  "i" = "Problem: {detailed_issue}",
  "i" = "Affected units: {n_affected}/{nrow(units)}",
  ">" = "Returning NA for affected units"
))
```

---

**Contract Status**: ✅ Complete - 5 indicators specified
