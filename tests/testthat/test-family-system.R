# Tests for Multi-Family System (US6 - Phase 9)
#
# Family-aware normalization, aggregation, and visualization

# ==============================================================================
# CREATE_FAMILY_INDEX - FAMILY COMPOSITE INDICES
# ==============================================================================

test_that("create_family_index aggregates indicators by family", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 5)
  units$C1 <- c(50, 60, 55, 65, 70) # Carbon biomass
  units$C2 <- c(70, 75, 72, 78, 80) # Carbon NDVI
  units$W1 <- c(10, 15, 12, 18, 20) # Water network
  units$W2 <- c(30, 35, 32, 38, 40) # Water wetlands
  units$W3 <- c(5, 8, 6, 10, 12) # Water TWI

  # Create family indices
  result <- create_family_index(units, method = "mean")

  # Test output structure
  expect_s3_class(result, "sf")
  expect_true("famille_carbone" %in% names(result)) # Carbon family score
  expect_true("famille_eau" %in% names(result)) # Water family score

  # Test values are in 0-100 range (if normalized)
  expect_true(all(!is.na(result$famille_carbone)))
  expect_true(all(!is.na(result$famille_eau)))
})

test_that("create_family_index supports custom weights per indicator", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 3)
  units$C1 <- c(50, 60, 55)
  units$C2 <- c(70, 75, 72)
  units$W1 <- c(10, 15, 12)

  # Custom weights: C1 more important than C2
  result <- create_family_index(
    units,
    weights = list(C = c(C1 = 0.7, C2 = 0.3))
  )

  expect_s3_class(result, "sf")
  expect_true("famille_carbone" %in% names(result))

  # Verify weighted average calculation. Les attentes passent par
  # normalize_indicator() : ce test porte sur la PONDÉRATION, pas sur l'échelle.
  # Coder l'échelle en dur revenait à supposer que `C1` est déjà un score 0-100,
  # alors que la convention des codes courts (cf. massif_demo_units : C1 en
  # tC/ha, S3 en habitants) est celle de la valeur brute.
  expected_C <- normalize_indicator("C1", units$C1) * 0.7 +
                normalize_indicator("C2", units$C2) * 0.3
  expect_equal(result$famille_carbone, expected_C, tolerance = 0.01)
})

test_that("create_family_index handles partial families", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 3)

  # Only one indicator from Carbon family
  units$C1 <- c(50, 60, 55)
  units$W1 <- c(10, 15, 12)
  units$W2 <- c(30, 35, 32)

  result <- create_family_index(units)

  # Should create indices for available families
  expect_true("famille_carbone" %in% names(result)) # Single indicator
  expect_true("famille_eau" %in% names(result)) # Two indicators
})

test_that("create_family_index detects family from indicator names", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 2)
  units$C1_biomass <- c(50, 60) # Alternative naming
  units$indicateur_c2_ndvi <- c(70, 75) # Non-standard
  units$W1 <- c(10, 15)

  # Should detect C1 prefix or W1
  result <- create_family_index(units)

  expect_true("famille_carbone" %in% names(result) || "famille_eau" %in% names(result))
})

test_that("create_family_index supports different aggregation methods", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 3)
  units$C1 <- c(50, 60, 55)
  units$C2 <- c(70, 75, 72)

  n_c1 <- normalize_indicator("C1", units$C1)
  n_c2 <- normalize_indicator("C2", units$C2)

  # Mean
  result_mean <- create_family_index(units, method = "mean")
  expect_equal(result_mean$famille_carbone, (n_c1 + n_c2) / 2)

  # Weighted mean with equal weights
  result_weighted <- create_family_index(units, method = "weighted")
  expect_true("famille_carbone" %in% names(result_weighted))

  # Geometric mean
  result_geom <- create_family_index(units, method = "geometric")
  expect_equal(result_geom$famille_carbone, sqrt(n_c1 * n_c2), tolerance = 0.01)
})

test_that("create_family_index handles NA values appropriately", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 3)
  units$C1 <- c(50, NA, 55)
  units$C2 <- c(70, 75, NA)

  result <- create_family_index(units, method = "mean", na.rm = TRUE)

  # First unit: both values present
  expect_false(is.na(result$famille_carbone[1]))

  # Second unit: C1 is NA, only C2 contributes
  expect_equal(result$famille_carbone[2], normalize_indicator("C2", 75))

  # Third unit: C2 is NA, only C1 contributes
  expect_equal(result$famille_carbone[3], normalize_indicator("C1", 55))
})

test_that("create_family_index validates inputs", {
  skip_if_not_installed("terra")
  # Invalid data
  expect_error(
    create_family_index(data.frame(x = 1:3)),
    "must be.*sf"
  )

  # No indicators - use clean units without indicator columns
  units <- create_test_units(n_features = 2)
  expect_error(
    create_family_index(units),
    "No family indicators found|No indicators"
  )
})

# ==============================================================================
# NORMALIZE_INDICATORS - FAMILY-AWARE NORMALIZATION
# ==============================================================================

test_that("normalize_indicators recognizes family prefixes", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 5)
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
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55) # Range: 50-60
  units$C2 <- c(700, 750, 725) # Range: 700-750 (different scale)

  # Normalize within each family separately
  # (some demo columns may have identical values on 3 rows)
  result <- suppressWarnings(
    normalize_indicators(units, method = "minmax", by_family = TRUE)
  )

  # Both should be normalized to 0-100 independently
  expect_true(all(result$C1 >= 0 & result$C1 <= 100))
  expect_true(all(result$C2 >= 0 & result$C2 <= 100))

  # Min/max should be 0/100 within family
  expect_equal(min(result$C1), 0, tolerance = 0.01)
  expect_equal(max(result$C1), 100, tolerance = 0.01)
})

test_that("normalize_indicators maintains backward compatibility", {
  skip_if_not_installed("terra")
  # v0.1.0 style: no family prefixes
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$indicateur_c1_biomasse <- c(50, 60, 55)
  units$indicateur_w3_humidite <- c(10, 15, 12)

  # Should work without family detection
  # (some demo columns may have identical values on 3 rows)
  result <- suppressWarnings(
    normalize_indicators(units, method = "minmax")
  )

  expect_s3_class(result, "sf")
  expect_true("indicateur_c1_biomasse" %in% names(result))
  expect_true("indicateur_w3_humidite" %in% names(result))
})

# ==============================================================================
# NEMETON_RADAR - MULTI-FAMILY RADAR PLOTS
# ==============================================================================

test_that("nemeton_radar supports multi-family mode", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  data(massif_demo_units)
  layers <- massif_demo_layers()

  # v0.1.0 style workflow
  units <- massif_demo_units[1:3, ]
  results <- nemeton_compute(units, layers, indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"))
  # (some computed columns may have identical values on 3 rows)
  normalized <- suppressWarnings(
    normalize_indicators(results, method = "minmax")
  )

  # Should work without family mode
  p <- nemeton_radar(normalized, unit_id = 1)

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar validates mode parameter", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  expect_true(any(grepl("^famille_", names(units_fam))))
})

test_that("Family system preserves original indicator columns", {
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$C1 <- c(50, 60, 55)
  units$W1 <- c(10, 15, 12)

  result <- create_family_index(units)

  # Original indicators should still be present
  expect_true("C1" %in% names(result))
  expect_true("W1" %in% names(result))

  # Family indices should be added
  expect_true("famille_carbone" %in% names(result))
  expect_true("famille_eau" %in% names(result))
})

test_that("Family system works with temporal datasets", {
  skip_if_not_installed("terra")
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
  rates <- calculate_change_rate(temporal, indicators = c("famille_carbone", "famille_eau"))

  expect_s3_class(rates, "sf")
  expect_true("famille_carbone_rate_abs" %in% names(rates))
  expect_true("famille_eau_rate_abs" %in% names(rates))
})

test_that("Family detection works with all family codes", {
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]

  # All 12 families
  units$C1 <- c(50, 60) # Carbon
  units$B1 <- c(5, 6) # Biodiversity
  units$W1 <- c(10, 15) # Water
  units$A1 <- c(20, 25) # Air
  units$F1 <- c(30, 35) # Soil (Fertilité)
  units$L1 <- c(3, 4) # Landscape
  units$T1 <- c(40, 45) # Time (Temps)
  units$R1 <- c(15, 18) # Risks (Risques)
  units$S1 <- c(25, 28) # Social
  units$P1 <- c(35, 38) # Productive
  units$E1 <- c(45, 48) # Energy
  units$N1 <- c(55, 58) # Naturalité

  result <- create_family_index(units)

  # Should detect all families
  family_cols <- grep("^famille_", names(result), value = TRUE)
  expect_true(length(family_cols) >= 10) # At least most families
})
# ==============================================================================
# v0.3.0: Tests for new family codes (B, R, T, A) - T059
# ==============================================================================

test_that("create_family_index handles B (Biodiversity) family correctly", {
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$B1 <- c(0, 25, 50, 75, 100) # Protection
  units$B2 <- c(0.2, 0.4, 0.6, 0.8, 1.0) # Structure
  units$B3 <- c(100, 200, 500, 1000, 2000) # Connectivity

  result <- create_family_index(units, family_codes = "B")

  expect_s3_class(result, "sf")
  expect_true("famille_biodiversite" %in% names(result))
  expect_true(all(!is.na(result$famille_biodiversite)))
  expect_true(all(result$famille_biodiversite >= 0))
})

test_that("create_family_index handles R (Risk/Resilience) family correctly", {
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$R1 <- c(10, 30, 50, 70, 90) # Fire risk
  units$R2 <- c(5, 25, 45, 65, 85) # Storm vulnerability
  units$R3 <- c(15, 35, 55, 75, 95) # Drought stress

  result <- create_family_index(units, family_codes = "R")

  expect_s3_class(result, "sf")
  expect_true("famille_risque" %in% names(result))
  expect_true(all(!is.na(result$famille_risque)))
})

test_that("create_family_index handles T (Temporal) family correctly", {
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$T1 <- c(20, 50, 100, 150, 250) # Age
  units$T2 <- c(0, 0.5, 1.0, 2.0, 5.0) # Change rate

  result <- create_family_index(units, family_codes = "T")

  expect_s3_class(result, "sf")
  expect_true("famille_temporel" %in% names(result))
  expect_true(all(!is.na(result$famille_temporel)))
})

test_that("create_family_index handles A (Air quality) family correctly", {
  skip_if_not_installed("terra")
  data(massif_demo_units)

  units <- massif_demo_units[1:5, ]
  units$A1 <- c(10, 30, 50, 70, 90) # Coverage
  units$A2 <- c(20, 40, 60, 80, 100) # Quality

  result <- create_family_index(units, family_codes = "A")

  expect_s3_class(result, "sf")
  expect_true("famille_air" %in% names(result))
  expect_true(all(!is.na(result$famille_air)))
})

test_that("create_family_index handles mixed v0.2.0 and v0.3.0 families", {
  skip_if_not_installed("terra")
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
  expect_true(all(c("famille_carbone", "famille_eau", "famille_biodiversite", "famille_risque", "famille_temporel", "famille_air") %in% names(result)))

  # All should have valid values
  expect_true(all(!is.na(result$famille_carbone)))
  expect_true(all(!is.na(result$famille_biodiversite)))
  expect_true(all(!is.na(result$famille_risque)))
})

test_that("create_family_index auto-detects all 9 implemented families (v0.3.0)", {
  skip_if_not_installed("terra")
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
  family_cols <- grep("^famille_", names(result), value = TRUE)
  expect_true(length(family_cols) >= 8)

  # Verify key v0.3.0 families exist
  expect_true("famille_biodiversite" %in% names(result))
  expect_true("famille_risque" %in% names(result))
  expect_true("famille_temporel" %in% names(result))
  expect_true("famille_air" %in% names(result))
})

test_that("create_family_index aggregation methods work for new families", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 3)
  units$B1 <- c(20, 40, 60)
  units$B2 <- c(30, 50, 70)
  units$B3 <- c(40, 60, 80)

  # Mean
  result_mean <- create_family_index(units, family_codes = "B", method = "mean")
  expect_equal(result_mean$famille_biodiversite, c(30, 50, 70))

  # Geometric mean
  result_geom <- create_family_index(units, family_codes = "B", method = "geometric")
  expected_geom <- (20 * 30 * 40)^(1 / 3)
  expect_equal(result_geom$famille_biodiversite[1], expected_geom, tolerance = 0.01)

  # Min (bottleneck approach - worst indicator drives score)
  result_min <- create_family_index(units, family_codes = "B", method = "min")
  expect_equal(result_min$famille_biodiversite, c(20, 40, 60))
})

test_that("create_family_index supports custom weights for new families", {
  skip_if_not_installed("terra")
  # Use clean test units without pre-existing indicator columns
  units <- create_test_units(n_features = 2)
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
  expect_equal(result$famille_risque, expected)
})

# ==============================================================================
# Additional tests for better coverage
# ==============================================================================

test_that("create_family_index uses harmonic mean method", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  units$C1 <- c(40, 80)
  units$C2 <- c(60, 90)

  result <- create_family_index(units, method = "harmonic", family_codes = "C")

  expect_true("famille_carbone" %in% names(result))
  # Harmonic mean should be less than arithmetic mean for unequal values
  mean_result <- create_family_index(units, method = "mean", family_codes = "C")
  expect_true(result$famille_carbone[1] <= mean_result$famille_carbone[1])
})

test_that("create_family_index warns when weights don't match all indicators", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  units$C1 <- c(50, 60)
  units$C2 <- c(70, 80)

  # Weights only for C1, not C2
  expect_warning(
    result <- create_family_index(
      units,
      family_codes = "C",
      weights = list(C = c(C1 = 0.7))  # Missing C2
    ),
    "weights"
  )
})

test_that("create_family_index prefers _norm columns when available", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  units$C1 <- c(500, 600)  # Raw values
  units$C1_norm <- c(50, 60)  # Normalized values
  units$C2 <- c(70, 80)

  result <- create_family_index(units, family_codes = "C")

  # Should use normalized C1_norm, not raw C1
  # So famille_carbone should be closer to (50+70)/2 = 60 than (500+70)/2 = 285
  expect_true(result$famille_carbone[1] < 100)
})

test_that("get_family_name returns family names", {
  skip_if_not_installed("terra")
  # Test family name lookups - check that non-empty strings are returned
  expect_type(get_family_name("C"), "character")
  expect_true(nchar(get_family_name("C")) > 0)
  expect_true(nchar(get_family_name("B")) > 0)
  expect_true(nchar(get_family_name("W")) > 0)
  expect_true(nchar(get_family_name("R")) > 0)
  expect_true(nchar(get_family_name("S")) > 0)
  expect_true(nchar(get_family_name("P")) > 0)
  expect_true(nchar(get_family_name("E")) > 0)
  expect_true(nchar(get_family_name("N")) > 0)
})

test_that("get_family_name handles invalid codes", {
  skip_if_not_installed("terra")
  # Invalid codes should return something (might be the code itself or Unknown)
  result_x <- get_family_name("X")
  result_zzz <- get_family_name("ZZZ")

  expect_type(result_x, "character")
  expect_type(result_zzz, "character")
})

test_that("detect_indicator_family extracts family from various patterns", {
  skip_if_not_installed("terra")
  # Standard patterns
  expect_equal(detect_indicator_family("C1"), "C")
  expect_equal(detect_indicator_family("B3"), "B")

  # With suffix
  expect_equal(detect_indicator_family("W2_norm"), "W")

  # Non-indicator columns
  expect_true(is.na(detect_indicator_family("geometry")))
  expect_true(is.na(detect_indicator_family("parcel_id")))
  expect_true(is.na(detect_indicator_family("area")))
})
