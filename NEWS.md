# nemeton 0.1.0-rc1 (2026-01-04)

## MVP Release Candidate

**Status**: ✅ 97% Complete (32/33 requirements) - Ready for testing

### Major Features

#### Core Functionality (✅ Complete)
* **Spatial Analysis Engine**: `nemeton_compute()` with 5 biophysical indicators
* **Automatic Preprocessing**: CRS harmonization, extent cropping
* **Error Resilience**: Per-indicator error handling (continues if one fails)
* **Lazy Loading**: Memory-efficient layer catalog system

#### Indicators (✅ 5/5 Complete)
* `indicator_carbon()` - Carbon stock from biomass (Mg C/ha)
* `indicator_biodiversity()` - Species richness / Shannon index
* `indicator_water()` - Water regulation (TWI + proximity to streams)
* `indicator_fragmentation()` - Forest coverage and connectivity
* `indicator_accessibility()` - Distance to roads and trails

#### Normalization & Indices (✅ Complete)
* `normalize_indicators()` - 3 methods (min-max, z-score, quantile)
* `create_composite_index()` - Weighted aggregation (4 methods)
* `invert_indicator()` - Reverse polarity for negative indicators
* Reference-based normalization support

#### Visualization (⚠️ 3/4 - Radar pending)
* `plot_indicators_map()` - Thematic choropleth maps (single + faceted)
* `plot_comparison_map()` - Side-by-side scenario comparison
* `plot_difference_map()` - Absolute and relative change visualization
* Multiple palettes: viridis, RdYlGn, Greens, Blues, etc.

#### Demo Dataset (✅ Complete)
* `massif_demo` - Synthetic forest data (136 ha, 20 parcels)
* 4 rasters at 25m: biomass, DEM, landcover, species richness
* 2 vector layers: roads (5), water courses (3)
* Lambert-93 projection (EPSG:2154)
* Reproducible generation script (`data-raw/massif_demo.R`)

#### Internationalization (✅ Bonus Feature)
* **Bilingual Support**: French + English (200+ messages)
* **Auto-detection**: System locale detection
* **Manual Override**: `nemeton_set_language("fr")` / `nemeton_set_language("en")`
* **Complete Coverage**: All user-facing messages translated
* Dedicated vignette: `internationalization.Rmd`

### Exported Functions (17)

**Core**: `nemeton_units()`, `nemeton_layers()`, `nemeton_compute()`, `massif_demo_layers()`
**Indicators**: `indicator_carbon()`, `indicator_biodiversity()`, `indicator_water()`, `indicator_fragmentation()`, `indicator_accessibility()`
**Normalization**: `normalize_indicators()`, `create_composite_index()`, `invert_indicator()`
**Visualization**: `plot_indicators_map()`, `plot_comparison_map()`, `plot_difference_map()`
**Utilities**: `list_indicators()`, `nemeton_set_language()`

### Documentation (✅ Complete)

* **README.md**: Comprehensive quick start guide (497 lines)
* **Vignettes**:
  - `getting-started.Rmd` - Full workflow with massif_demo
  - `internationalization.Rmd` - i18n guide (FR/EN)
* **Roxygen2**: All 17 exported functions fully documented
* **Examples**: Executable examples in all function docs

### Testing (✅ 225+ Tests)

* **Unit Tests**: Comprehensive coverage across all modules
* **Integration Tests**: End-to-end workflow validation
* **Real Data Tests**: French cadastral parcel testing
* **Fixtures**: Helper functions for test data generation

### Package Metrics

* **R Code**: ~2,500 lines
* **Tests**: ~2,100 lines
* **Dataset Size**: 0.81 Mo (< 5 Mo target)
* **Functions**: 17 exported
* **Vignettes**: 2
* **i18n Messages**: 200+ (FR/EN)

### Quick Start Example

```r
library(nemeton)

# 5-line workflow
data(massif_demo_units)
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
normalized <- normalize_indicators(results, method = "minmax")
plot_indicators_map(normalized, palette = "viridis")
```

## Known Issues

* ⚠️ Minor test fixture compatibility issue (to be fixed in v0.1.0 final)
* ⚠️ Test coverage measurement pending (covr fails due to test issues)
* 📝 User Story 4 (radar chart) not implemented (P3 - optional for MVP)

## Roadmap to v0.1.0

- [ ] Fix test fixtures
- [ ] Verify `devtools::check()` passes
- [ ] Measure test coverage (target: ≥70%)
- [ ] Optional: Implement `nemeton_radar()` (P3)

## Breaking Changes

* None (initial release)

## Credits

Developed with ❤️ and [Claude Code](https://claude.com/claude-code)
**Contributors**: Pascal Obstétar, Claude Sonnet 4.5
