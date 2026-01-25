# API Contract: Social Indicators (S Family)

**Family**: Social & Recreational Services
**Feature**: [spec.md](../spec.md) | **Data Model**: [data-model.md](../data-model.md)
**Created**: 2026-01-05

## Overview

This contract defines the API for calculating social/recreational indicators (S1-S3) that quantify forest accessibility and recreational use potential. All functions follow the nemeton convention: accept `sf` objects, return `sf` objects with new indicator column(s) appended.

---

## S1: Trail Density Indicator

### Function Signature

```r
indicator_social_trails(
  units,
  trails = NULL,
  method = c("osm", "local"),
  osm_bbox = NULL,
  osm_types = c("path", "footway", "cycleway", "bridleway"),
  column_name = "S1",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units (forest parcels) to assess |
| `trails` | `sf` (LINESTRING) | Conditional | `NULL` | Local trail dataset (if `method="local"`) |
| `method` | character | No | `"osm"` | Data source: "osm" (OpenStreetMap) or "local" (user-provided) |
| `osm_bbox` | numeric/bbox | No | `NULL` | Bounding box for OSM query (auto-detected from `units` if NULL) |
| `osm_types` | character vector | No | See above | OSM highway tags to include as trails |
| `column_name` | character | No | `"S1"` | Name for output column |
| `lang` | character | No | `"en"` | Message language ("en" or "fr") |

### Returns

**Type**: `sf` object (same class as `units`)

**Added Columns**:
- `{column_name}` (numeric): Trail density in km/ha

### Behavior

1. **If `method = "osm"`**:
   - Query OpenStreetMap using `osmdata` package
   - Filter highways by `osm_types` tags
   - Download trail network for `osm_bbox` (or auto-detect from `units`)

2. **If `method = "local"`**:
   - Use user-provided `trails` sf object
   - Validate geometry type (must be LINESTRING)

3. **Calculation**:
   - Clip trails to each unit's boundary
   - Sum total trail length (km)
   - Divide by unit area (ha)
   - Return density (km/ha)

4. **Edge Cases**:
   - Unit with no trails: `S1 = 0`
   - OSM query fails: Return NA with warning
   - Invalid geometries: Attempt repair, warn if fail

### Example

```r
library(nemeton)
library(sf)

# Load demo data
data(massif_demo_units_extended)

# Calculate S1 using OpenStreetMap
result <- indicator_social_trails(
  units = massif_demo_units_extended,
  method = "osm",
  osm_types = c("path", "footway", "cycleway")
)

# Check results
summary(result$S1)
#> Min: 0.0, Median: 0.8, Max: 4.2 km/ha
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| `units` not sf object | Stop with error message |
| `trails` is NULL when `method="local"` | Stop: "trails parameter required for method='local'" |
| OSM query timeout | Warn, return NA for all units |
| Invalid `osm_types` | Warn, filter invalid tags, proceed with valid |
| Geometry repair fails | Warn, set S1=NA for affected units |

### Dependencies

- `sf` (spatial operations)
- `osmdata` (OSM queries, if `method="osm"`)
- `units` (length/area conversions)
- `cli` (messages)

### Performance

- 20 parcels, OSM method: ~30 seconds (network query)
- 20 parcels, local method: ~1 second
- Recommend local method for large datasets (cache OSM data first)

---

## S2: Accessibility Score Indicator

### Function Signature

```r
indicator_social_accessibility(
  units,
  roads = NULL,
  transit_stops = NULL,
  cycling = NULL,
  method = c("osm", "local"),
  osm_bbox = NULL,
  weights = c(road = 0.4, transit = 0.3, cycling = 0.3),
  column_name = "S2",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units to assess |
| `roads` | `sf` (LINESTRING) | Conditional | `NULL` | Road network (if `method="local"`) |
| `transit_stops` | `sf` (POINT) | Conditional | `NULL` | Public transport stops (optional) |
| `cycling` | `sf` (LINESTRING) | Conditional | `NULL` | Cycling infrastructure (optional) |
| `method` | character | No | `"osm"` | Data source: "osm" or "local" |
| `osm_bbox` | numeric/bbox | No | `NULL` | Bounding box for OSM query |
| `weights` | named numeric | No | See above | Component weights (must sum to 1.0) |
| `column_name` | character | No | `"S2"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Accessibility score 0-100
- `{column_name}_road` (numeric): Road component score 0-40
- `{column_name}_transit` (numeric): Transit component score 0-30
- `{column_name}_cycling` (numeric): Cycling component score 0-30

### Behavior

1. **Road Component** (0-40 points):
   - Calculate distance to nearest paved road
   - Score: 0-500m=40, 500-2000m=20, 2000-5000m=10, >5000m=0

2. **Transit Component** (0-30 points):
   - Calculate distance to nearest bus/train stop
   - Score: 0-1000m=30, 1000-3000m=15, >3000m=0
   - If `transit_stops = NULL`, set to 0 with message

3. **Cycling Component** (0-30 points):
   - Check for cycleway within 2km
   - Score: Dedicated cycleway <500m=30, shared path <1000m=15, >1000m=0
   - If `cycling = NULL`, set to 0 with message

4. **Composite**:
   - Sum components: `S2 = road + transit + cycling`
   - Apply weights if provided: `S2 = weights[1]*road + weights[2]*transit + weights[3]*cycling`

### Example

```r
# Calculate S2 with default OSM method
result <- indicator_social_accessibility(
  units = massif_demo_units_extended,
  method = "osm"
)

# View component breakdown
result[, c("S2", "S2_road", "S2_transit", "S2_cycling")]
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| Weights don't sum to 1.0 | Stop with error |
| No data sources available | Stop with error (at least roads required) |
| OSM query fails | Warn, set components to NA |

### Dependencies

- `sf` (distance calculations)
- `osmdata` (if `method="osm"`)
- `units` (distance conversions)

### Performance

- 20 parcels, OSM: ~45 seconds (multiple queries)
- 20 parcels, local: ~2 seconds

---

## S3: Population Proximity Indicator

### Function Signature

```r
indicator_social_proximity(
  units,
  population = NULL,
  method = c("insee", "raster", "grid"),
  radii = c(5000, 10000, 20000),
  column_prefix = "S3",
  aggregate_method = c("sum", "mean", "weighted"),
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units to assess |
| `population` | `sf`/`SpatRaster` | Yes | - | Population grid (INSEE Carroyage or custom raster) |
| `method` | character | No | `"insee"` | Population data type: "insee" (sf grid), "raster" (SpatRaster), "grid" (generic sf) |
| `radii` | numeric vector | No | `c(5000, 10000, 20000)` | Buffer radii in meters |
| `column_prefix` | character | No | `"S3"` | Prefix for output columns |
| `aggregate_method` | character | No | `"sum"` | How to aggregate (sum, mean, weighted by area) |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_prefix}_5km` (numeric): Population within 5km
- `{column_prefix}_10km` (numeric): Population within 10km
- `{column_prefix}_20km` (numeric): Population within 20km
- `{column_prefix}` (numeric): Composite score (optional, normalized)

### Behavior

1. **Buffer Creation**:
   - Create buffers at each radius around unit centroids
   - Transform to appropriate CRS if needed

2. **Population Extraction**:
   - **If `method = "insee"/"grid"`**: Spatial join with population polygons, sum population field
   - **If `method = "raster"`**: Extract raster values within buffer, sum

3. **Aggregation**:
   - `sum`: Total population count
   - `mean`: Average population density
   - `weighted`: Area-weighted average

4. **Validation**:
   - Check monotonicity: S3_20km ≥ S3_10km ≥ S3_5km
   - Warn if violated (possible data issue)

### Example

```r
# Load INSEE Carroyage data (example)
insee_pop <- st_read("data/insee_carroyage_1km.gpkg")

# Calculate S3
result <- indicator_social_proximity(
  units = massif_demo_units_extended,
  population = insee_pop,
  method = "insee",
  radii = c(5000, 10000, 20000)
)

# Check monotonicity
all(result$S3_20km >= result$S3_10km)  # Should be TRUE
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| `population` is NULL | Stop with error |
| CRS mismatch | Auto-transform population to units CRS with message |
| Invalid radii (non-positive) | Stop with error |
| Monotonicity violated | Warn, proceed (may indicate data issue) |

### Dependencies

- `sf` (buffers, spatial joins)
- `terra` (raster extraction, if `method="raster"`)
- `units` (distance conversions)

### Performance

- 20 parcels, 3 radii, grid: ~5 seconds
- 20 parcels, 3 radii, raster: ~3 seconds

---

## Integration with Family System

All S indicators integrate with existing family infrastructure:

```r
# Calculate all S indicators
units_with_S <- units |>
  indicator_social_trails(method = "osm") |>
  indicator_social_accessibility(method = "osm") |>
  indicator_social_proximity(population = insee_grid)

# Normalize
units_normalized <- normalize_indicators(
  units_with_S,
  indicators = c("S1", "S2", "S3_5km"),
  methods = c("linear", "linear", "log")
)

# Create family composite
units_with_family <- create_family_index(
  units_normalized,
  family = "S",
  indicators = c("S1", "S2", "S3_5km"),
  weights = c(0.4, 0.3, 0.3)
)
```

---

## Testing Requirements

### Unit Tests

- ✅ OSM query with valid bbox
- ✅ Local data with valid sf object
- ✅ Edge case: no trails (S1=0)
- ✅ Edge case: invalid geometries
- ✅ Component score calculations (S2)
- ✅ Buffer creation and population sum (S3)
- ✅ Monotonicity validation (S3)

### Integration Tests

- ✅ Full S1-S2-S3 workflow
- ✅ Normalization compatibility
- ✅ Family composite creation
- ✅ Bilingual messages (FR/EN)

### Fixtures

- `tests/testthat/fixtures/social_reference.rds`: Expected S1-S3 values for 5 test parcels
- `tests/testthat/fixtures/osm_trails_mock.rds`: Mock OSM trail network
- `tests/testthat/fixtures/insee_pop_mock.rds`: Mock INSEE population grid

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Contract Complete
**Implemented**: TBD (Phase 3 tasks)
