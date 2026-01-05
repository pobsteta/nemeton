# nemeton: Systemic Forest Analysis Using the Nemeton Method

Implement the Nemeton method for systemic forest territory analysis.
Calculate multi-family biophysical indicators across 12 ecosystem
service families (carbon, water, soil, landscape, biodiversity, etc.),
perform temporal analysis, normalize to composite indices, and visualize
results. Designed for foresters, ecologists, and land managers.

The nemeton package implements the Nemeton method for comprehensive
forest ecosystem analysis. It provides tools to calculate, normalize,
and visualize multi-family biophysical indicators across 12 ecosystem
service dimensions.

## Key Features

**Multi-Family Indicator System:**

- **C - Carbon/Vitality**: Biomass stock (C1), NDVI vitality (C2)

- **W - Water**: Network density (W1), wetlands (W2), TWI (W3)

- **F - Soil Fertility**: Fertility (F1), erosion risk (F2)

- **L - Landscape**: Fragmentation (L1), edge ratio (L2)

- **B - Biodiversity**: Planned for v0.3.0+

- **R - Resilience/Risks**: Planned for v0.3.0+

- Plus 6 additional families in future versions

**Temporal Analysis:**

- Multi-period dataset management

- Change rate calculations (absolute and relative)

- Time-series and heatmap visualizations

- Before/after intervention comparison

**Normalization & Aggregation:**

- 3 normalization methods: minmax, zscore, quantile

- 4 aggregation methods: mean, weighted, geometric, harmonic

- Family-level composite indices

- Reference-based normalization for temporal consistency

**Visualization:**

- Spatial maps (single and faceted)

- Multi-family radar plots (4-12 axes)

- Temporal trend plots

- Multi-indicator heatmaps

- Comparison and difference maps

## Getting Started

See the vignettes for comprehensive guides:

- `vignette("getting-started", package = "nemeton")` - Introduction to
  basic workflows with demo data

- `vignette("temporal-analysis", package = "nemeton")` - Multi-period
  analysis and change detection

- `vignette("indicator-families", package = "nemeton")` - Complete
  reference for the 12-family system

- [`vignette("internationalization", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/internationalization.md) -
  Bilingual support (French/English)

## Quick Example

    library(nemeton)

    # Load demo data
    data(massif_demo_units)
    layers <- massif_demo_layers()

    # Compute multi-family indicators
    results <- nemeton_compute(
      massif_demo_units[1:10, ],
      layers,
      indicators = c("C1", "C2", "W1", "W2", "W3"),
      preprocess = TRUE
    )

    # Normalize by family
    normalized <- normalize_indicators(results, by_family = TRUE)

    # Create family indices
    family_scores <- create_family_index(normalized)

    # Visualize multi-family profile
    nemeton_radar(family_scores, unit_id = 1, mode = "family")

## Main Functions

**Indicator Calculation:**

- [`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md) -
  Compute biophysical indicators

- [`indicator_carbon_biomass`](https://pobsteta.github.io/nemeton/reference/indicator_carbon_biomass.md) -
  Carbon stock (C1)

- [`indicator_carbon_ndvi`](https://pobsteta.github.io/nemeton/reference/indicator_carbon_ndvi.md) -
  Vegetation vitality (C2)

- [`indicator_water_network`](https://pobsteta.github.io/nemeton/reference/indicator_water_network.md) -
  Hydrographic density (W1)

- [`indicator_water_wetlands`](https://pobsteta.github.io/nemeton/reference/indicator_water_wetlands.md) -
  Wetland coverage (W2)

- [`indicator_water_twi`](https://pobsteta.github.io/nemeton/reference/indicator_water_twi.md) -
  Topographic Wetness Index (W3)

- [`indicator_soil_fertility`](https://pobsteta.github.io/nemeton/reference/indicator_soil_fertility.md) -
  Soil fertility (F1)

- [`indicator_soil_erosion`](https://pobsteta.github.io/nemeton/reference/indicator_soil_erosion.md) -
  Erosion risk (F2)

- [`indicator_landscape_fragmentation`](https://pobsteta.github.io/nemeton/reference/indicator_landscape_fragmentation.md) -
  Fragmentation (L1)

- [`indicator_landscape_edge`](https://pobsteta.github.io/nemeton/reference/indicator_landscape_edge.md) -
  Edge ratio (L2)

**Temporal Analysis:**

- [`nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md) -
  Multi-period dataset management

- [`calculate_change_rate`](https://pobsteta.github.io/nemeton/reference/calculate_change_rate.md) -
  Change rate calculations

- [`plot_temporal_trend`](https://pobsteta.github.io/nemeton/reference/plot_temporal_trend.md) -
  Time-series plots

- [`plot_temporal_heatmap`](https://pobsteta.github.io/nemeton/reference/plot_temporal_heatmap.md) -
  Indicator evolution heatmaps

**Normalization & Aggregation:**

- [`normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md) -
  Scale indicators to 0-100

- [`create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md) -
  Aggregate indicators by family

- [`create_composite_index`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md) -
  Custom composite indices

- [`invert_indicator`](https://pobsteta.github.io/nemeton/reference/invert_indicator.md) -
  Invert indicator direction

**Visualization:**

- [`plot_indicators_map`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md) -
  Spatial maps

- [`nemeton_radar`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md) -
  Multi-family radar plots

- [`plot_comparison_map`](https://pobsteta.github.io/nemeton/reference/plot_comparison_map.md) -
  Side-by-side comparison

- [`plot_difference_map`](https://pobsteta.github.io/nemeton/reference/plot_difference_map.md) -
  Change maps

**Data Management:**

- [`massif_demo_units`](https://pobsteta.github.io/nemeton/reference/massif_demo_units.md) -
  Demo forest parcels dataset

- [`massif_demo_layers`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md) -
  Demo spatial layers

## Package Options

Control package behavior with options:

- `options(nemeton.language = "fr")` - Set French language

- `options(nemeton.language = "en")` - Set English language

- `nemeton_set_language("fr")` - Alternative language setting

## Author & Methodology

**Package Author:** Pascal Obstétar (<pascal.obstetar@gmail.com>)

**Methodology:** Based on the Nemeton systemic forest analysis method
developed by *Vivre en Forêt*, organizing ecosystem services into 12
families representing key dimensions of forest functioning.

## Version History

- **v0.2.0 (2026-01-05):** Multi-family system, temporal analysis, 5
  families implemented (C, W, F, L + infrastructure), 661 tests passing

- **v0.1.0 (2026-01-04):** Initial release with 5 basic indicators, 225
  tests passing

## Links

- GitHub: <https://github.com/pobsteta/nemeton>

- Bug Reports: <https://github.com/pobsteta/nemeton/issues>

- Development: Branch `001-mvp-v0.2.0`

## See also

Useful links:

- <https://github.com/pascalobstetar/nemeton>

- Report bugs at <https://github.com/pascalobstetar/nemeton/issues>

**Vignettes:**

- `vignette("getting-started")` - Introduction and basic workflows

- `vignette("temporal-analysis")` - Multi-period analysis guide

- `vignette("indicator-families")` - 12-family reference guide

- [`vignette("internationalization")`](https://pobsteta.github.io/nemeton/articles/internationalization.md) -
  Bilingual support

**Key Function Families:**

- Indicators:
  [`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

- Temporal:
  [`nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)

- Normalization:
  [`normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)

- Aggregation:
  [`create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)

- Visualization:
  [`nemeton_radar`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)

## Author

**Maintainer**: Pascal Obstétar <pascal.obstetar@gmail.com>
