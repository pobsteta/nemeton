# Research & Technical Decisions: v0.3.0

**Feature**: MVP v0.3.0 - Multi-Family Indicator Extension
**Date**: 2026-01-05
**Status**: Complete

## Purpose

This document records technical research and decisions made during Phase 0 planning for v0.3.0. All [NEEDS CLARIFICATION] items from the implementation plan have been resolved through literature review, technical testing, and best practices analysis.

## Research Questions Addressed

1. Protected Area Data Access (B1 indicator)
2. Land Use Change Detection (T2 indicator)
3. Risk Index Methodologies (R1, R2, R3 indicators)
4. Air Quality Proxy (A2 indicator)
5. Structural Diversity Index (B2 indicator)

---

## Decision R1: Protected Area Data Access

### Question
What is the most reliable method to access INPN protected area data (ZNIEFF, Natura2000) in R for the B1 indicator?

### Options Evaluated

| Method | Pros | Cons | Verdict |
|--------|------|------|---------|
| **INPN WFS API** | Real-time data, always up-to-date, no local storage | Network dependency, API rate limits, complex queries | ✅ PRIMARY |
| **Downloaded Shapefiles** | Offline, fast, no rate limits | Manual updates, storage overhead, versioning issues | ✅ FALLBACK |
| **rnaturalearth** | Easy API, good for global data | Limited French protected areas, not INPN source | ❌ REJECTED |

### Decision

**Use INPN WFS API as primary method with local shapefile fallback**.

### Rationale

1. **INPN is authoritative source**: INPN (Inventaire National du Patrimoine Naturel) is the official French biodiversity database managed by UMS PatriNat (OFB-CNRS-MNHN).

2. **WFS standard compliance**: INPN provides OGC WFS (Web Feature Service) endpoints that sf can consume directly via `sf::st_read()`.

3. **Reproducibility**: WFS URLs in documentation allow users to reproduce analyses with current data.

4. **Fallback necessity**: For offline workflows or API downtime, provide mechanism to use local shapefiles.

### Implementation Approach

```r
# Example implementation pattern (not final code)
indicator_biodiversity_protection <- function(units,
                                               protected_areas = NULL,
                                               source = c("wfs", "local"),
                                               wfs_url = "https://inpn.mnhn.fr/geoserver/wfs",
                                               ...) {

  source <- match.arg(source)

  if (source == "wfs" && is.null(protected_areas)) {
    # Fetch from INPN WFS
    protected_areas <- fetch_inpn_protected_areas(units, wfs_url)
  } else if (is.null(protected_areas)) {
    cli::cli_abort("Must provide protected_areas when source='local'")
  }

  # Calculate B1: % area overlap
  # ...
}
```

### References

- INPN WFS: https://inpn.mnhn.fr/geoserver/wfs
- INPN data catalog: https://inpn.mnhn.fr/telechargement/cartes-et-information-geographique

### Alternatives Considered

- **rgbif** (Global Biodiversity Information Facility): Too generic, not focused on protected areas
- **osmdata** for protected areas: OpenStreetMap data quality variable for French protected zones
- **Manual download + packaging**: Violates open data reproducibility principle

---

## Decision R2: Land Use Change Detection

### Question
How to efficiently compute T2 (land use change rate) from multi-temporal Corine Land Cover rasters in R?

### Options Evaluated

| Method | Pros | Cons | Verdict |
|--------|------|------|---------|
| **terra raster algebra** | Fast C++ backend, memory-efficient, native R | Requires user to download CLC | ✅ SELECTED |
| **Pre-process to vector transitions** | Smaller files, faster zonal stats | Complex preprocessing, information loss | ❌ REJECTED |
| **External tools (GDAL/Python)** | Powerful, mature | Breaks pure R workflow, dependency hell | ❌ REJECTED |

### Decision

**Use `terra` raster algebra for direct multi-temporal CLC processing**.

### Rationale

1. **Constitution compliance**: terra is required package (II. Interopérabilité R Spatial), replaces deprecated raster package.

2. **Performance**: terra is 3-10x faster than legacy raster package, uses C++ SpatRaster backend.

3. **Memory efficiency**: terra supports out-of-memory raster processing for large extents.

4. **Simplicity**: Direct raster math (`clc_2020 - clc_1990`) with `exactextractr::exact_extract()` for zonal stats.

### Implementation Approach

```r
# Workflow pattern
indicator_temporal_change <- function(units,
                                       land_cover_early,
                                       land_cover_late,
                                       years_elapsed,
                                       ...) {

  # terra raster algebra
  change_raster <- land_cover_late != land_cover_early

  # Zonal statistics with exactextractr
  change_pct <- exactextractr::exact_extract(
    change_raster,
    units,
    fun = "mean",  # % changed pixels
    progress = FALSE
  )

  # Annualized rate
  change_rate <- (change_pct * 100) / years_elapsed

  units$T2 <- change_rate
  return(units)
}
```

### Technical Details

- **CLC Data**: Corine Land Cover 2020, 2018, 2012, 2006, 2000, 1990 (EEA)
- **Resolution**: 100m (CLC standard)
- **Classes**: 44 land cover types (CLC nomenclature)
- **Change Detection**: Binary change (any class transition) or weighted by transition type
- **Zonal Stat**: Mean of binary change raster = % area changed

### References

- Corine Land Cover: https://land.copernicus.eu/pan-european/corine-land-cover
- terra performance: Hijmans (2022) terra package vignette
- exactextractr: https://github.com/isciences/exactextractr

### Alternatives Considered

- **Reclassify + crosstab**: More detail but slower, overkill for simple change rate
- **LandTrendr algorithm**: Time series analysis, too complex for single change rate metric
- **Google Earth Engine**: Powerful but requires rgee (optional dependency), internet connection

---

## Decision R3: Risk Index Methodologies

### Question
What are established fire risk (R1) and storm vulnerability (R2) index formulas used in French forestry?

### Research Findings

#### Fire Risk (R1)

**Formula Source**: Adapted from French IFN (Inventaire Forestier National) and ONF (Office National des Forêts) fire risk assessment.

**Composite Index**:
```
R1 = w1 × slope_factor + w2 × species_flammability + w3 × climate_dryness
```

**Factors**:
1. **Slope factor** (0-100): Steeper slopes = faster fire spread
   - 0-15%: Low (score 20)
   - 15-30%: Medium (score 50)
   - 30%+: High (score 80)

2. **Species flammability** (0-100): Based on resin content, litter structure
   - High: Pinus, Eucalyptus (80)
   - Medium: Quercus, mixed (50)
   - Low: Fagus, deciduous (20)

3. **Climate dryness** (0-100): Precipitation deficit, temperature
   - Use WorldClim bio variables: BIO17 (precipitation driest quarter)
   - Low precip (<200mm) → high fire risk

**Weights**: Equal (w1=w2=w3=1/3) unless user overrides

**References**:
- Chatry et al. (2010) "Rapport de la mission sur les incendies de forêt"
- Lampin-Maillet et al. (2010) Fire ecology research

#### Storm Vulnerability (R2)

**Formula Source**: European storm damage models (Gardiner et al. 2008, Klaus et al. 2009)

**Composite Index**:
```
R2 = w1 × stand_height + w2 × stand_density + w3 × topographic_exposure
```

**Factors**:
1. **Stand height** (0-100): Taller stands = higher wind moment
   - <10m: Low (20)
   - 10-25m: Medium (50)
   - 25m+: High (80)

2. **Stand density** (0-100): Dense stands = mutual protection BUT higher wind load
   - <30%: Low (40)
   - 30-70%: Medium (50)
   - 70%+: High (60)

3. **Topographic exposure** (0-100): From DEM, aspect to prevailing winds
   - Sheltered valleys: Low (20)
   - Ridges, exposed slopes: High (80)
   - Use TPI (Topographic Position Index) or aspect analysis

**Weights**: Equal default

**References**:
- Gardiner et al. (2008) "A review of mechanistic modelling of wind damage risk to forests"
- Klaus et al. (2009) "Windthrow after storm Kyrill"

#### Drought Stress (R3)

**Formula Source**: Forest drought vulnerability indices (Allen et al. 2010)

**Composite Index**:
```
R3 = w1 × (100 - TWI_normalized) + w2 × precipitation_deficit + w3 × species_sensitivity
```

**Factors**:
1. **TWI (Topographic Wetness Index)** (already in v0.2.0 as W3):
   - Low TWI → high drought stress
   - Inverse: `100 - normalize(TWI)` so dry sites score high

2. **Precipitation deficit** (0-100):
   - Use WorldClim BIO15 (precipitation seasonality)
   - High seasonality + low summer precip = high stress

3. **Species sensitivity** (0-100):
   - Drought-sensitive: Fagus, Abies (80)
   - Intermediate: Quercus, Pinus (50)
   - Drought-tolerant: Mediterranean species (20)

**Weights**: Adjust by region (w1=0.4, w2=0.4, w3=0.2 suggested)

**References**:
- Allen et al. (2010) "A global overview of drought and heat-induced tree mortality"
- McDowell et al. (2008) "Mechanisms of plant survival and mortality during drought"

### Decision

**Implement composite indices using weighted factor approach with documented scientific references**.

### Rationale

1. **Scientific credibility**: Formulas based on peer-reviewed literature and French forestry agency practice.

2. **Transparency**: Clear factor definitions, users can inspect and customize weights.

3. **Parameterizable**: Default weights from literature but `weights` argument allows expert override.

4. **Data availability**: All factors computable from available open data (DEM, climate, forest inventory).

### Implementation Considerations

- **Factor normalization**: All factors scaled to 0-100 before weighting (consistent with other nemeton indicators)
- **Species lookup tables**: Internal data (R/sysdata.rda) with flammability/drought sensitivity scores
- **Climate data**: WorldClim rasters (open, global) or Météo-France (if available)
- **User override**: `weights` parameter in each risk indicator function

---

## Decision R4: Air Quality Proxy

### Question
When ATMO air quality data is unavailable for A2, what distance-based proxy is most appropriate?

### Options Evaluated

| Proxy | Data Source | Rationale | Verdict |
|-------|-------------|-----------|---------|
| **Distance to major roads** | OpenStreetMap | Traffic = primary pollutant source | ✅ PRIMARY |
| **Distance to urban areas** | WorldPop / CLC urban class | Urban centers = pollution hotspots | ✅ SECONDARY |
| **Combined road + urban** | OSM + CLC | More comprehensive | ✅ COMBINED |
| **Population density** | WorldPop | Indirect proxy | ❌ TOO INDIRECT |

### Decision

**Use combined distance metric: weighted average of road distance and urban distance**.

### Rationale

1. **Traffic pollution dominates**: In peri-urban contexts, road traffic (NOx, PM2.5) is primary forest air quality threat.

2. **Urban areas supplement**: Cities contribute to regional pollution but less localized than roads.

3. **OSM data quality**: OpenStreetMap road network well-maintained in France, `osmdata` R package provides easy access.

4. **Fallback simplicity**: If ATMO data available, use directly; else proxy is scientifically defensible.

### Implementation Approach

```r
# Proxy formula
A2_proxy = w1 × normalize_inverse(dist_major_roads) +
           w2 × normalize_inverse(dist_urban_areas)

# Where:
# - dist_major_roads: Distance (m) to highways/primary roads (OSM motorway, trunk, primary)
# - dist_urban_areas: Distance (m) to CLC urban classes (111, 112, 121, 122)
# - normalize_inverse: Closer = worse air quality = higher score
# - Weights: w1=0.7 (roads dominant), w2=0.3 (urban background)
```

### Validation

- **Correlation with ATMO**: Where ATMO data available, validate proxy correlation (expect r > 0.6)
- **Warning message**: Clearly inform user when proxy used vs. direct measurements
- **Documentation**: Explain proxy limitations in roxygen2 docs

### Data Sources

- **Roads**: OpenStreetMap via `osmdata::opq()` or downloaded extracts
- **Urban areas**: Corine Land Cover urban classes (CLC 111-142)
- **ATMO (when available)**: Regional air quality networks, NO2/PM10 annual means

### References

- Vienneau et al. (2013) "Comparison of land-use regression models for NO2"
- OpenStreetMap France: https://download.openstreetmap.fr/extracts/europe/france/

### Alternatives Considered

- **Satellite AOD** (Aerosol Optical Depth): Available but coarse resolution (1km+), not forest-specific
- **Elevation proxy**: Higher elevation = cleaner air, but too simplistic
- **INERIS air quality models**: High quality but proprietary, not open data compliant

---

## Decision R5: Structural Diversity Index

### Question
How to quantify canopy stratification and age diversity for B2 (structural diversity) composite indicator?

### Options Evaluated

| Method | Calculation | Pros | Cons | Verdict |
|--------|-------------|------|------|---------|
| **Shannon Diversity** | H = -Σ(pi × ln(pi)) | Standard ecology metric, interpretable | Assumes categories equal | ✅ SELECTED |
| **Simpson Index** | D = 1 - Σ(pi²) | Robust to sample size | Less sensitive to rare classes | ❌ REJECTED |
| **Custom multi-factor** | Weighted sum of strata + age classes | Flexible | Arbitrary weights | ❌ TOO COMPLEX |

### Decision

**Use Shannon Diversity Index (H) applied separately to canopy strata and age classes, then combine**.

### Rationale

1. **Ecological standard**: Shannon H is widely used in forest ecology for structural diversity assessment.

2. **Interpretable**: H=0 (monoculture/single layer) to H_max (perfectly even distribution).

3. **Data availability**: BD Forêt v2 provides:
   - Strata data: Canopy height classes (emergent, dominant, intermediate, suppressed)
   - Age data: Stand age or age class distribution

4. **Composability**: Can compute H_strata and H_age separately, then combine.

### Implementation Approach

```r
# Structural diversity formula
B2 = w1 × H_strata_normalized + w2 × H_age_normalized

# Where:
# H_strata = Shannon diversity of canopy layers (e.g., 3 layers → H ≈ 1.1)
# H_age = Shannon diversity of age classes (e.g., 5 age cohorts → H ≈ 1.6)
# Normalize to 0-100 scale using H_max theoretical maximum
# Weights: w1=0.6 (strata more important), w2=0.4 (age classes)
```

### Shannon Diversity Calculation

```r
# For n categories with proportions p1, p2, ..., pn
H <- function(proportions) {
  p <- proportions[proportions > 0]  # Remove zeros
  -sum(p * log(p))
}

# Normalized to 0-100
H_normalized <- (H_observed / H_max) * 100
# Where H_max = log(n_categories) for perfectly even distribution
```

### Data Requirements

**From BD Forêt v2**:
1. **Canopy strata**: Derived from height data or vegetation profile
   - Categories: Emergent (>25m), Dominant (15-25m), Intermediate (5-15m), Suppressed (<5m)

2. **Age classes**: From stand age attribute
   - Categories: Young (<20yr), Intermediate (20-60yr), Mature (60-100yr), Old (100-150yr), Ancient (150yr+)

**Fallback if strata unavailable**:
- Use height coefficient of variation (CV) as proxy for vertical diversity
- Age diversity alone if height data missing

### Normalization

- **H_max for strata**: log(4) ≈ 1.386 (4 strata categories)
- **H_max for age**: log(5) ≈ 1.609 (5 age classes)
- Scale to 0-100: `(H / H_max) × 100`

### References

- Shannon (1948) "A mathematical theory of communication"
- McElhinny et al. (2005) "Forest and woodland stand structural complexity"
- Pommerening (2002) "Approaches to quantifying forest structures"

### Alternatives Considered

- **LiDAR-based metrics**: Ideal but requires LiDAR data (not universally available, violates open data first)
- **Species diversity + structure**: Combines biodiversity and structure, but conflates two dimensions
- **GINI coefficient**: Income inequality metric adapted to forest structure, less ecologically standard

---

## Summary of Decisions

| Question | Decision | Primary Method | Fallback |
|----------|----------|----------------|----------|
| **R1: Protected Area Access** | INPN WFS API | `sf::st_read(wfs_url)` | Local shapefiles |
| **R2: Land Use Change** | terra raster algebra | `terra` diff + `exactextractr` | Pre-processed vectors |
| **R3: Risk Indices** | Composite weighted factors | Literature formulas | User-defined weights |
| **R4: Air Quality Proxy** | Distance to roads + urban | OSM + CLC | ATMO direct data |
| **R5: Structural Diversity** | Shannon Index (H) | Strata H + Age H | Height CV proxy |

## Research Artifacts

All research decisions are **technology-agnostic at the specification level** but include **concrete implementation guidance** for R package development.

## Next Phase

✅ **Phase 0 Complete** - All [NEEDS CLARIFICATION] resolved

🔄 **Proceed to Phase 1**: Generate design artifacts (data-model.md, contracts/, quickstart.md)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Reviewed By**: Constitution compliance check passed
