# Implementation Plan: MVP v0.3.0 - Multi-Family Indicator Extension

**Branch**: `001-mvp-v0-3-0` | **Date**: 2026-01-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-mvp-v0-3-0/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Extend the nemeton R package with 4 new indicator families (B-Biodiversity, R-Resilience, T-Temporal, A-Air) to reach 9 out of 12 total families. This version builds on v0.2.0's temporal infrastructure and family system to add 10 new ecosystem service indicators while maintaining full backward compatibility.

**Primary Requirements**:
- 10 new indicator functions across 4 families (B1-B3, R1-R3, T1-T2, A1-A2)
- Integration with existing normalization and aggregation system
- Extension of radar visualization to 9 axes
- Cross-family correlation analysis capabilities
- 100% backward compatibility with v0.2.0 workflows

**Technical Approach**:
- Leverage existing family-system.R infrastructure for new families
- Reuse temporal analysis framework (nemeton_temporal) for T family
- Extend normalization.R to recognize new indicator prefixes (B*, R*, T*, A*)
- Add new R/indicators-biodiversity.R, R/indicators-risk.R, R/indicators-temporal.R, R/indicators-air.R modules
- Extend visualization.R radar plot from current capacity to support up to 12 axes
- Implement correlation matrix function in new R/analysis-correlation.R module

## Technical Context

**Language/Version**: R >= 4.0.0 (v0.2.0 uses R 4.5.2)
**Primary Dependencies**:
  - **Existing**: sf (>= 1.0-0), terra (>= 1.7-0), exactextractr (>= 0.9.0), ggplot2 (>= 3.4.0), dplyr (>= 1.1.0), tidyr, whitebox, cli (>= 3.6.0), rlang (>= 1.1.0)
  - **New Suggested**: rnaturalearth (protected area access), osmdata (OSM features), potentially rgee (Google Earth Engine - optional)
**Storage**: R package data structures (.rda in data/), external data sources (INPN WFS, IGN BD Forêt, Corine Land Cover rasters)
**Testing**: testthat framework with fixtures in tests/testthat/fixtures/
**Target Platform**: R package (CRAN-compatible, Linux/Windows/macOS)
**Project Type**: R package (standard R/ tests/ vignettes/ data/ inst/ structure)
**Performance Goals**:
  - Support ≥1000 units without crash (constitution requirement)
  - Buffer analysis (1km radius) computationally feasible for typical workloads
  - Indicator calculation time <10s for demo dataset (20 parcels)
**Constraints**:
  - ≥70% test coverage (spec requirement; constitution requires 80% - see justification below)
  - 100% backward compatibility with v0.2.0 (661 existing tests must pass)
  - Bilingual FR/EN documentation and messages (i18n system)
  - R CMD check must pass with 0 errors, 0 warnings except UTF-8 (acceptable for French text)
  - Maximum 300 lines per function (constitution)
**Scale/Scope**:
  - 10 new exported functions (indicator_biodiversity_*, indicator_risk_*, indicator_temporal_*, indicator_air_*)
  - 4 new R/ module files (~250-350 lines each estimated)
  - Extension of 3 existing files (normalization.R, visualization.R, family-system.R)
  - ~100-150 new tests (targeting 70%+ coverage for new code)
  - 1 new vignette (~1500-2000 words), 1 updated vignette

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Compliant Principles

| Principle | Compliance | Evidence |
|-----------|------------|----------|
| **I. Open Data First** | ✅ PASS | All data sources are open: INPN (open WFS), IGN BD Forêt (open), Corine Land Cover (EEA open data), Météo-France/WorldClim (open climate) |
| **II. Interopérabilité R Spatial** | ✅ PASS | Uses sf for vectors, terra for rasters, exactextractr for zonal stats; no raster/sp packages |
| **III. Modularité** | ✅ PASS | Clear module separation: R/indicators-biodiversity.R, R/indicators-risk.R, R/indicators-temporal.R, R/indicators-air.R; extends existing R/normalization.R, R/visualization.R |
| **V. Transparence** | ✅ PASS | Bilingual docs required (FR-018), explicit parameters, metadata tracking, informative warnings (FR-017) |
| **VI. Extensibilité** | ✅ PASS | Builds on existing indicator framework; new families use same API as v0.2.0 families |
| **VII. Simplicité** | ✅ PASS | Leverages v0.2.0 infrastructure (temporal, family system); no reinvention; incremental extension |

### ⚠️ Principles Requiring Justification

| Principle | Status | Justification |
|-----------|--------|---------------|
| **IV. Test-First avec Fixtures** | ⚠️ PARTIAL | **Coverage**: Spec requires ≥70%, constitution requires ≥80%. **Justification**: v0.3.0 is pre-1.0 (0.x.y series), constitution allows API flexibility. v0.2.0 achieved ~95% coverage (661 tests). We commit to ≥80% for v0.3.0 final release but accept ≥70% during development cycles. **Mitigation**: Track coverage per module; aim for 90%+ on new indicator functions (core logic). |

### 🔍 Constitution Gates (All Clear)

- ✅ **Stack Technique**: Uses terra (not raster), sf (not sp), exactextractr, cli, rlang - all required packages
- ✅ **Nommage**: New functions follow `indicator_*()` convention (e.g., indicator_biodiversity_protection)
- ✅ **Performance**: Buffer analysis feasible for 1000 units (constitution minimum); can parallelize if needed in v0.4.0
- ✅ **Documentation**: roxygen2 required for all 10 new functions (FR-018, SC-006)
- ✅ **Versioning**: 0.3.0 follows semantic versioning (MINOR bump for new features, pre-1.0 series)

**Gate Result**: ✅ **PASS** - May proceed to Phase 0 research with coverage commitment adjustment

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-v0-3-0/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (data sources, methods)
├── data-model.md        # Phase 1 output (indicator schemas, family structure)
├── quickstart.md        # Phase 1 output (usage examples)
├── contracts/           # Phase 1 output (function signatures, indicator specs)
│   ├── biodiversity-indicators.md
│   ├── risk-indicators.md
│   ├── temporal-indicators.md
│   └── air-indicators.md
└── checklists/
    └── requirements.md  # Validation checklist (completed)
```

### Source Code (R package structure)

```text
nemeton/  (repository root)
├── R/  (package source code)
│   ├── indicators-biodiversity.R    # NEW: B1, B2, B3 functions
│   ├── indicators-risk.R            # NEW: R1, R2, R3 functions
│   ├── indicators-temporal.R        # NEW: T1, T2 functions
│   ├── indicators-air.R             # NEW: A1, A2 functions
│   ├── analysis-correlation.R       # NEW: cross-family correlation matrix
│   ├── family-system.R              # EXTEND: support B, R, T, A families
│   ├── normalization.R              # EXTEND: recognize B*, R*, T*, A* prefixes
│   ├── visualization.R              # EXTEND: radar plot 9+ axes
│   ├── i18n.R                       # EXTEND: messages for new indicators
│   └── utils.R                      # EXTEND: helpers for new data types
│
├── tests/testthat/  (test suite)
│   ├── test-indicators-biodiversity.R   # NEW: ~15-20 tests
│   ├── test-indicators-risk.R           # NEW: ~15-20 tests
│   ├── test-indicators-temporal.R       # NEW: ~10-15 tests
│   ├── test-indicators-air.R            # NEW: ~10-15 tests
│   ├── test-analysis-correlation.R      # NEW: ~10 tests
│   ├── test-family-system.R             # EXTEND: test new families
│   ├── test-normalization.R             # EXTEND: test new prefixes
│   ├── test-visualization.R             # EXTEND: test 9-axis radar
│   ├── fixtures/
│   │   ├── protected_areas_demo.rds     # NEW: ZNIEFF/Natura2000 sample
│   │   ├── land_cover_2020.rds          # NEW: Corine Land Cover snippet
│   │   ├── land_cover_1990.rds          # NEW: Historical land cover
│   │   ├── climate_data.rds             # NEW: Temperature/precipitation
│   │   └── expected_indicators_v030.rds # NEW: Regression test fixtures
│   └── testthat.R
│
├── vignettes/
│   ├── biodiversity-resilience.Rmd      # NEW: Workflow for B, R, T, A families
│   └── indicator-families.Rmd           # EXTEND: Update to 9 families
│
├── data/
│   └── massif_demo_units.rda            # POTENTIAL EXTEND: add historical attributes
│
├── inst/extdata/massif_demo/
│   ├── protected_areas/                 # NEW: demo ZNIEFF zones
│   ├── land_cover_1990.tif              # NEW: historical land cover
│   └── climate/                         # NEW: demo climate rasters
│
├── man/  (generated by roxygen2)
│   ├── indicator_biodiversity_protection.Rd  # NEW (generated)
│   ├── indicator_biodiversity_structure.Rd   # NEW (generated)
│   └── [... 8 more indicator .Rd files]
│
├── DESCRIPTION                          # EXTEND: add Suggests: rnaturalearth, osmdata
├── NAMESPACE                            # AUTO-GENERATED by roxygen2
└── README.md                            # EXTEND: update feature list to 9 families
```

**Structure Decision**: Standard R package layout following Tidyverse conventions and v0.2.0 architecture. New indicator families get dedicated module files (indicators-*.R) to maintain separation of concerns (<300 lines each). Existing infrastructure files (family-system.R, normalization.R, visualization.R) extended minimally to integrate new families without breaking changes.

**File Organization Rationale**:
- **One module per family**: indicators-biodiversity.R, indicators-risk.R, etc. (follows v0.2.0 pattern of indicators-biophysical.R)
- **Separate analysis module**: analysis-correlation.R for cross-family functions (follows single responsibility principle)
- **Test file mirrors source**: test-indicators-biodiversity.R tests indicators-biodiversity.R
- **Fixtures directory**: Centralized test data (v0.2.0 established this pattern)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Test coverage 70% vs 80% | Development velocity during 0.x series; final release will meet 80% | Requiring 80% coverage during active development would slow iteration; v0.2.0 achieved 95% so team is capable; committing to 80%+ for v0.3.0 final tag |

**Note**: This is the ONLY deviation from constitution. All other principles are fully compliant.

## Phase 0: Research & Technical Decisions

**Objective**: Resolve technical unknowns and select optimal approaches for new indicator implementations.

### Research Questions

1. **Protected Area Data Access**:
   - **Question**: What is the most reliable method to access INPN protected area data (ZNIEFF, Natura2000) in R?
   - **Decision Needed**: WFS API vs. downloaded shapefiles vs. rnaturalearth package

2. **Land Use Change Detection**:
   - **Question**: How to efficiently compute T2 (land use change rate) from multi-temporal Corine Land Cover in R?
   - **Decision Needed**: terra raster algebra vs. pre-processing to vector transitions vs. external tools

3. **Risk Index Methodologies**:
   - **Question**: What are established fire risk (R1) and storm vulnerability (R2) index formulas used in French forestry?
   - **Decision Needed**: Literature review needed for scientifically validated weighting schemes

4. **Air Quality Proxy**:
   - **Question**: When ATMO data unavailable, what distance-based proxy is most appropriate for A2?
   - **Decision Needed**: Distance to roads vs. distance to urban areas vs. combined index

5. **Structural Diversity Index (B2)**:
   - **Question**: How to quantify canopy stratification and age diversity in a composite B2 index?
   - **Decision Needed**: Shannon diversity vs. Simpson index vs. custom multi-factor score

### Research Outputs

**See**: [research.md](research.md) - Generated in Phase 0 workflow

Expected sections in research.md:
- **Decision R1**: Protected area data access method
- **Decision R2**: Land use change computation approach
- **Decision R3**: Risk index formulas (fire, storm, drought)
- **Decision R4**: Air quality proxy methodology
- **Decision R5**: Structural diversity calculation

## Phase 1: Design & Contracts

**Prerequisites**: research.md complete (all NEEDS CLARIFICATION resolved)

### Artifacts to Generate

1. **data-model.md**:
   - Indicator schema (name, family, unit, range, thresholds)
   - Family definitions (B, R, T, A codes and full names)
   - Input data requirements per indicator
   - Normalization parameters per family

2. **contracts/** (function signatures):
   - **biodiversity-indicators.md**: indicator_biodiversity_protection(), indicator_biodiversity_structure(), indicator_biodiversity_connectivity()
   - **risk-indicators.md**: indicator_risk_fire(), indicator_risk_storm(), indicator_risk_drought()
   - **temporal-indicators.md**: indicator_temporal_age(), indicator_temporal_change()
   - **air-indicators.md**: indicator_air_coverage(), indicator_air_quality()

3. **quickstart.md**:
   - Step-by-step tutorial for computing new indicators
   - Example workflow: load data → calculate B1-B3 → normalize → create family_B → radar plot
   - Code snippets demonstrating integration with v0.2.0 workflows

### Agent Context Update

After Phase 1 design artifacts are complete:

```bash
.specify/scripts/bash/update-agent-context.sh claude
```

This will update `.specify/memory/agent-context-claude.md` with new technologies/dependencies from this plan (rnaturalearth, osmdata, new modules).

## Implementation Strategy

### Phase Breakdown

**Phase 0 (Research)**: ~1-2 days
- Literature review for risk indices
- Test protected area data access methods
- Validate land cover processing approaches

**Phase 1 (Design)**: ~1 day
- Document indicator schemas in data-model.md
- Define function contracts
- Write quickstart tutorial

**Phase 2 (Tasks)**: ~0.5 day
- Generate tasks.md using `/speckit.tasks` command
- Break implementation into prioritized, parallelizable tasks

**Phase 3 (Implementation)**: ~5-7 days (actual coding)
- Implement indicators by family (B, R, T, A in parallel if possible)
- Extend normalization and family system
- Update radar visualization
- Add correlation analysis
- Write tests (TDD: tests before code)
- Document with roxygen2
- Write/update vignettes

**Phase 4 (Validation)**: ~1-2 days
- Run full test suite (v0.2.0 + v0.3.0)
- Verify ≥70% coverage (aim for 80%)
- R CMD check --as-cran
- Build pkgdown site
- Manual testing of workflows

### Dependency Order

1. **Foundation** (no dependencies):
   - Research phase (Phase 0)
   - Design artifacts (Phase 1)
   - Test fixtures creation

2. **Core Indicators** (parallel):
   - indicators-biodiversity.R (B1, B2, B3)
   - indicators-risk.R (R1, R2, R3)
   - indicators-temporal.R (T1, T2)
   - indicators-air.R (A1, A2)

3. **Integration** (depends on core):
   - Extend family-system.R (needs indicator definitions)
   - Extend normalization.R (needs indicator functions)

4. **Visualization** (depends on integration):
   - Extend visualization.R radar plot (needs family system)

5. **Analysis** (depends on all above):
   - analysis-correlation.R (needs all indicators and families)

6. **Documentation** (depends on all above):
   - Vignettes (needs working functions)
   - README update

### Testing Strategy

**Test-First Approach** (constitution requirement IV):

1. **Before writing each indicator function**:
   - Write test_that() blocks with expected behavior
   - Create fixtures with known input/output pairs
   - Tests fail initially (Red phase)

2. **Implement function** until tests pass (Green phase)

3. **Refactor** for clarity while keeping tests green

**Coverage Targets by Module**:
- indicators-*.R: 90%+ (core business logic, high priority)
- normalization.R extensions: 85%+ (critical path)
- visualization.R extensions: 75%+ (UI code, harder to test)
- analysis-correlation.R: 80%+ (analytical functions)
- **Overall v0.3.0**: ≥70% (spec), aim for ≥80% (constitution)

**Test Categories**:
- **Unit tests**: Each indicator function with mocked data
- **Integration tests**: Full workflow (load → compute → normalize → aggregate → plot)
- **Regression tests**: Fixtures with expected v0.3.0 outputs (prevent future breaks)
- **Backward compat tests**: v0.2.0 workflows still work (SC-004)

### Backward Compatibility Requirements

**Critical Constraint** (FR-014, SC-004): 100% of v0.2.0 workflows must execute successfully.

**Verification**:
1. All 661 v0.2.0 tests must pass without modification
2. Existing vignettes must knit successfully
3. Function signatures unchanged for all v0.2.0 exported functions
4. Default parameters unchanged

**Safe Extension Points**:
- ✅ Add new functions (indicator_biodiversity_*, etc.) - safe
- ✅ Add new parameters to normalize_indicators() with defaults - safe
- ✅ Extend family codes in family-system.R (B, R, T, A) - safe
- ✅ Add new columns to output (family_B, family_R, etc.) - safe
- ❌ Change existing function signatures - **FORBIDDEN**
- ❌ Rename existing columns - **FORBIDDEN**
- ❌ Change normalization algorithms - **FORBIDDEN**

## Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Protected area data access unreliable | Medium | High | Phase 0 research tests multiple methods; fallback to local shapefiles |
| Land cover raster processing too slow | Medium | Medium | Test performance early; use terra (fast) vs raster (deprecated); optimize or pre-process |
| Risk index formulas not standardized | High | Medium | Phase 0 literature review; document assumptions; make parameterizable |
| Test coverage <70% on first pass | Medium | Medium | Track coverage per commit; prioritize core functions; skip low-value edge cases initially |
| Backward compatibility break | Low | High | Run v0.2.0 tests in CI; strict code review for changes to existing files |
| Buffer analysis (A1) memory issues | Low | Medium | Use exactextractr (memory-efficient); test with 1000 units; document limitations |

## Success Metrics

Aligned with spec.md Success Criteria (SC-001 through SC-010):

1. ✅ **All 10 indicator functions work**: Valid outputs for massif_demo
2. ✅ **Family composites correct**: family_B, family_R, family_T, family_A aggregate properly
3. ✅ **Radar visualization extended**: 9 axes display without artifacts
4. ✅ **Backward compatibility**: 661 v0.2.0 tests pass
5. ✅ **Correlation analysis**: Detects expected relationships (B × T positive)
6. ✅ **Bilingual docs**: FR/EN for all 10 functions
7. ✅ **R CMD check clean**: 0 errors, 0 warnings (except UTF-8)
8. ✅ **Vignette complete**: biodiversity-resilience demonstrates workflow
9. ✅ **Hotspot analysis**: Identifies top 20% multi-criteria parcels
10. ✅ **Graceful missing data**: Informative warnings, no crashes

**Gate for v0.3.0 Release**: All 10 metrics must be ✅ PASS

## Next Steps

1. ✅ **Spec complete**: spec.md written and validated
2. ✅ **Plan complete**: This file (plan.md)
3. 🔄 **Phase 0 - Research**: Run research workflow to generate research.md
4. ⏳ **Phase 1 - Design**: Generate data-model.md, contracts/, quickstart.md
5. ⏳ **Phase 2 - Tasks**: Run `/speckit.tasks` to generate tasks.md
6. ⏳ **Phase 3 - Implementation**: Execute tasks from tasks.md (TDD cycle)
7. ⏳ **Phase 4 - Validation**: Tests, R CMD check, coverage, manual QA
8. ⏳ **Release**: Tag v0.3.0, update pkgdown site, announce

**Immediate Next Command**: Begin Phase 0 research workflow (see research.md generation below)
