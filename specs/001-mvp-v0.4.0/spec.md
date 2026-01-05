# Feature Specification: MVP v0.4.0 - Complete 12-Family Ecosystem Services Referential

**Feature Branch**: `001-mvp-v0.4.0`
**Created**: 2026-01-05
**Status**: Draft
**Input**: User description: "MVP v0.4.0 du package R nemeton - Finalisation Référentiel 12 Familles : Social, Productif, Énergie"

## Executive Summary

This specification defines the completion of the nemeton ecosystem services assessment framework by implementing the final 4 indicator families (Social, Productive, Energy, Naturalness) to achieve a comprehensive 12-family referential. Building on the existing 9 families from v0.2.0-v0.3.0, this release will provide complete coverage of ecosystem services dimensions for forest management decision-making.

**Context**: The nemeton package currently supports 9/12 indicator families (C-Carbon, B-Biodiversity, W-Water, A-Air, F-Soil, L-Landscape, T-Temporal, R-Risk). This release completes the framework by adding Social/Recreational (S), Productive/Economic (P), Energy/Climate (E), and Naturalness/Wilderness (N) families, plus advanced multi-criteria analysis tools.

**Goal**: Enable forest managers, ecologists, and planners to perform comprehensive ecosystem services assessments covering all dimensions from carbon sequestration to social benefits, using a unified, scientifically-validated framework with complete documentation and demo datasets.

## User Scenarios & Testing

### User Story 1 - Social & Recreational Services Assessment (Priority: P1)

As a forest manager or natural area administrator, I need to quantify recreational use potential through trail density, multimodal accessibility, and population proximity to optimize public access while preserving ecosystem integrity.

**Why this priority**: Recreational services represent a critical ecosystem value for urban and peri-urban forests. Understanding visitor pressure helps balance conservation and public enjoyment, addressing a key gap in current assessment capabilities.

**Independent Test**: Can be fully tested by calculating S1 (trail density), S2 (accessibility score), and S3 (population proximity) for a set of forest parcels and verifying the family_S composite index ranges from 0-100 with higher values indicating greater recreational potential.

**Acceptance Scenarios**:

1. **Given** a forest parcel with known trail network data, **When** I calculate S1 trail density indicator, **Then** the system returns trail density in km/ha based on OpenStreetMap footway/cycleway data
2. **Given** a forest parcel location, **When** I calculate S2 accessibility indicator, **Then** the system returns a multimodal accessibility score (0-100) combining road, public transport, and cycling access
3. **Given** a forest parcel location, **When** I calculate S3 population proximity indicator, **Then** the system returns population counts within 5km, 10km, and 20km buffers based on INSEE grid data
4. **Given** calculated S1, S2, S3 indicators, **When** I create the Social family composite index, **Then** the system returns a normalized family_S score (0-100) representing overall recreational potential

---

### User Story 2 - Productive & Economic Services Assessment (Priority: P1)

As a forest manager, I need to evaluate timber production potential through standing volume, site productivity, and wood quality to optimize harvest planning and economic valorization.

**Why this priority**: Timber production represents the traditional economic foundation of forest management. Quantifying productive capacity is essential for sustainable management plans and economic viability assessments.

**Independent Test**: Can be fully tested by calculating P1 (standing volume), P2 (site productivity), and P3 (wood quality) for forest parcels with species and biometric data, verifying the family_P composite reflects economic potential.

**Acceptance Scenarios**:

1. **Given** forest parcel data with species composition and biometric measurements, **When** I calculate P1 standing volume indicator, **Then** the system returns volume (m³/ha) using IFN allometric equations
2. **Given** parcel data with soil fertility and climate variables, **When** I calculate P2 site productivity indicator, **Then** the system returns a productivity index combining station fertility, climate suitability, and species matching
3. **Given** parcel stand characteristics (stem form, diameter, height), **When** I calculate P3 wood quality indicator, **Then** the system returns a quality score (0-100) based on timber grade criteria (straightness, defect frequency, commercial diameter)
4. **Given** calculated P1, P2, P3 indicators, **When** I create the Productive family composite index, **Then** the system returns a normalized family_P score representing overall economic potential

---

### User Story 3 - Energy & Climate Services Assessment (Priority: P1)

As a regional energy planner, I need to quantify mobilizable fuelwood potential and carbon substitution benefits to evaluate forest contributions to energy transition and climate mitigation.

**Why this priority**: With climate targets and renewable energy goals, understanding forest energy potential and carbon substitution effects is critical for territorial planning and climate action plans.

**Independent Test**: Can be fully tested by calculating E1 (fuelwood potential) and E2 (carbon avoidance) for forest parcels, verifying the family_E composite captures energy/climate benefits.

**Acceptance Scenarios**:

1. **Given** forest parcel data with biomass estimates, **When** I calculate E1 fuelwood potential indicator, **Then** the system returns mobilizable fuelwood volume (tonnes dry matter/year) from harvest residues and coppice
2. **Given** fuelwood potential and substitution factors, **When** I calculate E2 carbon avoidance indicator, **Then** the system returns avoided CO2 emissions (tCO2eq/year) from fossil fuel and material substitution using ADEME emission factors
3. **Given** calculated E1, E2 indicators, **When** I create the Energy family composite index, **Then** the system returns a normalized family_E score representing climate mitigation potential

---

### User Story 4 - Naturalness & Wilderness Assessment (Priority: P2)

As a conservation ecologist, I need to measure wilderness character through infrastructure distance, forest continuity, and composite naturalness indices to identify high-value conservation areas and ecological corridors.

**Why this priority**: Naturalness complements biodiversity indicators by capturing wilderness quality, a key dimension for reserve selection and connectivity planning that wasn't fully addressed in previous families.

**Independent Test**: Can be fully tested by calculating N1 (infrastructure distance), N2 (forest continuity), and N3 (composite naturalness) for parcels, verifying the family_N composite identifies undisturbed areas.

**Acceptance Scenarios**:

1. **Given** forest parcel location and infrastructure datasets (roads, buildings, power lines), **When** I calculate N1 infrastructure distance indicator, **Then** the system returns minimum distance (meters) to nearest human infrastructure
2. **Given** forest parcel and land cover data, **When** I calculate N2 forest continuity indicator, **Then** the system returns continuous forest patch area (hectares) without fragmentation
3. **Given** N1, N2, and existing indicators (T1 ancientness, B1 protection status), **When** I calculate N3 composite naturalness indicator, **Then** the system returns an integrated wilderness score combining remoteness, continuity, age, and protection
4. **Given** calculated N1, N2, N3 indicators, **When** I create the Naturalness family composite index, **Then** the system returns a normalized family_N score representing wilderness character

---

### User Story 5 - Complete 12-Family System Integration (Priority: P2)

As a package user, I need all 12 indicator families integrated into the normalization, visualization, and cross-analysis infrastructure to work with the complete ecosystem services framework seamlessly.

**Why this priority**: Infrastructure integration ensures the new families work consistently with existing tools (radar plots, correlation analysis, hotspot detection), completing the unified framework.

**Independent Test**: Can be fully tested by calculating all 12 family indices for a parcel set, generating a 12-axis radar plot, computing 12×12 correlation matrix, and identifying multi-criteria hotspots across all dimensions.

**Acceptance Scenarios**:

1. **Given** calculated indicators for families S, P, E, N, **When** I normalize them using the normalization system, **Then** all new indicators transform correctly to 0-100 scales using appropriate methods (linear, log, inverse)
2. **Given** normalized indicators, **When** I create family composite indices for S, P, E, N, **Then** the family system generates family_S, family_P, family_E, family_N columns with weighted aggregation
3. **Given** 12 family indices (C, B, W, A, F, L, T, R, S, P, E, N), **When** I generate a radar plot, **Then** the visualization displays a 12-axis chart with appropriate labels and scaling
4. **Given** dataset with all 12 families, **When** I compute correlations, **Then** the correlation matrix includes all 12×12 family relationships with proper coefficient calculation
5. **Given** 12-family dataset, **When** I identify hotspots requiring top performance in ≥8 families, **Then** the system correctly flags multi-dimensional exceptional parcels

---

### User Story 6 - Complete Reference Dataset with All Families (Priority: P2)

As a user learning the package, I need demo data with all 12 families pre-calculated to quickly understand the complete framework without needing external data sources.

**Why this priority**: Comprehensive demo data accelerates adoption by providing immediate hands-on experience with the full framework, reducing barriers to entry and supporting documentation examples.

**Independent Test**: Can be fully tested by loading the extended demo dataset and verifying it contains valid values for all 20 indicators (C1-C2, B1-B3, W1-W3, A1-A2, F1-F2, L1-L2, T1-T2, R1-R3, S1-S3, P1-P3, E1-E2, N1-N3) plus 12 family composites.

**Acceptance Scenarios**:

1. **Given** the extended demo dataset, **When** I load it into R, **Then** the dataset contains 20 parcels with all 20 individual indicators calculated
2. **Given** the loaded dataset, **When** I inspect family composite columns, **Then** all 12 family_* columns exist with valid 0-100 scores
3. **Given** the dataset documentation, **When** I read the data generation methodology, **Then** the documentation clearly explains synthetic data generation methods and limitations
4. **Given** vignette examples using the dataset, **When** I execute workflow code, **Then** all 12-family analyses run successfully without requiring external data downloads

---

### User Story 7 - Advanced Multi-Criteria Analysis Tools (Priority: P3)

As a decision analyst, I need advanced optimization tools (Pareto optimality detection, clustering, trade-off visualization) to identify management strategies balancing competing objectives across the 12 ecosystem service dimensions.

**Why this priority**: With 12 dimensions, sophisticated analysis tools become essential for extracting actionable insights. Pareto analysis and clustering help navigate complexity and support evidence-based decisions.

**Independent Test**: Can be fully tested by applying Pareto analysis to identify non-dominated parcels, clustering to group similar profiles, and trade-off plots to visualize dimension conflicts.

**Acceptance Scenarios**:

1. **Given** a dataset with 12 family indices, **When** I identify Pareto-optimal parcels across selected dimensions (e.g., Production vs Conservation), **Then** the system returns parcels where no other parcel scores higher on all selected dimensions simultaneously
2. **Given** 12-family dataset, **When** I apply K-means clustering with k=4 groups, **Then** the system assigns each parcel to a cluster based on its multi-dimensional profile and returns cluster centers
3. **Given** two competing families (e.g., family_P production vs family_B biodiversity), **When** I generate a trade-off plot, **Then** the system produces a scatterplot showing the relationship, highlights Pareto frontier, and identifies win-win vs trade-off zones
4. **Given** clustering results, **When** I visualize cluster profiles, **Then** the system generates radar plots showing mean family scores per cluster for interpretation

---

### Edge Cases

- **Missing data**: What happens when parcel lacks trail data (S1) or species information (P1, P2)?
  - System should handle NAs gracefully, allow indicator skipping, and propagate missingness to family composite with warnings

- **Extreme values**: How does normalization handle outliers in new indicators (e.g., very high S3 population density)?
  - Normalization system should use robust methods (quantile-based) or allow manual threshold specification to avoid distortion

- **Infrastructure dependencies**: What if OpenStreetMap or INSEE data is unavailable for study area?
  - System should support local file inputs as alternative to web services, with clear fallback documentation

- **Composite conflicts**: How are conflicting weights handled in N3 composite naturalness when component indicators have different scales?
  - System should normalize components before aggregation and validate weight sums to 1.0

- **Backward compatibility**: Do v0.3.0 workflows break when new families are added?
  - All existing functions must continue working identically; new families are purely additive extensions

## Requirements

### Functional Requirements

#### Social Family (S) - Recreational Services

- **FR-001**: System MUST calculate S1 trail density indicator from line geometries (OpenStreetMap or local files), returning km/ha for each parcel
- **FR-002**: System MUST calculate S2 multimodal accessibility indicator combining road network distance, public transport availability, and cycling infrastructure proximity
- **FR-003**: System MUST calculate S3 population proximity indicator with configurable buffer radii (default: 5km, 10km, 20km) using INSEE or custom population grid data
- **FR-004**: System MUST aggregate S1, S2, S3 into family_S composite index (0-100) with user-definable weights

#### Productive Family (P) - Economic Services

- **FR-005**: System MUST calculate P1 standing volume indicator (m³/ha) using IFN allometric equations matched to parcel species composition
- **FR-006**: System MUST calculate P2 site productivity indicator integrating soil fertility (from existing F1), climate variables, and species-site matching tables
- **FR-007**: System MUST calculate P3 wood quality indicator based on silvicultural criteria (stem straightness, commercial diameter thresholds, defect frequency)
- **FR-008**: System MUST aggregate P1, P2, P3 into family_P composite index (0-100) with user-definable weights

#### Energy Family (E) - Climate Services

- **FR-009**: System MUST calculate E1 fuelwood potential indicator (tonnes dry matter/year) from harvest residue estimates and coppice biomass
- **FR-010**: System MUST calculate E2 carbon avoidance indicator (tCO2eq/year) using ADEME emission factors for wood-to-fossil and wood-to-material substitution
- **FR-011**: System MUST aggregate E1, E2 into family_E composite index (0-100) with user-definable weights

#### Naturalness Family (N) - Wilderness Character

- **FR-012**: System MUST calculate N1 infrastructure distance indicator as minimum Euclidean distance to roads, buildings, and power lines from OpenStreetMap or local sources
- **FR-013**: System MUST calculate N2 forest continuity indicator as continuous forest patch area using land cover data and patch connectivity analysis
- **FR-014**: System MUST calculate N3 composite naturalness indicator integrating N1, N2, with existing T1 (ancientness) and B1 (protection status) using multiplicative or weighted approach
- **FR-015**: System MUST aggregate N1, N2, N3 into family_N composite index (0-100) with user-definable weights

#### System Integration

- **FR-016**: System MUST extend normalization framework to support all new indicators (S1-S3, P1-P3, E1-E2, N1-N3) with appropriate transformation methods
- **FR-017**: System MUST extend family_index creation to support families S, P, E, N with backward compatibility for existing families
- **FR-018**: System MUST extend radar plot visualization to support 12-axis display with automatic layout adjustment
- **FR-019**: System MUST extend correlation analysis functions to handle 12×12 family matrices
- **FR-020**: System MUST extend hotspot detection to operate across all 12 families with configurable thresholds

#### Demo Data & Documentation

- **FR-021**: System MUST provide extended demo dataset (massif_demo_units_extended) with all 20 indicators and 12 families pre-calculated for the 20 reference parcels
- **FR-022**: Demo data generation MUST be reproducible with documented synthetic data methods for indicators lacking real source data
- **FR-023**: System MUST include vignette demonstrating complete 12-family workflow from raw indicators to multi-criteria analysis

#### Advanced Analysis

- **FR-024**: System MUST implement Pareto optimality detection to identify non-dominated parcels across user-selected family dimensions
- **FR-025**: System MUST implement K-means and hierarchical clustering on multi-family profiles with configurable number of clusters
- **FR-026**: System MUST generate trade-off scatterplots for family pairs showing correlation, Pareto frontier, and zone classification

### Non-Functional Requirements

- **NFR-001**: All new functions MUST maintain bilingual support (FR/EN) using existing i18n infrastructure
- **NFR-002**: All new indicators MUST have roxygen2 documentation with examples, mathematical formulas, and data source citations
- **NFR-003**: Test coverage MUST reach ≥70% for all new code (target: ≥80%)
- **NFR-004**: All v0.3.0 user workflows MUST continue functioning without modification (backward compatibility)
- **NFR-005**: Package MUST pass R CMD check with 0 errors, 0 warnings (excluding platform-specific UTF-8 notes)

### Key Entities

- **Social Indicators**: S1 (trail density), S2 (accessibility), S3 (population proximity) - quantify recreational use potential
- **Productive Indicators**: P1 (standing volume), P2 (site productivity), P3 (wood quality) - quantify economic timber value
- **Energy Indicators**: E1 (fuelwood potential), E2 (carbon avoidance) - quantify climate mitigation services
- **Naturalness Indicators**: N1 (infrastructure distance), N2 (forest continuity), N3 (composite naturalness) - quantify wilderness character
- **Family Composites**: family_S, family_P, family_E, family_N - aggregated 0-100 scores per ecosystem service family
- **Complete Referential**: 12 families × variable indicators = 20 total biophysical indicators covering full ecosystem services spectrum
- **Extended Demo Dataset**: massif_demo_units_extended - 20 parcels with all 12 families calculated for testing and documentation
- **Pareto Set**: Subset of non-dominated parcels representing optimal trade-offs across selected dimensions
- **Cluster Profiles**: K groups of parcels with similar multi-dimensional ecosystem service profiles

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can calculate all 11 new indicators (S1-S3, P1-P3, E1-E2, N1-N3) for a 20-parcel dataset in under 5 minutes on standard hardware
- **SC-002**: System generates 12-axis radar plots for parcel comparison without manual layout adjustment
- **SC-003**: Correlation analysis produces complete 12×12 family correlation matrices with valid coefficients (-1 to +1 range)
- **SC-004**: Pareto optimality detection identifies non-dominated parcels across 12 dimensions in under 10 seconds for 1000-parcel datasets
- **SC-005**: Clustering analysis assigns parcels to K groups and generates interpretable cluster profiles in under 30 seconds
- **SC-006**: Extended demo dataset loads and executes all vignette workflows without external data dependencies
- **SC-007**: Test suite achieves ≥70% code coverage for all new functions (target: ≥80%)
- **SC-008**: Package documentation includes working examples for all 11 new indicator functions
- **SC-009**: All v0.3.0 user code continues running without modification after v0.4.0 installation (100% backward compatibility)
- **SC-010**: R CMD check completes with 0 errors and 0 warnings (excluding platform UTF-8 notes)

### Quality Benchmarks

- **SC-011**: New indicator calculations produce consistent results across different input formats (sf vs data.frame geometries)
- **SC-012**: Normalization transformations preserve indicator ranking (no order inversions)
- **SC-013**: Family composite indices respond sensibly to individual indicator changes (monotonic relationships)
- **SC-014**: Vignettes execute successfully on fresh R installations with only CRAN package dependencies
- **SC-015**: All bilingual messages (FR/EN) display correctly without encoding errors

## Out of Scope

The following are explicitly excluded from v0.4.0 and deferred to future releases:

- **Interactive Shiny dashboard** for web-based exploration (v0.5.0)
- **Monte Carlo uncertainty analysis** for indicator confidence intervals (v0.5.0)
- **Google Earth Engine integration** for automated satellite data processing (v0.5.0)
- **REST API** for remote calculation services (v0.6.0)
- **Machine learning models** for indicator prediction from limited inputs (future)
- **Real-time data pipelines** for automatic updates from national databases (future)
- **Mobile application** for field data collection (future)

## Assumptions

1. **Data availability**: Users have access to OpenStreetMap, INSEE population grids, and basic forestry inventory data (species, DBH, height) OR can provide local equivalents
2. **Computational capacity**: Standard desktop/laptop (4GB RAM, dual-core CPU) sufficient for typical forest management units (<10,000 parcels)
3. **R environment**: Users have R ≥4.0.0 with ability to install CRAN packages
4. **Existing infrastructure**: The v0.3.0 family system, normalization, and temporal framework provide solid foundation requiring minimal refactoring
5. **Synthetic data acceptance**: Users understand demo dataset uses synthetic/approximated data for indicators lacking real sources, limiting its use to package exploration (not real-world analysis)
6. **French/international context**: Primary use case is French forest management, but framework designed for international applicability with data source substitution

## Dependencies

- **Existing nemeton v0.3.0**: Complete 9-family infrastructure (temporal, normalization, family system, visualization, correlation analysis)
- **External R packages**: osmdata (OSM queries), cluster (clustering algorithms), ggrepel (plot labels) - all available on CRAN
- **Data sources**: OpenStreetMap (trails, infrastructure), INSEE (population), IFN (allometric equations, productivity tables), ADEME (emission factors)
- **Optional data sources**: BD Forêt v2 (volume estimates), GTFS feeds (public transport), local cadastral data

## Constraints

### Technical Constraints

- **TC-001**: Must maintain R ≥4.0.0 compatibility (cannot use newer language features)
- **TC-002**: Must work within sf/terra spatial frameworks (no proprietary GIS dependencies)
- **TC-003**: Must support offline workflows (no hard requirement for internet connectivity if local data provided)
- **TC-004**: Must limit memory footprint to <2GB for 10,000-parcel analyses

### Business Constraints

- **BC-001**: Must maintain free/open-source licensing (MIT license)
- **BC-002**: Must support both research and operational forest management use cases
- **BC-003**: Must remain accessible to users without GIS expertise (friendly API design)

### Regulatory Constraints

- **RC-001**: Must respect data licensing (OpenStreetMap ODbL, INSEE open license)
- **RC-002**: Must not redistribute proprietary data (BD Forêt) within package

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OSM data quality varies by region | Medium | High | Provide local file input option; document quality assessment methods |
| INSEE population data access changes | Low | Low | Cache reference datasets; support custom population rasters |
| IFN allometric equations incomplete for rare species | Medium | Medium | Implement genus-level fallbacks; document coverage limitations |
| ADEME emission factors updated | Low | Medium | Version factor tables; allow user overrides |
| Computational performance degrades with 12 families | Medium | Low | Optimize correlation/clustering algorithms; add progress indicators |
| Backward compatibility breaks edge case | Medium | Low | Comprehensive regression test suite; semantic versioning |

## Glossary

- **Ecosystem Services**: Benefits humans derive from ecosystems (provisioning, regulating, cultural, supporting)
- **Family (Indicator Family)**: Thematic group of related ecosystem service indicators (e.g., Biodiversity family includes protection, structure, connectivity)
- **Composite Index**: Aggregated score combining multiple indicators into single 0-100 metric per family
- **Pareto Optimality**: Set of solutions where no objective can be improved without worsening another objective
- **Normalization**: Transformation of indicators to common 0-100 scale for comparability
- **Allometric Equation**: Mathematical relationship predicting tree characteristics (e.g., volume) from measured variables (e.g., diameter)
- **Wilderness Character**: Degree to which an area exhibits natural conditions free from human modification
- **Multi-criteria Analysis**: Decision support approach evaluating alternatives across multiple competing objectives

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Authors**: Generated from user requirements via speckit.specify
**Review Status**: Awaiting validation
