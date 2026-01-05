# nemeton v0.2.0 - Release Notes

**Release Date**: 2026-01-05
**Status**: ✅ Production Ready
**Test Coverage**: 661 tests passing (0 failures)

---

## 🎯 Overview

Version 0.2.0 represents a major expansion of the nemeton package, introducing:
- **Multi-family indicator framework** (12 ecosystem service families)
- **Temporal analysis infrastructure** (multi-period datasets)
- **5 new indicator families** with 10 sub-indicators
- **Enhanced normalization and visualization** for family-level analysis

This release transforms nemeton from a basic 5-indicator tool into a comprehensive ecosystem services assessment platform.

---

## 📦 What's New

### Major Features

#### 1. Multi-Family System (US6)
- **`create_family_index()`**: Aggregate indicators into family scores
  - 4 aggregation methods: mean, weighted, geometric, harmonic
  - Custom weights per family
  - Supports all 12 families (C, B, W, A, F, L, T, R, S, P, E, N)

- **`normalize_indicators()` extended**: Family-aware workflows
  - `by_family` parameter for in-place normalization
  - Auto-detection of family indicators (C1, W1, F1 pattern)

- **`nemeton_radar()` multi-family mode**: 4-12 family axes visualization
  - New `mode` parameter: "indicator" or "family"
  - Dynamic axis scaling

#### 2. Temporal Analysis (US1)
- **`nemeton_temporal()`**: Multi-period dataset management
- **`calculate_change_rate()`**: Absolute and relative change rates
- **`plot_temporal_trend()`**: Time-series line plots
- **`plot_temporal_heatmap()`**: Indicator evolution heatmaps

#### 3. Carbon Family (US2)
- **`indicator_carbon_biomass()` (C1)**: Allometric models for BD Forêt v2
  - Species-specific coefficients (Quercus, Fagus, Pinus, Abies, Generic)
  - Output: tC/ha

- **`indicator_carbon_ndvi()` (C2)**: Vegetation vitality from NDVI
  - Sentinel-2 compatible
  - Future: 5-year trend analysis

#### 4. Water Family (US3)
- **`indicator_water_network()` (W1)**: Hydrographic network density (km/ha)
- **`indicator_water_wetlands()` (W2)**: Wetland coverage (%)
- **`indicator_water_twi()` (W3)**: Topographic Wetness Index
  - D8 flow algorithm (terra)
  - Future: D-infinity support

#### 5. Soil Family (US4)
- **`indicator_soil_fertility()` (F1)**: BD Sol classification (0-100)
- **`indicator_soil_erosion()` (F2)**: Slope × cover protection risk

#### 6. Landscape Family (US5)
- **`indicator_landscape_fragmentation()` (L1)**: Forest patch counting
- **`indicator_landscape_edge()` (L2)**: Edge-to-area ratio (m/ha)

---

## 📊 Statistics

### Code
- **R Code**: ~4,500 lines (+2,000 from v0.1.0)
- **Tests**: ~3,200 lines (+1,100 from v0.1.0)
- **Functions**: 30 exported (+12 from v0.1.0)
- **Vignettes**: 4 (+2 from v0.1.0)

### Testing
- **Total Tests**: 661 passing (+436 from v0.1.0's 225 tests)
- **Test Coverage**: Expected >70%
- **Phases Completed**: 9/9 (100%)

### Indicators
- **v0.1.0**: 5 indicators (carbon, biodiversity, water, fragmentation, accessibility)
- **v0.2.0**: 15 indicators across 5 families (C, W, F, L + legacy)
- **Families Implemented**: 5/12 (C, W, F, L + infrastructure for all 12)

---

## 🔄 Migration Guide

### From v0.1.0 to v0.2.0

**✅ Full Backward Compatibility**: All v0.1.0 workflows continue to work unchanged.

#### Deprecated Functions
- `indicator_carbon()` → Use `indicator_carbon_biomass()` or `indicator_carbon_ndvi()`
  - Still works with deprecation warning
  - Will be removed in v1.0.0

#### New Recommended Workflow

**v0.1.0 style (still works):**
```r
results <- nemeton_compute(units, layers, indicators = "all")
normalized <- normalize_indicators(results)
plot_indicators_map(normalized)
```

**v0.2.0 multi-family style:**
```r
# Compute family indicators
results <- nemeton_compute(units, layers, indicators = c("C1", "C2", "W1", "W2", "W3"))

# Normalize by family
normalized <- normalize_indicators(results, by_family = TRUE)

# Create family indices
family_scores <- create_family_index(normalized, method = "weighted",
  weights = list(C = c(C1 = 0.7, C2 = 0.3))
)

# Visualize family profile
nemeton_radar(family_scores, unit_id = "P001", mode = "family")
```

---

## 🐛 Known Issues

### Minor Issues
1. **Non-ASCII characters warning**: Expected for bilingual FR/EN support
2. **Some suggested packages unavailable**: `whitebox`, `landscapemetrics` (optional)

### Workarounds
- Non-ASCII: No action needed for internal use; use `\uxxxx` escapes for CRAN submission
- Missing packages: Install manually if needed for TWI (whitebox) or advanced metrics

---

## 🚀 Future Roadmap

### v0.3.0 (Planned)
- **Famille B**: Biodiversité (B1, B2, B3)
- **Famille R**: Risques (R1, R2, R3)
- **Famille T**: Temporelle (T1, T2)

### v0.4.0 (Planned)
- **Famille S**: Social/Usages (S1, S2, S3)
- **Famille P**: Productif (P1, P2, P3)
- **Famille A**: Air/Microclimat (A1, A2)

### v0.5.0 (Planned)
- **Famille E**: Énergie (E1, E2)
- **Famille N**: Naturalité (N1, N2, N3)
- **Shiny Dashboard**: Interactive web interface

---

## 📚 Documentation

### Vignettes
1. **getting-started.Rmd**: Introduction and basic workflow
2. **internationalization.Rmd**: Bilingual support (FR/EN)
3. **temporal-analysis.Rmd**: Multi-period analysis (NEW)
4. **indicator-families.Rmd**: Complete family reference (NEW)

### Resources
- **README.md**: Quick start guide
- **NEWS.md**: Detailed changelog (9 phases)
- **GitHub**: https://github.com/pascalobstetar/nemeton

---

## 🙏 Acknowledgments

Developed with **Claude Code** (Claude Sonnet 4.5)
Package Author: Pascal Obstétar
Methodology: Nemeton systemic forest analysis

---

## 📋 Installation

### From GitHub (Current)
```r
# Install devtools if needed
install.packages("devtools")

# Install nemeton
devtools::install_github("pascalobstetar/nemeton")
```

### Required Dependencies
```r
install.packages(c("sf", "terra", "exactextractr", "dplyr", "ggplot2",
                   "rlang", "cli", "tidyr"))
```

### Optional Dependencies
```r
# For TWI and advanced metrics
install.packages("whitebox")
install.packages("landscapemetrics")
```

---

## 💡 Quick Start

```r
library(nemeton)

# Load demo data
data(massif_demo_units)
layers <- massif_demo_layers()

# Compute carbon family indicators
results <- nemeton_compute(
  massif_demo_units[1:5, ],
  layers,
  indicators = c("C1", "C2")
)

# Create family index
family_scores <- create_family_index(results)

# Visualize
nemeton_radar(family_scores, unit_id = 1, mode = "family")
```

---

**Happy analyzing! 🌲📊**
