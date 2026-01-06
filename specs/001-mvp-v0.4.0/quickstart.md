# Quickstart Guide: Complete 12-Family Ecosystem Services Workflow

**Feature**: MVP v0.4.0 - Complete 12-Family Referential
**Audience**: Forest managers, ecologists, planners using nemeton for the first time
**Estimated Time**: 15-20 minutes
**Prerequisites**: R ≥4.0.0, nemeton package installed

---

## Overview

This guide demonstrates the complete nemeton workflow for assessing ecosystem services across all 12 indicator families:

- **C**: Carbon & Vitality
- **B**: Biodiversity
- **W**: Water
- **A**: Air & Microclimate
- **F**: Soil Fertility
- **L**: Landscape
- **T**: Temporal Dynamics
- **R**: Risk & Resilience
- **S**: Social & Recreational (NEW in v0.4.0)
- **P**: Productive & Economic (NEW in v0.4.0)
- **E**: Energy & Climate (NEW in v0.4.0)
- **N**: Naturalness & Wilderness (NEW in v0.4.0)

**Learning Objectives**:
1. Calculate all 20 indicators (C1-C2, B1-B3, W1-W3, A1-A2, F1-F2, L1-L2, T1-T2, R1-R3, S1-S3, P1-P3, E1-E2, N1-N3)
2. Normalize and create 12 family composite indices
3. Visualize with 12-axis radar plots
4. Perform cross-family correlation analysis
5. Identify multi-criteria hotspots
6. Detect Pareto-optimal parcels
7. Cluster parcels into management zones
8. Visualize trade-offs between competing objectives

---

## Step 1: Setup and Data Loading (2 minutes)

### Load the Package

```r
# Install if not already installed
# install.packages("nemeton")  # From CRAN after v0.4.0 release
# devtools::install_github("yourorg/nemeton")  # Development version

# Load package and dependencies
library(nemeton)
library(sf)
library(dplyr)
library(ggplot2)
```

### Load Demo Dataset

```r
# Load extended demo dataset with 20 forest parcels
data(massif_demo_units_extended)

# Inspect structure
class(massif_demo_units_extended)
#> [1] "sf" "data.frame"

dim(massif_demo_units_extended)
#> [1] 20  55  # 20 parcels, ~55 columns (geometry + indicators + families + metadata)

# View first few rows
head(massif_demo_units_extended)

# Check existing indicators (v0.1.0-v0.3.0 families already calculated)
names(massif_demo_units_extended)[grepl("^(C|B|W|A|F|L|T|R)\\d", names(massif_demo_units_extended))]
#> [1] "C1" "C2" "B1" "B2" "B3" "W1" "W2" "W3" "A1" "A2" "F1" "F2" "L1" "L2" "T1" "T2" "R1" "R2" "R3"

# For this quickstart, we'll calculate the 4 NEW families (S, P, E, N)
```

**Note**: The demo dataset is synthetic data for learning purposes. For real-world analysis, you'll load your own spatial data (GeoPackage, shapefile, etc.) with forest inventory attributes.

---

## Step 2: Calculate Social Indicators (S Family) (3 minutes)

### S1: Trail Density

```r
# Calculate trail density from OpenStreetMap
# (Demo: using pre-loaded trails to avoid OSM query delay)
demo_trails <- st_read(system.file("extdata", "trails_demo.gpkg", package = "nemeton"))

parcels <- indicator_social_trails(
  units = massif_demo_units_extended,
  trails = demo_trails,
  method = "local"
)

summary(parcels$S1)
#> Min: 0.0, Median: 0.82, Max: 4.15 km/ha
```

### S2: Accessibility Score

```r
# Calculate multimodal accessibility
# (Demo: using local infrastructure data)
parcels <- indicator_social_accessibility(
  units = parcels,
  method = "osm"  # In practice, OSM query or local data
)

summary(parcels$S2)
#> Min: 12.3, Median: 58.7, Max: 94.2 (0-100 score)
```

### S3: Population Proximity

```r
# Load population grid (INSEE Carroyage or custom)
insee_pop <- st_read(system.file("extdata", "insee_pop_demo.gpkg", package = "nemeton"))

parcels <- indicator_social_proximity(
  units = parcels,
  population = insee_pop,
  method = "insee",
  radii = c(5000, 10000, 20000)
)

summary(parcels$S3_5km)
#> Min: 234, Median: 12458, Max: 87342 inhabitants
```

**Check**: Parcels now have S1, S2, S3_5km, S3_10km, S3_20km columns.

---

## Step 3: Calculate Productive Indicators (P Family) (2 minutes)

### P1: Standing Volume

```r
# Requires species, DBH, height in dataset
# Demo dataset has these fields: dominant_species, mean_dbh, mean_height

parcels <- indicator_productive_volume(
  units = parcels,
  species_field = "dominant_species",
  dbh_field = "mean_dbh",
  height_field = "mean_height",
  fallback = "genus"
)

summary(parcels$P1)
#> Min: 52.3, Median: 187.9, Max: 438.5 m³/ha
```

### P2: Site Productivity

```r
# Requires soil fertility (F1 from v0.2.0) and species
parcels <- indicator_productive_station(
  units = parcels,
  species_field = "dominant_species",
  fertility_field = "F1"
)

summary(parcels$P2)
#> Min: 28.4, Median: 62.7, Max: 91.3 (0-100 index)
```

### P3: Wood Quality

```r
# Requires form, DBH, defects assessment
# Demo: synthetic quality attributes
parcels <- indicator_productive_quality(
  units = parcels,
  species_field = "dominant_species",
  form_field = "stem_form",
  dbh_field = "mean_dbh",
  defects_field = "defect_level"
)

summary(parcels$P3)
#> Min: 18.5, Median: 54.2, Max: 88.7 (0-100 quality score)
```

---

## Step 4: Calculate Energy Indicators (E Family) (1 minute)

### E1: Fuelwood Potential

```r
parcels <- indicator_energy_fuelwood(
  units = parcels,
  volume_field = "P1",  # Uses standing volume from P1
  harvest_rate = 0.02,  # 2% annual harvest
  species_field = "dominant_species"
)

summary(parcels$E1)
#> Min: 0.54, Median: 1.89, Max: 5.12 t DM/year
```

### E2: Carbon Avoidance

```r
parcels <- indicator_energy_avoidance(
  units = parcels,
  fuelwood_field = "E1",
  timber_field = "P1",
  substitution_scenario = "energy+material",
  fossil_fuel = "heating_oil"
)

summary(parcels$E2)
#> Min: 1.12, Median: 3.78, Max: 14.23 tCO2eq/year
```

---

## Step 5: Calculate Naturalness Indicators (N Family) (3 minutes)

### N1: Infrastructure Distance

```r
# Using OpenStreetMap infrastructure (or local data)
parcels <- indicator_naturalness_distance(
  units = parcels,
  method = "osm",
  infra_types = c("roads", "buildings", "power")
)

summary(parcels$N1)
#> Min: 0, Median: 542, Max: 9847 meters
```

### N2: Forest Continuity

```r
# Using Corine Land Cover or local forest layer
corine_lc <- rast(system.file("extdata", "corine_demo.tif", package = "nemeton"))

parcels <- indicator_naturalness_continuity(
  units = parcels,
  land_cover = corine_lc,
  method = "corine",
  connectivity_distance = 100,
  forest_classes = c("311", "312", "313")
)

summary(parcels$N2)
#> Min: 15.7, Median: 287.4, Max: 6234.8 hectares
```

### N3: Composite Naturalness

```r
# Combines N1, N2 with existing T1 (ancientness) and B1 (protection)
parcels <- indicator_naturalness_composite(
  units = parcels,
  n1_field = "N1",
  n2_field = "N2",
  t1_field = "T1",  # From v0.3.0
  b1_field = "B1",  # From v0.3.0
  aggregation = "multiplicative"
)

summary(parcels$N3)
#> Min: 12.4, Median: 48.6, Max: 94.7 (0-100 composite)
```

**Check**: All 20 indicators now calculated (C1-C2, B1-B3, W1-W3, A1-A2, F1-F2, L1-L2, T1-T2, R1-R3, S1-S3, P1-P3, E1-E2, N1-N3).

---

## Step 6: Normalize and Create Family Composites (1 minute)

### Normalize All Indicators

```r
# Normalize all 20 indicators to 0-100 scale
parcels_norm <- normalize_indicators(
  parcels,
  indicators = c(
    # Existing families (v0.1.0-v0.3.0)
    "C1", "C2", "B1", "B2", "B3", "W1", "W2", "W3", "A1", "A2",
    "F1", "F2", "L1", "L2", "T1", "T2", "R1", "R2", "R3",
    # New families (v0.4.0)
    "S1", "S2", "S3_5km", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"
  ),
  methods = c(
    # Specify normalization method per indicator
    # "linear" = min-max, "log" = log transform, "inverse" = higher value worse
    rep("linear", 21), "log", rep("linear", 9)  # Example: W3 uses log
  )
)

# Check normalized values
summary(parcels_norm$S1_norm)
#> Min: 0.0, Median: 48.7, Max: 100.0
```

### Create Family Composite Indices

```r
# Create composites for all 12 families
families_to_create <- c("S", "P", "E", "N")  # New families (C-R already exist)

for (family in families_to_create) {
  if (family == "S") {
    parcels_norm <- create_family_index(
      parcels_norm,
      family = "S",
      indicators = c("S1_norm", "S2_norm", "S3_5km_norm"),
      weights = c(0.4, 0.3, 0.3)
    )
  } else if (family == "P") {
    parcels_norm <- create_family_index(
      parcels_norm,
      family = "P",
      indicators = c("P1_norm", "P2_norm", "P3_norm"),
      weights = c(0.4, 0.3, 0.3)
    )
  } else if (family == "E") {
    parcels_norm <- create_family_index(
      parcels_norm,
      family = "E",
      indicators = c("E1_norm", "E2_norm"),
      weights = c(0.5, 0.5)
    )
  } else if (family == "N") {
    parcels_norm <- create_family_index(
      parcels_norm,
      family = "N",
      indicators = c("N1_norm", "N2_norm", "N3_norm"),
      weights = c(0.25, 0.25, 0.5)
    )
  }
}

# Check: All 12 family_* columns present
names(parcels_norm)[grepl("^family_", names(parcels_norm))]
#> [1] "family_C" "family_B" "family_W" "family_A" "family_F" "family_L"
#> [7] "family_T" "family_R" "family_S" "family_P" "family_E" "family_N"
```

---

## Step 7: Visualize with 12-Axis Radar Plot (1 minute)

```r
# Select a parcel to visualize
parcel_5 <- parcels_norm[5, ]

# Extract family scores
family_scores <- parcel_5 |>
  st_drop_geometry() |>
  select(starts_with("family_")) |>
  as.numeric()

names(family_scores) <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")

# Generate 12-axis radar plot
nemeton_radar(
  family_scores,
  title = paste("Ecosystem Services Profile - Parcel", parcel_5$parcel_id),
  max_value = 100
)

# Compare two parcels
parcel_10 <- parcels_norm[10, ]
family_scores_10 <- parcel_10 |>
  st_drop_geometry() |>
  select(starts_with("family_")) |>
  as.numeric()

nemeton_radar(
  data = rbind(family_scores, family_scores_10),
  title = "Comparison: Parcel 5 vs Parcel 10",
  labels = c("Parcel 5", "Parcel 10")
)
```

**Interpretation**: The radar plot shows the parcel's performance across all 12 ecosystem service dimensions. Larger areas indicate higher overall service provision.

---

## Step 8: Cross-Family Correlation Analysis (1 minute)

```r
# Compute 12×12 correlation matrix
cor_matrix <- compute_family_correlations(
  parcels_norm,
  families = c("family_C", "family_B", "family_W", "family_A", "family_F", "family_L",
               "family_T", "family_R", "family_S", "family_P", "family_E", "family_N")
)

# Visualize correlation matrix
plot_correlation_matrix(
  cor_matrix,
  title = "12-Family Correlation Matrix"
)

# Identify positive synergies (corr > 0.5)
cor_matrix[cor_matrix > 0.5 & cor_matrix < 1.0]
#> family_C ~ family_B: 0.62 (carbon sequestration co-benefits with biodiversity)
#> family_W ~ family_N: 0.58 (water regulation in natural areas)

# Identify trade-offs (corr < -0.3)
cor_matrix[cor_matrix < -0.3]
#> family_P ~ family_N: -0.47 (production vs naturalness trade-off)
#> family_L ~ family_B: -0.35 (landscape fragmentation vs biodiversity)
```

**Interpretation**: Correlation analysis reveals synergies (where improving one service also improves another) and trade-offs (where one service comes at the expense of another). This informs management strategies.

---

## Step 9: Identify Multi-Criteria Hotspots (1 minute)

```r
# Identify parcels excelling across multiple dimensions
hotspots <- identify_hotspots(
  parcels_norm,
  families = c("family_C", "family_B", "family_W", "family_A", "family_F", "family_L",
               "family_T", "family_R", "family_S", "family_P", "family_E", "family_N"),
  threshold = 70,  # Must score ≥70 on multiple families
  min_families = 8  # Must excel on ≥8 of 12 families
)

# View hotspot parcels
hotspots[hotspots$is_hotspot == TRUE, c("parcel_id", "name", "hotspot_count")]
#>   parcel_id                name hotspot_count
#> 3       003   Forêt de Bellême            10
#> 7       007 Massif de Rambouillet         9
#> 12      012  Bois de Vincennes            8

# Map hotspots
ggplot() +
  geom_sf(data = parcels_norm, aes(fill = is_hotspot), color = "white", size = 0.3) +
  scale_fill_manual(values = c("FALSE" = "lightgray", "TRUE" = "darkgreen")) +
  labs(title = "Multi-Criteria Ecosystem Services Hotspots",
       fill = "Hotspot") +
  theme_minimal()
```

**Interpretation**: Hotspots are high-value parcels providing exceptional performance across many ecosystem service dimensions. Prioritize these for conservation.

---

## Step 10: Pareto Optimality Analysis (2 minutes)

```r
# Identify Pareto-optimal parcels (non-dominated across all 12 families)
parcels_pareto <- identify_pareto_optimal(
  parcels_norm,
  families = c("family_C", "family_B", "family_W", "family_A", "family_F", "family_L",
               "family_T", "family_R", "family_S", "family_P", "family_E", "family_N")
)

# Count Pareto-optimal parcels
table(parcels_pareto$is_pareto_optimal)
#> FALSE  TRUE
#>    14     6

# View Pareto set
parcels_pareto[parcels_pareto$is_pareto_optimal == TRUE, c("parcel_id", "name")]
#>   parcel_id                name
#> 2       002      Forêt d'Orient
#> 5       005 Parc de la Vanoise
#> 8       008  Forêt de Fontainebleau
#> 11      011 Réserve de Chambord
#> 15      015 Massif des Vosges
#> 18      018 Forêt de Compiègne

# Focus on Production vs Biodiversity trade-off
parcels_pareto_pb <- identify_pareto_optimal(
  parcels_norm,
  families = c("family_P", "family_B"),
  objectives = c("maximize", "maximize")
)

table(parcels_pareto_pb$is_pareto_optimal)
#> FALSE  TRUE
#>    12     8
```

**Interpretation**: Pareto-optimal parcels represent the best possible trade-offs. No other parcel is strictly better across all dimensions. These define the "efficient frontier" for management decisions.

---

## Step 11: Cluster Analysis for Management Zones (2 minutes)

```r
# Cluster parcels into 4 management zones based on ecosystem service profiles
parcels_clustered <- cluster_parcels(
  parcels_norm,
  families = c("family_C", "family_B", "family_W", "family_A", "family_F", "family_L",
               "family_T", "family_R", "family_S", "family_P", "family_E", "family_N"),
  k = 4,
  method = "kmeans",
  auto_k = "none"  # Manual k=4, or use "silhouette" for auto-detection
)

# View cluster assignments
table(parcels_clustered$cluster_id)
#> 1  2  3  4
#> 6  5  4  5

# Extract cluster profiles (mean family scores)
cluster_profile <- attr(parcels_clustered, "cluster_analysis")$profile
print(cluster_profile)
#>   cluster_id family_C_mean family_B_mean ... family_N_mean n_parcels
#> 1          1          68.3          45.2 ...          32.1         6
#> 2          2          42.7          82.5 ...          67.4         5
#> 3          3          85.1          31.8 ...          18.9         4
#> 4          4          56.4          58.7 ...          52.3         5

# Visualize cluster profiles with radar plots
par(mfrow = c(2, 2))
for (i in 1:4) {
  profile_i <- cluster_profile[i, grep("family_.*_mean", names(cluster_profile))]
  nemeton_radar(
    as.numeric(profile_i),
    title = paste("Cluster", i, "Profile (n =", cluster_profile$n_parcels[i], ")"),
    max_value = 100
  )
}

# Interpret clusters (example)
# Cluster 1: Production-focused (high P, low N)
# Cluster 2: Conservation-focused (high B, N, low P)
# Cluster 3: High carbon/energy, low biodiversity (intensive forestry)
# Cluster 4: Balanced multi-objective (moderate on all)

# Map clusters
ggplot() +
  geom_sf(data = parcels_clustered, aes(fill = factor(cluster_id)), color = "white") +
  scale_fill_viridis_d(option = "plasma") +
  labs(title = "Management Zones (K-means Clustering)",
       fill = "Cluster") +
  theme_minimal()
```

**Interpretation**: Clustering groups parcels with similar ecosystem service profiles into management zones. Each cluster suggests a different management strategy (e.g., production, conservation, multi-objective).

---

## Step 12: Trade-off Visualization (2 minutes)

```r
# Visualize Production vs Biodiversity trade-off
plot_tradeoff(
  parcels_clustered,
  family_x = "family_P",
  family_y = "family_B",
  show_pareto = TRUE,
  title = "Production-Biodiversity Trade-off",
  add_labels = TRUE,
  label_field = "name"
)

# Visualize Energy vs Naturalness trade-off
plot_tradeoff(
  parcels_clustered,
  family_x = "family_E",
  family_y = "family_N",
  show_pareto = TRUE,
  title = "Energy-Naturalness Trade-off"
)

# Multi-panel trade-off matrix (select 4 key families)
library(patchwork)

p1 <- plot_tradeoff(parcels_clustered, "family_P", "family_B", point_size = 2)
p2 <- plot_tradeoff(parcels_clustered, "family_P", "family_N", point_size = 2)
p3 <- plot_tradeoff(parcels_clustered, "family_B", "family_N", point_size = 2)
p4 <- plot_tradeoff(parcels_clustered, "family_E", "family_N", point_size = 2)

(p1 + p2) / (p3 + p4) +
  plot_annotation(title = "Key Ecosystem Services Trade-offs")
```

**Interpretation**: Trade-off plots show the relationship between competing objectives. The Pareto frontier (red line) represents the best achievable balance. Points above/right of the frontier are win-win scenarios; points below/left are suboptimal.

---

## Step 13: Export Results (1 minute)

```r
# Save enriched spatial data
st_write(
  parcels_clustered,
  "results/parcels_12families_clustered.gpkg",
  delete_dsn = TRUE
)

# Export cluster profiles to CSV
write.csv(
  cluster_profile,
  "results/cluster_profiles.csv",
  row.names = FALSE
)

# Export Pareto set
pareto_set <- parcels_clustered[parcels_clustered$is_pareto_optimal == TRUE, ]
st_write(
  pareto_set,
  "results/pareto_optimal_parcels.gpkg",
  delete_dsn = TRUE
)

# Export correlation matrix
write.csv(
  cor_matrix,
  "results/family_correlation_matrix.csv"
)
```

---

## Summary

**What You Accomplished**:

1. ✅ Calculated all 20 ecosystem service indicators across 12 families
2. ✅ Normalized indicators and created family composite indices
3. ✅ Visualized parcel profiles with 12-axis radar plots
4. ✅ Analyzed cross-family correlations to identify synergies and trade-offs
5. ✅ Identified multi-criteria hotspots for conservation prioritization
6. ✅ Detected Pareto-optimal parcels defining the efficiency frontier
7. ✅ Clustered parcels into management zones with distinct service profiles
8. ✅ Visualized key trade-offs (production vs biodiversity, energy vs naturalness)
9. ✅ Exported results for further analysis and decision-making

**Next Steps**:

- **Customize weights**: Adjust family composite weights to reflect local priorities
- **Scenario analysis**: Test management scenarios by modifying indicator inputs
- **Expand analysis**: Apply to your own forest inventory data
- **Deep-dive vignettes**: See `vignette("complete-referential")` and `vignette("multi-criteria-optimization")` for advanced workflows
- **Custom indicators**: Extend the framework with your own indicators following the nemeton API conventions

**Support**:

- Documentation: `?indicator_social_trails`, `?cluster_parcels`, etc.
- Vignettes: `browseVignettes("nemeton")`
- Issues: https://github.com/yourorg/nemeton/issues
- Tutorials: https://nemeton-project.org/tutorials

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Feature**: MVP v0.4.0 - 12-Family Complete Referential
**Status**: Quickstart Guide Complete
