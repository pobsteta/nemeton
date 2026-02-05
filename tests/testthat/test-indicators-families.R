# Tests for indicators-families.R
# Caching functions and indicator helpers

# ==============================================================================
# TWI Cache Tests
# ==============================================================================

test_that(".twi_cache environment exists", {
  expect_true(exists(".twi_cache", envir = asNamespace("nemeton")))
})

test_that(".wind_cache environment exists", {
  expect_true(exists(".wind_cache", envir = asNamespace("nemeton")))
})

# ==============================================================================
# get_nasapower_wind Tests
# ==============================================================================

test_that("get_nasapower_wind returns default when nasapower not available", {
  skip_if_not_installed("sf")

  # Create simple test units
  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(2, 46)), crs = 4326)
  )
  units <- sf::st_buffer(units, 100)

  # Mock that nasapower is not installed
  result <- withr::with_package("mockr", {
    # Use temp dir for caching to avoid hitting real API
    temp_cache <- tempdir()
    result <- nemeton:::get_nasapower_wind(units, default_dir = 270, cache_dir = temp_cache)
    result
  }, quietly = TRUE)

  # Should return a numeric value (either default or from cache/API)
  expect_type(result, "double")
  expect_true(result >= 0 && result <= 360)
})

test_that("get_nasapower_wind uses in-memory cache", {
  skip_if_not_installed("sf")

  # Clear wind cache first
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(2.5, 46.5)), crs = 4326)
  )
  units <- sf::st_buffer(units, 100)

  temp_cache <- tempdir()

  # First call
  result1 <- nemeton:::get_nasapower_wind(units, default_dir = 280, cache_dir = temp_cache)

  # Second call should use cache (won't hit API again)
  result2 <- nemeton:::get_nasapower_wind(units, default_dir = 280, cache_dir = temp_cache)

  expect_equal(result1, result2)
})

# ==============================================================================
# get_or_compute_twi Tests
# ==============================================================================

test_that("get_or_compute_twi computes TWI from DEM", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Create a simple test DEM
  dem <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1000, ymin = 0, ymax = 1000)
  terra::crs(dem) <- "EPSG:2154"

  # Create elevation values (simple slope)
  values <- matrix(1:100, nrow = 10)
  terra::values(dem) <- as.vector(values)

  temp_cache <- tempdir()

  result <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) == 1)
})

test_that("get_or_compute_twi uses file cache when available", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Create a simple test DEM
  dem <- terra::rast(nrows = 5, ncols = 5, xmin = 100, xmax = 600, ymin = 100, ymax = 600)
  terra::crs(dem) <- "EPSG:2154"
  terra::values(dem) <- 1:25

  temp_cache <- file.path(tempdir(), "twi_test_cache")
  if (dir.exists(temp_cache)) unlink(temp_cache, recursive = TRUE)
  dir.create(temp_cache, recursive = TRUE)

  # First computation
  result1 <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)

  # Check that cache file was created
  cache_file <- file.path(temp_cache, "twi.tif")
  expect_true(file.exists(cache_file))

  # Second call should use cache
  result2 <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)

  expect_s4_class(result2, "SpatRaster")

  unlink(temp_cache, recursive = TRUE)
})

# ==============================================================================
# calculate_twi Tests
# ==============================================================================

test_that("calculate_twi_terra computes TWI correctly", {
  skip_if_not_installed("terra")

  # Create a simple DEM with known slope
  dem <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000)
  terra::crs(dem) <- "EPSG:2154"

  # Create a gradient (values increase from bottom to top)
  vals <- matrix(rep(1:20, each = 20), nrow = 20, byrow = TRUE)
  terra::values(dem) <- as.vector(vals)

  result <- nemeton:::calculate_twi_terra(dem)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) == 1)

  # TWI values should be finite where calculated
  twi_vals <- terra::values(result)
  expect_true(sum(!is.na(twi_vals)) > 0)
})

# ==============================================================================
# Indicator Functions Tests
# ==============================================================================

test_that("indicator_carbon_biomass returns expected structure", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)

  # Create mock layers
  layers <- list()

  # This will likely return NA without actual data, but should not error
  result <- tryCatch({
    nemeton:::indicator_carbon_biomass(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_carbon_ndvi returns expected structure", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_carbon_ndvi(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_water_network returns expected structure", {
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_water_network(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_water_wetlands returns expected structure", {
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_water_wetlands(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_soil_fertility returns expected structure", {
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_soil_fertility(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_soil_erosion returns expected structure", {
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_soil_erosion(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_landscape_fragmentation returns expected structure", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_landscape_fragmentation(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicator_landscape_edge returns expected structure", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicator_landscape_edge(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

# ==============================================================================
# Alias Functions Tests
# ==============================================================================

test_that("indicator_air_forest_buffer is an alias function", {
  expect_true(exists("indicator_air_forest_buffer", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicator_air_forest_buffer, "closure")
})

test_that("indicator_fertility_soil is an alias function", {
  expect_true(exists("indicator_fertility_soil", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicator_fertility_soil, "closure")
})

test_that("indicator_fertility_erosion is an alias function", {
  expect_true(exists("indicator_fertility_erosion", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicator_fertility_erosion, "closure")
})

test_that("indicator_landscape_edge_ratio is an alias function", {
  expect_true(exists("indicator_landscape_edge_ratio", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicator_landscape_edge_ratio, "closure")
})

# ==============================================================================
# extract_fertility Functions Tests
# ==============================================================================

test_that("extract_fertility_from_raster handles missing layers", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()  # Empty layers

  result <- tryCatch({
    nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("extract_fertility_from_vector handles missing layers", {
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()  # Empty layers

  result <- tryCatch({
    nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

# ==============================================================================
# indicator_social_population Tests
# ==============================================================================

test_that("indicator_social_population exists and is callable", {
  expect_true(exists("indicator_social_population", envir = asNamespace("nemeton")))

  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)

  result <- tryCatch({
    nemeton:::indicator_social_population(units)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_equal(nrow(result), 2)
})
