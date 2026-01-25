# Tasks: MVP Package nemeton v0.1.0

**Input**: Design documents from `/specs/001-mvp-v0.1.0/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included - TDD is NON-NEGOTIABLE per constitution (Principle IV)

**Organization**: Tasks grouped by user story for independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story identifier (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

R package structure:
- **Code**: `R/`
- **Tests**: `tests/testthat/`
- **Data**: `data/`, `data-raw/`, `inst/extdata/`
- **Docs**: `man/` (generated), `vignettes/`, `README.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: R package initialization and basic structure

- [X] T001 Create R package structure with usethis::create_package("nemeton")
- [X] T002 Configure DESCRIPTION file with dependencies (sf, terra, exactextractr, dplyr, ggplot2, rlang, cli)
- [X] T003 [P] Create directory structure (R/, tests/testthat/, data/, data-raw/, inst/extdata/, vignettes/)
- [X] T004 [P] Setup .gitignore for R package (.Rproj.user, .Rhistory, .RData, etc.)
- [X] T005 [P] Configure testthat framework with usethis::use_testthat()
- [X] T006 [P] Create LICENSE file (MIT or GPL-3)
- [X] T007 [P] Initialize NEWS.md for changelog

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core S3 classes and utilities that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Core Utilities

- [X] T008 [P] Implement check_crs() helper in R/utils.R
- [X] T009 [P] Implement validate_sf() helper in R/utils.R
- [X] T010 [P] Implement message_nemeton() for cli messages in R/utils.R
- [X] T011 [P] Write tests for utils functions in tests/testthat/test-utils.R

### S3 Classes - nemeton_units

- [X] T012 Create nemeton_units() constructor in R/nemeton-class.R
- [X] T013 [P] Implement print.nemeton_units() method in R/nemeton-class.R
- [X] T014 [P] Implement summary.nemeton_units() method in R/nemeton-class.R
- [X] T015 Implement validate_units() internal function in R/data-units.R
- [X] T016 Add roxygen2 documentation for nemeton_units() in R/nemeton-class.R

### S3 Classes - nemeton_layers

- [X] T017 Create nemeton_layers() constructor in R/nemeton-class.R
- [X] T018 [P] Implement print.nemeton_layers() method in R/nemeton-class.R
- [X] T019 [P] Implement summary.nemeton_layers() method in R/nemeton-class.R
- [X] T020 Add roxygen2 documentation for nemeton_layers() in R/nemeton-class.R

### Tests for Core Classes

- [X] T021 [P] Write tests for nemeton_units() creation in tests/testthat/test-units.R
- [X] T022 [P] Write tests for nemeton_units() validation in tests/testthat/test-units.R
- [X] T023 [P] Write tests for nemeton_units() metadata in tests/testthat/test-units.R
- [X] T024 [P] Write tests for nemeton_layers() creation in tests/testthat/test-layers.R
- [X] T025 [P] Write tests for nemeton_layers() validation in tests/testthat/test-layers.R

### Test Fixtures

- [X] T026 [P] Create test fixtures: demo_units.gpkg (10 polygons) in tests/testthat/fixtures/
- [X] T027 [P] Create test fixtures: demo_raster_small.tif in tests/testthat/fixtures/
- [X] T028 [P] Create test fixtures: demo_hydro.gpkg (vectors) in tests/testthat/fixtures/

### Preprocessing Functions

- [X] T029 [P] Implement harmonize_crs() in R/data-preprocessing.R
- [X] T030 [P] Implement crop_to_units() in R/data-preprocessing.R
- [X] T031 [P] Implement mask_to_units() in R/data-preprocessing.R
- [X] T032 Write tests for preprocessing functions in tests/testthat/test-preprocessing.R

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Analyse simple d'une forêt (Priority: P1) 🎯 MVP

**Goal**: Un forestier peut calculer 5 indicateurs clés (carbone, biodiversité, eau, fragmentation, accessibilité) à partir de données spatiales standard

**Independent Test**: Fournir polygones + rasters/vecteurs basiques → retourne sf avec 5 indicateurs calculés

**Acceptance**:
1. nemeton_compute(units, layers, indicators = c("carbon", "biodiversity", "water")) retourne sf avec 3 colonnes d'indicateurs
2. CRS différents → reprojection automatique avec preprocess = TRUE
3. Couche manquante → warning mais autres indicateurs calculés

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation (TDD)**

- [X] T033 [P] [US1] Write test for nemeton_compute() basic functionality in tests/testthat/test-indicators.R
- [X] T034 [P] [US1] Write test for nemeton_compute() with CRS mismatch in tests/testthat/test-indicators.R
- [X] T035 [P] [US1] Write test for nemeton_compute() with missing layer (warning) in tests/testthat/test-indicators.R
- [X] T036 [P] [US1] Write test for indicator_carbon() in tests/testthat/test-indicators.R
- [X] T037 [P] [US1] Write test for indicator_biodiversity() in tests/testthat/test-indicators.R
- [X] T038 [P] [US1] Write test for indicator_water() in tests/testthat/test-indicators.R
- [X] T039 [P] [US1] Write test for indicator_fragmentation() in tests/testthat/test-indicators.R
- [X] T040 [P] [US1] Write test for indicator_accessibility() in tests/testthat/test-indicators.R

### Implementation for User Story 1

#### Core Compute Engine

- [X] T041 [US1] Implement nemeton_compute() core orchestration in R/indicators-core.R
- [X] T042 [US1] Implement compute_indicator() internal dispatcher in R/indicators-core.R
- [X] T043 [US1] Add roxygen2 documentation for nemeton_compute() in R/indicators-core.R

#### Indicator: Carbon

- [X] T044 [P] [US1] Implement indicator_carbon() in R/indicators-biophysical.R
- [X] T045 [P] [US1] Add roxygen2 documentation for indicator_carbon() in R/indicators-biophysical.R

#### Indicator: Biodiversity

- [X] T046 [P] [US1] Implement indicator_biodiversity() in R/indicators-biophysical.R
- [X] T047 [P] [US1] Add roxygen2 documentation for indicator_biodiversity() in R/indicators-biophysical.R

#### Indicator: Water

- [X] T048 [P] [US1] Implement indicator_water() in R/indicators-biophysical.R
- [X] T049 [P] [US1] Add roxygen2 documentation for indicator_water() in R/indicators-biophysical.R

#### Indicator: Fragmentation

- [X] T050 [P] [US1] Implement indicator_fragmentation() in R/indicators-biophysical.R
- [X] T051 [P] [US1] Add roxygen2 documentation for indicator_fragmentation() in R/indicators-biophysical.R

#### Indicator: Accessibility

- [X] T052 [P] [US1] Implement indicator_accessibility() in R/indicators-biophysical.R
- [X] T053 [P] [US1] Add roxygen2 documentation for indicator_accessibility() in R/indicators-biophysical.R

### Integration Tests for User Story 1

- [X] T054 [US1] Write integration test: full workflow units → layers → compute in tests/testthat/test-workflow.R
- [X] T055 [US1] Create expected values fixture for regression tests in tests/testthat/fixtures/expected_carbon.rds

**Checkpoint**: At this point, User Story 1 should be fully functional - can calculate 5 indicators independently ✅

---

## Phase 4: User Story 2 - Normalisation et indice composite (Priority: P2)

**Goal**: L'utilisateur peut normaliser indicateurs bruts (0-100) et calculer un indice Néméton global pondéré

**Independent Test**: Prend sf avec indicateurs bruts → applique normalisation et agrégation → retourne sf avec colonnes normalisées + indice global

**Acceptance**:
1. nemeton_index() ajoute colonne nemeton_index avec valeurs 0-100
2. Polarité inversée (fragmentation = -1) → valeurs inversées avant agrégation
3. normalize = TRUE → normalisation min-max automatique

### Tests for User Story 2

> **NOTE: Write these tests FIRST (TDD)**

- [X] T056 [P] [US2] Write test for normalize_indicators() with minmax method in tests/testthat/test-normalization.R
- [X] T057 [P] [US2] Write test for normalize_indicators() with zscore method in tests/testthat/test-normalization.R
- [X] T058 [P] [US2] Write test for normalize_indicators() with polarity inversion in tests/testthat/test-normalization.R
- [X] T059 [P] [US2] Write test for nemeton_index() weighted aggregation in tests/testthat/test-normalization.R
- [X] T060 [P] [US2] Write test for nemeton_index() with thematic groups in tests/testthat/test-normalization.R
- [X] T061 [P] [US2] Write test for nemeton_index() edge case (no variance) in tests/testthat/test-normalization.R

### Implementation for User Story 2

#### Normalization Functions

- [X] T062 [P] [US2] Implement normalize_indicators() with minmax method in R/normalization.R
- [X] T063 [P] [US2] Implement normalize_indicators() with zscore method in R/normalization.R
- [X] T064 [P] [US2] Implement normalize_indicators() with rank method in R/normalization.R
- [X] T065 [US2] Add polarity handling in normalize_indicators() in R/normalization.R
- [X] T066 [P] [US2] Add roxygen2 documentation for normalize_indicators() in R/normalization.R

#### Aggregation Functions

- [X] T067 [P] [US2] Implement aggregate_weighted() helper in R/normalization.R
- [X] T068 [P] [US2] Implement aggregate_geometric() helper in R/normalization.R
- [X] T069 [P] [US2] Implement aggregate_harmonic() helper in R/normalization.R

#### Index Computation

- [X] T070 [US2] Implement nemeton_index() main function in R/normalization.R
- [X] T071 [US2] Add thematic groups support in nemeton_index() in R/normalization.R
- [X] T072 [US2] Add metadata tracking in nemeton_index() in R/normalization.R
- [X] T073 [P] [US2] Add roxygen2 documentation for nemeton_index() in R/normalization.R

### Integration Tests for User Story 2

- [X] T074 [US2] Write integration test: compute → normalize → index workflow in tests/testthat/test-workflow.R

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently ✅

---

## Phase 5: User Story 3 - Visualisation cartographique (Priority: P2)

**Goal**: L'utilisateur peut visualiser spatialement un indicateur avec une carte thématique prête à l'emploi

**Independent Test**: nemeton_map(data, "carbon") → retourne ggplot valide et sauvegardable

**Acceptance**:
1. nemeton_map(data, "carbon") → ggplot avec géométries colorées par valeur
2. ggplot customisable (+ labs(title = "..."))
3. Indicateur inexistant → erreur explicite

### Tests for User Story 3

> **NOTE: Write these tests FIRST (TDD)**

- [X] T075 [P] [US3] Write test for nemeton_map() basic functionality in tests/testthat/test-visualization.R
- [X] T076 [P] [US3] Write test for nemeton_map() with custom palette in tests/testthat/test-visualization.R
- [X] T077 [P] [US3] Write test for nemeton_map() with custom breaks in tests/testthat/test-visualization.R
- [X] T078 [P] [US3] Write test for nemeton_map() error on invalid indicator in tests/testthat/test-visualization.R
- [X] T079 [P] [US3] Write test for nemeton_map() returns ggplot object in tests/testthat/test-visualization.R

### Implementation for User Story 3

#### Map Visualization

- [X] T080 [P] [US3] Implement classify_values() helper for breaks in R/visualization.R
- [X] T081 [US3] Implement nemeton_map() core function in R/visualization.R
- [X] T082 [US3] Add palette support (viridis, RColorBrewer) in nemeton_map() in R/visualization.R
- [X] T083 [US3] Add classification methods (quantile, equal, jenks) in nemeton_map() in R/visualization.R
- [X] T084 [P] [US3] Add roxygen2 documentation for nemeton_map() in R/visualization.R

### Integration Tests for User Story 3

- [X] T085 [US3] Write integration test: compute → map workflow in tests/testthat/test-workflow.R

**Checkpoint**: At this point, User Stories 1, 2 AND 3 should all work independently ✅

---

## Phase 6: User Story 4 - Profil radar d'une unité (Priority: P3)

**Goal**: L'utilisateur peut visualiser le profil multi-dimensionnel d'une parcelle sous forme de radar chart

**Independent Test**: nemeton_radar(data, unit_id = 5) → retourne radar chart ggplot

**Acceptance**:
1. nemeton_radar(data, unit_id = 5) → radar chart avec 5 axes pour unité 5
2. unit_id = NULL → radar affiche moyenne de toutes unités
3. normalize = TRUE → normalisation 0-100 avant affichage

### Tests for User Story 4

> **NOTE: Write these tests FIRST (TDD)**

- [X] T086 [P] [US4] Write test for nemeton_radar() with specific unit in tests/testthat/test-visualization.R
- [X] T087 [P] [US4] Write test for nemeton_radar() with average (unit_id = NULL) in tests/testthat/test-visualization.R
- [X] T088 [P] [US4] Write test for nemeton_radar() with normalization in tests/testthat/test-visualization.R
- [X] T089 [P] [US4] Write test for nemeton_radar() error on invalid unit_id in tests/testthat/test-visualization.R
- [X] T090 [P] [US4] Write test for nemeton_radar() returns ggplot object in tests/testthat/test-visualization.R

### Implementation for User Story 4

#### Radar Visualization

- [X] T091 [P] [US4] Implement prepare_radar_data() helper in R/visualization.R
- [X] T092 [US4] Implement nemeton_radar() core function with coord_polar() in R/visualization.R
- [X] T093 [US4] Add unit selection logic in nemeton_radar() in R/visualization.R
- [X] T094 [US4] Add custom axis labels support in nemeton_radar() in R/visualization.R
- [X] T095 [P] [US4] Add roxygen2 documentation for nemeton_radar() in R/visualization.R

### Integration Tests for User Story 4

- [X] T096 [US4] Write integration test: compute → index → radar workflow in tests/testthat/test-workflow.R

**Checkpoint**: All 4 user stories should now be independently functional ✅

---

## Phase 7: Example Data & Documentation

**Purpose**: Create example dataset, vignettes, and documentation

### Example Dataset

- [X] T097 [P] Create massif_demo dataset generation script in data-raw/massif_demo.R
- [X] T098 [P] Generate 50 synthetic forest parcels with st_sf() in data-raw/massif_demo.R
- [X] T099 [P] Add metadata attributes to massif_demo in data-raw/massif_demo.R
- [X] T100 Create massif_demo.rda with usethis::use_data() in data-raw/massif_demo.R
- [X] T101 [P] Add roxygen2 documentation for massif_demo in R/data.R

### Example Rasters

- [X] T102 [P] Create synthetic NDVI raster in inst/extdata/demo_ndvi.tif
- [X] T103 [P] Create synthetic DEM raster in inst/extdata/demo_dem.tif
- [X] T104 [P] Create synthetic hydro vector in inst/extdata/demo_hydro.gpkg

### Package Documentation

- [X] T105 [P] Create R/nemeton-package.R with package-level documentation
- [X] T106 [P] Add CITATION file in inst/CITATION
- [X] T107 [P] Create R/zzz.R with .onLoad() and .onAttach() hooks

### Vignettes

- [X] T108 [P] Create vignette intro-nemeton.Rmd with usethis::use_vignette()
- [X] T109 Write intro vignette: method explanation + package overview in vignettes/intro-nemeton.Rmd
- [X] T110 [P] Create vignette workflow-basic.Rmd with usethis::use_vignette()
- [X] T111 Write workflow vignette: complete A-Z example in vignettes/workflow-basic.Rmd

### README

- [X] T112 Create README.md with installation instructions and quick example
- [X] T113 Add badges (R CMD check, codecov) to README.md
- [X] T114 Add example workflow code to README.md

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final quality assurance and package polish

### Documentation Completion

- [X] T115 [P] Run devtools::document() to generate all man/*.Rd files
- [X] T116 [P] Verify all exported functions have complete roxygen2 docs
- [X] T117 [P] Add examples to all roxygen2 documentation
- [X] T118 Build vignettes with devtools::build_vignettes()

### Testing & Coverage

- [X] T119 Run devtools::test() and verify all tests pass
- [X] T120 Run covr::package_coverage() and verify >= 70% coverage
- [X] T121 Add additional tests if coverage < 70%
- [X] T122 Create regression test fixtures: save expected values for all indicators

### Code Quality

- [X] T123 [P] Run lintr::lint_package() and fix all style issues
- [X] T124 [P] Run styler::style_pkg() for consistent formatting
- [X] T125 Verify all files <= 300 lines (refactor if needed)
- [X] T126 Verify all lines <= 80 characters

### Package Checks

- [X] T127 Run devtools::check() and fix all ERRORs
- [X] T128 Run devtools::check() and fix all WARNINGs
- [X] T129 Run devtools::check() and fix all NOTEs (if possible)
- [X] T130 Verify package size < 10 MB
- [X] T131 Verify data/ size < 5 MB

### Performance Validation

- [X] T132 Test nemeton_compute() with 100 units + 5 indicators (< 2 min)
- [X] T133 Profile performance with profvis if needed
- [X] T134 Optimize bottlenecks identified by profiling

### CI/CD Setup

- [X] T135 [P] Setup GitHub Actions workflow for R-CMD-check
- [X] T136 [P] Setup GitHub Actions workflow for test-coverage
- [X] T137 [P] Setup pkgdown website with GitHub Pages

### Final Validation

- [X] T138 Run complete workflow from quickstart.md
- [X] T139 Verify all acceptance criteria from spec.md are met
- [X] T140 Tag release v0.1.0 with git tag

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - MVP CORE
- **User Story 2 (Phase 4)**: Depends on Foundational - can run parallel to US1 (different files)
- **User Story 3 (Phase 5)**: Depends on Foundational - can run parallel to US1/US2 (different files)
- **User Story 4 (Phase 6)**: Depends on Foundational - can run parallel to US1/US2/US3 (different files)
- **Example Data (Phase 7)**: Can run parallel to user stories
- **Polish (Phase 8)**: Depends on all user stories + data being complete

### User Story Dependencies

- **User Story 1 (P1)**: INDEPENDENT - can start after Foundational
- **User Story 2 (P2)**: INDEPENDENT - can start after Foundational (works with US1 output but doesn't block)
- **User Story 3 (P2)**: INDEPENDENT - can start after Foundational (visualizes US1 output but doesn't block)
- **User Story 4 (P3)**: INDEPENDENT - can start after Foundational (visualizes US1/US2 output but doesn't block)

### Within Each User Story (TDD Cycle)

1. **Tests FIRST** (marked [P] = parallel)
2. **Tests FAIL** (verify red state)
3. **Implementation** (models → services → core → integration)
4. **Tests PASS** (green state)
5. **Refactor** if needed
6. **Story Complete** - move to next priority

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T008-T011 (utils) can run parallel
- T012-T020 (classes) must be sequential within class, but nemeton_units and nemeton_layers can be parallel
- T021-T025 (tests) can run parallel
- T026-T028 (fixtures) can run parallel
- T029-T031 (preprocessing) can run parallel

**Phase 3 (US1 - Tests)**:
- T033-T040 can all run in parallel

**Phase 3 (US1 - Indicators)**:
- T044-T053 (all 5 indicators) can run in parallel (different functions)

**Phase 4-6 (US2, US3, US4)**:
- Entire user stories can run in parallel (different files)
- Within each story, tests can run parallel
- Within each story, implementation tasks in different files can run parallel

**Phase 7 (Documentation)**:
- T097-T104 (data) can run parallel
- T105-T107 (package docs) can run parallel
- T108-T111 (vignettes) can run parallel

**Phase 8 (Polish)**:
- T115-T118 (docs) can run parallel
- T123-T124 (linting) can run parallel
- T135-T137 (CI/CD) can run parallel

---

## Parallel Example: User Story 1 (5 Indicators)

```bash
# Launch all indicator tests in parallel:
Task T036: "Write test for indicator_carbon() in tests/testthat/test-indicators.R"
Task T037: "Write test for indicator_biodiversity() in tests/testthat/test-indicators.R"
Task T038: "Write test for indicator_water() in tests/testthat/test-indicators.R"
Task T039: "Write test for indicator_fragmentation() in tests/testthat/test-indicators.R"
Task T040: "Write test for indicator_accessibility() in tests/testthat/test-indicators.R"

# Then launch all indicator implementations in parallel:
Task T044: "Implement indicator_carbon() in R/indicators-biophysical.R"
Task T046: "Implement indicator_biodiversity() in R/indicators-biophysical.R"
Task T048: "Implement indicator_water() in R/indicators-biophysical.R"
Task T050: "Implement indicator_fragmentation() in R/indicators-biophysical.R"
Task T052: "Implement indicator_accessibility() in R/indicators-biophysical.R"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

**Recommended for initial delivery:**

1. Complete Phase 1: Setup (T001-T007)
2. Complete Phase 2: Foundational (T008-T032) - **CRITICAL BLOCKER**
3. Complete Phase 3: User Story 1 (T033-T055) - **CORE MVP**
4. **STOP and VALIDATE**: Test US1 independently with test fixtures
5. Basic README (T112-T114)
6. Run devtools::check() (T127-T129)
7. **DEPLOY/DEMO** v0.0.1 alpha

**Value**: Users can calculate 5 forest indicators - core value delivered!

### Incremental Delivery (Recommended)

**Deliver in increments, each adding value:**

1. **Foundation** (Phases 1-2): Package structure + core classes → v0.0.1-dev
2. **MVP** (Phase 3 + minimal Phase 8): User Story 1 → v0.1.0-alpha
3. **+Indices** (Phase 4): User Story 2 → v0.1.0-beta
4. **+Mapping** (Phase 5): User Story 3 → v0.1.0-rc1
5. **+Radar** (Phase 6): User Story 4 → v0.1.0-rc2
6. **+Documentation** (Phase 7): Full examples/vignettes → v0.1.0

Each increment:
- Adds new capability
- Maintains all previous capabilities
- Can be tested and demoed independently
- Can be released as pre-release version

### Parallel Team Strategy

With multiple developers (after Foundational phase):

- **Developer A**: User Story 1 (Phase 3) - Core indicators
- **Developer B**: User Story 2 (Phase 4) - Normalization (can start immediately)
- **Developer C**: User Story 3 (Phase 5) - Map viz (can start immediately)
- **Developer D**: Example data (Phase 7) - Parallel to all
- **All**: Converge on Phase 8 (Polish) after stories complete

Stories integrate naturally without blocking each other.

---

## Notes

- **[P] marker**: Tasks in different files with no dependencies = safe to parallelize
- **[Story] label**: Traceability to user stories from spec.md (US1, US2, US3, US4)
- **TDD Required**: Tests MUST be written first and fail before implementation (Constitution Principle IV)
- **Independent Stories**: Each user story is self-contained and testable on its own
- **File Paths**: All file paths are relative to package root (nemeton/)
- **Commits**: Commit after each task or logical group of [P] tasks
- **Checkpoints**: Use checkpoints to validate independent functionality before proceeding
- **Coverage**: Target >= 70% for MVP (Constitution allows this, though 80% is ideal)

---

## Summary

**Total Tasks**: 140
**User Story Breakdown**:
- Setup (Phase 1): 7 tasks
- Foundational (Phase 2): 25 tasks (BLOCKS all stories)
- User Story 1 (Phase 3 - P1): 23 tasks (CORE MVP)
- User Story 2 (Phase 4 - P2): 19 tasks
- User Story 3 (Phase 5 - P2): 11 tasks
- User Story 4 (Phase 6 - P3): 11 tasks
- Documentation (Phase 7): 18 tasks
- Polish (Phase 8): 26 tasks

**Parallel Opportunities Identified**: 70+ tasks can run in parallel (50% of total)

**Independent Test Criteria**:
- US1: Can calculate 5 indicators from spatial data ✅
- US2: Can normalize and aggregate indicators into composite index ✅
- US3: Can visualize indicators as thematic maps ✅
- US4: Can visualize unit profiles as radar charts ✅

**Suggested MVP Scope**: Phases 1-3 only (55 tasks) = User Story 1 = Core value delivery

---

**Tasks Generated**: ✅ Ready for implementation following TDD workflow (Red → Green → Refactor)
