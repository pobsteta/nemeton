# nemeton: Systemic Forest Analysis Using the Nemeton Method

Implement the Nemeton method for systemic forest territory analysis.
Calculate 41 biophysical indicators grouped in 12 ecosystem service
families (carbon, water, soil, landscape, biodiversity, risks, etc.),
weight them by data precision level (NDP, Fibonacci weighting),
normalize them to composite indices and visualize the results. Also
provides forest health monitoring (FAST, FORDEAD, RECONFORT), small-area
estimation of forest production from the French national forest
inventory, and regeneration and microclimate tools. The Shiny
application lives in the separate 'nemetonshiny' package. Designed for
foresters, ecologists and land managers.

The nemeton package implements the Nemeton method for comprehensive
forest ecosystem analysis. It provides tools to calculate, normalize,
and visualize multi-family biophysical indicators across 12 ecosystem
service dimensions.

## Key Features

**Multi-Family Indicator System:**

- **C - Carbon & Vitality**: C1-C2

- **B - Biodiversity**: B1-B4

- **W - Water**: W1-W4

- **A - Air & Microclimate**: A1-A5

- **F - Soil Fertility**: fertility (F1), erosion risk (F2)

- **L - Landscape**: edge effect (L1), fragmentation (L2), spectral
  heterogeneity (L3)

- **T - Temporal Dynamics**: T1-T3

- **R - Risks & Resilience**: R1-R7

- **S - Social & Recreational**: S1-S3

- **P - Production**: P1-P3

- **E - Energy & Climate**: E1-E2

- **N - Naturalness**: N1-N3

- Some indicators are conditional on optional sources (R5 FORDEAD, T3
  SUFOSAT, A5 LST, R7 SAFRAN); see
  [`indicator_families()`](https://pobsteta.github.io/nemeton/reference/indicator_families.md).

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

- [`vignette("getting-started_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/getting-started_fr.md) -
  Introduction to basic workflows with demo data

- [`vignette("temporal-analysis_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis_fr.md) -
  Multi-period analysis and change detection

- [`vignette("indicator-families_fr", package = "nemeton")`](https://pobsteta.github.io/nemeton/articles/indicator-families_fr.md) -
  Complete reference for the 12-family system

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
    normalized <- normalize_indicators(results)

    # Create family indices
    family_scores <- create_family_index(normalized)

    # Visualize multi-family profile
    nemeton_radar(family_scores, unit_id = 1, mode = "family")

## Main Functions

**Indicator Calculation:**

- [`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md) -
  Compute biophysical indicators

- [`indicateur_c1_biomasse`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md) -
  Carbon stock (C1)

- [`indicateur_c2_ndvi`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md) -
  Vegetation vitality (C2)

- [`indicateur_w1_reseau`](https://pobsteta.github.io/nemeton/reference/indicateur_w1_reseau.md) -
  Hydrographic density (W1)

- [`indicateur_w2_zones_humides`](https://pobsteta.github.io/nemeton/reference/indicateur_w2_zones_humides.md) -
  Wetland coverage (W2)

- [`indicateur_w3_humidite`](https://pobsteta.github.io/nemeton/reference/indicateur_w3_humidite.md) -
  Topographic Wetness Index (W3)

- [`indicateur_f1_fertilite`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md) -
  Soil fertility (F1)

- [`indicateur_f2_erosion`](https://pobsteta.github.io/nemeton/reference/indicateur_f2_erosion.md) -
  Erosion risk (F2)

- [`indicateur_l1_effet_lisiere`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md) -
  Edge effect (L1)

- [`indicateur_l2_morcellement`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_morcellement.md) -
  Landscape fragmentation (L2)

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

**terra memory guard.** When loaded, nemeton lowers terra's `memfrac` to
0.25 and caps `memmax` at 3 GB, so large rasters spill to disk instead
of exhausting RAM. Since 1.0.0 the guard is only applied to a setting
still at terra's default: a `terra::terraOptions(memfrac = , memmax = )`
made before nemeton is loaded is kept. The explicit levers below always
win:

- `options(nemeton.terra_memfrac = 0.5)` - memfrac set at load

- `options(nemeton.terra_memmax = 8)` or the environment variable
  `NEMETON_TERRA_MEMMAX=8` - memmax (GB) set at load; a non-positive
  value removes the cap

## Lifecycle

Every help page states the status of its function (spec 057):

- **Stable**: indicators, families, NDP, normalisation, data loaders,
  sampling and the API consumed by nemetonshiny. Covered by the 1.0 API
  contract: a breaking change needs a major release.

- **Experimental**: RAG (knowledge corpus), Sentinel-2 biophysics,
  FORDEAD / RECONFORT health monitoring and their field validation,
  regeneration (microclimate, water balance, E-OBS). May change in any
  release, without deprecation.

The reference index of the site groups the pages by status.

## Author & Methodology

**Package Author:** Pascal Obstétar (<pascal.obstetar@gmail.com>)

**Methodology:** Based on the Nemeton systemic forest analysis method
developed by *Vivre en Forêt*, organizing ecosystem services into 12
families representing key dimensions of forest functioning.

## Version History

See `news(package = "nemeton")` (NEWS.md) for the release history.

## Links

- GitHub: <https://github.com/pobsteta/nemeton>

- Bug Reports: <https://github.com/pobsteta/nemeton/issues>

## See also

Useful links:

- <https://pobsteta.github.io/nemeton/>

- <https://github.com/pobsteta/nemeton>

- Report bugs at <https://github.com/pobsteta/nemeton/issues>

**Vignettes:**

- [`vignette("getting-started_fr")`](https://pobsteta.github.io/nemeton/articles/getting-started_fr.md) -
  Introduction and basic workflows

- [`vignette("temporal-analysis_fr")`](https://pobsteta.github.io/nemeton/articles/temporal-analysis_fr.md) -
  Multi-period analysis guide

- [`vignette("indicator-families_fr")`](https://pobsteta.github.io/nemeton/articles/indicator-families_fr.md) -
  12-family reference guide

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

Authors:

- Pascal Obstétar <pascal.obstetar@gmail.com>
