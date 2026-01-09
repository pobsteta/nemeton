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

  # Tests
  expect_s3_class(result, "sf")
  expect_true("T1" %in% names(result))
  expect_true("T1_norm" %in% names(result))
  expect_equal(result$T1, c(25, 75, 150, 200, 300))

  # Normalization: log scale, ancient forests score high
  expect_true(result$T1_norm[5] > result$T1_norm[1]) # 300yr > 25yr
  expect_true(all(result$T1_norm >= 0 & result$T1_norm <= 100))
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

  # Should calculate: 2025 - planted
  expect_equal(result$T1, c(175, 75, 25))
  expect_true(all(result$T1_norm >= 0 & result$T1_norm <= 100))
  expect_true(result$T1_norm[1] > result$T1_norm[3]) # 175yr > 25yr
})

test_that("indicator_temporal_age uses default current year", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  units$planted <- c(1900, 1980)

  # Should use Sys.Date() year if current_year not specified
  result <- indicator_temporal_age(units, age_field = NULL, establishment_year_field = "planted")

  current_yr <- as.integer(format(Sys.Date(), "%Y"))
  expect_equal(result$T1, c(current_yr - 1900, current_yr - 1980))
})

test_that("indicator_temporal_age handles NA values", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:4, ]

  units$age <- c(50, NA, 100, NA)

  result <- indicator_temporal_age(units, age_field = "age")

  expect_true(is.na(result$T1[2]))
  expect_true(is.na(result$T1_norm[2]))
  expect_false(is.na(result$T1[1]))
  expect_false(is.na(result$T1[3]))
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
    units, lc_1990, lc_2020, 30,
    interpretation = "stability"
  )

  result_dynamism <- indicator_temporal_change(
    units, lc_1990, lc_2020, 30,
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

  result <- indicator_temporal_change(units, lc_1990, lc_2020, 30)

  expect_true("T2" %in% names(result))
})

# ==============================================================================
# T040: Integration Test for T Family Workflow
# ==============================================================================

test_that("T family workflow: T1-T2 → normalize → family_T composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Add age attribute
  units$age <- runif(10, 20, 250)

  # Load fixtures
  lc_1990 <- terra::rast(test_path("fixtures/land_cover/land_cover_1990.tif"))
  lc_2020 <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Full workflow
  result <- units %>%
    indicator_temporal_age(age_field = "age") %>%
    indicator_temporal_change(land_cover_early = lc_1990, land_cover_late = lc_2020, years_elapsed = 30) %>%
    normalize_indicators(indicators = c("T1", "T2")) %>%
    create_family_index(family_codes = "T")

  # Verify complete workflow
  expect_true(all(c("T1", "T2") %in% names(result)))
  expect_true(all(c("T1_norm", "T2_norm") %in% names(result)))
  expect_true("family_T" %in% names(result))
  expect_true(all(result$family_T >= 0 & result$family_T <= 100, na.rm = TRUE))
})

# ==============================================================================
# T041: Regression Test Fixture
# ==============================================================================

test_that("T indicators match expected regression fixture", {
  skip("Regression fixture not yet created - will be generated after implementation")

  # This test will be enabled after creating expected_indicators_v030_temporal.rds
  # with known T1/T2 values
})
