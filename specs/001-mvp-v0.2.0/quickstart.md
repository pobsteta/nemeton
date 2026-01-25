# Quickstart Guide: MVP v0.2.0 - Temporal & Multi-Family Indicators

**Feature**: MVP v0.2.0 - Temporal & Spatial Indicators Extension
**Branch**: 001-mvp-v0.2.0
**Estimated Time**: 5-10 minutes
**Prerequisites**: nemeton v0.2.0 installed, basic R knowledge

---

## Installation

```r
# Install from GitHub (once v0.2.0 is released)
remotes::install_github("pobsteta/nemeton@v0.2.0")

# Or install development version from branch
remotes::install_github("pobsteta/nemeton", ref = "001-mvp-v0.2.0")

# Load package
library(nemeton)
library(sf)
library(ggplot2)
```

---

## 1. Basic Multi-Family Indicator Workflow (3 minutes)

### 1.1 Load Demo Data & Compute New Indicators

```r
# Load example dataset (20 forest parcels)
data(massif_demo_units)

# Load spatial layers (rasters + vectors)
layers <- massif_demo_layers()

# Compute all v0.2.0 indicators (C, W, F, L families)
results <- nemeton_compute(
  units = massif_demo_units,
  layers = layers,
  indicators = c("C1", "C2", "W1", "W2", "W3", "F1", "F2", "L1", "L2"),
  forest_values = c(1, 2, 3)  # Landcover codes for forest
)

# View results
print(results)
# nemeton_units object
#   20 parcels (136 ha)
#   9 indicators: C1, C2, W1, W2, W3, F1, F2, L1, L2
```

**What's happening**:
- **C1**: Biomass calculated via allometric models (if BD Forêt v2 available, else fallback)
- **C2**: NDVI mean extracted from raster (optional trend if multi-date)
- **W1**: Stream network density (km/ha)
- **W2**: Wetland coverage (%)
- **W3**: Topographic Wetness Index (TWI) from DEM
- **F1**: Soil fertility class (if BD Sol available)
- **F2**: Erosion risk (slope × landcover)
- **L1**: Landscape fragmentation (patch count)
- **L2**: Edge-to-area ratio

---

### 1.2 Normalize & Create Family Scores

```r
# Normalize all indicators to 0-100 scale
normalized <- normalize_indicators(
  results,
  method = "minmax"  # or "zscore", "quantile"
)

# Create family composite indices
normalized <- create_family_index(normalized, family = "carbon")
normalized <- create_family_index(normalized, family = "water")
normalized <- create_family_index(normalized, family = "soil")
normalized <- create_family_index(normalized, family = "landscape")

# View family scores
summary(normalized[, c("score_carbon", "score_water", "score_soil", "score_landscape")])
```

**Output**:
```
    score_carbon   score_water   score_soil    score_landscape
Min.   :  23.5   Min.   :  45  Min.   :  12   Min.   :  18
Mean   :  62.3   Mean   :  68  Mean   :  54   Mean   :  61
Max.   :  89.1   Max.   :  91  Max.   :  82   Max.   :  87
```

---

### 1.3 Visualize Multi-Family Radar

```r
# Radar chart for specific parcel
nemeton_radar(
  normalized,
  unit_id = "P01",
  families = TRUE,  # Use family scores
  title = "Profil Écosystémique - Parcelle P01"
)

# Average radar across all units
nemeton_radar(
  normalized,
  families = TRUE,
  title = "Profil Moyen du Massif"
)
```

**Expected Output**: 4-axis radar chart showing Carbon, Water, Soil, Landscape scores (0-100).

---

## 2. Temporal Analysis Workflow (5 minutes)

### 2.1 Create Multi-Period Dataset

```r
# Load demo temporal data (if available)
data(massif_demo_temporal)

# Or create manually from two periods
# Simulate 2015 baseline
results_2015 <- nemeton_compute(
  massif_demo_units,
  layers_2015,  # Historical rasters
  indicators = c("C1", "W3", "F2")
)

# Simulate 2020 current state
results_2020 <- nemeton_compute(
  massif_demo_units,
  layers_2020,  # Current rasters
  indicators = c("C1", "W3", "F2")
)

# Create temporal dataset
temporal <- nemeton_temporal(
  periods = list("2015" = results_2015, "2020" = results_2020),
  dates = c("2015-01-01", "2020-01-01"),
  labels = c("Baseline", "Current")
)

print(temporal)
# nemeton_temporal object
#   2 periods: 2015 (Baseline), 2020 (Current)
#   20 units tracked across periods
#   3 indicators: C1, W3, F2
```

---

### 2.2 Calculate Change Rates

```r
# Calculate annual change rates
rates <- calculate_change_rate(
  temporal,
  indicators = c("C1", "W3", "F2"),
  type = "both"  # absolute + relative
)

# View change rates
summary(rates[, c("C1_rate_abs", "C1_rate_rel")])
#   C1_rate_abs (tC/ha/year)  C1_rate_rel (%/year)
#   Min.   : -2.3              Min.   : -1.8
#   Mean   :  4.1              Mean   :  3.2
#   Max.   : 12.7              Max.   :  9.5

# Identify parcels with high carbon gain
high_carbon <- rates[rates$C1_rate_abs > 5, ]
nrow(high_carbon)  # 8 parcels gaining > 5 tC/ha/year
```

---

### 2.3 Visualize Temporal Trends

```r
# Time-series line plot for carbon
plot_temporal_trends(
  temporal,
  indicator = "C1",
  units = c("P01", "P05", "P10"),  # Highlight specific parcels
  title = "Évolution du Stock de Carbone (2015-2020)"
)

# Heatmap of change rates
plot_change_heatmap(
  rates,
  indicators = c("C1", "W3", "F2"),
  diverging = TRUE  # Green=gain, Red=loss
)

# Before/after comparison map
plot_comparison_map(
  results_2015,
  results_2020,
  indicator = "C1",
  labels = c("2015 Baseline", "2020 Current")
)
```

---

## 3. Advanced Example: Intervention Impact Assessment (8 minutes)

### Scenario: Evaluate effect of selective thinning in 2017

```r
# Load 3-period dataset (2015, 2020, 2025)
data(massif_demo_intervention)

# Flag intervention date
temporal$metadata$interventions <- data.frame(
  date = as.Date("2017-06-15"),
  type = "selective_thinning",
  units_affected = "P01,P03,P05",
  intensity = "30%"
)

# Calculate change rates for pre- and post-intervention periods
rates_pre <- calculate_change_rate(
  temporal,
  period_start = "2015",
  period_end = "2020",
  indicators = "C1"
)

rates_post <- calculate_change_rate(
  temporal,
  period_start = "2020",
  period_end = "2025",
  indicators = "C1"
)

# Compare carbon gain before vs. after thinning
comparison <- data.frame(
  unit_id = rates_pre$parcel_id,
  carbon_gain_pre = rates_pre$C1_rate_abs,
  carbon_gain_post = rates_post$C1_rate_abs,
  intervention = rates_pre$parcel_id %in% c("P01", "P03", "P05")
)

# Statistical test
t.test(carbon_gain_post ~ intervention, data = comparison)
# Result: Intervention parcels show 2.1 tC/ha/year higher gain (p < 0.05)
```

---

## 4. Family-Specific Analyses

### 4.1 Water Regulation Hotspots

```r
# Identify high water regulation zones
water_scores <- normalized[, c("W1_norm", "W2_norm", "W3_norm", "score_water")]

# Parcels with top 25% water score
water_hotspots <- normalized[normalized$score_water > quantile(normalized$score_water, 0.75), ]

# Visualize on map
plot_indicators_map(
  normalized,
  indicators = "score_water",
  palette = "Blues",
  title = "Zones Prioritaires pour la Régulation Hydrique",
  breaks = c(0, 50, 75, 90, 100),
  labels = c("Faible", "Moyen", "Élevé", "Très élevé")
)
```

---

### 4.2 Erosion Risk Assessment

```r
# Filter high erosion risk parcels
high_erosion <- results[results$F2 > 70, ]  # Erosion risk > 70/100

# Cross with slope data
high_erosion$slope <- terra::terrain(layers$rasters$dem$object, "slope") |>
  exactextractr::exact_extract(high_erosion, "mean")

# Recommendations
high_erosion$recommendation <- ifelse(
  high_erosion$slope > 30,
  "Maintenir couvert forestier dense",
  "Sylviculture douce possible"
)

print(high_erosion[, c("parcel_id", "F2", "slope", "recommendation")])
```

---

## 5. Exporting Results

### 5.1 Save Spatial Data

```r
# Export to GeoPackage (QGIS/ArcGIS compatible)
sf::st_write(
  normalized,
  "results_v0.2.0.gpkg",
  layer = "indicators_normalized",
  delete_dsn = TRUE
)

# Export change rates
sf::st_write(
  rates,
  "change_rates_2015_2020.gpkg",
  delete_dsn = TRUE
)
```

---

### 5.2 Generate Summary Report

```r
# Create summary table
summary_table <- data.frame(
  Family = c("Carbon", "Water", "Soil", "Landscape"),
  Indicator_Count = c(2, 3, 2, 2),
  Mean_Score = c(
    mean(normalized$score_carbon, na.rm = TRUE),
    mean(normalized$score_water, na.rm = TRUE),
    mean(normalized$score_soil, na.rm = TRUE),
    mean(normalized$score_landscape, na.rm = TRUE)
  ),
  Parcels_High = c(
    sum(normalized$score_carbon > 75, na.rm = TRUE),
    sum(normalized$score_water > 75, na.rm = TRUE),
    sum(normalized$score_soil > 75, na.rm = TRUE),
    sum(normalized$score_landscape > 75, na.rm = TRUE)
  )
)

print(summary_table)
#   Family     Indicator_Count  Mean_Score  Parcels_High
#   Carbon              2          62.3          5
#   Water               3          68.1          8
#   Soil                2          54.2          3
#   Landscape           2          61.0          4

# Export to CSV
write.csv(summary_table, "summary_v0.2.0.csv", row.names = FALSE)
```

---

## Troubleshooting

### Issue: Missing BD Forêt data → C1 returns NA

**Solution**: Provide species/age/density as columns in `massif_demo_units`:

```r
massif_demo_units$species <- "Quercus"  # or read from BD Forêt
massif_demo_units$age <- 80
massif_demo_units$density <- 0.7

results <- nemeton_compute(massif_demo_units, layers, indicators = "C1")
# → C1 now calculated via allometric model
```

---

### Issue: TWI calculation slow or fails

**Solution**: Check whitebox installation or use terra fallback:

```r
# Install whitebox (optional)
install.packages("whitebox")
whitebox::wbt_init()

# Or force terra fallback
results <- nemeton_compute(
  massif_demo_units, layers,
  indicators = "W3",
  twi_method = "d8"  # Force terra D8 algorithm
)
```

---

### Issue: Temporal alignment errors (units mismatch)

**Solution**: Ensure consistent unit IDs across periods:

```r
# Check IDs
unique(results_2015$parcel_id)
unique(results_2020$parcel_id)

# If IDs differ, standardize:
results_2020$parcel_id <- results_2015$parcel_id[match(
  results_2020$geo_parcelle,
  results_2015$geo_parcelle
)]

# Retry temporal creation
temporal <- nemeton_temporal(
  list("2015" = results_2015, "2020" = results_2020),
  id_column = "parcel_id"  # Explicit ID column
)
```

---

## Next Steps

**Explore Vignettes**:
```r
browseVignettes("nemeton")
# → temporal-analysis: Full multi-period workflow
# → indicator-families: Deep dive into 12-family framework
# → getting-started: Basic v0.1.0 workflow (still valid)
```

**Help & Documentation**:
```r
?nemeton_temporal
?create_family_index
?plot_temporal_trends

# See all new functions
help(package = "nemeton")
```

**Report Issues**:
- GitHub: https://github.com/pobsteta/nemeton/issues
- Tag with `v0.2.0` label

---

## Complete 5-Line Example

```r
library(nemeton)
data(massif_demo_units); layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1,2,3))
normalized <- normalize_indicators(results) |> create_family_index("carbon") |> create_family_index("water")
nemeton_radar(normalized, unit_id = "P01", families = TRUE, title = "Parcelle P01")
```

**Expected Runtime**: < 30 seconds

**Expected Output**: 4-axis radar chart showing carbon, water, soil, landscape scores for parcel P01.

---

**Quickstart Complete!** 🎉

For production workflows, see [indicator-families.Rmd](../vignettes/indicator-families.Rmd) vignette.
