# Data Model: v0.3.0 Indicator Families

**Feature**: MVP v0.3.0 - Multi-Family Indicator Extension
**Date**: 2026-01-05
**Status**: Design Phase

## Overview

This document defines the data structures, schemas, and relationships for the 4 new indicator families (B, R, T, A) in nemeton v0.3.0. All indicators follow the established v0.2.0 architecture while extending the family system from 5 to 9 families.

## Family Definitions

### Complete 12-Family System (v0.3.0 implements 9/12)

| Code | Family Name (EN) | Family Name (FR) | Status | Indicators |
|------|------------------|------------------|--------|------------|
| **C** | Carbon & Vitality | Carbone / Énergétique | ✅ v0.2.0 | C1 (biomass), C2 (NDVI) |
| **B** | Biodiversity | Biodiversité / Vivant | ⭐ v0.3.0 | B1 (protection), B2 (structure), B3 (connectivity) |
| **W** | Water Regulation | Water (eau) / Infiltrée | ✅ v0.2.0 | W1 (network), W2 (wetlands), W3 (TWI) |
| **A** | Air Quality & Microclimate | Air (microclimat) / Vaporeuse | ⭐ v0.3.0 | A1 (coverage), A2 (air quality) |
| **F** | Soil Fertility | Fertilité / Riche | ✅ v0.2.0 | F1 (fertility), F2 (erosion) |
| **L** | Landscape & Aesthetics | Landscape (paysage) / Esthétique | ✅ v0.2.0 | L1 (fragmentation), L2 (edge) |
| **T** | Temporal Dynamics & Trame | Trame / Nervurée | ⭐ v0.3.0 | T1 (age), T2 (land use change) |
| **R** | Risk Management & Resilience | Résilience / Flexible | ⭐ v0.3.0 | R1 (fire), R2 (storm), R3 (drought) |
| **S** | Social & Recreational | Santé / Ouverte | ⏳ v0.4.0 | S1, S2, S3 |
| **P** | Productive & Economic | Patrimoine / Radicale | ⏳ v0.4.0 | P1, P2, P3 |
| **E** | Education & Climate | Éducation / Éducative | ⏳ v0.4.0 | E1, E2 |
| **N** | Naturalness & Night | Nuit / Ténébreuse | ⏳ v0.4.0 | N1, N2, N3 |

**Legend**: ✅ Implemented | ⭐ v0.3.0 (this version) | ⏳ Future

---

## Indicator Schemas

### B-Family: Biodiversity

#### B1 - Protection Status

**Full Name**: Protected Area Coverage
**Unit**: Percentage (%)
**Range**: 0-100
**Direction**: Higher is better (more protection)

**Schema**:
```
Indicator: B1
Name: Protection Status
Family: B (Biodiversity)
Value: Numeric [0-100]
Unit: % of area in designated protected zones
Calculation: (area_protected / area_total) × 100
Dependencies: Protected area datasets (ZNIEFF, Natura2000, Parks)
Normalization: Linear 0-100 (raw value is already percentage)
Thresholds:
  - Excellent: 75-100% (highly protected)
  - Good: 50-75% (partially protected)
  - Fair: 25-50% (low protection)
  - Poor: 0-25% (minimal or no protection)
```

**Input Data**:
- `units`: sf object with forest parcel geometries
- `protected_areas`: sf object with protected zone polygons (ZNIEFF types 1&2, Natura2000 SCI/SPA, National/Regional Parks)

**Output**:
- Column `B1` added to `units` with protection percentage

---

#### B2 - Structural Diversity

**Full Name**: Forest Structural Diversity
**Unit**: Index (0-100)
**Range**: 0-100
**Direction**: Higher is better (more diverse)

**Schema**:
```
Indicator: B2
Name: Structural Diversity
Family: B (Biodiversity)
Value: Numeric [0-100]
Unit: Composite diversity index
Calculation: Weighted Shannon H for strata + age classes
Dependencies: BD Forêt (height classes, age distribution)
Normalization: Shannon H scaled to 0-100 using H_max
Thresholds:
  - Excellent: 75-100 (multi-layered, multi-age)
  - Good: 50-75 (moderate diversity)
  - Fair: 25-50 (low diversity)
  - Poor: 0-25 (monoculture/even-aged)
```

**Formula**:
```
B2 = w1 × H_strata_normalized + w2 × H_age_normalized

Where:
  H_strata = Shannon diversity of canopy layers
  H_age = Shannon diversity of age classes
  w1 = 0.6 (strata weight)
  w2 = 0.4 (age weight)
  Normalized: (H / H_max) × 100
```

**Input Data**:
- `units`: sf object with forest attributes
- `height_data` or `strata_classes`: Canopy stratification
- `age_data` or `age_classes`: Age class distribution

**Output**:
- Column `B2` added to `units` with diversity index

---

#### B3 - Ecological Connectivity

**Full Name**: Proximity to Ecological Corridors
**Unit**: Meters (m)
**Range**: 0-∞ (smaller is better)
**Direction**: Lower is better (closer to corridors)

**Schema**:
```
Indicator: B3
Name: Ecological Connectivity
Family: B (Biodiversity)
Value: Numeric [0-∞]
Unit: Distance (meters) to nearest corridor
Calculation: Minimum distance to ecological network
Dependencies: Ecological corridor datasets (Trame Verte et Bleue)
Normalization: Inverse distance, capped at 5000m
Thresholds:
  - Excellent: 0-500m (directly connected)
  - Good: 500-1500m (close proximity)
  - Fair: 1500-3000m (moderate distance)
  - Poor: 3000m+ (isolated)
```

**Normalization Formula**:
```
B3_normalized = 100 × (1 - min(distance, 5000) / 5000)
```

**Input Data**:
- `units`: sf object with forest parcel geometries
- `corridors`: sf object with ecological corridor geometries (lines or polygons)

**Output**:
- Column `B3` added to `units` with distance (m)
- Column `B3_norm` with normalized 0-100 score

---

### R-Family: Risk & Resilience

#### R1 - Fire Risk

**Full Name**: Forest Fire Risk Index
**Unit**: Index (0-100)
**Range**: 0-100
**Direction**: Lower is better (less fire risk)

**Schema**:
```
Indicator: R1
Name: Fire Risk
Family: R (Risk & Resilience)
Value: Numeric [0-100]
Unit: Composite fire risk index
Calculation: Weighted slope + species flammability + climate dryness
Dependencies: DEM (slope), BD Forêt (species), WorldClim (climate)
Normalization: Composite already 0-100
Thresholds:
  - Low: 0-25 (minimal risk)
  - Moderate: 25-50 (manageable risk)
  - High: 50-75 (elevated risk)
  - Severe: 75-100 (critical risk)
```

**Formula**:
```
R1 = w1 × slope_factor + w2 × species_flammability + w3 × climate_dryness

Default weights: w1 = w2 = w3 = 1/3
```

**Input Data**:
- `units`: sf object with forest attributes
- `dem`: SpatRaster with elevation (for slope)
- `species`: Species attribute in units (or BD Forêt)
- `climate`: Climate raster (precipitation)

**Output**:
- Column `R1` added to `units` with fire risk index

---

#### R2 - Storm Vulnerability

**Full Name**: Storm Damage Vulnerability
**Unit**: Index (0-100)
**Range**: 0-100
**Direction**: Lower is better (less vulnerable)

**Schema**:
```
Indicator: R2
Name: Storm Vulnerability
Family: R (Risk & Resilience)
Value: Numeric [0-100]
Unit: Composite storm vulnerability index
Calculation: Weighted height + density + topographic exposure
Dependencies: BD Forêt (height, density), DEM (topography)
Normalization: Composite already 0-100
Thresholds:
  - Low: 0-25 (resilient)
  - Moderate: 25-50 (manageable)
  - High: 50-75 (vulnerable)
  - Severe: 75-100 (highly vulnerable)
```

**Formula**:
```
R2 = w1 × stand_height + w2 × stand_density + w3 × topographic_exposure

Default weights: w1 = w2 = w3 = 1/3
```

**Input Data**:
- `units`: sf object with height and density attributes
- `dem`: SpatRaster for topographic position/exposure

**Output**:
- Column `R2` added to `units` with vulnerability index

---

#### R3 - Drought Stress

**Full Name**: Drought Stress Vulnerability
**Unit**: Index (0-100)
**Range**: 0-100
**Direction**: Lower is better (less stress)

**Schema**:
```
Indicator: R3
Name: Drought Stress
Family: R (Risk & Resilience)
Value: Numeric [0-100]
Unit: Composite drought vulnerability index
Calculation: Weighted (inverse TWI) + precipitation deficit + species sensitivity
Dependencies: DEM (TWI), WorldClim (climate), BD Forêt (species)
Normalization: Composite already 0-100
Thresholds:
  - Low: 0-25 (drought-tolerant site)
  - Moderate: 25-50 (manageable)
  - High: 50-75 (stressed site)
  - Severe: 75-100 (critical drought risk)
```

**Formula**:
```
R3 = w1 × (100 - TWI_normalized) + w2 × precipitation_deficit + w3 × species_sensitivity

Default weights: w1 = 0.4, w2 = 0.4, w3 = 0.2
```

**Input Data**:
- `units`: sf object with TWI values (from v0.2.0 W3) and species
- `climate`: Climate raster (precipitation seasonality)

**Output**:
- Column `R3` added to `units` with drought stress index

---

### T-Family: Temporal Dynamics

#### T1 - Stand Age

**Full Name**: Forest Stand Age
**Unit**: Years
**Range**: 0-∞
**Direction**: Higher may be better (ancient forests valued)

**Schema**:
```
Indicator: T1
Name: Stand Age
Family: T (Temporal Dynamics)
Value: Numeric [0-∞]
Unit: Years since establishment
Calculation: Current year - establishment year, or from age classes
Dependencies: BD Forêt historical data, Cassini maps (proxy)
Normalization: Log-scale 0-100, capped at 300 years
Thresholds:
  - Ancient: 150+ years (old-growth potential)
  - Mature: 100-150 years (mature forest)
  - Intermediate: 60-100 years (mid-rotation)
  - Young: 20-60 years (young stand)
  - Recent: 0-20 years (plantation/regeneration)
```

**Normalization Formula**:
```
T1_normalized = 100 × (log(age + 1) / log(301))
# Log scale emphasizes ancient vs. recent, caps at 300 years
```

**Input Data**:
- `units`: sf object with age attribute or establishment year
- `historical_data`: Optional historical forest maps for proxy age

**Output**:
- Column `T1` added to `units` with age (years)
- Column `T1_norm` with normalized 0-100 score

---

#### T2 - Land Use Change Rate

**Full Name**: Land Use Change Rate
**Unit**: Percent per year (%/yr)
**Range**: 0-∞
**Direction**: Lower may be better (stability valued) OR context-dependent

**Schema**:
```
Indicator: T2
Name: Land Use Change Rate
Family: T (Temporal Dynamics)
Value: Numeric [0-∞]
Unit: % area changed per year
Calculation: (% area changed / years elapsed)
Dependencies: Multi-temporal land cover (Corine Land Cover 1990-2020)
Normalization: Inverse (stability = high score) OR direct (change = high score)
Thresholds:
  - Stable: 0-0.5%/yr (very low change)
  - Low change: 0.5-1.5%/yr (minor transitions)
  - Moderate change: 1.5-3%/yr (notable transitions)
  - High change: 3%+ /yr (major transformation)
```

**Formula**:
```
T2 = (pixels_changed / pixels_total) × 100 / years_elapsed

# For 30-year period (1990-2020):
T2 = % area changed / 30
```

**Input Data**:
- `units`: sf object with forest geometries
- `land_cover_early`: SpatRaster (e.g., CLC 1990)
- `land_cover_late`: SpatRaster (e.g., CLC 2020)
- `years_elapsed`: Numeric (e.g., 30)

**Output**:
- Column `T2` added to `units` with change rate (%/yr)
- Column `T2_norm` with normalized 0-100 score (interpretation depends on context)

---

### A-Family: Air & Microclimate

#### A1 - Tree Coverage Buffer

**Full Name**: Forest Coverage in 1km Buffer
**Unit**: Percentage (%)
**Range**: 0-100
**Direction**: Higher is better (more forest coverage)

**Schema**:
```
Indicator: A1
Name: Tree Coverage Buffer
Family: A (Air & Microclimate)
Value: Numeric [0-100]
Unit: % forest cover within 1km radius
Calculation: Mean forest coverage in buffer zone
Dependencies: Land cover raster (CLC forest classes or canopy cover)
Normalization: Linear 0-100 (raw value is already percentage)
Thresholds:
  - Excellent: 75-100% (dense forest matrix)
  - Good: 50-75% (majority forested)
  - Fair: 25-50% (fragmented)
  - Poor: 0-25% (isolated)
```

**Formula**:
```
A1 = (forest_pixels_in_buffer / total_pixels_in_buffer) × 100

Buffer radius: 1000m
```

**Input Data**:
- `units`: sf object with forest parcel geometries
- `land_cover`: SpatRaster with forest/non-forest classification

**Output**:
- Column `A1` added to `units` with buffer coverage (%)

---

#### A2 - Air Quality

**Full Name**: Air Quality Index
**Unit**: Index (0-100)
**Range**: 0-100
**Direction**: Higher is better (better air quality)

**Schema**:
```
Indicator: A2
Name: Air Quality
Family: A (Air & Microclimate)
Value: Numeric [0-100]
Unit: Air quality index (direct or proxy)
Calculation: ATMO data (if available) OR distance-based proxy
Dependencies: ATMO stations OR OSM roads + CLC urban areas (proxy)
Normalization: ATMO scale conversion OR inverse distance normalization
Thresholds:
  - Excellent: 75-100 (very good air quality)
  - Good: 50-75 (acceptable)
  - Fair: 25-50 (moderately polluted)
  - Poor: 0-25 (polluted)
```

**Formula (Proxy)**:
```
A2_proxy = w1 × normalize_inverse(dist_roads) + w2 × normalize_inverse(dist_urban)

Where:
  dist_roads: Distance (m) to major roads (OSM motorway, trunk, primary)
  dist_urban: Distance (m) to urban areas (CLC urban classes)
  w1 = 0.7, w2 = 0.3
  normalize_inverse: 100 × (1 - min(dist, 5000) / 5000)
```

**Input Data**:
- `units`: sf object with forest parcel geometries
- `atmo_data`: Optional ATMO station measurements
- `roads`: sf object with OSM road network (for proxy)
- `urban_areas`: sf object with CLC urban polygons (for proxy)

**Output**:
- Column `A2` added to `units` with air quality index
- Attribute `A2_method` indicating "direct" or "proxy"

---

## Family Composite Schemas

### Family Index Structure

Each family has a composite index combining its sub-indicators:

```
Family Index = weighted_average(sub-indicators)

Example:
  family_B = w1 × B1_norm + w2 × B2_norm + w3 × B3_norm

Default weights: Equal (w1 = w2 = w3 = 1/3)
User-configurable via create_family_index(weights = list(B = c(...)))
```

### Family Metadata

```
Family Schema:
  code: Single letter (B, R, T, A)
  name_en: English full name
  name_fr: French full name
  indicators: Vector of indicator codes (e.g., c("B1", "B2", "B3"))
  composite_column: Column name for family index (e.g., "family_B")
  normalization: Method ("mean", "weighted", "geometric", "harmonic")
  weights: Named vector of indicator weights (default: equal)
```

---

## Normalization Parameters

### Normalization Methods (v0.2.0 + v0.3.0 Extension)

| Method | Formula | Use Case |
|--------|---------|----------|
| **linear** | `(x - min) / (max - min) × 100` | Indicators with known min/max (B1, A1) |
| **quantile** | `rank(x) / n × 100` | Skewed distributions |
| **zscore** | `(x - mean) / sd × 50 + 50` | Normal distributions |
| **log** | `log(x + 1) / log(max + 1) × 100` | Age, distances (T1, B3) |
| **inverse** | `100 × (1 - (x / max))` | Risks, distances where lower is better (R1, R2, R3) |

### Indicator-Specific Normalization

| Indicator | Method | Rationale |
|-----------|--------|-----------|
| B1 | linear | Already percentage (0-100) |
| B2 | linear | Shannon H scaled to 0-100 |
| B3 | inverse distance | Lower distance = higher score, cap at 5000m |
| R1, R2, R3 | linear | Composite indices already 0-100 |
| T1 | log | Age has diminishing returns, emphasize ancient |
| T2 | linear or inverse | Context-dependent (stability vs. dynamism) |
| A1 | linear | Already percentage (0-100) |
| A2 | linear | Index already 0-100 (direct or proxy) |

---

## Data Relationships

### Entity Relationship Diagram

```
nemeton_units (sf object)
│
├─> Indicator Columns (raw values)
│   ├── B1 (numeric, %)
│   ├── B2 (numeric, 0-100)
│   ├── B3 (numeric, m)
│   ├── R1, R2, R3 (numeric, 0-100)
│   ├── T1 (numeric, years)
│   ├── T2 (numeric, %/yr)
│   ├── A1, A2 (numeric, 0-100)
│   └── [v0.2.0 indicators: C1, C2, W1, W2, W3, F1, F2, L1, L2]
│
├─> Normalized Columns (optional, 0-100)
│   ├── B1_norm, B2_norm, B3_norm, ...
│   └── [normalization adds "_norm" suffix]
│
├─> Family Composites (0-100)
│   ├── family_B (composite of B1, B2, B3)
│   ├── family_R (composite of R1, R2, R3)
│   ├── family_T (composite of T1, T2)
│   ├── family_A (composite of A1, A2)
│   └── [v0.2.0 families: family_C, family_W, family_F, family_L]
│
└─> Geometry
    └── geometry column (sf MULTIPOLYGON)
```

### External Data Dependencies

```
Protected Areas (sf) ──> B1 calculation
    └── Sources: INPN ZNIEFF, Natura2000, Parks

BD Forêt v2 (attributes) ──> B2, R1, R2, R3, T1
    └── Attributes: species, age, height, density, strata

Land Cover Rasters (SpatRaster) ──> T2, A1
    └── Sources: Corine Land Cover 1990, 2000, 2006, 2012, 2018, 2020

DEM (SpatRaster) ──> R1 (slope), R2 (exposure), R3 (TWI)
    └── Sources: IGN BD ALTI, SRTM

Climate Data (SpatRaster) ──> R1, R3
    └── Sources: WorldClim, Météo-France

Ecological Corridors (sf) ──> B3
    └── Sources: Trame Verte et Bleue regional datasets

OSM Roads (sf) ──> A2 (proxy)
    └── Sources: OpenStreetMap extracts

ATMO Stations (sf or raster) ──> A2 (direct)
    └── Sources: Regional ATMO networks (optional)
```

---

## Validation Rules

### Input Validation

1. **units**: Must be sf object, POLYGON or MULTIPOLYGON geometry, defined CRS
2. **Indicator values**: Must be numeric, can contain NA (handled gracefully)
3. **Family codes**: Must match `[A-Z][0-9]` pattern (e.g., B1, R2, T1)
4. **Weights**: Must sum to 1 (or auto-normalized), must be named vector matching indicators

### Output Constraints

1. **Raw indicators**: Range depends on indicator (%, index, meters, years)
2. **Normalized indicators**: Always 0-100 scale
3. **Family composites**: Always 0-100 scale
4. **NA handling**: Preserved through calculations, warnings issued, does not stop processing

---

## Backward Compatibility Guarantee

**v0.2.0 Indicators Unchanged**:
- C1, C2 (Carbon family)
- W1, W2, W3 (Water family)
- F1, F2 (Soil family)
- L1, L2 (Landscape family)

**Safe Extensions**:
- ✅ Add new indicator columns (B1, B2, B3, R1, R2, R3, T1, T2, A1, A2)
- ✅ Add new family composites (family_B, family_R, family_T, family_A)
- ✅ Extend `normalize_indicators()` to recognize B*, R*, T*, A* prefixes
- ✅ Extend `create_family_index()` to support B, R, T, A codes
- ✅ Extend radar plot to display 9+ axes

**Forbidden Changes**:
- ❌ Modify v0.2.0 indicator calculation formulas
- ❌ Rename v0.2.0 columns
- ❌ Change v0.2.0 function signatures

---

## Document Version

**Version**: 1.0
**Date**: 2026-01-05
**Status**: Design Phase Complete
**Next Phase**: Generate contracts/ function specifications
