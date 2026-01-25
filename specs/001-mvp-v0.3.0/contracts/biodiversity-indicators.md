# Function Contracts: Biodiversity Indicators (B-Family)

**Feature**: MVP v0.3.0
**Date**: 2026-01-05
**Family**: B (Biodiversity / Vivant)

## Overview

This document specifies the function signatures and behavior contracts for the 3 biodiversity indicators: B1 (protection), B2 (structural diversity), B3 (ecological connectivity).

---

## indicator_biodiversity_protection()

### Signature

```r
indicator_biodiversity_protection(
  units,
  protected_areas = NULL,
  source = c("wfs", "local"),
  wfs_url = "https://inpn.mnhn.fr/geoserver/wfs",
  protection_types = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI", "N2000_SPA", "PN", "PNR"),
  min_overlap = 0.01,
  preprocess = FALSE
)
```

### Parameters

- **units** (sf, required): Forest parcel geometries with defined CRS
- **protected_areas** (sf, optional): Pre-loaded protected area polygons; if NULL, fetched from source
- **source** (character): "wfs" for INPN API or "local" for user-provided data
- **wfs_url** (character): WFS endpoint URL for INPN data
- **protection_types** (character vector): Which protection designations to include
- **min_overlap** (numeric): Minimum overlap fraction to count as protected (default 0.01 = 1%)
- **preprocess** (logical): If TRUE, harmonize CRS and validate geometries automatically

### Returns

**sf object** with added columns:
- `B1`: Numeric [0-100], percentage of area in protected zones
- `B1_protection_types`: Character, comma-separated list of applicable protection types

### Behavior Contract

**Preconditions**:
- `units` must be sf object with POLYGON/MULTIPOLYGON geometry
- `units` must have defined CRS
- If `source="local"`, `protected_areas` must be provided
- If `source="wfs"`, internet connection required

**Postconditions**:
- All input rows preserved (no row filtering)
- B1 column added with values in [0-100] range
- NA values only if geometry invalid or CRS transformation fails
- Warning issued if WFS fetch fails (falls back to NA)

**Side Effects**:
- May fetch data from network (if source="wfs")
- May transform CRS (if preprocess=TRUE)
- Prints informative messages via cli

**Error Handling**:
- Stops if units not sf object
- Stops if CRS undefined and preprocess=FALSE
- Warns if WFS unreachable, returns NA for B1
- Warns if protected_areas empty, returns 0 for all B1 values

---

## indicator_biodiversity_structure()

### Signature

```r
indicator_biodiversity_structure(
  units,
  strata_field = "strata_classes",
  age_field = "age_classes",
  method = c("shannon", "simpson"),
  weights = c(strata = 0.6, age = 0.4),
  use_height_cv = FALSE
)
```

### Parameters

- **units** (sf, required): Forest parcels with structural attributes
- **strata_field** (character): Column name containing canopy strata categories
- **age_field** (character): Column name containing age class categories
- **method** (character): Diversity index calculation ("shannon" or "simpson")
- **weights** (named numeric vector): Weights for strata vs. age components
- **use_height_cv** (logical): If TRUE, use height coefficient of variation as fallback when strata missing

### Returns

**sf object** with added columns:
- `B2`: Numeric [0-100], structural diversity index
- `B2_H_strata`: Numeric, raw Shannon H for strata (if method="shannon")
- `B2_H_age`: Numeric, raw Shannon H for age classes (if method="shannon")

### Behavior Contract

**Preconditions**:
- `units` must have columns specified by `strata_field` and/or `age_field`
- Strata/age fields must be categorical (factor or character)
- If both fields missing and `use_height_cv=FALSE`, error
- `weights` must sum to 1 (auto-normalized if not)

**Postconditions**:
- B2 values in [0-100] range
- B2 = 0 for monocultures (single stratum, single age class)
- B2 = 100 for maximally diverse stands (theoretical H_max)
- NA only if required fields contain all NA values

**Error Handling**:
- Stops if neither strata_field nor age_field exists in units
- Warns if >20% of units have NA in structural fields
- Falls back to height CV if use_height_cv=TRUE and strata missing

---

## indicator_biodiversity_connectivity()

### Signature

```r
indicator_biodiversity_connectivity(
  units,
  corridors,
  distance_method = c("edge", "centroid"),
  max_distance = 5000,
  normalize = TRUE
)
```

### Parameters

- **units** (sf, required): Forest parcel geometries
- **corridors** (sf, required): Ecological corridor geometries (lines or polygons)
- **distance_method** (character): "edge" for nearest edge distance, "centroid" for centroid-to-centroid
- **max_distance** (numeric): Maximum distance for normalization cap (meters)
- **normalize** (logical): If TRUE, return B3_norm (0-100); if FALSE, return raw distance

### Returns

**sf object** with added columns:
- `B3`: Numeric [0-∞], distance to nearest corridor (meters)
- `B3_norm` (if normalize=TRUE): Numeric [0-100], normalized connectivity score

### Behavior Contract

**Preconditions**:
- `units` and `corridors` must have same CRS (or preprocess=TRUE)
- `corridors` must not be empty
- Units and corridors must overlap spatially (warnings if no overlap)

**Postconditions**:
- B3 = 0 if parcel intersects corridor
- B3 = distance(parcel, nearest_corridor) otherwise
- B3_norm = 100 if distance = 0 (connected)
- B3_norm = 0 if distance >= max_distance (isolated)
- B3_norm = 100 × (1 - distance/max_distance) for intermediate

**Normalization Formula**:
```r
B3_norm = 100 * (1 - min(B3, max_distance) / max_distance)
```

**Error Handling**:
- Stops if corridors not provided
- Warns if CRS mismatch and preprocess=FALSE
- Warns if no units within max_distance of any corridor

---

## Common Patterns (All B Functions)

### Bilingual Support

All functions use `msg_info()`, `msg_warn()`, `msg_error()` from R/i18n.R for bilingual messages (FR/EN).

### Progress Reporting

For large datasets (>100 units), display progress via cli:
```r
cli::cli_progress_bar("Calculating B1", total = nrow(units))
```

### Validation

All functions call internal validators:
```r
validate_sf(units, require_crs = TRUE, require_valid = TRUE)
validate_crs_match(units, other_layer) # if applicable
```

### Return Value

All functions return the **input sf object** with **added columns**. Original columns and geometry preserved.

### Testing Expectations

Each function has:
- Unit tests with mock data (10+ test cases)
- Integration tests with massif_demo (real workflow)
- Regression tests with fixtures (expected B1/B2/B3 values stored)
- Edge case tests (NA handling, empty inputs, CRS mismatches)

---

## Usage Examples

### B1 Example

```r
library(nemeton)
data(massif_demo_units)

# Fetch protected areas from INPN
units <- indicator_biodiversity_protection(
  massif_demo_units,
  source = "wfs"
)

# View results
summary(units$B1)  # % protected
table(units$B1_protection_types)  # Which types
```

### B2 Example

```r
# Assuming BD Forêt attributes loaded
units$strata_classes <- c("Emergent", "Dominant", "Intermediate")  # example
units$age_classes <- c("Mature", "Old", "Ancient")  # example

units <- indicator_biodiversity_structure(
  units,
  strata_field = "strata_classes",
  age_field = "age_classes"
)

hist(units$B2, main = "Structural Diversity Distribution")
```

### B3 Example

```r
# Load corridor data
corridors <- sf::st_read("trame_verte.gpkg")

units <- indicator_biodiversity_connectivity(
  units,
  corridors = corridors,
  max_distance = 3000  # 3km threshold
)

# Map connectivity
plot(units["B3_norm"], main = "Ecological Connectivity")
```

---

**Document Version**: 1.0
**Status**: Phase 1 Design Complete
