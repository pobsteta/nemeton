# Tasks: MVP v0.3.0 - Multi-Family Indicator Extension

**Input**: Design documents from `/specs/001-mvp-v0-3-0/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: TDD approach required (constitution principle IV). Write tests BEFORE implementing each indicator function.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1-US6)
- Include exact file paths in descriptions

## Path Conventions

R package structure:
- **Source code**: `R/` (package root)
- **Tests**: `tests/testthat/`
- **Fixtures**: `tests/testthat/fixtures/`
- **Vignettes**: `vignettes/`
- **Demo data**: `data/`, `inst/extdata/massif_demo/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization for v0.3.0 development

- [X] T001 Create R/ module files: indicators-biodiversity.R, indicators-risk.R, indicators-temporal.R, indicators-air.R, analysis-correlation.R
- [X] T002 Create test/ module files: test-indicators-biodiversity.R, test-indicators-risk.R, test-indicators-temporal.R, test-indicators-air.R, test-analysis-correlation.R
- [X] T003 [P] Create fixtures directory: tests/testthat/fixtures/ and subdirectories (protected_areas/, land_cover/, climate/)
- [X] T004 [P] Update DESCRIPTION: Add Suggests: rnaturalearth, osmdata (new dependencies from research.md)
- [X] T005 [P] Extend R/i18n.R: Add message keys for new indicators (B1-B3, R1-R3, T1-T2, A1-A2)

**Checkpoint**: Project structure ready for indicator development

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Create test fixtures: protected_areas_demo.rds (ZNIEFF/Natura2000 sample for B1 tests) in tests/testthat/fixtures/
- [X] T007 [P] Create test fixtures: land_cover_2020.rds, land_cover_1990.rds (CLC snippets for T2 tests) in tests/testthat/fixtures/
- [X] T008 [P] Create test fixtures: climate_data.rds (precipitation/temperature for R1, R3 tests) in tests/testthat/fixtures/
- [X] T009 Create internal data: species_flammability_lookup.rda (for R1), species_drought_sensitivity_lookup.rda (for R3) in R/sysdata.rda
- [X] T010 [P] Extend R/utils.R: Add helper functions for species lookups (get_species_flammability, get_species_drought_sensitivity)
- [X] T011 [P] Extend R/utils.R: Add Shannon diversity calculation helper (calculate_shannon_h)
- [X] T012 Extend R/family-system.R: Update all_families vector to include c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
- [X] T013 Extend R/family-system.R: Update get_family_name() bilingual mappings for B, R, T, A families (already done per previous context)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Biodiversity Assessment (Priority: P1) 🎯 MVP

**Goal**: Implement B1 (protection status), B2 (structural diversity), B3 (ecological connectivity) indicators to assess biodiversity potential

**Independent Test**: Calculate B1, B2, B3 for massif_demo_units and verify: (1) Protected areas get B1>75, (2) Diverse stands get B2>50, (3) Parcels near corridors get B3<500m

### Tests for User Story 1 (TDD: Write FIRST, ensure FAIL before implementation)

- [X] T014 [P] [US1] Unit test for indicator_biodiversity_protection() in tests/testthat/test-indicators-biodiversity.R (test WFS fetch, local fallback, overlap calculation)
- [X] T015 [P] [US1] Unit test for indicator_biodiversity_structure() in tests/testthat/test-indicators-biodiversity.R (test Shannon H calculation, strata+age weighting, height CV fallback)
- [X] T016 [P] [US1] Unit test for indicator_biodiversity_connectivity() in tests/testthat/test-indicators-biodiversity.R (test edge distance, normalization, max_distance cap)
- [X] T017 [US1] Integration test for B family workflow in tests/testthat/test-indicators-biodiversity.R (compute B1-B3 → normalize → create family_B → verify composite)
- [X] T018 [US1] Regression test fixture: Create expected_indicators_v030_biodiversity.rds with known B1/B2/B3 values for massif_demo in tests/testthat/fixtures/

### Implementation for User Story 1

- [X] T019 [P] [US1] Implement indicator_biodiversity_protection() in R/indicators-biodiversity.R (WFS fetch, local data, overlap calculation, B1 output)
- [X] T020 [P] [US1] Implement indicator_biodiversity_structure() in R/indicators-biodiversity.R (Shannon H for strata+age, weighting, normalization, B2 output)
- [X] T021 [P] [US1] Implement indicator_biodiversity_connectivity() in R/indicators-biodiversity.R (distance calculation, normalization, B3+B3_norm output)
- [X] T022 [US1] Add roxygen2 documentation for all 3 functions (indicator_biodiversity_*) with @param, @return, @examples
- [X] T023 [US1] Add bilingual messages (FR/EN) for B1, B2, B3 calculations using msg_info/msg_warn from i18n.R
- [X] T024 [US1] Run devtools::test() and verify all US1 tests pass (≥15 tests for B family)
- [X] T025 [US1] Run devtools::check() and ensure 0 errors, 0 warnings (UTF-8 acceptable)

**Checkpoint**: B family indicators (B1, B2, B3) fully functional and tested independently

---

## Phase 4: User Story 2 - Risk Assessment & Resilience (Priority: P1)

**Goal**: Implement R1 (fire risk), R2 (storm vulnerability), R3 (drought stress) to quantify forest vulnerabilities

**Independent Test**: Calculate R1, R2, R3 for massif_demo_units and verify: (1) Steep slopes + pine → R1>60, (2) Tall dense stands → R2>50, (3) Low TWI + sensitive species → R3>60

### Tests for User Story 2 (TDD: Write FIRST)

- [X] T026 [P] [US2] Unit test for indicator_risk_fire() in tests/testthat/test-indicators-risk.R (test slope factor, species flammability lookup, climate dryness, composite formula)
- [X] T027 [P] [US2] Unit test for indicator_risk_storm() in tests/testthat/test-indicators-risk.R (test height factor, density factor, topographic exposure, composite formula)
- [X] T028 [P] [US2] Unit test for indicator_risk_drought() in tests/testthat/test-indicators-risk.R (test inverse TWI, precipitation deficit, species sensitivity lookup, composite formula)
- [X] T029 [US2] Integration test for R family workflow in tests/testthat/test-indicators-risk.R (compute R1-R3 → normalize → create family_R → verify composite)
- [X] T030 [US2] Regression test fixture: Create expected_indicators_v030_risk.rds with known R1/R2/R3 values in tests/testthat/fixtures/

### Implementation for User Story 2

- [X] T031 [P] [US2] Implement indicator_risk_fire() in R/indicators-risk.R (slope from DEM, species lookup, climate data, weighted composite, R1 output)
- [X] T032 [P] [US2] Implement indicator_risk_storm() in R/indicators-risk.R (height/density attributes, topographic position, weighted composite, R2 output)
- [X] T033 [P] [US2] Implement indicator_risk_drought() in R/indicators-risk.R (inverse TWI reuse W3, precip data, species lookup, weighted composite, R3 output)
- [X] T034 [US2] Add roxygen2 documentation for all 3 functions (indicator_risk_*) with @param, @return, @examples
- [X] T035 [US2] Add bilingual messages (FR/EN) for R1, R2, R3 calculations
- [X] T036 [US2] Run devtools::test() and verify all US2 tests pass (≥15 tests for R family)
- [X] T037 [US2] Run devtools::check() and ensure 0 errors, 0 warnings

**Checkpoint**: R family indicators (R1, R2, R3) fully functional and tested independently

---

## Phase 5: User Story 3 - Temporal Dynamics (Priority: P1)

**Goal**: Implement T1 (stand age), T2 (land use change rate) to measure forest history and transformation dynamics

**Independent Test**: Calculate T1, T2 for massif_demo_units and verify: (1) Documented 1850 planting → T1≈175yr, (2) CLC 1990-2020 transition → T2 reflects change rate

### Tests for User Story 3 (TDD: Write FIRST)

- [X] T038 [P] [US3] Unit test for indicator_temporal_age() in tests/testthat/test-indicators-temporal.R (test age field, establishment year calculation, log normalization)
- [X] T039 [P] [US3] Unit test for indicator_temporal_change() in tests/testthat/test-indicators-temporal.R (test terra raster diff, exactextractr zonal stats, annualized rate, interpretation modes)
- [X] T040 [US3] Integration test for T family workflow in tests/testthat/test-indicators-temporal.R (compute T1-T2 → normalize → create family_T → verify composite)
- [X] T041 [US3] Regression test fixture: Create expected_indicators_v030_temporal.rds with known T1/T2 values in tests/testthat/fixtures/

### Implementation for User Story 3

- [X] T042 [P] [US3] Implement indicator_temporal_age() in R/indicators-temporal.R (age field or establishment year, current year default, log normalization, T1+T1_norm output)
- [X] T043 [P] [US3] Implement indicator_temporal_change() in R/indicators-temporal.R (terra raster algebra, exactextractr zonal stats, annualization, interpretation param, T2+T2_norm output)
- [X] T044 [US3] Add roxygen2 documentation for both functions (indicator_temporal_*) with @param, @return, @examples
- [X] T045 [US3] Add bilingual messages (FR/EN) for T1, T2 calculations
- [X] T046 [US3] Run devtools::test() and verify all US3 tests pass (≥10 tests for T family)
- [X] T047 [US3] Run devtools::check() and ensure 0 errors, 0 warnings

**Checkpoint**: T family indicators (T1, T2) fully functional and tested independently

---

## Phase 6: User Story 4 - Air Quality & Microclimate (Priority: P2)

**Goal**: Implement A1 (tree coverage buffer), A2 (air quality) to evaluate forest role in local climate and air quality

**Independent Test**: Calculate A1, A2 for massif_demo_units and verify: (1) Dense forest buffer → A1>80%, (2) Distance proxy correlates with expected pollution gradients

### Tests for User Story 4 (TDD: Write FIRST)

- [X] T048 [P] [US4] Unit test for indicator_air_coverage() in tests/testthat/test-indicators-air.R (test buffer creation, forest class filtering, coverage calculation)
- [X] T049 [P] [US4] Unit test for indicator_air_quality() in tests/testthat/test-indicators-air.R (test direct ATMO method, proxy method, road/urban distance weighting, method detection)
- [X] T050 [US4] Integration test for A family workflow in tests/testthat/test-indicators-air.R (compute A1-A2 → normalize → create family_A → verify composite)
- [X] T051 [US4] Regression test fixture: Create expected_indicators_v030_air.rds with known A1/A2 values in tests/testthat/fixtures/

### Implementation for User Story 4

- [X] T052 [P] [US4] Implement indicator_air_coverage() in R/indicators-air.R (sf buffer, land cover raster, forest class filter, coverage calc, A1 output)
- [X] T053 [P] [US4] Implement indicator_air_quality() in R/indicators-air.R (ATMO direct method, OSM/CLC proxy method, auto-detection, weighted distance, A2+A2_method output)
- [X] T054 [US4] Add roxygen2 documentation for both functions (indicator_air_*) with @param, @return, @examples
- [X] T055 [US4] Add bilingual messages (FR/EN) for A1, A2 calculations
- [X] T056 [US4] Run devtools::test() and verify all US4 tests pass (≥10 tests for A family)
- [X] T057 [US4] Run devtools::check() and ensure 0 errors, 0 warnings

**Checkpoint**: A family indicators (A1, A2) fully functional and tested independently

---

## Phase 7: User Story 5 - Integrated Multi-Family Indices (Priority: P2)

**Goal**: Extend normalization and aggregation system to support new families (B, R, T, A) and generate consistent composites

**Independent Test**: Normalize B1-B3, R1-R3, T1-T2, A1-A2 → create family_B, family_R, family_T, family_A → verify radar plot displays 9 axes

### Tests for User Story 5 (TDD: Write FIRST)

- [X] T058 [P] [US5] Test normalize_indicators() extension in tests/testthat/test-normalization.R (verify B*, R*, T*, A* prefix recognition, appropriate methods)
- [X] T059 [P] [US5] Test create_family_index() extension in tests/testthat/test-family-system.R (verify B, R, T, A family codes, correct aggregation)
- [X] T060 [P] [US5] Test nemeton_radar() extension in tests/testthat/test-visualization.R (verify 9-axis plot, no visual artifacts, correct scaling)
- [X] T061 [US5] Integration test: Full workflow (load massif_demo → compute all 10 indicators → normalize → aggregate → radar plot) in tests/testthat/test-workflow-v030.R

### Implementation for User Story 5

- [X] T062 [US5] Extend R/normalization.R: Update normalize_indicators() to recognize B*, R*, T*, A* prefixes and apply appropriate methods (linear, inverse, log)
- [X] T063 [US5] Extend R/family-system.R: Update create_family_index() to handle family codes B, R, T, A (add to family_groups logic)
- [X] T064 [US5] Extend R/visualization.R: Update nemeton_radar() to support up to 12 axes (currently handles 5, extend to 9-12 for future families)
- [X] T065 [US5] Add roxygen2 documentation updates for extended functions (normalize_indicators, create_family_index, nemeton_radar) - note v0.3.0 capabilities
- [X] T066 [US5] Run devtools::test() and verify all US5 tests pass (≥10 tests for integration)
- [X] T067 [US5] Verify backward compatibility: Run all 661 v0.2.0 tests and ensure 100% pass rate

**Checkpoint**: Integration layer complete - all 9 families (C, B, W, A, F, L, T, R, existing) work together seamlessly

---

## Phase 8: User Story 6 - Cross-Family Analysis (Priority: P3)

**Goal**: Implement correlation analysis and hotspot identification to reveal synergies and trade-offs between families

**Independent Test**: Compute correlation matrix for 9 families → identify expected relationships (B×T positive) → detect multi-criteria hotspots (top 20% in ≥3 families)

### Tests for User Story 6 (TDD: Write FIRST)

- [X] T068 [P] [US6] Unit test for compute_family_correlations() in tests/testthat/test-analysis-correlation.R (test correlation matrix calculation, NA handling, family selection)
- [X] T069 [P] [US6] Unit test for identify_hotspots() in tests/testthat/test-analysis-correlation.R (test multi-criteria filtering, percentile thresholds, output format)
- [X] T070 [US6] Integration test for cross-family analysis workflow in tests/testthat/test-analysis-correlation.R (compute indicators → family indices → correlations → hotspots → verify)

### Implementation for User Story 6

- [X] T071 [P] [US6] Implement compute_family_correlations() in R/analysis-correlation.R (correlation matrix for family_*, Pearson/Spearman methods, visualization helper)
- [X] T072 [P] [US6] Implement identify_hotspots() in R/analysis-correlation.R (multi-criteria filtering, percentile thresholds, spatial output with hotspot flag)
- [X] T073 [P] [US6] Implement plot_correlation_matrix() helper in R/analysis-correlation.R (corrplot-style visualization for family correlations)
- [X] T074 [US6] Add roxygen2 documentation for all functions in analysis-correlation.R with @param, @return, @examples
- [X] T075 [US6] Add bilingual messages (FR/EN) for correlation analysis operations
- [X] T076 [US6] Run devtools::test() and verify all US6 tests pass (≥10 tests for cross-family analysis)

**Checkpoint**: Cross-family analysis complete - users can explore synergies, trade-offs, and multi-criteria optimization

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, vignettes, and final validation

- [X] T077 [P] Create vignette: vignettes/biodiversity-resilience.Rmd (demonstrate B, R, T, A families workflow ~1500-2000 words)
- [ ] T078 [P] Update vignette: vignettes/indicator-families.Rmd (update to reflect 9/12 families implemented, add v0.3.0 examples)
- [ ] T079 [P] Extend demo data: Add historical attributes to data/massif_demo_units.rda if feasible (age, establishment_year for T1 examples)
- [ ] T080 [P] Create demo data: inst/extdata/massif_demo/protected_areas/ (synthetic ZNIEFF zones for B1 examples)
- [ ] T081 [P] Create demo data: inst/extdata/massif_demo/land_cover_1990.tif (historical land cover for T2 examples)
- [ ] T082 [P] Create demo data: inst/extdata/massif_demo/climate/ (temperature/precipitation rasters for R1, R3 examples)
- [X] T083 Update README.md: Add v0.3.0 features (9 families, 10 new indicators, cross-family analysis) with code examples
- [X] T084 Update NEWS.md: Document v0.3.0 changes (new indicators, extended functions, backward compatibility notes)
- [ ] T085 Run devtools::build_vignettes() and verify all vignettes knit successfully
- [X] T086 Run devtools::document() to regenerate all .Rd files from roxygen2
- [X] T087 Run devtools::check() final validation: 0 errors, 0 warnings (except UTF-8), 0 notes
- [X] T088 Run covr::package_coverage() and verify ≥70% total coverage (aim for ≥80% on new code)
- [X] T089 Build pkgdown site: pkgdown::build_site() and verify navigation, function reference, vignettes display correctly
- [ ] T090 Run quickstart.md validation: Execute all code snippets from quickstart.md and verify expected outputs

**Checkpoint**: Package ready for v0.3.0 release - all documentation, tests, and examples complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-8)**: All depend on Foundational phase completion
  - US1-US4 (indicators) can proceed in parallel (different R/ files)
  - US5 (integration) depends on US1-US4 being complete (needs indicators to integrate)
  - US6 (cross-family) depends on US5 being complete (needs family composites for correlation)
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Biodiversity - P1)**: After Foundational → Independent (no dependencies on other stories)
- **US2 (Risk - P1)**: After Foundational → Independent (reuses W3 from v0.2.0 for R3, but that's existing)
- **US3 (Temporal - P1)**: After Foundational → Independent (no dependencies on other stories)
- **US4 (Air - P2)**: After Foundational → Independent (no dependencies on other stories)
- **US5 (Integration - P2)**: Depends on US1-US4 completion (needs B, R, T, A indicators to normalize/aggregate)
- **US6 (Cross-Family - P3)**: Depends on US5 completion (needs family_B, family_R, family_T, family_A composites)

### Within Each User Story

**TDD Pattern** (Tests → Implementation → Documentation):
1. Write unit tests (MUST fail initially - Red phase)
2. Implement function until tests pass (Green phase)
3. Refactor for clarity (Refactor phase - keep tests green)
4. Add integration tests
5. Add regression test fixtures
6. Document with roxygen2
7. Add bilingual messages
8. Run devtools::test() and devtools::check()

### Parallel Opportunities

**Setup (Phase 1)**: All 5 tasks can run in parallel (T001-T005 marked [P])

**Foundational (Phase 2)**: Tasks T006-T008, T010-T011 can run in parallel (different fixtures and utils)

**Indicators (Phases 3-6)**: Once Foundational complete, ALL 4 families can be developed in parallel:
- Team Member A: US1 (Biodiversity) - T014-T025
- Team Member B: US2 (Risk) - T026-T037
- Team Member C: US3 (Temporal) - T038-T047
- Team Member D: US4 (Air) - T048-T057

**Within Each Story**: Tests can run in parallel (e.g., T014, T015, T016 all [P]), Models can run in parallel (e.g., T019, T020, T021 all [P])

**Polish (Phase 9)**: Tasks T077-T082 (vignettes and demo data) can run in parallel

---

## Parallel Example: User Story 1 (Biodiversity)

```bash
# Step 1: Launch all tests together (TDD - ensure they FAIL first):
Task: "Unit test for indicator_biodiversity_protection() in tests/testthat/test-indicators-biodiversity.R"
Task: "Unit test for indicator_biodiversity_structure() in tests/testthat/test-indicators-biodiversity.R"
Task: "Unit test for indicator_biodiversity_connectivity() in tests/testthat/test-indicators-biodiversity.R"

# Step 2: Launch all implementations together (after tests fail):
Task: "Implement indicator_biodiversity_protection() in R/indicators-biodiversity.R"
Task: "Implement indicator_biodiversity_structure() in R/indicators-biodiversity.R"
Task: "Implement indicator_biodiversity_connectivity() in R/indicators-biodiversity.R"

# Step 3: Sequential tasks (documentation, validation):
Task: "Add roxygen2 documentation for all 3 functions"
Task: "Run devtools::test() and verify all US1 tests pass"
```

---

## Implementation Strategy

### MVP First (Just User Story 1)

**Minimal Viable Product** - Deliver biodiversity assessment capability:

1. Complete Phase 1: Setup (T001-T005) → ~1 hour
2. Complete Phase 2: Foundational (T006-T013) → ~2-3 hours
3. Complete Phase 3: User Story 1 (T014-T025) → ~1-2 days
4. **STOP and VALIDATE**:
   - Run devtools::test() - expect ≥15 tests passing
   - Test B1, B2, B3 on massif_demo_units
   - Verify protected area data fetches from INPN
   - Calculate family_B composite
5. **Deploy/Demo**: Show biodiversity indicators to stakeholders

**Why MVP = US1**: Biodiversity is highest priority (P1), independently valuable, demonstrates v0.3.0 architecture

### Incremental Delivery (Add Stories Sequentially)

**Each increment adds value without breaking previous stories**:

1. **Foundation** (Setup + Foundational) → 3-4 hours
2. **MVP** (+US1 Biodiversity) → Test independently → Demo (Day 1-2)
3. **+Risk** (+US2) → Test independently → Demo (Day 3-4)
4. **+Temporal** (+US3) → Test independently → Demo (Day 5)
5. **+Air** (+US4) → Test independently → Demo (Day 6)
6. **+Integration** (+US5) → All 9 families working, radar plot → Demo (Day 7)
7. **+Cross-Family** (+US6) → Correlation analysis, hotspots → Demo (Day 8)
8. **Polish** (Phase 9) → Vignettes, final docs → Release (Day 9-10)

**Total Estimate**: ~10-12 days for solo developer, ~5-7 days with 2-3 parallel developers

### Parallel Team Strategy

**With 3 developers (optimal for Phases 3-6)**:

1. **Team completes Setup + Foundational together** (Day 1) → Foundation ready
2. **Phase 3-6: Parallel indicator development** (Day 2-5):
   - Developer A: User Story 1 (Biodiversity - T014-T025)
   - Developer B: User Story 2 (Risk - T026-T037)
   - Developer C: User Story 3 (Temporal - T038-T047)
   - (Developer C continues with US4 Air after US3 complete)
3. **Phase 7: Integration** (Day 6) - Single developer (US5 T058-T067)
4. **Phase 8: Cross-Family** (Day 7) - Single developer (US6 T068-T076)
5. **Phase 9: Polish** (Day 8-9) - Team parallelizes vignettes/docs (T077-T090)

**Benefit**: Reduces total time from 10-12 days to 8-9 days, all stories independently validated

---

## Notes

- **[P] tasks**: Different files, no dependencies → safe to parallelize
- **[Story] label**: Maps task to specific user story for traceability
- **TDD required**: Constitution principle IV - write tests BEFORE implementation
- **Backward compatibility**: All 661 v0.2.0 tests MUST pass (verified at T067)
- **Coverage target**: ≥70% (spec), aim for ≥80% (constitution), track per module
- **R CMD check**: Must pass with 0 errors, 0 warnings (UTF-8 acceptable), 0 notes
- **Commit strategy**: Commit after each logical task or group (e.g., after T025 - US1 complete)
- **Checkpoint validation**: Stop at each checkpoint to test story independently before proceeding
- **Avoid**: Same file conflicts (e.g., don't edit normalization.R in parallel), cross-story dependencies that break independence

---

## Task Count Summary

- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 8 tasks
- **Phase 3 (US1 - Biodiversity)**: 12 tasks (5 tests + 7 implementation)
- **Phase 4 (US2 - Risk)**: 12 tasks (5 tests + 7 implementation)
- **Phase 5 (US3 - Temporal)**: 10 tasks (4 tests + 6 implementation)
- **Phase 6 (US4 - Air)**: 10 tasks (4 tests + 6 implementation)
- **Phase 7 (US5 - Integration)**: 10 tasks (4 tests + 6 implementation)
- **Phase 8 (US6 - Cross-Family)**: 9 tasks (3 tests + 6 implementation)
- **Phase 9 (Polish)**: 14 tasks (vignettes, docs, validation)

**TOTAL**: 90 tasks

**Parallel Opportunities**: ~40 tasks marked [P] can run in parallel (44% of total)

**Independent Test Criteria**:
- **US1**: B1, B2, B3 calculate correctly for massif_demo → family_B composite works
- **US2**: R1, R2, R3 calculate correctly → family_R composite works
- **US3**: T1, T2 calculate correctly → family_T composite works
- **US4**: A1, A2 calculate correctly → family_A composite works
- **US5**: All 9 families normalize and aggregate → radar plot displays 9 axes
- **US6**: Correlation matrix computes → hotspots identified

**Suggested MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Story 1 - Biodiversity) = 25 tasks (~2-3 days solo)
