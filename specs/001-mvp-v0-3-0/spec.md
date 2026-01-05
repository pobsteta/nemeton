# Feature Specification: MVP v0.3.0 - Multi-Family Indicator Extension

**Feature Branch**: `001-mvp-v0-3-0`
**Created**: 2026-01-05
**Status**: Draft
**Input**: User description: "MVP v0.3.0 du package R nemeton - Extension Multi-Familles : Biodiversité, Résilience, Trame & Air"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Biodiversity Assessment (Priority: P1)

As an ecologist, I want to evaluate biodiversity potential through protection status (B1), structural diversity (B2), and ecological connectivity (B3), so that I can prioritize high-value ecological parcels for conservation efforts.

**Why this priority**: Biodiversity is a critical ecosystem service and a primary concern for forest managers. This provides immediate value by identifying priority conservation areas.

**Independent Test**: Can be fully tested by computing B1, B2, B3 indicators for demo parcels and verifying that protected areas receive higher scores and connectivity metrics reflect actual corridor distances.

**Acceptance Scenarios**:

1. **Given** a forest parcel with 80% of area in ZNIEFF Zone 1, **When** B1 (protection) indicator is calculated, **Then** the score reflects high protection status (>75/100)
2. **Given** a parcel with multiple canopy layers and diverse age classes, **When** B2 (structural diversity) is computed, **Then** the score is higher than monoculture stands
3. **Given** a parcel adjacent to ecological corridors, **When** B3 (connectivity) is calculated, **Then** the distance metric shows proximity to network (<500m)

---

### User Story 2 - Risk Assessment & Resilience (Priority: P1)

As a forest risk manager, I want to quantify vulnerabilities to fire (R1), storms (R2), and drought stress (R3), so that I can adapt preventive management plans and reduce damage probability.

**Why this priority**: Climate change increases forest risks. Proactive risk assessment enables preventive interventions that protect both ecological and economic value.

**Independent Test**: Can be tested by computing R1, R2, R3 indicators for parcels with known risk profiles (steep slopes for fire, exposed ridges for storms, shallow soils for drought) and verifying scores align with expert assessment.

**Acceptance Scenarios**:

1. **Given** a parcel on steep slope (>30%) with fire-prone species (pine), **When** R1 (fire risk) is calculated, **Then** the risk index is elevated (>60/100)
2. **Given** a dense stand with tall trees on exposed terrain, **When** R2 (storm vulnerability) is computed, **Then** vulnerability score reflects exposure and stand characteristics
3. **Given** a parcel with low TWI and drought-sensitive species, **When** R3 (drought stress) is calculated, **Then** stress index indicates high vulnerability

---

### User Story 3 - Temporal Dynamics & Forest History (Priority: P1)

As a forest historian, I want to measure stand age (T1) and land use change rates (T2), so that I can identify ancient forests and understand transformation dynamics over time.

**Why this priority**: Ancient forests have unique ecological value. Understanding historical dynamics informs conservation and restoration strategies.

**Independent Test**: Can be tested by applying T1 to parcels with known establishment dates and T2 to areas with documented land use transitions (forest to agriculture or vice versa).

**Acceptance Scenarios**:

1. **Given** a parcel with documented planting date of 1850, **When** T1 (stand age) is calculated from historical data, **Then** age is correctly estimated (175+ years)
2. **Given** a parcel that transitioned from agriculture to forest between 1990-2010, **When** T2 (land use change) is computed from Corine Land Cover, **Then** change rate reflects the transition
3. **Given** a stable old-growth forest with no recorded disturbance, **When** T2 is calculated, **Then** change rate is minimal (<5% over 30 years)

---

### User Story 4 - Air Quality & Microclimate (Priority: P2)

As an urban planner, I want to evaluate local climate role through tree coverage (A1) and air quality (A2), so that I can justify conservation of peri-urban forest massifs for public health benefits.

**Why this priority**: Peri-urban forests provide critical ecosystem services for human populations. Quantifying these services supports conservation arguments.

**Independent Test**: Can be tested by computing A1 for parcels with varying buffer coverages and A2 for areas near known pollution sources vs. remote areas.

**Acceptance Scenarios**:

1. **Given** a parcel with dense forest extending 1km in all directions, **When** A1 (tree coverage buffer) is calculated, **Then** coverage percentage is >80%
2. **Given** a parcel adjacent to major roadway (<500m), **When** A2 (air quality proxy) is computed, **Then** score reflects proximity to pollution source
3. **Given** a remote forest parcel (>5km from urban areas), **When** A2 is calculated, **Then** air quality score is high

---

### User Story 5 - Integrated Multi-Family Indices (Priority: P2)

As a forest analyst, I want the 4 new indicator families integrated into the normalization and aggregation system, so that I can generate consistent composite indices across all 9 families (C, B, W, A, F, L, T, R).

**Why this priority**: Composite indices enable holistic ecosystem service assessment. Integration ensures backward compatibility and consistent methodology.

**Independent Test**: Can be tested by normalizing new indicators, creating family indices, and verifying radar plots display all 9 families correctly.

**Acceptance Scenarios**:

1. **Given** raw B1, B2, B3 values calculated for demo parcels, **When** normalization is applied, **Then** all values are scaled to 0-100 range
2. **Given** normalized biodiversity indicators, **When** family_B composite is created with equal weights, **Then** composite reflects average of B1, B2, B3
3. **Given** 9 family composites (C, B, W, A, F, L, T, R, plus existing), **When** radar plot is generated, **Then** all 9 axes display correctly

---

### User Story 6 - Cross-Family Analysis (Priority: P3)

As a multi-criteria analyst, I want to cross-reference new families with existing ones to detect synergies (e.g., biodiversity × age) or conflicts (e.g., productivity × protection), so that I can identify multi-objective optimization opportunities.

**Why this priority**: Cross-family insights reveal trade-offs and co-benefits, supporting more nuanced decision-making. Lower priority as it builds on Stories 1-5.

**Independent Test**: Can be tested by computing correlation matrices between families and identifying parcels ranking high on multiple criteria.

**Acceptance Scenarios**:

1. **Given** computed indicators across all families, **When** correlation matrix is generated, **Then** expected relationships appear (e.g., positive correlation between B and T indicators)
2. **Given** correlation thresholds for synergy detection, **When** analysis runs, **Then** parcels with high biodiversity AND high age are identified
3. **Given** multi-criteria ranking, **When** hotspots are mapped, **Then** parcels in top 20% for ≥3 families are highlighted

---

### Edge Cases

- What happens when protection zone data (ZNIEFF, Natura2000) is unavailable for a parcel? → B1 indicator returns NA or default score with warning
- How does the system handle parcels with no historical land use data for T2? → Indicator returns NA; change rate analysis requires multi-temporal data
- What if ATMO air quality data is not available for A2? → Fallback to distance-based proxy (distance to roads, urban areas)
- How are species-specific risk factors handled when species data is missing for R1/R3? → Use generic coefficients based on parcel characteristics
- What happens when buffer analysis (A1) extends beyond available coverage data? → Calculate coverage only for available extent with notation

## Requirements *(mandatory)*

### Functional Requirements

#### Biodiversity Family (B)

- **FR-001**: System MUST calculate B1 (protection status) as percentage of parcel area within designated protected zones (ZNIEFF, Natura2000, National Parks, Regional Parks)
- **FR-002**: System MUST calculate B2 (structural diversity) as composite index incorporating canopy stratification, age class diversity, and species composition
- **FR-003**: System MUST calculate B3 (connectivity) as minimum distance to ecological corridors or protected area networks

#### Risk & Resilience Family (R)

- **FR-004**: System MUST calculate R1 (fire risk) incorporating slope gradient, species flammability, and climate data
- **FR-005**: System MUST calculate R2 (storm vulnerability) based on stand height, density, slope exposure, and topographic position
- **FR-006**: System MUST calculate R3 (drought stress) combining TWI (Topographic Wetness Index), precipitation data, and species drought sensitivity

#### Temporal Dynamics Family (T)

- **FR-007**: System MUST calculate T1 (stand age) from forest inventory historical data or proxy indicators (Cassini maps, historical archives)
- **FR-008**: System MUST calculate T2 (land use change rate) from multi-temporal land cover datasets (Corine Land Cover or equivalent)

#### Air & Microclimate Family (A)

- **FR-009**: System MUST calculate A1 (tree coverage) as percentage of forest cover within 1km buffer around parcel
- **FR-010**: System MUST calculate A2 (air quality) using available ATMO data OR distance-based proxy when direct measurements unavailable

#### Integration & Normalization

- **FR-011**: System MUST extend normalization functions to support all 10 new indicators (B1, B2, B3, R1, R2, R3, T1, T2, A1, A2)
- **FR-012**: System MUST create family-level composite indices (family_B, family_R, family_T, family_A) using configurable weighting
- **FR-013**: System MUST extend radar visualization to display up to 9 family axes simultaneously
- **FR-014**: System MUST maintain backward compatibility with v0.2.0 workflows (existing indicators and functions continue to work)

#### Cross-Family Analysis

- **FR-015**: System MUST compute correlation matrices between any selected indicator families
- **FR-016**: System MUST identify and map multi-criteria hotspots (parcels ranking top percentile across multiple families)

#### Data Handling

- **FR-017**: System MUST handle missing data gracefully (return NA with informative warning messages)
- **FR-018**: System MUST provide bilingual (FR/EN) messages and documentation for all new functions
- **FR-019**: System MUST validate input data CRS compatibility and transform when necessary

### Key Entities

- **Indicator**: Quantitative measure of ecosystem service dimension (e.g., B1, R1, T1); has raw value, normalized value, family assignment, reference thresholds
- **Family**: Thematic group of related indicators (e.g., Biodiversity=B, Resilience=R); has composite score computed from member indicators
- **Parcel**: Spatial management unit (forest stand); has geometry, attributes, collection of indicator values across families
- **Protected Area**: Designated conservation zone (ZNIEFF, Natura2000, Parks); has geometry, protection level, designation type
- **Land Cover**: Temporal snapshot of landscape use classification; supports change detection across multiple dates
- **Risk Factor**: Environmental or structural characteristic contributing to vulnerability (slope, species, climate); influences risk indicator calculations

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 10 new indicator functions (B1-B3, R1-R3, T1-T2, A1-A2) produce valid outputs for demo dataset (massif_demo) with ≥70% test coverage
- **SC-002**: Family composite indices (family_B, family_R, family_T, family_A) correctly aggregate sub-indicators using documented methodology
- **SC-003**: Radar visualization displays all 9 implemented families (C, B, W, A, F, L, T, R, existing) without visual artifacts or overlap
- **SC-004**: 100% of v0.2.0 workflows execute successfully on v0.3.0 (backward compatibility verified through regression tests)
- **SC-005**: Cross-family correlation analysis identifies expected ecological relationships (e.g., positive correlation between biodiversity and stand age) in demo data
- **SC-006**: All new functions include complete bilingual documentation (FR/EN) with usage examples
- **SC-007**: Package builds successfully without errors and passes R CMD check with acceptable warnings (UTF-8 encoding only)
- **SC-008**: Vignette "biodiversity-resilience" demonstrates complete workflow from data loading to multi-family visualization
- **SC-009**: Hotspot analysis correctly identifies parcels in top 20% for ≥3 families when applied to demo dataset
- **SC-010**: Missing data scenarios produce informative warnings without breaking analysis workflows

## Assumptions

1. **Data Availability**: Protected area datasets (ZNIEFF, Natura2000) are available in standard formats (GeoJSON, Shapefile, or WFS services)
2. **Historical Data**: BD Forêt historical versions or equivalent proxy data exists for stand age estimation (T1)
3. **Land Cover**: Corine Land Cover or equivalent multi-temporal dataset is accessible for change detection (T2)
4. **Climate Data**: Basic climate indicators (precipitation, temperature) are available from Météo-France or WorldClim for risk assessment
5. **Computation Resources**: Buffer analysis (A1) with 1km radius is computationally feasible for typical parcel counts (<1000 units)
6. **Species Data**: Forest inventory includes species composition or dominant species for risk factor calculations
7. **Backward Compatibility**: v0.2.0 architecture (family-system.R, normalization.R, visualization.R) supports extension without breaking changes
8. **Temporal Infrastructure**: Multi-temporal analysis framework from v0.2.0 (nemeton_temporal, calculate_change_rate) is reusable for T family indicators
9. **Testing Strategy**: TDD approach maintained; tests written before implementation with ≥70% coverage target
10. **User Base**: Package users are familiar with R spatial analysis (sf, terra) and ecosystem service concepts

## Dependencies

### External Data Sources

- **INPN** (Inventaire National du Patrimoine Naturel): ZNIEFF zones, protected areas
- **IGN**: BD Forêt v2 (current + historical if available), MNT (Digital Elevation Model)
- **European Environment Agency**: Corine Land Cover multi-temporal datasets
- **Météo-France / WorldClim**: Climate data for risk assessment
- **ATMO regional networks**: Air quality measurements (optional, fallback to proxy)

### R Package Dependencies

- **Existing** (v0.2.0): sf, terra, ggplot2, dplyr, tidyr, exactextractr, whitebox
- **New Suggested**: rnaturalearth (protected area access), osmdata (OpenStreetMap data), potentially rgee (Google Earth Engine - optional)

### Infrastructure Dependencies

- Temporal analysis framework (nemeton_temporal) from v0.2.0
- Family system (create_family_index, get_family_name) from v0.2.0
- Normalization and aggregation functions from v0.2.0
- i18n bilingual system from v0.2.0

## Out of Scope

### Version 0.4.0 (Future Release)

- Families S, P, E, N (Social/Usages, Productive/Economy, Energy/Climate, Naturalness)
- L3 (Trame Verte et Bleue regional-scale connectivity)
- Shiny dashboard for interactive exploration
- Monte Carlo uncertainty analysis for indicator confidence intervals
- Full Google Earth Engine integration for satellite time series

### Not Included in Any Version

- Real-time data streaming or automated updates
- Machine learning-based indicator prediction
- Economic valuation of ecosystem services (monetary conversion)
- Detailed carbon accounting beyond biomass stocks
- Invasive species risk modeling
- Detailed soil chemistry beyond fertility classes
