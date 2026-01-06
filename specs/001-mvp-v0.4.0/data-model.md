# Data Model: MVP v0.4.0 - 12-Family Ecosystem Services Referential

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)
**Created**: 2026-01-05
**Status**: Design Phase

## Overview

This data model defines the entities, attributes, relationships, and validation rules for the 4 new indicator families (Social, Productive, Energy, Naturalness) completing the 12-family nemeton ecosystem services framework. All entities follow the existing v0.3.0 conventions: spatial units as `sf` objects, indicators as numeric columns, family composites as aggregated 0-100 scores.

**Core Principle**: Indicators are computed attributes added to spatial unit objects (sf data frames). Each indicator function accepts an `sf` object and returns the same object with new indicator column(s) appended. This maintains consistency with v0.2.0-v0.3.0 architecture.

---

## Entity Catalog

### 1. Social Family Indicators (S)

**Purpose**: Quantify recreational use potential and public access to forest areas.

#### S1: Trail Density Indicator

**Entity Name**: `trail_density` (column: `S1` or `indicator_S1`)

**Attributes**:
- **Type**: Numeric
- **Unit**: km/ha (kilometers of trails per hectare)
- **Range**: [0, ∞) - theoretically unbounded, typical values 0-5 km/ha
- **Computation**: Total length of trail network within/intersecting parcel divided by parcel area

**Data Sources**:
- OpenStreetMap: `highway` tags (path, footway, cycleway, bridleway)
- Local trail datasets (GeoPackage, shapefile with linear geometries)

**Validation Rules**:
- Must be non-negative
- NA allowed if trail data unavailable for area
- Warning if value >10 km/ha (unusually dense, possible data error)

**Relationships**:
- Input: Spatial unit (polygon), trail network (lines)
- Output: Numeric value appended to spatial unit

---

#### S2: Accessibility Score Indicator

**Entity Name**: `accessibility_score` (column: `S2` or `indicator_S2`)

**Attributes**:
- **Type**: Numeric
- **Unit**: Score (0-100)
- **Range**: [0, 100] - higher = more accessible
- **Computation**: Composite of road proximity, public transport access, cycling infrastructure

**Components**:
1. **Road access** (0-40 points): Distance to paved road
   - 0-500m: 40 pts
   - 500-2000m: 20 pts
   - 2000-5000m: 10 pts
   - >5000m: 0 pts
2. **Public transport** (0-30 points): Distance to bus/train stop (optional)
   - 0-1km: 30 pts
   - 1-3km: 15 pts
   - >3km: 0 pts
3. **Cycling infrastructure** (0-30 points): Presence of bike paths within 2km
   - Dedicated cycleway within 500m: 30 pts
   - Shared path within 1km: 15 pts
   - >1km: 0 pts

**Data Sources**:
- OpenStreetMap: roads, public transport stops, cycling infrastructure
- Optional: GTFS feeds for public transport

**Validation Rules**:
- Must be in [0, 100]
- Components must sum to ≤100
- NA allowed if data sources unavailable

**Relationships**:
- Input: Spatial unit (polygon), infrastructure networks
- Output: Composite score appended to spatial unit

---

#### S3: Population Proximity Indicator

**Entity Name**: `population_proximity` (column: `S3_5km`, `S3_10km`, `S3_20km` or single `S3` composite)

**Attributes**:
- **Type**: Numeric (or list with 3 values)
- **Unit**: Population count (inhabitants)
- **Range**: [0, ∞) - typically 0 to several million for 20km buffer
- **Computation**: Sum of population within concentric buffers (5km, 10km, 20km)

**Data Sources**:
- INSEE Carroyage 1km (preferred)
- INSEE Carroyage 200m (higher resolution)
- Custom population rasters

**Validation Rules**:
- Must be non-negative integers
- S3_10km ≥ S3_5km ≥ 0 (monotonic)
- S3_20km ≥ S3_10km ≥ S3_5km
- NA allowed if population data unavailable

**Relationships**:
- Input: Spatial unit (polygon), population grid (raster or polygons)
- Output: Population counts appended to spatial unit (3 columns or 1 composite)

---

### 2. Productive Family Indicators (P)

**Purpose**: Quantify timber production potential and economic valorization.

#### P1: Standing Volume Indicator

**Entity Name**: `standing_volume` (column: `P1` or `indicator_P1`)

**Attributes**:
- **Type**: Numeric
- **Unit**: m³/ha (cubic meters per hectare)
- **Range**: [0, ∞) - typical managed forests 50-500 m³/ha
- **Computation**: Apply IFN allometric equations based on species, DBH, height

**Required Input Fields** (in spatial unit object):
- `species`: Character or factor (scientific/common name)
- `dbh`: Numeric, diameter at breast height (cm)
- `height`: Numeric, total height (m) - optional, can be estimated from DBH
- `density`: Numeric, stems per hectare - optional, default from species tables

**Allometric Equation Pattern**:
```
volume_tree = f(DBH, height, species_params)
volume_ha = volume_tree × density
```

**Data Sources**:
- IFN allometric equations database (by species)
- Genus-level fallbacks for rare species
- BD Forêt v2 (optional direct volume estimates)

**Validation Rules**:
- Must be non-negative
- Warning if >1000 m³/ha (exceptionally high, possible error)
- NA propagated if required fields missing
- Species must exist in equation database or fallback to genus

**Relationships**:
- Input: Spatial unit with biometric attributes
- Dependencies: IFN equation lookup table (internal package data)
- Output: Volume estimate appended to spatial unit

---

#### P2: Site Productivity Indicator

**Entity Name**: `site_productivity` (column: `P2` or `indicator_P2`)

**Attributes**:
- **Type**: Numeric
- **Unit**: Score (0-100)
- **Range**: [0, 100] - higher = more productive
- **Computation**: Fertility × Climate suitability × Species-site match

**Components**:
1. **Soil fertility** (reuse `F1` from v0.2.0): BD Sol fertility index
2. **Climate suitability**: Temperature + precipitation optimality for species
3. **Species-site matching**: Species ecological requirements vs actual conditions

**Required Input Fields**:
- `fertility_F1`: Numeric, existing F1 soil fertility indicator
- `species`: Character, tree species
- `temp_annual`: Numeric, annual temperature (°C) - optional, extracted from climate data
- `precip_annual`: Numeric, annual precipitation (mm) - optional

**Data Sources**:
- ONF/IFN productivity tables by species and station type
- Climate data: WorldClim, ERA5, or local weather stations
- Soil data: existing F1 indicator from v0.2.0

**Validation Rules**:
- Must be in [0, 100]
- Components normalized before multiplication
- NA if F1 missing or species unknown
- Default climate to regional average if not provided

**Relationships**:
- Input: Spatial unit with F1, species, optional climate
- Dependencies: Productivity lookup tables (by species), climate rasters (optional)
- Output: Productivity score appended to spatial unit

---

#### P3: Wood Quality Indicator

**Entity Name**: `wood_quality` (column: `P3` or `indicator_P3`)

**Attributes**:
- **Type**: Numeric
- **Unit**: Score (0-100)
- **Range**: [0, 100] - higher = better timber quality
- **Computation**: Weighted average of form, diameter, defect criteria

**Components**:
1. **Stem form** (0-40 points): Straightness, taper
   - Straight: 40 pts
   - Slight curve: 25 pts
   - Crooked: 0 pts
2. **Commercial diameter** (0-30 points): DBH vs species thresholds
   - DBH ≥ sawlog threshold: 30 pts
   - DBH ≥ pulpwood threshold: 15 pts
   - Below thresholds: 0 pts
3. **Defect frequency** (0-30 points): Knots, rot, scars
   - No visible defects: 30 pts
   - Minor defects: 15 pts
   - Major defects: 0 pts

**Required Input Fields**:
- `form`: Character or numeric (straight/curve/crooked or 0-2 scale)
- `dbh`: Numeric, diameter at breast height (cm)
- `defects`: Character or numeric (none/minor/major or 0-2 scale)
- `species`: Character (for threshold lookup)

**Data Sources**:
- Field inventory data
- Silvicultural quality assessment protocols (ONF, CNPF)
- Species-specific thresholds for sawlog/pulpwood

**Validation Rules**:
- Must be in [0, 100]
- Components sum to 100
- NA if required fields missing
- Species thresholds default to generic if not in lookup table

**Relationships**:
- Input: Spatial unit with quality attributes
- Dependencies: Species threshold lookup table (sawlog/pulpwood diameters)
- Output: Quality score appended to spatial unit

---

### 3. Energy Family Indicators (E)

**Purpose**: Quantify bioenergy potential and climate mitigation through wood energy.

#### E1: Fuelwood Potential Indicator

**Entity Name**: `fuelwood_potential` (column: `E1` or `indicator_E1`)

**Attributes**:
- **Type**: Numeric
- **Unit**: tonnes dry matter per year (t DM/year)
- **Range**: [0, ∞) - typical 0.5-5 t/ha/year
- **Computation**: Harvest residues + coppice biomass

**Components**:
1. **Harvest residues**: Logging slash from timber operations
   - Volume_harvested × residue_fraction × wood_density × dry_matter_content
2. **Coppice biomass**: Short-rotation woody crops
   - Coppice_area × annual_yield

**Required Input Fields**:
- `volume_P1`: Numeric, standing volume from P1 (optional, for residue calculation)
- `harvest_rate`: Numeric, fraction of volume harvested annually (default 0.02 = 2%)
- `coppice_area`: Numeric, hectares in coppice management (default 0)
- `species`: Character (for wood density lookup)

**Data Sources**:
- IFN tarifs de cubage for residue fractions
- Coppice yield tables (willow, poplar, chestnut)
- Wood density tables by species

**Validation Rules**:
- Must be non-negative
- Warning if >10 t/ha/year (very high productivity)
- NA if volume_P1 missing and coppice_area = 0
- Default harvest_rate if not provided

**Relationships**:
- Input: Spatial unit with P1 volume (optional), coppice data
- Dependencies: Residue fraction tables, yield tables, density tables
- Output: Fuelwood potential appended to spatial unit

---

#### E2: Carbon Avoidance Indicator

**Entity Name**: `carbon_avoidance` (column: `E2` or `indicator_E2`)

**Attributes**:
- **Type**: Numeric
- **Unit**: tCO2eq/year (tonnes CO2 equivalent per year)
- **Range**: [0, ∞) - typically 0.5-10 tCO2eq/ha/year
- **Computation**: Fuelwood × (fossil_emission_factor - wood_emission_factor) + material_substitution

**Components**:
1. **Energy substitution**: Wood replaces fossil fuels (heating oil, natural gas)
   - fuelwood_potential × energy_content × (fossil_EF - wood_EF)
2. **Material substitution**: Wood replaces cement/steel (construction)
   - timber_volume × (concrete_EF - wood_production_EF)

**Required Input Fields**:
- `fuelwood_E1`: Numeric, fuelwood potential from E1
- `timber_volume_P1`: Numeric, standing volume from P1 (optional for material substitution)
- `substitution_scenario`: Character, "energy_only" or "energy+material" (default "energy_only")

**Data Sources**:
- ADEME Base Carbone emission factors:
  - Heating oil: 324 kgCO2eq/MWh
  - Natural gas: 227 kgCO2eq/MWh
  - Wood combustion: 30 kgCO2eq/MWh (transport + processing only)
  - Concrete: 900 kgCO2eq/m³
  - Steel: 2500 kgCO2eq/tonne
  - Wood construction: 150 kgCO2eq/m³

**Validation Rules**:
- Must be non-negative
- NA if fuelwood_E1 missing
- Material substitution set to 0 if timber_volume_P1 missing or scenario = "energy_only"

**Relationships**:
- Input: Spatial unit with E1, optional P1
- Dependencies: ADEME emission factor table (internal package data)
- Output: Carbon avoidance estimate appended to spatial unit

---

### 4. Naturalness Family Indicators (N)

**Purpose**: Quantify wilderness character and remoteness from human influence.

#### N1: Infrastructure Distance Indicator

**Entity Name**: `infrastructure_distance` (column: `N1` or `indicator_N1`)

**Attributes**:
- **Type**: Numeric
- **Unit**: meters
- **Range**: [0, ∞) - typically 0-10,000m
- **Computation**: Minimum Euclidean distance to nearest road, building, or power line

**Infrastructure Types** (configurable):
- Roads: Primary, secondary, tertiary (OSM highway tags)
- Buildings: All building polygons (OSM building tag)
- Power lines: High-voltage transmission (OSM power=line)
- Optional: Railways, quarries, urban areas

**Data Sources**:
- OpenStreetMap: roads, buildings, power infrastructure
- Local cadastral/infrastructure databases

**Validation Rules**:
- Must be non-negative
- NA if infrastructure data unavailable
- Warning if >20,000m (very remote, verify data completeness)

**Relationships**:
- Input: Spatial unit (polygon), infrastructure layers (lines/polygons)
- Output: Minimum distance appended to spatial unit

---

#### N2: Forest Continuity Indicator

**Entity Name**: `forest_continuity` (column: `N2` or `indicator_N2`)

**Attributes**:
- **Type**: Numeric
- **Unit**: hectares
- **Range**: [0, ∞) - patch area containing the parcel
- **Computation**: Area of continuous forest patch (no gaps >100m) containing the parcel

**Algorithm**:
1. Buffer forest parcels by connectivity distance (default 100m)
2. Dissolve overlapping buffers to form patches
3. Assign each parcel to its patch
4. Return patch area for each parcel

**Data Sources**:
- Forest land cover (Corine Land Cover, BD Forêt, OSM landuse=forest)
- Parcel-level forest inventory

**Validation Rules**:
- Must be non-negative
- N2 ≥ parcel area (patch contains at least the parcel itself)
- NA if land cover data unavailable

**Relationships**:
- Input: Spatial unit (polygon), forest land cover layer
- Dependencies: Buffering distance parameter (default 100m)
- Output: Patch area appended to spatial unit

---

#### N3: Composite Naturalness Indicator

**Entity Name**: `composite_naturalness` (column: `N3` or `indicator_N3`)

**Attributes**:
- **Type**: Numeric
- **Unit**: Score (0-100)
- **Range**: [0, 100] - higher = more natural/wild
- **Computation**: Weighted combination of N1, N2, T1 (ancientness), B1 (protection)

**Components** (normalized to 0-1 before aggregation):
1. **N1_normalized**: Distance to infrastructure (normalize by quantiles)
2. **N2_normalized**: Forest continuity (normalize by quantiles)
3. **T1_normalized**: Ancientness from existing T1 indicator (v0.3.0)
4. **B1_normalized**: Protection status from existing B1 indicator (v0.3.0)

**Aggregation Method** (configurable):
- **Multiplicative** (default): N3 = (N1_norm × N2_norm × T1_norm × B1_norm)^0.25 × 100
  - Penalizes low values on any dimension (all components matter)
- **Weighted average**: N3 = (0.3×N1 + 0.3×N2 + 0.2×T1 + 0.2×B1)
  - Allows partial compensation

**Required Input Fields**:
- `N1`: Numeric, infrastructure distance
- `N2`: Numeric, forest continuity
- `T1`: Numeric, ancientness indicator (from v0.3.0)
- `B1`: Numeric, protection status indicator (from v0.3.0)

**Validation Rules**:
- Must be in [0, 100]
- NA if any required component missing (no imputation)
- Warn if T1 or B1 unavailable (requires v0.3.0 calculations)

**Relationships**:
- Input: Spatial unit with N1, N2, T1, B1
- Dependencies: Normalization parameters (quantiles for N1/N2)
- Output: Composite naturalness score appended to spatial unit

---

### 5. Family Composite Indices

**Purpose**: Aggregate individual indicators into family-level 0-100 scores for cross-family comparison.

#### Family Composite Entity

**Entity Names**: `family_S`, `family_P`, `family_E`, `family_N`

**Attributes**:
- **Type**: Numeric
- **Unit**: Score (0-100)
- **Range**: [0, 100]
- **Computation**: Weighted average of normalized family indicators

**Aggregation Pattern** (per existing v0.3.0 `create_family_index()`):
```
family_X = w1 × X1_norm + w2 × X2_norm + ... + wn × Xn_norm
where Σwi = 1.0
```

**Default Weights**:
- **family_S**: S1 (0.4), S2 (0.3), S3 (0.3)
- **family_P**: P1 (0.4), P2 (0.3), P3 (0.3)
- **family_E**: E1 (0.5), E2 (0.5)
- **family_N**: N1 (0.25), N2 (0.25), N3 (0.5)

**Validation Rules**:
- Weights must sum to 1.0
- NA if all component indicators NA
- Partial aggregation if some indicators NA (renormalize weights)

**Relationships**:
- Input: Spatial unit with normalized family indicators
- Dependencies: `create_family_index()` function from family-system.R
- Output: Family composite score appended to spatial unit

---

### 6. Extended Demo Dataset

**Purpose**: Provide complete 12-family reference data for testing and documentation.

#### massif_demo_units_extended

**Entity Type**: `sf` object (spatial data frame)

**Attributes**:
- **Geometry**: POLYGON (forest parcels)
- **CRS**: EPSG:2154 (Lambert-93, France)
- **Rows**: 20 parcels
- **Columns**: ~50 (geometry + 20 indicators + 12 families + metadata)

**Indicator Columns** (all numeric):
- **C family**: C1 (biomass), C2 (NDVI_trend)
- **B family**: B1 (protection), B2 (diversity), B3 (connectivity)
- **W family**: W1 (hydro_network), W2 (wetlands), W3 (TWI)
- **A family**: A1 (canopy_cover), A2 (air_quality)
- **F family**: F1 (fertility), F2 (slope_erosion)
- **L family**: L1 (fragmentation), L2 (edge_ratio)
- **T family**: T1 (ancientness), T2 (land_change)
- **R family**: R1 (fire_risk), R2 (storm_risk), R3 (water_stress)
- **S family**: S1 (trail_density), S2 (accessibility), S3 (population_5km/10km/20km)
- **P family**: P1 (standing_volume), P2 (productivity), P3 (wood_quality)
- **E family**: E1 (fuelwood_potential), E2 (carbon_avoidance)
- **N family**: N1 (infra_distance), N2 (forest_continuity), N3 (composite_naturalness)

**Family Composite Columns** (all numeric 0-100):
- family_C, family_B, family_W, family_A, family_F, family_L, family_T, family_R, family_S, family_P, family_E, family_N

**Metadata Columns**:
- `parcel_id`: Character, unique identifier
- `name`: Character, descriptive name
- `area_ha`: Numeric, parcel area (hectares)
- `dominant_species`: Character, main tree species
- `management_type`: Character, production/conservation/mixed

**Data Generation Method**:
- Synthetic data for indicators lacking real sources
- Realistic parameter ranges based on French forest statistics
- Documented in `data-raw/generate_extended_demo.R`

**Validation Rules**:
- All 20 parcels have valid geometries
- All indicator columns have numeric values (NA allowed)
- All family composites in [0, 100] or NA
- Documented limitations prevent real-world use (demo only)

**Relationships**:
- Used by: Vignettes, examples, tests
- Generated by: `data-raw/generate_extended_demo.R`
- Loaded via: `data(massif_demo_units_extended)`

---

### 7. Analysis Outputs

**Purpose**: Results from advanced multi-criteria analysis tools.

#### Pareto Optimality Flags

**Entity**: Logical column `is_pareto_optimal` appended to spatial units

**Attributes**:
- **Type**: Logical (TRUE/FALSE)
- **Meaning**: TRUE = parcel is non-dominated on selected objectives
- **Computation**: No other parcel scores strictly higher on all objectives simultaneously

**Relationships**:
- Input: Spatial unit with family composites
- Generated by: `identify_pareto_optimal(units, families, objectives)`
- Used for: Highlighting exceptional parcels, trade-off visualization

---

#### Cluster Assignments

**Entity**: Integer column `cluster_id` appended to spatial units

**Attributes**:
- **Type**: Integer
- **Range**: [1, k] where k = number of clusters
- **Meaning**: Cluster membership based on multi-family profile similarity
- **Computation**: K-means or hierarchical clustering on family composite scores

**Relationships**:
- Input: Spatial unit with family composites
- Generated by: `cluster_parcels(units, families, k, method)`
- Used for: Grouping similar parcels, management zone delineation

---

#### Cluster Profiles

**Entity**: Data frame with mean family scores per cluster

**Attributes**:
- **Columns**: cluster_id, family_C, family_B, ..., family_N, n_parcels
- **Rows**: k rows (one per cluster)
- **Type**: Numeric for family means, integer for cluster_id and n_parcels

**Relationships**:
- Derived from: Spatial units with cluster_id assignments
- Generated by: `cluster_parcels()` (as attribute of result)
- Used for: Radar plots comparing cluster profiles, interpretation

---

## Relationships Overview

### Data Flow Diagram

```
External Data Sources
  │
  ├─ OpenStreetMap ──→ S1, S2, N1 indicators
  ├─ INSEE ──→ S3 indicator
  ├─ IFN equations ──→ P1, E1 indicators
  ├─ Climate/Soil ──→ P2 indicator
  └─ ADEME factors ──→ E2 indicator
  │
  ↓
Spatial Units (sf object)
  │
  ├─ indicator_*() functions ──→ Add indicator columns
  │
  ├─ normalize_indicators() ──→ Normalize to 0-100
  │
  ├─ create_family_index() ──→ Add family_* columns
  │
  ↓
Complete Dataset (12 families)
  │
  ├─ nemeton_radar() ──→ 12-axis visualization
  ├─ compute_family_correlations() ──→ 12×12 matrix
  ├─ identify_pareto_optimal() ──→ Pareto flags
  ├─ cluster_parcels() ──→ Cluster assignments + profiles
  └─ plot_tradeoff() ──→ Trade-off scatterplots
```

### Key Dependencies

1. **S3 → Population data**: Requires INSEE or custom rasters
2. **P1 → Species**: Requires species field for allometric equations
3. **P2 → F1**: Reuses existing soil fertility indicator
4. **E1 → P1**: Optionally uses standing volume for residue calculation
5. **E2 → E1**: Requires fuelwood potential for emission calculations
6. **N3 → N1, N2, T1, B1**: Composite requires 4 component indicators
7. **Family composites → Normalized indicators**: Require normalization first
8. **Pareto/clustering → Family composites**: Require complete 12-family dataset

---

## Validation Summary

### Entity Validation Rules

All entities follow these general rules:

1. **Type Safety**: Numeric for scores/measurements, character for categorical
2. **Range Validation**: Scores in [0, 100], physical measurements ≥0
3. **NA Handling**: Propagate NAs with warnings, no silent failures
4. **Monotonicity**: Related indicators (e.g., S3_5km ≤ S3_10km) maintain order
5. **Backward Compatibility**: New columns append, never modify existing

### Data Quality Checks

Implemented in indicator functions:

- ✅ Check input geometry validity (`sf::st_is_valid()`)
- ✅ Warn on missing required fields
- ✅ Validate external data source availability
- ✅ Flag outliers beyond expected ranges
- ✅ Document assumptions when data incomplete

### Testing Strategy

Each entity validated through:

1. **Unit tests**: Individual indicator calculations with fixtures
2. **Integration tests**: Full workflow from raw data to family composites
3. **Regression tests**: Compare v0.4.0 results to expected reference values
4. **Edge case tests**: Missing data, extreme values, boundary conditions

---

## Evolution and Versioning

### v0.4.0 Additions

**New Entities**:
- 11 new indicators (S1-S3, P1-P3, E1-E2, N1-N3)
- 4 new family composites (family_S, family_P, family_E, family_N)
- 3 new analysis outputs (Pareto flags, cluster assignments, cluster profiles)
- 1 extended demo dataset (massif_demo_units_extended)

**Modified Entities**:
- None - all changes are additive to maintain backward compatibility

**Deprecated Entities**:
- `massif_demo_units` (superseded by `massif_demo_units_extended`) - retained for v0.3.0 compatibility

### Future Considerations (v0.5.0+)

Potential entity extensions (out of scope for v0.4.0):

- Uncertainty estimates for indicators (confidence intervals)
- Temporal trajectories (indicator time series)
- Scenario projections (climate change impacts)
- Real-time data linkages (API integrations)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Design Complete
**Next Phase**: Contract specifications (contracts/)
