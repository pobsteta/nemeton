# Data Model: MVP v0.2.0 - Temporal & Spatial Indicators

**Feature**: MVP v0.2.0 - Temporal & Spatial Indicators Extension
**Branch**: 001-mvp-v0.2.0
**Date**: 2026-01-05
**Status**: Phase 1 - Design

---

## Overview

This document describes the core data entities and their relationships for the temporal and multi-family indicator extension. All entities are implemented as R S3 classes following nemeton constitution principles (simple, interoperable, extensible).

**Key Design Principles**:
1. **Backward Compatibility**: All new entities extend or coexist with v0.1.0 `nemeton_units` S3 class
2. **Spatial-First**: All indicator data attached to `sf` spatial objects (no separate data frames)
3. **Metadata-Rich**: Entities carry provenance, calculation parameters, and validation info
4. **Lazy Evaluation**: Large rasters/vectors loaded on-demand via existing `nemeton_layers` system

---

## Entity Diagram

```
┌─────────────────────┐
│  Temporal Dataset   │ 1:N  ┌──────────────────┐
│  (nemeton_temporal) │─────▶│  nemeton_units   │
└─────────────────────┘      │  (single period) │
         │                   └──────────────────┘
         │ metadata                    │
         │                             │ contains
         ▼                             ▼
┌─────────────────────┐      ┌──────────────────┐
│  Period Metadata    │      │  Sub-Indicators  │
│  (dates, labels)    │      │  (C1, W2, etc.)  │
└─────────────────────┘      └──────────────────┘
                                      │ aggregates into
                                      ▼
                             ┌──────────────────┐
                             │  Indicator       │
                             │  Family          │
                             │  (score_carbon)  │
                             └──────────────────┘
                                      │ uses
                                      ▼
                             ┌──────────────────┐
                             │  Allometric      │
                             │  Model           │
                             │  (for C1)        │
                             └──────────────────┘

┌──────────────────┐
│  Change Rate     │ calculated from
│  (%/year)        │◀────────────────┐
└──────────────────┘                 │
                            Temporal Dataset
```

---

## Core Entities

### 1. Temporal Dataset (`nemeton_temporal`)

**Purpose**: Container for multi-period indicator values with temporal indexing.

**Structure**:
```r
# S3 class: nemeton_temporal (extends list)
temporal_dataset <- list(
  periods = list(
    "2015" = nemeton_units_2015,  # Each period is a standard nemeton_units sf object
    "2020" = nemeton_units_2020,
    "2025" = nemeton_units_2025
  ),
  metadata = list(
    dates = as.Date(c("2015-01-01", "2020-01-01", "2025-01-01")),
    period_labels = c("baseline", "mid-term", "target"),
    alignment = data.frame(
      unit_id = c("P01", "P02", ...),
      present_2015 = c(TRUE, TRUE, ...),
      present_2020 = c(TRUE, FALSE, ...),  # P02 removed/merged
      present_2025 = c(TRUE, TRUE, ...)
    ),
    created_at = Sys.time(),
    nemeton_version = "0.2.0"
  )
)
class(temporal_dataset) <- c("nemeton_temporal", "list")
```

**Attributes**:
- `periods`: Named list of `nemeton_units` objects (one per time period)
- `metadata$dates`: Date vector (same length as periods)
- `metadata$period_labels`: Human-readable labels (optional, defaults to dates)
- `metadata$alignment`: Data frame tracking which units present in which periods
- `metadata$created_at`: Timestamp
- `metadata$nemeton_version`: Package version that created dataset

**Validation Rules**:
- All periods must have same CRS (enforced by `nemeton_temporal()` constructor)
- All periods must have same indicator columns (or NA for missing periods)
- `unit_id` column required for temporal matching (flexible: nemeton_id, parcel_id, id, geo_parcelle)
- At least 2 periods required for change rate calculations

**Relationships**:
- **Contains** 2+ `nemeton_units` objects
- **Used by** `calculate_change_rate()`, `plot_temporal_trends()`

**Methods**:
- `print.nemeton_temporal()`: Display period summary
- `summary.nemeton_temporal()`: Indicator statistics across periods
- `subset.nemeton_temporal()`: Filter periods or units
- `plot.nemeton_temporal()`: Default time-series plot

**Example**:
```r
# Create temporal dataset
data(massif_demo_units)
layers <- massif_demo_layers()

# Compute for 2015
results_2015 <- nemeton_compute(massif_demo_units, layers,
                                indicators = "all", forest_values = c(1,2,3))

# Simulate 2020 data (same units, new raster values)
results_2020 <- nemeton_compute(massif_demo_units, layers_2020,
                                indicators = "all", forest_values = c(1,2,3))

# Create temporal dataset
temporal <- nemeton_temporal(
  list("2015" = results_2015, "2020" = results_2020),
  dates = c("2015-01-01", "2020-01-01")
)
```

---

### 2. Indicator Family (`nemeton_family`)

**Purpose**: Logical grouping of related sub-indicators representing a single ecosystem service dimension.

**Structure**:
```r
# S3 class: nemeton_family (extends character vector)
family_info <- list(
  code = "C",                    # Single-letter code
  name = "Carbon/Vitality",      # Full name
  sub_indicators = c("C1", "C2"),  # Sub-indicator codes
  score_column = "score_carbon",   # Composite score column name
  description = "Carbon stock and forest health",
  reference_thresholds = list(
    C1 = c(low = 50, medium = 100, high = 150),  # tC/ha
    C2 = c(low = 0.4, medium = 0.6, high = 0.8)   # NDVI
  ),
  weights = c(C1 = 0.7, C2 = 0.3),  # Default aggregation weights
  polarity = c(C1 = "positive", C2 = "positive")  # Higher is better
)
class(family_info) <- c("nemeton_family", "list")
```

**Predefined Families (v0.2.0)**:
- **C** (Carbon/Vitality): C1 (biomass), C2 (NDVI)
- **W** (Water): W1 (network density), W2 (wetlands %), W3 (TWI)
- **F** (Soil Fertility): F1 (fertility class), F2 (erosion risk)
- **L** (Landscape): L1 (fragmentation), L2 (edge ratio)

**Future Families** (v0.3.0+):
- **B** (Biodiversity): B1, B2, B3
- **R** (Risks): R1, R2, R3
- **T** (Temporal): T1, T2
- **A** (Air/Microclimate): A1, A2
- **S** (Social): S1, S2, S3
- **P** (Productive): P1, P2, P3
- **E** (Energy): E1, E2
- **N** (Naturalness): N1, N2, N3

**Validation Rules**:
- Family code must be single uppercase letter (A-Z)
- Sub-indicators must match pattern `{code}{digit}` (e.g., C1, W2)
- Weights must sum to 1.0 (enforced by `create_family_index()`)
- All sub-indicators must be present in dataset or marked as optional

**Relationships**:
- **Contains** 1-5 Sub-Indicators
- **Produces** Family Score (composite index)

**Methods**:
- `print.nemeton_family()`: Display family info
- `validate_family()`: Check if dataset has required sub-indicators

**Example**:
```r
# Get family info
carbon_family <- nemeton_family("C")
print(carbon_family)
# Carbon/Vitality (C)
#   Sub-indicators: C1 (biomass), C2 (NDVI)
#   Default weights: C1=70%, C2=30%
#   Thresholds: C1 > 100 tC/ha = high carbon stock

# Check if dataset has family
validate_family(results, "C")  # TRUE if C1 and C2 columns present
```

---

### 3. Sub-Indicator

**Purpose**: Individual measurement within an indicator family.

**Structure**:
```r
# Stored as column in nemeton_units sf object
# Attributes attached to column describe metadata

# Example: C1 biomass sub-indicator
results$C1  # Numeric vector: biomass values (tC/ha)

# Column attributes
attr(results$C1, "indicator_code") <- "C1"
attr(results$C1, "indicator_name") <- "Aboveground Biomass Stock"
attr(results$C1, "family") <- "C"
attr(results$C1, "units") <- "tC/ha"
attr(results$C1, "calculation_method") <- "allometric"
attr(results$C1, "parameters") <- list(
  species_model = "Quercus_Dupouey2011",
  age_source = "BD_Foret_v2",
  density_adjustment = TRUE
)
attr(results$C1, "data_sources") <- c("BD_Foret_v2", "biomass_raster")
attr(results$C1, "calculated_at") <- Sys.time()
```

**Attributes**:
- `indicator_code`: Unique identifier (C1, W2, F1, etc.)
- `indicator_name`: Human-readable name
- `family`: Parent family code
- `units`: Physical units (tC/ha, km/ha, %, unitless, etc.)
- `calculation_method`: Algorithm used (allometric, zonal_mean, TWI, etc.)
- `parameters`: Named list of calculation parameters
- `data_sources`: Vector of input data sources
- `calculated_at`: Timestamp
- `polarity`: "positive" (higher is better) or "negative" (lower is better)

**Validation Rules**:
- Code format: `[A-Z][0-9]` (single letter + single digit)
- Values must be numeric (can contain NA)
- Units must be specified (for normalization)
- Polarity required for inverse normalization

**Naming Convention** (Constitution compliant):
- Function name: `indicator_{family}_{subindicator}()` (e.g., `indicator_carbon_biomass()`)
- Column name: `{code}` (e.g., `C1`, `W3`)
- Normalized column: `{code}_norm` (e.g., `C1_norm`)

**Example Sub-Indicators (v0.2.0)**:

| Code | Name | Family | Units | Polarity | Method |
|------|------|--------|-------|----------|--------|
| C1 | Aboveground Biomass | C | tC/ha | + | Allometric |
| C2 | NDVI Mean/Trend | C | unitless | + | Zonal mean |
| W1 | Hydrographic Network Density | W | km/ha | + | Spatial length |
| W2 | Wetland Coverage | W | % | + | Zonal proportion |
| W3 | Topographic Wetness Index | W | unitless | + | TWI algorithm |
| F1 | Soil Fertility Class | F | 1-5 scale | + | BD Sol extraction |
| F2 | Erosion Risk | F | 0-100 | - | Slope × landcover |
| L1 | Fragmentation | L | patches/km² | - | Patch count |
| L2 | Edge Ratio | L | m/ha | - | Perimeter/area |

---

### 4. Allometric Model

**Purpose**: Mathematical relationship for biomass estimation from forest inventory data.

**Structure**:
```r
# Lookup table stored in package sysdata (R/sysdata.rda)
allometric_models <- data.frame(
  species = c("Quercus", "Fagus", "Pinus", "Abies", "Generic"),
  model_type = c("power", "power", "exponential", "power", "power"),
  equation = c("a * DBH^b * H^c", ...),  # Human-readable
  a = c(0.0437, 0.0389, ...),  # Coefficients
  b = c(2.13, 2.24, ...),
  c = c(0.87, 0.82, ...),
  source = c("Dupouey2011", "Bontemps2012", "Vallet2011", "Wutzler2008", "Wutzler2008"),
  citation = c(
    "Dupouey et al. (2011). IFN Mémorial.",
    "Bontemps & Duplat (2012). Revue Forestière Française.",
    ...
  ),
  valid_age_range = c("20-200", "30-150", ...),  # years
  valid_density_range = c("0.3-1.0", "0.4-1.0", ...),  # crown closure
  accuracy_rmse = c(15.2, 18.7, ...)  # % RMSE from validation
)
```

**Attributes**:
- `species`: Tree species code (IGN classification)
- `model_type`: "power", "exponential", "linear"
- `equation`: Mathematical formula (for documentation)
- `a, b, c, ...`: Model coefficients
- `source`: Short reference ID
- `citation`: Full bibliographic reference
- `valid_age_range`: Applicable age range (years)
- `valid_density_range`: Applicable crown closure
- `accuracy_rmse`: Root Mean Square Error from validation (%)

**Usage**:
```r
# Internal function (not exported)
calculate_biomass <- function(species, age, density, height = NULL) {
  model <- allometric_models[allometric_models$species == species, ]

  if (nrow(model) == 0) {
    warning("Unknown species, using generic model")
    model <- allometric_models[allometric_models$species == "Generic", ]
  }

  # Apply model equation
  if (model$model_type == "power") {
    biomass <- model$a * (age^model$b) * (density^model$c)
  }

  biomass  # tC/ha
}
```

**Validation**:
- Fixtures: `tests/testthat/fixtures/allometric_reference.rds` contains IFN reference values
- Test suite verifies ±15% accuracy for each species
- Out-of-range warnings for age/density outside valid range

**Relationships**:
- **Used by** `indicator_carbon_biomass()` (C1 sub-indicator)
- **Validated against** IFN forest inventory data

---

### 5. Family Score (`score_{family}`)

**Purpose**: Composite index aggregating multiple sub-indicators within a family (0-100 scale).

**Structure**:
```r
# Stored as column in nemeton_units sf object
results$score_carbon  # Numeric vector: composite carbon score (0-100)

# Column attributes
attr(results$score_carbon, "family") <- "C"
attr(results$score_carbon, "sub_indicators") <- c("C1_norm", "C2_norm")
attr(results$score_carbon, "weights") <- c(C1_norm = 0.7, C2_norm = 0.3)
attr(results$score_carbon, "method") <- "weighted_mean"
attr(results$score_carbon, "calculated_at") <- Sys.time()
attr(results$score_carbon, "missing_handling") <- "na.rm=FALSE"  # or "pairwise"
```

**Calculation**:
```r
# Weighted arithmetic mean (default)
score_carbon = (C1_norm * 0.7) + (C2_norm * 0.3)

# All sub-indicators must be normalized to 0-100 before aggregation
```

**Validation Rules**:
- All input sub-indicators must be normalized (`*_norm` suffix)
- Weights must sum to 1.0
- Output range: [0, 100]
- NA handling: If any sub-indicator is NA, family score is NA (unless `na.rm=TRUE`)

**Missing Sub-Indicator Handling** (Partial Family Scores):
```r
# Example: C2 (NDVI) unavailable for some units
create_family_index(results, family = "carbon", partial = TRUE)
# → Renormalizes weights: C1_norm weight becomes 1.0 for units with NA C2
# → Flags partial score in attributes
```

**Relationships**:
- **Aggregates** 1-5 normalized Sub-Indicators
- **Used in** `nemeton_radar()` for multi-family visualization
- **Compared across** units, scenarios, periods

**Example**:
```r
# Create family score
results <- create_family_index(
  results,
  family = "carbon",
  weights = c(C1_norm = 0.7, C2_norm = 0.3),
  method = "mean"
)

# Visualize on radar
nemeton_radar(results, unit_id = "P01", families = TRUE)
# → Shows 4 family scores (C, W, F, L) on 4-axis radar
```

---

### 6. Change Rate

**Purpose**: Temporal derivative of indicator value (annual change).

**Structure**:
```r
# Stored in nemeton_units sf object derived from temporal dataset
change_rates$carbon_rate_abs  # Absolute change (tC/ha/year)
change_rates$carbon_rate_rel  # Relative change (%/year)

# Column attributes
attr(change_rates$carbon_rate_abs, "indicator") <- "carbon"
attr(change_rates$carbon_rate_abs, "type") <- "absolute"
attr(change_rates$carbon_rate_abs, "units") <- "tC/ha/year"
attr(change_rates$carbon_rate_abs, "period_start") <- as.Date("2015-01-01")
attr(change_rates$carbon_rate_abs, "period_end") <- as.Date("2020-01-01")
attr(change_rates$carbon_rate_abs, "years_elapsed") <- 5
```

**Calculation Formulas**:
```r
# Absolute change rate
rate_abs = (value_t2 - value_t1) / (t2 - t1)
# Units: [indicator_units] / year

# Relative change rate
rate_rel = ((value_t2 - value_t1) / value_t1) / (t2 - t1) * 100
# Units: %/year
```

**Edge Cases**:
- **Zero baseline** (value_t1 = 0): `rate_rel = Inf` or `NA` (warn user)
- **Same value** (value_t2 = value_t1): `rate = 0`
- **Missing period** (unit present in t1 but not t2): `rate = NA`, flag in alignment metadata

**Validation Rules**:
- Periods must be chronologically ordered (t2 > t1)
- Units matched by ID across periods
- At least 1 year between periods (no same-date comparisons)

**Relationships**:
- **Calculated from** Temporal Dataset
- **Visualized in** `plot_temporal_trends()` (line plots with slope)
- **Used for** intervention impact assessment, degradation detection

**Example**:
```r
# Calculate change rates
rates <- calculate_change_rate(
  temporal_dataset,
  indicators = c("carbon", "biodiversity", "water"),
  type = "both"  # absolute + relative
)

# Filter units with carbon gain > 5 tC/ha/year
high_carbon_gain <- rates[rates$carbon_rate_abs > 5, ]
```

---

## Derived Entities

### 7. Normalized Indicator (`{code}_norm`)

**Purpose**: Indicator value rescaled to 0-100 for cross-indicator comparison.

**Structure**: Column in `nemeton_units` with `_norm` suffix.

**Normalization Methods** (inherited from v0.1.0):
- **min-max**: `(x - min) / (max - min) * 100`
- **z-score**: `(x - mean) / sd * 20 + 50` (capped at [0,100])
- **quantile**: Percentile rank × 100

**Polarity Handling**:
- Positive indicators (C1, W1): Higher value = higher score
- Negative indicators (F2, L1): Lower value = higher score (inverted)

**Example**:
```r
normalized <- normalize_indicators(
  results,
  indicators = c("C1", "F2"),
  method = "minmax"
)
# → Creates C1_norm (direct) and F2_norm (inverted)
```

---

### 8. Intervention Marker

**Purpose**: Flag specific dates/events in temporal analysis (e.g., thinning, fire, harvest).

**Structure**: Metadata in `nemeton_temporal`.

```r
temporal_dataset$metadata$interventions <- data.frame(
  date = as.Date(c("2017-06-15", "2019-03-20")),
  type = c("thinning", "prescribed_burn"),
  units_affected = c("P01,P03,P05", "P10,P12"),
  description = c("Selective thinning 30%", "Prescribed burn 5 ha")
)
```

**Visualization**:
- `plot_temporal_trends(..., interventions = TRUE)` draws vertical lines at intervention dates
- Shaded regions for before/after comparison

---

## Relationships Summary

```
Temporal Dataset
  └── contains 2+ nemeton_units (one per period)
        └── each nemeton_units contains
              ├── Sub-Indicators (C1, W2, etc.)
              ├── Normalized Indicators (C1_norm, etc.)
              └── Family Scores (score_carbon, etc.)

Temporal Dataset
  └── generates Change Rates
        └── used in temporal plots

Indicator Family
  └── groups Sub-Indicators
        └── aggregates into Family Score

Allometric Model
  └── used by indicator_carbon_biomass()
        └── produces C1 sub-indicator
```

---

## Storage & Persistence

### In-Memory (R session)
- All entities are R objects (S3 classes)
- Spatial data: `sf` and `terra` objects (standard R spatial formats)

### On-Disk (package data)
- `data/massif_demo_units.rda`: Example `nemeton_units` object
- `data/massif_demo_temporal.rda`: Example `nemeton_temporal` object (if feasible to create)
- `R/sysdata.rda`: Internal data (allometric_models lookup table)

### Test Fixtures
- `tests/testthat/fixtures/allometric_reference.rds`: IFN validation data
- `tests/testthat/fixtures/twi_reference.rds`: Validated TWI values
- `tests/testthat/fixtures/temporal_test_data.rds`: Multi-period test dataset

### User Data (External)
- BD Forêt v2: User-provided Geo Package / Shapefile / CSV
- BD Sol: User-provided raster (GeoTIFF) or vector
- Sentinel-2 NDVI: User-provided GeoTIFF time series

---

## Validation & Constraints

### Data Quality Checks
- **CRS Consistency**: All spatial layers same projection (enforced by preprocessing)
- **Unit ID Matching**: Temporal datasets require consistent IDs across periods
- **Indicator Range**: Values within expected physical ranges (e.g., NDVI in [0,1])
- **Missing Data**: NA handling explicit, documented in function parameters

### Performance Constraints
- **Max Dataset Size**: 1000 units (constitution requirement for `nemeton_compute()`)
- **Max Raster Size**: Lazy loading, no full raster in memory
- **Test Suite Speed**: < 5 minutes (constitution requirement)

### Documentation Requirements
- Every entity has roxygen2 `@format` documentation
- Example datasets demonstrate all entities
- Vignettes show entity creation and manipulation

---

## Migration from v0.1.0

### Backward Compatibility
- Existing `nemeton_units` objects work unchanged
- New columns added (`C1`, `W3`, etc.) coexist with old (`carbon`, `water`)
- Deprecated `indicator_carbon()` wraps `indicator_carbon_biomass()`

### Data Migration
- No migration needed - v0.1.0 datasets remain valid
- Users can add new indicators via `nemeton_compute(..., indicators = c("C1", "W3"))`

---

## Next Steps (Phase 2)

This data model enables:
1. **tasks.md** generation (`/speckit.tasks`) - Implementation task breakdown
2. **Test fixture creation** - Allometric validation, TWI reference values
3. **Vignette development** - temporal-analysis.Rmd, indicator-families.Rmd
4. **Implementation** - R code following TDD principles

**Data Model**: ✅ COMPLETE
**Next**: Create `quickstart.md` and proceed to task breakdown.
