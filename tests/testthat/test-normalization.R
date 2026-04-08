test_that("normalize_indicators normalizes with min-max method", {
  # Create test data
  test_data <- data.frame(
    id = 1:5,
    indicateur_c1_biomasse = c(10, 20, 30, 40, 50),
    indicateur_w3_humidite = c(5, 10, 15, 20, 25)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    method = "minmax"
  )

  # Check that normalized columns were created
  expect_true("indicateur_c1_biomasse_norm" %in% names(normalized))
  expect_true("indicateur_w3_humidite_norm" %in% names(normalized))

  # Check min-max scaling (0-100)
  expect_equal(min(normalized$indicateur_c1_biomasse_norm), 0)
  expect_equal(max(normalized$indicateur_c1_biomasse_norm), 100)
  expect_equal(min(normalized$indicateur_w3_humidite_norm), 0)
  expect_equal(max(normalized$indicateur_w3_humidite_norm), 100)

  # Check linearity is preserved
  expect_equal(normalized$indicateur_c1_biomasse_norm[3], 50) # Middle value
})

test_that("normalize_indicators normalizes with z-score method", {
  test_data <- data.frame(
    id = 1:10,
    indicateur_c1_biomasse = rnorm(10, mean = 50, sd = 10)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = "indicateur_c1_biomasse",
    method = "zscore"
  )

  # Z-score should have mean ~0 and sd ~1
  expect_true(abs(mean(normalized$indicateur_c1_biomasse_norm)) < 0.01)
  expect_true(abs(sd(normalized$indicateur_c1_biomasse_norm) - 1) < 0.01)
})

test_that("normalize_indicators normalizes with quantile method", {
  test_data <- data.frame(
    id = 1:100,
    indicateur_c1_biomasse = 1:100
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = "indicateur_c1_biomasse",
    method = "quantile"
  )

  # Quantile normalization should create uniform distribution
  expect_equal(min(normalized$indicateur_c1_biomasse_norm), 1) # Lowest percentile
  expect_equal(max(normalized$indicateur_c1_biomasse_norm), 100) # Highest percentile
  expect_equal(normalized$indicateur_c1_biomasse_norm[50], 50) # Median
})

test_that("normalize_indicators auto-detects indicator columns", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse = c(10, 20, 30),
    indicateur_b1_protection = c(5, 10, 15),
    other_col = c(1, 2, 3)
  )

  # Should auto-detect carbon and biodiversity, ignore other_col
  normalized <- normalize_indicators(test_data, method = "minmax")

  expect_true("indicateur_c1_biomasse_norm" %in% names(normalized))
  expect_true("indicateur_b1_protection_norm" %in% names(normalized))
  expect_false("other_col_norm" %in% names(normalized))
})

test_that("normalize_indicators can remove original columns", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse = c(10, 20, 30)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = "indicateur_c1_biomasse",
    keep_original = FALSE
  )

  expect_false("indicateur_c1_biomasse" %in% names(normalized))
  expect_true("indicateur_c1_biomasse_norm" %in% names(normalized))
})

test_that("normalize_indicators accepts custom suffix", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse = c(10, 20, 30)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = "indicateur_c1_biomasse",
    suffix = "_scaled"
  )

  expect_true("indicateur_c1_biomasse_scaled" %in% names(normalized))
})

test_that("normalize_indicators handles NA values", {
  test_data <- data.frame(
    id = 1:5,
    indicateur_c1_biomasse = c(10, 20, NA, 40, 50)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = "indicateur_c1_biomasse",
    method = "minmax",
    na.rm = TRUE
  )

  # NA should be preserved
  expect_true(is.na(normalized$indicateur_c1_biomasse_norm[3]))

  # Other values should be normalized correctly
  expect_equal(min(normalized$indicateur_c1_biomasse_norm, na.rm = TRUE), 0)
  expect_equal(max(normalized$indicateur_c1_biomasse_norm, na.rm = TRUE), 100)
})

test_that("normalize_indicators works with reference data", {
  # Reference data with range 0-100
  reference <- data.frame(
    indicateur_c1_biomasse = c(0, 25, 50, 75, 100)
  )

  # New data with values outside reference range
  new_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse = c(10, 50, 120) # 120 is outside reference range
  )

  normalized <- normalize_indicators(
    new_data,
    indicators = "indicateur_c1_biomasse",
    reference_data = reference,
    method = "minmax"
  )

  # Value of 50 should normalize to 50 (middle of 0-100)
  expect_equal(normalized$indicateur_c1_biomasse_norm[2], 50)

  # Value of 10 should normalize to 10
  expect_equal(normalized$indicateur_c1_biomasse_norm[1], 10)

  # Value of 120 should be >100 (extrapolated)
  expect_true(normalized$indicateur_c1_biomasse_norm[3] > 100)
})

test_that("normalize_indicators preserves sf class", {
  units <- nemeton_units(create_test_units())
  units$indicateur_c1_biomasse <- c(10, 20, 30)

  normalized <- normalize_indicators(units, indicators = "indicateur_c1_biomasse")

  expect_s3_class(normalized, "sf")
  expect_s3_class(normalized, "nemeton_units")
})

test_that("normalize_indicators errors on missing indicators", {
  test_data <- data.frame(id = 1:3, indicateur_c1_biomasse = c(10, 20, 30))

  expect_error(
    normalize_indicators(test_data, indicators = "missing_column"),
    "not found"
  )
})

test_that("normalize_indicators handles constant values", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse = c(50, 50, 50) # All same value
  )

  expect_warning(
    normalized <- normalize_indicators(test_data, indicators = "indicateur_c1_biomasse", method = "minmax"),
    "identical"
  )

  # Should set to 50 (middle value)
  expect_true(all(normalized$indicateur_c1_biomasse_norm == 50))
})

test_that("create_composite_index creates weighted mean composite", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(0, 50, 100),
    indicateur_w3_humidite_norm = c(0, 50, 100)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    weights = c(0.6, 0.4)
  )

  expect_true("composite_index" %in% names(result))

  # With equal values, composite should equal the values
  expect_equal(result$composite_index[2], 50)
  expect_equal(result$composite_index[3], 100)
})

test_that("create_composite_index uses equal weights by default", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(0, 60, 100),
    indicateur_w3_humidite_norm = c(0, 40, 100)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm")
  )

  # With equal weights, composite should be average
  expect_equal(result$composite_index[2], 50) # (60 + 40) / 2
})

test_that("create_composite_index accepts custom name", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(0, 50, 100),
    indicateur_w3_humidite_norm = c(0, 50, 100)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    name = "ecosystem_health"
  )

  expect_true("ecosystem_health" %in% names(result))
  expect_false("composite_index" %in% names(result))
})

test_that("create_composite_index supports geometric mean", {
  test_data <- data.frame(
    id = 1:4,
    indicateur_c1_biomasse_norm = c(10, 25, 50, 100),
    indicateur_w3_humidite_norm = c(10, 25, 50, 100)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    aggregation = "geometric_mean"
  )

  # Geometric mean of equal values = the value
  expect_equal(result$composite_index[1], 10)
  expect_equal(result$composite_index[4], 100)

  # Geometric mean of 25 and 25 = 25
  expect_equal(result$composite_index[2], 25)
})

test_that("create_composite_index supports min aggregation", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(80, 60, 40),
    indicateur_w3_humidite_norm = c(20, 40, 60)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    aggregation = "min"
  )

  # Should take minimum value
  expect_equal(result$composite_index[1], 20)
  expect_equal(result$composite_index[2], 40)
  expect_equal(result$composite_index[3], 40)
})

test_that("create_composite_index supports max aggregation", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(80, 60, 40),
    indicateur_w3_humidite_norm = c(20, 40, 60)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    aggregation = "max"
  )

  # Should take maximum value
  expect_equal(result$composite_index[1], 80)
  expect_equal(result$composite_index[2], 60)
  expect_equal(result$composite_index[3], 60)
})

test_that("create_composite_index normalizes weights", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(0, 50, 100),
    indicateur_w3_humidite_norm = c(100, 50, 0)
  )

  # Weights that don't sum to 1 should be normalized
  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    weights = c(2, 1) # Will be normalized to c(0.667, 0.333)
  )

  # With weights 2:1, index[1] = (0*2 + 100*1)/3 = 33.33
  expect_equal(result$composite_index[1], 100 / 3, tolerance = 0.01)
})

test_that("create_composite_index handles NA values", {
  test_data <- data.frame(
    id = 1:4,
    indicateur_c1_biomasse_norm = c(50, NA, 60, 70),
    indicateur_w3_humidite_norm = c(50, 40, NA, 70)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    na.rm = TRUE
  )

  # Row 1: both valid, should be 50
  expect_equal(result$composite_index[1], 50)

  # Row 2: one NA, should use only indicateur_w3_humidite_norm = 40
  expect_equal(result$composite_index[2], 40)

  # Row 3: one NA, should use only indicateur_c1_biomasse_norm = 60
  expect_equal(result$composite_index[3], 60)

  # Row 4: both valid, should be 70
  expect_equal(result$composite_index[4], 70)
})

test_that("create_composite_index errors on missing indicators", {
  test_data <- data.frame(id = 1:3, indicateur_c1_biomasse_norm = c(0, 50, 100))

  expect_error(
    create_composite_index(
      test_data,
      indicators = c("indicateur_c1_biomasse_norm", "missing_indicator")
    ),
    "Indicators missing"
  )
})

test_that("create_composite_index errors on mismatched weights", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(0, 50, 100),
    indicateur_w3_humidite_norm = c(0, 50, 100)
  )

  expect_error(
    create_composite_index(
      test_data,
      indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
      weights = c(0.5) # Only 1 weight for 2 indicators
    ),
    "must match"
  )
})

test_that("create_composite_index errors on negative weights", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_c1_biomasse_norm = c(0, 50, 100),
    indicateur_w3_humidite_norm = c(0, 50, 100)
  )

  expect_error(
    create_composite_index(
      test_data,
      indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
      weights = c(0.6, -0.4)
    ),
    "non-negative"
  )
})

test_that("invert_indicator inverts values correctly", {
  test_data <- data.frame(
    id = 1:5,
    indicateur_s2_bati_norm = c(0, 25, 50, 75, 100)
  )

  inverted <- invert_indicator(
    test_data,
    indicators = "indicateur_s2_bati_norm",
    scale = 100
  )

  expect_true("indicateur_s2_bati_norm_inv" %in% names(inverted))

  # Check inversion
  expect_equal(inverted$indicateur_s2_bati_norm_inv[1], 100) # 0 becomes 100
  expect_equal(inverted$indicateur_s2_bati_norm_inv[3], 50) # 50 stays 50
  expect_equal(inverted$indicateur_s2_bati_norm_inv[5], 0) # 100 becomes 0
})

test_that("invert_indicator can remove original", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_s2_bati_norm = c(0, 50, 100)
  )

  inverted <- invert_indicator(
    test_data,
    indicators = "indicateur_s2_bati_norm",
    keep_original = FALSE
  )

  expect_false("indicateur_s2_bati_norm" %in% names(inverted))
  expect_true("indicateur_s2_bati_norm_inv" %in% names(inverted))
})

test_that("invert_indicator accepts custom suffix", {
  test_data <- data.frame(
    id = 1:3,
    indicateur_s2_bati_norm = c(0, 50, 100)
  )

  inverted <- invert_indicator(
    test_data,
    indicators = "indicateur_s2_bati_norm",
    suffix = "_wilderness"
  )

  expect_true("indicateur_s2_bati_norm_wilderness" %in% names(inverted))
})

test_that("full normalization workflow works end-to-end", {
  # Create test data with indicators
  units <- nemeton_units(create_test_units(n_features = 5))
  units$indicateur_c1_biomasse <- c(100, 200, 300, 400, 500)
  units$indicateur_b1_protection <- c(10, 20, 30, 40, 50)
  units$indicateur_w3_humidite <- c(5, 15, 25, 35, 45)
  units$indicateur_s2_bati <- c(20, 40, 60, 80, 100)

  # Step 1: Normalize
  normalized <- normalize_indicators(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_b1_protection", "indicateur_w3_humidite", "indicateur_s2_bati"),
    method = "minmax"
  )

  expect_s3_class(normalized, "nemeton_units")
  expect_true(all(c("indicateur_c1_biomasse_norm", "indicateur_b1_protection_norm", "indicateur_w3_humidite_norm", "indicateur_s2_bati_norm") %in% names(normalized)))

  # Step 2: Invert accessibility for wilderness index
  normalized <- invert_indicator(
    normalized,
    indicators = "indicateur_s2_bati_norm",
    suffix = "_wilderness",
    keep_original = TRUE
  )

  expect_true("indicateur_s2_bati_norm_wilderness" %in% names(normalized))

  # Step 3: Create ecosystem health composite
  result <- create_composite_index(
    normalized,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_b1_protection_norm", "indicateur_w3_humidite_norm"),
    weights = c(0.4, 0.4, 0.2),
    name = "ecosystem_health"
  )

  expect_true("ecosystem_health" %in% names(result))

  # Step 4: Create wilderness index
  result <- create_composite_index(
    result,
    indicators = c("indicateur_b1_protection_norm", "indicateur_s2_bati_norm_wilderness"),
    weights = c(0.5, 0.5),
    name = "wilderness_index"
  )

  expect_true("wilderness_index" %in% names(result))

  # Check metadata was preserved
  meta <- attr(result, "metadata")
  expect_true("normalized_at" %in% names(meta))
  expect_true("composite_index_created_at" %in% names(meta))
})
# ==============================================================================
# v0.3.0: Tests for new family indicators (B, R, T, A)
# ==============================================================================

test_that("normalize_indicators recognizes B* (Biodiversity) indicators", {
  test_data <- data.frame(
    id = 1:5,
    B1 = c(0, 25, 50, 75, 100), # Protection coverage
    B2 = c(0.2, 0.4, 0.6, 0.8, 1.0), # Structural diversity
    B3 = c(100, 200, 500, 1000, 2000) # Connectivity distance
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("B1", "B2", "B3"),
    method = "minmax"
  )

  expect_true(all(c("B1_norm", "B2_norm", "B3_norm") %in% names(normalized)))
  expect_true(all(normalized$B1_norm >= 0 & normalized$B1_norm <= 100))
  expect_true(all(normalized$B2_norm >= 0 & normalized$B2_norm <= 100))
  expect_true(all(normalized$B3_norm >= 0 & normalized$B3_norm <= 100))
})

test_that("normalize_indicators recognizes R* (Risk/Resilience) indicators", {
  test_data <- data.frame(
    id = 1:5,
    R1 = c(10, 30, 50, 70, 90), # Fire risk
    R2 = c(5, 25, 45, 65, 85), # Storm vulnerability
    R3 = c(15, 35, 55, 75, 95) # Drought stress
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("R1", "R2", "R3"),
    method = "minmax"
  )

  expect_true(all(c("R1_norm", "R2_norm", "R3_norm") %in% names(normalized)))
  expect_true(all(normalized$R1_norm >= 0 & normalized$R1_norm <= 100))
})

test_that("normalize_indicators recognizes T* (Temporal) indicators", {
  test_data <- data.frame(
    id = 1:5,
    T1 = c(20, 50, 100, 150, 250), # Stand age
    T2 = c(0, 0.5, 1.0, 2.0, 5.0) # Change rate
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("T1", "T2"),
    method = "minmax"
  )

  expect_true(all(c("T1_norm", "T2_norm") %in% names(normalized)))
  expect_true(all(normalized$T1_norm >= 0 & normalized$T1_norm <= 100))
})

test_that("normalize_indicators recognizes A* (Air quality) indicators", {
  test_data <- data.frame(
    id = 1:5,
    A1 = c(10, 30, 50, 70, 90), # Tree coverage
    A2 = c(20, 40, 60, 80, 100) # Air quality index
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("A1", "A2"),
    method = "minmax"
  )

  expect_true(all(c("A1_norm", "A2_norm") %in% names(normalized)))
  expect_true(all(normalized$A1_norm >= 0 & normalized$A1_norm <= 100))
})

test_that("normalize_indicators auto-detects all v0.3.0 family indicators", {
  test_data <- data.frame(
    id = 1:3,
    # v0.2.0 families
    C1 = c(100, 200, 300),
    W1 = c(10, 20, 30),
    F1 = c(5, 10, 15),
    L1 = c(0.3, 0.5, 0.7),
    # v0.3.0 families
    B1 = c(25, 50, 75),
    R1 = c(30, 50, 70),
    T1 = c(50, 100, 150),
    A1 = c(40, 60, 80),
    # Non-indicator column
    other = c(1, 2, 3)
  )

  # Should auto-detect all indicator families, ignore 'other'
  normalized <- normalize_indicators(test_data, method = "minmax")

  # Check all families detected
  expected_norms <- c(
    "C1_norm", "W1_norm", "F1_norm", "L1_norm",
    "B1_norm", "R1_norm", "T1_norm", "A1_norm"
  )
  expect_true(all(expected_norms %in% names(normalized)))
  expect_false("other_norm" %in% names(normalized))
})

test_that("normalize_indicators applies correct method for each family", {
  test_data <- data.frame(
    id = 1:10,
    B1 = runif(10, 0, 100), # Linear scale (0-100%)
    T1 = runif(10, 20, 300), # Log scale (age in years)
    R1 = runif(10, 0, 100) # Linear scale (0-100 risk)
  )

  # All should use minmax by default
  normalized <- normalize_indicators(test_data, method = "minmax")

  # Check all normalized
  expect_true(all(c("B1_norm", "T1_norm", "R1_norm") %in% names(normalized)))

  # All should be in 0-100 range after normalization
  expect_true(all(normalized$B1_norm >= 0 & normalized$B1_norm <= 100))
  expect_true(all(normalized$T1_norm >= 0 & normalized$T1_norm <= 100))
  expect_true(all(normalized$R1_norm >= 0 & normalized$R1_norm <= 100))
})

test_that("normalize_indicators handles mixed v0.2.0 and v0.3.0 families", {
  test_data <- data.frame(
    id = 1:5,
    C1 = c(100, 200, 300, 400, 500), # v0.2.0
    B1 = c(0, 25, 50, 75, 100), # v0.3.0
    R2 = c(10, 30, 50, 70, 90) # v0.3.0
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("C1", "B1", "R2"),
    method = "minmax"
  )

  expect_true(all(c("C1_norm", "B1_norm", "R2_norm") %in% names(normalized)))
  expect_equal(normalized$C1_norm[1], 0)
  expect_equal(normalized$C1_norm[5], 100)
  expect_equal(normalized$B1_norm[1], 0)
  expect_equal(normalized$B1_norm[5], 100)
})

# ==============================================================================
# Coverage expansion: uncovered paths in normalization.R
# ==============================================================================

# --- normalize_vector (internal) ---

test_that("normalize_vector quantile method returns percentile ranks", {
  result <- nemeton:::normalize_vector(c(10, 20, 30, 40, 50), method = "quantile")
  # Each value's percentile rank
  expect_equal(result[1], 20)  # 1/5 = 0.2 * 100
  expect_equal(result[5], 100) # 5/5 = 1.0 * 100
  expect_length(result, 5)
})

test_that("normalize_vector quantile method handles NAs in input", {
  result <- nemeton:::normalize_vector(c(10, NA, 30, 40, 50), method = "quantile")
  expect_true(is.na(result[2]))
  expect_false(is.na(result[1]))
  expect_false(is.na(result[5]))
})

test_that("normalize_vector quantile method with separate reference", {
  # Reference has different range than input
  ref <- c(0, 25, 50, 75, 100)
  result <- nemeton:::normalize_vector(c(50, 100), method = "quantile", reference = ref)
  # 50 is <= by 3 of 5 ref values -> 60
  expect_equal(result[1], 60)
  # 100 is <= by all 5 ref values -> 100
  expect_equal(result[2], 100)
})

test_that("normalize_vector quantile method with all-NA reference returns NAs", {
  result <- nemeton:::normalize_vector(c(10, 20), method = "quantile", reference = c(NA, NA, NA))
  expect_true(all(is.na(result)))
})

test_that("normalize_vector minmax with all-NA reference returns NAs", {
  result <- nemeton:::normalize_vector(c(10, 20), method = "minmax", reference = c(NA_real_, NA_real_))
  expect_true(all(is.na(result)))
})

test_that("normalize_vector zscore with zero sd returns zeros", {
  expect_warning(
    result <- nemeton:::normalize_vector(c(50, 50, 50), method = "zscore"),
    "0|zero"
  )
  expect_true(all(result == 0))
})

# --- normalize_indicators: by_family=TRUE path ---

test_that("normalize_indicators with by_family=TRUE normalizes in-place", {
  test_data <- data.frame(
    id = 1:5,
    C1 = c(10, 20, 30, 40, 50),
    C2 = c(100, 200, 300, 400, 500)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = c("C1", "C2"),
    method = "minmax",
    by_family = TRUE
  )

  # When by_family=TRUE with default suffix, suffix becomes "" and keep_original=FALSE

  # So values are replaced in-place
  expect_true("C1" %in% names(normalized))
  expect_true("C2" %in% names(normalized))
  # Values should now be normalized 0-100
  expect_equal(min(normalized$C1), 0)
  expect_equal(max(normalized$C1), 100)
  expect_equal(min(normalized$C2), 0)
  expect_equal(max(normalized$C2), 100)
})

test_that("normalize_indicators by_family=TRUE with explicit suffix uses that suffix", {
  test_data <- data.frame(
    id = 1:3,
    C1 = c(10, 20, 30)
  )

  normalized <- normalize_indicators(
    test_data,
    indicators = "C1",
    method = "minmax",
    by_family = TRUE,
    suffix = "_scaled"
  )

  # Explicit suffix overrides the default "_norm" -> "" behavior
  expect_true("C1_scaled" %in% names(normalized))
})

# --- normalize_indicators: reference_data with missing indicator ---

test_that("normalize_indicators warns when reference_data missing an indicator", {
  reference <- data.frame(
    C1 = c(0, 25, 50, 75, 100)
  )

  new_data <- data.frame(
    id = 1:3,
    C1 = c(10, 50, 90),
    W1 = c(5, 15, 25)
  )

  # W1 is missing from reference_data, should produce a warning
  expect_warning(
    normalized <- normalize_indicators(
      new_data,
      indicators = c("C1", "W1"),
      reference_data = reference,
      method = "minmax"
    ),
    "missing|manquant"
  )

  # Should still produce normalized columns
  expect_true("C1_norm" %in% names(normalized))
  expect_true("W1_norm" %in% names(normalized))
})

# --- normalize_indicators: auto-detect with no indicators found ---

test_that("normalize_indicators errors when auto-detect finds no indicators", {
  test_data <- data.frame(
    id = 1:3,
    name = c("a", "b", "c"),
    score = c(10, 20, 30)  # Not matching any known indicator pattern
  )

  expect_error(
    normalize_indicators(test_data, method = "minmax"),
    "indicator|indicateur"
  )
})

# --- normalize_indicators: preserves nemeton_units metadata ---

test_that("normalize_indicators preserves and updates nemeton_units metadata", {
  units <- nemeton_units(create_test_units())
  units$C1 <- c(10, 20, 30)

  normalized <- normalize_indicators(units, indicators = "C1", method = "minmax")

  # Check metadata was updated
  meta <- attr(normalized, "metadata")
  expect_true("normalized_at" %in% names(meta))
  expect_equal(meta$normalization_method, "minmax")
  expect_equal(meta$normalized_indicators, "C1")
  expect_s3_class(normalized, "nemeton_units")
})

# --- create_composite_index: geometric_mean with different values ---

test_that("create_composite_index geometric_mean with different indicator values", {
  test_data <- data.frame(
    id = 1:3,
    ind1 = c(16, 25, 100),
    ind2 = c(4, 100, 100)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("ind1", "ind2"),
    aggregation = "geometric_mean"
  )

  # Geometric mean of (16, 4) with equal weights: exp(0.5*log(16) + 0.5*log(4)) = exp(0.5*2.77 + 0.5*1.39) = exp(2.08) = 8
  expect_equal(result$composite_index[1], sqrt(16 * 4), tolerance = 0.01)
  # Geometric mean of (25, 100): sqrt(25*100) = sqrt(2500) = 50
  expect_equal(result$composite_index[2], 50, tolerance = 0.01)
  # Geometric mean of (100, 100) = 100
  expect_equal(result$composite_index[3], 100, tolerance = 0.01)
})

test_that("create_composite_index geometric_mean with NA values", {
  test_data <- data.frame(
    id = 1:3,
    ind1 = c(25, NA, 50),
    ind2 = c(25, 50, NA)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("ind1", "ind2"),
    aggregation = "geometric_mean",
    na.rm = TRUE
  )

  # Row 2: NA removed, only ind2=50 -> result should be based on remaining
  expect_false(is.na(result$composite_index[1]))
})

# --- create_composite_index: with sf data ---

test_that("create_composite_index works with sf data", {
  units <- create_test_units()
  units$ind1_norm <- c(40, 60, 80)
  units$ind2_norm <- c(60, 40, 20)

  result <- create_composite_index(
    units,
    indicators = c("ind1_norm", "ind2_norm")
  )

  expect_s3_class(result, "sf")
  expect_true("composite_index" %in% names(result))
  # Equal weights: (40+60)/2=50, (60+40)/2=50, (80+20)/2=50
  expect_equal(result$composite_index, c(50, 50, 50))
})

# --- create_composite_index: with nemeton_units preserving metadata ---

test_that("create_composite_index preserves nemeton_units metadata", {
  units <- nemeton_units(create_test_units())
  units$C1_norm <- c(40, 60, 80)
  units$W1_norm <- c(60, 40, 20)

  result <- create_composite_index(
    units,
    indicators = c("C1_norm", "W1_norm"),
    name = "forest_health"
  )

  expect_s3_class(result, "nemeton_units")
  meta <- attr(result, "metadata")
  expect_true("composite_index_created_at" %in% names(meta))
  expect_equal(meta$composite_index_name, "forest_health")
  expect_equal(meta$composite_index_method, "weighted_mean")
  expect_equal(meta$composite_index_indicators, c("C1_norm", "W1_norm"))
})

# --- create_composite_index: scale_to_100 with non-weighted_mean ---

test_that("create_composite_index scale_to_100 works with min aggregation", {
  test_data <- data.frame(
    id = 1:4,
    ind1 = c(20, 40, 60, 80),
    ind2 = c(30, 50, 70, 90)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("ind1", "ind2"),
    aggregation = "min",
    scale_to_100 = TRUE
  )

  # Min values: 20, 40, 60, 80
  # Scaled to 0-100: (20-20)/(80-20)*100=0, (40-20)/60*100=33.33, (60-20)/60*100=66.67, (80-20)/60*100=100
  expect_equal(result$composite_index[1], 0, tolerance = 0.01)
  expect_equal(result$composite_index[4], 100, tolerance = 0.01)
})

test_that("create_composite_index scale_to_100 works with max aggregation", {
  test_data <- data.frame(
    id = 1:4,
    ind1 = c(20, 40, 60, 80),
    ind2 = c(10, 30, 50, 90)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("ind1", "ind2"),
    aggregation = "max",
    scale_to_100 = TRUE
  )

  # Max values: 20, 40, 60, 90
  # Scaled to 0-100: min=20, max=90, range=70
  expect_equal(result$composite_index[1], 0, tolerance = 0.01)
  expect_equal(result$composite_index[4], 100, tolerance = 0.01)
})

test_that("create_composite_index scale_to_100 works with geometric_mean aggregation", {
  test_data <- data.frame(
    id = 1:3,
    ind1 = c(10, 50, 100),
    ind2 = c(10, 50, 100)
  )

  result <- create_composite_index(
    test_data,
    indicators = c("ind1", "ind2"),
    aggregation = "geometric_mean",
    scale_to_100 = TRUE
  )

  # Geometric means: 10, 50, 100 (same values)
  # Scaled to 0-100
  expect_equal(result$composite_index[1], 0, tolerance = 0.01)
  expect_equal(result$composite_index[3], 100, tolerance = 0.01)
})

test_that("create_composite_index default scale_to_100 is FALSE for non-weighted_mean", {
  test_data <- data.frame(
    id = 1:3,
    ind1 = c(20, 50, 80),
    ind2 = c(30, 60, 70)
  )

  # Default scale_to_100 for min should be FALSE
  result <- create_composite_index(
    test_data,
    indicators = c("ind1", "ind2"),
    aggregation = "min"
  )

  # Min values: 20, 50, 70 (not scaled to 0-100)
  expect_equal(result$composite_index[1], 20)
  expect_equal(result$composite_index[2], 50)
  expect_equal(result$composite_index[3], 70)
})

# --- invert_indicator: missing indicators error ---

test_that("invert_indicator errors on missing indicators", {
  test_data <- data.frame(
    id = 1:3,
    C1_norm = c(0, 50, 100)
  )

  expect_error(
    invert_indicator(test_data, indicators = "nonexistent_column"),
    "missing|manquant|Indicators"
  )
})

# --- invert_indicator: keep_original=TRUE preserves originals ---

test_that("invert_indicator keep_original=TRUE preserves original columns", {
  test_data <- data.frame(
    id = 1:3,
    social_norm = c(10, 50, 90)
  )

  inverted <- invert_indicator(
    test_data,
    indicators = "social_norm",
    scale = 100,
    keep_original = TRUE
  )

  # Both original and inverted should be present
  expect_true("social_norm" %in% names(inverted))
  expect_true("social_norm_inv" %in% names(inverted))
  # Inverted values
  expect_equal(inverted$social_norm_inv, c(90, 50, 10))
  # Original preserved
  expect_equal(inverted$social_norm, c(10, 50, 90))
})

# --- invert_indicator: multiple indicators at once ---

test_that("invert_indicator inverts multiple indicators", {
  test_data <- data.frame(
    id = 1:3,
    A1_norm = c(0, 50, 100),
    A2_norm = c(20, 60, 80)
  )

  inverted <- invert_indicator(
    test_data,
    indicators = c("A1_norm", "A2_norm"),
    scale = 100
  )

  expect_true("A1_norm_inv" %in% names(inverted))
  expect_true("A2_norm_inv" %in% names(inverted))
  expect_equal(inverted$A1_norm_inv, c(100, 50, 0))
  expect_equal(inverted$A2_norm_inv, c(80, 40, 20))
})

# ==============================================================================
# (migrated from test-cov80-batch13.R)
# ==============================================================================

# --- normalize_indicators() ---

test_that("normalize_indicators() minmax with explicit indicators scales to 0-100", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)
  units$indicateur_w3_humidite <- c(100, 200, 300, 400, 500)

  result <- nemeton::normalize_indicators(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    method = "minmax"
  )

  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
  expect_true("indicateur_w3_humidite_norm" %in% names(result))
  expect_equal(min(result$indicateur_c1_biomasse_norm), 0)
  expect_equal(max(result$indicateur_c1_biomasse_norm), 100)
  expect_equal(result$indicateur_c1_biomasse_norm[3], 50)
  expect_equal(min(result$indicateur_w3_humidite_norm), 0)
  expect_equal(max(result$indicateur_w3_humidite_norm), 100)
})

test_that("normalize_indicators() zscore method centers around 0 with sd=1", {
  set.seed(42)
  units <- create_test_units(n_features = 20)
  units$indicateur_c1_biomasse <- rnorm(20, mean = 50, sd = 10)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "zscore"
  )

  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
  expect_true(abs(mean(result$indicateur_c1_biomasse_norm)) < 0.01)
  expect_true(abs(sd(result$indicateur_c1_biomasse_norm) - 1) < 0.01)
})

test_that("normalize_indicators() quantile method produces 0-100 ranks", {
  units <- create_test_units(n_features = 10)
  units$indicateur_c1_biomasse <- seq(10, 100, by = 10)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "quantile"
  )

  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
  # The lowest value should get the lowest rank
  expect_equal(result$indicateur_c1_biomasse_norm[1], 10) # 1/10 * 100 = 10
  # The highest value should get rank 100
  expect_equal(result$indicateur_c1_biomasse_norm[10], 100) # 10/10 * 100 = 100
  # All should be in [0, 100]
  expect_true(all(result$indicateur_c1_biomasse_norm >= 0 & result$indicateur_c1_biomasse_norm <= 100))
})

test_that("normalize_indicators() auto-detects known indicator columns", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)
  units$indicateur_w3_humidite <- c(5, 10, 15, 20, 25)
  units$random_col <- c(1, 2, 3, 4, 5) # Should NOT be auto-detected

  result <- nemeton::normalize_indicators(units, method = "minmax")

  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
  expect_true("indicateur_w3_humidite_norm" %in% names(result))
  expect_false("random_col_norm" %in% names(result))
})

test_that("normalize_indicators() auto-detects family indicators (C1, W1, etc.)", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(10, 20, 30, 40, 50)
  units$W1 <- c(5, 10, 15, 20, 25)
  units$B2 <- c(1, 2, 3, 4, 5)
  units$not_indicator <- c(100, 200, 300, 400, 500)


  result <- nemeton::normalize_indicators(units, method = "minmax")

  expect_true("C1_norm" %in% names(result))
  expect_true("W1_norm" %in% names(result))
  expect_true("B2_norm" %in% names(result))
  expect_false("not_indicator_norm" %in% names(result))
})

test_that("normalize_indicators() auto-detects famille_ columns", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- c(10, 20, 30, 40, 50)
  units$famille_eau <- c(5, 10, 15, 20, 25)

  result <- nemeton::normalize_indicators(units, method = "minmax")

  expect_true("famille_carbone_norm" %in% names(result))
  expect_true("famille_eau_norm" %in% names(result))
})

test_that("normalize_indicators() by_family=TRUE changes suffix to '' and keep_original=FALSE", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(10, 20, 30, 40, 50)
  units$W1 <- c(5, 10, 15, 20, 25)

  result <- nemeton::normalize_indicators(
    units,
    indicators = c("C1", "W1"),
    method = "minmax",
    by_family = TRUE
  )

  # When by_family=TRUE and suffix="_norm" (default), suffix becomes "" and keep_original=FALSE

  # So columns should be replaced in place with normalized values
  expect_true("C1" %in% names(result))
  expect_true("W1" %in% names(result))
  # The values should be normalized (0-100)
  expect_equal(min(result$C1), 0)
  expect_equal(max(result$C1), 100)
})

test_that("normalize_indicators() with reference_data uses external parameters", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(20, 30, 40, 50, 60)

  ref <- data.frame(indicateur_c1_biomasse = c(0, 100))

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "minmax",
    reference_data = ref
  )

  # With reference range 0-100, value 20 should become 20, 60 should become 60
  expect_equal(result$indicateur_c1_biomasse_norm[1], 20)
  expect_equal(result$indicateur_c1_biomasse_norm[5], 60)
})

test_that("normalize_indicators() warns when reference_data missing indicator", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  ref <- data.frame(other_col = c(0, 100))

  # Should warn about missing indicator in reference, then fall back to using own values
  expect_warning(
    result <- nemeton::normalize_indicators(
      units,
      indicators = "indicateur_c1_biomasse",
      method = "minmax",
      reference_data = ref
    ),
    class = "rlang_warning"
  )
})

test_that("normalize_indicators() errors on missing indicator columns", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  expect_error(
    nemeton::normalize_indicators(
      units,
      indicators = c("indicateur_c1_biomasse", "nonexistent_col"),
      method = "minmax"
    )
  )
})

test_that("normalize_indicators() errors when no indicators found", {
  units <- create_test_units(n_features = 5)
  units$random_x <- c(1, 2, 3, 4, 5)
  units$random_y <- c(10, 20, 30, 40, 50)

  expect_error(
    nemeton::normalize_indicators(units, method = "minmax")
  )
})

test_that("normalize_indicators() suffix parameter customizes column names", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "minmax",
    suffix = "_z"
  )

  expect_true("indicateur_c1_biomasse_z" %in% names(result))
  expect_false("indicateur_c1_biomasse_norm" %in% names(result))
})

test_that("normalize_indicators() keep_original=TRUE keeps originals", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "minmax",
    keep_original = TRUE
  )

  expect_true("indicateur_c1_biomasse" %in% names(result))
  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
  expect_equal(result$indicateur_c1_biomasse, c(10, 20, 30, 40, 50))
})

test_that("normalize_indicators() keep_original=FALSE removes originals", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "minmax",
    keep_original = FALSE,
    suffix = "_norm"
  )

  # When keep_original=FALSE and suffix != "", original is removed
  expect_false("indicateur_c1_biomasse" %in% names(result))
  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
})

test_that("normalize_indicators() preserves sf class", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "minmax"
  )

  expect_s3_class(result, "sf")
  expect_true(!is.null(sf::st_geometry(result)))
})

test_that("normalize_indicators() preserves nemeton_units class metadata", {
  units <- create_test_units(n_features = 5)
  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Test Forest", year = 2024)
  )
  nu$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)

  result <- nemeton::normalize_indicators(
    nu,
    indicators = "indicateur_c1_biomasse",
    method = "minmax"
  )

  expect_s3_class(result, "nemeton_units")
  meta <- attr(result, "metadata")
  expect_equal(meta$site_name, "Test Forest")
  expect_equal(meta$year, 2024)
  expect_equal(meta$normalization_method, "minmax")
  expect_true(!is.null(meta$normalized_at))
  expect_equal(meta$normalized_indicators, "indicateur_c1_biomasse")
})

# --- normalize_vector() (internal) ---

test_that("normalize_vector() minmax with normal range produces 0-100", {
  result <- nemeton:::normalize_vector(
    x = c(10, 20, 30, 40, 50),
    method = "minmax"
  )

  expect_equal(result[1], 0)
  expect_equal(result[5], 100)
  expect_equal(result[3], 50)
})

test_that("normalize_vector() minmax with all identical values returns 50", {
  result <- suppressWarnings(
    nemeton:::normalize_vector(
      x = c(5, 5, 5, 5),
      method = "minmax"
    )
  )

  expect_equal(result, rep(50, 4))
})

test_that("normalize_vector() minmax with all NA reference returns NA", {
  result <- nemeton:::normalize_vector(
    x = c(1, 2, 3),
    method = "minmax",
    reference = c(NA_real_, NA_real_, NA_real_)
  )

  expect_true(all(is.na(result)))
})

test_that("normalize_vector() zscore produces mean~0, sd~1", {
  set.seed(42)
  x <- rnorm(100, mean = 50, sd = 10)

  result <- nemeton:::normalize_vector(x, method = "zscore")

  expect_true(abs(mean(result)) < 0.01)
  expect_true(abs(sd(result) - 1) < 0.01)
})

test_that("normalize_vector() zscore with sd=0 returns 0", {
  result <- suppressWarnings(
    nemeton:::normalize_vector(
      x = c(5, 5, 5, 5),
      method = "zscore"
    )
  )

  expect_equal(result, rep(0, 4))
})

test_that("normalize_vector() quantile produces percentile ranks", {
  result <- nemeton:::normalize_vector(
    x = c(10, 20, 30, 40, 50),
    method = "quantile"
  )

  # 10 is <= 1/5 of values -> 20%
  expect_equal(result[1], 20)
  # 50 is <= 5/5 of values -> 100%
  expect_equal(result[5], 100)
  expect_true(all(result >= 0 & result <= 100))
})

test_that("normalize_vector() quantile with NAs returns NA for NA inputs", {
  result <- nemeton:::normalize_vector(
    x = c(10, NA, 30, NA, 50),
    method = "quantile"
  )

  expect_true(is.na(result[2]))
  expect_true(is.na(result[4]))
  expect_false(is.na(result[1]))
  expect_false(is.na(result[3]))
  expect_false(is.na(result[5]))
})

test_that("normalize_vector() quantile with empty reference returns NA", {
  # All NA in reference -> ref_clean is empty
  result <- nemeton:::normalize_vector(
    x = c(1, 2, 3),
    method = "quantile",
    reference = c(NA_real_, NA_real_)
  )

  expect_true(all(is.na(result)))
})

# --- Additional edge cases ---

test_that("normalize_indicators() on plain data.frame (not sf)", {
  df <- data.frame(
    indicateur_c1_biomasse = c(10, 20, 30, 40, 50),
    indicateur_w3_humidite = c(5, 10, 15, 20, 25)
  )

  result <- nemeton::normalize_indicators(
    df,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    method = "minmax"
  )

  expect_true("indicateur_c1_biomasse_norm" %in% names(result))
  expect_true("indicateur_w3_humidite_norm" %in% names(result))
  expect_false(inherits(result, "sf"))
})

test_that("normalize_vector() minmax with separate reference range", {
  x <- c(20, 40, 60)
  ref <- c(0, 100)

  result <- nemeton:::normalize_vector(x, method = "minmax", reference = ref)

  expect_equal(result[1], 20)
  expect_equal(result[2], 40)
  expect_equal(result[3], 60)
})

test_that("normalize_vector() zscore with separate reference", {
  x <- c(50, 60, 70)
  ref <- c(0, 20, 40, 60, 80, 100)

  result <- nemeton:::normalize_vector(x, method = "zscore", reference = ref)

  ref_mean <- mean(ref)
  ref_sd <- sd(ref)
  expected <- (x - ref_mean) / ref_sd
  expect_equal(result, expected)
})
