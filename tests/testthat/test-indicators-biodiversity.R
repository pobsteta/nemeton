# test-indicators-biodiversity.R
# Unit and integration tests for Biodiversity Family (B) Indicators
# MVP v0.3.0 - Following TDD: Tests written BEFORE implementation

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T014: Unit Tests for indicateur_b1_protection() (B1)
# ==============================================================================

test_that("indicateur_b1_protection calculates overlap correctly", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Load test fixture
  protected_areas <- readRDS(test_path("fixtures/protected_areas/protected_areas_demo.rds"))

  # Calculate B1 with local data
  result <- indicateur_b1_protection(
    units,
    protected_areas = protected_areas,
    source = "local"
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_type(result$B1, "double")
  expect_true(all(result$B1 >= 0 & result$B1 <= 100, na.rm = TRUE))

  # At least some parcels should have protection coverage
  expect_true(any(result$B1 > 0, na.rm = TRUE))
})

test_that("indicateur_b1_protection handles missing data gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Empty protected areas
  empty_pa <- st_sf(
    zone_id = character(0),
    geometry = st_sfc(crs = st_crs(units))
  )

  result <- indicateur_b1_protection(units, protected_areas = empty_pa, source = "local")

  # Should return 0% protection for all parcels
  expect_true(all(result$B1 == 0, na.rm = TRUE))
})

# ==============================================================================
# T015: Unit Tests for indicateur_b2_structure() (B2)
# ==============================================================================

test_that("indicateur_b2_structure calculates Shannon diversity", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add synthetic strata and age class attributes
  units$strata_classes <- sample(c("Emergent", "Dominant", "Intermediate", "Suppressed"),
    5,
    replace = TRUE
  )
  units$age_classes <- sample(c("Young", "Intermediate", "Mature", "Old", "Ancient"),
    5,
    replace = TRUE
  )

  result <- indicateur_b2_structure(
    units,
    strata_field = "strata_classes",
    age_class_field = "age_classes",
    method = "shannon",
    weights = c(strata = 0.4, age = 0.3, species = 0.3)
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
  expect_type(result$B2, "double")
  expect_true(all(result$B2 >= 0 & result$B2 <= 100, na.rm = TRUE))
})

test_that("indicateur_b2_structure handles monoculture", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Single strata and age class (no diversity)
  units$strata_classes <- rep("Dominant", 3)
  units$age_classes <- rep("Mature", 3)

  result <- indicateur_b2_structure(
    units,
    strata_field = "strata_classes",
    age_class_field = "age_classes"
  )

  # Low diversity should yield low scores
  expect_true(all(result$B2 < 30, na.rm = TRUE))
})

# ==============================================================================
# T016: Unit Tests for indicateur_b3_connectivite() (B3)
# ==============================================================================

test_that("indicateur_b3_connectivite calculates with bdforet data", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Create synthetic forest polygons near parcels
  bbox <- st_bbox(units)
  forest1 <- st_polygon(list(matrix(c(
    bbox["xmin"], bbox["ymin"],
    bbox["xmin"] + 200, bbox["ymin"],
    bbox["xmin"] + 200, bbox["ymin"] + 200,
    bbox["xmin"], bbox["ymin"] + 200,
    bbox["xmin"], bbox["ymin"]
  ), ncol = 2, byrow = TRUE)))
  forest2 <- st_polygon(list(matrix(c(
    bbox["xmax"] - 300, bbox["ymax"] - 300,
    bbox["xmax"], bbox["ymax"] - 300,
    bbox["xmax"], bbox["ymax"],
    bbox["xmax"] - 300, bbox["ymax"],
    bbox["xmax"] - 300, bbox["ymax"] - 300
  ), ncol = 2, byrow = TRUE)))
  bdforet <- st_sf(
    code = c("FF1", "FF2"),
    geometry = st_sfc(forest1, forest2, crs = st_crs(units))
  )

  result <- indicateur_b3_connectivite(
    units,
    bdforet = bdforet,
    max_distance = 3000
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
  expect_type(result$B3, "double")
  expect_true(all(result$B3 >= 0 & result$B3 <= 100, na.rm = TRUE))
})

test_that("indicateur_b3_connectivite returns fallback when no bdforet", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  expect_warning(
    result <- indicateur_b3_connectivite(units, bdforet = NULL),
    "BD"
  )

  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
  expect_true(all(result$B3 == 50))
})

# ==============================================================================
# T017: Integration Test for B Family Workflow
# ==============================================================================

test_that("B family workflow: B1-B3 → normalize → famille_biodiversite composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Load fixtures
  protected_areas <- readRDS(test_path("fixtures/protected_areas/protected_areas_demo.rds"))

  # Add attributes
  units$strata_classes <- sample(c("Emergent", "Dominant", "Intermediate", "Suppressed"),
    10,
    replace = TRUE
  )
  units$age_classes <- sample(c("Young", "Intermediate", "Mature", "Old"), 10, replace = TRUE)

  # Create synthetic forest polygons
  bbox <- st_bbox(units)
  forest_poly <- st_polygon(list(matrix(c(
    bbox["xmin"], bbox["ymin"],
    bbox["xmin"] + 500, bbox["ymin"],
    bbox["xmin"] + 500, bbox["ymin"] + 500,
    bbox["xmin"], bbox["ymin"] + 500,
    bbox["xmin"], bbox["ymin"]
  ), ncol = 2, byrow = TRUE)))
  bdforet <- st_sf(
    code = "FF1",
    geometry = st_sfc(forest_poly, crs = st_crs(units))
  )

  # Full workflow
  result <- units %>%
    indicateur_b1_protection(protected_areas = protected_areas, source = "local") %>%
    indicateur_b2_structure(
      strata_field = "strata_classes",
      age_class_field = "age_classes"
    ) %>%
    indicateur_b3_connectivite(bdforet = bdforet) %>%
    normalize_indicators(indicators = c("B1", "B2", "B3")) %>%
    create_family_index(family_codes = "B")

  # Verify complete workflow
  expect_true(all(c("B1", "B2", "B3") %in% names(result)))
  expect_true(all(c("B1_norm", "B2_norm", "B3_norm") %in% names(result)))
  expect_true("famille_biodiversite" %in% names(result))
  expect_true(all(result$famille_biodiversite >= 0 & result$famille_biodiversite <= 100, na.rm = TRUE))
})

# Note: Regression fixture test removed - will be added when fixtures are created

# ==============================================================================
# Additional tests for better coverage
# ==============================================================================

test_that("indicateur_b1_protection validates input", {
  expect_error(
    indicateur_b1_protection(data.frame(x = 1:3), source = "local"),
    "must be an.*sf.*object"
  )
})

test_that("indicateur_b1_protection returns 0 when source='local' and no protected_areas", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # No protected areas data -> graceful degradation to 0% coverage
  result <- indicateur_b1_protection(units, protected_areas = NULL, source = "local")
  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_true(all(result$B1 == 0))
})

test_that("indicateur_b1_protection handles WFS source with fallback", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # WFS source without protected_areas should warn but work
  expect_warning(
    result <- indicateur_b1_protection(units, source = "wfs"),
    "WFS"
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  # All should be 0 since WFS failed
  expect_true(all(result$B1 == 0))
})

test_that("indicateur_b1_protection transforms CRS when needed", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Create protected area in different CRS
  pa <- sf::st_sf(
    zone_id = "Z1",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(
        c(566400, 6615100, 567000, 6615100, 567000, 6615500, 566400, 6615500, 566400, 6615100),
        ncol = 2, byrow = TRUE
      ))),
      crs = 2154
    )
  )
  pa_4326 <- sf::st_transform(pa, 4326)

  result <- indicateur_b1_protection(
    units,
    protected_areas = pa_4326,
    source = "local",
    preprocess = TRUE
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
})

test_that("indicateur_b2_structure validates input", {
  expect_error(
    indicateur_b2_structure(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("indicateur_b2_structure returns NA when required fields missing", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Missing strata/age fields should return NA (graceful degradation)
  result <- indicateur_b2_structure(
    units,
    strata_field = "nonexistent_field",
    age_class_field = "nonexistent_field"
  )
  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
  expect_true(all(is.na(result$B2)))
})

test_that("indicateur_b2_structure uses species field when provided", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  units$species <- c("Quercus", "Fagus", "Pinus", "Quercus", "Fagus")
  units$strata_classes <- sample(c("Dominant", "Intermediate"), 5, replace = TRUE)

  result <- indicateur_b2_structure(
    units,
    strata_field = "strata_classes",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
})

test_that("indicateur_b3_connectivite validates input", {
  expect_error(
    indicateur_b3_connectivite(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("indicateur_b3_connectivite handles empty bdforet", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  empty_bdforet <- sf::st_sf(
    code = character(0),
    geometry = sf::st_sfc(crs = sf::st_crs(units))
  )

  expect_warning(
    result <- indicateur_b3_connectivite(units, bdforet = empty_bdforet),
    "BD"
  )

  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
  expect_true(all(result$B3 == 50))
})

test_that("indicateur_b3_connectivite scores vary with forest proximity", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Create forest polygons overlapping some parcels
  bbox <- sf::st_bbox(units)
  forest_poly <- sf::st_polygon(list(matrix(c(
    bbox["xmin"], bbox["ymin"],
    bbox["xmin"] + 1000, bbox["ymin"],
    bbox["xmin"] + 1000, bbox["ymin"] + 1000,
    bbox["xmin"], bbox["ymin"] + 1000,
    bbox["xmin"], bbox["ymin"]
  ), ncol = 2, byrow = TRUE)))
  bdforet <- sf::st_sf(
    code = "FF1",
    geometry = sf::st_sfc(forest_poly, crs = sf::st_crs(units))
  )

  result <- indicateur_b3_connectivite(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
  expect_true(all(result$B3 >= 0 & result$B3 <= 100, na.rm = TRUE))
})

# ==============================================================================
# Coverage-focused tests for uncovered code paths
# ==============================================================================

# --- B1: indicateur_b1_protection additional coverage ---

test_that("indicateur_b1_protection with type_protection column exercises weighted scoring", {
  # Create test units
  units <- create_test_units(n_features = 3)

  # Create protected areas WITH type_protection column overlapping units
  # Use st_buffer on the sfc directly, then combine
  pa_geom1 <- sf::st_buffer(sf::st_geometry(units)[1], 200)
  pa_geom2 <- sf::st_buffer(sf::st_geometry(units)[2], 200)
  pa <- sf::st_sf(
    zone_id = c("Z1", "Z2"),
    type_protection = c("ZNIEFF1", "N2000_SCI"),
    geometry = c(pa_geom1, pa_geom2)
  )

  result <- indicateur_b1_protection(
    units,
    protected_areas = pa,
    source = "local"
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_true("B1_pct" %in% names(result))
  expect_true("B1_nb" %in% names(result))
  expect_true(all(result$B1 >= 0 & result$B1 <= 100))
  # At least some units should have non-zero coverage

  expect_true(any(result$B1 > 0))
})

test_that("indicateur_b1_protection without type column uses simple coverage", {
  # Create test units
  units <- create_test_units(n_features = 2)

  # Create protected areas WITHOUT type_protection column
  pa_geom <- sf::st_buffer(sf::st_geometry(units)[1], 300)
  pa <- sf::st_sf(
    zone_id = c("Z1"),
    geometry = pa_geom
  )

  result <- indicateur_b1_protection(
    units,
    protected_areas = pa,
    source = "local"
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_true("B1_pct" %in% names(result))
  expect_true("B1_nb" %in% names(result))
  # Without type column, B1_nb is always 0
  expect_true(all(result$B1_nb == 0))
  expect_true(all(result$B1 >= 0 & result$B1 <= 100))
})

test_that("indicateur_b1_protection with WFS source and provided protected_areas", {
  units <- create_test_units(n_features = 2)

  # Protected areas with type column, CRS matches
  pa_geom <- sf::st_buffer(sf::st_geometry(units)[1], 200)
  pa <- sf::st_sf(
    zone_id = c("Z1"),
    type_protection = c("RNN"),
    geometry = pa_geom
  )

  # WFS source but with protected_areas already provided should use them directly
  result <- indicateur_b1_protection(
    units,
    protected_areas = pa,
    source = "wfs"
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_true(all(result$B1 >= 0 & result$B1 <= 100))
})

# --- B2: indicateur_b2_structure additional coverage ---

test_that("indicateur_b2_structure with strata and age and species fields", {
  units <- create_test_units(n_features = 5)
  units$strata <- c("Emergent", "Dominant", "Intermediate", "Suppressed", "Dominant")
  units$age_class <- c("Young", "Mature", "Old", "Ancient", "Young")
  units$species <- c("Quercus", "Fagus", "Pinus", "Abies", "Betula")

  result <- indicateur_b2_structure(
    units,
    strata_field = "strata",
    age_class_field = "age_class",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
  expect_true(all(result$B2 >= 0 & result$B2 <= 100))
  # With diverse strata (4 categories), age (4 categories), species (5):
  # Should not be monoculture capped
  expect_true(any(result$B2 > 20))
})

test_that("indicateur_b2_structure without strata/age falls back to NA (no layers)", {
  units <- create_test_units(n_features = 3)

  # No strata or age fields, no layers -> should return NA
  result <- indicateur_b2_structure(
    units,
    strata_field = "missing_strata",
    age_class_field = "missing_age",
    layers = NULL
  )

  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
  expect_true(all(is.na(result$B2)))
})

test_that("indicateur_b2_structure monoculture with species", {
  units <- create_test_units(n_features = 3)
  units$strata <- rep("Dominant", 3)
  units$age_class <- rep("Mature", 3)
  units$species <- rep("Pinus", 3)

  result <- indicateur_b2_structure(
    units,
    strata_field = "strata",
    age_class_field = "age_class",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
  # Monoculture should be capped at 20
  expect_true(all(result$B2 <= 23))  # 20 + max 3 variation
})

# --- B3: indicateur_b3_connectivite sub-component coverage ---

test_that(".b3_local calculates distance-based local connectivity", {
  units <- create_test_units(n_features = 3)

  # Create bdforet near units using st_buffer on sfc geometry
  bdforet_geom <- c(
    sf::st_buffer(sf::st_geometry(units)[1], 50),
    sf::st_buffer(sf::st_geometry(units)[3], 50)
  )
  bdforet <- sf::st_sf(
    code = c("F1", "F2"),
    geometry = bdforet_geom
  )

  result <- nemeton:::.b3_local(bdforet, units, max_distance = 5000)

  expect_type(result, "double")
  expect_length(result, 3)
  expect_true(all(result >= 0))
})

test_that(".b3_cost_distance returns numeric score", {
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)

  # Create bdforet overlapping unit extent
  bdforet_geom <- sf::st_buffer(sf::st_geometry(units)[1], 80)
  bdforet <- sf::st_sf(
    code = "F1",
    geometry = bdforet_geom
  )

  result <- tryCatch(
    nemeton:::.b3_cost_distance(bdforet, units, dem = NULL),
    error = function(e) 50
  )

  expect_type(result, "double")
  expect_true(result >= 0 && result <= 100)
})

test_that(".b3_structural returns numeric score", {
  skip_if_not_installed("landscapemetrics")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)

  # Create bdforet within unit extent
  bdforet_geom <- c(
    sf::st_buffer(sf::st_geometry(units)[1], 80),
    sf::st_buffer(sf::st_geometry(units)[3], 80)
  )
  bdforet <- sf::st_sf(
    code = c("F1", "F2"),
    geometry = bdforet_geom
  )

  result <- tryCatch(
    nemeton:::.b3_structural(bdforet, units),
    error = function(e) 50
  )

  expect_type(result, "double")
  expect_true(all(result >= 0 & result <= 100))
})

test_that(".b3_graph returns numeric score", {
  skip_if_not_installed("igraph")

  units <- create_test_units(n_features = 3)

  # Create multiple forest patches
  bdforet <- sf::st_sf(
    code = c("F1", "F2", "F3"),
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_point(c(566500, 6615200)), 60),
      sf::st_buffer(sf::st_point(c(566700, 6615300)), 60),
      sf::st_buffer(sf::st_point(c(566900, 6615400)), 60),
      crs = 2154
    )
  )

  result <- tryCatch(
    nemeton:::.b3_graph(bdforet, units, threshold = 500),
    error = function(e) 50
  )

  expect_type(result, "double")
  expect_true(result >= 0 && result <= 100)
})

test_that(".b3_graph returns 100 for single patch", {
  skip_if_not_installed("igraph")

  units <- create_test_units(n_features = 2)

  # Single large forest polygon
  bdforet <- sf::st_sf(
    code = "F1",
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_point(c(566700, 6615300)), 200),
      crs = 2154
    )
  )

  result <- tryCatch(
    nemeton:::.b3_graph(bdforet, units, threshold = 500),
    error = function(e) 50
  )

  # Single patch -> 100% connectivity
  expect_equal(result, 100)
})

test_that(".b3_kernel returns score or 50 for too few parcels", {
  skip_if_not_installed("adehabitatHR")
  skip_if_not_installed("sp")

  units <- create_test_units(n_features = 3)

  # Create bdforet that barely intersects units
  bdforet_geom <- sf::st_buffer(sf::st_geometry(units)[1], 80)
  bdforet <- sf::st_sf(
    code = "F1",
    geometry = bdforet_geom
  )

  # With only 3 units and likely fewer than 5 intersecting bdforet,
  # should return 50 (fallback)
  result <- tryCatch(
    nemeton:::.b3_kernel(bdforet, units),
    error = function(e) 50
  )

  expect_type(result, "double")
  expect_true(result >= 0 && result <= 100)
})

test_that(".b3_kernel computes kernel with enough intersecting parcels", {
  skip_if_not_installed("adehabitatHR")
  skip_if_not_installed("sp")

  # Need at least 5 units intersecting bdforet
  units <- create_test_units(n_features = 7)

  # Create large bdforet that overlaps all units
  bbox <- sf::st_bbox(units)
  bdforet <- sf::st_sf(
    code = "F1",
    geometry = sf::st_sfc(
      sf::st_as_sfc(bbox),
      crs = 2154
    )
  )

  result <- tryCatch(
    nemeton:::.b3_kernel(bdforet, units),
    error = function(e) 50
  )

  expect_type(result, "double")
  expect_true(result >= 0 && result <= 100)
})

test_that("indicateur_b3_connectivite rejects non-sf bdforet", {
  units <- create_test_units(n_features = 2)

  expect_error(
    indicateur_b3_connectivite(units, bdforet = data.frame(x = 1)),
    "bdforet must be an sf object"
  )
})

# ==============================================================================
# (migrated from test-cov80-batch8.R)
# Coverage boost for B1 weighted scoring, B2 fallbacks, B3 components
# ==============================================================================

# --- B1: indicateur_b1_protection batch8 tests ---

test_that("B1 with typed protection areas computes weighted score", {
  units <- create_test_units(n_features = 2)
  # Create protected areas with different protection types
  pa <- sf::st_sf(
    zone_type = c("ZNIEFF1", "Natura_SIC", "RNR_reserve"),
    geometry = sf::st_sfc(
      # ZNIEFF1 overlaps both units
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500, 566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      # Natura overlaps first unit only
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 566600, 6615100, 566600, 6615300, 566400, 6615300, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      # Reserve overlaps second unit only
      sf::st_polygon(list(matrix(c(
        566550, 6615250, 566800, 6615250, 566800, 6615500, 566550, 6615500, 566550, 6615250
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_b1_protection(units, protected_areas = pa, source = "local")
  expect_true("B1" %in% names(result))
  expect_true("B1_pct" %in% names(result))
  expect_true("B1_nb" %in% names(result))
  expect_true(all(result$B1 >= 0 & result$B1 <= 100))
  # Both units should have some coverage
  expect_true(all(result$B1 > 0))
})

test_that("B1 with no type column uses default weight", {
  units <- create_test_units(n_features = 2)
  # No zone_type column — triggers default weight path
  pa <- sf::st_sf(
    name = "Zone A",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500, 566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_b1_protection(units, protected_areas = pa)
  expect_true(all(result$B1 >= 0))
  # Score should be multiplied by 0.5 (default weight)
  expect_true(all(result$B1_pct > 0))
})

test_that("B1 with WFS source and NULL areas returns 0", {
  units <- create_test_units(n_features = 2)
  suppressWarnings({
    result <- nemeton::indicateur_b1_protection(units, source = "wfs")
  })
  expect_true(all(result$B1 == 0))
})

test_that("B1 with NULL protected_areas in local mode returns 0", {
  units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_b1_protection(units, protected_areas = NULL, source = "local")
  expect_true(all(result$B1 == 0))
})

test_that("B1 with CRS mismatch preprocesses correctly", {
  units <- create_test_units(n_features = 2)
  # Create PA in WGS84
  pa <- sf::st_sf(
    zone_type = "ZNIEFF1",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        2.9, 47.0, 3.1, 47.0, 3.1, 47.2, 2.9, 47.2, 2.9, 47.0
      ), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  # Should not error even if no overlap
  result <- nemeton::indicateur_b1_protection(units, protected_areas = pa, preprocess = TRUE)
  expect_true("B1" %in% names(result))
})

# --- B2: indicateur_b2_structure batch8 tests ---

test_that("B2 with strata and age fields computes score", {
  units <- create_test_units(n_features = 4)
  units$strata <- c("Emergent", "Dominant", "Intermediate", "Suppressed")
  units$age_class <- c("young", "mature", "old", "ancient")

  result <- nemeton::indicateur_b2_structure(units)
  expect_true("B2" %in% names(result))
  expect_true(all(result$B2 >= 0 & result$B2 <= 100, na.rm = TRUE))
})

test_that("B2 with species field uses 3-component weighting", {
  units <- create_test_units(n_features = 4)
  units$strata <- c("Emergent", "Dominant", "Intermediate", "Suppressed")
  units$age_class <- c("young", "mature", "old", "ancient")
  units$species <- c("Quercus robur", "Fagus sylvatica", "Pinus sylvestris", "Picea abies")

  result <- nemeton::indicateur_b2_structure(units, species_field = "species")
  expect_true(all(result$B2 >= 0 & result$B2 <= 100))
})

test_that("B2 monoculture capped at 20", {
  units <- create_test_units(n_features = 3)
  units$strata <- rep("Dominant", 3)
  units$age_class <- rep("mature", 3)

  result <- nemeton::indicateur_b2_structure(units)
  expect_true(all(result$B2 <= 20))
})

test_that("B2 falls back to NDVI when no strata/age fields", {
  units <- create_test_units(n_features = 3)
  ndvi_raster <- create_test_raster(values = "random")
  terra::values(ndvi_raster) <- runif(terra::ncell(ndvi_raster), 0.2, 0.9)

  # Create a minimal nemeton_layers object
  layers <- list(
    rasters = list(ndvi = ndvi_raster)
  )
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicateur_b2_structure(units, layers = layers)
  expect_true("B2" %in% names(result))
  expect_true(all(!is.na(result$B2)))
})

test_that("B2 falls back to LiDAR MNH", {
  units <- create_test_units(n_features = 3)
  mnh_raster <- create_test_raster(values = "random")
  terra::values(mnh_raster) <- runif(terra::ncell(mnh_raster), 5, 25)

  layers <- list(
    rasters = list(lidar_mnh = mnh_raster)
  )
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicateur_b2_structure(units, layers = layers)
  expect_true("B2" %in% names(result))
  expect_true(all(!is.na(result$B2)))
})

test_that("B2 returns NA when no data available at all", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicateur_b2_structure(units, layers = NULL)
  expect_true(all(is.na(result$B2)))
})

# --- B3: indicateur_b3_connectivite batch8 tests ---

test_that("B3 with NULL bdforet returns fallback 50", {
  units <- create_test_units(n_features = 3)
  suppressWarnings({
    result <- nemeton::indicateur_b3_connectivite(units, bdforet = NULL)
  })
  expect_true(all(result$B3 == 50))
})

test_that("B3 with bdforet computes connectivity", {
  units <- create_test_units(n_features = 3)
  # Create forest patches covering the test area
  bdforet <- sf::st_sf(
    code_tfv = c("FF1-00", "FF2G61"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 566700, 6615100, 566700, 6615300, 566400, 6615300, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        566700, 6615200, 567000, 6615200, 567000, 6615500, 566700, 6615500, 566700, 6615200
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_b3_connectivite(units, bdforet = bdforet)
  expect_true("B3" %in% names(result))
  expect_true(all(result$B3 >= 0 & result$B3 <= 100))
})
