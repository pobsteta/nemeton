# Tests for Landscape Family Indicators (Famille L)
# Phase 7: US5 - Landscape/Paysage
#
# L1: indicator_landscape_fragmentation() - Forest patch metrics
# L2: indicator_landscape_edge() - Edge-to-area ratio

# ==============================================================================
# L1: LANDSCAPE FRAGMENTATION
# ==============================================================================

test_that("indicator_landscape_fragmentation calculates patch metrics", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate fragmentation (number of patches within buffer)
  fragmentation <- indicator_landscape_fragmentation(
    units,
    layers,
    landcover_layer = "landcover",
    forest_values = c(1, 2, 3),
    buffer = 1000
  )

  # Test output
  expect_type(fragmentation, "double")
  expect_length(fragmentation, 5)
  expect_true(all(!is.na(fragmentation)))
  expect_true(all(fragmentation >= 0)) # Number of patches should be non-negative
})

test_that("indicator_landscape_fragmentation with different buffer sizes", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Smaller buffer
  frag_500 <- indicator_landscape_fragmentation(
    units,
    layers,
    landcover_layer = "landcover",
    forest_values = c(1, 2, 3),
    buffer = 500
  )

  # Larger buffer
  frag_2000 <- indicator_landscape_fragmentation(
    units,
    layers,
    landcover_layer = "landcover",
    forest_values = c(1, 2, 3),
    buffer = 2000
  )

  expect_length(frag_500, 3)
  expect_length(frag_2000, 3)

  # Larger buffer should generally detect more or equal patches
  expect_true(all(frag_2000 >= frag_500 | abs(frag_2000 - frag_500) < 2))
})

test_that("indicator_landscape_fragmentation with different forest definitions", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Only value 1 as forest
  frag_1 <- indicator_landscape_fragmentation(
    units,
    layers,
    forest_values = 1,
    buffer = 1000
  )

  # Values 1,2,3 as forest (broader definition)
  frag_123 <- indicator_landscape_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 1000
  )

  expect_length(frag_1, 3)
  expect_length(frag_123, 3)
  expect_true(all(!is.na(frag_1)))
  expect_true(all(!is.na(frag_123)))
})

test_that("indicator_landscape_fragmentation errors when landcover missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicator_landscape_fragmentation(units, layers, landcover_layer = "nonexistent"),
    "not found"
  )
})

test_that("indicator_landscape_fragmentation validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicator_landscape_fragmentation(data.frame(x = 1:3), layers),
    "must be.*sf"
  )

  # Invalid layers
  expect_error(
    indicator_landscape_fragmentation(massif_demo_units, list()),
    "must be.*nemeton_layers"
  )
})

test_that("indicator_landscape_fragmentation handles zero buffer", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Zero buffer means only parcel itself
  frag_0 <- indicator_landscape_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 0
  )

  expect_length(frag_0, 3)
  expect_true(all(!is.na(frag_0)))

  # With zero buffer, each parcel should typically be 1 patch (or 0 if non-forest)
  expect_true(all(frag_0 >= 0))
})

# ==============================================================================
# L2: EDGE-TO-AREA RATIO
# ==============================================================================

test_that("indicator_landscape_edge calculates edge density", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]

  # Calculate edge density (m/ha)
  edge <- indicator_landscape_edge(units)

  # Test output
  expect_type(edge, "double")
  expect_length(edge, 5)
  expect_true(all(!is.na(edge)))
  expect_true(all(edge >= 0)) # Edge density should be non-negative
})

test_that("indicator_landscape_edge scales with parcel geometry", {
  data(massif_demo_units)

  # Test that edge density reflects perimeter-to-area ratio
  # Smaller parcels typically have higher edge density
  units <- massif_demo_units[1:10, ]

  edge <- indicator_landscape_edge(units)

  # Calculate actual perimeter and area for comparison
  units$perimeter_m <- as.numeric(sf::st_length(sf::st_cast(units, "MULTILINESTRING")))
  units$area_ha <- as.numeric(sf::st_area(units)) / 10000
  units$expected_ratio <- units$perimeter_m / units$area_ha

  # Edge density should correlate with perimeter/area ratio
  if (sd(edge) > 0 && sd(units$expected_ratio) > 0) {
    cor_value <- cor(edge, units$expected_ratio)
    expect_true(cor_value > 0.9) # Strong positive correlation
  }
})

test_that("indicator_landscape_edge handles different parcel sizes", {
  data(massif_demo_units)

  # Select parcels with different areas
  units_small <- massif_demo_units[1:3, ]
  units_large <- massif_demo_units[15:17, ]

  edge_small <- indicator_landscape_edge(units_small)
  edge_large <- indicator_landscape_edge(units_large)

  expect_length(edge_small, 3)
  expect_length(edge_large, 3)
  expect_true(all(!is.na(edge_small)))
  expect_true(all(!is.na(edge_large)))
})

test_that("indicator_landscape_edge validates inputs", {
  # Invalid units
  expect_error(
    indicator_landscape_edge(data.frame(x = 1:3)),
    "must be.*sf"
  )

  # Empty units
  data(massif_demo_units)
  expect_error(
    indicator_landscape_edge(massif_demo_units[0, ]),
    "empty|no features|nrow.*0"
  )
})

test_that("indicator_landscape_edge works for single parcel", {
  data(massif_demo_units)

  units <- massif_demo_units[1, ]

  edge <- indicator_landscape_edge(units)

  expect_length(edge, 1)
  expect_true(!is.na(edge))
  expect_true(edge > 0)
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("Both landscape indicators work together", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate both indicators
  expect_no_error({
    l1 <- indicator_landscape_fragmentation(
      units,
      layers,
      forest_values = c(1, 2, 3),
      buffer = 1000
    )
    l2 <- indicator_landscape_edge(units)
  })

  # Both should return valid numeric vectors
  expect_length(l1, 5)
  expect_length(l2, 5)

  expect_true(all(!is.na(l1)))
  expect_true(all(!is.na(l2)))
})

test_that("Landscape indicators can be added to units dataframe", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Add all landscape indicators as columns
  units$L1_fragmentation <- indicator_landscape_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 1000
  )
  units$L2_edge <- indicator_landscape_edge(units)

  # Check structure
  expect_true("L1_fragmentation" %in% names(units))
  expect_true("L2_edge" %in% names(units))

  # Check all rows populated
  expect_true(all(!is.na(units$L1_fragmentation)))
  expect_true(all(!is.na(units$L2_edge)))
})

test_that("Fragmentation and edge density can be correlated", {
  # Higher fragmentation might correlate with higher edge density

  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:10, ]

  l1 <- indicator_landscape_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 1000
  )
  l2 <- indicator_landscape_edge(units)

  # Check that both indicators produce valid values
  expect_true(all(!is.na(l1)))
  expect_true(all(!is.na(l2)))

  # If there's variation, correlation should be calculable
  if (sd(l1) > 0 && sd(l2) > 0) {
    cor_value <- cor(l1, l2)
    expect_true(is.numeric(cor_value))
    expect_true(!is.na(cor_value))
  }
})

test_that("Landscape indicators work with full dataset", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Test on all 20 parcels
  units <- massif_demo_units

  l1 <- indicator_landscape_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 1000
  )
  l2 <- indicator_landscape_edge(units)

  expect_length(l1, nrow(massif_demo_units))
  expect_length(l2, nrow(massif_demo_units))

  # All values should be valid
  expect_true(all(!is.na(l1)))
  expect_true(all(!is.na(l2)))

  # Reasonable ranges
  expect_true(all(l1 >= 0)) # Patch count non-negative
  expect_true(all(l2 > 0)) # Edge density positive for real parcels
  expect_true(all(l2 < 10000)) # Reasonable upper bound for edge density (m/ha)
})
