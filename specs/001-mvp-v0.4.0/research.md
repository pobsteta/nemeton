# Research & Technical Decisions: MVP v0.4.0

**Feature**: Complete 12-Family Ecosystem Services Referential
**Date**: 2026-01-05
**Purpose**: Resolve technical unknowns and establish implementation patterns for new indicator families and analysis tools

---

## TD-001: OpenStreetMap Integration Patterns

**Context**: Social (S1 trails) and Naturalness (N1 infrastructure distance) indicators require querying OpenStreetMap for linear and point features.

### Decision

Use `osmdata` package (CRAN) with Overpass API for querying OSM data, with local file fallback option.

**Implementation pattern**:
```r
library(osmdata)

# Query trails within bounding box
query_trails <- function(bbox, trail_types = c("footway", "path", "cycleway")) {
  q <- opq(bbox = bbox) %>%
    add_osm_feature(key = "highway", value = trail_types)
  osmdata_sf(q)
}

# Query infrastructure
query_infrastructure <- function(bbox, types = c("motorway", "building", "power")) {
  results <- list()
  for (type in types) {
    q <- opq(bbox = bbox) %>% add_osm_feature(key = type)
    results[[type]] <- osmdata_sf(q)
  }
  results
}
```

### Rationale

- **osmdata** is actively maintained, CRAN-available, returns `sf` objects (constitution compliance)
- Overpass API provides flexible querying with bbox limitation (performance)
- Supports both vector (lines, points, polygons) and attribute filtering
- Handles large queries with automatic chunking

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Direct Overpass HTTP calls | Requires parsing XML/JSON manually; osmdata provides clean interface |
| Geofabrik shapefiles | Requires manual download/update; not automated; large file sizes |
| QGIS/ArcGIS manual extraction | Not reproducible; requires GUI; defeats automation purpose |

### Implementation Notes

1. **Data quality handling**:
   - OSM completeness varies by region → allow user to provide local files as fallback
   - Use `validate = TRUE` in osmdata queries to check data integrity
   - Warn user if OSM returns no features (suggest local file alternative)

2. **Performance optimization**:
   - Limit queries to parcel bounding box + small buffer (avoid global queries)
   - Cache OSM results per study area to avoid repeated queries
   - Use `quiet = TRUE` for batch processing

3. **Highway tag mapping for S1 (trails)**:
   - `footway`: pedestrian trails
   - `path`: general paths
   - `cycleway`: cycling paths
   - `bridleway`: equestrian paths
   - `track`: forest tracks (optional, depends on interpretation)

4. **Infrastructure types for N1 (distance)**:
   - Roads: `highway = c("motorway", "trunk", "primary", "secondary")`
   - Buildings: `building = *` (all types)
   - Power lines: `power = "line"`

---

## TD-002: INSEE Population Grid Access

**Context**: S3 population proximity indicator requires French population grid data.

### Decision

Use INSEE's "Carroyage" 1km population grid (open data), accessed via direct download from data.gouv.fr or bundled reference dataset.

**Primary source**: [INSEE Carroyage 1km (Filosofi)](https://www.insee.fr/fr/statistiques/4176290)

**Implementation approach**:
- Bundle a small reference grid covering typical study areas as package data
- Allow users to provide custom population raster for other regions
- Support both vector (grid cells) and raster formats

### Rationale

- INSEE Carroyage is **open data** (constitution requirement)
- 1km resolution provides good balance between precision and data size
- Updated annually (2018, 2019, 2020+ available)
- Covers all of France with consistent methodology

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| 200m resolution grid | 25x larger file size; overkill for regional-scale analysis; not always available |
| Commune-level aggregates | Too coarse (avg commune = 15 km²); loses spatial detail |
| WorldPop global dataset | Lower resolution (100m-1km); not optimized for France; requires large download |

### Implementation Notes

1. **Data access**:
   ```r
   # Option 1: Package-bundled reference (demo areas only)
   data(insee_population_grid_reference, package = "nemeton")

   # Option 2: User-provided raster
   pop_grid <- terra::rast("path/to/custom_population_grid.tif")

   # Option 3: Download from data.gouv.fr (optional helper function)
   download_insee_grid(year = 2020, dest_path = "data/")
   ```

2. **Buffer radius defaults**:
   - 5 km: immediate surroundings (local recreation)
   - 10 km: regional catchment
   - 20 km: extended region (day trips)

3. **Spatial join**:
   - Use `terra::extract()` with `sum` for population within buffer
   - Alternatively, `sf::st_intersection()` for vector grid cells

4. **Missing data handling**:
   - If grid cell has NA population → treat as 0 (uninhabited)
   - Warn if study area falls outside grid coverage

---

## TD-003: IFN Allometric Equations Coverage

**Context**: P1 standing volume indicator requires volume equations. Existing C1 (biomass) uses IFN equations; need to extend for volume.

### Decision

Extend existing allometric infrastructure from v0.2.0 (R/utils.R `get_allometric_model()`) with IFN volume equations table.

**Primary source**: [IFN Volume Tariffs](https://inventaire-forestier.ign.fr/spip.php?rubrique223) - Tarifs de cubage

**Implementation**: Bundle volume equations as internal dataset `sysdata.rda` (similar to biomass equations in v0.2.0).

### Rationale

- IFN volume equations are **reference standard** for French forestry
- Covers ~60 major species with diameter-height-volume relationships
- Consistent with existing C1 biomass approach (proven pattern)
- Equations are scientific publications (openly documented)

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| BD Forêt v2 direct volume | Proprietary; not redistributable; constitution violation |
| Generic allometric models (Chave) | Designed for tropical forests; less accurate for temperate European species |
| User-provided volume field | Reduces automation; requires pre-processing; defeats indicator purpose |

### Implementation Notes

1. **Equation catalog structure** (`inst/extdata/ifn_volume_equations.csv`):
   ```csv
   species,equation_type,a,b,c,dbh_min,dbh_max,reference
   Quercus_robur,volume,0.42,2.15,1.08,7.5,67.5,IFN_2005
   Fagus_sylvatica,volume,0.38,2.22,1.12,7.5,67.5,IFN_2005
   ...
   ```

2. **Fallback strategy** (for rare/unlisted species):
   - **Level 1**: Use genus-level equation (e.g., Quercus sp. for Q. pubescens)
   - **Level 2**: Use generic broadleaf/conifer equation
   - **Level 3**: Use height-diameter-volume universal equation (Deleuze & Houllier)
   - Always warn user which fallback was applied

3. **Integration with C1 biomass**:
   - Reuse `get_allometric_model()` helper, add `type = "volume"` parameter
   - Share species name standardization logic (handle synonyms, typos)

4. **Volume calculation formula** (typical IFN tariff):
   ```
   V = a * (DBH^b) * (H^c)
   Where: V = volume (m³), DBH = diameter at breast height (cm), H = total height (m)
   ```

5. **Validation**:
   - Cross-check against published IFN tariff values
   - Include test fixture with known volume (e.g., DBH=30cm, H=20m for Quercus → expect ~0.85 m³)

---

## TD-004: ADEME Emission Factors

**Context**: E2 carbon avoidance indicator requires CO2 emission factors for wood vs fossil fuels and wood vs construction materials.

### Decision

Bundle ADEME Base Carbone® emission factors as internal reference table, with user override capability for custom factors.

**Primary source**: [Base Carbone® ADEME](https://www.bilans-ges.ademe.fr/) (open database)

**Implementation**: Store factors in `inst/extdata/ademe_emission_factors.csv` with version metadata.

### Rationale

- ADEME Base Carbone® is **official French reference** for carbon accounting
- Open data (freely accessible online)
- Regularly updated (versioned releases)
- Covers wood energy, fossil fuels, construction materials

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| IPCC default factors | Less region-specific than ADEME; French users expect ADEME data |
| Ecoinvent database | Requires license; not open data; constitution violation |
| User-provided factors only | Reduces automation; requires expert knowledge; defeats indicator purpose |

### Implementation Notes

1. **Emission factor table structure**:
   ```csv
   category,subcategory,unit,kgCO2eq_per_unit,version,year
   fossil_fuel,natural_gas,kWh,0.227,v20.0,2023
   fossil_fuel,fuel_oil,kWh,0.324,v20.0,2023
   fossil_fuel,electricity_france,kWh,0.057,v20.0,2023
   material,cement,kg,0.865,v20.0,2023
   material,steel,kg,2.54,v20.0,2023
   wood,fuelwood_combustion,kg,-0.013,v20.0,2023
   wood,material_substitution_cement,kg,-0.782,v20.0,2023
   wood,material_substitution_steel,kg,-2.45,v20.0,2023
   ```

2. **Substitution calculation**:
   ```r
   # Energy substitution (wood replacing fossil fuel)
   co2_avoided_energy <- fuelwood_tonnes * 1000 *
                         (emission_factor_fossilfuel - emission_factor_wood)

   # Material substitution (wood replacing cement/steel in construction)
   co2_avoided_material <- wood_material_tonnes *
                           substitution_factor_concrete
   ```

3. **Versioning strategy**:
   - Include ADEME version metadata in output (e.g., `attr(result, "ademe_version") <- "v20.0"`)
   - Allow user to override factors: `indicator_energy_avoidance(units, custom_factors = my_factors)`
   - Document in roxygen when factors were last updated

4. **Functional unit conversions**:
   - Wood fuelwood: tonnes dry matter → kWh (heating value ~4.2 kWh/kg DM)
   - Fossil fuels: kWh (natural gas, fuel oil, electricity)
   - Materials: kg (cement, steel) based on substitution ratios

5. **Conservative assumptions**:
   - Use lower-bound estimates for wood carbon benefits (avoid overestimation)
   - Account for combustion inefficiency (real-world vs theoretical)
   - Document assumptions in roxygen `@details` section

---

## TD-005: Pareto Optimality Algorithms

**Context**: US7 (Advanced Multi-Criteria Analysis) requires identifying Pareto-optimal parcels across 12 family dimensions.

### Decision

Implement efficient Pareto dominance check using vectorized R operations (no external package for core algorithm).

**Algorithm**: Pairwise dominance comparison with early termination optimization.

### Rationale

- Pareto dominance for multi-objective optimization is **well-established** in operations research
- No need for specialized package; algorithm is ~30 lines of R code
- Vectorized operations in R are fast enough for 1000-parcel × 12-dimension datasets
- Avoids new dependency (YAGNI principle)

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| `emoa` package | Focuses on evolutionary algorithms (overkill); we only need dominance check |
| `mco` package | Multi-criteria optimization for continuous problems; overkill for discrete parcels |
| `rPref` package | Skyline queries (similar to Pareto); adds dependency; not significantly faster |

### Implementation Notes

1. **Pareto dominance definition**:
   - Parcel A dominates parcel B if:
     - A is better than B in at least one objective, AND
     - A is not worse than B in any other objective
   - Parcel is **Pareto-optimal** if no other parcel dominates it

2. **Algorithm pseudocode**:
   ```r
   identify_pareto_optimal <- function(units, families, objectives = "max") {
     # Extract family scores as matrix
     scores <- as.matrix(sf::st_drop_geometry(units[, families]))

     # Flip scores for minimization objectives
     if (any(objectives == "min")) {
       scores[, objectives == "min"] <- -scores[, objectives == "min"]
     }

     # Check dominance
     n <- nrow(scores)
     is_dominated <- rep(FALSE, n)

     for (i in 1:n) {
       if (is_dominated[i]) next  # Skip already dominated
       for (j in 1:n) {
         if (i == j) next
         # Check if j dominates i
         if (all(scores[j, ] >= scores[i, ]) && any(scores[j, ] > scores[i, ])) {
           is_dominated[i] <- TRUE
           break
         }
       }
     }

     units$is_pareto_optimal <- !is_dominated
     units
   }
   ```

3. **Objectives specification**:
   - Default: all families are "maximize" (higher = better)
   - Exception: family_R (Risk) may be "minimize" (lower risk = better)
   - User can specify per-family: `objectives = c(family_P = "max", family_R = "min", ...)`

4. **Performance optimization**:
   - Early termination: once parcel is dominated, skip remaining comparisons
   - Vectorized comparisons: use matrix operations instead of loops where possible
   - Expected complexity: O(n² × m) where n = parcels, m = families (acceptable for n < 10000)

5. **Output**:
   - Add column `is_pareto_optimal` (logical) to units sf object
   - Optionally return Pareto set as separate sf object: `units[units$is_pareto_optimal, ]`

6. **Validation**:
   - Test with known Pareto sets (e.g., 2D example: points on convex hull are Pareto-optimal)
   - Ensure at least 1 parcel is always Pareto-optimal (unless all identical)
   - Handle ties correctly (equal scores → not dominated)

---

## TD-006: Clustering Methods for Multi-Family Profiles

**Context**: US7 requires clustering parcels based on 12-family profiles to identify similar management strategies.

### Decision

Use `cluster` package (base R, no installation needed) with **K-means** as primary method and **hierarchical clustering** as alternative.

**Default method**: K-means with k determined by elbow/silhouette analysis.

### Rationale

- `cluster` package is **part of base R** (no new dependency)
- K-means is fast, scalable, well-suited for continuous data (family scores 0-100)
- Hierarchical clustering provides dendrogram visualization (useful for interpretation)
- Both methods well-documented in R ecosystem

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| `Mclust` (model-based clustering) | Requires `mclust` package; overkill for 12 dimensions; slower |
| DBSCAN | Density-based; requires distance threshold tuning; not ideal for continuous scores |
| PCA + clustering | Loses interpretability (principal components harder to explain than family scores) |

### Implementation Notes

1. **K-means implementation**:
   ```r
   cluster_parcels <- function(units, families = NULL, k = NULL, method = "kmeans") {
     # Auto-detect families if not specified
     if (is.null(families)) {
       families <- grep("^family_", names(units), value = TRUE)
     }

     # Extract family scores
     scores <- sf::st_drop_geometry(units[, families])

     # Determine k if not provided
     if (is.null(k)) {
       k <- determine_optimal_k(scores, max_k = min(10, nrow(scores) / 2))
     }

     # Cluster
     if (method == "kmeans") {
       result <- kmeans(scores, centers = k, nstart = 25)
       units$cluster_id <- result$cluster
     } else if (method == "hierarchical") {
       d <- dist(scores)
       hc <- hclust(d, method = "ward.D2")
       units$cluster_id <- cutree(hc, k = k)
     }

     # Add cluster profiles as attribute
     attr(units, "cluster_profiles") <- compute_cluster_profiles(scores, units$cluster_id)

     units
   }
   ```

2. **Optimal k determination**:
   - **Elbow method**: Within-cluster sum of squares (WCSS) vs k
   - **Silhouette method**: Average silhouette width vs k
   - **Default**: Use k that maximizes silhouette score
   ```r
   determine_optimal_k <- function(data, max_k = 10) {
     silhouettes <- numeric(max_k - 1)
     for (k in 2:max_k) {
       km <- kmeans(data, centers = k, nstart = 10)
       sil <- cluster::silhouette(km$cluster, dist(data))
       silhouettes[k - 1] <- mean(sil[, 3])
     }
     which.max(silhouettes) + 1  # +1 because index starts at k=2
   }
   ```

3. **Cluster profile computation**:
   ```r
   compute_cluster_profiles <- function(scores, cluster_ids) {
     profiles <- scores %>%
       mutate(cluster = cluster_ids) %>%
       group_by(cluster) %>%
       summarise(across(everything(), mean, na.rm = TRUE))
     as.data.frame(profiles)
   }
   ```

4. **Visualization - cluster profiles as radar plots**:
   - Generate one radar plot per cluster showing mean family scores
   - Use `patchwork` to combine multiple radars in grid layout
   - Color-code clusters consistently across visualizations

5. **Interpretation aids**:
   - Name clusters based on dominant families (e.g., "High Production", "High Conservation", "Balanced")
   - Provide summary statistics: cluster size, within-cluster variance
   - Suggest management strategies per cluster type

6. **Validation**:
   - Test with synthetic data: clear clusters should be recovered
   - Ensure k=1 and k=n (all different) work as edge cases
   - Check stability: run clustering 10 times, ensure consistent results (k-means random initialization)

---

## Summary of Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| **OSM Integration** | osmdata package | CRAN, returns sf, flexible queries, handles large data |
| **INSEE Population** | Carroyage 1km grid | Open data, good resolution, covers France, annual updates |
| **IFN Volume Equations** | Bundle IFN tariffs in sysdata | Reference standard, extends v0.2.0 pattern, genus fallbacks |
| **ADEME Factors** | Bundle Base Carbone® table | Official French reference, open data, versioned, user overrides |
| **Pareto Algorithm** | Custom vectorized R code | No dependency, fast enough, well-established algorithm |
| **Clustering** | cluster pkg K-means/hierarchical | Base R, scalable, interpretable, silhouette-based k selection |

All decisions align with constitution principles:
- ✅ **Open Data First**: OSM, INSEE, IFN, ADEME all open/documented
- ✅ **Interopérabilité**: sf objects, standard R functions
- ✅ **Simplicité/YAGNI**: No over-engineering, proven patterns, minimal dependencies
- ✅ **Transparence**: Explicit parameters, documented sources, version metadata

---

**Research Phase Status**: ✅ COMPLETE
**Next Phase**: Phase 1 - Data Model & API Contracts
**Document Version**: 1.0
**Last Updated**: 2026-01-05
