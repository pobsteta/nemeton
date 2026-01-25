# Implementation Plan: MVP v0.4.0 - Complete 12-Family Ecosystem Services Referential

**Branch**: `001-mvp-v0.4.0` | **Date**: 2026-01-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-mvp-v0.4.0/spec.md`

## Summary

This implementation plan completes the nemeton R package ecosystem services framework by adding the final 4 indicator families (Social, Productive, Energy, Naturalness) to reach 12/12 families. Building on the solid foundation of v0.3.0 (9 families with complete temporal, normalization, and cross-analysis infrastructure), this release adds 11 new indicator functions, advanced multi-criteria analysis tools (Pareto optimality, clustering, trade-offs), comprehensive demo data, and vignettes demonstrating the complete referential.

**Primary requirement**: Enable comprehensive ecosystem services assessments covering social/recreational (S), productive/economic (P), energy/climate (E), and naturalness/wilderness (N) dimensions through scientifically-validated indicators integrated with existing infrastructure.

**Technical approach**: Extend existing R/indicators-*.R module pattern, leverage OpenStreetMap/INSEE open data sources, implement Pareto/clustering algorithms using CRAN `cluster` package, generate synthetic demo data for all 12 families, and maintain 100% backward compatibility with v0.3.0 workflows.

## Technical Context

**Language/Version**: R >= 4.0.0 (targeting R 4.1.0+ for compatibility with existing codebase)
**Primary Dependencies**:
- Core spatial: `sf` >= 1.0-0, `terra` >= 1.7-0, `exactextractr` >= 0.9.0
- Data manipulation: `dplyr` >= 1.1.0, `tidyr` >= 1.3.0
- Visualization: `ggplot2` >= 3.4.0, `viridisLite` (existing)
- Infrastructure: `rlang`, `cli` >= 3.6.0, `glue`
- **New dependencies**: `osmdata` (OpenStreetMap queries), `cluster` (K-means/hierarchical clustering), `ggrepel` (plot labels)

**Storage**:
- Input: Spatial files (GeoPackage, shapefile, GeoTIFF) via `sf::st_read()` / `terra::rast()`
- Demo data: Internal `.rda` files in `data/` (massif_demo_units_extended.rda)
- Test fixtures: `.rds` files in `tests/testthat/fixtures/`
- No database backend required

**Testing**:
- Framework: `testthat` >= 3.0.0
- Coverage tool: `covr`
- Target: ≥70% coverage (aim for ≥80% per constitution)
- Approach: TDD with fixtures for indicator regression tests

**Target Platform**:
- Cross-platform R (Windows, macOS, Linux)
- Desktop/server environments (4GB RAM, dual-core CPU minimum)
- No mobile/web deployment (pure R package)

**Project Type**: R package (single project structure with standard R pkg layout)

**Performance Goals**:
- Calculate all 11 new indicators for 20-parcel demo dataset: <5 minutes
- Pareto optimality detection: <10 seconds for 1000 parcels
- Clustering (K-means, k=4): <30 seconds for 1000 parcels
- 12-family correlation matrix: <5 seconds for 1000 parcels
- Support ≥1000 parcels without memory issues (<2GB footprint)

**Constraints**:
- **Backward compatibility**: All v0.3.0 code must continue functioning (NFR-004)
- **R CMD check**: 0 errors, 0 warnings (excluding platform UTF-8 notes) - NON-NÉGOCIABLE per constitution
- **Test coverage**: ≥70% minimum (constitution requirement: 80% target)
- **Open data first**: OpenStreetMap/INSEE prioritized, proprietary data optional (constitution)
- **Documentation**: roxygen2 for all 11 new functions, vignettes for workflows
- **Bilingual**: FR/EN support via existing i18n infrastructure

**Scale/Scope**:
- 11 new exported indicator functions (S1-S3, P1-P3, E1-E2, N1-N3)
- 3 new analysis functions (identify_pareto_optimal, cluster_parcels, plot_tradeoff)
- 2 new vignettes (complete-referential, multi-criteria-optimization)
- Extended demo dataset: 20 parcels × 20 indicators × 12 families
- Estimated new code: ~1500 lines R + ~800 lines tests + ~600 lines documentation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

### Compliance with NON-NÉGOCIABLES

| Principle | Status | Notes |
|-----------|--------|-------|
| **II. Interopérabilité R Spatial** | ✅ PASS | All indicators use `sf` objects input/output; osmdata returns sf; terra for any raster processing |
| **III. Modularité** | ✅ PASS | New indicators follow existing pattern: R/indicators-social.R, R/indicators-productive.R, etc. Separate R/analysis-pareto.R for advanced tools |
| **IV. Test-First avec Fixtures** | ✅ PASS | TDD approach: write tests before implementation; fixtures for regression; target >70% coverage |
| **VI. Nommage** | ✅ PASS | Functions: indicator_social_*(), indicator_productive_*(), etc. Files: indicators-social.R, analysis-pareto.R |
| **VII. Documentation** | ✅ PASS | roxygen2 for all 11 indicator functions + 3 analysis functions; 2 new vignettes; pkgdown update |

### Constitution Principles Alignment

- ✅ **Open Data First**: OpenStreetMap (trails, infrastructure), INSEE (population) prioritized; BD Forêt/GTFS optional
- ✅ **Modularité**: Each indicator family in separate file; analysis tools in dedicated module
- ✅ **Transparence**: All parameters explicit; metadata documented; cli messages for operations
- ✅ **Extensibilité**: New indicators use same API as existing; family system auto-extends
- ✅ **Simplicité/YAGNI**: Only implementing requested features; no speculative optimization
- ✅ **TDD**: Tests written first with fixtures for indicator validation

### Pre-Implementation Gates

- ✅ **Stack technique conforme**: R >=4.0, sf/terra/exactextractr, ggplot2, dplyr - all per constitution
- ✅ **Pas de dépendances interdites**: No `raster`, no `sp`, no proprietary packages
- ✅ **Paradigme fonctionnel**: Pure functions for indicators; S3 classes for objects
- ✅ **Performance minimale**: Design supports >=1000 parcels per constitution requirement

### Post-Design Re-check

*To be completed after Phase 1 design artifacts generated*

- [ ] data-model.md entities align with S3 class conventions
- [ ] contracts/ API patterns match existing indicator signatures
- [ ] No new violations introduced during design phase

**GATE STATUS**: ✅ PASS - Proceed to Phase 0 research

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-v0.4.0/
├── spec.md              # Feature specification (DONE)
├── plan.md              # This file (IN PROGRESS)
├── research.md          # Phase 0 output (PENDING)
├── data-model.md        # Phase 1 output (PENDING)
├── quickstart.md        # Phase 1 output (PENDING)
├── contracts/           # Phase 1 output (PENDING)
│   ├── social-indicators.md
│   ├── productive-indicators.md
│   ├── energy-indicators.md
│   ├── naturalness-indicators.md
│   └── analysis-tools.md
├── checklists/          # Quality validation
│   └── requirements.md  # Spec validation (DONE)
└── tasks.md             # Task breakdown (Phase 2 - NOT by /speckit.plan)
```

### Source Code (repository root)

**R Package Structure** (standard R package layout per constitution):

```text
nemeton/                          # Repository root
├── R/                            # Source code
│   ├── indicators-social.R       # NEW: S1, S2, S3 functions
│   ├── indicators-productive.R   # NEW: P1, P2, P3 functions
│   ├── indicators-energy.R       # NEW: E1, E2 functions
│   ├── indicators-naturalness.R  # NEW: N1, N2, N3 functions
│   ├── analysis-pareto.R         # NEW: Pareto optimality detection
│   ├── analysis-clustering.R     # NEW: K-means/hierarchical clustering
│   ├── analysis-tradeoff.R       # NEW: Trade-off visualization
│   ├── family-system.R           # EXTEND: Support S, P, E, N families
│   ├── normalization.R           # EXTEND: Add normalization methods for new indicators
│   ├── visualization.R           # EXTEND: 12-axis radar, cluster profiles
│   ├── i18n.R                    # EXTEND: Add FR/EN messages for new indicators
│   └── utils.R                   # EXTEND: Helpers for OSM queries, clustering
│
├── data/                         # Package data
│   └── massif_demo_units_extended.rda  # NEW: Demo data with 12 families
│
├── data-raw/                     # Data generation scripts
│   └── generate_extended_demo.R  # NEW: Synthetic data generation
│
├── tests/testthat/               # Tests
│   ├── fixtures/                 # Test fixtures
│   │   ├── social_reference.rds       # NEW: S1-S3 expected values
│   │   ├── productive_reference.rds   # NEW: P1-P3 expected values
│   │   ├── energy_reference.rds       # NEW: E1-E2 expected values
│   │   ├── naturalness_reference.rds  # NEW: N1-N3 expected values
│   │   └── pareto_reference.rds       # NEW: Pareto set expected results
│   ├── test-indicators-social.R       # NEW: S family tests
│   ├── test-indicators-productive.R   # NEW: P family tests
│   ├── test-indicators-energy.R       # NEW: E family tests
│   ├── test-indicators-naturalness.R  # NEW: N family tests
│   ├── test-analysis-pareto.R         # NEW: Pareto analysis tests
│   ├── test-analysis-clustering.R     # NEW: Clustering tests
│   └── test-analysis-tradeoff.R       # NEW: Trade-off plot tests
│
├── vignettes/                    # Documentation
│   ├── complete-referential.Rmd  # NEW: 12-family comprehensive guide
│   └── multi-criteria-optimization.Rmd  # NEW: Pareto/clustering workflows
│
├── man/                          # Roxygen2 documentation (auto-generated)
├── inst/                         # Installed files
└── DESCRIPTION                   # EXTEND: Add osmdata, cluster, ggrepel

```

**Structure Decision**:
Standard R package structure is maintained. New indicator families follow the established `indicators-{family}.R` pattern (social, productive, energy, naturalness). Advanced analysis tools are modularized into separate `analysis-*.R` files (pareto, clustering, tradeoff). This ensures consistency with v0.1.0-v0.3.0 architecture and adheres to constitution's modularity principle.

Key structural decisions:
1. **One file per family**: R/indicators-social.R contains S1, S2, S3 (not separate files per indicator)
2. **Separate analysis modules**: Pareto, clustering, tradeoff each get dedicated files (distinct responsibilities)
3. **Extended demo data**: Single `massif_demo_units_extended.rda` replaces/extends current `massif_demo_units.rda`
4. **Fixtures per family**: Separate .rds files for regression testing each family's indicators
5. **Two new vignettes**: complete-referential (all 12 families), multi-criteria-optimization (advanced tools)

## Complexity Tracking

**No constitution violations requiring justification.**

All design choices comply with constitution principles:
- R package structure: standard per R-pkgs best practices
- Dependencies: all CRAN packages, open-source, aligned with constitution stack
- Testing: TDD with ≥70% coverage requirement met
- Modularity: clear separation of responsibilities per constitution Section III
- No premature abstractions: extending proven v0.3.0 patterns

---

## Phase 0: Research & Technical Decisions

### Research Topics

The following research tasks resolve technical unknowns and establish implementation patterns:

1. **OpenStreetMap Integration Patterns**
   - How to query OSM for trails (highway tags), infrastructure (roads, buildings, power)
   - osmdata package API and query optimization
   - Handling OSM data quality/completeness variability

2. **INSEE Population Grid Access**
   - Available INSEE datasets and access methods
   - Grid resolution options (1km vs 200m)
   - Spatial join patterns for population proximity

3. **IFN Allometric Equations Coverage**
   - Catalog of IFN volume equations by species
   - Fallback strategies for rare species (genus-level, default equations)
   - Integration with existing v0.2.0 biomass calculations (C1)

4. **ADEME Emission Factors**
   - Current ADEME CO2 emission factors for wood vs fossils
   - Wood material substitution factors (wood vs cement/steel)
   - Versioning strategy for factor table updates

5. **Pareto Optimality Algorithms**
   - Efficient algorithms for multi-objective Pareto frontier detection
   - R implementations (base vs specialized packages)
   - Computational complexity for 1000+ parcels × 12 dimensions

6. **Clustering Methods for Multi-Family Profiles**
   - K-means vs hierarchical clustering trade-offs
   - Optimal number of clusters determination (elbow, silhouette)
   - Visualization strategies for cluster profiles (radar plots)

### Research Outputs

Research findings will be consolidated in `research.md` with the following structure for each topic:

- **Decision**: Selected approach/library/data source
- **Rationale**: Why this choice (performance, compatibility, data quality)
- **Alternatives considered**: Other options evaluated and reasons for rejection
- **Implementation notes**: Key API patterns, parameters, edge cases

---

## Phase 1: Data Model & API Contracts

### Data Model Entities

*Extracted from spec.md Key Entities section and functional requirements*

The following entities will be documented in `data-model.md`:

1. **Social Indicators (S Family)**
   - S1 (trail_density): km/ha
   - S2 (accessibility_score): 0-100 composite
   - S3 (population_proximity): population counts at 5/10/20 km buffers

2. **Productive Indicators (P Family)**
   - P1 (standing_volume): m³/ha
   - P2 (site_productivity): 0-100 index
   - P3 (wood_quality): 0-100 score

3. **Energy Indicators (E Family)**
   - E1 (fuelwood_potential): tonnes DM/year
   - E2 (carbon_avoidance): tCO2eq/year

4. **Naturalness Indicators (N Family)**
   - N1 (infrastructure_distance): meters
   - N2 (forest_continuity): hectares
   - N3 (composite_naturalness): 0-100 composite

5. **Family Composites**
   - family_S, family_P, family_E, family_N: 0-100 aggregated scores

6. **Extended Demo Dataset**
   - massif_demo_units_extended: sf object, 20 parcels, 20 indicators, 12 families

7. **Analysis Outputs**
   - Pareto Set: logical vector flagging non-dominated parcels
   - Cluster Assignments: integer vector of cluster IDs
   - Cluster Profiles: data.frame with mean family scores per cluster

### API Contracts

*Generated from functional requirements FR-001 to FR-026*

API contracts will be documented in `contracts/` directory:

**contracts/social-indicators.md**:
- `indicator_social_trails(units, trails, method)` → units with S1
- `indicator_social_accessibility(units, roads, transit, cycling)` → units with S2
- `indicator_social_proximity(units, population, radii)` → units with S3

**contracts/productive-indicators.md**:
- `indicator_productive_volume(units, species_field, dbh_field, height_field)` → units with P1
- `indicator_productive_station(units, fertility_field, climate, species_field)` → units with P2
- `indicator_productive_quality(units, form_field, diameter_field, defects_field)` → units with P3

**contracts/energy-indicators.md**:
- `indicator_energy_fuelwood(units, biomass_field, coppice_area)` → units with E1
- `indicator_energy_avoidance(units, fuelwood_field, substitution_factors)` → units with E2

**contracts/naturalness-indicators.md**:
- `indicator_naturalness_distance(units, infrastructure, types)` → units with N1
- `indicator_naturalness_continuity(units, land_cover, forest_classes)` → units with N2
- `indicator_naturalness_composite(units, n1_field, n2_field, t1_field, b1_field)` → units with N3

**contracts/analysis-tools.md**:
- `identify_pareto_optimal(units, families, objectives)` → units with is_pareto_optimal
- `cluster_parcels(units, families, k, method)` → units with cluster_id
- `plot_tradeoff(units, family_x, family_y, parcel_ids)` → ggplot object

### Quickstart Workflow

*User journey demonstrating complete 12-family workflow*

`quickstart.md` will provide a step-by-step guide:

1. Load package and extended demo data
2. Calculate new indicators (S1-S3, P1-P3, E1-E2, N1-N3)
3. Normalize and create family composites
4. Generate 12-axis radar plot
5. Compute 12×12 correlation matrix
6. Identify multi-criteria hotspots
7. Detect Pareto-optimal parcels
8. Cluster parcels and visualize profiles
9. Create trade-off plots for competing families
10. Export results

Estimated time: 15-20 minutes for full workflow.

---

## Phase 2: Implementation Ready

After completing Phase 0 (research.md) and Phase 1 (data-model.md, contracts/, quickstart.md), the feature will be ready for task breakdown via `/speckit.tasks`.

The tasks.md will organize implementation into phases:
- **Phase 1**: Setup (dependencies, test infrastructure)
- **Phase 2**: Foundational (extend normalization, family system)
- **Phase 3**: US1 - Social Family (S1-S3 + tests)
- **Phase 4**: US2 - Productive Family (P1-P3 + tests)
- **Phase 5**: US3 - Energy Family (E1-E2 + tests)
- **Phase 6**: US4 - Naturalness Family (N1-N3 + tests)
- **Phase 7**: US5 - System Integration (12-axis radar, correlation)
- **Phase 8**: US6 - Demo Data (massif_demo_units_extended generation)
- **Phase 9**: US7 - Advanced Analysis (Pareto, clustering, trade-offs)
- **Phase 10**: Polish (vignettes, documentation, final validation)

**Next command**: `/speckit.tasks` to generate executable task breakdown

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Phase 0 and Phase 1 outputs pending
**Ready for**: Research phase execution
