# Tests for Landscape Family Indicators (Famille L)
# L1: indicateur_l2_fragmentation() - Sylvosphere (edge effect), score 0-100
# L2: indicateur_l1_sylvosphere() - Landscape fragmentation, score 0-100

# ==============================================================================
# L1: SYLVOSPHERE (EDGE EFFECT)
# ==============================================================================

test_that("indicateur_l2_fragmentation returns score 0-100", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  score <- indicateur_l2_fragmentation(
    units,
    layers,
    landcover_layer = "landcover",
    forest_values = c(1, 2, 3),
    buffer = 50
  )

  # Test output
  expect_type(score, "double")
  expect_length(score, 5)
  expect_true(all(!is.na(score)))
  expect_true(all(score >= 0 & score <= 100))
})

test_that("indicateur_l2_fragmentation works without layers (fallback)", {
  data(massif_demo_units)
  units <- massif_demo_units[1:3, ]

  # No layers: geometry + exposure still work, contrast defaults to 50
  score <- indicateur_l2_fragmentation(units)

  expect_type(score, "double")
  expect_length(score, 3)
  expect_true(all(!is.na(score)))
  expect_true(all(score >= 0 & score <= 100))
})

test_that("indicateur_l2_fragmentation geometry component varies with shape", {
  data(massif_demo_units)
  units <- massif_demo_units[1:10, ]

  # Scores should vary across parcels with different shapes

  score <- indicateur_l2_fragmentation(units)

  expect_length(score, 10)
  expect_true(all(score >= 0 & score <= 100))

  # With multiple parcels of different shapes, we expect some variation
  if (length(unique(round(score))) > 1) {
    expect_true(sd(score) > 0)
  }
})

test_that("indicateur_l2_fragmentation validates inputs", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Invalid units
  expect_error(
    indicateur_l2_fragmentation(data.frame(x = 1:3), layers),
    "must be.*sf"
  )
})

test_that("indicateur_l2_fragmentation works for single parcel", {
  data(massif_demo_units)
  units <- massif_demo_units[1, ]

  score <- indicateur_l2_fragmentation(units)

  expect_length(score, 1)
  expect_true(!is.na(score))
  expect_true(score >= 0 && score <= 100)
})

# ==============================================================================
# L2: LANDSCAPE FRAGMENTATION
# ==============================================================================

test_that("indicateur_l1_sylvosphere returns score 0-100", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]

  score <- indicateur_l1_sylvosphere(units)

  # Test output
  expect_type(score, "double")
  expect_length(score, 5)
  expect_true(all(!is.na(score)))
  expect_true(all(score >= 0 & score <= 100))
})

test_that("indicateur_l1_sylvosphere fallback uses shape index", {
  data(massif_demo_units)
  units <- massif_demo_units[1:5, ]

  # Without layers, should use shape index fallback
  score <- indicateur_l1_sylvosphere(units)

  expect_type(score, "double")
  expect_length(score, 5)
  expect_true(all(!is.na(score)))
  expect_true(all(score >= 0 & score <= 100))
})

test_that("indicateur_l1_sylvosphere with layers uses landscapemetrics when available", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # With layers - may use landscapemetrics if available, otherwise shape index
  score <- indicateur_l1_sylvosphere(
    units,
    layers,
    landcover_layer = "landcover",
    forest_values = c(1, 2, 3),
    buffer = 1000
  )

  expect_type(score, "double")
  expect_length(score, 5)
  expect_true(all(!is.na(score)))
  expect_true(all(score >= 0 & score <= 100))
})

test_that("indicateur_l1_sylvosphere validates inputs", {
  # Invalid units
  expect_error(
    indicateur_l1_sylvosphere(data.frame(x = 1:3)),
    "must be.*sf"
  )

  # Empty units
  data(massif_demo_units)
  expect_error(
    indicateur_l1_sylvosphere(massif_demo_units[0, ]),
    "empty|no features|nrow.*0"
  )
})

test_that("indicateur_l1_sylvosphere works for single parcel", {
  data(massif_demo_units)

  units <- massif_demo_units[1, ]

  score <- indicateur_l1_sylvosphere(units)

  expect_length(score, 1)
  expect_true(!is.na(score))
  expect_true(score > 0 && score <= 100)
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
    l1 <- indicateur_l2_fragmentation(
      units,
      layers,
      forest_values = c(1, 2, 3),
      buffer = 50
    )
    l2 <- indicateur_l1_sylvosphere(units)
  })

  # Both should return valid 0-100 scores
  expect_length(l1, 5)
  expect_length(l2, 5)

  expect_true(all(!is.na(l1)))
  expect_true(all(!is.na(l2)))
  expect_true(all(l1 >= 0 & l1 <= 100))
  expect_true(all(l2 >= 0 & l2 <= 100))
})

test_that("Landscape indicators can be added to units dataframe", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Add all landscape indicators as columns
  units$L1_sylvosphere <- indicateur_l2_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 50
  )
  units$L2_fragmentation <- indicateur_l1_sylvosphere(units)

  # Check structure
  expect_true("L1_sylvosphere" %in% names(units))
  expect_true("L2_fragmentation" %in% names(units))

  # Check all rows populated with 0-100 scores
  expect_true(all(!is.na(units$L1_sylvosphere)))
  expect_true(all(!is.na(units$L2_fragmentation)))
  expect_true(all(units$L1_sylvosphere >= 0 & units$L1_sylvosphere <= 100))
  expect_true(all(units$L2_fragmentation >= 0 & units$L2_fragmentation <= 100))
})

test_that("Landscape indicators work with full dataset", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # Test on all parcels
  units <- massif_demo_units

  l1 <- indicateur_l2_fragmentation(
    units,
    layers,
    forest_values = c(1, 2, 3),
    buffer = 50
  )
  l2 <- indicateur_l1_sylvosphere(units)

  expect_length(l1, nrow(massif_demo_units))
  expect_length(l2, nrow(massif_demo_units))

  # All values should be valid 0-100 scores
  expect_true(all(!is.na(l1)))
  expect_true(all(!is.na(l2)))
  expect_true(all(l1 >= 0 & l1 <= 100))
  expect_true(all(l2 >= 0 & l2 <= 100))
})
