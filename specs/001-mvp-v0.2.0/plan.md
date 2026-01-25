# Implementation Plan: MVP v0.2.0 - Temporal & Spatial Indicators Extension

**Branch**: `001-mvp-v0.2.0` | **Date**: 2026-01-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-mvp-v0.2.0/spec.md`

## Summary

**Primary Goal**: Establish foundations for comprehensive 12-family indicator framework (36 sub-indicators) by implementing multi-temporal analysis infrastructure and 5 indicator families (C, W, F, L partial) on top of existing nemeton v0.1.0 package.

**Technical Approach**:
1. **Temporal Infrastructure** (US1-P1): Extend `nemeton_units` S3 class to support multi-period datasets with temporal indexing, create `nemeton_temporal()` wrapper, implement change rate calculations and time-series visualizations using ggplot2.

2. **Carbon Family** (US2-P1): Create `indicator_carbon_biomass()` with species-specific allometric equations (Quercus, Fagus, Pinus, Abies) sourced from IGN/IFN literature, implement `indicator_carbon_ndvi()` for NDVI extraction and optional trend calculation (Sentinel-2), deprecate existing `indicator_carbon()` with backward-compatible fallback.

3. **Water Family** (US3-P1): Extend existing partial water implementation with `indicator_water_network()` (stream length density via sf), `indicator_water_wetlands()` (% wetland from land cover raster), `indicator_water_twi()` (Topographic Wetness Index using whitebox::wbt_wetness_index or terra flow accumulation).

4. **Soil Family** (US4-P2): Implement `indicator_soil_fertility()` extracting BD Sol fertility classes via exactextractr, create `indicator_soil_erosion()` combining slope (terra::terrain) with land cover for risk index (0-100 scale).

5. **Landscape Family** (US5-P2): Refactor existing fragmentation indicator into `indicator_landscape_fragmentation()` (patch metrics via landscapemetrics or manual sf analysis), add `indicator_landscape_edge()` (perimeter/area ratio).

6. **Multi-Family System** (US6-P3): Extend `normalize_indicators()` to recognize family prefixes (C_, W_, F_, L_), create `create_family_index()` for weighted family scores, extend `nemeton_radar()` for 4-12 dynamic axes.

**Key Dependencies**: No new external data sources required for MVP testing (use synthetic massif_demo extensions). BD Forêt v2, BD Sol, Sentinel-2 are optional - graceful NA handling with warnings when unavailable.

**Backward Compatibility Strategy**: All v0.1.0 workflows preserved via wrapper functions, deprecated warnings for `indicator_carbon()` migration, existing massif_demo dataset untouched (create `massif_demo_temporal` variant).

---

## Technical Context

**Language/Version**: R >= 4.1.0 (constitution minimum 4.1.0, recommend 4.3.0+ for performance)

**Primary Dependencies**:
- **Spatial Core** (existing): `sf` >= 1.0-0, `terra` >= 1.7-0, `exactextractr` >= 0.9.0
- **Data Manipulation** (existing): `dplyr` >= 1.1.0, `tidyr`, `rlang` >= 1.1.0
- **Visualization** (existing): `ggplot2` >= 3.4.0, `cli` >= 3.6.0
- **New for v0.2.0**:
  - `whitebox` >= 2.3.0 (TWI calculation via `wbt_wetness_index`) - **OPTIONAL**: Fallback to terra flow accumulation if unavailable
  - `landscapemetrics` >= 2.0.0 (fragmentation metrics) - **OPTIONAL**: Manual implementation via sf if unavailable

**Storage**:
- **Data**: .rda files in `data/` (massif_demo_units, massif_demo_temporal), GeoPackage/GeoTIFF in `inst/extdata/`
- **Fixtures**: .rds files in `tests/testthat/fixtures/` for regression tests (allometric model outputs, TWI reference values)
- **External**: BD Forêt v2 (user-provided), BD Sol (user-provided), Sentinel-2 (user-provided, optional)

**Testing**:
- **Framework**: `testthat` >= 3.0.0 (existing)
- **Coverage Goal**: >= 70% (constitution minimum 80%, but spec allows 70% for MVP)
- **Test Types**:
  - Unit tests: Each new indicator function independently
  - Integration tests: Full temporal workflow (create → compute → visualize)
  - Regression tests: Allometric models against IFN reference values (fixtures)
  - Edge case tests: Missing data, zero values, extreme TWI, partial family scores

**Target Platform**:
- Cross-platform R package (Linux, macOS, Windows)
- Primary development: Linux (Ubuntu 22.04 LTS)
- CI/CD: GitHub Actions (R-CMD-check on all platforms)

**Project Type**: R package (single project structure with standard R package layout)

**Performance Goals**:
- `nemeton_temporal()`: Handle 50 units × 3 periods in < 10 minutes (SC-006: 95% users)
- `indicator_water_twi()`: 100+ units with 25m DEM in < 2 minutes (SC-010)
- Maintain v0.1.0 performance: `nemeton_compute()` supports >= 1000 units (constitution requirement)

**Constraints**:
- **Backward Compatibility** (CRITICAL): All v0.1.0 workflows continue without modification (SC-015)
- **Memory**: Lazy raster loading via `nemeton_layers` (existing), no full raster loading for large datasets
- **Disk**: Package size < 5 Mo excluding vignettes (constitution: data/ < 5 Mo, fixtures < 1 Mo)
- **Test Time**: Full test suite < 5 minutes on CI (constitution: tests must be fast)
- **Documentation**: 100% roxygen2 coverage for exported functions (constitution NON-NEGOTIABLE)

**Scale/Scope**:
- **Functions**: +10-12 new exported functions (7-8 indicators + 3-4 utilities)
- **User Stories**: 6 stories (3× P1, 2× P2, 1× P3)
- **Indicators**: 10 sub-indicators total (C1, C2, W1, W2, W3, F1, F2, L1, L2 + temporal framework)
- **Test Cases**: ~100-150 new tests (maintain 70%+ coverage)
- **Vignettes**: +2 new (temporal-analysis, indicator-families)
- **LOC**: ~1500-2000 new R code lines + ~800-1000 test lines

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ **CONSTITUTIONAL COMPLIANCE - ALL GATES PASS**

#### I. Open Data First ✅
- **Compliance**: All new indicators support open data sources (IGN BD Forêt/BD Sol, Copernicus Sentinel-2, OpenStreetMap streams)
- **Evidence**: Spec documents graceful NA handling when proprietary data unavailable (FR-009, FR-023)
- **Vignettes**: Will use synthetic massif_demo extensions (no proprietary data in examples)

#### II. Interopérabilité R Spatial (NON-NÉGOCIABLE) ✅
- **Compliance**: All new functions use `sf` for vectors, `terra` for rasters, `exactextractr` for zonal statistics
- **Evidence**: Architecture uses existing R/data-units.R (sf), R/data-layers.R (terra), no reinvention
- **Tidyverse**: All functions pipe-friendly (`%>%` and `|>` compatible)

#### III. Modularité et Séparation des Responsabilités ✅
- **Compliance**: Clear module separation maintained
  - Temporal: New `R/temporal.R` module (nemeton_temporal, calculate_change_rate)
  - Indicators: Extend `R/indicators-core.R` with family-specific functions
  - Normalization: Extend `R/normalization.R` with family awareness
  - Visualization: Extend `R/visualization.R` with temporal plots
- **Function Size**: No function > 300 lines (will refactor allometric equations into lookup table)

#### IV. Test-First avec Fixtures (NON-NÉGOCIABLE) ✅
- **Compliance**: TDD approach mandated in implementation
  - Fixtures required for allometric model validation (FR-040: reference calculations)
  - Each exported function requires unit test (40 new FR → 40+ test cases minimum)
- **Coverage**: >= 70% target (spec), >= 80% ideal (constitution)
- **Regression**: Fixtures for C1 biomass (IFN values), TWI (validated datasets)

#### V. Transparence et Traçabilité ✅
- **Compliance**: All indicator parameters explicit
  - Allometric equations documented in roxygen2 (species, formula source)
  - TWI algorithm documented (D-infinity vs D8)
  - Family weights documented (default + customizable)
- **Metadata**: Temporal datasets include period labels, dates, alignment flags (Key Entity: Temporal Dataset)

#### VI. Extensibilité par Design ✅
- **Compliance**: New indicators use same public API as v0.1.0 indicators
  - `indicator_*()` pattern consistent
  - `create_family_index()` accepts custom weights
  - No closed list: users can add custom indicators via existing `nemeton_compute()` inline functions

#### VII. Simplicité et YAGNI ✅
- **Compliance**: MVP approach, no over-engineering
  - C2 NDVI: Optional, returns NA if no Sentinel-2 (not forcing preprocessing)
  - Whitebox TWI: Optional dependency with terra fallback
  - No uncertainty quantification yet (deferred to v0.3.0)
- **Evidence**: "Hors Scope" section clearly defers advanced features (Shiny, Monte Carlo, ML)

### Stack Compliance ✅

**Obligatoire** (all present):
- ✅ R >= 4.1.0
- ✅ `sf` >= 1.0-0
- ✅ `terra` >= 1.7-0 (no `raster` legacy)
- ✅ `exactextractr` >= 0.9.0
- ✅ `dplyr` >= 1.1.0
- ✅ `ggplot2` >= 3.4.0
- ✅ `rlang` >= 1.1.0
- ✅ `cli` >= 3.6.0

**Interdit** (none violated):
- ✅ No `raster` package usage
- ✅ No `sp` package usage
- ✅ No proprietary/closed dependencies

### Nommage (NON-NÉGOCIABLE) ✅
- ✅ Exported functions: `nemeton_temporal()`, `create_family_index()` (nemeton_ prefix)
- ✅ Indicators: `indicator_carbon_biomass()`, `indicator_water_twi()`, etc. (indicator_ prefix)
- ✅ S3 classes: Temporal datasets extend `nemeton_units` class
- ✅ Files: `R/temporal.R`, `R/indicators-families.R` (hyphens)
- ✅ Tests: `test-temporal.R`, `test-indicators-families.R`

### Documentation (NON-NÉGOCIABLE) ✅
- ✅ roxygen2 mandatory for all 10-12 new exported functions
- ✅ Executable `@examples` for all (constitution requirement)
- ✅ +2 vignettes planned (temporal-analysis, indicator-families)
- ✅ pkgdown site will be updated automatically

### **GATE VERDICT**: ✅ **ALL CLEAR - PROCEED TO PHASE 0**

No constitutional violations. No complexity tracking required.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-v0.2.0/
├── plan.md              # This file ✅ (you are here)
├── spec.md              # Feature specification ✅ (completed)
├── checklists/
│   └── requirements.md  # Spec quality validation ✅ (completed)
├── research.md          # Phase 0 output (next)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT by /speckit.plan)
```

### Source Code (R package structure - existing nemeton v0.1.0)

```text
nemeton/                           # Repository root
├── R/                             # Source code
│   ├── data-units.R               # EXISTING: nemeton_units S3 class
│   ├── data-layers.R              # EXISTING: nemeton_layers lazy-loading
│   ├── data-preprocessing.R       # EXISTING: harmonize_crs, crop, mask
│   ├── indicators-core.R          # EXTEND: Add 5 existing + deprecate indicator_carbon
│   ├── indicators-families.R      # NEW: Family-specific indicators (C, W, F, L)
│   ├── temporal.R                 # NEW: nemeton_temporal, calculate_change_rate
│   ├── normalization.R            # EXTEND: Add family awareness
│   ├── composite.R                # EXTEND: Add create_family_index
│   ├── visualization.R            # EXTEND: Add temporal plots, extend radar
│   ├── nemeton-class.R            # EXISTING: print/summary methods
│   ├── utils.R                    # EXTEND: Add helpers for allometric models
│   └── i18n.R                     # EXTEND: Add messages for new indicators
│
├── data/                          # Packaged datasets
│   ├── massif_demo_units.rda      # EXISTING: 20 parcels (v0.1.0)
│   └── massif_demo_temporal.rda   # NEW: Multi-period extension (if feasible)
│
├── inst/extdata/                  # External data for examples
│   ├── massif_demo/               # EXISTING: Rasters + vectors (v0.1.0)
│   │   ├── rasters/               #   biomass.tif, dem.tif, landcover.tif, richness.tif
│   │   └── vectors/               #   roads.gpkg, watercourses.gpkg
│   └── 360053000AS0090.gpkg       # EXISTING: Real cadastral parcel (tests)
│
├── tests/testthat/                # Test suite
│   ├── fixtures/                  # Test data
│   │   ├── allometric_reference.rds   # NEW: IFN biomass validation data
│   │   ├── twi_reference.rds          # NEW: Validated TWI values
│   │   └── temporal_test_data.rds     # NEW: Multi-period test dataset
│   ├── helper-fixtures.R          # EXISTING: Test helpers
│   ├── test-temporal.R            # NEW: Temporal infrastructure tests
│   ├── test-indicators-families.R # NEW: C, W, F, L indicator tests
│   ├── test-normalization.R       # EXTEND: Family index tests
│   ├── test-visualization.R       # EXTEND: Temporal plots, radar tests
│   └── [existing test files]      # EXISTING: 359 tests (v0.1.0)
│
├── vignettes/                     # Documentation
│   ├── getting-started.Rmd        # EXISTING: Basic workflow (v0.1.0)
│   ├── internationalization.Rmd   # EXISTING: i18n guide (v0.1.0)
│   ├── temporal-analysis.Rmd      # NEW: Multi-period analysis workflow
│   └── indicator-families.Rmd     # NEW: 12-family framework guide
│
├── man/                           # Generated documentation (roxygen2)
│   └── [auto-generated .Rd files]
│
├── DESCRIPTION                    # EXTEND: Add whitebox, landscapemetrics suggests
├── NAMESPACE                      # EXTEND: Export new functions
└── README.md                      # EXTEND: Add v0.2.0 examples

```

**Structure Decision**: Standard R package structure (single project) following constitution requirements. All new functionality extends existing modules or adds focused new modules (temporal.R, indicators-families.R). No architectural changes needed - v0.1.0 structure is sound and constitutional-compliant.

**Key Module Responsibilities**:
- `R/temporal.R`: Multi-period dataset management, change rate calculations
- `R/indicators-families.R`: Family-specific indicator implementations (C1, C2, W1-W3, F1-F2, L1-L2)
- `R/normalization.R` (extended): Family-aware normalization, create_family_index()
- `R/visualization.R` (extended): Temporal time-series plots, extended radar for 4-12 axes

---

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations** - This section intentionally left empty.

All constitutional requirements met without exceptions. No complexity justification needed.
