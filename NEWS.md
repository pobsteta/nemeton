# nemeton 0.14.0

**Date**: 2026-02-10

### Test Suite Stabilization

#### Bug Fixes

* Fixed ExtendedTask global state leak in mod_home retry test that blocked
  mod_project testServer calls when running the full test suite
  - Mock `promises::future_promise` to prevent multisession worker spawning
  - Return terminal state from `read_progress_state` to stop `later::later` polling loop
  - Restore `future::plan` on exit via `withr::defer`
* Suppressed expected warnings in test-workflow, test-visualization,
  test-mod_map, and test-mod_synthesis
* Renamed test files with z/zz prefix for stable execution ordering

#### Documentation

* Added Mistral API key example in nemetonApp guide vignette

#### Tests

* All 9272 tests passing (0 warnings)
* R CMD check: 0 errors, 0 warnings

---

# nemeton 0.13.0

**Date**: 2026-02-08

### CI/CD Optimization

* Optimized CI workflow with timeout, split check and coverage jobs
* Suppressed expected warnings in test suite (normalize, locale patterns)
* Fixed French locale support in match.arg error patterns

---

# nemeton 0.12.0

**Date**: 2026-02-05

### Phase 9 Finalization - MVP 0.7.0 Complete

#### New Features

* **PDF Report Generation** (`generate_report_pdf()`)
  - Quarto-based reports with professional layout
  - Fallback to base R graphics when Quarto unavailable
  - Automatic Quarto installation via `ensure_quarto_installed()`
  - Bilingual support (French/English)

* **GeoPackage Export** (`export_geopackage()`)
  - Export family scores with geometry for GIS analysis
  - Full spatial data preservation

* **nemetonApp Synthesis Tab**
  - AI-generated analysis with expert profiles
  - Integrated comment editor
  - Real-time PDF generation with progress indicator

#### Documentation

* New vignette: "Guide de l'Application nemetonApp"
* Updated README with nemetonApp section
* Enhanced pkgdown reference for Shiny functions

#### Bug Fixes

* Fixed TWI normalization windows for F2 soil fertility ([2.5, 10] range)
* Fixed R3 drought risk raster extent mismatch
* Fixed non-ASCII characters in service_export.R
* Added data.table to Suggests for fasterRaster compatibility

#### Tests

* All 3447 tests passing
* R CMD check: 0 errors, 0 warnings, 2 notes


# nemeton 0.8.0

**Date**: 2026-01-25

### New Features

#### nemetonApp - Interactive Shiny Application

* **`run_app()`** - Launch the nemetonApp Shiny application
  - Interactive parcel selection on a map (Leaflet)
  - French commune search with autocomplete
  - Calculate all 31 nemeton indicators automatically
  - Visualize results with 12-family radar charts
  - Export PDF reports and GeoPackage data
  - Bilingual support (French/English)

* **Application Architecture**
  - `app_ui.R` - bslib-based responsive UI with Bootstrap 5
  - `app_server.R` - Modular server with reactive state management
  - `app_config.R` - Configuration constants and indicator families
  - `utils_theme.R` - WCAG 2.1 AA accessible theme
  - `utils_i18n.R` - Internationalization with 200+ messages

* **Accessibility (WCAG 2.1 AA)**
  - Color contrast ratio >= 4.5:1 for text
  - Colorblind-friendly viridis palettes
  - Minimum touch target 44×44px
  - Focus visible indicators
  - Keyboard navigation support

* **Data Services**
  - `service_communes.R` - French commune search API
  - `service_cadastre.R` - Cadastral parcel retrieval
  - `service_project.R` - Project management and persistence

### Bug Fixes

* Fixed `\dontrun` missing brace in service_communes.R documentation
* Fixed integer type for symbol_shapes in accessibility config
* Updated indicator count test (29 → 31 indicators)

### Dependencies

* Added `shiny (>= 1.8.0)` to Imports
* Added `bslib (>= 0.6.0)` to Imports
* Added `htmltools (>= 0.5.7)` to Imports
* Added `leaflet (>= 2.1.0)` to Suggests
* Added `cicerone (>= 1.0.0)` to Suggests (guided tour)
* Added `shinyWidgets (>= 0.8.0)` to Suggests
* Added `rappdirs` to Suggests (project directories)

---

# nemeton 0.6.2

**Date**: 2026-01-24

### Changes

- **Data consolidation**: Merged `massif_demo_units` and `massif_demo_units_extended` into a single dataset with 89 columns (29 indicators, 12 family composites, normalized values)
- **Tests**: Fixed 19 skipped tests, now 1478 tests passing (0 skipped)
- **Documentation**: Simplified README from 846 to 138 lines
- **Fixtures**: Added synthetic cadastral file for integration tests

---

# nemeton 0.6.1

**Date**: 2026-01-23

### Changes

- Fix pkgdown references to obsolete v0.1.0 indicators
- Add lasR remote for GitHub Actions CI

---

# nemeton 0.6.0 (Development)

## v0.6.0 - Legacy Indicators Removal

**Date**: 2026-01-23

### BREAKING CHANGES ⚠️

**Removed Legacy Indicators (v0.1.0)**

The original 5 MVP indicators have been removed in favor of the comprehensive 12-family framework (32+ indicators). This is a breaking change for code using v0.1.0 indicators.

#### Removed Functions

- `indicator_carbon()` - **Use instead:** `indicator_carbon_biomass()` (C1) or `indicator_carbon_ndvi()` (C2)
- `indicator_biodiversity()` - **Use instead:** `indicator_biodiversity_protection()` (B1), `indicator_biodiversity_structure()` (B2), or `indicator_biodiversity_connectivity()` (B3)
- `indicator_water()` - **Use instead:** `indicator_water_network()` (W1), `indicator_water_wetlands()` (W2), or `indicator_water_twi()` (W3)
- `indicator_fragmentation()` - **Use instead:** `indicator_landscape_fragmentation()` (L1) or `indicator_landscape_edge()` (L2)
- `indicator_accessibility()` - **Use instead:** `indicator_social_accessibility()` (S2) or `indicator_social_trails()` (S1)

#### Migration Guide

**Before (v0.1.0-v0.5.x):**
```r
# Old API
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon", "biodiversity", "water")
)
```

**After (v0.6.0+):**
```r
# New API with family-based indicators
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon_biomass", "biodiversity_protection", "water_twi")
)

# Or use list_indicators() to see all available indicators
available <- list_indicators(return_type = "details")
```

#### Updated Core Functions

- `nemeton_compute()` - Now uses `list_indicators()` for available indicators
- `list_indicators()` - Returns all 31 indicators from the 12-family framework
- `compute_indicator()` - Dynamic dispatch supporting all family-based indicators

#### Files Removed

- `R/indicators-biophysical.R` - Legacy indicator implementations (567 lines)
- `tests/testthat/test-indicators-biophysical.R` - Legacy tests (414 lines, 26 tests)

### Rationale

The legacy indicators were functional placeholders from the v0.1.0 MVP. The new 12-family framework (introduced in v0.2.0-v0.4.0) provides:

- **More comprehensive coverage**: 31 indicators vs 5
- **Better scientific foundation**: Species-specific allometric models, multiple data sources
- **Clearer organization**: 12 families (C, W, F, L, B, R, T, A, S, P, E, N)
- **Improved flexibility**: Multiple sub-indicators per ecosystem service

All legacy indicators had superior replacements available since v0.2.0 (January 2026).

---

# nemeton 0.5.2

## v0.5.2 - Tutorial 09 Sampling + TSP

**Date**: 2026-01-23

### New Features

#### Tutorial 09: Échantillonnage de calibration LiDAR HD + TSP (180 min)

* **Dimensionnement optimal** - Calcul du nombre de placettes basé sur la formule n = t² × CV² / E²
  - Fonctions `calculate_sample_size()` et `sample_size_table()`
  - Tableau de référence interactif pour CV (10-40%) et erreur (5-20%)
  - Correction pour population finie

* **Sampling Frame** - Construction d'une grille de candidats avec contraintes terrain
  - Filtrage par couvert forestier (≥70%) et pente (≤45%)
  - Utilisation des données T01/T03/T07 (zone_etude, bd_foret, mnt, chm_complet)

* **Stratification triple** - Basée sur 3 critères forestiers
  - **Hauteur CHM LiDAR** : 4 classes (H1-H4) par quartiles
  - **Type de peuplement** (BD Forêt v2 tfv) : FEU/CON/MIX/POP/AUT
  - **Position topographique** (TPI) : Bas/Milieu/Haut de pente
  - Calcul TPI avec `focal()` (rayon 100m)

* **Tirage GRTS stratifié** - Échantillonnage spatialement équilibré
  - Package `spsurvey::grts()` avec allocation proportionnelle
  - Oversample par strate pour placettes de remplacement
  - Fallback `BalancedSampling::lpm2` si GRTS échoue

* **Réseau de chemins** - Construction réseau avec `sfnetworks` depuis BD TOPO
  - Filtrage chemins praticables à pied
  - Calcul poids avec `edge_length()`

* **Optimisation TSP** - Parcours optimal avec package `TSP`
  - Méthode nearest insertion + 2-opt
  - Visualisation avec distinction Base/Remplacement

* **Export terrain** - Formats multiples pour GPS
  - GeoPackage (SIG)
  - GPX (navigation GPS)
  - CSV (tableau récapitulatif avec coordonnées WGS84)

### Improvements

* **Harmonisation data_dir** - Chemin unifié sur tous les tutoriels T01-T09
  - `~/.local/share/nemeton/tutorial_data`
  - Suppression variable `cache_dir` dans T08

### Dependencies

* Added `spsurvey (>= 5.0.0)` to Suggests
* Added `BalancedSampling (>= 1.6.0)` to Suggests
* Added `sfnetworks (>= 0.6.0)` to Suggests
* Added `TSP (>= 1.2.0)` to Suggests
* Added `tidygraph (>= 1.2.0)` to Suggests
* Added `igraph (>= 1.4.0)` to Suggests

### Documentation

* Updated `vignettes/tutorial-guide.Rmd` with Tutorial 09
* Updated `TUTORIAL_INSTALL.md` with Tutorial 09

**References**:
- Stevens, D. L., & Olsen, A. R. (2004). Spatially balanced sampling of natural resources. *JASA*, 99(465), 262-278.
- Grafström, A., & Tillé, Y. (2013). Doubly balanced spatial sampling with spreading and restitution of auxiliary totals. *Environmetrics*, 24(2), 120-131.
- Hahsler, M., & Hornik, K. (2007). TSP—Infrastructure for the traveling salesperson problem. *Journal of Statistical Software*, 23(2).

---

# nemeton 0.5.1

## v0.5.1 - Tutorial 08 Coregistration

**Date**: 2025-01-18

### New Features

#### Tutorial 08: Coregistration LiDAR/Terrain (130 min)

* **Problématique GPS** - Précision GPS sous couvert forestier (2-10 m)
* **Corrélation MNH/Terrain** - Recalage par corrélation croisée
* **lidaRtRee::coregistration()** - Recherche translation optimale (dx, dy)
* **Traitement parallèle** - `future_lapply()` pour lots de placettes
* **Analyse statistique** - Tests de significativité, visualisation vecteurs
* **Export** - CSV et GeoPackage pour utilisation SIG

### Documentation

* Updated `vignettes/tutorial-guide.Rmd` with Tutorial 08
* Updated `TUTORIAL_INSTALL.md` with Tutorial 08

**Reference**: Monnet, J.-M., & Mermin, É. (2014). Cross-correlation of diameter measures for the co-registration of forest inventory plots with airborne laser scanning data. *Forests*, 5(9), 2307-2326.

---

# nemeton 0.5.0

## v0.5.0 - Tutorial 07 & CRAN Compliance

**Date**: 2025-01-18

### Overview

Release featuring the complete Tutorial 07 (Advanced LiDAR) and CRAN compliance improvements. All 7 interactive tutorials are now complete (195/195 tasks).

### New Features

#### Tutorial 07: LiDAR Avancé (90 min)

* **LAScatalog Management** - Multi-tile LiDAR processing with lidR
* **lasR Pipelines** - Ultra-fast C++ processing for DTM/CHM generation
* **Individual Tree Detection (ITD)** - Tree segmentation with lidaRtRee
* **Gap & Edge Detection** - Forest structure analysis
* **Area-Based Approach (ABA)** - Model calibration and wall-to-wall prediction
* **BABA Exploration** - Rapid LiDAR metrics without field calibration
* **Parallelization** - `future_lapply()` for tile-based processing
* **Incremental Caching** - Resume interrupted processing
* **OSO Forest Mask** - Land cover filtering for predictions

### Dependencies

* Added `lasR` to Suggests (from r-lidar.r-universe.dev)
* Added `lidaRtRee` to Suggests

### Documentation

* Updated `vignettes/tutorial-guide.Rmd` with Tutorial 07
* Updated `TUTORIAL_INSTALL.md` with lasR/lidaRtRee installation
* Updated quickstart guide with Tutorial 07 instructions

### CRAN Compliance

* Removed development artifacts (RELEASE_*.md, .RData, .Rhistory, etc.)
* Updated `.Rbuildignore` and `.gitignore`
* Excluded spec-kit directories from version control

---

# nemeton 0.4.0

## v0.4.0 - Complete 12-Family Ecosystem Services Referential

**Date**: 2026-01-05

### Overview

Major release completing the **12-family ecosystem services referential** with 4 new indicator families (S, P, E, N) and advanced multi-criteria analysis tools. This release adds 11 new indicator functions, 3 analysis functions, and brings the total to **29 indicators across 12 families**.

### New Indicator Families

#### Social & Recreational Family (Famille S) - 3 Indicators

* **`indicator_social_trails()`** (S1) - Trail density
  - Calculates recreational trail density (km/ha) from OSM or local data
  - Supports footways, cycleways, and bridleways
  - Output: 0-5+ km/ha trail density

* **`indicator_social_accessibility()`** (S2) - Multimodal accessibility score
  - Distance-based scoring for road, parking, and public transport access
  - Configurable distance thresholds and weights
  - Output: 0-100 accessibility score

* **`indicator_social_proximity()`** (S3) - Population proximity
  - Population within configurable buffer zones (5/10/20 km)
  - Supports INSEE population grid or custom data
  - Output: Total population count within buffers

#### Productive & Economic Family (Famille P) - 3 Indicators

* **`indicator_productive_volume()`** (P1) - Standing timber volume
  - IFN-based allometric equations by species
  - Genus-level fallback for rare species
  - Output: m³/ha standing volume

* **`indicator_productive_station()`** (P2) - Site productivity index
  - Fertility × climate × species interaction
  - Based on French forestry station classification
  - Output: m³/ha/yr potential productivity

* **`indicator_productive_quality()`** (P3) - Timber quality score
  - Form factor, diameter distribution, defect assessment
  - Configurable quality criteria weights
  - Output: 0-100 quality score

#### Energy & Climate Family (Famille E) - 2 Indicators

* **`indicator_energy_fuelwood()`** (E1) - Fuelwood potential
  - Harvest residues + coppice biomass estimation
  - Species-specific conversion factors
  - Output: tonnes DM/ha/yr mobilizable fuelwood

* **`indicator_energy_avoidance()`** (E2) - CO2 emission avoidance
  - ADEME emission factors for energy substitution
  - Supports energy and material substitution scenarios
  - Output: tCO2eq/ha/yr avoided emissions

#### Naturalness & Wilderness Family (Famille N) - 3 Indicators

* **`indicator_naturalness_distance()`** (N1) - Infrastructure distance
  - Distance to roads, buildings, powerlines from OSM
  - Minimum distance to nearest infrastructure
  - Output: meters to nearest infrastructure

* **`indicator_naturalness_continuity()`** (N2) - Forest patch continuity
  - Connected forest area calculation
  - Based on landscape patch analysis
  - Output: hectares of continuous forest

* **`indicator_naturalness_composite()`** (N3) - Wilderness composite index
  - Multiplicative aggregation of N1 × N2 × T1 × B1
  - Weighted aggregation option available
  - Output: 0-100 wilderness score

### New Analysis Functions

#### Multi-Criteria Decision Support

* **`identify_pareto_optimal()`** - Pareto optimality analysis
  - Identifies non-dominated solutions across multiple objectives
  - Supports both maximization and minimization objectives
  - Returns data with `is_optimal` column for Pareto-optimal parcels

* **`cluster_parcels()`** - Multi-family clustering
  - K-means and hierarchical clustering methods
  - Automatic optimal k determination via silhouette analysis
  - Returns cluster assignments with centroid profiles

* **`plot_tradeoff()`** - Trade-off visualization
  - 2D scatterplot with optional Pareto frontier overlay
  - Color and size mapping for additional dimensions
  - Label support for parcel identification

### Enhanced Features

* **12-axis radar plots** - `nemeton_radar()` now supports all 12 families
* **12×12 correlation matrix** - `compute_family_correlations()` extended
* **12-family hotspot detection** - `identify_hotspots()` updated
* **Normalization presets** - Added for S, P, E, N families

### New Demo Dataset

* **`massif_demo_units_extended`** - Complete 12-family reference dataset
  - 20 demo parcels with all 29 indicators
  - 12 pre-calculated family composite indices
  - Synthetic but realistic value distributions

### New Vignettes

* **`complete-referential_fr.Rmd`** - 12-family workflow demonstration
* **`multi-criteria-optimization_fr.Rmd`** - Pareto, clustering, and trade-off analysis

### Dependencies

* Added `cluster` package dependency for silhouette analysis
* Added `ggrepel` to Suggests for label positioning

### Documentation

* Updated README with v0.4.0 feature highlights
* Updated pkgdown site configuration
* Full roxygen2 documentation for all new functions

---

# nemeton 0.3.0 (Development)

## v0.3.0 MVP - Multi-Family Extension (B, R, T, A)

**Status**: ✅ v0.3.0 Complete (845+ tests passing, 100% backward compatible)

### Overview

Extension of the ecosystem service indicator framework with 4 new families (B, R, T, A), bringing the total to **9 of 12 planned families** implemented. This release adds 10 new indicator functions and enhances the family aggregation and visualization system.

### New Indicator Families

#### Biodiversity Family (Famille B) - 3 Indicators

* **`indicator_biodiversity_protection()`** (B1) - Protected area coverage
  - Calculates percentage of forest parcel within protected zones (ZNIEFF, Natura2000, etc.)
  - Supports local or remote protected area datasets
  - Output: 0-100% protection coverage
  - Spatial overlay with area-weighted calculation

* **`indicator_biodiversity_structure()`** (B2) - Structural diversity index
  - Shannon diversity index across vegetation strata, age classes, and species
  - Configurable weights for each diversity component (default: strata 0.4, age 0.3, species 0.3)
  - Optional height coefficient of variation (CV) integration
  - Output: 0-100 diversity score
  - Handles monoculture scenarios (low diversity → low scores)

* **`indicator_biodiversity_connectivity()`** (B3) - Ecological connectivity
  - Distance to ecological corridors (TVB - Trame Verte et Bleue)
  - Supports edge and centroid distance methods
  - Configurable max distance threshold (default: 5000m)
  - Fallback scoring when corridor data unavailable
  - Output: Distance in meters (lower = better connectivity)

#### Risk & Resilience Family (Famille R) - 3 Indicators

* **`indicator_risk_fire()`** (R1) - Fire risk index
  - Multi-factor fire susceptibility: slope + species + climate
  - Species flammability coefficients (conifer > broadleaf)
  - Slope amplification (higher slope = faster fire spread)
  - Optional climate data integration (temperature, precipitation)
  - Output: 0-100 risk score (higher = more vulnerable)

* **`indicator_risk_storm()`** (R2) - Storm vulnerability index
  - Wind damage risk: tree height × stand density × exposure
  - Height coefficient (taller trees more vulnerable)
  - Density factor (dense stands = higher windthrow risk)
  - Topographic exposure from DEM (exposed ridges = higher risk)
  - Output: 0-100 vulnerability score

* **`indicator_risk_drought()`** (R3) - Drought stress index
  - Combines water availability (TWI) and species drought tolerance
  - Species tolerance coefficients (drought-resistant vs. water-demanding)
  - Optional precipitation data integration
  - Low TWI + intolerant species = high stress
  - Output: 0-100 stress score

#### Temporal Dynamics Family (Famille T) - 2 Indicators

* **`indicator_temporal_age()`** (T1) - Stand age/ancientness
  - Historical forest age from BD Forêt or Cassini maps
  - Ancient forest detection (age > 150 years)
  - Supports multi-source age estimation
  - Output: Years since establishment (or age class)
  - Handles missing historical data gracefully

* **`indicator_temporal_change()`** (T2) - Land cover change rate
  - Temporal change detection using Corine Land Cover multi-dates
  - Calculates change rate between two periods
  - Supports custom date ranges
  - Identifies stable vs. dynamic forests
  - Output: % change per year (or absolute area change)
  - Leverages existing nemeton_temporal() infrastructure

#### Air Quality & Microclimate Family (Famille A) - 2 Indicators

* **`indicator_air_coverage()`** (A1) - Tree canopy coverage
  - Percentage of tree cover within 1km buffer
  - High-resolution vegetation data (sentinel-2 or lidar-derived)
  - Urban microclimate regulation potential
  - Output: 0-100% coverage in buffer zone
  - Supports custom buffer distances

* **`indicator_air_quality()`** (A2) - Air quality index
  - Integration with ATMO air quality data (when available)
  - Fallback: distance to pollution sources (roads, industry)
  - Supports custom air quality datasets
  - Output: 0-100 air quality score (higher = better)
  - Proxy mode for areas without monitoring stations

### Extended Functions

* **`create_family_index()` - New "min" aggregation method**
  - Added conservative worst-case aggregation: `method = "min"`
  - Useful for risk assessment (score = worst sub-indicator)
  - Joins existing methods: mean, weighted, geometric, harmonic
  - Example: `create_family_index(data, method = "min")`

* **`nemeton_radar()` - Comparison mode for multiple units**
  - New: compare multiple forest parcels on same radar chart
  - Overlaid polygons for visual comparison
  - Syntax: `nemeton_radar(data, unit_id = c(1, 5, 10), mode = "family")`
  - Supports 9-12 axes dynamically (adapts to available families)
  - Enhanced legend and color differentiation

### Testing

* **186 new tests** for v0.3.0 families
  - Biodiversity (B1-B3): 56 tests (protection zones, diversity indices, corridors)
  - Risk (R1-R3): 52 tests (fire models, storm factors, drought stress)
  - Temporal (T1-T2): 38 tests (historical data, change detection)
  - Air (A1-A2): 28 tests (coverage buffers, quality indices)
  - Integration: 12 tests (multi-family workflows, normalization, radar)

* **Total test suite: 845+ tests passing** (up from 659)
* **100% backward compatibility verified** with v0.2.0 workflows

### Use Cases

* **Conservation prioritization**: Identify high biodiversity + low risk parcels
* **Climate adaptation planning**: Map drought stress + storm vulnerability
* **Urban forestry**: Quantify air quality and microclimate benefits
* **Historical ecology**: Detect ancient forests + track land use change
* **Multi-criteria decision support**: 9-family composite indices for holistic management

### Implemented Families Status (9/12)

* ✅ **C** - Carbon & Vitality (C1-C2)
* ✅ **B** - Biodiversity (B1-B3) - **NEW v0.3.0**
* ✅ **W** - Water Regulation (W1-W3)
* ✅ **A** - Air Quality & Microclimate (A1-A2) - **NEW v0.3.0**
* ✅ **F** - Soil Fertility (F1-F2)
* ✅ **L** - Landscape & Aesthetics (L1-L2)
* ✅ **T** - Temporal Dynamics & Trame (T1-T2) - **NEW v0.3.0**
* ✅ **R** - Risk Management & Resilience (R1-R3) - **NEW v0.3.0**
* ⏳ **S** - Social & Recreational (planned v0.4.0)
* ⏳ **P** - Productive & Economic (planned v0.4.0)
* ⏳ **E** - Energy & Climate (planned v0.4.0)
* ⏳ **N** - Naturalness & Night (planned v0.4.0)

---

# nemeton 0.2.0 (Development)

## v0.2.0 - Phase 9: Multi-Family System (US6)

**Status**: ✅ Phase 9 Complete (659 tests passing, +46 from Phase 8)

### New Functions

#### Multi-Family Aggregation & Visualization

* **`create_family_index()`** - Family-level composite scores
  - Aggregates sub-indicators into family indices (family_C, family_W, etc.)
  - Automatic detection of family prefixes (C1, C2 → family_C)
  - 4 aggregation methods: mean, weighted, geometric, harmonic
  - Custom weights per family
  - Supports all 12 families (C, B, W, A, F, L, T, R, S, P, E, N)
  - Returns sf object with added family_* columns

### Extended Functions

* **`normalize_indicators()` family support**
  - Added `by_family` parameter for family-aware workflows
  - Auto-detection of family indicators (C1, W1, F1 pattern)
  - Backward compatible with v0.1.0 indicators (carbon, water, etc.)
  - When `by_family = TRUE`: normalizes in-place (suffix = "", keep_original = FALSE)

* **`nemeton_radar()` multi-family mode**
  - New `mode` parameter: "indicator" (default) or "family"
  - Family mode: displays 4-12 family axes dynamically
  - Auto-detects family_* columns when mode = "family"
  - Backward compatible with indicator mode
  - Enhanced unit_id handling: supports both ID matching and numeric row indices

### Helper Functions (Internal)

* **`detect_indicator_family()`** - Extract family code from indicator name
* **`get_family_name()`** - Full family name from code (bilingual FR/EN)

### Testing

* **46 new tests** for multi-family system
  - create_family_index(): 9 tests (aggregation methods, weights, NA handling)
  - normalize_indicators() family support: 3 tests (auto-detection, by_family mode)
  - nemeton_radar() family mode: 4 tests (multi-family display, validation)
  - Integration: 5 tests (end-to-end workflows, temporal integration)
  - Family detection: 2 tests (all 12 families)

* **Total test suite: 659 tests passing** (up from 613)
* **2 minor test issues**: plot data structure check, locale-dependent error message
* **Full backward compatibility maintained**

### Technical Details

* **Family Detection**: Regex pattern `^[A-Z][0-9]` matches C1, W1, F1, etc.
* **Aggregation Methods**:
  - Mean/Weighted: Handles NA values with weight renormalization
  - Geometric: `exp(mean(log(values)))` with negative value handling
  - Harmonic: `n / sum(1/x)` with zero value handling
* **12 Family Codes**:
  - C (Carbon & Vitality), B (Biodiversity), W (Water Regulation)
  - A (Air Quality & Microclimate), F (Soil Fertility), L (Landscape & Aesthetics)
  - T (Temporal Dynamics), R (Risk Management), S (Social & Recreational)
  - P (Productive & Economic), E (Energy & Climate), N (Naturalness)

### Use Cases

* **Multi-dimensional assessment**: Compare ecosystem services across 12 families
* **Custom weighting**: Priority to specific families (e.g., 60% carbon, 40% water)
* **Radar visualization**: Visual profiling of forest parcels across all families
* **Family-level reporting**: Aggregate detailed indicators into comprehensible family scores

---

## v0.2.0 - Phase 8: Infrastructure Multi-Temporelle (US1)

**Status**: ✅ Phase 8 Complete (613 tests passing)

### New Functions

#### Temporal Analysis Framework - 2 Core Functions + 2 Visualizations

* **`nemeton_temporal()`** - Multi-period temporal dataset creation
  - Combines nemeton_units objects from different time periods
  - Automatic unit alignment tracking across periods
  - Support for ISO dates and custom period labels
  - Metadata: dates, period labels, alignment status
  - Returns nemeton_temporal S3 class with print/summary methods

* **`calculate_change_rate()`** - Temporal change rate calculation
  - Computes absolute change rates (units per year)
  - Computes relative change rates (% per year)
  - Supports indicator selection or "all" indicators
  - Configurable start/end periods
  - Handles NA values appropriately
  - Returns sf object with _rate_abs and _rate_rel columns

* **`plot_temporal_trend()`** - Time-series line plots
  - Line plots showing indicator evolution over time
  - Single indicator: all units on one plot
  - Multiple indicators: faceted plots (2 columns)
  - Optional mean trend line overlay
  - Unit selection support
  - Automatic date handling from temporal metadata

* **`plot_temporal_heatmap()`** - Indicator evolution heatmap
  - Heatmap showing all indicators across periods for one unit
  - Optional normalization to 0-100 scale
  - Viridis color scale
  - Value labels on tiles
  - Indicator selection support
  - Useful for single-unit profiling

### S3 Methods

* **`print.nemeton_temporal()`** - Console summary
  - Shows number of periods and units
  - Date range if available
  - Warns about incomplete alignment
  - Lists available indicators

* **`summary.nemeton_temporal()`** - Detailed statistics
  - Per-period summaries (unit counts, indicator ranges)
  - Mean values for each indicator per period
  - Alignment information

### Technical Details

* **Temporal Framework**:
  - Unit ID tracking with configurable column (default: "parcel_id")
  - Automatic alignment detection (units present in all periods vs. incomplete)
  - Flexible date handling (ISO dates, years, or custom labels)
  - Preserves all sf attributes and geometry

* **Change Rates**:
  - Time difference calculation from dates or period names
  - Absolute rate: `(value_end - value_start) / years`
  - Relative rate: `((value_end / value_start) - 1) * 100 / years`
  - NA propagation for missing data

* **Visualizations**:
  - ggplot2-based with theme_minimal
  - Date axis with automatic formatting
  - Faceting for multiple indicators
  - Viridis colormap for heatmaps
  - Responsive layouts (legend positions, text angles)

### Testing

* **79 new tests** for temporal infrastructure
  - nemeton_temporal(): 13 tests (creation, alignment, validation)
  - calculate_change_rate(): 13 tests (absolute/relative rates, NA handling)
  - print/summary methods: 3 tests (output format)
  - plot_temporal_trend(): 11 tests (single/multiple indicators, unit selection)
  - plot_temporal_heatmap(): 10 tests (normalization, indicator selection)
  - Integration: 4 tests (multi-period workflows, 3+ periods)

* **Total test suite: 613 tests passing** (up from 584)
* **Full backward compatibility maintained**

### Use Cases

* **Longitudinal monitoring**: Track indicator evolution over 5-10+ years
* **Management impact**: Compare before/after forest intervention
* **Climate change**: Detect long-term trends in carbon stock, water regulation
* **Scenario comparison**: Visualize different management trajectories

---

## v0.2.0 - Phase 7: Famille L (Landscape/Paysage)

**Status**: ✅ Phase 7 Complete (584 tests passing)

### New Indicator Functions

#### Landscape Family (Famille L) - 2 Indicators

* **`indicator_landscape_fragmentation()`** (L1) - Forest fragmentation metric
  - Counts number of forest patches within a buffer zone around each parcel
  - Uses connected component labeling (terra::patches with 8-neighbor connectivity)
  - Configurable buffer distance (default: 1000m)
  - Configurable forest definition via landcover codes
  - Output: Number of discrete forest patches (higher = more fragmented)
  - Zero buffer option for parcel-only analysis

* **`indicator_landscape_edge()`** (L2) - Edge-to-area ratio
  - Calculates perimeter-to-area ratio for forest parcels
  - Formula: `Edge density = perimeter (m) / area (ha)`
  - Higher values indicate greater edge effect and fragmentation
  - Output: m/ha (meters of edge per hectare)
  - Uses sf geometry operations for precise boundary calculations

### Technical Details

* **L1 Fragmentation**:
  - Buffer zone creation using sf::st_buffer()
  - Landcover cropping and masking with terra
  - Forest mask creation using terra::app() with custom classification
  - Connected component analysis: terra::patches(directions = 8)
  - Handles zero-forest scenarios gracefully

* **L2 Edge Density**:
  - Boundary extraction: sf::st_cast() to MULTILINESTRING
  - Perimeter calculation: sf::st_length()
  - Area calculation: sf::st_area() converted to hectares
  - No dependencies on raster layers (geometry-only)

### Testing

* **49 new tests** for landscape family indicators
  - L1 fragmentation: 13 tests (patch counting, buffer effects, forest definitions)
  - L2 edge: 11 tests (geometry scaling, parcel size effects, validation)
  - Integration: 8 tests (combined workflow, dataframe integration, correlation analysis)
  - Edge cases: 5 tests (empty units, single parcels, full dataset)

* **Total test suite: 584 tests passing** (up from 535)
* **Full backward compatibility maintained**

---

## v0.2.0 - Phase 6: Famille F (Fertilité des Sols)

**Status**: ✅ Phase 6 Complete (535 tests passing)

### New Indicator Functions

#### Soil Family (Famille F) - 2 Indicators

* **`indicator_soil_fertility()`** (F1) - Soil fertility classification
  - Extracts fertility scores from soil data (raster or vector)
  - Supports BD Sol (French soil database) or equivalent pedological data
  - Output: 0-100 scale (higher = more fertile)
  - Auto-normalizes input values to 0-100 range
  - Supports both raster and vector soil layers (with area-weighted averaging)

* **`indicator_soil_erosion()`** (F2) - Erosion risk index
  - Calculates erosion risk by combining slope and land cover protection
  - Formula: `Risk = slope × (1 - forest_protection)`
  - High slope + low forest cover = high erosion risk
  - Output: 0-100 risk score
  - Uses terra for slope calculation and land cover analysis

### Internal Utilities

* **Soil Data Extraction**
  - `extract_fertility_from_raster()` - Raster-based fertility extraction
  - `extract_fertility_from_vector()` - Vector-based fertility with spatial join
  - Area-weighted averaging for overlapping soil polygons
  - Automatic CRS harmonization

### Testing

* **37 new tests** for soil family indicators
  - F1 fertility: 11 tests (raster/vector extraction, normalization, error handling)
  - F2 erosion: 17 tests (slope-cover combination, forest definitions, edge cases)
  - Integration: 9 tests (combined workflow, correlation analysis, dataframe integration)
  - 1 skipped test (vector soil data - future enhancement)

* **Total test suite: 535 tests passing** (up from 498)
* **Full backward compatibility maintained**

### Technical Details

* **F1 Fertility**:
  - Flexible input: accepts any raster or vector soil layer
  - Linear normalization: `(value - min) / (max - min) × 100`
  - Vector mode: area-weighted spatial join with soil polygons
* **F2 Erosion**:
  - Slope from DEM using `terra::terrain(v="slope")`
  - Forest mask using `terra::app()` for multi-value classification
  - Protection factor: 1 = full forest, 0 = no forest
  - Normalized to 0-100 scale (max slope = 90°)

---

## v0.2.0 - Phase 5: Famille W (Eau/Infiltrée)

**Status**: ✅ Phase 5 Complete (498 tests passing)

### New Indicator Functions

#### Water Family (Famille W) - 3 Indicators

* **`indicator_water_network()`** (W1) - Hydrographic network density
  - Calculates stream/river network length density within or near forest parcels
  - Supports buffer distance parameter for proximity analysis
  - Output: km/ha (kilometers of watercourse per hectare)
  - Higher values = greater hydrological connectivity

* **`indicator_water_wetlands()`** (W2) - Wetland coverage percentage
  - Calculates percentage of parcel area classified as wetland or riparian zone
  - Supports multiple wetland type codes from landcover rasters
  - Output: 0-100% coverage
  - Area-weighted calculation using coverage fractions

* **`indicator_water_twi()`** (W3) - Topographic Wetness Index
  - Calculates TWI using terra D8 flow algorithm
  - Formula: `TWI = ln(catchment_area / tan(slope))`
  - Automatically handles flat areas and edge cases
  - Output: TWI values (typically 0-20, higher = wetter areas)
  - Future: whitebox D-infinity algorithm support (v0.3.0+)

### Internal Utilities

* **TWI Calculation System**
  - `calculate_twi_terra()` - D8 flow direction algorithm
  - Slope-based flow accumulation
  - Catchment area calculation
  - Handles numerical edge cases (flat areas, infinite values)
  - `calculate_twi_whitebox()` - Placeholder for future D-infinity implementation

### Testing

* **51 new tests** for water family indicators
  - W1 network: 13 tests (density calculation, buffer zones, zero-stream parcels)
  - W2 wetlands: 14 tests (percentage calculation, multiple codes, zero coverage)
  - W3 TWI: 16 tests (DEM processing, method validation, terrain variation)
  - Integration: 8 tests (combined workflow, dataframe integration)

* **Total test suite: 498 tests passing** (up from 447)
* **Full backward compatibility maintained**

### Technical Details

* **W1 Network Density**: Uses sf spatial operations for line-polygon intersection
* **W2 Wetland Coverage**: Uses exactextractr for area-weighted raster value extraction
* **W3 TWI**: Terra hydrology functions (`terrain(v="flowdir")`, `flowAccumulation()`)
* **Flow algorithm**: D8 (8-neighbor) for computational efficiency
* **Coordinate transformations**: Automatic CRS harmonization for vector layers

---

## v0.2.0 - Phase 4: Famille C (Carbone/Énergétique)

**Status**: ✅ Phase 4 Complete (447 tests passing)

### New Indicator Functions

#### Carbon Family (Famille C) - 2 Indicators

* **`indicator_carbon_biomass()`** (C1) - Aboveground carbon stock using species-specific allometric equations
  - Requires: BD Forêt v2 attributes (species, age, density)
  - Species support: Quercus, Fagus, Pinus, Abies, + Generic fallback
  - Allometric model: `Biomass = a × Age^b × Density^c`
  - Output: tC/ha (tonnes carbon per hectare)
  - Citations: IGN/IFN literature (Dupouey, Bontemps, Vallet, Wutzler)

* **`indicator_carbon_ndvi()`** (C2) - Vegetation vitality via NDVI
  - Requires: Sentinel-2 or equivalent NDVI raster (0-1 scale)
  - Output: Mean NDVI per forest parcel
  - Future: Temporal trend analysis (v0.3.0+)

### Internal Data & Utilities

* **Allometric Model System** (`R/sysdata.rda`)
  - 5 species-specific coefficient sets
  - Calibrated for realistic French forest biomass (50-200 tC/ha mature stands)
  - Source: `data-raw/allometric_models.R`

* **New Utility Functions** (internal)
  - `get_allometric_coefficients()` - Species-specific coefficient lookup
  - `calculate_allometric_biomass()` - Vectorized biomass calculation
  - `detect_indicator_family()` - Extract family code from indicator name
  - `get_family_name()` - Full family name from code

### Deprecations

* **`indicator_carbon()`** - Now deprecated (will be removed in v1.0.0)
  - Replacement: Use `indicator_carbon_biomass()` for BD Forêt support, or `indicator_carbon_ndvi()` for NDVI
  - Backward compatibility: Function still works with deprecation warning
  - All existing workflows continue to function

### Testing

* **38 new tests** for carbon family indicators
  - C1 biomass: 15 tests (allometric calculations, NA handling, column names, Generic fallback)
  - C2 NDVI: 10 tests (raster extraction, edge values, trend warning)
  - Integration: 8 tests (backward compatibility, nemeton_compute integration)
  - Edge cases: 5 tests (missing columns, invalid inputs, error messages)

* **Total test suite: 447 tests passing** (up from 409)
* **Full backward compatibility verified**

### Technical Details

* **Allometric coefficients** calibrated to produce realistic biomass values:
  - Young/sparse stands: 2-10 tC/ha
  - Mature forests: 50-200 tC/ha
  - Age exponent (b): 1.55-1.75
  - Density exponent (c): 0.80-0.90

* **NA propagation**: Properly handles missing species, age, or density data

---

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
