# nemeton v0.1.0-rc2 - Release Candidate 2

**Release Date**: 2026-01-05 **Status**: Release Candidate - Ready for
User Testing

## 🎯 Overview

Second release candidate for the nemeton R package MVP (v0.1.0). This
release resolves critical test suite failures and improves package
stability. All core functionality is now operational with 92% test
success rate.

## ✨ Highlights

- **269/290 tests passing** (92% success rate, up from ~50%)
- **All 5 biophysical indicators** working correctly
- **Fixed S3 method dispatch issues** with exactextractr and terra
- **Complete bilingual support** (French/English) with i18n
- **Production-ready documentation** (2 vignettes, full Roxygen2)

## 🔧 What’s Fixed in RC2

### Core Fixes

- **S3 Method Dispatch**: Added `as_pure_sf()` helper function to strip
  `nemeton_units` class for compatibility with exactextractr and terra
  packages
- **Test Geometries**: Fixed test fixture polygons to stay within raster
  extent (adjusted from 150m to 120m offset)
- **Edge Cases**: Added guard for constant values in
  [`indicator_water()`](https://pobsteta.github.io/nemeton/reference/indicator_water.md)
  TWI normalization to prevent NaN results
- **Vignette Error**: Fixed `getting-started.Rmd` by including
  `accessibility` in normalization before inversion

### Modified Functions

- [`indicator_carbon()`](https://pobsteta.github.io/nemeton/reference/indicator_carbon.md),
  [`indicator_biodiversity()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity.md),
  [`indicator_water()`](https://pobsteta.github.io/nemeton/reference/indicator_water.md),
  [`indicator_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicator_fragmentation.md):
  Use `as_pure_sf()` for exactextractr compatibility
- `mask_to_units()`: Use `as_pure_sf()` for terra::vect() compatibility
- `create_test_units()`: Adjusted polygon coordinates to stay within
  raster bounds

### Test Infrastructure

- Force English language in tests for consistent error messages
- Update vignette to normalize all 5 indicators before inversion
- Improved test fixtures for better coverage

## 📦 Package Features

### Core Functionality

- **5 Biophysical Indicators**:
  - [`indicator_carbon()`](https://pobsteta.github.io/nemeton/reference/indicator_carbon.md) -
    Carbon stock from biomass (Mg C/ha)
  - [`indicator_biodiversity()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity.md) -
    Species richness / Shannon index
  - [`indicator_water()`](https://pobsteta.github.io/nemeton/reference/indicator_water.md) -
    Water regulation (TWI + proximity to streams)
  - [`indicator_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicator_fragmentation.md) -
    Forest coverage and connectivity
  - [`indicator_accessibility()`](https://pobsteta.github.io/nemeton/reference/indicator_accessibility.md) -
    Distance to roads and trails
- **Normalization & Indices**:
  - [`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md) -
    3 methods (min-max, z-score, quantile)
  - [`create_composite_index()`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md) -
    Weighted aggregation (4 methods)
  - [`invert_indicator()`](https://pobsteta.github.io/nemeton/reference/invert_indicator.md) -
    Reverse polarity for negative indicators
- **Visualization**:
  - [`plot_indicators_map()`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md) -
    Thematic choropleth maps (single + faceted)
  - [`plot_comparison_map()`](https://pobsteta.github.io/nemeton/reference/plot_comparison_map.md) -
    Side-by-side scenario comparison
  - [`plot_difference_map()`](https://pobsteta.github.io/nemeton/reference/plot_difference_map.md) -
    Absolute and relative change visualization
- **Demo Dataset**:
  - `massif_demo` - Synthetic forest data (136 ha, 20 parcels)
  - 4 rasters at 25m: biomass, DEM, landcover, species richness
  - 2 vector layers: roads (5), water courses (3)
  - Lambert-93 projection (EPSG:2154)

### Internationalization (i18n)

- **Bilingual Support**: French + English (200+ messages)
- **Auto-detection**: System locale detection
- **Manual Override**: `nemeton_set_language("fr")` /
  `nemeton_set_language("en")`
- **Complete Coverage**: All user-facing messages translated

## 📊 Package Metrics

- **R Code**: ~2,500 lines
- **Tests**: ~2,100 lines (269/290 passing - 92%)
- **Dataset Size**: 0.81 Mo (\< 5 Mo target)
- **Functions**: 17 exported
- **Vignettes**: 2 (getting-started, internationalization)
- **i18n Messages**: 200+ (FR/EN)

## 🚀 Quick Start

``` r
# Install from GitHub
remotes::install_github("pobsteta/nemeton@v0.1.0-rc2")

# Load package
library(nemeton)

# 5-line workflow
data(massif_demo_units)
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
normalized <- normalize_indicators(results, method = "minmax")
plot_indicators_map(normalized, palette = "viridis")
```

## ⚠️ Known Issues

- 21 minor test failures (tests for print/summary output formatting and
  error message regexes)
- These are cosmetic issues that don’t affect package functionality
- Will be addressed in v0.1.1 maintenance release

## 📝 Documentation

- **README.md**: Comprehensive quick start guide
- **Vignettes**:
  - `getting-started.Rmd` - Full workflow with massif_demo
  - `internationalization.Rmd` - i18n guide (FR/EN)
- **Roxygen2**: All 17 exported functions fully documented
- **Examples**: Executable examples in all function docs

## 🎯 Testing Recommendations

Users testing this RC2 should:

1.  **Test with real data**: Try the package with actual forest parcels
    and environmental layers
2.  **Report issues**: File issues on GitHub for any bugs or unexpected
    behavior
3.  **Check documentation**: Verify that documentation is clear and
    examples work
4.  **Test bilingual support**: Try both French and English interfaces
5.  **Performance testing**: Test with larger datasets (100+ parcels)

## 📋 Next Steps to v0.1.0 Final

Collect user feedback from RC2 testing

Fix remaining 21 cosmetic test failures

Verify `devtools::check()` passes without errors

Measure test coverage with `covr` (target: ≥70%)

Optional: Implement
[`nemeton_radar()`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)
for User Story 4 (P3)

## 🙏 Credits

Developed with ❤️ and [Claude Code](https://claude.com/claude-code)

**Contributors**: Pascal Obstétar, Claude Sonnet 4.5

## 📄 Full Status Report

See
[MVP_STATUS_FINAL.md](https://github.com/pobsteta/nemeton/blob/main/MVP_STATUS_FINAL.md)
for complete status report with detailed breakdown by user story and
functional requirements.

------------------------------------------------------------------------

**Installation**:

``` r
remotes::install_github("pobsteta/nemeton@v0.1.0-rc2")
```

**Questions or Issues?** Please file an issue at
<https://github.com/pobsteta/nemeton/issues>
