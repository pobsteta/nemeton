# Indicator Families Reference Guide

## Introduction

The `nemeton` package implements a **comprehensive multi-family
indicator framework** for forest ecosystem assessment, based on the
**Nemeton method** developed by *Vivre en Forêt*. This framework
organizes ecosystem services into **12 distinct families**, each
representing a key dimension of forest functioning.

### The 12 Families

| Code | Family           | Status_v0.2.0               |
|:-----|:-----------------|:----------------------------|
| C    | Carbon/Vitality  | ✅ Implemented (C1, C2)     |
| B    | Biodiversity     | ⏳ v0.3.0+                  |
| W    | Water            | ✅ Implemented (W1, W2, W3) |
| A    | Air/Microclimate | ⏳ v0.3.0+                  |
| F    | Soil Fertility   | ✅ Implemented (F1, F2)     |
| L    | Landscape        | ✅ Partial (L1, L2)         |
| T    | Time/Dynamics    | ⏳ v0.3.0+                  |
| R    | Resilience/Risks | ⏳ v0.3.0+                  |
| S    | Social/Uses      | ⏳ v0.4.0+                  |
| P    | Productive       | ⏳ v0.4.0+                  |
| E    | Energy/Climate   | ⏳ v0.4.0+                  |
| N    | Naturalness      | ⏳ v0.3.0+                  |

Overview of the 12 Indicator Families

**Version 0.2.0** implements **5 families** with **10 sub-indicators**,
providing a solid foundation for multi-dimensional ecosystem analysis.

## Installation

``` r
# Install from GitHub
remotes::install_github("pobsteta/nemeton")
```

``` r
library(nemeton)
library(ggplot2)
library(dplyr)
```

### Visual Overview: The 12-Family Framework

The radar chart below illustrates the complete multi-dimensional
framework, showing how all 12 families combine to provide a holistic
assessment of forest ecosystem services.

``` r
# Load demo data
data(massif_demo_units)

# Create sample family scores for demonstration (0-100 scale)
# In practice, these would be computed from real indicators
demo_unit <- massif_demo_units[1, ]

# Simulate family scores for all 12 families
# Higher values = better performance in that dimension
demo_unit$family_C <- 75  # Carbon/Vitality - Good carbon storage
demo_unit$family_B <- 65  # Biodiversity - Moderate species richness
demo_unit$family_W <- 82  # Water - Excellent water regulation
demo_unit$family_A <- 70  # Air/Microclimate - Good air quality
demo_unit$family_F <- 68  # Soil Fertility - Moderate fertility
demo_unit$family_L <- 55  # Landscape - Some fragmentation
demo_unit$family_T <- 78  # Time/Dynamics - Old-growth characteristics
demo_unit$family_R <- 60  # Resilience/Risks - Moderate climate risk
demo_unit$family_S <- 85  # Social/Uses - High recreational value
demo_unit$family_P <- 72  # Productive - Good timber potential
demo_unit$family_E <- 80  # Energy/Climate - Strong carbon sequestration
demo_unit$family_N <- 62  # Naturalness - Moderate naturalness

# Create 12-family radar chart
nemeton_radar(
  demo_unit,
  mode = "family",
  indicators = c("family_C", "family_B", "family_W", "family_A",
                 "family_F", "family_L", "family_T", "family_R",
                 "family_S", "family_P", "family_E", "family_N"),
  normalize = FALSE,  # Already on 0-100 scale
  title = "Complete 12-Family Ecosystem Profile",
  fill_color = "#2E7D32",
  fill_alpha = 0.25
)
```

![12-Family Radar Chart - Complete Nemeton
Framework](indicator-families_files/figure-html/unnamed-chunk-4-1.png)

12-Family Radar Chart - Complete Nemeton Framework

**Interpretation**: This example parcel shows:

- **Strengths** (\> 75): Social value (S), Water regulation (W),
  Energy/Climate (E), Time/Dynamics (T)
- **Good performance** (65-75): Carbon (C), Air (A), Productive (P),
  Biodiversity (B)
- **Areas for improvement** (\< 65): Naturalness (N), Resilience (R),
  Landscape (L)

The radar chart reveals the **multi-dimensional trade-offs** inherent in
forest management: high productivity (P) and social value (S) may come
at the expense of naturalness (N) and landscape integrity (L).

## Implemented Families (v0.2.0)

### Family C: Carbon & Vitality

The **Carbon family** quantifies carbon storage and vegetation vitality.

#### C1: Biomass Stock (indicator_carbon_biomass)

Estimates aboveground biomass using **allometric models** from BD Forêt
v2 data.

``` r
# Requires BD Forêt v2 with species, age, density
layers <- list(
  bd_foret = terra::vect("data/bd_foret_v2.gpkg")
)

carbon_biomass <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "C1",
  preprocess = TRUE
)

summary(carbon_biomass$C1)  # tC/ha
```

**Allometric Models**:

- **Quercus** (oak): Species-specific coefficients
- **Fagus** (beech): Species-specific coefficients
- **Pinus** (pine): Species-specific coefficients
- **Abies** (fir): Species-specific coefficients
- **Generic**: For other species

**Output**: Tonnes of carbon per hectare (tC/ha)

#### C2: Vegetation Vitality (indicator_carbon_ndvi)

Calculates mean NDVI (Normalized Difference Vegetation Index) from
Sentinel-2 imagery.

``` r
# Requires NDVI raster (Sentinel-2)
layers <- list(
  ndvi = terra::rast("data/sentinel2_ndvi.tif")
)

carbon_ndvi <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "C2"
)

summary(carbon_ndvi$C2)  # 0-1 scale
```

**Future Extension** (v0.3.0): 5-year NDVI trend analysis for vitality
dynamics.

------------------------------------------------------------------------

### Family W: Water Regulation

The **Water family** assesses the forest’s role in infiltration,
storage, and water quality.

#### W1: Hydrographic Network Density (indicator_water_network)

Measures river/stream length per hectare.

``` r
# Requires hydrographic network (SF linestring)
layers <- list(
  rivers = sf::st_read("data/hydrographic_network.gpkg")
)

water_network <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "W1"
)

summary(water_network$W1)  # km/ha
```

#### W2: Wetland Coverage (indicator_water_wetlands)

Percentage of parcel covered by wetlands or riparian zones.

``` r
# Requires wetland polygons (SF)
layers <- list(
  wetlands = sf::st_read("data/wetlands.gpkg")
)

water_wetlands <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "W2"
)

summary(water_wetlands$W2)  # % coverage
```

#### W3: Topographic Wetness Index (indicator_water_twi)

Calculates TWI from DEM using flow accumulation and slope.

``` r
# Requires DEM (terra raster)
layers <- list(
  dem = terra::rast("data/dem_25m.tif")
)

water_twi <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "W3"
)

summary(water_twi$W3)  # TWI index
```

**Note**: Uses `terra` D8 flow algorithm by default. Optional `whitebox`
support for D-infinity.

------------------------------------------------------------------------

### Family F: Soil Fertility

The **Soil family** evaluates soil health and erosion risk.

#### F1: Soil Fertility (indicator_soil_fertility)

Classifies soil fertility from BD Sol (French soil database) or
equivalent.

``` r
# Requires BD Sol raster with fertility classes
layers <- list(
  soil_fertility = terra::rast("data/bd_sol_fertility.tif")
)

soil_fertility <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "F1"
)

summary(soil_fertility$F1)  # 0-100 scale
```

**Classes**:

- High fertility (80-100)
- Medium fertility (40-80)
- Low fertility (0-40)

#### F2: Erosion Risk (indicator_soil_erosion)

Combines slope and vegetation cover to assess erosion vulnerability.

``` r
# Requires DEM and land cover raster
layers <- list(
  dem = terra::rast("data/dem_25m.tif"),
  landcover = terra::rast("data/landcover.tif")
)

soil_erosion <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "F2"
)

summary(soil_erosion$F2)  # Risk score (higher = more risk)
```

**Formula**: Erosion Risk = Slope (%) × (1 - Vegetation Cover)

------------------------------------------------------------------------

### Family L: Landscape Quality

The **Landscape family** quantifies spatial patterns and connectivity.

#### L1: Forest Fragmentation (indicator_landscape_fragmentation)

Counts forest patches and calculates mean patch size.

``` r
# Requires land cover raster
layers <- list(
  landcover = terra::rast("data/landcover.tif")
)

landscape_frag <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "L1",
  forest_values = c(1, 2, 3)  # Forest classes
)

summary(landscape_frag$L1)  # Patch count
```

#### L2: Edge-to-Area Ratio (indicator_landscape_edge)

Calculates forest edge density (m/ha).

``` r
landscape_edge <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "L2",
  forest_values = c(1, 2, 3)
)

summary(landscape_edge$L2)  # m/ha
```

**Interpretation**: Higher values indicate more fragmented landscapes.

------------------------------------------------------------------------

## Multi-Family Workflows

### Compute Multiple Families

``` r
# Load demo data and layers
data(massif_demo_units)
layers <- massif_demo_layers()

# Compute indicators from 4 families (C, W, F, L)
results <- nemeton_compute(
  massif_demo_units[1:10, ],
  layers,
  indicators = c("C1", "C2", "W1", "W2", "W3", "F1", "F2", "L1", "L2"),
  preprocess = TRUE
)

# Check results
names(results)
```

### Normalize by Family

Normalize indicators independently within each family:

``` r
# Family-aware normalization
normalized <- normalize_indicators(
  results,
  method = "minmax",
  by_family = TRUE  # Normalize C1/C2 together, W1/W2/W3 together, etc.
)

# All indicators now on 0-100 scale within families
summary(normalized$C1)
summary(normalized$W1)
```

### Create Family Indices

Aggregate indicators into family-level scores:

``` r
# Create family composite scores
family_scores <- create_family_index(
  normalized,
  method = "weighted",
  weights = list(
    C = c(C1 = 0.6, C2 = 0.4),      # Prioritize biomass
    W = c(W1 = 0.3, W2 = 0.3, W3 = 0.4),  # TWI most important
    F = c(F1 = 0.7, F2 = 0.3),      # Fertility > erosion
    L = c(L1 = 0.5, L2 = 0.5)       # Equal weights
  )
)

# Check family scores
names(family_scores)
# Contains: family_C, family_W, family_F, family_L + original indicators
```

**Aggregation Methods**:

- `method = "mean"`: Simple average
- `method = "weighted"`: Weighted average (custom weights)
- `method = "geometric"`: Geometric mean (penalizes low values)
- `method = "harmonic"`: Harmonic mean (emphasizes balance)

## Multi-Family Visualization

### Radar Plots with Family Scores

``` r
# Multi-family radar plot
nemeton_radar(
  family_scores,
  unit_id = 1,
  mode = "family",           # Use family scores
  title = "Parcel P001: Multi-Family Profile"
)
```

The radar plot displays **4 axes** (one per family: C, W, F, L), showing
the ecosystem service profile at a glance.

**Future** (v0.3.0+): Expand to **12 axes** as all families are
implemented.

### Compare Units

``` r
# Compare two parcels
p1 <- nemeton_radar(family_scores, unit_id = 1, mode = "family",
                    title = "Parcel P001")
p2 <- nemeton_radar(family_scores, unit_id = 5, mode = "family",
                    title = "Parcel P005")

# Display side by side
library(patchwork)
p1 + p2
```

## Complete Example Workflow

``` r
library(nemeton)

# ============================================================================
# STEP 1: Load Data
# ============================================================================

data(massif_demo_units)
layers <- massif_demo_layers()

# Select 10 parcels for analysis
units <- massif_demo_units[1:10, ]
units$parcel_id <- paste0("P", sprintf("%03d", 1:10))

# ============================================================================
# STEP 2: Compute Multi-Family Indicators
# ============================================================================

# Compute all available indicators (v0.2.0)
results <- nemeton_compute(
  units,
  layers,
  indicators = c("C1", "C2", "W1", "W2", "W3", "F1", "F2", "L1", "L2"),
  preprocess = TRUE
)

# ============================================================================
# STEP 3: Normalize by Family
# ============================================================================

normalized <- normalize_indicators(
  results,
  method = "minmax",
  by_family = TRUE
)

# ============================================================================
# STEP 4: Create Family Indices
# ============================================================================

family_scores <- create_family_index(
  normalized,
  method = "weighted",
  weights = list(
    C = c(C1 = 0.7, C2 = 0.3),
    W = c(W1 = 0.25, W2 = 0.25, W3 = 0.5),
    F = c(F1 = 0.6, F2 = 0.4),
    L = c(L1 = 0.5, L2 = 0.5)
  )
)

# ============================================================================
# STEP 5: Visualize Multi-Family Profiles
# ============================================================================

# Radar plot for parcel P001
nemeton_radar(
  family_scores,
  unit_id = "P001",
  mode = "family",
  title = "Multi-Family Ecosystem Profile - Parcel P001"
)

# ============================================================================
# STEP 6: Identify Strengths and Weaknesses
# ============================================================================

# Extract family scores
scores_table <- family_scores %>%
  sf::st_drop_geometry() %>%
  select(parcel_id, starts_with("family_"))

# Rank parcels by family
cat("\n=== Top Parcels by Family ===\n")

cat("\nCarbon (family_C):\n")
scores_table %>%
  arrange(desc(family_C)) %>%
  select(parcel_id, family_C) %>%
  head(3) %>%
  print()

cat("\nWater (family_W):\n")
scores_table %>%
  arrange(desc(family_W)) %>%
  select(parcel_id, family_W) %>%
  head(3) %>%
  print()

# ============================================================================
# STEP 7: Export Results
# ============================================================================

# Save family scores
sf::st_write(
  family_scores,
  "results/family_scores_2025.gpkg",
  delete_dsn = TRUE
)

# Export CSV table
write.csv(
  scores_table,
  "results/family_scores_2025.csv",
  row.names = FALSE
)
```

## Roadmap: Future Families

### v0.3.0 - Biodiversity & Risks Extension

**Family B - Biodiversity**:

- B1: Protected habitat presence
- B2: Structural diversity (age classes, layers)
- B3: Ecological connectivity

**Family R - Resilience/Risks**:

- R1: Fire risk (FWI, fuel load)
- R2: Storm risk (exposure, stand structure)
- R3: Drought risk (water balance, species)

**Family T - Time/Dynamics**:

- T1: Forest cover ancientness
- T2: Land use change analysis

**Family N - Naturalness**:

- N1: Distance to infrastructure
- N2: Continuous forest cover
- N3: Composite naturalness index

------------------------------------------------------------------------

### v0.4.0 - Socio-Economic Extension

**Family S - Social/Uses**:

- S1: Trail density
- S2: Accessibility (distance to roads)
- S3: Proximity to populations

**Family P - Productive/Heritage**:

- P1: Standing timber volume
- P2: Forest productivity
- P3: Timber vs fuelwood ratio

**Family A - Air/Microclimate**:

- A1: Forest cover (1 km buffer)
- A2: Air quality (ATMO data integration)

**Family E - Energy/Climate**:

- E1: Fuelwood potential
- E2: Carbon emission avoidance (substitution)

------------------------------------------------------------------------

### v0.5.0 - Complete Framework

- **12/12 families** implemented
- **36 sub-indicators**
- Shiny dashboard for interactive exploration
- Uncertainty analysis
- Multi-format export (PDF reports, GeoPackage, CSV)

## Reference Tables

### Indicator Naming Conventions

| Element           | Format          | Example                    |
|:------------------|:----------------|:---------------------------|
| Function Name     | indicator\_\_() | indicator_carbon_biomass() |
| Indicator Code    |                 | C1, W3, F2                 |
| Normalized Column | `_norm`         | C1_norm, W3_norm           |
| Family Score      | family\_        | family_C, family_W         |

Naming Conventions

### Family Letter Codes

| Code | English          | French              |
|:-----|:-----------------|:--------------------|
| C    | Carbon           | Carbone             |
| B    | Biodiversity     | Biodiversité        |
| W    | Water            | Eau (Water)         |
| A    | Air              | Air                 |
| F    | Fertility (Soil) | Fertilité           |
| L    | Landscape        | Paysage (Landscape) |
| T    | Time             | Trame               |
| R    | Resilience       | Résilience          |
| S    | Social           | Santé               |
| P    | Productive       | Patrimoine          |
| E    | Energy           | Éducation           |
| N    | Naturalness      | Nuit                |

Family Letter Codes (Bilingual)

## Advanced Topics

### Custom Aggregation Functions

You can define custom aggregation methods by modifying
[`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md):

``` r
# Example: Min-max aggregation (most pessimistic)
custom_aggregate <- function(indicators) {
  # Return the minimum value within family
  min(indicators, na.rm = TRUE)
}

# Would require extending create_family_index() to accept custom functions
```

### Multi-Period Family Analysis

Combine family indices with temporal analysis:

``` r
# Compute family scores for each period
family_2015 <- create_family_index(results_2015)
family_2020 <- create_family_index(results_2020)
family_2025 <- create_family_index(results_2025)

# Create temporal object
temporal_families <- nemeton_temporal(
  periods = list(
    "2015" = family_2015,
    "2020" = family_2020,
    "2025" = family_2025
  ),
  id_column = "parcel_id"
)

# Calculate family score change rates
family_rates <- calculate_change_rate(
  temporal_families,
  indicators = c("family_C", "family_W", "family_F", "family_L"),
  type = "both"
)

# Which family is improving fastest?
```

See
[`vignette("temporal-analysis")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis.md)
for more details.

## Summary

The **nemeton multi-family framework** enables:

1.  **Comprehensive assessment**: 12 dimensions of ecosystem services
2.  **Flexible aggregation**: 4 methods (mean, weighted, geometric,
    harmonic)
3.  **Family-aware normalization**: Independent scaling within families
4.  **Holistic visualization**: Multi-family radar plots
5.  **Progressive implementation**: v0.2.0 → v0.3.0 → v0.4.0 → v0.5.0

### Current Status (v0.2.0)

- ✅ **5 families** implemented (C, W, F, L + partial infrastructure)
- ✅ **10 sub-indicators** ready for use
- ✅ **Full backward compatibility** with v0.1.0
- ✅ **Production-ready** with 661 passing tests

### Next Steps

- Explore temporal analysis:
  [`vignette("temporal-analysis")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis.md)
- Learn basic workflows:
  [`vignette("getting-started")`](https://pobsteta.github.io/nemeton/articles/getting-started.md)
- Read function documentation:
  [`help(package = "nemeton")`](https://rdrr.io/pkg/nemeton/man)
- Check GitHub roadmap: <https://github.com/pobsteta/nemeton>

## Session Info

``` r
sessionInfo()
#> R version 4.5.2 (2025-10-31)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.3 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.0 
#> LAPACK: /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.12.0  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=fr_FR.UTF-8       LC_NUMERIC=C              
#>  [3] LC_TIME=fr_FR.UTF-8        LC_COLLATE=fr_FR.UTF-8    
#>  [5] LC_MONETARY=fr_FR.UTF-8    LC_MESSAGES=fr_FR.UTF-8   
#>  [7] LC_PAPER=fr_FR.UTF-8       LC_NAME=C                 
#>  [9] LC_ADDRESS=C               LC_TELEPHONE=C            
#> [11] LC_MEASUREMENT=fr_FR.UTF-8 LC_IDENTIFICATION=C       
#> 
#> time zone: Europe/Paris
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] dplyr_1.1.4   ggplot2_4.0.1 nemeton_0.2.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] gtable_0.3.6       jsonlite_2.0.0     compiler_4.5.2     tidyselect_1.2.1  
#>  [5] dichromat_2.0-0.1  jquerylib_0.1.4    systemfonts_1.3.1  scales_1.4.0      
#>  [9] textshaping_1.0.4  yaml_2.3.12        fastmap_1.2.0      R6_2.6.1          
#> [13] labeling_0.4.3     generics_0.1.4     knitr_1.51         htmlwidgets_1.6.4 
#> [17] tibble_3.3.0       desc_1.4.3         bslib_0.9.0        pillar_1.11.1     
#> [21] RColorBrewer_1.1-3 rlang_1.1.6        cachem_1.1.0       xfun_0.55         
#> [25] fs_1.6.6           sass_0.4.10        S7_0.2.1           otel_0.2.0        
#> [29] cli_3.6.5          pkgdown_2.2.0      withr_3.0.2        magrittr_2.0.4    
#> [33] digest_0.6.39      grid_4.5.2         lifecycle_1.0.4    vctrs_0.6.5       
#> [37] evaluate_1.0.5     glue_1.8.0         farver_2.1.2       ragg_1.5.0        
#> [41] rmarkdown_2.30     tools_4.5.2        pkgconfig_2.0.3    htmltools_0.5.9
```
