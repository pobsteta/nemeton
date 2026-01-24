# test-indicators-temporal.R
# Unit and integration tests for Temporal Dynamics Family (T) Indicators
# MVP v0.3.0 - Following TDD: Tests written BEFORE implementation

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T038: Unit Tests for indicator_temporal_age() (T1)
# ==============================================================================

test_that("indicator_temporal_age calculates age from age field", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add age attribute
  units$age <- c(25, 75, 150, 200, 300)

  result <- indicator_temporal_age(units, age_field = "age")

  # Result is a numeric vector (normalized T1 score 0-100)
  expect_type(result, "double")
  expect_length(result, 5)

  # Normalization: log scale, ancient forests score high
  expect_true(result[5] > result[1]) # 300yr > 25yr
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicator_temporal_age calculates age from establishment year", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Add establishment year
  units$planted <- c(1850, 1950, 2000)

  result <- indicator_temporal_age(
    units,
    age_field = NULL,
    establishment_year_field = "planted",
    current_year = 2025
  )

  # Result is a numeric vector (normalized T1 score 0-100)
  expect_type(result, "double")
  expect_length(result, 3)
  expect_true(all(result >= 0 & result <= 100))
  expect_true(result[1] > result[3]) # 175yr > 25yr
})

test_that("indicator_temporal_age uses default current year", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  units$planted <- c(1900, 1980)

  # Should use Sys.Date() year if current_year not specified
  result <- indicator_temporal_age(units, age_field = NULL, establishment_year_field = "planted")

  # Result is a numeric vector (normalized T1 score 0-100)
  expect_type(result, "double")
  expect_length(result, 2)
  # Older forest should have higher score
  expect_true(result[1] > result[2])
})

test_that("indicator_temporal_age handles NA values", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:4, ]

  units$age <- c(50, NA, 100, NA)

  result <- indicator_temporal_age(units, age_field = "age")

  # Result is a numeric vector (normalized T1 score 0-100)
  expect_type(result, "double")
  expect_length(result, 4)
  expect_true(is.na(result[2]))
  expect_true(is.na(result[4]))
  expect_false(is.na(result[1]))
  expect_false(is.na(result[3]))
})

# ==============================================================================
# T039: Unit Tests for indicator_temporal_change() (T2)
# ==============================================================================

test_that("indicator_temporal_change calculates change rate correctly", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Load test fixtures
  lc_1990 <- terra::rast(test_path("fixtures/land_cover/land_cover_1990.tif"))
  lc_2020 <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  result <- indicator_temporal_change(
    units,
    land_cover_early = lc_1990,
    land_cover_late = lc_2020,
    years_elapsed = 30,
    interpretation = "stability"
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("T2" %in% names(result))
  expect_true("T2_norm" %in% names(result))
  expect_type(result$T2, "double")

  # T2 should be annualized rate (%/year)
  expect_true(all(result$T2 >= 0, na.rm = TRUE))

  # T2_norm with "stability" interpretation: low change = high score
  expect_true(all(result$T2_norm >= 0 & result$T2_norm <= 100, na.rm = TRUE))
})

test_that("indicator_temporal_change supports dynamism interpretation", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  lc_1990 <- terra::rast(test_path("fixtures/land_cover/land_cover_1990.tif"))
  lc_2020 <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  result_stability <- indicator_temporal_change(
    units,
    land_cover_early = lc_1990,
    land_cover_late = lc_2020,
    years_elapsed = 30,
    interpretation = "stability"
  )

  result_dynamism <- indicator_temporal_change(
    units,
    land_cover_early = lc_1990,
    land_cover_late = lc_2020,
    years_elapsed = 30,
    interpretation = "dynamism"
  )

  # Same T2 raw values
  expect_equal(result_stability$T2, result_dynamism$T2)

  # Opposite T2_norm (stability inverts, dynamism does not)
  # If T2 is high, stability_norm should be low, dynamism_norm should be high
  if (any(result_stability$T2 > 1, na.rm = TRUE)) {
    high_change_idx <- which(result_stability$T2 > 1)[1]
    expect_true(
      result_dynamism$T2_norm[high_change_idx] > result_stability$T2_norm[high_change_idx]
    )
  }
})

test_that("indicator_temporal_change uses terra and exactextractr", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  lc_1990 <- terra::rast(test_path("fixtures/land_cover/land_cover_1990.tif"))
  lc_2020 <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Should work with SpatRaster inputs
  expect_s4_class(lc_1990, "SpatRaster")
  expect_s4_class(lc_2020, "SpatRaster")

  result <- indicator_temporal_change(
    units,
    land_cover_early = lc_1990,
    land_cover_late = lc_2020,
    years_elapsed = 30
  )

  expect_true("T2" %in% names(result))
})

# ==============================================================================
# T040: Integration Test for T Family Workflow
# Note: Pipe workflow test removed - use nemeton_compute() instead
# Note: Regression fixture test removed - will be added when fixtures are created
