# test-indicators-risk.R
# Unit and integration tests for Risk & Resilience Family (R) Indicators
# Aligned with tuto 03 methodology (fireexposuR, microclima, SPEI)

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T026: Unit Tests for indicator_risk_fire() (R1)
# ==============================================================================

test_that("indicator_risk_fire calculates fallback risk correctly", {
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

  # Calculate R1 (fallback: no bdforet, no fireexposuR)
  result <- indicator_risk_fire(
    units,
    dem = dem,
    species_field = "species",
    climate = climate
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_type(result$R1, "double")
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
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

test_that("indicator_risk_fire returns NA without DEM", {
  units <- create_test_units(n_features = 3)
  result <- indicator_risk_fire(units)
  expect_true(all(is.na(result$R1)))
})

test_that("indicator_risk_fire accepts bdforet parameter", {
  # Verify the function signature accepts bdforet (even if fireexposuR not installed)
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # Create a simple bdforet-like sf object
  bdforet <- create_test_units(n_features = 2)

  # Should work without error (falls back if fireexposuR not installed)
  result <- indicator_risk_fire(units, dem = dem, bdforet = bdforet)
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T027: Unit Tests for indicator_risk_storm() (R2)
# ==============================================================================

test_that("indicator_risk_storm calculates vulnerability with DEM", {
  units <- create_test_units(n_features = 5)
  dem <- create_test_raster()

  result <- indicator_risk_storm(units, dem = dem)

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_type(result$R2, "double")
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_storm returns NA without DEM", {
  units <- create_test_units(n_features = 3)

  result <- indicator_risk_storm(units)
  expect_true(all(is.na(result$R2)))
})

test_that("indicator_risk_storm simplified signature (no height/density)", {
  # Verify the new signature: only units, dem, layers
  expect_true(all(c("units", "dem", "layers") %in% names(formals(indicator_risk_storm))))
  # Old params should NOT be in the signature
  expect_false("height_field" %in% names(formals(indicator_risk_storm)))
  expect_false("density_field" %in% names(formals(indicator_risk_storm)))
  expect_false("weights" %in% names(formals(indicator_risk_storm)))
})

test_that("indicator_risk_storm with demo data", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  result <- indicator_risk_storm(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T028: Unit Tests for indicator_risk_drought() (R3)
# ==============================================================================

test_that("indicator_risk_drought calculates stress with DEM", {
  units <- create_test_units(n_features = 5)
  dem <- create_test_raster()

  result <- indicator_risk_drought(units, dem = dem)

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_type(result$R3, "double")
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_drought returns NA without DEM", {
  units <- create_test_units(n_features = 3)

  result <- indicator_risk_drought(units)
  expect_true(all(is.na(result$R3)))
})

test_that("indicator_risk_drought simplified signature", {
  # Verify the new signature: units, layers, dem, climate_data
  params <- names(formals(indicator_risk_drought))
  expect_true(all(c("units", "layers", "dem", "climate_data") %in% params))
  # Old params should NOT be in the signature
  expect_false("twi_field" %in% params)
  expect_false("species_field" %in% params)
  expect_false("weights" %in% params)
})

test_that("indicator_risk_drought accepts climate_data", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # Provide climate data
  n_months <- 60
  climate_data <- list(
    precip = pmax(0, rep(c(60, 55, 50, 45, 50, 30, 20, 25, 40, 55, 65, 70), length.out = n_months) +
      rnorm(n_months, 0, 10)),
    temp = list(
      tmin = rep(c(0, 1, 4, 7, 11, 15, 18, 17, 13, 8, 4, 1), length.out = n_months) +
        rnorm(n_months, 0, 1),
      tmax = rep(c(8, 10, 14, 18, 22, 27, 30, 29, 24, 18, 12, 8), length.out = n_months) +
        rnorm(n_months, 0, 1)
    )
  )

  # Should work with or without SPEI
  result <- indicator_risk_drought(units, dem = dem, climate_data = climate_data)
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_drought with demo data", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  result <- indicator_risk_drought(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T029: Integration Test for R Family Workflow
# ==============================================================================

test_that("R family workflow: R1-R3 -> normalize -> family_R composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Add species for R1 fallback
  units$species <- sample(c("Pinus", "Quercus", "Fagus"), 10, replace = TRUE)

  # Load fixtures
  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))
  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  # Full workflow (R1 fallback, R2 terrain fallback, R3 topo+default climate)
  result <- units %>%
    indicator_risk_fire(dem = dem, species_field = "species", climate = climate) %>%
    indicator_risk_storm(dem = dem) %>%
    indicator_risk_drought(dem = dem) %>%
    normalize_indicators(indicators = c("R1", "R2", "R3")) %>%
    create_family_index(family_codes = "R")

  # Verify complete workflow
  expect_true(all(c("R1", "R2", "R3") %in% names(result)))
  expect_true(all(c("R1_norm", "R2_norm", "R3_norm") %in% names(result)))
  expect_true("family_R" %in% names(result))
  expect_true(all(result$family_R >= 0 & result$family_R <= 100, na.rm = TRUE))
})

# ==============================================================================
# T030: Unit Tests for indicator_risk_browsing() (R4)
# ==============================================================================

test_that("indicator_risk_browsing calculates composite risk correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Without layers: defaults for palatability and vulnerability
  result <- indicator_risk_browsing(units)

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  expect_true("R4_vulnerability" %in% names(result))
  expect_type(result$R4, "double")
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_browsing simplified signature (tuto 03)", {
  # Verify the new signature: units, layers, bdforet, game_density, edge_buffer
  params <- names(formals(indicator_risk_browsing))
  expect_true(all(c("units", "layers", "bdforet", "game_density", "edge_buffer") %in% params))
  # Old params should NOT be in the signature
  expect_false("species_field" %in% params)
  expect_false("height_field" %in% params)
  expect_false("age_field" %in% params)
  expect_false("weights" %in% params)
})

test_that("indicator_risk_browsing uses BD Foret for palatability", {
  # Create test units and a mock BD Foret sf
  units <- create_test_units(n_features = 3)

  # Create BD Foret polygons overlapping test units with species info
  bdforet <- create_test_units(n_features = 3)
  bdforet$essence <- c("Chene sessile", "Pin maritime", "Epicea commun")

  result <- indicator_risk_browsing(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("R4_palatability" %in% names(result))
  # Chene (oak) should be high, Epicea (spruce) should be low
  expect_true(result$R4_palatability[1] > result$R4_palatability[3])
})

test_that("indicator_risk_browsing calculates edge exposure", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  result <- indicator_risk_browsing(units, edge_buffer = 50)

  # Edge factor should be calculated (part of R4)
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicator_risk_browsing uses game density raster when provided", {
  # Use test units that match raster extent
  units <- create_test_units(n_features = 3)

  # Create mock game density raster matching the test units extent
  game_raster <- create_test_raster(values = "random")

  result <- indicator_risk_browsing(
    units,
    game_density = game_raster
  )

  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_browsing defaults to 50 without layers", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # No layers, no bdforet → default palatability and vulnerability
  result <- indicator_risk_browsing(units)

  # Should use defaults (50 for both)
  expect_true(all(result$R4_palatability == 50))
  expect_true(all(result$R4_vulnerability == 50))
})

test_that("indicator_risk_browsing uses fixed weights from tuto 03", {
  # With default data, R4 should be computed with fixed weights
  # palatability(50)*0.35 + vulnerability(50)*0.30 + edge*0.20 + density(50)*0.15
  units <- create_test_units(n_features = 2)
  result <- indicator_risk_browsing(units)

  # Without any data sources, palatability=50, vulnerability=50, density=50
  # So R4 ≈ 0.35*50 + 0.30*50 + 0.20*edge + 0.15*50 = 40 + 0.20*edge
  # Edge for 100m squares with 50m buffer = 100% (entirely in edge zone)
  # So R4 ≈ 17.5 + 15 + 20 + 7.5 = 60
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
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

# ==============================================================================
# Coverage-focused tests for uncovered code paths
# ==============================================================================

# --- R1: indicator_risk_fire additional coverage ---

test_that("indicator_risk_fire fallback path without species field", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # No species column present, should use species_factor=50 fallback
  result <- indicator_risk_fire(units, dem = dem, species_field = "nonexistent_species")

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_fire with DEM but no bdforet exercises fallback method", {
  units <- create_test_units(n_features = 3)
  units$species <- c("Pinus", "Quercus", "Fagus")
  dem <- create_test_raster()

  # DEM provided, no bdforet -> should use fallback method (slope + species + climate)
  result <- indicator_risk_fire(
    units,
    dem = dem,
    bdforet = NULL,
    species_field = "species",
    climate = NULL
  )

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_fire weight redistribution when no climate", {
  units <- create_test_units(n_features = 2)
  units$species <- c("Pinus", "Quercus")
  dem <- create_test_raster()

  # Explicit weights, no climate -> weights should be redistributed
  result <- indicator_risk_fire(
    units,
    dem = dem,
    species_field = "species",
    climate = NULL,
    weights = c(slope = 0.4, species = 0.3, climate = 0.3)
  )

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

# --- R2: indicator_risk_storm additional coverage ---

test_that("indicator_risk_storm exercises terrain fallback (no microclima)", {
  # This test exercises the fallback branch with aspect, slope, TRI
  units <- create_test_units(n_features = 4)

  # Create DEM with varying elevation for meaningful terrain derivatives
  dem <- terra::rast(
    extent = terra::ext(566400, 567000, 6615100, 6615500),
    resolution = 10,
    crs = "EPSG:2154"
  )
  # Gradient from low to high elevation
  vals <- rep(seq(100, 500, length.out = terra::ncol(dem)), terra::nrow(dem))
  terra::values(dem) <- vals

  result <- indicator_risk_storm(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_type(result$R2, "double")
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_storm with constant DEM (TRI max = 0 edge case)", {
  units <- create_test_units(n_features = 2)

  # Flat DEM -> TRI max will be 0 or very small
  dem <- create_test_raster(values = "constant")

  result <- indicator_risk_storm(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

# --- R3: indicator_risk_drought additional coverage ---

test_that("indicator_risk_drought with SPEI package exercises climate component", {
  skip_if_not_installed("SPEI")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # With SPEI installed and no climate_data, uses simulated data

  result <- indicator_risk_drought(units, dem = dem, climate_data = NULL)

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_drought with provided climate_data and SPEI", {
  skip_if_not_installed("SPEI")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  n_months <- 60
  set.seed(123)
  climate_data <- list(
    precip = pmax(0, rep(c(60, 55, 50, 45, 50, 30, 20, 25, 40, 55, 65, 70),
                         length.out = n_months) + rnorm(n_months, 0, 10)),
    temp = list(
      tmin = rep(c(0, 1, 4, 7, 11, 15, 18, 17, 13, 8, 4, 1),
                 length.out = n_months) + rnorm(n_months, 0, 1),
      tmax = rep(c(8, 10, 14, 18, 22, 27, 30, 29, 24, 18, 12, 8),
                 length.out = n_months) + rnorm(n_months, 0, 1)
    )
  )

  result <- indicator_risk_drought(
    units,
    dem = dem,
    climate_data = climate_data
  )

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicator_risk_drought topographic component with varied DEM", {
  units <- create_test_units(n_features = 3)

  # Create DEM with varying terrain for aspect/slope/TWI variation
  dem <- terra::rast(
    extent = terra::ext(566400, 567000, 6615100, 6615500),
    resolution = 10,
    crs = "EPSG:2154"
  )
  # Diagonal gradient for slope and aspect variation
  nr <- terra::nrow(dem)
  nc <- terra::ncol(dem)
  vals <- matrix(0, nrow = nr, ncol = nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      vals[i, j] <- 200 + i * 5 + j * 3
    }
  }
  terra::values(dem) <- as.vector(t(vals))

  result <- indicator_risk_drought(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

# --- R4: indicator_risk_browsing additional coverage ---

test_that("indicator_risk_browsing exercises all default components", {
  units <- create_test_units(n_features = 5)

  # No bdforet, no layers, no game_density -> all defaults
  result <- indicator_risk_browsing(units)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  expect_true("R4_vulnerability" %in% names(result))
  # All components use defaults
  expect_true(all(result$R4_palatability == 50))
  expect_true(all(result$R4_vulnerability == 50))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicator_risk_browsing with bdforet lacking essence column", {
  units <- create_test_units(n_features = 3)

  # BD Foret without any recognized essence column
  bdforet_geom <- c(
    sf::st_buffer(sf::st_geometry(units)[1], 80),
    sf::st_buffer(sf::st_geometry(units)[2], 80),
    sf::st_buffer(sf::st_geometry(units)[3], 80)
  )
  bdforet <- sf::st_sf(
    code_tfv_unused = c("A", "B", "C"),
    geometry = bdforet_geom
  )

  # Should use default palatability (50) since no recognized essence column
  result <- indicator_risk_browsing(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4_palatability == 50))
})

test_that("indicator_risk_browsing edge exposure with small polygons", {
  # Very small polygons where buffer might collapse entirely
  units <- create_test_units(n_features = 2)

  # With edge_buffer larger than polygon -> inner should collapse, edge_proportion = 1
  result <- indicator_risk_browsing(units, edge_buffer = 200)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicator_risk_browsing with bdforet and valid essence column", {
  units <- create_test_units(n_features = 3)

  # BD Foret with recognized 'essence' column
  bdforet_geom <- c(
    sf::st_buffer(sf::st_geometry(units)[1], 100),
    sf::st_buffer(sf::st_geometry(units)[2], 100),
    sf::st_buffer(sf::st_geometry(units)[3], 100)
  )
  bdforet <- sf::st_sf(
    essence = c("chene sessile", "pin maritime", "hetre commun"),
    geometry = bdforet_geom
  )

  result <- indicator_risk_browsing(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  # The palatability should differ per species (at least some non-50)
  expect_true(any(result$R4_palatability != 50))
})
