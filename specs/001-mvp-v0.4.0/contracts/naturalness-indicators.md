# API Contract: Naturalness Indicators (N Family)

**Family**: Naturalness & Wilderness Character
**Feature**: [spec.md](../spec.md) | **Data Model**: [data-model.md](../data-model.md)
**Created**: 2026-01-05

## Overview

This contract defines the API for calculating naturalness/wilderness indicators (N1-N3) that quantify remoteness from human influence and wilderness character. Functions integrate spatial infrastructure data with existing temporal and biodiversity indicators.

---

## N1: Infrastructure Distance Indicator

### Function Signature

```r
indicator_naturalness_distance(
  units,
  infrastructure = NULL,
  method = c("osm", "local"),
  osm_bbox = NULL,
  infra_types = c("roads", "buildings", "power"),
  osm_road_tags = c("motorway", "trunk", "primary", "secondary", "tertiary"),
  distance_method = c("euclidean", "network"),
  column_name = "N1",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units to assess |
| `infrastructure` | `sf` or list | Conditional | `NULL` | Infrastructure dataset(s), required if `method="local"` |
| `method` | character | No | `"osm"` | Data source: "osm" (OpenStreetMap) or "local" |
| `osm_bbox` | numeric/bbox | No | `NULL` | Bounding box for OSM query (auto-detect from units if NULL) |
| `infra_types` | character vector | No | See above | Infrastructure categories to include |
| `osm_road_tags` | character vector | No | See above | OSM highway tags considered as roads (excludes paths/tracks) |
| `distance_method` | character | No | `"euclidean"` | Distance calculation: "euclidean" (straight-line) or "network" (not implemented v0.4.0) |
| `column_name` | character | No | `"N1"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Minimum distance to infrastructure (meters)
- `{column_name}_roads` (numeric): Distance to nearest road
- `{column_name}_buildings` (numeric): Distance to nearest building
- `{column_name}_power` (numeric): Distance to nearest power line

### Behavior

1. **Infrastructure Acquisition**:
   - **If `method = "osm"`**:
     - Query OpenStreetMap for infrastructure layers
     - Roads: `highway` tag in `osm_road_tags`
     - Buildings: `building` tag (any value)
     - Power: `power=line` or `power=tower`
   - **If `method = "local"`**:
     - Use user-provided `infrastructure` (sf object or named list)
     - Expected list names: `"roads"`, `"buildings"`, `"power"`

2. **Distance Calculation**:
   ```r
   # For each unit centroid (or boundary if preferred)
   for each infra_type:
     dist = st_distance(unit_centroid, infra_layer)
     min_dist[infra_type] = min(dist)

   # Overall minimum
   N1 = min(min_dist[infra_types])
   ```

3. **Missing Infrastructure**:
   - If infrastructure type not found: Set component to NA with message
   - If all types missing: N1 = NA with warning

4. **Edge Cases**:
   - Unit intersects infrastructure: N1 = 0
   - Very remote (>20km): Valid, no warning (wilderness areas expected)

### Example

```r
library(nemeton)
library(sf)

# Load demo data
data(massif_demo_units_extended)

# Calculate N1 using OpenStreetMap
result <- indicator_naturalness_distance(
  units = massif_demo_units_extended,
  method = "osm",
  infra_types = c("roads", "buildings", "power")
)

# Check component distances
result[, c("N1", "N1_roads", "N1_buildings", "N1_power")]

summary(result$N1)
#> Min: 0, Median: 487, Max: 8342 meters
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| `method="local"` but infrastructure=NULL | Stop: "infrastructure parameter required for method='local'" |
| OSM query fails (timeout/network) | Warn, set N1 = NA |
| Invalid infra_types | Warn, filter invalid, proceed with valid |
| CRS mismatch | Auto-transform infrastructure to units CRS with message |

### Dependencies

- `sf` (distance calculations)
- `osmdata` (if `method="osm"`)
- `units` (distance conversions)

### Performance

- 20 parcels, OSM: ~40 seconds (multiple OSM queries)
- 20 parcels, local: ~2 seconds
- Recommend caching OSM data for large datasets

---

## N2: Forest Continuity Indicator

### Function Signature

```r
indicator_naturalness_continuity(
  units,
  land_cover = NULL,
  forest_classes = c("forest", "woodland"),
  connectivity_distance = 100,
  method = c("corine", "osm", "local"),
  column_name = "N2",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units to assess |
| `land_cover` | `sf`/`SpatRaster` | Conditional | `NULL` | Land cover layer, required if `method="local"` |
| `forest_classes` | character vector | No | See above | Land cover classes considered as forest |
| `connectivity_distance` | numeric | No | `100` | Maximum gap (meters) to maintain connectivity |
| `method` | character | No | `"corine"` | Land cover source: "corine" (Corine Land Cover), "osm" (OpenStreetMap landuse), "local" |
| `column_name` | character | No | `"N2"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Continuous forest patch area (hectares)
- `{column_name}_patch_id` (integer): Patch identifier (for joining/visualization)

### Behavior

1. **Forest Extraction**:
   - **If `method = "corine"`**: Extract Corine classes 311-313 (forests)
   - **If `method = "osm"`**: Query OSM `landuse=forest` or `natural=wood`
   - **If `method = "local"`**: Filter `land_cover` by `forest_classes`

2. **Patch Connectivity Algorithm**:
   ```r
   # 1. Buffer forest polygons by connectivity_distance
   forest_buffered = st_buffer(forest, connectivity_distance)

   # 2. Dissolve overlapping buffers → patches
   patches = st_union(forest_buffered) |>
             st_cast("POLYGON")

   # 3. Assign each unit to its patch
   unit_patch = st_join(units, patches)

   # 4. Calculate patch area
   N2 = st_area(unit_patch$patch_geometry) / 10000  # Convert to hectares
   ```

3. **Validation**:
   - N2 ≥ unit area (patch must contain at least the unit itself)
   - Warn if N2 < unit area (possible geometry error)

4. **Edge Cases**:
   - Unit not in forest: N2 = 0 with message
   - Multiple patches touching unit: Use largest patch area
   - Isolated unit: N2 = unit area

### Example

```r
# Load land cover (example)
corine <- rast("data/corine_land_cover.tif")

# Calculate N2
result <- indicator_naturalness_continuity(
  units = massif_demo_units_extended,
  land_cover = corine,
  method = "corine",
  connectivity_distance = 100,
  forest_classes = c("311", "312", "313")  # Corine forest codes
)

summary(result$N2)
#> Min: 12.5, Median: 284.7, Max: 5432.1 hectares
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| land_cover missing + method="local" | Stop: "land_cover required for method='local'" |
| No forest classes found | Warn: "No forest detected, N2 = 0" |
| N2 < unit area | Warn: "Patch smaller than unit (geometry issue)" |
| CRS mismatch | Auto-transform land_cover to units CRS |

### Dependencies

- `sf` (buffering, dissolving, spatial joins)
- `terra` (raster land cover, if provided)
- `osmdata` (if `method="osm"`)

### Performance

- 20 parcels, local vector: ~3 seconds
- 20 parcels, raster: ~5 seconds
- 20 parcels, OSM: ~45 seconds

---

## N3: Composite Naturalness Indicator

### Function Signature

```r
indicator_naturalness_composite(
  units,
  n1_field = "N1",
  n2_field = "N2",
  t1_field = "T1",
  b1_field = "B1",
  aggregation = c("multiplicative", "weighted"),
  weights = c(N1 = 0.25, N2 = 0.25, T1 = 0.25, B1 = 0.25),
  normalization = "quantile",
  quantiles = c(0.1, 0.9),
  column_name = "N3",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with N1, N2, T1, B1 indicators |
| `n1_field` | character | No | `"N1"` | Column for infrastructure distance |
| `n2_field` | character | No | `"N2"` | Column for forest continuity |
| `t1_field` | character | No | `"T1"` | Column for ancientness (from v0.3.0) |
| `b1_field` | character | No | `"B1"` | Column for protection status (from v0.3.0) |
| `aggregation` | character | No | `"multiplicative"` | Aggregation method |
| `weights` | named numeric | No | Equal weights | Component weights (for weighted method, must sum to 1.0) |
| `normalization` | character | No | `"quantile"` | Normalization method: "quantile", "minmax", "zscore" |
| `quantiles` | numeric(2) | No | `c(0.1, 0.9)` | Quantile bounds for normalization (10th-90th percentile) |
| `column_name` | character | No | `"N3"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Composite naturalness score 0-100
- `{column_name}_N1_norm` (numeric): Normalized N1 component
- `{column_name}_N2_norm` (numeric): Normalized N2 component
- `{column_name}_T1_norm` (numeric): Normalized T1 component
- `{column_name}_B1_norm` (numeric): Normalized B1 component

### Behavior

1. **Normalization** (each component to 0-1 scale):
   - **Quantile method** (default, robust to outliers):
     ```r
     q_low = quantile(x, quantiles[1])
     q_high = quantile(x, quantiles[2])
     x_norm = (x - q_low) / (q_high - q_low)
     x_norm = pmax(0, pmin(1, x_norm))  # Clip to [0, 1]
     ```
   - **MinMax**: `x_norm = (x - min(x)) / (max(x) - min(x))`
   - **Z-score**: `x_norm = (x - mean(x)) / sd(x)` then clip

2. **Aggregation**:
   - **Multiplicative** (default, all components matter):
     ```r
     N3 = (N1_norm × N2_norm × T1_norm × B1_norm)^0.25 × 100
     ```
     - Geometric mean scaled to 0-100
     - Low value on any component strongly penalizes overall score

   - **Weighted average** (allows compensation):
     ```r
     N3 = (w1×N1_norm + w2×N2_norm + w3×T1_norm + w4×B1_norm) × 100
     ```
     - Linear combination, weights must sum to 1.0

3. **Missing Data Handling**:
   - If any component NA: N3 = NA with warning
   - No imputation (requires complete data for valid wilderness assessment)

4. **Edge Cases**:
   - All components = 0: N3 = 0 (no wilderness character)
   - All components = max: N3 = 100 (pristine wilderness)

### Example

```r
# Assuming N1, N2, T1, B1 already calculated
result <- indicator_naturalness_composite(
  units = massif_demo_units_extended,
  n1_field = "N1",
  n2_field = "N2",
  t1_field = "T1",  # From v0.3.0
  b1_field = "B1",  # From v0.3.0
  aggregation = "multiplicative",
  normalization = "quantile"
)

# Component contributions
result[, c("N3", "N3_N1_norm", "N3_N2_norm", "N3_T1_norm", "N3_B1_norm")]

summary(result$N3)
#> Min: 8.4, Median: 45.7, Max: 92.3
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| Required field missing | Stop: "Field '{field}' not found" |
| T1 or B1 unavailable | Stop: "Requires v0.3.0 indicators (T1, B1)" |
| Weights don't sum to 1.0 (weighted) | Stop: "Weights must sum to 1.0" |
| Any component NA | Warn: "Missing component, N3 = NA" |

### Dependencies

- `sf`
- `stats` (quantile, scaling)

### Performance

- 20 parcels: <1 second
- 1000 parcels: ~1 second

---

## Integration with Family System

```r
# Calculate all N indicators
units_with_N <- units |>
  indicator_naturalness_distance(
    method = "osm",
    infra_types = c("roads", "buildings", "power")
  ) |>
  indicator_naturalness_continuity(
    land_cover = corine_lc,
    method = "local"
  ) |>
  indicator_naturalness_composite(
    n1_field = "N1",
    n2_field = "N2",
    t1_field = "T1",  # Requires v0.3.0
    b1_field = "B1",  # Requires v0.3.0
    aggregation = "multiplicative"
  )

# Normalize
units_normalized <- normalize_indicators(
  units_with_N,
  indicators = c("N1", "N2", "N3"),
  methods = c("linear", "log", "linear")
)

# Create family composite
units_with_family <- create_family_index(
  units_normalized,
  family = "N",
  indicators = c("N1", "N2", "N3"),
  weights = c(0.25, 0.25, 0.5)  # N3 weighted more (comprehensive)
)
```

---

## Testing Requirements

### Unit Tests

- ✅ Distance calculation (unit to infrastructure)
- ✅ OSM infrastructure query
- ✅ Forest patch connectivity algorithm
- ✅ Normalization methods (quantile, minmax, zscore)
- ✅ Aggregation methods (multiplicative, weighted)
- ✅ Edge cases (missing components, isolated units)

### Integration Tests

- ✅ Full N1-N2-N3 workflow
- ✅ Dependency on v0.3.0 indicators (T1, B1)
- ✅ Normalization and family composite

### Fixtures

- `tests/testthat/fixtures/naturalness_reference.rds`: Expected N1-N3 values
- `tests/testthat/fixtures/osm_infrastructure_mock.rds`: Mock OSM infrastructure
- `tests/testthat/fixtures/corine_lc_mock.rds`: Mock land cover raster

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Contract Complete
**Implemented**: TBD (Phase 6 tasks)
