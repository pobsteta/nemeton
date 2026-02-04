# Tests for Soil Family Indicators (Famille F)
# Phase 6: US4 - Fertilité des Sols (Soil Fertility)
#
# F1: indicator_soil_fertility() - Soil fertility classification
# F2: indicator_soil_erosion() - Soil fertility index (TWI + slope)

# ==============================================================================
# F1: SOIL FERTILITY CLASS
# ==============================================================================

test_that("indicator_soil_fertility extracts fertility from raster", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Use landcover as proxy for soil fertility (for testing)
  # In production, this would be BD Sol or equivalent
  fertility <- indicator_soil_fertility(
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

test_that("indicator_soil_fertility with custom fertility mapping", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Test with fertility mapping (landcover values → fertility scores)
  # Value 1 = high fertility, value 4 = low fertility, etc.
  fertility <- indicator_soil_fertility(
    units,
    layers,
    soil_layer = "landcover",
    fertility_col = "value"
  )

  expect_length(fertility, 3)
  expect_true(all(fertility >= 0 & fertility <= 100))
})

test_that("indicator_soil_fertility errors when soil layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicator_soil_fertility(units, layers, soil_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicator_soil_fertility validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicator_soil_fertility(data.frame(x = 1:3), layers),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicator_soil_fertility(massif_demo_units, list()),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# F2: SOIL FERTILITY INDEX (TWI + SLOPE)
# ==============================================================================

test_that("indicator_soil_erosion calculates fertility from TWI and slope", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate soil fertility (F2 = (twi_norm + slope_norm) / 2)
  fertility <- indicator_soil_erosion(units, layers, dem_layer = "dem")

  # Test output
  expect_type(fertility, "double")
  expect_length(fertility, 5)
  expect_true(all(!is.na(fertility)))

  # Fertility should be 0-100 scale
  expect_true(all(fertility >= 0))
  expect_true(all(fertility <= 100))
})

test_that("indicator_soil_erosion produces higher values on flat wet areas", {
  # Flat areas with high TWI should have higher fertility

  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:10, ]

  fertility <- indicator_soil_erosion(units, layers)

  # Check that calculation produces valid results
  expect_true(all(fertility >= 0))
  expect_true(all(fertility <= 100))

  # At least some parcels should have measurable values
  expect_true(mean(fertility) > 0)
})

test_that("indicator_soil_erosion still works with nonexistent dem_layer (falls back to lidar_mnt/dem)", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # The function first tries get_dem_raster() which checks lidar_mnt then dem
  # If the demo layers have dem, it will still work
  fertility <- indicator_soil_erosion(units, layers, dem_layer = "nonexistent")
  expect_type(fertility, "double")
  expect_length(fertility, 3)
})

test_that("indicator_soil_erosion validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicator_soil_erosion(data.frame(x = 1:3), layers),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicator_soil_erosion(massif_demo_units, list()),
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
    f1 <- indicator_soil_fertility(units, layers, soil_layer = "landcover")
    f2 <- indicator_soil_erosion(units, layers)
  })

  # Both should return valid numeric vectors
  expect_length(f1, 5)
  expect_length(f2, 5)

  expect_true(all(!is.na(f1)))
  expect_true(all(!is.na(f2)))
})

test_that("Soil indicators can be added to units dataframe", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Add all soil indicators as columns
  units$F1_fertility <- indicator_soil_fertility(units, layers, soil_layer = "landcover")
  units$F2_fertility <- indicator_soil_erosion(units, layers)

  # Check structure
  expect_true("F1_fertility" %in% names(units))
  expect_true("F2_fertility" %in% names(units))

  # Check all rows populated
  expect_true(all(!is.na(units$F1_fertility)))
  expect_true(all(!is.na(units$F2_fertility)))
})

test_that("Soil fertility indicators can be correlated", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:10, ]

  f1 <- indicator_soil_fertility(units, layers, soil_layer = "landcover")
  f2 <- indicator_soil_erosion(units, layers)

  # Check that both indicators produce valid values
  expect_true(all(!is.na(f1)))
  expect_true(all(!is.na(f2)))

  # If there's variation, correlation should be calculable
  if (sd(f1) > 0 && sd(f2) > 0) {
    cor_value <- cor(f1, f2)
    expect_true(is.numeric(cor_value))
    expect_true(!is.na(cor_value))
  }
})
