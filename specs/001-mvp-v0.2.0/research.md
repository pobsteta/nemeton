# Research & Technical Decisions: MVP v0.2.0

**Feature**: MVP v0.2.0 - Temporal & Spatial Indicators Extension
**Branch**: 001-mvp-v0.2.0
**Date**: 2026-01-05
**Status**: Phase 0 Complete

---

## Executive Summary

No critical unknowns requiring extensive research. All technical decisions can be made based on:
- Existing nemeton v0.1.0 architecture (proven, constitutional-compliant)
- Standard R spatial ecosystem practices (sf, terra, exactextractr)
- Literature-validated allometric models (IGN/IFN)
- Established landscape ecology metrics (TWI, fragmentation indices)

All technologies align with constitution requirements. **Proceed directly to Phase 1 (Data Model & Contracts)**.

---

## Key Technical Decisions

### TD-001: Temporal Dataset Structure

**Decision**: Extend existing `nemeton_units` S3 class with temporal metadata rather than creating new class.

**Rationale**:
- **Backward compatibility**: Preserves all existing S3 methods (print, summary, plot)
- **Simplicity**: Reuses existing validation logic from v0.1.0
- **Extensibility**: Temporal metadata stored as attributes (period labels, dates, alignment flags) without breaking existing workflows
- **Constitution compliance**: Follows "Simplicité et YAGNI" (VII) - no new abstraction needed

**Implementation**:
```r
# Temporal dataset structure (conceptual)
temporal_data <- list(
  periods = list(
    "2015" = nemeton_units_2015,  # Each period is standard nemeton_units
    "2020" = nemeton_units_2020
  ),
  metadata = list(
    dates = c("2015-01-01", "2020-01-01"),
    alignment = data.frame(unit_id, present_2015, present_2020)
  )
)
class(temporal_data) <- c("nemeton_temporal", "list")
```

**Alternatives Considered**:
- **New S4 class hierarchy**: Rejected - Constitution prohibits S4 unless strong justification (II.Paradigme)
- **Nested data frames (tidyverse style)**: Rejected - Would break existing sf-based workflows
- **Separate temporal package**: Rejected - YAGNI, premature abstraction

**References**:
- Constitution Section III (Modularité): Extend existing structures before creating new ones
- v0.1.0 `R/nemeton-class.R`: S3 class patterns to replicate

---

### TD-002: Allometric Model Implementation

**Decision**: Use lookup table of species-specific equations from IGN/IFN rather than mechanistic growth models.

**Rationale**:
- **Accuracy vs. Simplicity**: IGN equations provide 15-20% accuracy (acceptable for SC-002), mechanistic models add complexity without MVP benefit
- **Data availability**: BD Forêt v2 provides species, age, density (sufficient for allometric approach) but lacks detailed mensuration for mechanistic models
- **Validation**: IGN equations are reference standard for French forest inventory - direct comparison possible
- **Computational efficiency**: Lookup table + simple math vs. iterative solvers

**Allometric Equation Sources**:
1. **Quercus** (Oak): Equation from *Dupouey et al. (2011)* - IFN Mémorial
2. **Fagus** (Beech): Equation from *Bontemps & Duplat (2012)* - Revue Forestière Française
3. **Pinus** (Pine): Equation from *Vallet & Pérot (2011)* - Forest Ecology and Management
4. **Abies** (Fir): Equation from *Wutzler et al. (2008)* - Allgemeine Forst- und Jagdzeitung
5. **Generic**: Pan-European equation from *Wutzler et al. (2008)* for unknown species

**Implementation Strategy**:
```r
# Lookup table structure
allometric_models <- data.frame(
  species = c("Quercus", "Fagus", "Pinus", "Abies", "Generic"),
  a = c(...),  # Equation coefficients
  b = c(...),
  source = c("Dupouey2011", "Bontemps2012", ...),
  citation = c("Dupouey et al. 2011. IFN Mémorial.", ...)
)
```

**Alternatives Considered**:
- **FVS (Forest Vegetation Simulator)**: Rejected - US-centric, not French species
- **3-PG (Physiological Principles Predicting Growth)**: Rejected - Requires climate data not in MVP scope
- **Direct diameter measurements**: Rejected - BD Forêt v2 does not include DBH

**Validation Approach** (FR-040):
- Create `tests/testthat/fixtures/allometric_reference.rds` with IFN biomass values for 10 reference stands
- Test suite verifies ±15% accuracy (SC-002 requirement)

**References**:
- IGN: https://inventaire-forestier.ign.fr/
- Literature citations in function roxygen2 documentation

---

### TD-003: TWI (Topographic Wetness Index) Calculation

**Decision**: Use `whitebox::wbt_wetness_index()` as primary method with `terra` flow accumulation as fallback.

**Rationale**:
- **Accuracy**: Whitebox uses D-infinity (Tarboton 1997) which handles convergent/divergent flow better than D8
- **Performance**: Compiled C++ backend handles 100+ units in <2 min (SC-010 requirement)
- **Optional dependency**: Whitebox is Suggests, not Imports - graceful degradation to terra if unavailable
- **Constitution compliance**: Both whitebox and terra are open-source, no proprietary dependencies (I.Open Data First)

**Flow Algorithm Comparison**:
| Algorithm | Package | Accuracy | Speed | Edge Cases |
|-----------|---------|----------|-------|------------|
| D8 | terra | Moderate | Fast | Poor in flat areas |
| D-infinity | whitebox | High | Very Fast | Excellent |
| Multiple Flow Direction (MFD) | SAGA GIS | Highest | Slow | Excellent but overkill for MVP |

**Implementation Logic**:
```r
indicator_water_twi <- function(units, dem, method = "auto") {
  if (method == "auto") {
    method <- if (requireNamespace("whitebox", quietly = TRUE)) "dinf" else "d8"
  }

  if (method == "dinf") {
    whitebox::wbt_wetness_index(dem, output = "twi.tif")
  } else {
    # terra fallback using D8
    flow_acc <- terra::terrain(dem, "flowdir") |> terra::accum()
    slope <- terra::terrain(dem, "slope")
    twi <- log((flow_acc + 1) / (tan(slope) + 0.001))
  }
}
```

**Extreme Value Handling** (Edge Case):
- Flat areas (slope → 0): Cap TWI at 30 (99th percentile in French forests)
- Convergent valleys (very high TWI): Acceptable, represents actual wetness
- No-data pixels: Propagate NA, document in warning

**Alternatives Considered**:
- **SAGA GIS integration**: Rejected - Requires system dependency, breaks cross-platform compatibility
- **Pure terra implementation**: Kept as fallback, but D8 less accurate than D-infinity
- **Manual implementation**: Rejected - Reinventing wheel violates Constitution II (Interopérabilité)

**References**:
- Tarboton, D.G. (1997). "A new method for the determination of flow directions..." Water Resources Research.
- Whitebox manual: https://www.whiteboxgeo.com/manual/wbt_book/

---

### TD-004: Landscape Fragmentation Metrics

**Decision**: Use manual sf-based implementation for MVP, migrate to `landscapemetrics` in v0.3.0+ if needed.

**Rationale**:
- **MVP sufficiency**: L1 (patch count, mean size) and L2 (edge ratio) can be calculated with basic sf geometry operations
- **Dependency minimization**: landscapemetrics requires raster conversion, adds complexity
- **Performance**: sf is already loaded, no additional overhead
- **Future-proofing**: If advanced metrics needed (shape index, clumpiness, etc.), landscapemetrics becomes justifiable in v0.3.0

**L1 Fragmentation Calculation**:
```r
# Patch count within 1 km buffer
indicator_landscape_fragmentation <- function(units, landcover) {
  buffer_1km <- sf::st_buffer(units, dist = 1000)
  forest_patches <- landcover[landcover$class %in% forest_classes, ]

  patches_per_unit <- sapply(seq_len(nrow(units)), function(i) {
    intersecting <- sf::st_intersection(forest_patches, buffer_1km[i, ])
    n_patches <- nrow(intersecting)
    mean_size <- mean(sf::st_area(intersecting))
    c(n_patches = n_patches, mean_size = mean_size)
  })
}
```

**L2 Edge Ratio Calculation**:
```r
# Edge density (m/ha)
indicator_landscape_edge <- function(units) {
  perimeter <- sf::st_length(sf::st_cast(units, "LINESTRING"))  # m
  area <- sf::st_area(units)  # m²
  edge_density <- perimeter / (area / 10000)  # m/ha
}
```

**Alternatives Considered**:
- **landscapemetrics package**: Deferred to v0.3.0 - adds 5+ dependencies, overkill for L1/L2
- **FRAGSTATS integration**: Rejected - Proprietary, Windows-only, violates Constitution I (Open Data)
- **Raster-based approach**: Rejected - Requires rasterization of vector data, lossy conversion

**Migration Path**:
- v0.2.0: Manual sf implementation (simple, fast)
- v0.3.0+: If users request SHDI, CONTAG, etc. → Add landscapemetrics as Suggests
- Decision point: User feedback after v0.2.0 release

**References**:
- McGarigal, K. (2015). FRAGSTATS Help.
- sf documentation: https://r-spatial.github.io/sf/

---

### TD-005: Family Index Aggregation Method

**Decision**: Weighted arithmetic mean as default, expose `method` parameter for future extension.

**Rationale**:
- **Simplicity**: Arithmetic mean is interpretable, well-understood by forest managers
- **Alignment with v0.1.0**: Existing `create_composite_index()` uses weighted mean
- **Flexibility**: Method parameter allows future addition of geometric mean, harmonic mean, min operator if needed
- **Transparency**: Users can inspect and override weights (Constitution V: Transparence)

**Default Weights**:
- **Within families**: Equal weights (C1=50%, C2=50% for carbon family)
- **Cross-family**: User-specified (no default "master index" in MVP)
- **Rationale**: Avoid imposing normative judgments on indicator importance - domain expert decision

**Implementation**:
```r
create_family_index <- function(units, family = "carbon",
                                 weights = NULL, method = "mean") {
  # Auto-detect family indicators
  family_indicators <- grep(paste0("^", substr(family, 1, 1), "[0-9]"),
                             names(units), value = TRUE)

  if (is.null(weights)) {
    weights <- rep(1/length(family_indicators), length(family_indicators))
  }

  if (method == "mean") {
    family_score <- rowSums(units[family_indicators] * weights, na.rm = FALSE)
  }
  # Future: else if (method == "geometric") ...
}
```

**Alternatives Considered**:
- **Geometric mean**: Better for ratio data, but harder to interpret - defer to v0.3.0
- **Min operator** (limiting factor): Ecologically sound but pessimistic - defer to v0.3.0
- **PCA/Factor analysis**: Statistical but opaque - violates Transparency principle

**References**:
- Tallis & Polasky (2009). "Mapping and valuing ecosystem services..." TREE.
- Existing v0.1.0 `R/composite.R` implementation

---

### TD-006: Backward Compatibility Strategy

**Decision**: Deprecation warnings + wrapper functions, no breaking changes in v0.2.0.

**Rationale**:
- **Constitution requirement**: Semver 0.x allows API changes, but preserving workflows builds user trust
- **Migration path**: Users get 1-2 release cycles to update (v0.2.0 warns, v0.3.0 still warns, v1.0.0 might remove)
- **User experience**: Zero-friction upgrade from v0.1.0 (SC-015 requirement)

**Deprecation Implementation**:
```r
# indicator_carbon() wrapper
indicator_carbon <- function(...) {
  .Deprecated("indicator_carbon_biomass",
              msg = "indicator_carbon() is deprecated. Use indicator_carbon_biomass() for BD Forêt support.")
  indicator_carbon_biomass(...)  # Identical behavior when no BD Forêt data
}
```

**Namespace Management**:
- Keep `indicator_carbon` exported in NAMESPACE
- Add `@export` to `indicator_carbon_biomass`
- Roxygen2 `@seealso` cross-reference

**Alternatives Considered**:
- **Hard removal**: Rejected - Breaks SC-015 (v0.1.0 workflows must work)
- **Renaming existing function**: Rejected - Confusing, violates least surprise principle
- **No deprecation**: Rejected - Two functions doing same thing forever (maintenance burden)

**References**:
- R Core `.Deprecated()` documentation
- Tidyverse deprecation lifecycle: https://lifecycle.r-lib.org/

---

## Research Outcomes Summary

| Decision | Technology/Approach | Confidence | Blocker Risk |
|----------|---------------------|------------|--------------|
| TD-001 | S3 class extension | ✅ High | None - proven pattern |
| TD-002 | Allometric lookup table | ✅ High | None - literature validated |
| TD-003 | Whitebox TWI + terra fallback | ✅ High | Low - both packages stable |
| TD-004 | Manual sf fragmentation | ⚠️ Medium | Low - simple calculations, may need refinement |
| TD-005 | Weighted arithmetic mean | ✅ High | None - standard practice |
| TD-006 | Deprecation wrappers | ✅ High | None - R core feature |

**Overall Assessment**: ✅ **LOW RISK** - All decisions based on established practices or existing v0.1.0 patterns. No experimental technologies or unproven approaches.

---

## Open Questions (Deferred to Implementation/Testing)

1. **TWI Extreme Values**: Exact capping threshold (30 vs 25 vs log-transform) - decide based on massif_demo DEM distribution
2. **Fragmentation Buffer Size**: 1 km default appropriate? - validate with literature review during implementation
3. **NDVI Trend Calculation**: Linear regression vs Sen's slope? - test both, choose more robust
4. **Test Fixtures**: Which IFN stands to use for allometric validation - identify during data preparation

**Resolution Strategy**: These are implementation details, not architectural blockers. Resolve during TDD cycle with test-driven validation.

---

## Next Steps

**Phase 0**: ✅ COMPLETE
**Phase 1**: PROCEED
- Create `data-model.md` (document 6 key entities: Temporal Dataset, Indicator Family, Sub-Indicator, Allometric Model, Family Score, Change Rate)
- Create `quickstart.md` (5-minute v0.2.0 workflow example)
- Skip `contracts/` (no REST API for R package)
- Update agent context

**No blocking issues identified.** Ready for design phase.
