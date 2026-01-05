# Quickstart Guide: v0.3.0 Indicator Families

**Feature**: MVP v0.3.0 - Multi-Family Indicator Extension
**Date**: 2026-01-05
**Audience**: R package users (ecologists, forest managers, analysts)

## Overview

This quickstart demonstrates how to use the 4 new indicator families (B-Biodiversity, R-Risk, T-Temporal, A-Air) introduced in nemeton v0.3.0. You'll learn to:

1. Calculate new indicators (B1-B3, R1-R3, T1-T2, A1-A2)
2. Normalize and create family composites
3. Visualize results with extended 9-axis radar plots
4. Perform cross-family correlation analysis

**Time**: ~15 minutes
**Prerequisites**: nemeton v0.3.0 installed, basic R and sf knowledge

---

## Step 1: Load Package and Demo Data

```r
# Load nemeton and dependencies
library(nemeton)
library(sf)
library(terra)
library(ggplot2)

# Load demo dataset (20 forest parcels, 136 ha)
data(massif_demo_units)

# Inspect
print(massif_demo_units)
# Simple feature collection with 20 features and X fields
# Geometry type: MULTIPOLYGON
# CRS: EPSG:2154 (Lambert 93)
```

**Expected output**: sf object with 20 parcels, existing v0.2.0 indicators (C1, C2, W1-W3, F1, F2, L1, L2), geometry column.

---

## Step 2: Calculate Biodiversity Indicators (B Family)

### B1: Protected Area Coverage

```r
# Option A: Fetch from INPN WFS (requires internet)
units <- indicator_biodiversity_protection(
  massif_demo_units,
  source = "wfs",
  protection_types = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI")
)

# Option B: Use local protected area shapefile
# protected_zones <- sf::st_read("path/to/protected_areas.shp")
# units <- indicator_biodiversity_protection(
#   massif_demo_units,
#   protected_areas = protected_zones,
#   source = "local"
# )

# View results
summary(units$B1)
#    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#    0.00   12.50   35.00   40.25   67.50   100.00

# Which parcels are highly protected?
highly_protected <- units[units$B1 > 75, ]
nrow(highly_protected)  # e.g., 5 parcels
```

### B2: Structural Diversity

```r
# Assuming BD Forêt attributes loaded
# (in real workflow, you'd load from BD Forêt v2)
units$strata_classes <- sample(
  c("Emergent", "Dominant", "Intermediate", "Suppressed"),
  nrow(units),
  replace = TRUE
)
units$age_classes <- sample(
  c("Young", "Intermediate", "Mature", "Old", "Ancient"),
  nrow(units),
  replace = TRUE
)

units <- indicator_biodiversity_structure(
  units,
  strata_field = "strata_classes",
  age_field = "age_classes",
  method = "shannon",
  weights = c(strata = 0.6, age = 0.4)
)

# Distribution of structural diversity
hist(units$B2,
     main = "Structural Diversity (B2)",
     xlab = "Shannon Index (0-100)",
     col = "forestgreen")
```

### B3: Ecological Connectivity

```r
# Load corridor data (example: Trame Verte et Bleue)
# In real workflow: corridors <- sf::st_read("trame_verte.gpkg")
# For demo, create synthetic corridors
corridors <- sf::st_buffer(massif_demo_units[c(1, 5, 10), ], dist = 500)

units <- indicator_biodiversity_connectivity(
  units,
  corridors = corridors,
  distance_method = "edge",
  max_distance = 3000  # 3km threshold
)

# How many parcels are well-connected (<500m)?
sum(units$B3 < 500)  # e.g., 8 parcels
```

---

## Step 3: Calculate Risk Indicators (R Family)

### R1: Fire Risk

```r
# Load DEM for slope calculation
dem <- rast(system.file("extdata/massif_demo/dem.tif", package = "nemeton"))

# Assuming species attribute exists
units$species <- sample(c("Pinus", "Quercus", "Fagus"), nrow(units), replace = TRUE)

units <- indicator_risk_fire(
  units,
  dem = dem,
  species_field = "species",
  weights = c(slope = 1/3, species = 1/3, climate = 1/3)
)

# Which parcels have high fire risk?
high_fire_risk <- units[units$R1 > 60, ]
plot(high_fire_risk["R1"], main = "High Fire Risk Parcels")
```

### R2: Storm Vulnerability

```r
# Using parcel attributes
units$height <- runif(nrow(units), 10, 30)  # Stand height (m)
units$density <- runif(nrow(units), 0.3, 0.9)  # Stand density (0-1)

units <- indicator_risk_storm(
  units,
  dem = dem,
  height_field = "height",
  density_field = "density"
)

summary(units$R2)
```

### R3: Drought Stress

```r
# Reuse TWI from W3 (v0.2.0 indicator)
# Assuming W3 already calculated
units <- indicator_risk_drought(
  units,
  twi_field = "W3",
  species_field = "species",
  weights = c(twi = 0.4, precip = 0.4, species = 0.2)
)

# Drought stress vs. TWI correlation
plot(units$W3, units$R3,
     xlab = "TWI (W3)",
     ylab = "Drought Stress (R3)",
     main = "Expected inverse relationship")
```

---

## Step 4: Calculate Temporal Indicators (T Family)

### T1: Stand Age

```r
# Option A: Use existing age field
units$age <- runif(nrow(units), 20, 180)  # Example ages (years)

units <- indicator_temporal_age(
  units,
  age_field = "age"
)

# Option B: Calculate from establishment year
# units$establishment_year <- sample(1850:2000, nrow(units), replace = TRUE)
# units <- indicator_temporal_age(
#   units,
#   establishment_year_field = "establishment_year",
#   current_year = 2025
# )

# Ancient forest distribution
hist(units$T1, main = "Stand Age Distribution", xlab = "Age (years)")
```

### T2: Land Use Change Rate

```r
# Load multi-temporal land cover rasters
lc_1990 <- rast(system.file("extdata/massif_demo/land_cover_1990.tif", package = "nemeton"))
lc_2020 <- rast(system.file("extdata/massif_demo/land_cover_2020.tif", package = "nemeton"))

units <- indicator_temporal_change(
  units,
  land_cover_early = lc_1990,
  land_cover_late = lc_2020,
  years_elapsed = 30,
  interpretation = "stability"  # Higher score = more stable
)

# Stable vs. dynamic parcels
stable <- units[units$T2 < 0.5, ]  # <0.5%/yr change
dynamic <- units[units$T2 > 2, ]   # >2%/yr change
```

---

## Step 5: Calculate Air Quality Indicators (A Family)

### A1: Tree Coverage Buffer

```r
# Load land cover raster
land_cover <- rast(system.file("extdata/massif_demo/land_cover.tif", package = "nemeton"))

units <- indicator_air_coverage(
  units,
  land_cover = land_cover,
  forest_classes = c(311, 312, 313),  # CLC forest codes
  buffer_radius = 1000  # 1km
)

# Parcels with high surrounding forest coverage
high_coverage <- units[units$A1 > 75, ]
```

### A2: Air Quality

```r
# Option A: Use ATMO data (if available)
# atmo_stations <- sf::st_read("atmo_stations.gpkg")
# units <- indicator_air_quality(
#   units,
#   atmo_data = atmo_stations,
#   method = "direct"
# )

# Option B: Use distance proxy (fallback)
roads <- sf::st_read(system.file("extdata/massif_demo/roads.gpkg", package = "nemeton"))
urban <- sf::st_read(system.file("extdata/massif_demo/urban_areas.gpkg", package = "nemeton"))

units <- indicator_air_quality(
  units,
  roads = roads,
  urban_areas = urban,
  method = "proxy",
  weights = c(roads = 0.7, urban = 0.3)
)

# Check which method was used
table(units$A2_method)
```

---

## Step 6: Normalize All Indicators

```r
# Normalize all indicators to 0-100 scale
units <- normalize_indicators(
  units,
  indicators = c("B1", "B2", "B3", "R1", "R2", "R3", "T1", "T2", "A1", "A2"),
  method = "linear"  # or "quantile", "zscore", etc.
)

# Check normalized columns
names(units)[grep("_norm$", names(units))]
# [1] "B1_norm" "B2_norm" "B3_norm" "R1_norm" ... "A2_norm"
```

**Note**: B1, A1 are already 0-100 (percentages), so normalization has minimal effect. B3, T1 use log/inverse transforms for proper scaling.

---

## Step 7: Create Family Composite Indices

```r
# Create family-level indices
units <- create_family_index(
  units,
  method = "mean",  # Equal weighting
  family_codes = c("B", "R", "T", "A")
)

# Or with custom weights
units <- create_family_index(
  units,
  method = "weighted",
  weights = list(
    B = c(B1 = 0.4, B2 = 0.3, B3 = 0.3),
    R = c(R1 = 0.33, R2 = 0.33, R3 = 0.34),
    T = c(T1 = 0.5, T2 = 0.5),
    A = c(A1 = 0.6, A2 = 0.4)
  )
)

# View family composites
summary(units[, c("family_B", "family_R", "family_T", "family_A")])
```

**Result**: 4 new columns (family_B, family_R, family_T, family_A) with 0-100 scores representing overall family performance.

---

## Step 8: Visualize with Extended Radar Plot

```r
# Create 9-axis radar plot (v0.2.0: C, W, F, L + v0.3.0: B, R, T, A)
nemeton_radar(
  units,
  families = c("C", "B", "W", "A", "F", "L", "T", "R"),  # 8 families (or 9 if all available)
  parcel_ids = c(1, 5, 10),  # Compare 3 parcels
  labels = c("Parcel 1", "Parcel 5", "Parcel 10")
)
```

**Expected output**: Radar plot with 8-9 axes, each parcel as a different colored polygon, showing multi-dimensional ecosystem service profile.

**Interpretation**:
- **Large polygon**: High scores across many families (multi-functional parcel)
- **Narrow polygon**: Specialized (high in 1-2 families, low in others)
- **Balanced shape**: Even distribution of services

---

## Step 9: Cross-Family Correlation Analysis (US6)

### Compute Family Correlations

```r
# Compute correlation matrix using nemeton functions
corr_matrix <- compute_family_correlations(
  units,
  families = NULL,  # Auto-detect all family_* columns
  method = "pearson"
)

print(corr_matrix)
#         family_C family_B family_W family_A family_F family_L family_T family_R
# family_C     1.00     0.45     0.23     0.18     0.31     0.12     0.56    -0.22
# family_B     0.45     1.00     0.38     0.29     0.19     0.15     0.67    -0.31
# family_W     0.23     0.38     1.00     0.52     0.44     0.08     0.28    -0.18
# ...

# Visualize with built-in heatmap
plot_correlation_matrix(
  corr_matrix,
  method = "circle",
  palette = "RdBu",
  title = "Ecosystem Service Synergies & Trade-offs"
)
```

**Interpretation**:
- **Strong positive** (red, >0.5): Synergies (services co-occur)
  - family_B × family_T: +0.67 (biodiversity ↔ ancient forests)
  - family_W × family_A: +0.52 (water regulation ↔ air quality)
- **Strong negative** (blue, <-0.5): Trade-offs (services conflict)
  - family_R × family_B: -0.31 (high risk ↔ reduced biodiversity)
- **Weak** (white, ~0): Independence

### Identify Multi-Criteria Hotspots

```r
# Use nemeton's hotspot identification function
hotspots <- identify_hotspots(
  units,
  families = NULL,  # All families
  threshold = 80,   # Top 20%
  min_families = 3  # At least 3 families above threshold
)

# View hotspot summary
summary(hotspots[, c("hotspot_count", "hotspot_families", "is_hotspot")])
#  hotspot_count    hotspot_families     is_hotspot
#  Min.   :0.00     Length:20          Mode :logical
#  1st Qu.:1.00     Class :character   FALSE:17
#  Median :2.00     Mode  :character   TRUE :3
#  Mean   :2.15
#  3rd Qu.:3.00
#  Max.   :6.00

# Filter to hotspot parcels only
hotspot_parcels <- hotspots[hotspots$is_hotspot, ]
nrow(hotspot_parcels)  # e.g., 3 parcels

# Map hotspots
plot(sf::st_geometry(units), col = "lightgray", main = "Multi-Criteria Hotspots")
plot(sf::st_geometry(hotspot_parcels), col = "darkgreen", add = TRUE)
legend("topright",
       legend = c("Standard", "Hotspot (≥3 families)"),
       fill = c("lightgray", "darkgreen"))
```

---

## Step 10: Export Results

```r
# Save enhanced dataset
sf::st_write(units, "massif_demo_v030_results.gpkg", delete_dsn = TRUE)

# Export family indices to CSV
family_summary <- sf::st_drop_geometry(units[, c("id", family_cols)])
write.csv(family_summary, "family_indices.csv", row.names = FALSE)

# Generate summary report
summary_table <- data.frame(
  Family = c("C-Carbon", "B-Biodiversity", "W-Water", "A-Air",
             "F-Soil", "L-Landscape", "T-Temporal", "R-Risk"),
  Mean = colMeans(sf::st_drop_geometry(units[, family_cols]), na.rm = TRUE),
  SD = apply(sf::st_drop_geometry(units[, family_cols]), 2, sd, na.rm = TRUE)
)

print(summary_table)
```

---

## Complete Workflow Script

Here's the full workflow in a single script:

```r
# v0.3.0 Quickstart - Complete Workflow
library(nemeton)
library(sf)
library(terra)
library(ggplot2)

# 1. Load data
data(massif_demo_units)
dem <- rast(system.file("extdata/massif_demo/dem.tif", package = "nemeton"))

# 2. Calculate all indicators
units <- massif_demo_units %>%
  # Biodiversity
  indicator_biodiversity_protection(source = "wfs") %>%
  indicator_biodiversity_structure(strata_field = "strata", age_field = "age") %>%
  indicator_biodiversity_connectivity(corridors = corridors) %>%
  # Risk
  indicator_risk_fire(dem = dem, species_field = "species") %>%
  indicator_risk_storm(dem = dem, height_field = "height") %>%
  indicator_risk_drought(twi_field = "W3", species_field = "species") %>%
  # Temporal
  indicator_temporal_age(age_field = "age") %>%
  indicator_temporal_change(lc_1990, lc_2020, years_elapsed = 30) %>%
  # Air
  indicator_air_coverage(land_cover, buffer_radius = 1000) %>%
  indicator_air_quality(roads = roads, urban = urban, method = "proxy")

# 3. Normalize and aggregate
units <- units %>%
  normalize_indicators(indicators = c("B1", "B2", "B3", "R1", "R2", "R3",
                                       "T1", "T2", "A1", "A2")) %>%
  create_family_index(family_codes = c("B", "R", "T", "A"))

# 4. Visualize
nemeton_radar(units, families = c("C", "B", "W", "A", "F", "L", "T", "R"),
              parcel_ids = 1:5)

# 5. Export
sf::st_write(units, "results.gpkg")
```

---

## Troubleshooting

### Common Issues

**1. WFS fetch fails (B1)**:
```r
# Solution: Use local shapefiles
protected_areas <- sf::st_read("protected_areas.shp")
units <- indicator_biodiversity_protection(units, protected_areas = protected_areas, source = "local")
```

**2. CRS mismatch**:
```r
# Solution: Enable preprocessing
units <- indicator_biodiversity_protection(units, preprocess = TRUE)
```

**3. Missing structural data (B2)**:
```r
# Solution: Use height CV fallback
units <- indicator_biodiversity_structure(units, use_height_cv = TRUE)
```

**4. Land cover rasters too large (T2)**:
```r
# Solution: Pre-crop to study area
lc_cropped <- terra::crop(lc_1990, sf::st_bbox(units))
```

---

## Next Steps

- **Read vignette**: `vignette("biodiversity-resilience", package = "nemeton")`
- **Customize weights**: Adjust family composite weights based on management priorities
- **Temporal analysis**: Use `nemeton_temporal()` to compare multiple time periods
- **Multi-criteria optimization**: Combine indicators to identify Pareto-optimal parcels

---

## Resources

- **Data sources**: See research.md for INPN, IGN, Corine Land Cover, WorldClim links
- **Function reference**: `?indicator_biodiversity_protection` (and other functions)
- **Package site**: https://pobsteta.github.io/nemeton/ (pkgdown)
- **Issues**: https://github.com/pobsteta/nemeton/issues

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Tested with**: nemeton v0.3.0, R 4.5.2
