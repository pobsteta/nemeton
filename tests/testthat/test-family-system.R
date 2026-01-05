# Tests for Multi-Family System (US6 - Phase 9)
#
# Family-aware normalization, aggregation, and visualization

# ==============================================================================
# CREATE_FAMILY_INDEX - FAMILY COMPOSITE INDICES
# ==============================================================================

test_that("create_family_index aggregates indicators by family", {
  data(massif_demo_units)

  # Create dataset with multiple family indicators
  units <- massif_demo_units[1:5, ]
  units$C1 <- c(50, 60, 55, 65, 70)  # Carbon biomass
  units$C2 <- c(70, 75, 72, 78, 80)  # Carbon NDVI
  units$W1 <- c(10, 15, 12, 18, 20)  # Water network
  units$W2 <- c(30, 35, 32, 38, 40)  # Water wetlands
  units$W3 <- c(5, 8, 6, 10, 12)     # Water TWI

  # Create family indices
  result <- create_family_index(units, method = "mean")

  # Test output structure
  expect_s3_class(result, "sf")
  expect_true("family_C" %in% names(result))  # Carbon family score
  expect_true("family_W" %in% names(result))  # Water family score

  # Test values are in 0-100 range (if normalized)
  expect_true(all(!is.na(result$family_C)))
  expect_true(all(!is.na(result$family_W)))
})

test_that("create_family_index supports custom weights per indicator", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)
  units$C2 <- c(70, 75, 72)
  units$W1 <- c(10, 15, 12)

  # Custom weights: C1 more important than C2
  result <- create_family_index(
    units,
    weights = list(C = c(C1 = 0.7, C2 = 0.3))
  )

  expect_s3_class(result, "sf")
  expect_true("family_C" %in% names(result))

  # Verify weighted average calculation
  expected_C <- units$C1 * 0.7 + units$C2 * 0.3
  expect_equal(result$family_C, expected_C, tolerance = 0.01)
})

test_that("create_family_index handles partial families", {
  data(massif_demo_units)

  # Only one indicator from Carbon family
  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)
  units$W1 <- c(10, 15, 12)
  units$W2 <- c(30, 35, 32)

  result <- create_family_index(units)

  # Should create indices for available families
  expect_true("family_C" %in% names(result))  # Single indicator
  expect_true("family_W" %in% names(result))  # Two indicators
})

test_that("create_family_index detects family from indicator names", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]
  units$C1_biomass <- c(50, 60)  # Alternative naming
  units$carbon_ndvi <- c(70, 75)  # Non-standard
  units$W1 <- c(10, 15)

  # Should detect C1 prefix
  result <- create_family_index(units)

  expect_true("family_C" %in% names(result) || "family_W" %in% names(result))
})

test_that("create_family_index supports different aggregation methods", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)
  units$C2 <- c(70, 75, 72)

  # Mean
  result_mean <- create_family_index(units, method = "mean")
  expect_equal(result_mean$family_C, (units$C1 + units$C2) / 2)

  # Weighted mean with equal weights
  result_weighted <- create_family_index(units, method = "weighted")
  expect_true("family_C" %in% names(result_weighted))

  # Geometric mean
  result_geom <- create_family_index(units, method = "geometric")
  expect_equal(result_geom$family_C, sqrt(units$C1 * units$C2), tolerance = 0.01)
})

test_that("create_family_index handles NA values appropriately", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, NA, 55)
  units$C2 <- c(70, 75, NA)

  result <- create_family_index(units, method = "mean", na.rm = TRUE)

  # First unit: both values present
  expect_false(is.na(result$family_C[1]))

  # Second unit: C1 is NA, only C2 contributes
  expect_equal(result$family_C[2], 75)

  # Third unit: C2 is NA, only C1 contributes
  expect_equal(result$family_C[3], 55)
})

test_that("create_family_index validates inputs", {
  data(massif_demo_units)

  # Invalid data
  expect_error(
    create_family_index(data.frame(x = 1:3)),
    "must be.*sf"
  )

  # No indicators
  units <- massif_demo_units[1:2, ]
  expect_error(
    create_family_index(units),
    "No family indicators found|No indicators"
  )
})

# ==============================================================================
# NORMALIZE_INDICATORS - FAMILY-AWARE NORMALIZATION
# ==============================================================================

test_that("normalize_indicators recognizes family prefixes", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$C1 <- c(50, 60, 55, 65, 70)
  units$C2 <- c(70, 75, 72, 78, 80)
  units$W1 <- c(10, 15, 12, 18, 20)

  # Normalize with family awareness
  result <- normalize_indicators(units, method = "minmax")

  # All indicators should be normalized to 0-100
  expect_true(all(result$C1 >= 0 & result$C1 <= 100))
  expect_true(all(result$C2 >= 0 & result$C2 <= 100))
  expect_true(all(result$W1 >= 0 & result$W1 <= 100))
})

test_that("normalize_indicators can normalize by family", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)   # Range: 50-60
  units$C2 <- c(700, 750, 725) # Range: 700-750 (different scale)

  # Normalize within each family separately
  result <- normalize_indicators(units, method = "minmax", by_family = TRUE)

  # Both should be normalized to 0-100 independently
  expect_true(all(result$C1 >= 0 & result$C1 <= 100))
  expect_true(all(result$C2 >= 0 & result$C2 <= 100))

  # Min/max should be 0/100 within family
  expect_equal(min(result$C1), 0, tolerance = 0.01)
  expect_equal(max(result$C1), 100, tolerance = 0.01)
})

test_that("normalize_indicators maintains backward compatibility", {
  # v0.1.0 style: no family prefixes
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$carbon <- c(50, 60, 55)
  units$water <- c(10, 15, 12)

  # Should work without family detection
  result <- normalize_indicators(units, method = "minmax")

  expect_s3_class(result, "sf")
  expect_true("carbon" %in% names(result))
  expect_true("water" %in% names(result))
})

# ==============================================================================
# NEMETON_RADAR - MULTI-FAMILY RADAR PLOTS
# ==============================================================================

test_that("nemeton_radar supports multi-family mode", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)
  units$C2 <- c(70, 75, 72)
  units$W1 <- c(10, 15, 12)
  units$F1 <- c(30, 35, 32)

  # First create family indices
  units_fam <- create_family_index(units)

  # Radar with family scores
  p <- nemeton_radar(units_fam, unit_id = 1, mode = "family")

  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
})

test_that("nemeton_radar handles 4-12 family axes dynamically", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]
  units$C1 <- c(50, 60)
  units$W1 <- c(10, 15)
  units$F1 <- c(30, 35)
  units$L1 <- c(40, 45)

  # Create family indices (4 families)
  units_fam <- create_family_index(units)

  # Should create radar with 4 axes
  p <- nemeton_radar(units_fam, unit_id = 1, mode = "family")

  expect_s3_class(p, "ggplot")

  # Check that plot has layers (indicates successful construction)
  expect_true(length(p$layers) > 0)
})

test_that("nemeton_radar maintains backward compatibility with indicator mode", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # v0.1.0 style workflow
  units <- massif_demo_units[1:3, ]
  results <- nemeton_compute(units, layers, indicators = c("carbon", "water"))
  normalized <- normalize_indicators(results, method = "minmax")

  # Should work without family mode
  p <- nemeton_radar(normalized, unit_id = 1)

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar validates mode parameter", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]
  units$C1 <- c(50, 60)

  # Invalid mode (error message varies by locale)
  expect_error(
    nemeton_radar(units, unit_id = 1, mode = "invalid"),
    "mode.*must be|should be one of|doit être"
  )
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("Complete multi-family workflow works end-to-end", {
  data(massif_demo_units)

  # Setup multi-family indicators
  units <- massif_demo_units[1:5, ]
  units$C1 <- rnorm(5, 50, 10)
  units$C2 <- rnorm(5, 70, 10)
  units$W1 <- rnorm(5, 15, 5)
  units$W2 <- rnorm(5, 30, 5)
  units$F1 <- rnorm(5, 40, 10)
  units$L1 <- rnorm(5, 3, 1)

  # Workflow
  expect_no_error({
    # 1. Normalize indicators
    units_norm <- normalize_indicators(units, method = "minmax")

    # 2. Create family indices
    units_fam <- create_family_index(units_norm)

    # 3. Create radar plot
    p <- nemeton_radar(units_fam, unit_id = 1, mode = "family")
  })

  # Verify outputs
  expect_s3_class(units_norm, "sf")
  expect_s3_class(units_fam, "sf")
  expect_s3_class(p, "ggplot")

  # Check family columns exist
  expect_true(any(grepl("^family_", names(units_fam))))
})

test_that("Family system preserves original indicator columns", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)
  units$W1 <- c(10, 15, 12)

  result <- create_family_index(units)

  # Original indicators should still be present
  expect_true("C1" %in% names(result))
  expect_true("W1" %in% names(result))

  # Family indices should be added
  expect_true("family_C" %in% names(result))
  expect_true("family_W" %in% names(result))
})

test_that("Family system works with temporal datasets", {
  data(massif_demo_units)

  # Create temporal dataset with family indicators
  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, 55)
  units_2015$W1 <- c(10, 15, 12)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(55, 65, 60)
  units_2020$W1 <- c(12, 17, 14)

  # Create family indices for each period
  units_2015_fam <- create_family_index(units_2015)
  units_2020_fam <- create_family_index(units_2020)

  # Create temporal object
  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015_fam, "2020" = units_2020_fam),
    id_column = "parcel_id"
  )

  # Calculate change rates for family scores
  rates <- calculate_change_rate(temporal, indicators = c("family_C", "family_W"))

  expect_s3_class(rates, "sf")
  expect_true("family_C_rate_abs" %in% names(rates))
  expect_true("family_W_rate_abs" %in% names(rates))
})

test_that("Family detection works with all family codes", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]

  # All 12 families
  units$C1 <- c(50, 60)  # Carbon
  units$B1 <- c(5, 6)    # Biodiversity
  units$W1 <- c(10, 15)  # Water
  units$A1 <- c(20, 25)  # Air
  units$F1 <- c(30, 35)  # Soil (Fertilité)
  units$L1 <- c(3, 4)    # Landscape
  units$T1 <- c(40, 45)  # Time (Temps)
  units$R1 <- c(15, 18)  # Risks (Risques)
  units$S1 <- c(25, 28)  # Social
  units$P1 <- c(35, 38)  # Productive
  units$E1 <- c(45, 48)  # Energy
  units$N1 <- c(55, 58)  # Naturalité

  result <- create_family_index(units)

  # Should detect all families
  family_cols <- grep("^family_", names(result), value = TRUE)
  expect_true(length(family_cols) >= 10)  # At least most families
})
# ==============================================================================
# v0.3.0: Tests for new family codes (B, R, T, A) - T059
# ==============================================================================

test_that("create_family_index handles B (Biodiversity) family correctly", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$B1 <- c(0, 25, 50, 75, 100)      # Protection
  units$B2 <- c(0.2, 0.4, 0.6, 0.8, 1.0) # Structure
  units$B3 <- c(100, 200, 500, 1000, 2000) # Connectivity

  result <- create_family_index(units, family_codes = "B")

  expect_s3_class(result, "sf")
  expect_true("family_B" %in% names(result))
  expect_true(all(!is.na(result$family_B)))
  expect_true(all(result$family_B >= 0))
})

test_that("create_family_index handles R (Risk/Resilience) family correctly", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$R1 <- c(10, 30, 50, 70, 90)  # Fire risk
  units$R2 <- c(5, 25, 45, 65, 85)   # Storm vulnerability
  units$R3 <- c(15, 35, 55, 75, 95)  # Drought stress

  result <- create_family_index(units, family_codes = "R")

  expect_s3_class(result, "sf")
  expect_true("family_R" %in% names(result))
  expect_true(all(!is.na(result$family_R)))
})

test_that("create_family_index handles T (Temporal) family correctly", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$T1 <- c(20, 50, 100, 150, 250)   # Age
  units$T2 <- c(0, 0.5, 1.0, 2.0, 5.0)  # Change rate

  result <- create_family_index(units, family_codes = "T")

  expect_s3_class(result, "sf")
  expect_true("family_T" %in% names(result))
  expect_true(all(!is.na(result$family_T)))
})

test_that("create_family_index handles A (Air quality) family correctly", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$A1 <- c(10, 30, 50, 70, 90)  # Coverage
  units$A2 <- c(20, 40, 60, 80, 100) # Quality

  result <- create_family_index(units, family_codes = "A")

  expect_s3_class(result, "sf")
  expect_true("family_A" %in% names(result))
  expect_true(all(!is.na(result$family_A)))
})

test_that("create_family_index handles mixed v0.2.0 and v0.3.0 families", {
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  # v0.2.0 families
  units$C1 <- c(100, 200, 300, 400, 500)
  units$W1 <- c(10, 20, 30, 40, 50)
  # v0.3.0 families
  units$B1 <- c(0, 25, 50, 75, 100)
  units$R1 <- c(10, 30, 50, 70, 90)
  units$T1 <- c(20, 50, 100, 150, 250)
  units$A1 <- c(10, 30, 50, 70, 90)

  result <- create_family_index(units, family_codes = c("C", "W", "B", "R", "T", "A"))

  # Check all families created
  expect_true(all(c("family_C", "family_W", "family_B", "family_R", "family_T", "family_A") %in% names(result)))

  # All should have valid values
  expect_true(all(!is.na(result$family_C)))
  expect_true(all(!is.na(result$family_B)))
  expect_true(all(!is.na(result$family_R)))
})

test_that("create_family_index auto-detects all 9 implemented families (v0.3.0)", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  # v0.2.0 families (C, W, F, L)
  units$C1 <- c(100, 200, 300)
  units$W1 <- c(10, 20, 30)
  units$F1 <- c(5, 10, 15)
  units$L1 <- c(0.3, 0.5, 0.7)
  # v0.3.0 families (B, R, T, A)
  units$B1 <- c(25, 50, 75)
  units$R1 <- c(30, 50, 70)
  units$T1 <- c(50, 100, 150)
  units$A1 <- c(40, 60, 80)

  # Auto-detect all families
  result <- create_family_index(units)

  # Should detect all 8-9 families (C, W, F, L, B, R, T, A)
  family_cols <- grep("^family_", names(result), value = TRUE)
  expect_true(length(family_cols) >= 8)

  # Verify key v0.3.0 families exist
  expect_true("family_B" %in% names(result))
  expect_true("family_R" %in% names(result))
  expect_true("family_T" %in% names(result))
  expect_true("family_A" %in% names(result))
})

test_that("create_family_index aggregation methods work for new families", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$B1 <- c(20, 40, 60)
  units$B2 <- c(30, 50, 70)
  units$B3 <- c(40, 60, 80)

  # Mean
  result_mean <- create_family_index(units, family_codes = "B", method = "mean")
  expect_equal(result_mean$family_B, c(30, 50, 70))

  # Geometric mean
  result_geom <- create_family_index(units, family_codes = "B", method = "geometric")
  expected_geom <- (20 * 30 * 40)^(1/3)
  expect_equal(result_geom$family_B[1], expected_geom, tolerance = 0.01)

  # Min (bottleneck approach - worst indicator drives score)
  result_min <- create_family_index(units, family_codes = "B", method = "min")
  expect_equal(result_min$family_B, c(20, 40, 60))
})

test_that("create_family_index supports custom weights for new families", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]
  units$R1 <- c(50, 60)
  units$R2 <- c(40, 50)
  units$R3 <- c(30, 40)

  # Custom weights: R1 most important (fire risk)
  result <- create_family_index(
    units,
    family_codes = "R",
    weights = list(R = c(R1 = 0.5, R2 = 0.3, R3 = 0.2))
  )

  # Calculate expected weighted average
  expected <- units$R1 * 0.5 + units$R2 * 0.3 + units$R3 * 0.2
  expect_equal(result$family_R, expected)
})
