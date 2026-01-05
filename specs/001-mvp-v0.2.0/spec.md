# Feature Specification: MVP v0.2.0 - Temporal & Spatial Indicators Extension

**Feature Branch**: `001-mvp-v0.2.0`
**Created**: 2026-01-05
**Status**: Draft
**Input**: User description: "MVP v0.2.0 du package R nemeton - Fondations Temporelles & Extension Spatiale - Poser les fondations pour un référentiel complet de 12 familles d'indicateurs (36 sous-indicateurs) en implémentant: (1) infrastructure d'analyse multi-temporelle, (2) 5 familles d'indicateurs sur 12, (3) extension du système de normalisation/agrégation pour gérer les familles."

## Context

The nemeton R package v0.1.0 is a production-ready toolkit for multi-criteria ecosystem services assessment in forest management. It currently includes 5 basic biophysical indicators (carbon, biodiversity, water, fragmentation, accessibility) with calculation, normalization, aggregation, and visualization capabilities (maps + radar charts).

### Vision for v0.2.0

Establish foundations for a comprehensive framework of 12 indicator families (36 sub-indicators total) by implementing:
1. Multi-temporal analysis infrastructure (reusable framework)
2. 5 indicator families out of 12 (C, W, F, L partial, plus temporal framework)
3. Extended normalization/aggregation system to manage indicator families

### Complete 12-Family Framework (4-version roadmap)

**Scope for v0.2.0** (highlighted):
- ✅ **C - Carbon/Vitality**: C1 (biomass stock), C2 (NDVI trend)
- ⏭️ B - Biodiversity: B1 (protected status), B2 (structural diversity), B3 (connectivity)
- ✅ **W - Water**: W1 (hydrographic network), W2 (wetlands), W3 (TWI)
- ⏭️ A - Air/Microclimate: A1 (tree cover buffer), A2 (air quality ATMO)
- ✅ **F - Soil Fertility**: F1 (fertility class), F2 (slope/erosion)
- ✅ **L - Landscape/Continuity**: L1 (fragmentation), L2 (edge ratio), ⏭️ L3 (regional connectivity)
- ⏭️ T - Temporal/Dynamics: T1 (forest age), T2 (land use changes)
- ⏭️ R - Risks: R1 (fire), R2 (storm), R3 (drought)
- ⏭️ S - Social/Uses: S1 (trails), S2 (accessibility), S3 (population proximity)
- ⏭️ P - Productive/Economy: P1 (exploitable volume), P2 (productivity), P3 (timber/energy)
- ⏭️ E - Energy/Climate: E1 (wood-energy potential), E2 (carbon avoidance)
- ⏭️ N - Naturalness: N1 (infrastructure distance), N2 (continuous forest), N3 (composite)

**Future versions**: B, R, T, A (v0.3.0) | S, P, E (v0.4.0) | N, Shiny dashboard (v0.5.0)

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Multi-Temporal Analysis Infrastructure (Priority: P1)

As a forest manager, I want to analyze indicator evolution across multiple time periods (e.g., 2015, 2020, 2025) to detect trends and changes, so I can adapt my management strategy based on temporal dynamics rather than single snapshots.

**Why this priority**: Foundation for all temporal analysis - required by users who need to track forest evolution over time. Without this, users can only assess current state but cannot detect degradation, improvement, or intervention impacts. This infrastructure will be reused in all future versions (v0.3.0+) for temporal indicators like T1/T2.

**Independent Test**: Can be fully tested by running the same 5 existing indicators (carbon, biodiversity, water, fragmentation, accessibility) on massif_demo at two different dates and verifying:
- Temporal dataset structure is created correctly
- Change rates are calculated accurately
- Trend visualizations display properly
- Delivers value: users can see "carbon increased 15% from 2015 to 2020" without implementing any new indicators

**Acceptance Scenarios**:

1. **Given** a nemeton_units object with indicators calculated for 2015 data, **When** user provides the same units with 2020 data to `nemeton_temporal()`, **Then** system creates a temporal dataset with both periods indexed by date
2. **Given** a temporal dataset with 2+ periods, **When** user calls `calculate_change_rate()`, **Then** system returns annual change rates for each indicator and each unit
3. **Given** temporal data for an indicator, **When** user requests trend visualization, **Then** system generates time-series line plots showing evolution across periods with clear date labels
4. **Given** temporal data spanning 2015-2020, **When** user compares pre/post intervention (e.g., 2017 thinning), **Then** system highlights the intervention date and shows before/after metrics

---

### User Story 2 - Family C: Carbon & Forest Vitality (Priority: P1)

As a carbon analyst, I want to evaluate aboveground biomass stock (C1) and vitality via NDVI (C2) to quantify sequestration potential and detect forest stress, so I can report on carbon storage and early-warning signs of decline.

**Why this priority**: Carbon is the most requested indicator family by forest managers and policy makers for climate mitigation reporting. C1 (biomass) directly replaces the existing simple carbon indicator with a more accurate BD Forêt v2-based calculation. C2 (NDVI) adds health monitoring capability.

**Independent Test**: Can be fully tested using massif_demo with BD Forêt v2 attributes (species, age, density) by:
- Calculating C1 biomass using allometric models
- Computing C2 NDVI mean from raster data (or mock raster if Sentinel-2 unavailable)
- Verifying outputs are in correct units (tC/ha for C1, 0-1 scale for C2)
- Delivers value: users get accurate carbon stock estimates aligned with national forest inventory methods

**Acceptance Scenarios**:

1. **Given** units with BD Forêt v2 attributes (species="Quercus", age=80, density=0.7), **When** user calls `indicator_carbon_biomass()`, **Then** system applies species-specific allometric equation and returns biomass in tC/ha
2. **Given** units without species information, **When** biomass calculation is attempted, **Then** system uses conservative generic allometric model or returns NA with clear warning
3. **Given** NDVI raster covering units, **When** user calls `indicator_carbon_ndvi()`, **Then** system extracts mean NDVI per unit and optionally calculates 5-year trend if multiple dates provided
4. **Given** C1 and C2 calculated, **When** both indicators normalized to 0-100, **Then** system creates family score `score_carbon` as weighted average (C1: 70%, C2: 30% default weights)

---

### User Story 3 - Family W: Water Regulation (Complete Extension) (Priority: P1)

As a hydrologist, I want to evaluate water regulation via network density (W1), wetland coverage (W2), and Topographic Wetness Index (W3) to identify parcels with high hydrological stakes, so I can prioritize riparian forest protection and flood mitigation areas.

**Why this priority**: Water regulation is critical for ecosystem services beyond carbon. Completing the Water family (W1-W3) builds on the existing partial implementation and provides comprehensive hydrological assessment requested by watershed managers.

**Independent Test**: Can be fully tested with massif_demo plus hydrographic network and DEM data by:
- Calculating W1 (stream length/ha) using existing watercourses layer
- Computing W2 (% wetland) from land cover or dedicated wetland layer
- Calculating W3 (TWI) from DEM using terrain analysis
- Delivers value: users identify high water regulation zones for protection planning

**Acceptance Scenarios**:

1. **Given** units with stream network layer, **When** user calls `indicator_water_network()`, **Then** system calculates total stream length within each unit and returns density in km/ha
2. **Given** units with wetland classification raster, **When** user calls `indicator_water_wetlands()`, **Then** system computes % of unit surface classified as wetland or riparian forest
3. **Given** high-resolution DEM, **When** user calls `indicator_water_twi()`, **Then** system calculates TWI using flow accumulation and slope, returning unitless index (higher = wetter)
4. **Given** all three W indicators calculated, **When** normalized and aggregated, **Then** system creates `score_water` family index with equal weights (W1: 33%, W2: 33%, W3: 33% default)

---

### User Story 4 - Family F: Soil Fertility & Erosion (Priority: P2)

As a forest ecologist, I want to evaluate soil fertility class (F1) and erosion risk (F2) to adapt species selection and prevent soil degradation, so I can maintain long-term site productivity and avoid irreversible soil loss.

**Why this priority**: Secondary to carbon/water but essential for sustainable management. Soil fertility determines species suitability and growth potential. Erosion risk is critical in mountainous areas and after intensive harvesting.

**Independent Test**: Can be fully tested with massif_demo plus soil map and slope data by:
- Extracting F1 fertility class from BD Sol or soil texture/depth rasters
- Calculating F2 erosion risk from slope + land cover
- Verifying outputs match reference soil classifications
- Delivers value: users get soil-informed planting recommendations and erosion hotspot identification

**Acceptance Scenarios**:

1. **Given** units with BD Sol coverage, **When** user calls `indicator_soil_fertility()`, **Then** system extracts fertility class (1-5 scale or categorical) based on available water capacity and texture
2. **Given** units without BD Sol, **When** fertility calculation attempted, **Then** system uses alternative (soil texture raster, parent material) or returns NA with suggestion to provide soil data
3. **Given** DEM with slope layer, **When** user calls `indicator_soil_erosion()`, **Then** system combines slope (%) with land cover type (bare soil = high risk, forest = low risk) into erosion risk index (0-100)
4. **Given** F2 erosion > 70 threshold, **When** visualized, **Then** system highlights high-risk units with warning message recommending protective measures

---

### User Story 5 - Family L: Landscape Fragmentation & Edge Effects (Priority: P2)

As a territorial planner, I want to quantify landscape fragmentation (L1) and edge-to-surface ratio (L2) to optimize ecological connectivity, so I can design forest corridors and minimize negative edge effects on interior forest species.

**Why this priority**: Landscape-level indicators complement unit-level indicators. Fragmentation affects biodiversity, microclimate, and ecosystem resilience. Edge ratio influences species composition and disturbance vulnerability.

**Independent Test**: Can be fully tested with massif_demo forest cover by:
- Calculating L1 metrics (number of patches, mean patch size) using spatial analysis
- Computing L2 (perimeter/area ratio) for each unit
- Verifying metrics match landscape ecology standards
- Delivers value: users identify highly fragmented areas needing corridor restoration

**Acceptance Scenarios**:

1. **Given** units with forest/non-forest classification, **When** user calls `indicator_landscape_fragmentation()`, **Then** system counts forest patches and calculates mean size within 1 km buffer around each unit
2. **Given** units with complex geometry, **When** user calls `indicator_landscape_edge()`, **Then** system calculates perimeter length, divides by surface area, and returns edge density (m/ha)
3. **Given** L2 edge ratio > 200 m/ha, **When** normalized, **Then** system flags units as "high edge effect" (relevant for interior forest specialists)
4. **Given** L1 and L2 calculated, **When** combined into `score_landscape`, **Then** system uses inverse normalization (low fragmentation = high score, low edge = high score for naturalness)

---

### User Story 6 - Multi-Family Normalization & Composite Indices (Priority: P3)

As a user, I want family-level composite indices (score_carbon, score_water, score_soil, score_landscape) and a 12-axis radar chart to compare ecosystem profiles across units or scenarios, so I can communicate multi-dimensional forest quality to non-technical stakeholders.

**Why this priority**: Nice-to-have enhancement for communication and synthesis. The core value is in the indicators themselves (US2-US5). This story adds polish and user experience improvements but is not essential for MVP functionality.

**Independent Test**: Can be fully tested once US2-US5 are complete by:
- Extending `normalize_indicators()` to handle family grouping
- Creating `create_family_index()` function for weighted family scores
- Extending `nemeton_radar()` to display up to 12 family axes
- Delivers value: users produce executive summary visualizations for reports

**Acceptance Scenarios**:

1. **Given** indicators from families C, W, F, L calculated and normalized, **When** user calls `create_family_index()`, **Then** system creates score_carbon, score_water, score_soil, score_landscape using specified or default weights
2. **Given** family scores created, **When** user calls `nemeton_radar()` with family-level data, **Then** system displays radar chart with 4-12 axes (only families with data present)
3. **Given** 12 family scores (in future versions), **When** radar chart created, **Then** all 12 families displayed with clear labels and legend explaining each family
4. **Given** family scores normalized to 0-100, **When** user compares two scenarios, **Then** system overlays both profiles on same radar for visual comparison

---

### Edge Cases

- **Temporal alignment**: What happens when input datasets for different time periods have different spatial extents (some parcels added/removed)? System should match on unit IDs and flag non-overlapping units.
- **Missing indicator data**: How does system handle units where specific data layers are unavailable (e.g., no BD Forêt attributes for C1, no soil map for F1)? System should return NA for affected indicators and allow partial family scores.
- **Zero denominators**: What happens when calculating change rates for indicators with zero baseline values? System should return Inf or NA with appropriate warning.
- **Extreme TWI values**: How does system handle very flat areas (TWI → 0) or convergent valleys (TWI → 30+)? System should cap TWI at reasonable thresholds or use log transformation.
- **Multi-date NDVI**: If user provides 5 years of NDVI rasters for C2 trend calculation, does system require all dates for all units or handle partial coverage? System should calculate trend only for units with 3+ dates, otherwise return mean NDVI.
- **Family aggregation with missing indicators**: If user has C1 but no C2 (no NDVI data), can score_carbon still be calculated? System should allow partial family scores with adjusted weights or flag as incomplete.
- **Incompatible normalization methods across families**: What happens if user normalizes some families with min-max and others with z-score before creating radar chart? System should warn and recommend consistent normalization for visual comparison.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Temporal Analysis (US1)

- **FR-001**: System MUST accept multiple nemeton_units objects indexed by date/period to create temporal dataset
- **FR-002**: System MUST calculate annual change rate for each indicator between consecutive periods
- **FR-003**: System MUST generate time-series line plots showing indicator evolution with date labels
- **FR-004**: System MUST support pre/post comparison mode with user-specified intervention date
- **FR-005**: System MUST handle units present in some periods but not others (match on ID, flag gaps)
- **FR-006**: System MUST persist temporal data structure compatible with existing nemeton_units S3 class

#### Carbon Family (US2)

- **FR-007**: System MUST calculate C1 biomass stock (tC/ha) using BD Forêt v2 attributes (species, age, density) via allometric models
- **FR-008**: System MUST provide species-specific allometric equations for major French forest species (Quercus, Fagus, Pinus, Abies minimum)
- **FR-009**: System MUST fallback to generic allometric model when species information unavailable
- **FR-010**: System MUST calculate C2 NDVI mean from raster data for each unit
- **FR-011**: System MUST optionally calculate C2 NDVI trend (slope) if multi-date NDVI rasters provided (3+ dates required)
- **FR-012**: System MUST create score_carbon as weighted average of C1 and C2 (default weights: C1=70%, C2=30%)
- **FR-013**: System MUST replace existing `indicator_carbon()` with `indicator_carbon_biomass()` while maintaining backward compatibility

#### Water Family (US3)

- **FR-014**: System MUST calculate W1 hydrographic network density (km/ha or m/ha) using stream vector layer
- **FR-015**: System MUST calculate W2 wetland percentage using land cover classification or dedicated wetland layer
- **FR-016**: System MUST calculate W3 Topographic Wetness Index using DEM via flow accumulation and slope
- **FR-017**: System MUST create score_water as weighted average of W1, W2, W3 (default equal weights)
- **FR-018**: System MUST extend existing partial water indicator implementation to include all three sub-indicators

#### Soil Family (US4)

- **FR-019**: System MUST extract F1 soil fertility class from BD Sol or equivalent soil database (categorical or 1-5 scale)
- **FR-020**: System MUST calculate F2 erosion risk by combining slope (from DEM) with land cover type
- **FR-021**: System MUST apply erosion risk formula: higher slope + less vegetation cover = higher risk (0-100 scale)
- **FR-022**: System MUST create score_soil as weighted average of F1 and F2 (default equal weights)
- **FR-023**: System MUST handle absence of BD Sol gracefully (return NA or use alternative soil texture data)

#### Landscape Family (US5)

- **FR-024**: System MUST calculate L1 fragmentation metrics: patch count and mean patch size within specified buffer (default 1 km)
- **FR-025**: System MUST calculate L2 edge-to-surface ratio (perimeter/area in m/ha)
- **FR-026**: System MUST create score_landscape using inverse normalization (low fragmentation = high score)
- **FR-027**: System MUST extend existing fragmentation indicator to provide both L1 and L2 metrics

#### Multi-Family System (US6)

- **FR-028**: System MUST extend `normalize_indicators()` to recognize indicator family prefixes (C_, W_, F_, L_)
- **FR-029**: System MUST provide `create_family_index()` function accepting indicator list and weights per family
- **FR-030**: System MUST extend `nemeton_radar()` to display 4-12 family axes (dynamic based on available families)
- **FR-031**: System MUST document reference thresholds for each indicator (e.g., C1 > 100 tC/ha = high carbon stock)
- **FR-032**: System MUST maintain all 0-100 normalization for cross-family comparison
- **FR-033**: System MUST preserve backward compatibility with v0.1.0 workflow (existing 5 indicators continue to work)

#### Data & I/O

- **FR-034**: System MUST document required data sources: BD Forêt v2, BD Sol, high-res DEM, Sentinel-2 (optional), wetland maps (optional)
- **FR-035**: System MUST provide example datasets for testing: extended massif_demo with multi-date samples if feasible
- **FR-036**: System MUST maintain bilingual support (FR/EN) for all new messages using existing i18n system

#### Testing & Quality

- **FR-037**: System MUST achieve >= 70% test coverage for all new functions
- **FR-038**: System MUST provide executable examples in all function documentation (roxygen2)
- **FR-039**: System MUST include integration tests for complete temporal workflow
- **FR-040**: System MUST include validation tests comparing outputs to reference calculations (especially allometric models)

### Key Entities

#### Temporal Dataset
Multi-period collection of indicator values with temporal indexing. Contains same spatial units (matched by ID) measured at different dates. Structure: list of nemeton_units objects + metadata (dates, period labels, alignment flags).

#### Indicator Family
Logical grouping of related sub-indicators (e.g., Carbon family = C1 biomass + C2 NDVI). Each family represents a distinct ecosystem service dimension. Families have composite scores calculated as weighted averages of constituent sub-indicators.

#### Sub-Indicator
Individual measurement within a family (e.g., C1, W2, F1). Each sub-indicator has: unique identifier, unit of measurement, calculation method, data requirements, normalization parameters, reference thresholds.

#### Allometric Model
Mathematical relationship between tree attributes (diameter, height, age, species) and biomass. Species-specific equations provided for major French species. Generic fallback equation for unknown species. Returns biomass in Mg/ha or tC/ha.

#### Family Score
Composite index aggregating multiple sub-indicators within a family. Range: 0-100 (normalized). Calculated as weighted average (default equal weights, user-customizable). Used for family-level comparisons and radar chart axes.

#### Change Rate
Temporal derivative of indicator value. Calculated as: (value_t2 - value_t1) / (t2 - t1) / value_t1 * 100 for relative change, or (value_t2 - value_t1) / (t2 - t1) for absolute change. Units: %/year or indicator_units/year.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

#### Functional Completeness
- **SC-001**: Users can compute temporal change rates for all 5 existing indicators across 2+ periods and visualize trends
- **SC-002**: Users can calculate C1 biomass for forest stands with BD Forêt v2 attributes with accuracy within 15% of IFN reference values
- **SC-003**: Users can complete full water family assessment (W1, W2, W3) and obtain score_water composite index
- **SC-004**: Users can identify high soil erosion risk parcels (F2 > 70) and low fertility areas (F1 < 2) for management prioritization
- **SC-005**: Users can quantify landscape fragmentation (L1) and edge effects (L2) for connectivity planning

#### System Performance & Quality
- **SC-006**: 95% of users successfully execute temporal analysis workflow in under 10 minutes for datasets with 50 units and 3 time periods
- **SC-007**: Test suite covers >= 70% of new code with all tests passing
- **SC-008**: Documentation allows new users to run first temporal analysis within 30 minutes using vignettes

#### Data Integration
- **SC-009**: System successfully processes BD Forêt v2 data for biomass calculation with 90% coverage of French forest species
- **SC-010**: TWI calculation (W3) completes for 100+ units in under 2 minutes using standard DEM resolution (25m)
- **SC-011**: Family indices (score_carbon, score_water, score_soil, score_landscape) can be calculated even when some sub-indicators are missing (partial family scores)

#### Visualization & Communication
- **SC-012**: Users can generate multi-family radar charts with 4-12 axes in a single function call
- **SC-013**: Temporal trend plots clearly display indicator evolution with automatic date labeling and trend lines
- **SC-014**: 80% of users find family-level composite indices easier to interpret than individual indicator values for executive reporting

#### Backward Compatibility
- **SC-015**: All v0.1.0 workflows continue to function without modification after v0.2.0 upgrade
- **SC-016**: Migration from `indicator_carbon()` to `indicator_carbon_biomass()` requires zero code changes for users without BD Forêt data (fallback behavior identical)

#### Foundation for Future Versions
- **SC-017**: Temporal infrastructure supports extension to 12 families in v0.3.0+ without architectural changes
- **SC-018**: Family score calculation system scales to 36 sub-indicators (12 families × 3 avg) with consistent normalization approach

---

## Assumptions & Decisions

### Data Availability Assumptions
1. **BD Forêt v2 coverage**: Assume BD Forêt v2 is available for French territories or users can provide equivalent species/age/density attributes. For areas without BD Forêt, generic allometric models provide degraded but usable biomass estimates.

2. **Soil data**: Assume BD Sol or regional soil databases available for F1 fertility class. If unavailable, users can provide soil texture rasters or skip F1 (partial family score for F).

3. **DEM resolution**: Assume 25m resolution DEMs sufficient for TWI (W3) and slope (F2). Higher resolution (5-10m) preferred but not required for MVP.

4. **Sentinel-2 for NDVI**: Assume Sentinel-2 access is optional for C2. Users without satellite data can skip C2 (partial family score for C). No cloud-free image preprocessing required in MVP - users provide preprocessed NDVI rasters.

### Technical Decisions
5. **Allometric model selection**: Use simplified IGN/IFN allometric equations for major species rather than complex mechanistic models. Priority: accuracy vs. simplicity → choose simplicity for MVP.

6. **TWI calculation method**: Use standard D-infinity flow direction algorithm via terra or whitebox packages. No custom hydrology modeling required.

7. **Normalization consistency**: All indicators normalized to 0-100 using min-max by default for cross-family comparison. Users can override with z-score or quantile methods.

8. **Temporal alignment**: Temporal datasets require exact spatial unit ID matching. Units present in only some periods flagged but not excluded (allows partial temporal coverage).

### Scope Boundaries
9. **Multi-date data preprocessing**: Assume users provide temporally aligned rasters/vectors. No automated image registration, cloud masking, or phenological correction in v0.2.0.

10. **Family weights**: Default equal weights within families (e.g., C1=50%, C2=50%). Users can customize via function arguments but no interactive weight calibration tool in MVP.

11. **Uncertainty quantification**: No confidence intervals or error propagation for allometric models or change rates in v0.2.0. Acknowledged as future enhancement (v0.3.0+).

12. **Shiny dashboard**: All analysis via R scripts/Rmd. No interactive web interface in v0.2.0 (planned for v0.5.0).

### Backward Compatibility Strategy
13. **Deprecation approach**: `indicator_carbon()` marked as deprecated (warning message) but continues to work. Replaced by `indicator_carbon_biomass()` with identical behavior when BD Forêt data absent.

14. **Existing massif_demo**: Original massif_demo preserved. New extended version `massif_demo_temporal` added with multi-date samples (if feasible to create synthetic temporal data).

---

## Out of Scope (Deferred to Future Versions)

### v0.3.0 - Biodiversity, Risks, Temporal Indicators
- B1, B2, B3 (protected status, structural diversity, connectivity graphs)
- R1, R2, R3 (fire, storm, drought risk modeling)
- T1, T2 (forest age from historical maps, land use change frequency)
- N1, N2 (infrastructure distance, continuous forest >50 ha)
- Advanced connectivity analysis (graph theory for B3)

### v0.4.0 - Socio-Economic Indicators
- S1, S2, S3 (trail density, accessibility, population proximity)
- P1, P2, P3 (exploitable volume, productivity classes, timber/energy split)
- E1, E2 (wood-energy potential, carbon substitution calculations)
- A1, A2 (tree cover buffer analysis, ATMO air quality integration)

### v0.5.0 - Dashboard & Advanced Features
- L3 (regional green/blue corridor connectivity)
- N3 (composite naturalness index combining T1 + L1)
- Interactive Shiny dashboard for all 12 families
- Automated PDF/HTML reporting
- Uncertainty quantification (Monte Carlo for allometric models)
- Advanced spatial statistics (Moran's I, hotspot detection)

### Not Planned (Any Version)
- Real-time satellite data fetching (users provide preprocessed rasters)
- Mobile app interface
- Machine learning model training for indicator prediction
- Integration with commercial forest management software (pro-Silva, etc.)
