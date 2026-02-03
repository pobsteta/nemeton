# test-indicators-biodiversity.R
# Unit and integration tests for Biodiversity Family (B) Indicators
# MVP v0.3.0 - Following TDD: Tests written BEFORE implementation

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T014: Unit Tests for indicator_biodiversity_protection() (B1)
# ==============================================================================

test_that("indicator_biodiversity_protection calculates overlap correctly", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Load test fixture
  protected_areas <- readRDS(test_path("fixtures/protected_areas/protected_areas_demo.rds"))

  # Calculate B1 with local data
  result <- indicator_biodiversity_protection(
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

test_that("indicator_biodiversity_protection handles missing data gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Empty protected areas
  empty_pa <- st_sf(
    zone_id = character(0),
    geometry = st_sfc(crs = st_crs(units))
  )

  result <- indicator_biodiversity_protection(units, protected_areas = empty_pa, source = "local")

  # Should return 0% protection for all parcels
  expect_true(all(result$B1 == 0, na.rm = TRUE))
})

# ==============================================================================
# T015: Unit Tests for indicator_biodiversity_structure() (B2)
# ==============================================================================

test_that("indicator_biodiversity_structure calculates Shannon diversity", {
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

  result <- indicator_biodiversity_structure(
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

test_that("indicator_biodiversity_structure handles monoculture", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Single strata and age class (no diversity)
  units$strata_classes <- rep("Dominant", 3)
  units$age_classes <- rep("Mature", 3)

  result <- indicator_biodiversity_structure(
    units,
    strata_field = "strata_classes",
    age_class_field = "age_classes"
  )

  # Low diversity should yield low scores
  expect_true(all(result$B2 < 30, na.rm = TRUE))
})

# ==============================================================================
# T016: Unit Tests for indicator_biodiversity_connectivity() (B3)
# ==============================================================================

test_that("indicator_biodiversity_connectivity calculates distances correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Create synthetic corridor (line through center)
  bbox <- st_bbox(units)
  corridor <- st_sf(
    corridor_id = "TVB_001",
    geometry = st_sfc(
      st_linestring(cbind(
        c(bbox["xmin"], bbox["xmax"]),
        c((bbox["ymin"] + bbox["ymax"]) / 2, (bbox["ymin"] + bbox["ymax"]) / 2)
      )),
      crs = st_crs(units)
    )
  )

  result <- indicator_biodiversity_connectivity(
    units,
    corridors = corridor,
    distance_method = "edge",
    max_distance = 3000
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
  expect_type(result$B3, "double")
  expect_true(all(result$B3 >= 0, na.rm = TRUE))
})

test_that("indicator_biodiversity_connectivity handles max_distance cap", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Corridor far away
  far_corridor <- st_sf(
    corridor_id = "TVB_FAR",
    geometry = st_sfc(
      st_point(c(800000, 6600000)), # Very far from units
      crs = st_crs(units)
    )
  )

  result <- indicator_biodiversity_connectivity(
    units,
    corridors = far_corridor,
    max_distance = 5000
  )

  # Distances beyond max should be capped
  expect_true(all(result$B3 >= 5000, na.rm = TRUE) || all(is.na(result$B3)))
})

# ==============================================================================
# T017: Integration Test for B Family Workflow
# ==============================================================================

test_that("B family workflow: B1-B3 → normalize → family_B composite", {
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

  # Create corridor
  bbox <- st_bbox(units)
  corridor <- st_sf(
    corridor_id = "TVB",
    geometry = st_sfc(
      st_point(c(
        mean(c(bbox["xmin"], bbox["xmax"])),
        mean(c(bbox["ymin"], bbox["ymax"]))
      )),
      crs = st_crs(units)
    )
  )

  # Full workflow
  result <- units %>%
    indicator_biodiversity_protection(protected_areas = protected_areas, source = "local") %>%
    indicator_biodiversity_structure(
      strata_field = "strata_classes",
      age_class_field = "age_classes"
    ) %>%
    indicator_biodiversity_connectivity(corridors = corridor) %>%
    normalize_indicators(indicators = c("B1", "B2", "B3")) %>%
    create_family_index(family_codes = "B")

  # Verify complete workflow
  expect_true(all(c("B1", "B2", "B3") %in% names(result)))
  expect_true(all(c("B1_norm", "B2_norm", "B3_norm") %in% names(result)))
  expect_true("family_B" %in% names(result))
  expect_true(all(result$family_B >= 0 & result$family_B <= 100, na.rm = TRUE))
})

# Note: Regression fixture test removed - will be added when fixtures are created

# ==============================================================================
# Additional tests for better coverage
# ==============================================================================

test_that("indicator_biodiversity_protection validates input", {
  expect_error(
    indicator_biodiversity_protection(data.frame(x = 1:3), source = "local"),
    "must be an.*sf.*object"
  )
})

test_that("indicator_biodiversity_protection returns 0 when source='local' and no protected_areas", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # No protected areas data -> graceful degradation to 0% coverage
  result <- indicator_biodiversity_protection(units, protected_areas = NULL, source = "local")
  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_true(all(result$B1 == 0))
})

test_that("indicator_biodiversity_protection handles WFS source with fallback", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # WFS source without protected_areas should warn but work
  expect_warning(
    result <- indicator_biodiversity_protection(units, source = "wfs"),
    "WFS"
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  # All should be 0 since WFS failed
  expect_true(all(result$B1 == 0))
})

test_that("indicator_biodiversity_protection transforms CRS when needed", {
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

  result <- indicator_biodiversity_protection(
    units,
    protected_areas = pa_4326,
    source = "local",
    preprocess = TRUE
  )

  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
})

test_that("indicator_biodiversity_structure validates input", {
  expect_error(
    indicator_biodiversity_structure(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("indicator_biodiversity_structure returns NA when required fields missing", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Missing strata/age fields should return NA (graceful degradation)
  result <- indicator_biodiversity_structure(
    units,
    strata_field = "nonexistent_field",
    age_class_field = "nonexistent_field"
  )
  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
  expect_true(all(is.na(result$B2)))
})

test_that("indicator_biodiversity_structure uses species field when provided", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  units$species <- c("Quercus", "Fagus", "Pinus", "Quercus", "Fagus")
  units$strata_classes <- sample(c("Dominant", "Intermediate"), 5, replace = TRUE)

  result <- indicator_biodiversity_structure(
    units,
    strata_field = "strata_classes",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
})

test_that("indicator_biodiversity_connectivity validates input", {
  expect_error(
    indicator_biodiversity_connectivity(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("indicator_biodiversity_connectivity handles empty corridors", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  empty_corridors <- sf::st_sf(
    corridor_id = character(0),
    geometry = sf::st_sfc(crs = sf::st_crs(units))
  )

  result <- indicator_biodiversity_connectivity(
    units,
    corridors = empty_corridors
  )

  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
})

test_that("indicator_biodiversity_connectivity uses centroid method", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Create corridor
  bbox <- sf::st_bbox(units)
  corridor <- sf::st_sf(
    corridor_id = "C1",
    geometry = sf::st_sfc(
      sf::st_point(c(mean(c(bbox["xmin"], bbox["xmax"])), mean(c(bbox["ymin"], bbox["ymax"])))),
      crs = sf::st_crs(units)
    )
  )

  result <- indicator_biodiversity_connectivity(
    units,
    corridors = corridor,
    distance_method = "centroid"
  )

  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
})
