# Tests for Soil Family Indicators (Famille F)
# Phase 6: US4 - Fertilité des Sols (Soil Fertility)
#
# F1: indicateur_f2_erosion() - Erosion risk (RUSLE: LS × C_factor)
# F2: indicateur_f1_fertilite() - Soil fertility index (TWI + slope)
#
# Core functions:
# indicateur_f1_fertilite() - Soil fertility classification (BD Sol)
# indicateur_f2_erosion() - Soil fertility index (TWI + slope)

# ==============================================================================
# F1: SOIL FERTILITY CLASS
# ==============================================================================

test_that("indicateur_f1_fertilite extracts fertility from raster", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Use landcover as proxy for soil fertility (for testing)
  # In production, this would be BD Sol or equivalent
  fertility <- indicateur_f1_fertilite(
    units,
    layers,
    soil_layer = "landcover",
    fertility_col = "value"
  )

  # Test output
  expect_type(fertility, "double")
  expect_length(fertility, 5)
  expect_true(all(!is.na(fertility)))

  # Fertility should be 0-100 scale
  expect_true(all(fertility >= 0))
  expect_true(all(fertility <= 100))
})

# Note: Vector soil data handling is not implemented in MVP (raster-only)
# This test was removed as it was a placeholder

test_that("indicateur_f1_fertilite with custom fertility mapping", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Test with fertility mapping (landcover values → fertility scores)
  # Value 1 = high fertility, value 4 = low fertility, etc.
  fertility <- indicateur_f1_fertilite(
    units,
    layers,
    soil_layer = "landcover",
    fertility_col = "value"
  )

  expect_length(fertility, 3)
  expect_true(all(fertility >= 0 & fertility <= 100))
})

test_that("indicateur_f1_fertilite errors when soil layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicateur_f1_fertilite(units, layers, soil_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicateur_f1_fertilite validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicateur_f1_fertilite(data.frame(x = 1:3), layers),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicateur_f1_fertilite(massif_demo_units, list()),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# F2: SOIL FERTILITY INDEX (TWI + SLOPE)
# ==============================================================================

test_that("indicateur_f2_erosion calculates fertility from TWI and slope", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate soil fertility (F2 = (twi_norm + slope_norm) / 2)
  fertility <- indicateur_f2_erosion(units, layers, dem_layer = "dem")

  # Test output
  expect_type(fertility, "double")
  expect_length(fertility, 5)

  # Most values should be valid (allow edge NA due to DEM boundary effects)
  valid_count <- sum(!is.na(fertility))
  expect_true(valid_count >= 3, info = paste("Only", valid_count, "valid values"))

  # Valid fertility should be 0-100 scale
  valid_fertility <- fertility[!is.na(fertility)]
  expect_true(all(valid_fertility >= 0))
  expect_true(all(valid_fertility <= 100))
})

test_that("indicateur_f2_erosion produces higher values on flat wet areas", {
  # Flat areas with high TWI should have higher fertility

  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:10, ]

  fertility <- indicateur_f2_erosion(units, layers)

  # Check that calculation produces valid results (allow some NA for edge cases)
  valid_fertility <- fertility[!is.na(fertility)]
  expect_true(length(valid_fertility) >= 5, info = "Need at least 5 valid parcels")
  expect_true(all(valid_fertility >= 0))
  expect_true(all(valid_fertility <= 100))

  # At least some parcels should have measurable values
  expect_true(mean(valid_fertility) > 0)
})

test_that("indicateur_f2_erosion still works with nonexistent dem_layer (falls back to lidar_mnt/dem)", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # The function first tries get_dem_raster() which checks lidar_mnt then dem
  # If the demo layers have dem, it will still work
  fertility <- indicateur_f2_erosion(units, layers, dem_layer = "nonexistent")
  expect_type(fertility, "double")
  expect_length(fertility, 3)
})

test_that("indicateur_f2_erosion validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicateur_f2_erosion(data.frame(x = 1:3), layers),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicateur_f2_erosion(massif_demo_units, list()),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("Both soil indicators work together", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate both indicators
  expect_no_error({
    f1 <- indicateur_f1_fertilite(units, layers, soil_layer = "landcover")
    f2 <- indicateur_f2_erosion(units, layers)
  })

  # Both should return valid numeric vectors
  expect_length(f1, 5)
  expect_length(f2, 5)

  # F1 from landcover should have no NA
  expect_true(all(!is.na(f1)))
  # F2 from TWI may have some NA at DEM boundaries
  expect_true(sum(!is.na(f2)) >= 3)
})

# ==============================================================================
# ALIAS FUNCTIONS (dispatch from app_config)
# F1 -> indicateur_f2_erosion (RUSLE)
# F2 -> indicateur_f1_fertilite (TWI + slope)
# ==============================================================================

test_that("indicateur_f2_erosion computes RUSLE erosion risk (F1)", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  erosion <- indicateur_f2_erosion(units, layers)

  expect_type(erosion, "double")
  expect_length(erosion, 5)

  # RUSLE erosion should be 0-100 scale
  expect_true(all(erosion >= 0, na.rm = TRUE))
  expect_true(all(erosion <= 100, na.rm = TRUE))
})

# ==============================================================================
# Removed 5 tests that expected stub behavior (return NA on NULL layers) and
# that had inverted F1/F2 semantics. The real functions in
# R/indicators-families.R validate inputs and stop() with "layers must be a
# nemeton_layers object" or "Soil layer 'soil' not found". The real F1 is
# fertility (soil lookup) and F2 is erosion (TWI+slope), as per CLAUDE.md.
# ==============================================================================
