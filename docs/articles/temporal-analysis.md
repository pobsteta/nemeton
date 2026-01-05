# Temporal Analysis with nemeton

## Introduction

The `nemeton` package provides comprehensive tools for **temporal
analysis** of forest ecosystem indicators. This vignette demonstrates
how to:

- Manage multi-period datasets with
  [`nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)
- Calculate change rates (absolute and relative) with
  [`calculate_change_rate()`](https://pobsteta.github.io/nemeton/reference/calculate_change_rate.md)
- Visualize temporal trends with time-series plots
- Create heatmaps of indicator evolution
- Compare before/after intervention scenarios

Temporal analysis enables forest managers to:

- **Detect trends**: Identify long-term changes in ecosystem services
- **Assess interventions**: Evaluate the impact of management actions
- **Monitor resilience**: Track recovery after disturbances
- **Inform decisions**: Base strategies on observed dynamics

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

## Creating Multi-Period Datasets

### Temporal Object Structure

A `nemeton_temporal` object contains multiple time periods, each with
the same spatial units tracked over time.

``` r
# Load demo data
data(massif_demo_units)

# Simulate three time periods (2015, 2020, 2025)
# In practice, these would come from different data sources

# Period 1: 2015 baseline
units_2015 <- massif_demo_units[1:10, ]
units_2015$period <- "2015"
units_2015$parcel_id <- paste0("P", sprintf("%03d", 1:10))
units_2015$carbon <- rnorm(10, mean = 150, sd = 20)
units_2015$biodiversity <- rnorm(10, mean = 12, sd = 3)
units_2015$water <- rnorm(10, mean = 8, sd = 2)

# Period 2: 2020 intermediate (some growth)
units_2020 <- massif_demo_units[1:10, ]
units_2020$period <- "2020"
units_2020$parcel_id <- paste0("P", sprintf("%03d", 1:10))
units_2020$carbon <- units_2015$carbon * runif(10, 1.05, 1.15)  # 5-15% growth
units_2020$biodiversity <- units_2015$biodiversity + rnorm(10, mean = 1, sd = 0.5)
units_2020$water <- units_2015$water + rnorm(10, mean = 0, sd = 0.3)

# Period 3: 2025 recent (continued growth + intervention effects)
units_2025 <- massif_demo_units[1:10, ]
units_2025$period <- "2025"
units_2025$parcel_id <- paste0("P", sprintf("%03d", 1:10))
units_2025$carbon <- units_2020$carbon * runif(10, 1.08, 1.20)
units_2025$biodiversity <- units_2020$biodiversity + rnorm(10, mean = 1.5, sd = 0.8)
units_2025$water <- units_2020$water + rnorm(10, mean = 0.5, sd = 0.4)
```

### Create Temporal Object

``` r
# Create temporal dataset
temporal_data <- nemeton_temporal(
  periods = list(
    "2015" = units_2015,
    "2020" = units_2020,
    "2025" = units_2025
  ),
  id_column = "parcel_id"
)

# Inspect temporal object
print(temporal_data)
#> nemeton_temporal object
#>   3 periods: 2015, 2020, 2025
#>   10 units tracked across periods
#>   Date range: 2015-01-01 to 2025-01-01
#>   Indicators: surface_ha, carbon, biodiversity, water
```

``` r
# Summary statistics
summary(temporal_data)
#> nemeton_temporal object
#>   3 periods: 2015, 2020, 2025
#>   10 units tracked across periods
#>   Date range: 2015-01-01 to 2025-01-01
#>   Indicators: surface_ha, carbon, biodiversity, water
#> 
#> Period summaries:
#> 
#>   Period 1: 2015 (2015)
#>     Units: 10
#>     Indicator ranges:
#>       surface_ha: [1.05, 17.08] (mean: 8.97)
#>       carbon: [101.25, 172.97] (mean: 141.17)
#>       biodiversity: [6.41, 18.20] (mean: 11.46)
#>       water: [4.98, 11.78] (mean: 7.75)
#> 
#>   Period 2: 2020 (2020)
#>     Units: 10
#>     Indicator ranges:
#>       surface_ha: [1.05, 17.08] (mean: 8.97)
#>       carbon: [112.09, 184.93] (mean: 155.10)
#>       biodiversity: [7.45, 19.06] (mean: 12.36)
#>       water: [4.98, 11.20] (mean: 7.81)
#> 
#>   Period 3: 2025 (2025)
#>     Units: 10
#>     Indicator ranges:
#>       surface_ha: [1.05, 17.08] (mean: 8.97)
#>       carbon: [121.21, 216.21] (mean: 179.80)
#>       biodiversity: [8.17, 21.45] (mean: 13.79)
#>       water: [5.45, 12.23] (mean: 8.43)
```

The temporal object tracks:

- **3 periods** (2015, 2020, 2025)
- **10 spatial units** (parcels P001-P010)
- **3 indicators** (carbon, biodiversity, water)
- **Consistent identifiers** across time (parcel_id)

## Calculating Change Rates

### Absolute Change Rates

Absolute change quantifies the raw difference between periods (e.g., Mg
C/ha/year).

``` r
# Calculate absolute change rates for all indicators
rates_absolute <- calculate_change_rate(
  temporal_data,
  indicators = c("carbon", "biodiversity", "water"),
  type = "absolute"
)

# Inspect results
head(rates_absolute)
#>   parcel_id      forest_type age_class   management surface_ha
#> 1      P001     Futaie mixte    Mature        Mixte   4.989211
#> 2      P002 Futaie résineuse     Moyen   Production   5.867935
#> 3      P003  Futaie feuillue  Surannée Conservation   6.557777
#> 4      P004  Futaie feuillue  Surannée   Production   9.989553
#> 5      P005 Futaie résineuse     Moyen   Production   5.906395
#> 6      P006 Futaie résineuse    Mature   Production   1.048296
#>                                                                                                                                            geometry
#> 1 698299.9, 698307.5, 698178.8, 698041.8, 698102.3, 698233.7, 698299.9, 6499928.5, 6500052.6, 6500088.1, 6500018.3, 6499875.5, 6499800.4, 6499928.5
#> 2 701702.2, 701545.6, 701524.5, 701618.0, 701728.6, 701835.0, 701702.2, 6500418.0, 6500353.8, 6500209.5, 6500109.1, 6500169.3, 6500291.3, 6500418.0
#> 3 702240.4, 702137.6, 702277.7, 702435.0, 702507.7, 702383.6, 702240.4, 6500270.5, 6500128.7, 6500037.9, 6499990.8, 6500159.9, 6500263.2, 6500270.5
#> 4 700641.3, 700417.2, 700340.3, 700507.4, 700668.4, 700737.6, 700641.3, 6504129.1, 6504158.6, 6503926.2, 6503794.3, 6503839.4, 6503983.5, 6504129.1
#> 5 699268.2, 699169.9, 699042.1, 698949.3, 699026.1, 699190.4, 699268.2, 6500307.1, 6500408.9, 6500423.2, 6500304.0, 6500154.1, 6500172.1, 6500307.1
#> 6 699943.5, 699930.6, 699871.2, 699822.8, 699822.3, 699883.0, 699943.5, 6499420.5, 6499489.5, 6499502.7, 6499474.5, 6499411.2, 6499388.2, 6499420.5
#>   period   carbon biodiversity     water carbon_rate_abs biodiversity_rate_abs
#> 1   2025 160.9713    13.631380  9.674640        3.896687             0.3292028
#> 2   2025 198.0079    14.899832  9.353522        4.289574             0.1012747
#> 3   2025 121.2110    21.446618  6.599154        1.995354             0.3251098
#> 4   2025 192.7201     9.253592 10.105690        4.282563             0.2146266
#> 5   2025 216.2063    15.628884 12.230811        5.376789             0.2091317
#> 6   2025 210.8236     8.165302  8.773300        3.785024             0.1754097
#>   water_rate_abs
#> 1     0.07382297
#> 2     0.06275336
#> 3     0.12080755
#> 4     0.06300507
#> 5     0.04537391
#> 6     0.09680573
```

``` r
# Summary of carbon change rate
cat("\n=== Carbon Change Rate (Mg C/parcel/year) ===\n")
#> 
#> === Carbon Change Rate (Mg C/parcel/year) ===
summary(rates_absolute$carbon_rate_abs)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   1.995   3.610   3.909   3.863   4.283   5.377

# Identify parcels with highest carbon accumulation
top_carbon <- rates_absolute %>%
  sf::st_drop_geometry() %>%
  arrange(desc(carbon_rate_abs)) %>%
  head(3)

cat("\nTop 3 parcels for carbon accumulation:\n")
#> 
#> Top 3 parcels for carbon accumulation:
print(top_carbon[, c("parcel_id", "carbon_rate_abs")])
#>   parcel_id carbon_rate_abs
#> 1      P005        5.376789
#> 2      P002        4.289574
#> 3      P004        4.282563
```

### Relative Change Rates

Relative change expresses change as percentage of baseline (e.g.,
%/year).

``` r
# Calculate relative change rates
rates_relative <- calculate_change_rate(
  temporal_data,
  indicators = c("carbon", "biodiversity", "water"),
  type = "relative"
)

# Summary of biodiversity change (%)
cat("\n=== Biodiversity Change Rate (%/year) ===\n")
#> 
#> === Biodiversity Change Rate (%/year) ===
summary(rates_relative$biodiversity_rate_rel)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.7293  1.6053  2.1036  2.1586  2.8635  3.1841

# Identify parcels with highest biodiversity increase
top_bio <- rates_relative %>%
  sf::st_drop_geometry() %>%
  arrange(desc(biodiversity_rate_rel)) %>%
  head(3)

cat("\nTop 3 parcels for biodiversity increase:\n")
#> 
#> Top 3 parcels for biodiversity increase:
print(top_bio[, c("parcel_id", "biodiversity_rate_rel")])
#>   parcel_id biodiversity_rate_rel
#> 1      P001              3.184117
#> 2      P004              3.019919
#> 3      P007              2.905961
```

### Both Absolute and Relative

Calculate both types simultaneously:

``` r
# Both rate types
rates_both <- calculate_change_rate(
  temporal_data,
  indicators = c("carbon", "biodiversity", "water"),
  type = "both"
)

# Check columns
cat("\nAvailable columns:\n")
#> 
#> Available columns:
grep("_rate_", names(rates_both), value = TRUE)
#> [1] "carbon_rate_abs"       "carbon_rate_rel"       "biodiversity_rate_abs"
#> [4] "biodiversity_rate_rel" "water_rate_abs"        "water_rate_rel"
```

## Temporal Visualizations

### Time-Series Trend Plots

Visualize indicator evolution across all periods.

``` r
# Carbon trends over time
plot_temporal_trend(
  temporal_data,
  indicator = "carbon",
  title = "Carbon Stock Evolution (2015-2025)"
)
```

![Carbon stock evolution
(2015-2025)](temporal-analysis_files/figure-html/unnamed-chunk-10-1.png)

Carbon stock evolution (2015-2025)

``` r
# Multiple indicators
plot_temporal_trend(
  temporal_data,
  indicator = c("carbon", "biodiversity", "water"),
  title = "Multi-Indicator Temporal Trends"
)
```

![Multiple indicator
trends](temporal-analysis_files/figure-html/unnamed-chunk-11-1.png)

Multiple indicator trends

### Heatmap Visualizations

Heatmaps show spatial-temporal patterns (parcels × periods).

``` r
# Multi-indicator heatmap for a single parcel
plot_temporal_heatmap(
  temporal_data,
  unit_id = "P001",
  indicators = c("carbon", "biodiversity", "water"),
  title = "Multi-Indicator Evolution - Parcel P001"
)
```

Heatmaps help identify:

- **Indicator patterns**: Which indicators are changing together
- **Temporal anomalies**: Unexpected changes in specific periods
- **Parcel profiles**: Quick visualization of multi-indicator evolution

## Use Case: Before/After Intervention

### Simulate Forest Management Intervention

``` r
# Scenario: Selective thinning in 2020 affects carbon and biodiversity

# Before intervention (2015)
units_before <- massif_demo_units[1:5, ]
units_before$parcel_id <- paste0("P", 1:5)
units_before$carbon <- c(120, 135, 128, 142, 138)
units_before$biodiversity <- c(10, 11, 9, 12, 10)

# After intervention (2025) - thinning increases biodiversity, reduces carbon short-term
units_after <- massif_demo_units[1:5, ]
units_after$parcel_id <- paste0("P", 1:5)
units_after$carbon <- c(110, 125, 118, 132, 128)       # -8% carbon
units_after$biodiversity <- c(14, 15, 13, 16, 14)     # +40% biodiversity

# Create temporal object
intervention <- nemeton_temporal(
  periods = list("2015" = units_before, "2025" = units_after),
  id_column = "parcel_id"
)

print(intervention)
#> nemeton_temporal object
#>   2 periods: 2015, 2025
#>   5 units tracked across periods
#>   Date range: 2015-01-01 to 2025-01-01
#>   Indicators: surface_ha, carbon, biodiversity
```

### Evaluate Intervention Effects

``` r
# Calculate change rates
intervention_rates <- calculate_change_rate(
  intervention,
  indicators = c("carbon", "biodiversity"),
  type = "both"
)

# Summary
cat("\n=== Intervention Impact Summary ===\n")
#> 
#> === Intervention Impact Summary ===
cat("\nCarbon change (absolute):\n")
#> 
#> Carbon change (absolute):
summary(intervention_rates$carbon_rate_abs)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#> -0.9999 -0.9999 -0.9999 -0.9999 -0.9999 -0.9999

cat("\nBiodiversity change (absolute):\n")
#> 
#> Biodiversity change (absolute):
summary(intervention_rates$biodiversity_rate_abs)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.3999  0.3999  0.3999  0.3999  0.3999  0.3999

# Trade-off analysis
tradeoff <- intervention_rates %>%
  sf::st_drop_geometry() %>%
  select(parcel_id, carbon_rate_abs, biodiversity_rate_abs)

cat("\nTrade-off Analysis:\n")
#> 
#> Trade-off Analysis:
print(tradeoff)
#>   parcel_id carbon_rate_abs biodiversity_rate_abs
#> 1        P1      -0.9998631             0.3999453
#> 2        P2      -0.9998631             0.3999453
#> 3        P3      -0.9998631             0.3999453
#> 4        P4      -0.9998631             0.3999453
#> 5        P5      -0.9998631             0.3999453
```

``` r
# Visualize biodiversity increase
plot_temporal_trend(
  intervention,
  indicator = "biodiversity",
  title = "Biodiversity Response to Thinning Intervention"
)
```

![Intervention impact on
biodiversity](temporal-analysis_files/figure-html/unnamed-chunk-15-1.png)

Intervention impact on biodiversity

## Advanced Workflows

### Multi-Family Temporal Analysis

Combine temporal analysis with the multi-family system (see
[`vignette("indicator-families")`](https://pobsteta.github.io/nemeton/articles/indicator-families.md)).

``` r
# Example workflow (requires family indicators computed)

# Compute family indicators for each period
layers <- massif_demo_layers()

# Period 1
results_2015 <- nemeton_compute(
  units_2015,
  layers,
  indicators = c("C1", "C2", "W1", "W2", "W3")
)

# Period 2
results_2020 <- nemeton_compute(
  units_2020,
  layers,
  indicators = c("C1", "C2", "W1", "W2", "W3")
)

# Create family indices for each period
family_2015 <- create_family_index(results_2015)
family_2020 <- create_family_index(results_2020)

# Temporal analysis of family scores
temporal_families <- nemeton_temporal(
  periods = list("2015" = family_2015, "2020" = family_2020),
  id_column = "parcel_id"
)

# Family score change rates
family_rates <- calculate_change_rate(
  temporal_families,
  indicators = c("family_C", "family_W"),
  type = "both"
)
```

### Reference Period Normalization

Normalize all periods using the first period as reference:

``` r
# Extract first period data
baseline <- temporal_data$periods[[1]]

# Normalize each period using baseline reference
temporal_normalized <- nemeton_temporal(
  periods = lapply(temporal_data$periods, function(period_data) {
    normalize_indicators(
      period_data,
      indicators = c("carbon", "biodiversity", "water"),
      method = "minmax",
      reference_data = baseline  # Use baseline min/max
    )
  }),
  id_column = "parcel_id"
)

# All periods now normalized to baseline (0-100 scale)
```

### Detecting Anomalies

Identify parcels with unusual change patterns:

``` r
# Calculate z-scores of change rates
rates_zscore <- rates_absolute %>%
  sf::st_drop_geometry() %>%
  mutate(
    carbon_zscore = scale(carbon_rate_abs)[, 1],
    biodiversity_zscore = scale(biodiversity_rate_abs)[, 1]
  )

# Flag anomalies (|z| > 2)
anomalies <- rates_zscore %>%
  filter(abs(carbon_zscore) > 2 | abs(biodiversity_zscore) > 2) %>%
  select(parcel_id, carbon_zscore, biodiversity_zscore)

if (nrow(anomalies) > 0) {
  cat("\nDetected anomalies (|z| > 2):\n")
  print(anomalies)
} else {
  cat("\nNo anomalies detected (all |z| < 2)\n")
}
#> 
#> Detected anomalies (|z| > 2):
#>   parcel_id carbon_zscore biodiversity_zscore
#> 1      P003     -2.147385            1.168131
```

## Exporting Temporal Results

### Save Temporal Object

``` r
# Save as RDS for future analysis
saveRDS(temporal_data, "results/temporal_data_2015_2025.rds")

# Load later
temporal_data <- readRDS("results/temporal_data_2015_2025.rds")
```

### Export Change Rates

``` r
# Export as GeoPackage
sf::st_write(
  rates_both,
  "results/change_rates_2015_2025.gpkg",
  delete_dsn = TRUE
)

# Export as CSV (without geometry)
rates_table <- rates_both %>%
  sf::st_drop_geometry()

write.csv(
  rates_table,
  "results/change_rates_2015_2025.csv",
  row.names = FALSE
)
```

### Save Plots

``` r
# Time-series plot
p1 <- plot_temporal_trend(temporal_data, indicator = "carbon")
ggsave("figures/carbon_trend_2015_2025.png", p1, width = 10, height = 6, dpi = 300)

# Heatmap
p2 <- plot_temporal_heatmap(temporal_data, unit_id = "P001")
ggsave("figures/multi_indicator_heatmap.png", p2, width = 10, height = 6, dpi = 300)
```

## Summary

The `nemeton` temporal analysis workflow enables:

1.  **Multi-period management**: Track indicators across 2+ time periods
2.  **Change quantification**: Calculate absolute and relative rates
3.  **Trend visualization**: Time-series plots and heatmaps
4.  **Intervention assessment**: Evaluate management impacts
5.  **Integration**: Combine with multi-family system for comprehensive
    analysis

### Key Functions

- [`nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md):
  Create multi-period datasets
- [`calculate_change_rate()`](https://pobsteta.github.io/nemeton/reference/calculate_change_rate.md):
  Compute absolute/relative change rates
- [`plot_temporal_trend()`](https://pobsteta.github.io/nemeton/reference/plot_temporal_trend.md):
  Time-series line plots for all parcels
- [`plot_temporal_heatmap()`](https://pobsteta.github.io/nemeton/reference/plot_temporal_heatmap.md):
  Multi-indicator heatmap for a single parcel

### Next Steps

- Explore the multi-family system:
  [`vignette("indicator-families")`](https://pobsteta.github.io/nemeton/articles/indicator-families.md)
- Learn basic workflows:
  [`vignette("getting-started")`](https://pobsteta.github.io/nemeton/articles/getting-started.md)
- Check function documentation:
  [`help(package = "nemeton")`](https://rdrr.io/pkg/nemeton/man)

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
#>  [1] gtable_0.3.6       jsonlite_2.0.0     compiler_4.5.2     Rcpp_1.1.0        
#>  [5] tidyselect_1.2.1   dichromat_2.0-0.1  jquerylib_0.1.4    systemfonts_1.3.1 
#>  [9] scales_1.4.0       textshaping_1.0.4  yaml_2.3.12        fastmap_1.2.0     
#> [13] R6_2.6.1           labeling_0.4.3     generics_0.1.4     classInt_0.4-11   
#> [17] sf_1.0-23          knitr_1.51         htmlwidgets_1.6.4  tibble_3.3.0      
#> [21] units_1.0-0        desc_1.4.3         DBI_1.2.3          bslib_0.9.0       
#> [25] pillar_1.11.1      RColorBrewer_1.1-3 rlang_1.1.6        cachem_1.1.0      
#> [29] xfun_0.55          fs_1.6.6           sass_0.4.10        S7_0.2.1          
#> [33] otel_0.2.0         cli_3.6.5          pkgdown_2.2.0      withr_3.0.2       
#> [37] magrittr_2.0.4     class_7.3-23       digest_0.6.39      grid_4.5.2        
#> [41] lifecycle_1.0.4    vctrs_0.6.5        KernSmooth_2.23-26 proxy_0.4-29      
#> [45] evaluate_1.0.5     glue_1.8.0         farver_2.1.2       ragg_1.5.0        
#> [49] e1071_1.7-17       rmarkdown_2.30     tools_4.5.2        pkgconfig_2.0.3   
#> [53] htmltools_0.5.9
```
