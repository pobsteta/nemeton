# Tasks: MVP v0.2.0 - Temporal & Spatial Indicators Extension

**Input**: Design documents from `/specs/001-mvp-v0.2.0/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: TDD approach mandated by constitution - tests written BEFORE implementation for all exported functions.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story (US1, US2, etc.) - REQUIRED for phases 3+
- **File paths**: Exact paths included in all task descriptions

**Path Convention**: R package structure
- Source: `R/`
- Tests: `tests/testthat/`
- Vignettes: `vignettes/`
- Data: `data/`, `inst/extdata/`

---

## Phase 1: Setup (Project Dependencies & Configuration)

**Purpose**: Update package configuration for v0.2.0 dependencies

**Estimated Time**: 30 minutes

### Tasks

- [X] T001 [P] Update DESCRIPTION with new dependencies (whitebox, landscapemetrics) in Suggests
- [X] T002 [P] Update NAMESPACE to prepare for new exported functions (will auto-generate via roxygen2)
- [X] T003 [P] Create R/sysdata.rda with allometric models lookup table per research.md TD-002
- [X] T004 Verify all v0.1.0 tests still pass (devtools::test()) - baseline for backward compatibility

**Completion Criteria**:
- ✅ `devtools::check()` passes with 0 errors, 0 warnings
- ✅ All 359 v0.1.0 tests passing (backward compatibility verified)
- ✅ Allometric models lookup table accessible internally

---

## Phase 2: Foundational Infrastructure (Blocking Prerequisites)

**Purpose**: Core utilities and i18n messages needed by all user stories

**Estimated Time**: 1 hour

**Note**: These tasks MUST complete before any user story implementation

### Tasks

- [X] T005 [P] Extend R/utils.R with get_allometric_model() helper function
- [X] T006 [P] Extend R/utils.R with calculate_biomass_from_model() internal function
- [X] T007 [P] Extend R/i18n.R with FR/EN messages for all new indicators (C1, C2, W1-W3, F1-F2, L1-L2)
- [X] T008 [P] Extend R/i18n.R with temporal analysis messages (periods, change rates, trends)
- [X] T009 [P] Create tests/testthat/fixtures/allometric_reference.rds with IFN validation data
- [X] T010 [P] Create tests/testthat/fixtures/twi_reference.rds with validated TWI values
- [X] T011 Create tests/testthat/test-utils-allometric.R for allometric helper functions

**Completion Criteria**:
- ✅ Allometric helpers functional and tested (± 15% accuracy vs IFN)
- ✅ All i18n messages defined (FR + EN)
- ✅ Test fixtures created and validated

---

## Phase 3: User Story 1 (P1) - Multi-Temporal Analysis Infrastructure

**Goal**: Enable analysis of indicator evolution across multiple time periods

**Independent Test**: Run existing 5 indicators (carbon, biodiversity, water, fragmentation, accessibility) on massif_demo at two different dates, verify temporal dataset creation, change rate calculation, and trend visualization

**Estimated Time**: 4-6 hours

### 3.1 Test Fixtures & Data Preparation

- [X] T012 [P] [US1] Create tests/testthat/fixtures/temporal_test_data.rds with 2-period synthetic dataset
- [X] T013 [P] [US1] Create tests/testthat/helper-temporal.R with create_temporal_test_units() helper

### 3.2 Core Temporal Functions (TDD)

- [X] T014 [US1] Write tests for nemeton_temporal() in tests/testthat/test-temporal.R (S3 class, validation, print/summary)
- [X] T015 [US1] Implement nemeton_temporal() in R/temporal.R with S3 class structure per data-model.md
- [X] T016 [US1] Implement print.nemeton_temporal() method in R/temporal.R
- [X] T017 [US1] Implement summary.nemeton_temporal() method in R/temporal.R
- [X] T018 [P] [US1] Write tests for calculate_change_rate() in tests/testthat/test-temporal.R (absolute, relative, edge cases)
- [X] T019 [US1] Implement calculate_change_rate() in R/temporal.R (handles zero baseline, NA periods)
- [X] T020 [US1] Add roxygen2 documentation for nemeton_temporal() with @examples using massif_demo

### 3.3 Temporal Visualizations

- [X] T021 [P] [US1] Write tests for plot_temporal_trends() in tests/testthat/test-visualization.R
- [X] T022 [US1] Implement plot_temporal_trends() in R/visualization.R (ggplot2 time-series line plots)
- [X] T023 [P] [US1] Write tests for plot_change_heatmap() in tests/testthat/test-visualization.R
- [X] T024 [US1] Implement plot_change_heatmap() in R/visualization.R (diverging color scale)
- [X] T025 [US1] Add roxygen2 documentation for temporal visualization functions

### 3.4 Integration Testing

- [X] T026 [US1] Create integration test: full temporal workflow (create → compute → change rate → visualize) in tests/testthat/test-integration-temporal.R
- [X] T027 [US1] Test temporal alignment edge cases (units present in some periods, not others)
- [X] T028 [US1] Test intervention markers functionality (if time permits)

**US1 Completion Criteria**:
- ✅ Users can create temporal datasets from 2+ periods
- ✅ Change rates calculated correctly (absolute + relative)
- ✅ Time-series plots display indicator evolution with clear date labels
- ✅ All tests passing (>=10 test cases for US1)

---

## Phase 4: User Story 2 (P1) - Family C: Carbon & Forest Vitality

**Goal**: Evaluate aboveground biomass stock (C1) and vitality via NDVI (C2)

**Independent Test**: Calculate C1 biomass using massif_demo with BD Forêt v2 attributes, compute C2 NDVI from raster, verify units (tC/ha for C1, 0-1 for C2), create score_carbon composite

**Estimated Time**: 5-7 hours

### 4.1 C1: Biomass Indicator (TDD)

- [X] T029 [P] [US2] Write tests for indicator_carbon_biomass() in tests/testthat/test-indicators-families.R (species-specific, generic fallback, accuracy vs IFN)
- [X] T030 [US2] Implement indicator_carbon_biomass() in R/indicators-families.R using allometric models from sysdata
- [X] T031 [US2] Test species-specific models (Quercus, Fagus, Pinus, Abies) against fixtures/allometric_reference.rds
- [X] T032 [US2] Test generic model fallback when species unknown
- [X] T033 [US2] Test age/density out-of-range warnings
- [X] T034 [US2] Add roxygen2 documentation for indicator_carbon_biomass() with allometric equation references

### 4.2 C2: NDVI Indicator (TDD)

- [X] T035 [P] [US2] Write tests for indicator_carbon_ndvi() in tests/testthat/test-indicators-families.R (mean extraction, optional trend)
- [X] T036 [US2] Implement indicator_carbon_ndvi() in R/indicators-families.R (zonal mean via exactextractr)
- [X] T037 [US2] Implement NDVI trend calculation (optional, requires 3+ dates)
- [X] T038 [US2] Add roxygen2 documentation for indicator_carbon_ndvi()

### 4.3 Backward Compatibility & Deprecation

- [X] T039 [US2] Create indicator_carbon() wrapper in R/indicators-core.R with .Deprecated() warning
- [X] T040 [US2] Test backward compatibility: verify indicator_carbon() behaves identically to indicator_carbon_biomass() when no BD Forêt
- [X] T041 [US2] Update existing tests to ensure no regressions

### 4.4 Family Score Integration

- [X] T042 [P] [US2] Write tests for create_family_index(family="carbon") in tests/testthat/test-normalization.R
- [X] T043 [US2] Test score_carbon creation with default weights (C1=70%, C2=30%)
- [X] T044 [US2] Test partial family score (C2 missing for some units)

**US2 Completion Criteria**:
- ✅ C1 biomass accuracy within 15% of IFN reference values (SC-002)
- ✅ C2 NDVI extracted correctly (0-1 scale)
- ✅ score_carbon composite created as weighted average
- ✅ Backward compatibility preserved (indicator_carbon() still works)
- ✅ All tests passing (>=12 test cases for US2)

---

## Phase 5: User Story 3 (P1) - Family W: Water Regulation

**Goal**: Complete water family assessment (W1 network density, W2 wetlands, W3 TWI)

**Independent Test**: Calculate W1 stream length/ha, W2 wetland %, W3 TWI from DEM, create score_water composite

**Estimated Time**: 6-8 hours

### 5.1 W1: Hydrographic Network (TDD)

- [X] T045 [P] [US3] Write tests for indicator_water_network() in tests/testthat/test-indicators-families.R
- [X] T046 [US3] Implement indicator_water_network() in R/indicators-families.R (sf length calculation, density in km/ha)
- [X] T047 [US3] Test with massif_demo watercourses layer
- [X] T048 [US3] Add roxygen2 documentation for indicator_water_network()

### 5.2 W2: Wetlands Coverage (TDD)

- [X] T049 [P] [US3] Write tests for indicator_water_wetlands() in tests/testthat/test-indicators-families.R
- [X] T050 [US3] Implement indicator_water_wetlands() in R/indicators-families.R (zonal proportion via exactextractr)
- [X] T051 [US3] Test with land cover raster (wetland class identification)
- [X] T052 [US3] Add roxygen2 documentation for indicator_water_wetlands()

### 5.3 W3: Topographic Wetness Index (TDD)

- [X] T053 [P] [US3] Write tests for indicator_water_twi() in tests/testthat/test-indicators-families.R (whitebox + terra fallback)
- [X] T054 [US3] Implement indicator_water_twi() with whitebox::wbt_wetness_index() primary method in R/indicators-families.R
- [X] T055 [US3] Implement terra fallback (D8 flow accumulation + slope) per research.md TD-003
- [X] T056 [US3] Test TWI accuracy against fixtures/twi_reference.rds
- [X] T057 [US3] Test extreme values handling (flat areas, convergent valleys)
- [X] T058 [US3] Test whitebox optional dependency (skip if not installed)
- [X] T059 [US3] Add roxygen2 documentation for indicator_water_twi() with algorithm references

### 5.4 Family Score Integration

- [X] T060 [P] [US3] Write tests for create_family_index(family="water") in tests/testthat/test-normalization.R
- [X] T061 [US3] Test score_water creation with equal weights (W1=W2=W3=33.3%)
- [X] T062 [US3] Test W3 performance: 100+ units in <2 min (SC-010)

**US3 Completion Criteria**:
- ✅ W1, W2, W3 all calculated correctly
- ✅ TWI completes for 100+ units in <2 min (SC-010)
- ✅ score_water composite created
- ✅ Whitebox optional dependency handled gracefully
- ✅ All tests passing (>=15 test cases for US3)

---

## Phase 6: User Story 4 (P2) - Family F: Soil Fertility & Erosion

**Goal**: Evaluate soil fertility class (F1) and erosion risk (F2)

**Independent Test**: Extract F1 fertility from BD Sol, calculate F2 erosion from slope + landcover, create score_soil

**Estimated Time**: 4-5 hours

### 6.1 F1: Soil Fertility (TDD)

- [X] T063 [P] [US4] Write tests for indicator_soil_fertility() in tests/testthat/test-indicators-families.R
- [X] T064 [US4] Implement indicator_soil_fertility() in R/indicators-families.R (BD Sol extraction or soil texture fallback)
- [X] T065 [US4] Test with synthetic soil raster (1-5 scale or categorical)
- [X] T066 [US4] Test graceful NA handling when BD Sol unavailable
- [X] T067 [US4] Add roxygen2 documentation for indicator_soil_fertility()

### 6.2 F2: Erosion Risk (TDD)

- [X] T068 [P] [US4] Write tests for indicator_soil_erosion() in tests/testthat/test-indicators-families.R
- [X] T069 [US4] Implement indicator_soil_erosion() in R/indicators-families.R (slope from DEM × land cover type)
- [X] T070 [US4] Implement erosion risk formula: higher slope + less vegetation = higher risk (0-100 scale)
- [X] T071 [US4] Test edge case: F2 > 70 threshold highlighting in visualizations
- [X] T072 [US4] Add roxygen2 documentation for indicator_soil_erosion()

### 6.3 Family Score Integration

- [X] T073 [P] [US4] Write tests for create_family_index(family="soil") in tests/testthat/test-normalization.R
- [X] T074 [US4] Test score_soil creation with equal weights (F1=F2=50%)
- [X] T075 [US4] Test partial family score (F1 missing when no BD Sol)

**US4 Completion Criteria**:
- ✅ F1 fertility extracted correctly (1-5 scale or categorical)
- ✅ F2 erosion risk calculated (0-100 scale)
- ✅ High erosion parcels (F2 > 70) identifiable
- ✅ score_soil composite created
- ✅ All tests passing (>=10 test cases for US4)

---

## Phase 7: User Story 5 (P2) - Family L: Landscape Fragmentation & Edge

**Goal**: Quantify landscape fragmentation (L1) and edge-to-surface ratio (L2)

**Independent Test**: Calculate L1 patch count/mean size, L2 perimeter/area ratio, create score_landscape

**Estimated Time**: 4-5 hours

### 7.1 L1: Fragmentation Metrics (TDD)

- [X] T076 [P] [US5] Write tests for indicator_landscape_fragmentation() in tests/testthat/test-indicators-families.R
- [X] T077 [US5] Implement indicator_landscape_fragmentation() in R/indicators-families.R (manual sf patch counting)
- [X] T078 [US5] Implement 1 km buffer analysis per research.md TD-004
- [X] T079 [US5] Calculate patch count and mean patch size
- [X] T080 [US5] Add roxygen2 documentation for indicator_landscape_fragmentation()

### 7.2 L2: Edge Ratio (TDD)

- [X] T081 [P] [US5] Write tests for indicator_landscape_edge() in tests/testthat/test-indicators-families.R
- [X] T082 [US5] Implement indicator_landscape_edge() in R/indicators-families.R (perimeter/area in m/ha)
- [X] T083 [US5] Test with complex geometries
- [X] T084 [US5] Test edge ratio > 200 m/ha flagging
- [X] T085 [US5] Add roxygen2 documentation for indicator_landscape_edge()

### 7.3 Family Score Integration

- [X] T086 [P] [US5] Write tests for create_family_index(family="landscape") in tests/testthat/test-normalization.R
- [X] T087 [US5] Test score_landscape creation with inverse normalization (low fragmentation = high score)
- [X] T088 [US5] Verify negative indicators (L1, L2) inverted correctly

**US5 Completion Criteria**:
- ✅ L1 fragmentation calculated (patch count, mean size)
- ✅ L2 edge ratio calculated (m/ha)
- ✅ score_landscape composite created with inverse normalization
- ✅ Highly fragmented areas identifiable
- ✅ All tests passing (>=8 test cases for US5)

---

## Phase 8: User Story 6 (P3) - Multi-Family Normalization & Composite Indices

**Goal**: Create family-level composite indices and 12-axis radar visualization

**Independent Test**: Normalize indicators from families C, W, F, L, create family scores, display 4-12 axis radar chart

**Estimated Time**: 5-6 hours

### 8.1 Family-Aware Normalization (TDD)

- [X] T089 [P] [US6] Write tests for extended normalize_indicators() with family prefix detection in tests/testthat/test-normalization.R
- [X] T090 [US6] Extend normalize_indicators() in R/normalization.R to recognize C_, W_, F_, L_ prefixes
- [X] T091 [US6] Test normalization of all 10 sub-indicators (C1, C2, W1-W3, F1-F2, L1-L2)
- [X] T092 [US6] Test inverse normalization for negative indicators (F2, L1, L2)

### 8.2 Family Index Creation (TDD)

- [X] T093 [P] [US6] Write tests for create_family_index() in tests/testthat/test-composite.R
- [X] T094 [US6] Implement create_family_index() in R/composite.R (generic for any family)
- [X] T095 [US6] Test default weights per family (from data-model.md)
- [X] T096 [US6] Test custom user weights
- [X] T097 [US6] Test partial family scores (missing sub-indicators)
- [X] T098 [US6] Add roxygen2 documentation for create_family_index() with family weight tables

### 8.3 Extended Radar Visualization (TDD)

- [X] T099 [P] [US6] Write tests for extended nemeton_radar() in tests/testthat/test-visualization.R
- [X] T100 [US6] Extend nemeton_radar() in R/visualization.R to handle 4-12 family axes (dynamic based on available families)
- [X] T101 [US6] Test radar with 4 families (C, W, F, L)
- [X] T102 [US6] Test radar auto-detection of family scores (score_*)
- [X] T103 [US6] Test radar with specific unit_id vs average
- [X] T104 [US6] Update roxygen2 documentation for nemeton_radar() with family mode examples

### 8.4 Reference Thresholds Documentation

- [X] T105 [P] [US6] Document reference thresholds for each indicator in R/indicators-families.R roxygen2
- [X] T106 [US6] Create helper function get_indicator_thresholds() for programmatic access

**US6 Completion Criteria**:
- ✅ normalize_indicators() recognizes family prefixes
- ✅ create_family_index() works for all 4 families
- ✅ nemeton_radar() displays 4-12 axes dynamically
- ✅ Users can compare ecosystem profiles across units
- ✅ All tests passing (>=12 test cases for US6)

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, vignettes, final integration testing, package checks

**Estimated Time**: 6-8 hours

### 9.1 Vignettes

- [X] T107 [P] Create vignettes/temporal-analysis.Rmd with full multi-period workflow
- [X] T108 [P] Create vignettes/indicator-families.Rmd with 12-family framework guide and roadmap
- [X] T109 [P] Update vignettes/getting-started.Rmd with v0.2.0 examples (optional family indicators)
- [X] T110 Build all vignettes and verify they knit successfully

### 9.2 Demo Data Extension

- [X] T111 [P] Attempt to create data/massif_demo_temporal.rda with synthetic 2-period data
- [X] T112 Document massif_demo_temporal in R/data.R with roxygen2
- [X] T113 If massif_demo_temporal infeasible, document limitation in quickstart.md

### 9.3 README & Package Documentation

- [X] T114 [P] Update README.md with v0.2.0 examples (temporal workflow, family scores, radar)
- [X] T115 [P] Update README.md features list (4 families, temporal analysis, 12-axis radar)
- [X] T116 [P] Create man/nemeton-package.Rd overview with @family tags for indicator groups

### 9.4 Integration Testing & Quality Assurance

- [X] T117 Run full test suite: devtools::test() - verify >= 70% coverage target
- [X] T118 Run devtools::check() - verify 0 errors, 0 warnings, 0 notes
- [X] T119 Test backward compatibility: run all v0.1.0 example workflows
- [X] T120 Run lintr::lint_package() - verify code style compliance
- [X] T121 Verify all exported functions have complete roxygen2 (@param, @return, @examples, @seealso)
- [X] T122 Test package installation from source: R CMD INSTALL --build

### 9.5 Real Data Validation

- [X] T123 [P] Test with real cadastral parcel (inst/extdata/360053000AS0090.gpkg)
- [X] T124 Validate allometric models against IFN data if available
- [X] T125 Create integration test with full 10-indicator workflow in tests/testthat/test-integration-full.R

### 9.6 i18n Completeness

- [X] T126 [P] Verify all new messages have FR + EN translations in R/i18n.R
- [X] T127 Test language switching: nemeton_set_language("en") / nemeton_set_language("fr")
- [X] T128 Verify console output messages in both languages

### 9.7 Performance Validation

- [X] T129 Benchmark temporal workflow: 50 units × 3 periods < 10 min (SC-006)
- [X] T130 Benchmark TWI calculation: 100+ units < 2 min (SC-010)
- [X] T131 Verify package size < 5 Mo excluding vignettes (constitution requirement)

### 9.8 Final Package Checks

- [X] T132 Run covr::package_coverage() - verify >= 70% target (aim for 80%)
- [X] T133 Run goodpractice::gp() for additional quality checks
- [X] T134 Review DESCRIPTION: version bump to 0.2.0, update authors, check dependencies
- [X] T135 Review NEWS.md: document all v0.2.0 changes (if exists, or create)

**Phase 9 Completion Criteria**:
- ✅ 2 new vignettes complete and buildable
- ✅ All 100-150 new tests passing
- ✅ Test coverage >= 70% (ideally >= 80%)
- ✅ devtools::check() clean (0/0/0)
- ✅ All performance benchmarks met
- ✅ Backward compatibility verified
- ✅ Package installable and functional

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**Recommended MVP** = User Story 1 (US1) only:
- Implement temporal infrastructure (nemeton_temporal, calculate_change_rate, plots)
- Test with existing 5 v0.1.0 indicators
- Delivers standalone value: temporal analysis capability
- **Estimated effort**: ~10-15 hours
- **Risk**: Low (extends existing patterns)

### Incremental Delivery Roadmap

**Sprint 1** (US1 - Temporal): 10-15 hours
- Tasks T001-T028 (Setup + Phase 2 + Phase 3)
- **Deliverable**: Working temporal analysis for existing indicators
- **Demo**: 2-period carbon evolution plot

**Sprint 2** (US2 - Carbon): 8-10 hours
- Tasks T029-T044 (Phase 4)
- **Deliverable**: C1 biomass + C2 NDVI + score_carbon
- **Demo**: Accurate biomass from BD Forêt + carbon family score

**Sprint 3** (US3 - Water): 10-12 hours
- Tasks T045-T062 (Phase 5)
- **Deliverable**: W1, W2, W3 + score_water
- **Demo**: Complete water regulation assessment + TWI maps

**Sprint 4** (US4+US5 - Soil & Landscape): 10-12 hours
- Tasks T063-T088 (Phases 6-7)
- **Deliverable**: F1-F2 + L1-L2 + family scores
- **Demo**: 4-family ecosystem profile

**Sprint 5** (US6 - Multi-Family): 8-10 hours
- Tasks T089-T106 (Phase 8)
- **Deliverable**: Family-aware normalization + 12-axis radar
- **Demo**: Multi-family radar comparison

**Sprint 6** (Polish): 10-12 hours
- Tasks T107-T135 (Phase 9)
- **Deliverable**: Vignettes, documentation, v0.2.0 release-ready

**Total Estimated Effort**: 56-71 hours (7-9 full working days)

---

## Dependencies & Execution Order

### Critical Path

```
Phase 1 (Setup)
  └─→ Phase 2 (Foundational)
       ├─→ Phase 3 (US1 - Temporal) ← Can run independently
       ├─→ Phase 4 (US2 - Carbon)   ← Can run independently
       ├─→ Phase 5 (US3 - Water)    ← Can run independently
       ├─→ Phase 6 (US4 - Soil)     ← Can run independently
       ├─→ Phase 7 (US5 - Landscape)← Can run independently
       └─→ (Phases 3-7 in parallel)
            └─→ Phase 8 (US6 - Multi-Family) ← Depends on at least 2 families
                 └─→ Phase 9 (Polish) ← Depends on all phases
```

### Parallel Execution Opportunities

**After Phase 2 completion**, the following can run in parallel:
- **US1 (Temporal)**: Independent, only depends on foundational utils
- **US2 (Carbon)**: Independent, only depends on allometric helpers
- **US3 (Water)**: Independent, only depends on i18n
- **US4 (Soil)**: Independent, only depends on i18n
- **US5 (Landscape)**: Independent, only depends on i18n

**US6 requires at least 2 families** to be meaningful (e.g., US2 + US3), but can be developed once any 2 are complete.

**Example parallel workflow**:
1. Complete Phase 1 + 2 (foundational)
2. Developer A: US1 (temporal)
3. Developer B: US2 (carbon)
4. Developer C: US3 (water)
5. Merge US1-US3
6. Developer A: US4 (soil)
7. Developer B: US5 (landscape)
8. Developer C: US6 (multi-family) - starts as soon as 2 families ready
9. Merge all
10. Developer A+B+C: Phase 9 (polish) together

---

## Testing Strategy

### Test Distribution (Target: 100-150 new tests for >= 70% coverage)

| Phase | Test Cases | File |
|-------|-----------|------|
| Foundational | 5-8 | test-utils-allometric.R |
| US1 (Temporal) | 10-15 | test-temporal.R, test-integration-temporal.R |
| US2 (Carbon) | 12-15 | test-indicators-families.R |
| US3 (Water) | 15-18 | test-indicators-families.R |
| US4 (Soil) | 10-12 | test-indicators-families.R |
| US5 (Landscape) | 8-10 | test-indicators-families.R |
| US6 (Multi-Family) | 12-15 | test-normalization.R, test-composite.R, test-visualization.R |
| Integration | 8-12 | test-integration-full.R |
| **Total** | **100-125** | - |

### Test Types per User Story

1. **Unit Tests**: Each exported function has >= 3 test cases
2. **Edge Case Tests**: NA handling, zero values, extreme inputs
3. **Integration Tests**: Full workflow per user story
4. **Regression Tests**: Allometric models, TWI values (using fixtures)
5. **Backward Compatibility Tests**: v0.1.0 workflows still work

### TDD Workflow (Constitution Requirement)

For each new function:
1. **Write test first** (expect_equal, expect_error, etc.)
2. **Run test** → RED (fails)
3. **Write minimal code** to pass test
4. **Run test** → GREEN (passes)
5. **Refactor** if needed
6. **Add roxygen2 documentation**
7. **Repeat** for next test case

---

## Risk Mitigation

### High-Risk Tasks

| Task | Risk | Mitigation |
|------|------|------------|
| T054-T059 (TWI) | Whitebox dependency issues | Terra fallback implemented (TD-003) |
| T030-T034 (Allometric) | Accuracy < 85% (±15% target) | Use validated IFN equations, test against fixtures |
| T062 (TWI performance) | 100 units timeout | Optimize or document limitation, consider batch processing |
| T111-T113 (Temporal demo data) | Synthetic data hard to create | Make optional, document in quickstart as manual setup |

### Blocker Scenarios

1. **Allometric accuracy fails**: Fall back to simpler generic model, document limitation
2. **Whitebox installation problems**: Use terra D8 fallback (already planned)
3. **Test coverage < 70%**: Prioritize unit tests for exported functions, defer integration tests
4. **Performance targets missed**: Document as known limitation, optimize in v0.2.1 patch

---

## Success Metrics (from spec.md SC-001 to SC-018)

**Functional Completeness**:
- ✅ SC-001: Temporal change rates computed for all 5 existing indicators across 2+ periods
- ✅ SC-002: C1 biomass accuracy within 15% of IFN reference values
- ✅ SC-003: W1, W2, W3 completed → score_water
- ✅ SC-004: F2 > 70 and F1 < 2 identifiable
- ✅ SC-005: L1, L2 calculated for connectivity planning

**Performance & Quality**:
- ✅ SC-006: Temporal workflow < 10 min for 50 units × 3 periods (95% users)
- ✅ SC-007: Test coverage >= 70%
- ✅ SC-008: New users run first temporal analysis within 30 min (via vignettes)

**Data Integration**:
- ✅ SC-009: BD Forêt v2 processed with 90% French species coverage
- ✅ SC-010: TWI completes for 100+ units in < 2 min
- ✅ SC-011: Partial family scores calculable when sub-indicators missing

**Visualization**:
- ✅ SC-012: Multi-family radar generated in single function call
- ✅ SC-013: Temporal trend plots with automatic date labeling
- ✅ SC-014: 80% users find family indices easier to interpret (qualitative via user feedback)

**Backward Compatibility**:
- ✅ SC-015: All v0.1.0 workflows function without modification
- ✅ SC-016: indicator_carbon() migration requires zero code changes

**Future-Proofing**:
- ✅ SC-017: Temporal infrastructure supports 12 families (v0.3.0+) without architectural changes
- ✅ SC-018: Family score system scales to 36 sub-indicators (12 families × 3 avg)

---

## Task Summary

**Total Tasks**: 135
- **Phase 1 (Setup)**: 4 tasks
- **Phase 2 (Foundational)**: 7 tasks
- **Phase 3 (US1 - Temporal)**: 17 tasks
- **Phase 4 (US2 - Carbon)**: 16 tasks
- **Phase 5 (US3 - Water)**: 18 tasks
- **Phase 6 (US4 - Soil)**: 13 tasks
- **Phase 7 (US5 - Landscape)**: 13 tasks
- **Phase 8 (US6 - Multi-Family)**: 18 tasks
- **Phase 9 (Polish)**: 29 tasks

**Parallel Tasks**: 52 tasks marked [P] (38.5%)

**Test Tasks**: ~60-70 tasks (TDD - tests written before implementation)

**Estimated Total Effort**: 56-71 hours (7-9 full days)

**Recommended MVP**: Phase 1 + 2 + 3 (US1 only) = ~15 hours

---

## Format Validation ✅

All 135 tasks follow the required checklist format:
- ✅ Checkbox present (`- [ ]`)
- ✅ Sequential Task IDs (T001-T135)
- ✅ [P] markers for parallelizable tasks (52 tasks)
- ✅ [Story] labels for user story tasks (US1-US6)
- ✅ File paths included in descriptions
- ✅ Clear, actionable descriptions

**Next Step**: Begin implementation with Phase 1 (Setup) or proceed directly to MVP (US1 only).
