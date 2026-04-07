# test-analysis-correlation.R
# Unit and integration tests for Cross-Family Correlation Analysis
# MVP v0.3.0 - Multi-Family Indicator Extension

# Tests for:
# - compute_family_correlations()
# - identify_hotspots()
# - plot_correlation_matrix()

# TDD: Write tests FIRST, ensure they FAIL, then implement functions
# See spec.md User Story 6 for requirements

library(testthat)
library(sf)

# ==============================================================================
# T068: Unit Tests for compute_family_correlations()
# ==============================================================================

test_that("compute_family_correlations returns correlation matrix for family indices", {
  # Use clean test units to avoid conflicts with pre-existing family columns
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_eau <- runif(10, 35, 80)
  units$famille_risque <- runif(10, 25, 75)
  units$famille_temporel <- runif(10, 45, 95)
  units$famille_air <- runif(10, 50, 85)

  # Compute correlations
  result <- compute_family_correlations(units)

  # Test structure
  expect_true(is.matrix(result))
  expect_true(is.numeric(result))
  expect_equal(nrow(result), ncol(result)) # Square matrix
  expect_true(all(c("famille_carbone", "famille_biodiversite", "famille_eau", "famille_risque", "famille_temporel", "famille_air") %in% colnames(result)))

  # Test properties of correlation matrix
  expect_true(all(result >= -1 & result <= 1)) # Correlations in [-1, 1]
  expect_true(all(diag(result) == 1)) # Diagonal = 1
  expect_true(isSymmetric(result)) # Symmetric matrix
})

test_that("compute_family_correlations works with subset of families", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:8, ]
  units$famille_carbone <- runif(8, 40, 90)
  units$famille_biodiversite <- runif(8, 30, 85)
  units$famille_eau <- runif(8, 35, 80)

  # Compute for specific families only
  result <- compute_family_correlations(
    units,
    families = c("famille_carbone", "famille_biodiversite", "famille_eau")
  )

  expect_equal(nrow(result), 3)
  expect_equal(ncol(result), 3)
  expect_true(all(c("famille_carbone", "famille_biodiversite", "famille_eau") %in% colnames(result)))
})

test_that("compute_family_correlations supports different correlation methods", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_eau <- runif(10, 35, 80)

  # Pearson (default)
  result_pearson <- compute_family_correlations(units, method = "pearson")

  # Spearman
  result_spearman <- compute_family_correlations(units, method = "spearman")

  expect_true(is.matrix(result_pearson))
  expect_true(is.matrix(result_spearman))
  expect_equal(dim(result_pearson), dim(result_spearman))
})

test_that("compute_family_correlations handles NA values gracefully", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_biodiversite[c(3, 7)] <- NA # Introduce NAs

  # Should work with na.rm equivalent
  result <- compute_family_correlations(units)

  expect_true(is.matrix(result))
  expect_true(all(is.finite(result) | is.na(result)))
})

test_that("compute_family_correlations auto-detects family columns", {
  # Use clean test units to control exactly which family columns exist
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_eau <- runif(10, 35, 80)
  units$other_col <- runif(10) # Non-family column

  # Auto-detect (families = NULL)
  result <- compute_family_correlations(units, families = NULL)

  expect_equal(nrow(result), 3)
  expect_false("other_col" %in% colnames(result))
  expect_true(all(grepl("^famille_", colnames(result))))
})

# ==============================================================================
# T069: Unit Tests for identify_hotspots()
# ==============================================================================

test_that("identify_hotspots identifies parcels ranking high on multiple families", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:20, ]
  units$famille_carbone <- runif(20, 40, 90)
  units$famille_biodiversite <- runif(20, 30, 85)
  units$famille_eau <- runif(20, 35, 80)
  units$famille_risque <- runif(20, 25, 75)

  # Identify hotspots: top 20% in at least 3 families
  result <- identify_hotspots(
    units,
    threshold = 80, # 80th percentile
    min_families = 3
  )

  # Test structure
  expect_s3_class(result, "sf")
  expect_true("hotspot_count" %in% names(result))
  expect_true("hotspot_families" %in% names(result))
  expect_true("is_hotspot" %in% names(result))

  # Test logic
  expect_true(all(result$hotspot_count >= 0))
  expect_true(all(result$hotspot_count[result$is_hotspot] >= 3))
})

test_that("identify_hotspots respects threshold parameter", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:15, ]
  units$famille_carbone <- c(rep(90, 3), rep(50, 12)) # 3 high, 12 low
  units$famille_biodiversite <- c(rep(85, 3), rep(45, 12))
  units$famille_eau <- c(rep(88, 3), rep(48, 12))

  # Top 20% = 3 parcels
  result <- identify_hotspots(units, threshold = 80, min_families = 2)

  # First 3 parcels should be hotspots (high in all 3 families)
  expect_true(all(result$is_hotspot[1:3]))
  expect_true(sum(result$is_hotspot) >= 3)
})

test_that("identify_hotspots handles min_families parameter", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$famille_carbone <- c(95, 90, 85, rep(50, 7))
  units$famille_biodiversite <- c(92, 88, 50, rep(45, 7))
  units$famille_eau <- c(90, 50, 82, rep(48, 7))

  # min_families = 1: parcel high in ANY family
  result1 <- identify_hotspots(units, threshold = 80, min_families = 1)

  # min_families = 2: parcel high in ≥2 families
  result2 <- identify_hotspots(units, threshold = 80, min_families = 2)

  # min_families = 3: parcel high in all 3 families
  result3 <- identify_hotspots(units, threshold = 80, min_families = 3)

  expect_true(sum(result1$is_hotspot) >= sum(result2$is_hotspot))
  expect_true(sum(result2$is_hotspot) >= sum(result3$is_hotspot))
  expect_true(result3$is_hotspot[1]) # Parcel 1 high in all 3
})

test_that("identify_hotspots works with specific family subset", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_eau <- runif(10, 35, 80)
  units$famille_risque <- runif(10, 25, 75)

  # Analyze only specific families
  result <- identify_hotspots(
    units,
    families = c("famille_carbone", "famille_biodiversite"),
    threshold = 70,
    min_families = 2
  )

  expect_s3_class(result, "sf")
  expect_true("is_hotspot" %in% names(result))
})

test_that("identify_hotspots returns hotspot_families as comma-separated list", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:8, ]
  units$famille_carbone <- c(95, 90, 85, rep(50, 5))
  units$famille_biodiversite <- c(92, 50, 88, rep(45, 5))
  units$famille_eau <- c(50, 91, 86, rep(48, 5))

  result <- identify_hotspots(units, threshold = 80, min_families = 1)

  # Parcel 1: high in C and B
  expect_true(grepl("famille_carbone", result$hotspot_families[1]))
  expect_true(grepl("famille_biodiversite", result$hotspot_families[1]))

  # Parcel 2: high in C and W
  expect_true(grepl("famille_carbone", result$hotspot_families[2]))
  expect_true(grepl("famille_eau", result$hotspot_families[2]))
})

test_that("identify_hotspots handles no hotspots when threshold very high", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$famille_carbone <- runif(10, 30, 50) # Low-mid range
  units$famille_biodiversite <- runif(10, 25, 45) # Low-mid range

  # With 100th percentile threshold, no parcels can be above it
  result <- identify_hotspots(units, threshold = 100, min_families = 2)

  # No parcels should meet the criteria for 2+ families
  expect_true(all(!result$is_hotspot))
  expect_true(all(result$hotspot_count <= 1))
})

# ==============================================================================
# T070: Integration Test for Complete Workflow
# ==============================================================================

test_that("Complete workflow: correlation + hotspot identification", {
  # Use clean test units to control exactly which family columns exist
  units <- create_test_units(n_features = 15)

  # Simulate family indices with realistic relationships
  set.seed(42)
  units$famille_biodiversite <- runif(15, 30, 90) # Biodiversity
  units$famille_temporel <- 20 + 0.6 * units$famille_biodiversite + rnorm(15, 0, 10) # Age correlates with biodiversity
  units$famille_risque <- 100 - 0.3 * units$famille_biodiversite + rnorm(15, 0, 15) # Risk inversely correlated
  units$famille_carbone <- 40 + 0.5 * units$famille_temporel + rnorm(15, 0, 12) # Carbon correlates with age
  units$famille_eau <- runif(15, 30, 80) # Independent
  units$famille_air <- runif(15, 40, 85) # Independent

  # Step 1: Compute correlations
  corr_matrix <- compute_family_correlations(units)

  expect_true(is.matrix(corr_matrix))
  expect_equal(nrow(corr_matrix), 6)

  # Verify expected relationships
  expect_true(corr_matrix["famille_biodiversite", "famille_temporel"] > 0.3) # Positive
  expect_true(corr_matrix["famille_biodiversite", "famille_risque"] < 0) # Negative

  # Step 2: Identify hotspots
  hotspots <- identify_hotspots(
    units,
    threshold = 70,
    min_families = 3
  )

  expect_s3_class(hotspots, "sf")
  expect_true("is_hotspot" %in% names(hotspots))

  # At least some hotspots should be identified
  expect_true(sum(hotspots$is_hotspot) > 0)

  # Step 3: Verify hotspot properties
  if (sum(hotspots$is_hotspot) > 0) {
    hotspot_parcels <- hotspots[hotspots$is_hotspot, ]
    expect_true(all(hotspot_parcels$hotspot_count >= 3))
    expect_true(all(nchar(hotspot_parcels$hotspot_families) > 0))
  }
})

test_that("Workflow handles edge case: only 2 families available", {
  # Use clean test units to control exactly which family columns exist
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  # Should work with just 2 families
  corr_matrix <- compute_family_correlations(units)
  expect_equal(nrow(corr_matrix), 2)

  # Hotspots with min_families = 1
  hotspots <- identify_hotspots(units, threshold = 75, min_families = 1)
  expect_s3_class(hotspots, "sf")
})

test_that("Workflow detects biodiversity-age synergy (US6 acceptance scenario)", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:20, ]

  # Create deliberate synergy: high biodiversity + high age
  units$famille_biodiversite <- c(rep(85, 5), rep(45, 15)) # 5 high biodiversity
  units$famille_temporel <- c(rep(90, 5), rep(40, 15)) # Same 5 high age
  units$famille_carbone <- runif(20, 40, 70) # Neutral

  # Correlation should be positive
  corr_matrix <- compute_family_correlations(units)
  expect_true(corr_matrix["famille_biodiversite", "famille_temporel"] > 0.5)

  # Hotspots should identify the 5 parcels
  hotspots <- identify_hotspots(units, threshold = 80, min_families = 2)

  expect_true(sum(hotspots$is_hotspot) >= 5)
  expect_true(all(hotspots$is_hotspot[1:5]))
})

# ==============================================================================
# Additional Edge Cases
# ==============================================================================

test_that("Functions handle sf objects with CRS correctly", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  # Verify CRS is preserved
  original_crs <- st_crs(units)

  hotspots <- identify_hotspots(units, threshold = 70, min_families = 1)

  expect_equal(st_crs(hotspots), original_crs)
})

test_that("Functions work with tibble sf objects", {
  skip_if_not_installed("dplyr")

  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ] %>%
    dplyr::as_tibble() %>%
    sf::st_as_sf()
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  result <- identify_hotspots(units, threshold = 70, min_families = 1)

  expect_s3_class(result, "sf")
})

# ==============================================================================
# Additional coverage tests for uncovered lines
# ==============================================================================

# --- compute_family_correlations: specific families parameter ---

test_that("compute_family_correlations works with explicit families parameter", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_eau <- runif(10, 35, 80)

  result <- compute_family_correlations(
    units,
    families = c("famille_carbone", "famille_biodiversite")
  )

  expect_true(is.matrix(result))
  expect_equal(nrow(result), 2)
  expect_equal(ncol(result), 2)
  expect_true(all(c("famille_carbone", "famille_biodiversite") %in% colnames(result)))
  # famille_eau should NOT be included

  expect_false("famille_eau" %in% colnames(result))
})

# --- compute_family_correlations: spearman and kendall methods ---

test_that("compute_family_correlations works with spearman method", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  result <- compute_family_correlations(units, method = "spearman")

  expect_true(is.matrix(result))
  expect_equal(attr(result, "method"), "spearman")
})

test_that("compute_family_correlations works with kendall method", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  result <- compute_family_correlations(units, method = "kendall")

  expect_true(is.matrix(result))
  expect_equal(attr(result, "method"), "kendall")
})

# --- compute_family_correlations: missing families error ---

test_that("compute_family_correlations errors on missing families", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)

  expect_error(
    compute_family_correlations(units, families = c("famille_carbone", "family_MISSING")),
    "Families not found in data"
  )
})

# --- compute_family_correlations: non-numeric columns error ---

test_that("compute_family_correlations errors on non-numeric family columns", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- c("a", "b", "c", "d", "e")  # character, not numeric
  units$famille_biodiversite <- runif(5, 30, 85)

  expect_error(
    compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite")),
    "All family columns must be numeric"
  )
})

# --- identify_hotspots: auto-detect families (no families parameter) ---

test_that("identify_hotspots auto-detects family columns", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$other_col <- runif(10)  # should be ignored

  result <- identify_hotspots(units, threshold = 80, min_families = 1)

  expect_s3_class(result, "sf")
  expect_true("is_hotspot" %in% names(result))
  # other_col should not affect hotspot analysis
})

# --- identify_hotspots: threshold=100 (strict >) ---

test_that("identify_hotspots with threshold=100 uses strict greater-than", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  result <- identify_hotspots(
    units,
    families = c("famille_carbone", "famille_biodiversite"),
    threshold = 100,
    min_families = 1
  )

  expect_true("is_hotspot" %in% names(result))
  # With strict > at 100th percentile, no value can exceed the max
  expect_true(all(!result$is_hotspot))
  expect_true(all(result$hotspot_count == 0))
})

# --- identify_hotspots: all NA family values ---

test_that("identify_hotspots handles all-NA family values", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- rep(NA_real_, 5)
  units$famille_biodiversite <- runif(5, 30, 85)

  result <- identify_hotspots(
    units,
    families = c("famille_carbone", "famille_biodiversite"),
    threshold = 80,
    min_families = 1
  )

  expect_s3_class(result, "sf")
  expect_true("is_hotspot" %in% names(result))
  # All-NA family should produce NA thresholds; no parcels above NA threshold
})

# --- identify_hotspots: specific families parameter ---

test_that("identify_hotspots works with specific families parameter", {
  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)
  units$famille_eau <- runif(10, 35, 80)

  # Only analyze C and B, not W
  result <- identify_hotspots(
    units,
    families = c("famille_carbone", "famille_biodiversite"),
    threshold = 70,
    min_families = 1
  )

  expect_s3_class(result, "sf")
  # hotspot_families should never mention famille_eau
  expect_false(any(grepl("famille_eau", result$hotspot_families)))
})

# --- identify_hotspots: error on missing families ---

test_that("identify_hotspots errors on missing families", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- runif(5, 40, 90)

  expect_error(
    identify_hotspots(units, families = c("famille_carbone", "family_NONEXISTENT")),
    "Families not found in data"
  )
})

# --- identify_hotspots: error when no famille_ columns exist ---

test_that("identify_hotspots errors when no family columns found for auto-detect", {
  units <- create_test_units(n_features = 5)
  # No famille_ columns at all

  expect_error(
    identify_hotspots(units),
    "No family indices found"
  )
})

# --- plot_correlation_matrix: method="number" ---

test_that("plot_correlation_matrix works with method='number'", {
  skip_if_not_installed("ggplot2")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite"))
  p <- plot_correlation_matrix(cm, method = "number")

  expect_s3_class(p, "ggplot")
})

# --- plot_correlation_matrix: method="square" ---

test_that("plot_correlation_matrix works with method='square'", {
  skip_if_not_installed("ggplot2")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite"))
  p <- plot_correlation_matrix(cm, method = "square")

  expect_s3_class(p, "ggplot")
})

# --- plot_correlation_matrix: method="color" ---

test_that("plot_correlation_matrix works with method='color'", {
  skip_if_not_installed("ggplot2")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite"))
  p <- plot_correlation_matrix(cm, method = "color")

  expect_s3_class(p, "ggplot")
})

# --- plot_correlation_matrix: palette="viridis" ---

test_that("plot_correlation_matrix works with viridis palette", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("viridisLite")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite"))
  p <- plot_correlation_matrix(cm, palette = "viridis")

  expect_s3_class(p, "ggplot")
})

# --- plot_correlation_matrix: auto-generated title with method attribute ---

test_that("plot_correlation_matrix generates title from method attribute", {
  skip_if_not_installed("ggplot2")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, method = "spearman")
  p <- plot_correlation_matrix(cm, title = NULL)

  expect_s3_class(p, "ggplot")
  # Title should contain "Spearman"
  expect_true(grepl("Spearman", p$labels$title, ignore.case = TRUE))
})

# --- plot_correlation_matrix: custom title ---

test_that("plot_correlation_matrix uses custom title when provided", {
  skip_if_not_installed("ggplot2")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite"))
  p <- plot_correlation_matrix(cm, title = "My Custom Title")

  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "My Custom Title")
})

# --- plot_correlation_matrix: matrix without method attribute ---

test_that("plot_correlation_matrix handles matrix without method attribute", {
  skip_if_not_installed("ggplot2")

  # Create a plain matrix without the method attribute
  m <- matrix(c(1, 0.5, 0.5, 1), nrow = 2)
  colnames(m) <- c("famille_carbone", "famille_biodiversite")
  rownames(m) <- c("famille_carbone", "famille_biodiversite")

  p <- plot_correlation_matrix(m, title = NULL)

  expect_s3_class(p, "ggplot")
  # Should fallback to "pearson" as default
  expect_true(grepl("Pearson", p$labels$title, ignore.case = TRUE))
})

# --- plot_correlation_matrix: all methods via loop ---

test_that("plot_correlation_matrix supports all four display methods", {
  skip_if_not_installed("ggplot2")

  units <- create_test_units(n_features = 10)
  units$famille_carbone <- runif(10, 40, 90)
  units$famille_biodiversite <- runif(10, 30, 85)

  cm <- compute_family_correlations(units, families = c("famille_carbone", "famille_biodiversite"))

  for (m in c("circle", "square", "number", "color")) {
    p <- plot_correlation_matrix(cm, method = m)
    expect_s3_class(p, "ggplot")
  }
})

# --- plot_correlation_matrix: invalid method error ---

test_that("plot_correlation_matrix errors on invalid method", {
  m <- matrix(c(1, 0.5, 0.5, 1), nrow = 2)
  colnames(m) <- c("A", "B")
  rownames(m) <- c("A", "B")

  expect_error(
    plot_correlation_matrix(m, method = "invalid"),
    "method must be one of"
  )
})

# --- compute_family_correlations: no family columns error ---

test_that("compute_family_correlations errors when no family columns auto-detected", {
  units <- create_test_units(n_features = 5)
  # No famille_ columns

  expect_error(
    compute_family_correlations(units),
    "No family indices found"
  )
})

# --- compute_family_correlations: invalid method error ---

test_that("compute_family_correlations errors on invalid method", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- runif(5)

  expect_error(
    compute_family_correlations(units, method = "invalid"),
    "method must be one of"
  )
})

# --- compute_family_correlations: n_obs attribute ---

test_that("compute_family_correlations stores n_obs attribute", {
  units <- create_test_units(n_features = 8)
  units$famille_carbone <- runif(8, 40, 90)
  units$famille_biodiversite <- runif(8, 30, 85)

  result <- compute_family_correlations(units)

  expect_equal(attr(result, "n_obs"), 8)
  expect_equal(attr(result, "method"), "pearson")
})
