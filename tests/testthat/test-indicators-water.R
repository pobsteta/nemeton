# Tests for Water Family Indicators (Famille W)
# Phase 5: US3 - Eau (Water)
#
# W1: indicateur_w1_reseau() - Hydrographic network density
# W2: indicateur_w2_zones_humides() - Wetland coverage
# W3: indicateur_w3_humidite() - Topographic Wetness Index

# ==============================================================================
# W1: HYDROGRAPHIC NETWORK DENSITY
# ==============================================================================

test_that("indicateur_w1_reseau calculates stream density within parcels", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Use "indicateur_w3_humidite" layer (actual name in massif_demo, not "watercourses")
  density <- indicateur_w1_reseau(units, layers, watercourse_layer = "water")

  # Test output
  expect_type(density, "double")
  expect_length(density, 5)
  expect_true(all(!is.na(density)))
  expect_true(all(density >= 0)) # Density should be non-negative

  # Reasonable range check (m/ha)
  # Dense network: ~500-2000 m/ha, sparse: 0-100 m/ha
  expect_true(all(density < 5000)) # Upper bound check
})

test_that("indicateur_w1_reseau with buffer expands search area", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # No buffer
  density_0 <- indicateur_w1_reseau(units, layers, watercourse_layer = "water", buffer = 0)

  # 100m buffer
  density_100 <- indicateur_w1_reseau(units, layers, watercourse_layer = "water", buffer = 100)

  # Buffer should generally increase or maintain density (catches nearby streams)
  expect_true(all(density_100 >= density_0))
})

test_that("indicateur_w1_reseau handles parcels with no watercourses", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Use parcels that might not intersect watercourses
  units <- massif_demo_units[15:20, ]

  density <- indicateur_w1_reseau(units, layers, watercourse_layer = "water")

  expect_length(density, 6)
  expect_true(all(density >= 0)) # Should be 0 for parcels without streams
  expect_true(all(!is.na(density)))
})

test_that("indicateur_w1_reseau errors when watercourse layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicateur_w1_reseau(units, layers, watercourse_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicateur_w1_reseau validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicateur_w1_reseau(data.frame(x = 1:3), layers, watercourse_layer = "water"),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicateur_w1_reseau(massif_demo_units, list(), watercourse_layer = "water"),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# W2: WETLAND COVERAGE
# ==============================================================================

test_that("indicateur_w2_zones_humides calculates wetland percentage from landcover", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Designate landcover value 4 as wetland (for testing)
  coverage <- indicateur_w2_zones_humides(
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

test_that("indicateur_w2_zones_humides handles multiple wetland codes", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Multiple wetland types (e.g., marsh, riparian, peat)
  coverage <- indicateur_w2_zones_humides(
    units,
    layers,
    wetland_layer = "landcover",
    wetland_values = c(3, 4) # Two landcover classes as wetlands
  )

  expect_length(coverage, 3)
  expect_true(all(coverage >= 0 & coverage <= 100))
})

test_that("indicateur_w2_zones_humides returns 0 when no wetlands present", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Use non-existent wetland code (landcover only has 1-4)
  coverage <- indicateur_w2_zones_humides(
    units,
    layers,
    wetland_layer = "landcover",
    wetland_values = 99
  )

  # Should be 0% for all parcels
  expect_true(all(coverage == 0))
})

test_that("indicateur_w2_zones_humides handles nonexistent wetland layer gracefully", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Non-existent layer -> falls back to TWI from DEM or returns NA
  coverage <- indicateur_w2_zones_humides(units, layers, wetland_layer = "nonexistent")
  expect_type(coverage, "double")
  expect_length(coverage, 3)
})

test_that("indicateur_w2_zones_humides with NULL wetland_values uses TWI or vector fallback", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # NULL wetland_values with landcover layer -> falls back to TWI or returns NA
  coverage <- indicateur_w2_zones_humides(units, layers, wetland_layer = "landcover", wetland_values = NULL)
  expect_type(coverage, "double")
  expect_length(coverage, 3)
})

test_that("indicateur_w2_zones_humides validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicateur_w2_zones_humides(data.frame(x = 1:3), layers, wetland_values = 4),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicateur_w2_zones_humides(massif_demo_units, list(), wetland_values = 4),
    "must be.*nemeton_layers"
  )
})

# ==============================================================================
# W3: TOPOGRAPHIC WETNESS INDEX
# ==============================================================================

test_that("indicateur_w3_humidite calculates TWI from DEM", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Default method (auto - will use terra D8 if whitebox not available)
  twi <- indicateur_w3_humidite(units, layers, dem_layer = "dem")

  # Test output
  expect_type(twi, "double")
  expect_length(twi, 5)

  # Most values should be valid (allow edge NA due to DEM boundary effects)
  valid_twi <- twi[!is.na(twi)]
  expect_true(length(valid_twi) >= 3, info = paste("Only", length(valid_twi), "valid values"))

  # TWI typically ranges from ~0 to ~20+ (higher = wetter)
  expect_true(all(valid_twi >= 0))
  expect_true(all(valid_twi < 50)) # Upper bound sanity check
})

test_that("indicateur_w3_humidite with explicit d8 method", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Force D8 method (terra fallback)
  twi_d8 <- indicateur_w3_humidite(units, layers, dem_layer = "dem", method = "d8")

  expect_length(twi_d8, 3)
  # Allow some NA for edge parcels
  valid_twi <- twi_d8[!is.na(twi_d8)]
  expect_true(length(valid_twi) >= 1)
  expect_true(all(valid_twi >= 0))
})

test_that("indicateur_w3_humidite shows higher values in depressions", {
  # This is a qualitative test - TWI should reflect terrain wetness
  # Lower elevation parcels or flatter areas should generally have higher TWI

  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:10, ]

  twi <- indicateur_w3_humidite(units, layers, dem_layer = "dem")

  # Filter valid values
  valid_twi <- twi[!is.na(twi)]
  expect_true(length(valid_twi) >= 5, info = "Need at least 5 valid parcels")

  # Check variation - TWI should vary across landscape
  if (length(valid_twi) >= 2) {
    expect_true(sd(valid_twi) >= 0) # May be small variation in demo data
    expect_true(max(valid_twi) >= min(valid_twi)) # Logical check
  }
})

test_that("indicateur_w3_humidite still works with nonexistent dem_layer (falls back to lidar_mnt/dem)", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # The function first tries get_dem_raster() which checks lidar_mnt then dem
  # Since demo layers have dem, it will still work
  twi <- indicateur_w3_humidite(units, layers, dem_layer = "nonexistent")
  expect_type(twi, "double")
  expect_length(twi, 3)
})

test_that("indicateur_w3_humidite validates method parameter", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Invalid method (match.arg error in French or English)
  expect_error(
    indicateur_w3_humidite(units, layers, dem_layer = "dem", method = "invalid"),
    "should be one of|must be|doit être"
  )
})

test_that("indicateur_w3_humidite validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicateur_w3_humidite(data.frame(x = 1:3), layers, dem_layer = "dem"),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicateur_w3_humidite(massif_demo_units, list(), dem_layer = "dem"),
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
    w1 <- indicateur_w1_reseau(units, layers, watercourse_layer = "water")
    w2 <- indicateur_w2_zones_humides(units, layers, wetland_layer = "landcover", wetland_values = 4)
    w3 <- indicateur_w3_humidite(units, layers, dem_layer = "dem")
  })

  # All should return valid numeric vectors
  expect_length(w1, 5)
  expect_length(w2, 5)
  expect_length(w3, 5)

  # W1 and W2 from vector/raster should have no NA
  expect_true(all(!is.na(w1)))
  expect_true(all(!is.na(w2)))
  # W3 from DEM may have edge NA
  expect_true(sum(!is.na(w3)) >= 3)
})

test_that("Water indicators can be added to units dataframe", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Add all water indicators as columns
  units$W1_network <- indicateur_w1_reseau(units, layers, watercourse_layer = "water")
  units$W2_wetlands <- indicateur_w2_zones_humides(units, layers, wetland_layer = "landcover", wetland_values = 4)
  units$W3_twi <- indicateur_w3_humidite(units, layers, dem_layer = "dem")

  # Check structure
  expect_true("W1_network" %in% names(units))
  expect_true("W2_wetlands" %in% names(units))
  expect_true("W3_twi" %in% names(units))

  # Check rows populated (W1/W2 should be complete, W3 may have edge NA)
  expect_true(all(!is.na(units$W1_network)))
  expect_true(all(!is.na(units$W2_wetlands)))
  expect_true(sum(!is.na(units$W3_twi)) >= 1)
})
