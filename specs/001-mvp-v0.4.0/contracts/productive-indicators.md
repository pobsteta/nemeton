# API Contract: Productive Indicators (P Family)

**Family**: Production & Economic Services
**Feature**: [spec.md](../spec.md) | **Data Model**: [data-model.md](../data-model.md)
**Created**: 2026-01-05

## Overview

This contract defines the API for calculating productive/economic indicators (P1-P3) that quantify timber production potential and economic valorization. All functions accept `sf` objects with forest inventory attributes and return enriched `sf` objects with new indicator columns.

---

## P1: Standing Volume Indicator

### Function Signature

```r
indicator_productive_volume(
  units,
  species_field = "species",
  dbh_field = "dbh",
  height_field = "height",
  density_field = "density",
  equation_source = c("ifn", "generic"),
  fallback = c("genus", "generic", "none"),
  column_name = "P1",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with forest inventory attributes |
| `species_field` | character | No | `"species"` | Column name containing species (scientific/common name) |
| `dbh_field` | character | No | `"dbh"` | Column name for diameter at breast height (cm) |
| `height_field` | character | No | `"height"` | Column name for total height (m), optional if estimated from DBH |
| `density_field` | character | No | `"density"` | Column name for stems per hectare, optional (default by species) |
| `equation_source` | character | No | `"ifn"` | Allometric equation database ("ifn" or "generic") |
| `fallback` | character | No | `"genus"` | Fallback strategy if species not found: "genus" (use genus-level), "generic" (use default), "none" (return NA) |
| `column_name` | character | No | `"P1"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Standing volume in m³/ha

### Behavior

1. **Equation Selection**:
   - Lookup species in IFN allometric database
   - If not found, try fallback strategy:
     - `"genus"`: Extract genus from species name, use genus-level equation
     - `"generic"`: Use default equation for deciduous/coniferous
     - `"none"`: Return NA with warning

2. **Volume Calculation**:
   ```r
   # Single tree volume
   volume_tree = equation(dbh, height, species_params)

   # If height missing, estimate from DBH
   if (is.na(height)) {
     height_est = height_equation(dbh, species)
   }

   # Volume per hectare
   volume_ha = volume_tree × density
   ```

3. **Density Defaults**:
   - If `density_field` missing, use species-specific default from lookup table
   - Managed stands: 150-400 stems/ha (species-dependent)
   - Natural stands: 300-800 stems/ha

4. **Edge Cases**:
   - DBH = 0 or NA: Set P1 = 0 with message
   - Species not found + fallback="none": P1 = NA with warning
   - Extreme values (>1000 m³/ha): Warn (possible error)

### Example

```r
library(nemeton)
library(sf)

# Load demo data
data(massif_demo_units_extended)

# Calculate P1
result <- indicator_productive_volume(
  units = massif_demo_units_extended,
  species_field = "dominant_species",
  dbh_field = "mean_dbh",
  height_field = "mean_height",
  fallback = "genus"
)

# Check results
summary(result$P1)
#> Min: 45.3, Median: 187.5, Max: 412.8 m³/ha
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| Required field missing | Stop: "Column '{field}' not found in units" |
| All species unknown + fallback="none" | Warn, all P1 = NA |
| Invalid DBH values (<0) | Warn, set P1 = NA for invalid rows |
| Volume >1000 m³/ha | Warn: "Exceptionally high volume, verify data" |

### Dependencies

- `sf`
- Internal IFN equation database (in `data/ifn_allometry.rda`)
- `dplyr` (data manipulation)

### Performance

- 20 parcels: <1 second
- 1000 parcels: ~5 seconds

---

## P2: Site Productivity Indicator

### Function Signature

```r
indicator_productive_station(
  units,
  species_field = "species",
  fertility_field = "F1",
  climate = NULL,
  temp_field = "temp_annual",
  precip_field = "precip_annual",
  productivity_tables = "onf",
  column_name = "P2",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with fertility and optional climate data |
| `species_field` | character | No | `"species"` | Column name containing species |
| `fertility_field` | character | No | `"F1"` | Column name for soil fertility indicator (from v0.2.0) |
| `climate` | `SpatRaster` | No | `NULL` | Climate raster stack (temp, precip), optional |
| `temp_field` | character | No | `"temp_annual"` | Column or climate layer for annual temperature (°C) |
| `precip_field` | character | No | `"precip_annual"` | Column or climate layer for annual precipitation (mm) |
| `productivity_tables` | character | No | `"onf"` | Productivity lookup source ("onf" or "ifn") |
| `column_name` | character | No | `"P2"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Site productivity index 0-100

### Behavior

1. **Fertility Component** (from existing F1):
   - Extract `fertility_field` value
   - Normalize to 0-1 scale if not already

2. **Climate Suitability**:
   - If `climate` provided: Extract temp/precip at unit centroids
   - If climate fields in units: Use directly
   - If neither: Use regional defaults with message
   - Calculate optimality: `climate_suit = 1 - abs(actual - optimal) / tolerance`

3. **Species-Site Matching**:
   - Lookup species requirements from productivity tables
   - Match fertility class + climate to expected productivity class
   - Score: Optimal=100, Sub-optimal=60, Poor=30

4. **Composite**:
   ```r
   P2 = fertility_norm × climate_suit × species_match
   P2_scaled = P2 × 100  # Scale to 0-100
   ```

### Example

```r
# Assuming F1 already calculated
result <- indicator_productive_station(
  units = massif_demo_units_extended,
  species_field = "dominant_species",
  fertility_field = "F1"
  # Climate will use regional defaults
)

summary(result$P2)
#> Min: 22.5, Median: 65.3, Max: 94.7
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| F1 field missing | Stop: "Soil fertility (F1) required" |
| Climate extraction fails | Warn, use regional defaults |
| Species not in productivity tables | Warn, use generic deciduous/coniferous |

### Dependencies

- `sf`
- `terra` (climate extraction if raster provided)
- Internal productivity tables (`data/productivity_tables.rda`)

### Performance

- 20 parcels, no climate: <1 second
- 20 parcels, with climate raster: ~3 seconds

---

## P3: Wood Quality Indicator

### Function Signature

```r
indicator_productive_quality(
  units,
  species_field = "species",
  form_field = "stem_form",
  dbh_field = "dbh",
  defects_field = "defects",
  quality_thresholds = "default",
  weights = c(form = 0.4, diameter = 0.3, defects = 0.3),
  column_name = "P3",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with quality attributes |
| `species_field` | character | No | `"species"` | Column name for species |
| `form_field` | character | No | `"stem_form"` | Column for stem form (straight/curved/crooked or 0-2 scale) |
| `dbh_field` | character | No | `"dbh"` | Column for diameter at breast height (cm) |
| `defects_field` | character | No | `"defects"` | Column for defect assessment (none/minor/major or 0-2 scale) |
| `quality_thresholds` | character/list | No | `"default"` | Threshold source or custom list |
| `weights` | named numeric | No | See above | Component weights (must sum to 1.0) |
| `column_name` | character | No | `"P3"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Wood quality score 0-100
- `{column_name}_form` (numeric): Form component score
- `{column_name}_diameter` (numeric): Diameter component score
- `{column_name}_defects` (numeric): Defects component score

### Behavior

1. **Form Component** (0-40 points):
   - Straight (0): 40 pts
   - Slight curve (1): 25 pts
   - Crooked (2): 0 pts

2. **Diameter Component** (0-30 points):
   - Lookup species-specific sawlog/pulpwood thresholds
   - DBH ≥ sawlog_threshold: 30 pts
   - DBH ≥ pulpwood_threshold: 15 pts
   - Below: 0 pts

3. **Defects Component** (0-30 points):
   - None (0): 30 pts
   - Minor (1): 15 pts
   - Major (2): 0 pts

4. **Composite**:
   ```r
   P3 = weights$form × form_score +
        weights$diameter × diam_score +
        weights$defects × defects_score
   ```

### Example

```r
result <- indicator_productive_quality(
  units = massif_demo_units_extended,
  species_field = "dominant_species",
  form_field = "stem_quality",  # Assume 0/1/2 encoding
  dbh_field = "mean_dbh",
  defects_field = "defect_level"
)

# Component breakdown
result[, c("P3", "P3_form", "P3_diameter", "P3_defects")]
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| Weights don't sum to 1.0 | Stop with error |
| Form/defects not in 0-2 range | Warn, attempt coercion or set NA |
| Species threshold not found | Warn, use generic threshold (30cm sawlog, 15cm pulpwood) |

### Dependencies

- `sf`
- Internal quality threshold tables (`data/quality_thresholds.rda`)

### Performance

- 20 parcels: <1 second
- 1000 parcels: ~2 seconds

---

## Integration with Family System

```r
# Calculate all P indicators
units_with_P <- units |>
  indicator_productive_volume(
    species_field = "species",
    dbh_field = "dbh"
  ) |>
  indicator_productive_station(
    species_field = "species",
    fertility_field = "F1"
  ) |>
  indicator_productive_quality(
    species_field = "species",
    form_field = "form",
    dbh_field = "dbh",
    defects_field = "defects"
  )

# Normalize
units_normalized <- normalize_indicators(
  units_with_P,
  indicators = c("P1", "P2", "P3"),
  methods = c("linear", "linear", "linear")
)

# Create family composite
units_with_family <- create_family_index(
  units_normalized,
  family = "P",
  indicators = c("P1", "P2", "P3"),
  weights = c(0.4, 0.3, 0.3)
)
```

---

## Testing Requirements

### Unit Tests

- ✅ IFN equation lookup (species found)
- ✅ Fallback to genus/generic
- ✅ Height estimation from DBH
- ✅ Productivity components (fertility, climate, species match)
- ✅ Quality scoring (form, diameter, defects)
- ✅ Weight validation

### Integration Tests

- ✅ Full P1-P2-P3 workflow
- ✅ Compatibility with v0.2.0 F1 indicator
- ✅ Normalization and family composite

### Fixtures

- `tests/testthat/fixtures/productive_reference.rds`: Expected P1-P3 values
- `tests/testthat/fixtures/ifn_equations_sample.rds`: Sample allometric equations
- `tests/testthat/fixtures/productivity_tables_sample.rds`: Sample productivity tables

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Contract Complete
**Implemented**: TBD (Phase 4 tasks)
