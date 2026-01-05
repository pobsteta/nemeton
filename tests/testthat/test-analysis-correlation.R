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
  data(massif_demo_units, package = "nemeton")

  # Create dataset with multiple family indicators
  units <- massif_demo_units[1:10, ]
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)
  units$family_W <- runif(10, 35, 80)
  units$family_R <- runif(10, 25, 75)
  units$family_T <- runif(10, 45, 95)
  units$family_A <- runif(10, 50, 85)

  # Compute correlations
  result <- compute_family_correlations(units)

  # Test structure
  expect_true(is.matrix(result))
  expect_true(is.numeric(result))
  expect_equal(nrow(result), ncol(result))  # Square matrix
  expect_true(all(colnames(result) %in% c("family_C", "family_B", "family_W",
                                           "family_R", "family_T", "family_A")))

  # Test properties of correlation matrix
  expect_true(all(result >= -1 & result <= 1))  # Correlations in [-1, 1]
  expect_true(all(diag(result) == 1))  # Diagonal = 1
  expect_true(isSymmetric(result))  # Symmetric matrix
})

test_that("compute_family_correlations works with subset of families", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:8, ]
  units$family_C <- runif(8, 40, 90)
  units$family_B <- runif(8, 30, 85)
  units$family_W <- runif(8, 35, 80)

  # Compute for specific families only
  result <- compute_family_correlations(
    units,
    families = c("family_C", "family_B", "family_W")
  )

  expect_equal(nrow(result), 3)
  expect_equal(ncol(result), 3)
  expect_true(all(c("family_C", "family_B", "family_W") %in% colnames(result)))
})

test_that("compute_family_correlations supports different correlation methods", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)
  units$family_W <- runif(10, 35, 80)

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
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)
  units$family_B[c(3, 7)] <- NA  # Introduce NAs

  # Should work with na.rm equivalent
  result <- compute_family_correlations(units)

  expect_true(is.matrix(result))
  expect_true(all(is.finite(result) | is.na(result)))
})

test_that("compute_family_correlations auto-detects family columns", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)
  units$family_W <- runif(10, 35, 80)
  units$other_col <- runif(10)  # Non-family column

  # Auto-detect (families = NULL)
  result <- compute_family_correlations(units, families = NULL)

  expect_equal(nrow(result), 3)
  expect_false("other_col" %in% colnames(result))
  expect_true(all(grepl("^family_", colnames(result))))
})

# ==============================================================================
# T069: Unit Tests for identify_hotspots()
# ==============================================================================

test_that("identify_hotspots identifies parcels ranking high on multiple families", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:20, ]
  units$family_C <- runif(20, 40, 90)
  units$family_B <- runif(20, 30, 85)
  units$family_W <- runif(20, 35, 80)
  units$family_R <- runif(20, 25, 75)

  # Identify hotspots: top 20% in at least 3 families
  result <- identify_hotspots(
    units,
    threshold = 80,  # 80th percentile
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
  units$family_C <- c(rep(90, 3), rep(50, 12))  # 3 high, 12 low
  units$family_B <- c(rep(85, 3), rep(45, 12))
  units$family_W <- c(rep(88, 3), rep(48, 12))

  # Top 20% = 3 parcels
  result <- identify_hotspots(units, threshold = 80, min_families = 2)

  # First 3 parcels should be hotspots (high in all 3 families)
  expect_true(all(result$is_hotspot[1:3]))
  expect_true(sum(result$is_hotspot) >= 3)
})

test_that("identify_hotspots handles min_families parameter", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$family_C <- c(95, 90, 85, rep(50, 7))
  units$family_B <- c(92, 88, 50, rep(45, 7))
  units$family_W <- c(90, 50, 82, rep(48, 7))

  # min_families = 1: parcel high in ANY family
  result1 <- identify_hotspots(units, threshold = 80, min_families = 1)

  # min_families = 2: parcel high in ≥2 families
  result2 <- identify_hotspots(units, threshold = 80, min_families = 2)

  # min_families = 3: parcel high in all 3 families
  result3 <- identify_hotspots(units, threshold = 80, min_families = 3)

  expect_true(sum(result1$is_hotspot) >= sum(result2$is_hotspot))
  expect_true(sum(result2$is_hotspot) >= sum(result3$is_hotspot))
  expect_true(result3$is_hotspot[1])  # Parcel 1 high in all 3
})

test_that("identify_hotspots works with specific family subset", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)
  units$family_W <- runif(10, 35, 80)
  units$family_R <- runif(10, 25, 75)

  # Analyze only specific families
  result <- identify_hotspots(
    units,
    families = c("family_C", "family_B"),
    threshold = 70,
    min_families = 2
  )

  expect_s3_class(result, "sf")
  expect_true("is_hotspot" %in% names(result))
})

test_that("identify_hotspots returns hotspot_families as comma-separated list", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:8, ]
  units$family_C <- c(95, 90, 85, rep(50, 5))
  units$family_B <- c(92, 50, 88, rep(45, 5))
  units$family_W <- c(50, 91, 86, rep(48, 5))

  result <- identify_hotspots(units, threshold = 80, min_families = 1)

  # Parcel 1: high in C and B
  expect_true(grepl("family_C", result$hotspot_families[1]))
  expect_true(grepl("family_B", result$hotspot_families[1]))

  # Parcel 2: high in C and W
  expect_true(grepl("family_C", result$hotspot_families[2]))
  expect_true(grepl("family_W", result$hotspot_families[2]))
})

test_that("identify_hotspots handles no hotspots when threshold very high", {
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$family_C <- runif(10, 30, 50)  # Low-mid range
  units$family_B <- runif(10, 25, 45)  # Low-mid range

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
  data(massif_demo_units, package = "nemeton")

  # Simulate complete multi-family analysis
  units <- massif_demo_units[1:15, ]

  # Simulate family indices with realistic relationships
  set.seed(42)
  units$family_B <- runif(15, 30, 90)  # Biodiversity
  units$family_T <- 20 + 0.6 * units$family_B + rnorm(15, 0, 10)  # Age correlates with biodiversity
  units$family_R <- 100 - 0.3 * units$family_B + rnorm(15, 0, 15)  # Risk inversely correlated
  units$family_C <- 40 + 0.5 * units$family_T + rnorm(15, 0, 12)  # Carbon correlates with age
  units$family_W <- runif(15, 30, 80)  # Independent
  units$family_A <- runif(15, 40, 85)  # Independent

  # Step 1: Compute correlations
  corr_matrix <- compute_family_correlations(units)

  expect_true(is.matrix(corr_matrix))
  expect_equal(nrow(corr_matrix), 6)

  # Verify expected relationships
  expect_true(corr_matrix["family_B", "family_T"] > 0.3)  # Positive
  expect_true(corr_matrix["family_B", "family_R"] < 0)    # Negative

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
  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ]
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)

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
  units$family_B <- c(rep(85, 5), rep(45, 15))  # 5 high biodiversity
  units$family_T <- c(rep(90, 5), rep(40, 15))  # Same 5 high age
  units$family_C <- runif(20, 40, 70)           # Neutral

  # Correlation should be positive
  corr_matrix <- compute_family_correlations(units)
  expect_true(corr_matrix["family_B", "family_T"] > 0.5)

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
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)

  # Verify CRS is preserved
  original_crs <- st_crs(units)

  hotspots <- identify_hotspots(units, threshold = 70, min_families = 1)

  expect_equal(st_crs(hotspots), original_crs)
})

test_that("Functions work with tibble sf objects", {
  skip_if_not_installed("dplyr")

  data(massif_demo_units, package = "nemeton")

  units <- massif_demo_units[1:10, ] %>% dplyr::as_tibble() %>% sf::st_as_sf()
  units$family_C <- runif(10, 40, 90)
  units$family_B <- runif(10, 30, 85)

  result <- identify_hotspots(units, threshold = 70, min_families = 1)

  expect_s3_class(result, "sf")
})
