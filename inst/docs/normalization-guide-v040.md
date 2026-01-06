# Normalization Guide for nemeton v0.4.0

## Overview

This guide provides detailed normalization recommendations for all 12 indicator families in the nemeton package v0.4.0, with focus on the 4 new families added in this release: Social (S), Productive (P), Energy (E), and Naturalness (N).

## Normalization Methods

### 1. Min-Max Normalization (0-100)

**Formula**: `norm = (value - min) / (max - min) * 100`

**Characteristics**:
- Linear transformation preserving distribution shape
- Sensitive to outliers
- Intuitive interpretation (0 = minimum, 100 = maximum)
- **Recommended for**: Most indicators where absolute bounds are meaningful

### 2. Z-Score Standardization

**Formula**: `norm = (value - mean) / sd`

**Characteristics**:
- Centers data around 0
- Units in standard deviations
- Less sensitive to outliers
- **Recommended for**: Comparing indicators with different scales

### 3. Quantile/Percentile Normalization

**Formula**: `norm = percentile_rank * 100`

**Characteristics**:
- Robust to extreme outliers
- Creates uniform distribution
- Relative ranking approach
- **Recommended for**: Indicators with heavy-tailed distributions

## Family S - Social & Recreational Services

### S1: Trail Density (km/ha)

- **Recommended method**: minmax
- **Reference range**: 0-3 km/ha
- **Interpretation**:
  - 0-30: Low recreational access
  - 30-70: Moderate recreational use
  - 70-100: Intensive recreational infrastructure
- **Notes**: Use OSM highway=path/footway/cycleway/bridleway. Urban forests may exceed 3 km/ha.

### S2: Accessibility Score (0-100)

- **Recommended method**: minmax (already 0-100)
- **Reference range**: 0-100
- **Interpretation**:
  - 0-30: Remote, difficult access
  - 30-70: Moderate accessibility
  - 70-100: Excellent multimodal access
- **Notes**: Composite of road distance, public transport, and parking availability.

### S3: Population Proximity (total within 5/10/20km)

- **Recommended method**: minmax OR quantile
- **Reference range**: 0-500,000 (highly context-dependent)
- **Interpretation**:
  - 0-30: Isolated forest, low visitor potential
  - 30-70: Peri-urban, moderate visitor potential
  - 70-100: Urban/suburban, high visitor pressure
- **Notes**: Use quantile method if comparing regions with very different population densities.

## Family P - Productive & Economic Services

### P1: Standing Volume (m³/ha)

- **Recommended method**: minmax
- **Reference range**: 0-800 m³/ha
- **Interpretation**:
  - 0-30: Young stands, regeneration, or sparse forests
  - 30-70: Mature productive forests
  - 70-100: Old-growth or intensively managed high-volume stands
- **Notes**: Based on IFN allometric equations. Conifers typically reach higher volumes than broadleaves.

### P2: Site Productivity (m³/ha/yr)

- **Recommended method**: minmax
- **Reference range**: 0-15 m³/ha/yr
- **Interpretation**:
  - 0-30: Poor site conditions (low fertility, harsh climate)
  - 30-70: Average productivity
  - 70-100: Excellent site conditions (high fertility, favorable climate)
- **Notes**: Integrates fertility class, climate suitability, and species-specific growth potential.

### P3: Timber Quality Score (0-100)

- **Recommended method**: minmax (already 0-100)
- **Reference range**: 0-100
- **Interpretation**:
  - 0-30: Low quality - defects, poor form, small diameter
  - 30-70: Medium quality - suitable for pulp/pallets
  - 70-100: High quality - construction timber, sawlogs
- **Notes**: Composite of stem straightness, diameter class, and defect presence.

## Family E - Energy & Climate Services

### E1: Fuelwood Potential (tonnes DM/yr)

- **Recommended method**: minmax
- **Reference range**: 0-10 tonnes DM/ha/yr
- **Interpretation**:
  - 0-30: Low biomass availability
  - 30-70: Moderate fuelwood potential
  - 70-100: High biomass mobilization potential
- **Notes**: Includes harvest residues (branches, tops) + coppice regrowth if applicable.

### E2: CO2 Emission Avoidance (tCO2eq/yr)

- **Recommended method**: minmax
- **Reference range**: 0-20 tCO2eq/ha/yr
- **Interpretation**:
  - 0-30: Low climate mitigation benefit
  - 30-70: Moderate substitution potential
  - 70-100: High climate mitigation via wood energy/materials
- **Notes**: Based on ADEME emission factors for fossil fuel/cement substitution scenarios.

## Family N - Naturalness & Wilderness

### N1: Infrastructure Distance (m)

- **Recommended method**: minmax OR quantile
- **Reference range**: 0-5000 m
- **Interpretation**:
  - 0-30: Near infrastructure, high human influence
  - 30-70: Semi-natural, moderate remoteness
  - 70-100: Wild, remote areas
- **Notes**: Minimum distance to roads (motorway-tertiary), buildings, power lines. Use quantile for regional comparisons.

### N2: Forest Continuity (ha)

- **Recommended method**: quantile
- **Reference range**: 0-2000 ha (context-dependent)
- **Interpretation**:
  - 0-30: Fragmented, small patches
  - 30-70: Moderately continuous forest
  - 70-100: Large, unfragmented forest blocks
- **Notes**: Continuous patch area after 100m buffer-dissolve. Quantile method recommended due to skewed distribution.

### N3: Wilderness Composite (0-100)

- **Recommended method**: Already normalized (0-100)
- **Reference range**: 0-100
- **Interpretation**:
  - 0-30: Low wilderness character - managed/disturbed
  - 30-70: Semi-natural character
  - 70-100: High wilderness - pristine/undisturbed
- **Notes**: Geometric mean of normalized N1, N2, T1 (ancientness), B1 (protection status).

## Cross-Family Recommendations

### When to use minmax:
- Indicators with known absolute bounds (S2, P3, N3)
- Physical measurements with meaningful extremes (P1, E1, E2, N1)
- When interpretation relative to theoretical min/max is important

### When to use quantile:
- Indicators with heavy-tailed distributions (N2, S3)
- Regional comparisons with different baseline conditions
- When relative ranking is more important than absolute values

### When to use zscore:
- Creating composite indices from multiple families
- Statistical modeling requiring standardized inputs
- When outlier sensitivity is a concern

## Reference Datasets

For consistent multi-site comparisons, use reference normalization:

```r
# Normalize new sites using reference parameters from baseline dataset
normalized_new <- normalize_indicators(
  new_data,
  indicators = c("S1", "S2", "S3", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"),
  method = "minmax",
  reference_data = baseline_reference
)
```

Reference datasets available:
- `inst/extdata/normalization_presets_v040.csv`: Default min/max bounds per indicator
- French regional references: Contact ONF for regional reference datasets
- European references: Contact EFI for pan-European normalization bounds

## Examples

### Social Family Normalization

```r
# Normalize social indicators
result_social <- data %>%
  indicator_social_trails(method = "osm") %>%
  indicator_social_accessibility() %>%
  indicator_social_proximity() %>%
  normalize_indicators(
    indicators = c("S1", "S2", "S3"),
    method = "minmax"
  )
```

### Productive Family with Custom Bounds

```r
# Regional normalization for oak-dominated forests
result_productive <- data %>%
  indicator_productive_volume(species_field = "species") %>%
  indicator_productive_station() %>%
  indicator_productive_quality() %>%
  normalize_indicators(
    indicators = c("P1", "P2", "P3"),
    method = "minmax",
    reference_data = oak_reference
  )
```

### Naturalness with Quantile Method

```r
# Quantile normalization for regional wilderness assessment
result_naturalness <- data %>%
  indicator_naturalness_distance(method = "osm") %>%
  indicator_naturalness_continuity(connectivity_distance = 100) %>%
  indicator_naturalness_composite() %>%
  normalize_indicators(
    indicators = c("N1", "N2"),  # N3 already normalized
    method = "quantile"
  )
```

## Version History

- **v0.4.0**: Added normalization presets for S, P, E, N families
- **v0.3.0**: Added normalization presets for A, T, R families
- **v0.2.0**: Established normalization framework for C, B, W, F, L families

## References

- **OSM Trail Classification**: OpenStreetMap Wiki - Highway classification
- **IFN Allometry**: Institut National de l'Information Géographique et Forestière (2021)
- **ADEME Factors**: Base Carbone® v22.0 (2024)
- **Wilderness Mapping**: Carver et al. (2012) - Wilderness mapping methodology
