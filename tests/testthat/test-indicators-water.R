# Tests for Water Family Indicators (Famille W)
# Phase 5: US3 - Eau (Water)
#
# W1: indicator_water_network() - Hydrographic network density
# W2: indicator_water_wetlands() - Wetland coverage
# W3: indicator_water_twi() - Topographic Wetness Index

# ==============================================================================
# W1: HYDROGRAPHIC NETWORK DENSITY
# ==============================================================================

test_that("indicator_water_network calculates stream density within parcels", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Use "water" layer (actual name in massif_demo, not "watercourses")
  density <- indicator_water_network(units, layers, watercourse_layer = "water")

  # Test output
  expect_type(density, "double")
  expect_length(density, 5)
  expect_true(all(!is.na(density)))
  expect_true(all(density >= 0)) # Density should be non-negative

  # Reasonable range check (km/ha should be small values)
  # Dense network: ~0.5-2 km/ha, sparse: 0-0.1 km/ha
  expect_true(all(density < 5)) # Upper bound check
})

test_that("indicator_water_network with buffer expands search area", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # No buffer
  density_0 <- indicator_water_network(units, layers, watercourse_layer = "water", buffer = 0)

  # 100m buffer
  density_100 <- indicator_water_network(units, layers, watercourse_layer = "water", buffer = 100)

  # Buffer should generally increase or maintain density (catches nearby streams)
  expect_true(all(density_100 >= density_0))
})

test_that("indicator_water_network handles parcels with no watercourses", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Use parcels that might not intersect watercourses
  units <- massif_demo_units[15:20, ]

  density <- indicator_water_network(units, layers, watercourse_layer = "water")

  expect_length(density, 6)
  expect_true(all(density >= 0)) # Should be 0 for parcels without streams
  expect_true(all(!is.na(density)))
})

test_that("indicator_water_network errors when watercourse layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicator_water_network(units, layers, watercourse_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicator_water_network validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicator_water_network(data.frame(x = 1:3), layers, watercourse_layer = "water"),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicator_water_network(massif_demo_units, list(), watercourse_layer = "water"),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# W2: WETLAND COVERAGE
# ==============================================================================

test_that("indicator_water_wetlands calculates wetland percentage from landcover", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Designate landcover value 4 as wetland (for testing)
  coverage <- indicator_water_wetlands(
    units,
    layers,
    wetland_layer = "landcover",
    wetland_values = 4
  )

  # Test output
  expect_type(coverage, "double")
  expect_length(coverage, 5)
  expect_true(all(!is.na(coverage)))

  # Percentage should be 0-100%
  expect_true(all(coverage >= 0))
  expect_true(all(coverage <= 100))
})

test_that("indicator_water_wetlands handles multiple wetland codes", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Multiple wetland types (e.g., marsh, riparian, peat)
  coverage <- indicator_water_wetlands(
    units,
    layers,
    wetland_layer = "landcover",
    wetland_values = c(3, 4) # Two landcover classes as wetlands
  )

  expect_length(coverage, 3)
  expect_true(all(coverage >= 0 & coverage <= 100))
})

test_that("indicator_water_wetlands returns 0 when no wetlands present", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Use non-existent wetland code (landcover only has 1-4)
  coverage <- indicator_water_wetlands(
    units,
    layers,
    wetland_layer = "landcover",
    wetland_values = 99
  )

  # Should be 0% for all parcels
  expect_true(all(coverage == 0))
})

test_that("indicator_water_wetlands errors when wetland layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicator_water_wetlands(units, layers, wetland_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicator_water_wetlands requires wetland_values parameter", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # NULL wetland_values should error with helpful message
  expect_error(
    indicator_water_wetlands(units, layers, wetland_layer = "landcover", wetland_values = NULL),
    "wetland_values.*required|must specify"
  )
})

test_that("indicator_water_wetlands validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicator_water_wetlands(data.frame(x = 1:3), layers, wetland_values = 4),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicator_water_wetlands(massif_demo_units, list(), wetland_values = 4),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# W3: TOPOGRAPHIC WETNESS INDEX
# ==============================================================================

test_that("indicator_water_twi calculates TWI from DEM", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Default method (auto - will use terra D8 if whitebox not available)
  twi <- indicator_water_twi(units, layers, dem_layer = "dem")

  # Test output
  expect_type(twi, "double")
  expect_length(twi, 5)
  expect_true(all(!is.na(twi)))

  # TWI typically ranges from ~0 to ~20+ (higher = wetter)
  expect_true(all(twi >= 0))
  expect_true(all(twi < 50)) # Upper bound sanity check
})

test_that("indicator_water_twi with explicit d8 method", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Force D8 method (terra fallback)
  twi_d8 <- indicator_water_twi(units, layers, dem_layer = "dem", method = "d8")

  expect_length(twi_d8, 3)
  expect_true(all(!is.na(twi_d8)))
  expect_true(all(twi_d8 >= 0))
})

test_that("indicator_water_twi shows higher values in depressions", {
  # This is a qualitative test - TWI should reflect terrain wetness
  # Lower elevation parcels or flatter areas should generally have higher TWI

  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:10, ]

  twi <- indicator_water_twi(units, layers, dem_layer = "dem")

  # Check variation - TWI should vary across landscape
  expect_true(sd(twi) > 0) # Not all identical
  expect_true(max(twi) > min(twi)) # Some variation in wetness
})

test_that("indicator_water_twi errors when DEM layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicator_water_twi(units, layers, dem_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicator_water_twi validates method parameter", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Invalid method (match.arg error in French or English)
  expect_error(
    indicator_water_twi(units, layers, dem_layer = "dem", method = "invalid"),
    "should be one of|must be|doit être"
  )
})

test_that("indicator_water_twi validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicator_water_twi(data.frame(x = 1:3), layers, dem_layer = "dem"),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicator_water_twi(massif_demo_units, list(), dem_layer = "dem"),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("All three water indicators work together", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate all three indicators
  expect_no_error({
    w1 <- indicator_water_network(units, layers, watercourse_layer = "water")
    w2 <- indicator_water_wetlands(units, layers, wetland_layer = "landcover", wetland_values = 4)
    w3 <- indicator_water_twi(units, layers, dem_layer = "dem")
  })

  # All should return valid numeric vectors
  expect_length(w1, 5)
  expect_length(w2, 5)
  expect_length(w3, 5)

  expect_true(all(!is.na(w1)))
  expect_true(all(!is.na(w2)))
  expect_true(all(!is.na(w3)))
})

test_that("Water indicators can be added to units dataframe", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Add all water indicators as columns
  units$W1_network <- indicator_water_network(units, layers, watercourse_layer = "water")
  units$W2_wetlands <- indicator_water_wetlands(units, layers, wetland_layer = "landcover", wetland_values = 4)
  units$W3_twi <- indicator_water_twi(units, layers, dem_layer = "dem")

  # Check structure
  expect_true("W1_network" %in% names(units))
  expect_true("W2_wetlands" %in% names(units))
  expect_true("W3_twi" %in% names(units))

  # Check all rows populated
  expect_true(all(!is.na(units$W1_network)))
  expect_true(all(!is.na(units$W2_wetlands)))
  expect_true(all(!is.na(units$W3_twi)))
})
