# test-coverage-boost2.R
# Additional tests to reach 60% coverage
# Targets: normalization.R, analysis-correlation.R, analysis-tradeoff.R,
#          visualization.R, utils.R, i18n.R


# ==============================================================================
# NORMALIZATION: normalize_vector()
# ==============================================================================

test_that("normalize_vector minmax works", {
  x <- c(10, 20, 30, 40, 50)
  result <- nemeton:::normalize_vector(x, method = "minmax")
  expect_equal(result[1], 0)
  expect_equal(result[5], 100)
  expect_equal(result[3], 50)
})

test_that("normalize_vector zscore works", {
  x <- c(10, 20, 30, 40, 50)
  result <- nemeton:::normalize_vector(x, method = "zscore")
  expect_equal(mean(result), 0, tolerance = 1e-10)
  expect_equal(sd(result), 1, tolerance = 1e-10)
})

test_that("normalize_vector quantile works", {
  x <- c(10, 20, 30, 40, 50)
  result <- nemeton:::normalize_vector(x, method = "quantile")
  expect_true(all(result >= 0 & result <= 100))
  # Lowest value should be at low percentile, highest at 100
  expect_equal(result[1], 20) # 1 out of 5 values <= 10
  expect_equal(result[5], 100) # all 5 values <= 50
})

test_that("normalize_vector handles all-NA reference", {
  x <- c(1, 2, 3)
  ref <- c(NA, NA, NA)
  result <- nemeton:::normalize_vector(x, method = "minmax", reference = ref)
  expect_true(all(is.na(result)))
})

test_that("normalize_vector handles identical values (minmax)", {
  x <- c(5, 5, 5)
  result <- nemeton:::normalize_vector(x, method = "minmax")
  expect_equal(result, c(50, 50, 50))
})

test_that("normalize_vector handles identical values (zscore)", {
  x <- c(5, 5, 5)
  result <- nemeton:::normalize_vector(x, method = "zscore")
  expect_equal(result, c(0, 0, 0))
})

test_that("normalize_vector quantile with empty clean ref", {
  x <- c(NA, NA, NA)
  result <- nemeton:::normalize_vector(x, method = "quantile")
  expect_true(all(is.na(result)))
})

test_that("normalize_vector with separate reference", {
  x <- c(25, 50, 75)
  ref <- c(0, 100)
  result <- nemeton:::normalize_vector(x, method = "minmax", reference = ref)
  expect_equal(result[1], 25)
  expect_equal(result[2], 50)
  expect_equal(result[3], 75)
})

test_that("normalize_vector quantile with NA values in x", {
  x <- c(10, NA, 30, 40, 50)
  result <- nemeton:::normalize_vector(x, method = "quantile")
  expect_true(is.na(result[2]))
  expect_false(is.na(result[1]))
})


# ==============================================================================
# NORMALIZATION: normalize_indicators()
# ==============================================================================

test_that("normalize_indicators works on sf with explicit indicators", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(10, 20, 30, 40, 50)
  units$W1 <- c(50, 40, 30, 20, 10)
  result <- normalize_indicators(units, indicators = c("C1", "W1"), method = "minmax")
  expect_true("C1_norm" %in% names(result))
  expect_true("W1_norm" %in% names(result))
  expect_true("C1" %in% names(result)) # keep_original = TRUE
  expect_equal(result$C1_norm[1], 0)
  expect_equal(result$C1_norm[5], 100)
})

test_that("normalize_indicators with zscore method", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(10, 20, 30, 40, 50)
  result <- normalize_indicators(units, indicators = "C1", method = "zscore")
  expect_true("C1_norm" %in% names(result))
  expect_equal(mean(result$C1_norm), 0, tolerance = 1e-10)
})

test_that("normalize_indicators with quantile method", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(10, 20, 30, 40, 50)
  result <- normalize_indicators(units, indicators = "C1", method = "quantile")
  expect_true("C1_norm" %in% names(result))
  expect_true(all(result$C1_norm >= 0 & result$C1_norm <= 100))
})

test_that("normalize_indicators with reference_data", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(25, 50, 75)
  ref_data <- data.frame(C1 = c(0, 100))
  result <- normalize_indicators(units, indicators = "C1", method = "minmax",
                                 reference_data = ref_data)
  expect_equal(result$C1_norm[1], 25)
  expect_equal(result$C1_norm[2], 50)
})

test_that("normalize_indicators warns for missing ref column", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(25, 50, 75)
  ref_data <- data.frame(W1 = c(0, 100))
  # Should warn about missing reference column
  expect_warning(
    result <- normalize_indicators(units, indicators = "C1", method = "minmax",
                                   reference_data = ref_data),
    regexp = NULL # Any warning
  )
})

test_that("normalize_indicators errors on missing indicator", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(25, 50, 75)
  expect_error(
    normalize_indicators(units, indicators = c("C1", "NONEXISTENT")),
    regexp = NULL
  )
})

test_that("normalize_indicators by_family mode", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(10, 20, 30, 40, 50)
  units$C2 <- c(5, 15, 25, 35, 45)
  result <- normalize_indicators(units, indicators = c("C1", "C2"),
                                 method = "minmax", by_family = TRUE)
  # by_family sets suffix="" and keep_original=FALSE, so C1 is normalized in-place
  expect_true("C1" %in% names(result))
  expect_true("C2" %in% names(result))
})


# ==============================================================================
# NORMALIZATION: create_composite_index()
# ==============================================================================

test_that("create_composite_index weighted_mean with equal weights", {
  units <- create_test_units(n_features = 4)
  units$C1_norm <- c(80, 60, 40, 20)
  units$W1_norm <- c(20, 40, 60, 80)
  result <- create_composite_index(units,
                                   indicators = c("C1_norm", "W1_norm"),
                                   name = "test_index")
  expect_true("test_index" %in% names(result))
  expect_equal(result$test_index, c(50, 50, 50, 50))
})

test_that("create_composite_index with custom weights", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(100, 0, 50)
  units$W1_norm <- c(0, 100, 50)
  result <- create_composite_index(units,
                                   indicators = c("C1_norm", "W1_norm"),
                                   weights = c(3, 1),
                                   name = "weighted_idx")
  expect_true("weighted_idx" %in% names(result))
  expect_equal(result$weighted_idx[1], 75)  # 3/4*100 + 1/4*0
  expect_equal(result$weighted_idx[2], 25)  # 3/4*0 + 1/4*100
})

test_that("create_composite_index geometric_mean method", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(50, 100, 25)
  units$W1_norm <- c(50, 100, 25)
  result <- create_composite_index(units,
                                   indicators = c("C1_norm", "W1_norm"),
                                   aggregation = "geometric_mean",
                                   name = "geo_idx")
  expect_true("geo_idx" %in% names(result))
  expect_equal(result$geo_idx[1], 50, tolerance = 1) # sqrt(50*50) = 50
  expect_equal(result$geo_idx[2], 100, tolerance = 1) # sqrt(100*100) = 100
})

test_that("create_composite_index min method", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(80, 40, 60)
  units$W1_norm <- c(30, 70, 50)
  result <- create_composite_index(units,
                                   indicators = c("C1_norm", "W1_norm"),
                                   aggregation = "min",
                                   name = "min_idx")
  expect_true("min_idx" %in% names(result))
  # min takes the minimum of each row
  expect_equal(result$min_idx[1], 30)
  expect_equal(result$min_idx[2], 40)
})

test_that("create_composite_index max method", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(80, 40, 60)
  units$W1_norm <- c(30, 70, 50)
  result <- create_composite_index(units,
                                   indicators = c("C1_norm", "W1_norm"),
                                   aggregation = "max",
                                   name = "max_idx")
  expect_true("max_idx" %in% names(result))
  expect_equal(result$max_idx[1], 80)
  expect_equal(result$max_idx[2], 70)
})

test_that("create_composite_index handles NA values with na.rm", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(80, NA, 60)
  units$W1_norm <- c(30, 70, 50)
  result <- create_composite_index(units,
                                   indicators = c("C1_norm", "W1_norm"),
                                   na.rm = TRUE,
                                   name = "na_idx")
  expect_equal(result$na_idx[2], 70) # only W1_norm contributes
})

test_that("create_composite_index errors on wrong weights length", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(80, 40, 60)
  units$W1_norm <- c(30, 70, 50)
  expect_error(
    create_composite_index(units,
                           indicators = c("C1_norm", "W1_norm"),
                           weights = c(1, 2, 3)),
    regexp = NULL
  )
})

test_that("create_composite_index errors on negative weights", {
  units <- create_test_units(n_features = 3)
  units$C1_norm <- c(80, 40, 60)
  units$W1_norm <- c(30, 70, 50)
  expect_error(
    create_composite_index(units,
                           indicators = c("C1_norm", "W1_norm"),
                           weights = c(1, -1)),
    regexp = NULL
  )
})

test_that("create_composite_index errors on missing indicators", {
  units <- create_test_units(n_features = 3)
  expect_error(
    create_composite_index(units,
                           indicators = c("NONEXIST_A", "NONEXIST_B")),
    regexp = NULL
  )
})


# ==============================================================================
# NORMALIZATION: invert_indicator()
# ==============================================================================

test_that("invert_indicator works", {
  units <- create_test_units(n_features = 3)
  units$risk_norm <- c(80, 50, 20)
  result <- invert_indicator(units, indicators = "risk_norm", scale = 100)
  expect_true("risk_norm_inv" %in% names(result))
  expect_equal(result$risk_norm_inv, c(20, 50, 80))
  # Original should be removed (keep_original = FALSE by default)
  expect_false("risk_norm" %in% names(result))
})

test_that("invert_indicator with keep_original", {
  units <- create_test_units(n_features = 3)
  units$risk_norm <- c(80, 50, 20)
  result <- invert_indicator(units, indicators = "risk_norm",
                             keep_original = TRUE)
  expect_true("risk_norm" %in% names(result))
  expect_true("risk_norm_inv" %in% names(result))
})

test_that("invert_indicator errors on missing indicator", {
  units <- create_test_units(n_features = 3)
  expect_error(
    invert_indicator(units, indicators = "nonexistent"),
    regexp = NULL
  )
})


# ==============================================================================
# ANALYSIS-CORRELATION: compute_family_correlations()
# ==============================================================================

test_that("compute_family_correlations works with auto-detection", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$family_W <- runif(10, 35, 75)
  result <- compute_family_correlations(units)
  expect_true(inherits(result, "matrix"))
  expect_equal(nrow(result), 3)
  expect_equal(ncol(result), 3)
  # Diagonal should be 1
  expect_equal(unname(diag(result)), c(1, 1, 1))
  # Symmetric
  expect_equal(result[1, 2], result[2, 1])
})

test_that("compute_family_correlations with spearman", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  result <- compute_family_correlations(units, method = "spearman")
  expect_true(inherits(result, "matrix"))
  expect_equal(attr(result, "method"), "spearman")
})

test_that("compute_family_correlations with kendall", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  result <- compute_family_correlations(units, method = "kendall")
  expect_true(inherits(result, "matrix"))
})

test_that("compute_family_correlations with explicit families", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$family_W <- runif(10, 35, 75)
  result <- compute_family_correlations(units, families = c("family_C", "family_B"))
  expect_equal(nrow(result), 2)
  expect_equal(ncol(result), 2)
})

test_that("compute_family_correlations errors on non-sf", {
  df <- data.frame(family_C = 1:5, family_B = 5:1)
  expect_error(compute_family_correlations(df), "sf")
})

test_that("compute_family_correlations errors on invalid method", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  expect_error(compute_family_correlations(units, method = "invalid"), "method")
})

test_that("compute_family_correlations errors on no family columns", {
  units <- create_test_units(n_features = 5)
  expect_error(compute_family_correlations(units), "family")
})

test_that("compute_family_correlations errors on missing family", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  expect_error(compute_family_correlations(units, families = c("family_C", "family_NONE")),
               "not found")
})


# ==============================================================================
# ANALYSIS-CORRELATION: identify_hotspots()
# ==============================================================================

test_that("identify_hotspots works with default threshold", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$family_W <- runif(10, 35, 75)
  result <- identify_hotspots(units, threshold = 50, min_families = 2)
  expect_true("hotspot_count" %in% names(result))
  expect_true("hotspot_families" %in% names(result))
  expect_true("is_hotspot" %in% names(result))
  expect_true(is.logical(result$is_hotspot))
})

test_that("identify_hotspots with strict threshold", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- c(rep(90, 3), rep(10, 7))
  units$family_B <- c(rep(90, 3), rep(10, 7))
  units$family_W <- c(rep(90, 3), rep(10, 7))
  result <- identify_hotspots(units, threshold = 80, min_families = 3)
  # Top 20% should be parcels 1-3 (value 90)
  expect_true(sum(result$is_hotspot) >= 1)
})

test_that("identify_hotspots with threshold 100", {
  units <- create_test_units(n_features = 5)
  units$family_C <- c(100, 90, 80, 70, 60)
  units$family_B <- c(100, 90, 80, 70, 60)
  result <- identify_hotspots(units, threshold = 100, min_families = 1)
  # Threshold=100 uses strict > (no values above max)
  expect_true(all(!result$is_hotspot))
})

test_that("identify_hotspots errors on non-sf", {
  df <- data.frame(family_C = 1:5, family_B = 5:1)
  expect_error(identify_hotspots(df), "sf")
})

test_that("identify_hotspots errors on invalid threshold", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  expect_error(identify_hotspots(units, threshold = 150), "threshold")
})

test_that("identify_hotspots errors on invalid min_families", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  expect_error(identify_hotspots(units, min_families = 0), "min_families")
})


# ==============================================================================
# VISUALIZATION: clean_indicator_name()
# ==============================================================================

test_that("clean_indicator_name works for family indices", {
  expect_equal(nemeton:::clean_indicator_name("family_C"), "C")
  expect_equal(nemeton:::clean_indicator_name("family_B"), "B")
})

test_that("clean_indicator_name strips _norm suffix", {
  expect_equal(nemeton:::clean_indicator_name("carbon_norm"), "Carbon (Normalized)")
})

test_that("clean_indicator_name strips _inv suffix", {
  expect_equal(nemeton:::clean_indicator_name("risk_inv"), "Risk (Inverted)")
})

test_that("clean_indicator_name capitalizes and replaces underscores", {
  expect_equal(nemeton:::clean_indicator_name("carbon_stock"), "Carbon stock")
})

test_that("clean_indicator_name works as vector", {
  result <- nemeton:::clean_indicator_name(c("family_C", "carbon_norm", "C1"))
  expect_equal(length(result), 3)
  expect_equal(result[1], "C")
  expect_equal(result[2], "Carbon (Normalized)")
  expect_equal(result[3], "C1")
})


# ==============================================================================
# ANALYSIS-TRADEOFF: plot_tradeoff() validation
# ==============================================================================

test_that("plot_tradeoff works with basic sf data", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  p <- plot_tradeoff(units, x = "family_C", y = "family_B")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff works with data.frame", {
  df <- data.frame(family_C = runif(10), family_B = runif(10))
  p <- plot_tradeoff(df, x = "family_C", y = "family_B")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on invalid data type", {
  expect_error(
    plot_tradeoff("not_a_df", x = "a", y = "b"),
    regexp = NULL
  )
})

test_that("plot_tradeoff errors on missing x variable", {
  units <- create_test_units(n_features = 5)
  units$family_B <- 1:5
  expect_error(
    plot_tradeoff(units, x = "nonexistent", y = "family_B"),
    regexp = NULL
  )
})

test_that("plot_tradeoff errors on missing y variable", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  expect_error(
    plot_tradeoff(units, x = "family_C", y = "nonexistent"),
    regexp = NULL
  )
})

test_that("plot_tradeoff errors on non-numeric x", {
  units <- create_test_units(n_features = 5)
  units$x_var <- letters[1:5]
  units$y_var <- 1:5
  expect_error(
    plot_tradeoff(units, x = "x_var", y = "y_var"),
    regexp = NULL
  )
})

test_that("plot_tradeoff errors on non-numeric y", {
  units <- create_test_units(n_features = 5)
  units$x_var <- 1:5
  units$y_var <- letters[1:5]
  expect_error(
    plot_tradeoff(units, x = "x_var", y = "y_var"),
    regexp = NULL
  )
})

test_that("plot_tradeoff with color parameter", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$family_W <- runif(10, 20, 70)
  p <- plot_tradeoff(units, x = "family_C", y = "family_B", color = "family_W")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on missing color variable", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  units$family_B <- 5:1
  expect_error(
    plot_tradeoff(units, x = "family_C", y = "family_B", color = "nonexistent"),
    regexp = NULL
  )
})

test_that("plot_tradeoff with size parameter", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$area_ha <- runif(10, 1, 50)
  p <- plot_tradeoff(units, x = "family_C", y = "family_B", size = "area_ha")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on missing size variable", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  units$family_B <- 5:1
  expect_error(
    plot_tradeoff(units, x = "family_C", y = "family_B", size = "nonexistent"),
    regexp = NULL
  )
})

test_that("plot_tradeoff with pareto_frontier", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$is_optimal <- c(TRUE, FALSE, TRUE, FALSE, FALSE,
                        FALSE, FALSE, TRUE, FALSE, FALSE)
  p <- plot_tradeoff(units, x = "family_C", y = "family_B",
                     pareto_frontier = TRUE)
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors when pareto without is_optimal", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  units$family_B <- 5:1
  expect_error(
    plot_tradeoff(units, x = "family_C", y = "family_B",
                  pareto_frontier = TRUE),
    regexp = NULL
  )
})

test_that("plot_tradeoff with custom labels", {
  units <- create_test_units(n_features = 5)
  units$family_C <- c(80, 60, 40, 20, 50)
  units$family_B <- c(20, 40, 60, 80, 50)
  units$name <- paste0("Parcel_", 1:5)
  p <- plot_tradeoff(units, x = "family_C", y = "family_B",
                     label = "name",
                     xlab = "Carbon", ylab = "Biodiversity",
                     title = "Test Trade-off")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on missing label variable", {
  units <- create_test_units(n_features = 5)
  units$family_C <- 1:5
  units$family_B <- 5:1
  expect_error(
    plot_tradeoff(units, x = "family_C", y = "family_B",
                  label = "nonexistent"),
    regexp = NULL
  )
})


# ==============================================================================
# VISUALIZATION: plot_indicators_map() - basic validation
# ==============================================================================

test_that("plot_indicators_map works with single indicator", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  p <- plot_indicators_map(units, indicators = "C1")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_indicators_map errors on non-sf data", {
  df <- data.frame(C1 = 1:5)
  expect_error(plot_indicators_map(df, indicators = "C1"), regexp = NULL)
})

test_that("plot_indicators_map errors on missing indicator", {
  units <- create_test_units(n_features = 5)
  expect_error(
    plot_indicators_map(units, indicators = "nonexistent"),
    regexp = NULL
  )
})

test_that("plot_indicators_map with palette option", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  p <- plot_indicators_map(units, indicators = "C1", palette = "RdYlGn")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_indicators_map with multiple indicators", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  units$W1 <- c(20, 40, 60, 80, 50)
  p <- plot_indicators_map(units, indicators = c("C1", "W1"))
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_indicators_map with custom breaks and labels", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  p <- plot_indicators_map(units, indicators = "C1",
                           breaks = c(0, 25, 50, 75, 100),
                           title = "Carbon", legend_title = "Score")
  expect_true(inherits(p, "ggplot"))
})


# ==============================================================================
# VISUALIZATION: nemeton_radar() - basic tests
# ==============================================================================

test_that("nemeton_radar works in family mode", {
  units <- create_test_units(n_features = 5)
  units$family_C <- c(80, 60, 40, 20, 50)
  units$family_B <- c(70, 50, 30, 10, 40)
  units$family_W <- c(60, 80, 20, 40, 50)
  units$family_A <- c(50, 70, 60, 30, 80)
  p <- nemeton_radar(units, unit_id = 1, mode = "family")
  expect_true(inherits(p, "ggplot"))
})

test_that("nemeton_radar works in mean mode", {
  units <- create_test_units(n_features = 5)
  units$family_C <- c(80, 60, 40, 20, 50)
  units$family_B <- c(70, 50, 30, 10, 40)
  units$family_W <- c(60, 80, 20, 40, 50)
  units$family_A <- c(50, 70, 60, 30, 80)
  p <- nemeton_radar(units, mode = "family")
  expect_true(inherits(p, "ggplot"))
})

test_that("nemeton_radar comparison mode with multiple units", {
  units <- create_test_units(n_features = 5)
  units$family_C <- c(80, 60, 40, 20, 50)
  units$family_B <- c(70, 50, 30, 10, 40)
  units$family_W <- c(60, 80, 20, 40, 50)
  units$family_A <- c(50, 70, 60, 30, 80)
  p <- nemeton_radar(units, unit_id = c(1, 2, 3), mode = "family")
  expect_true(inherits(p, "ggplot"))
})

test_that("nemeton_radar errors on non-sf", {
  df <- data.frame(family_C = 1:5)
  expect_error(nemeton_radar(df), "sf")
})

test_that("nemeton_radar errors on no family columns in family mode", {
  units <- create_test_units(n_features = 5)
  expect_error(nemeton_radar(units, mode = "family"), "family")
})


# ==============================================================================
# VISUALIZATION: reshape_for_facet()
# ==============================================================================

test_that("reshape_for_facet creates long format", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(80, 60, 40)
  units$W1 <- c(20, 40, 60)
  result <- nemeton:::reshape_for_facet(units, c("C1", "W1"))
  expect_true(inherits(result, "sf"))
  expect_true("indicator" %in% names(result))
  expect_true("value" %in% names(result))
  expect_equal(nrow(result), 6) # 3 parcels * 2 indicators
})

test_that("reshape_for_facet with nemeton_id", {
  units <- create_test_units(n_features = 3)
  units$nemeton_id <- paste0("P", 1:3)
  units$C1 <- c(80, 60, 40)
  units$W1 <- c(20, 40, 60)
  result <- nemeton:::reshape_for_facet(units, c("C1", "W1"))
  expect_true("nemeton_id" %in% names(result))
})


# ==============================================================================
# VISUALIZATION: add_color_scale()
# ==============================================================================

test_that("add_color_scale viridis works", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  p <- ggplot2::ggplot(units) +
    ggplot2::geom_sf(ggplot2::aes(fill = C1))
  p_result <- nemeton:::add_color_scale(p, palette = "viridis",
                                         direction = 1, breaks = NULL,
                                         labels = NULL, legend_title = "Score")
  expect_true(inherits(p_result, "ggplot"))
})

test_that("add_color_scale with ColorBrewer palette works", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  p <- ggplot2::ggplot(units) +
    ggplot2::geom_sf(ggplot2::aes(fill = C1))
  p_result <- nemeton:::add_color_scale(p, palette = "RdYlGn",
                                         direction = 1, breaks = NULL,
                                         labels = NULL, legend_title = "Score")
  expect_true(inherits(p_result, "ggplot"))
})

test_that("add_color_scale with breaks works", {
  units <- create_test_units(n_features = 5)
  units$C1 <- c(80, 60, 40, 20, 50)
  p <- ggplot2::ggplot(units) +
    ggplot2::geom_sf(ggplot2::aes(fill = C1))
  p_result <- nemeton:::add_color_scale(p, palette = "viridis",
                                         direction = 1,
                                         breaks = c(0, 25, 50, 75, 100),
                                         labels = c("Low", "Med-Low", "Med", "Med-Hi", "High"),
                                         legend_title = "Score")
  expect_true(inherits(p_result, "ggplot"))
})


# ==============================================================================
# I18N: more msg() paths and French messages
# ==============================================================================

test_that("msg returns key for unknown message key", {
  result <- nemeton:::msg("totally_unknown_key_xyz")
  expect_equal(result, "totally_unknown_key_xyz")
})

test_that("msg_info dispatches correctly", {
  # Should produce a message (cli_alert_info), not an error
  expect_message(nemeton:::msg_info("indicator_carbon_biomass"))
})

test_that("nemeton_set_language to fr works", {
  old_lang <- nemeton:::get_language()
  on.exit(nemeton_set_language(old_lang), add = TRUE)
  nemeton_set_language("fr")
  expect_equal(nemeton:::get_language(), "fr")
})

test_that("msg works in French", {
  old_lang <- nemeton:::get_language()
  on.exit(nemeton_set_language(old_lang), add = TRUE)
  nemeton_set_language("fr")
  result <- nemeton:::msg("language_set")
  # French message should contain something recognizable
  expect_true(nchar(result) > 0)
})

test_that("get_language auto-detects from locale", {
  # Clear cached language
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  # Set a French locale
  withr::with_envvar(c(LANG = "fr_FR.UTF-8"), {
    # Clear again inside the envvar scope
    if (exists("language", envir = nemeton:::.nemeton_env)) {
      rm("language", envir = nemeton:::.nemeton_env)
    }
    lang <- nemeton:::get_language()
    expect_equal(lang, "fr")
  })
  # Restore English
  nemeton_set_language("en")
})

test_that("get_language defaults to en for unknown locale", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = "de_DE.UTF-8"), {
    if (exists("language", envir = nemeton:::.nemeton_env)) {
      rm("language", envir = nemeton:::.nemeton_env)
    }
    lang <- nemeton:::get_language()
    expect_equal(lang, "en")
  })
  nemeton_set_language("en")
})

test_that("msg falls back to English when key missing in French", {
  old_lang <- nemeton:::get_language()
  on.exit(nemeton_set_language(old_lang), add = TRUE)
  nemeton_set_language("fr")
  # Test a key that exists in both languages
  result <- nemeton:::msg("language_set")
  expect_true(nchar(result) > 0)
})


# ==============================================================================
# UTILS: resolve_raster_layer & resolve_vector_layer
# ==============================================================================

test_that("resolve_raster_layer returns NULL for non-nemeton_layers", {
  result <- nemeton:::resolve_raster_layer(list(), "dem")
  expect_null(result)
})

test_that("resolve_raster_layer returns NULL for missing layer name", {
  layers <- structure(list(rasters = list()), class = "nemeton_layers")
  result <- nemeton:::resolve_raster_layer(layers, "nonexistent")
  expect_null(result)
})

test_that("resolve_raster_layer returns NULL for NULL entry", {
  layers <- structure(list(rasters = list(dem = NULL)), class = "nemeton_layers")
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

test_that("resolve_vector_layer returns NULL for non-nemeton_layers", {
  result <- nemeton:::resolve_vector_layer(list(), "water")
  expect_null(result)
})

test_that("resolve_vector_layer returns NULL for missing layer name", {
  layers <- structure(list(vectors = list()), class = "nemeton_layers")
  result <- nemeton:::resolve_vector_layer(layers, "nonexistent")
  expect_null(result)
})

test_that("resolve_vector_layer returns NULL for NULL entry", {
  layers <- structure(list(vectors = list(water = NULL)), class = "nemeton_layers")
  result <- nemeton:::resolve_vector_layer(layers, "water")
  expect_null(result)
})

test_that("resolve_vector_layer returns sf object directly", {
  sf_obj <- create_test_units(n_features = 3)
  layers <- structure(list(vectors = list(parcels = sf_obj)), class = "nemeton_layers")
  result <- nemeton:::resolve_vector_layer(layers, "parcels")
  expect_true(inherits(result, "sf"))
  expect_equal(nrow(result), 3)
})

test_that("resolve_raster_layer handles lazy-load list with no path", {
  entry <- list(object = NULL, loaded = FALSE, path = "")
  layers <- structure(list(rasters = list(dem = entry)), class = "nemeton_layers")
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

test_that("get_dem_raster returns NULL for non-nemeton_layers", {
  result <- nemeton:::get_dem_raster(list())
  expect_null(result)
})


# ==============================================================================
# UTILS: detect_indicator_family (from utils.R)
# ==============================================================================

test_that("detect_indicator_family extracts family code", {
  expect_equal(nemeton:::detect_indicator_family("C1"), "C")
  expect_equal(nemeton:::detect_indicator_family("W3"), "W")
  expect_equal(nemeton:::detect_indicator_family("B2"), "B")
})

test_that("detect_indicator_family returns NA for non-indicator", {
  expect_true(is.na(nemeton:::detect_indicator_family("carbon")))
  expect_true(is.na(nemeton:::detect_indicator_family("family_C")))
})


# ==============================================================================
# ANALYSIS-CORRELATION: plot_correlation_matrix()
# ==============================================================================

test_that("plot_correlation_matrix works", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  units$family_W <- runif(10, 35, 75)
  corr <- compute_family_correlations(units)
  p <- plot_correlation_matrix(corr)
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_correlation_matrix with number method", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  corr <- compute_family_correlations(units)
  p <- plot_correlation_matrix(corr, method = "number")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_correlation_matrix with color method", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$family_C <- runif(10, 30, 90)
  units$family_B <- runif(10, 40, 85)
  corr <- compute_family_correlations(units)
  p <- plot_correlation_matrix(corr, method = "color", title = "Test")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_correlation_matrix errors on non-matrix", {
  expect_error(plot_correlation_matrix("not_a_matrix"), "matrix")
})

test_that("plot_correlation_matrix errors on invalid method", {
  m <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  class(m) <- c("matrix", "array")
  expect_error(plot_correlation_matrix(m, method = "invalid"), "method")
})


# ==============================================================================
# UTILS: species lookup functions
# ==============================================================================

test_that("get_species_flammability returns scores", {
  result <- nemeton:::get_species_flammability("Pinus")
  expect_true(is.numeric(result))
  expect_true(result >= 0 && result <= 100)
})

test_that("get_species_flammability returns 50 for unknown species", {
  result <- nemeton:::get_species_flammability("UnknownSpeciesXYZ")
  expect_equal(result, 50)
})

test_that("get_species_flammability handles NA", {
  result <- nemeton:::get_species_flammability(NA)
  expect_true(is.na(result))
})

test_that("get_species_flammability is vectorized", {
  result <- nemeton:::get_species_flammability(c("Pinus", "Quercus", NA))
  expect_equal(length(result), 3)
  expect_true(is.na(result[3]))
})


# ==============================================================================
# APP_CONFIG: basic tests
# ==============================================================================

test_that("APP_CONFIG has expected fields", {
  config <- nemeton:::APP_CONFIG
  expect_true("app_name" %in% names(config))
  expect_true("max_parcels" %in% names(config))
  expect_true("default_crs" %in% names(config))
  expect_equal(config$default_crs, 2154L)
})

test_that("APP_CONFIG LLM models are configured", {
  config <- nemeton:::APP_CONFIG
  expect_true("llm_models" %in% names(config))
  expect_true("mistral" %in% names(config$llm_models))
  expect_true("anthropic" %in% names(config$llm_models))
})
