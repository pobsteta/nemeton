# test-indicators-risk.R
# Unit and integration tests for Risk & Resilience Family (R) Indicators
# MVP v0.3.0 - Following TDD: Tests written BEFORE implementation

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T026: Unit Tests for indicator_risk_fire() (R1)
# ==============================================================================

test_that("indicator_risk_fire calculates composite risk correctly", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add species attribute
  units$species <- sample(c("Pinus", "Quercus", "Fagus"), 5, replace = TRUE)

  # Load test fixtures
  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))
  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  # Calculate R1
  result <- indicator_risk_fire(
    units,
    dem = dem,
    species_field = "species",
    climate = climate,
    weights = c(slope = 1 / 3, species = 1 / 3, climate = 1 / 3)
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_type(result$R1, "double")
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))

  # Pinus (high flammability) on steep slopes should have high R1
  pine_parcels <- which(result$species == "Pinus")
  if (length(pine_parcels) > 0) {
    expect_true(any(result$R1[pine_parcels] > 40, na.rm = TRUE))
  }
})

test_that("indicator_risk_fire handles missing climate data gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]
  units$species <- rep("Quercus", 3)

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  # Without climate data (should use slope + species only)
  result <- indicator_risk_fire(units, dem = dem, species_field = "species", climate = NULL)

  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T027: Unit Tests for indicator_risk_storm() (R2)
# ==============================================================================

test_that("indicator_risk_storm calculates vulnerability correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add stand attributes
  units$height <- runif(5, 10, 35) # meters
  units$density <- runif(5, 0.5, 1.0) # 0-1 scale

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  result <- indicator_risk_storm(
    units,
    dem = dem,
    height_field = "height",
    density_field = "density",
    weights = c(height = 1 / 3, density = 1 / 3, exposure = 1 / 3)
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_type(result$R2, "double")
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))

  # Tall dense stands should have higher vulnerability
  tall_dense <- which(units$height > 25 & units$density > 0.8)
  short_sparse <- which(units$height < 15 & units$density < 0.6)

  if (length(tall_dense) > 0 && length(short_sparse) > 0) {
    expect_true(mean(result$R2[tall_dense]) > mean(result$R2[short_sparse]))
  }
})

test_that("indicator_risk_storm handles missing attributes with defaults", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  # Remove height and density columns - should use default neutral values
  units_no_height <- units
  units_no_height$height <- NULL
  units_no_height$density <- NULL

  result <- indicator_risk_storm(units_no_height, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T028: Unit Tests for indicator_risk_drought() (R3)
# ==============================================================================

test_that("indicator_risk_drought calculates stress correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add TWI (reuse from W3) and species
  units$W3 <- runif(5, 5, 15) # TWI values
  units$species <- sample(c("Fagus", "Quercus", "Pinus"), 5, replace = TRUE)

  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  result <- indicator_risk_drought(
    units,
    twi_field = "W3",
    climate = climate,
    species_field = "species",
    weights = c(twi = 0.4, precip = 0.4, species = 0.2)
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_type(result$R3, "double")
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))

  # Low TWI (dry sites) + sensitive species should have high R3
  fagus_parcels <- which(units$species == "Fagus") # Fagus is drought-sensitive
  if (length(fagus_parcels) > 0) {
    fagus_low_twi <- fagus_parcels[units$W3[fagus_parcels] < 10]
    if (length(fagus_low_twi) > 0) {
      expect_true(any(result$R3[fagus_low_twi] > 40, na.rm = TRUE))
    }
  }
})

test_that("indicator_risk_drought reuses W3 TWI correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Pre-computed W3 from v0.2.0
  units$W3 <- c(8, 12, 15)
  units$species <- rep("Quercus", 3)

  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  result <- indicator_risk_drought(units, twi_field = "W3", climate = climate, species_field = "species")

  # Inverse TWI component: low TWI = high drought stress
  expect_true(all(!is.na(result$R3)))
  expect_true(result$R3[1] > result$R3[3]) # TWI=8 should have higher R3 than TWI=15
})

# ==============================================================================
# T029: Integration Test for R Family Workflow
# ==============================================================================

test_that("R family workflow: R1-R3 → normalize → family_R composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Add attributes
  units$species <- sample(c("Pinus", "Quercus", "Fagus"), 10, replace = TRUE)
  units$height <- runif(10, 10, 30)
  units$density <- runif(10, 0.5, 0.9)
  units$W3 <- runif(10, 5, 15)

  # Load fixtures
  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))
  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  # Full workflow
  result <- units %>%
    indicator_risk_fire(dem = dem, species_field = "species", climate = climate) %>%
    indicator_risk_storm(dem = dem, height_field = "height", density_field = "density") %>%
    indicator_risk_drought(twi_field = "W3", climate = climate, species_field = "species") %>%
    normalize_indicators(indicators = c("R1", "R2", "R3")) %>%
    create_family_index(family_codes = "R")

  # Verify complete workflow
  expect_true(all(c("R1", "R2", "R3") %in% names(result)))
  expect_true(all(c("R1_norm", "R2_norm", "R3_norm") %in% names(result)))
  expect_true("family_R" %in% names(result))
  expect_true(all(result$family_R >= 0 & result$family_R <= 100, na.rm = TRUE))
})

# Note: Regression fixture test removed - will be added when fixtures are created

# ==============================================================================
# T030: Unit Tests for indicator_risk_browsing() (R4)
# ==============================================================================

test_that("indicator_risk_browsing calculates composite risk correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add required attributes
  units$species <- sample(c("Quercus", "Fagus", "Pinus", "Abies"), 5, replace = TRUE)
  units$height <- c(2, 5, 10, 15, 25)  # Various heights

  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    height_field = "height"
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  expect_true("R4_vulnerability" %in% names(result))
  expect_type(result$R4, "double")
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_browsing uses height for vulnerability", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  units$species <- rep("Quercus", 3)
  units$height <- c(1, 5, 15)  # Very short, medium, tall

  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    height_field = "height"
  )

  # Short stand (1m) should have highest vulnerability
  expect_true(result$R4_vulnerability[1] > result$R4_vulnerability[2])
  expect_true(result$R4_vulnerability[2] > result$R4_vulnerability[3])
})

test_that("indicator_risk_browsing uses age when height not available", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  units$species <- rep("Fagus", 3)
  units$age <- c(5, 20, 50)  # Young, medium, old

  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    age_field = "age"
  )

  # Young stand (5 years) should have highest vulnerability
  expect_true(result$R4_vulnerability[1] > result$R4_vulnerability[2])
  expect_true(result$R4_vulnerability[2] > result$R4_vulnerability[3])
})

test_that("indicator_risk_browsing calculates palatability correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:4, ]

  units$species <- c("Quercus", "Fagus", "Pinus", "Picea")
  units$height <- rep(10, 4)

  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    height_field = "height"
  )

  # Quercus (oak) should have highest palatability
  expect_true(result$R4_palatability[1] > result$R4_palatability[3])  # Oak > Pine

  # Picea (spruce) should have lowest palatability
  expect_true(result$R4_palatability[4] < result$R4_palatability[1])  # Spruce < Oak
})

test_that("indicator_risk_browsing handles missing species field gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Missing species field -> uses default moderate palatability
  result <- indicator_risk_browsing(units, species_field = "nonexistent_column")
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicator_risk_browsing uses custom weights", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  units$species <- rep("Quercus", 3)
  units$height <- c(2, 5, 10)

  # Use only palatability (weight = 1, others = 0)
  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    height_field = "height",
    weights = c(palatability = 1, vulnerability = 0, edge = 0, density = 0)
  )

  # All parcels should have same R4 (same species, same palatability)
  expect_true(max(result$R4) - min(result$R4) < 5)  # Close to identical
})

test_that("indicator_risk_browsing calculates edge exposure", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  units$species <- rep("Fagus", 3)

  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    edge_buffer = 50
  )

  # Edge factor should be calculated (part of R4)
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicator_risk_browsing uses game density raster when provided", {
  # Use test units that match raster extent
  units <- create_test_units(n_features = 3)
  units$species <- rep("Quercus", 3)
  units$height <- rep(10, 3)

  # Create mock game density raster matching the test units extent
  game_raster <- create_test_raster(values = "random")

  result <- indicator_risk_browsing(
    units,
    species_field = "species",
    height_field = "height",
    game_density = game_raster
  )

  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_browsing handles default vulnerability when no height/age", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  units$species <- rep("Fagus", 3)
  # No height or age field

  result <- indicator_risk_browsing(
    units,
    species_field = "species"
  )

  # Should use default moderate vulnerability (50)
  expect_true(all(result$R4_vulnerability == 50))
})

# ==============================================================================
# Additional edge case tests for R family
# ==============================================================================

test_that("indicator_risk_fire handles units outside raster extent gracefully", {
  # Create units outside the standard test raster extent
  offset_units <- create_test_units(n_features = 2)
  sf::st_geometry(offset_units) <- sf::st_geometry(offset_units) + c(10000, 10000)
  sf::st_crs(offset_units) <- 2154

  offset_units$species <- c("Pinus", "Fagus")

  dem <- create_test_raster()

  # Should still work but may have NA values for slope
  result <- indicator_risk_fire(
    offset_units,
    dem = dem,
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
})

test_that("R indicators validate sf input", {
  expect_error(
    indicator_risk_fire(data.frame(x = 1:3), dem = create_test_raster()),
    "must be an.*sf.*object"
  )

  expect_error(
    indicator_risk_storm(data.frame(x = 1:3), dem = create_test_raster()),
    "must be an.*sf.*object"
  )

  expect_error(
    indicator_risk_drought(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )

  expect_error(
    indicator_risk_browsing(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})
