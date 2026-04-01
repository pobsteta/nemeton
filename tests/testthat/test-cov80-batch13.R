# test-cov80-batch13.R
# Coverage tests for R/normalization.R, R/temporal.R, R/nemeton-class.R
# Targets: normalize_indicators, normalize_vector, nemeton_temporal,
#          calculate_change_rate, nemeton_units, nemeton_layers, and print/summary methods

# =============================================================================
# R/normalization.R — normalize_indicators()
# =============================================================================

test_that("normalize_indicators() minmax with explicit indicators scales to 0-100", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)
  units$indicateur_w3_humidite <- c(100, 200, 300, 400, 500)

  result <- nemeton::normalize_indicators(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    method = "minmax"
  )

  expect_true("carbon_biomass_norm" %in% names(result))
  expect_true("water_twi_norm" %in% names(result))
  expect_equal(min(result$carbon_biomass_norm), 0)
  expect_equal(max(result$carbon_biomass_norm), 100)
  expect_equal(result$carbon_biomass_norm[3], 50)
  expect_equal(min(result$water_twi_norm), 0)
  expect_equal(max(result$water_twi_norm), 100)
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

  expect_true("carbon_biomass_norm" %in% names(result))
  expect_true(abs(mean(result$carbon_biomass_norm)) < 0.01)
  expect_true(abs(sd(result$carbon_biomass_norm) - 1) < 0.01)
})

test_that("normalize_indicators() quantile method produces 0-100 ranks", {
  units <- create_test_units(n_features = 10)
  units$indicateur_c1_biomasse <- seq(10, 100, by = 10)

  result <- nemeton::normalize_indicators(
    units,
    indicators = "indicateur_c1_biomasse",
    method = "quantile"
  )

  expect_true("carbon_biomass_norm" %in% names(result))
  # The lowest value should get the lowest rank
  expect_equal(result$carbon_biomass_norm[1], 10) # 1/10 * 100 = 10
  # The highest value should get rank 100
  expect_equal(result$carbon_biomass_norm[10], 100) # 10/10 * 100 = 100
  # All should be in [0, 100]
  expect_true(all(result$carbon_biomass_norm >= 0 & result$carbon_biomass_norm <= 100))
})

test_that("normalize_indicators() auto-detects known indicator columns", {
  units <- create_test_units(n_features = 5)
  units$indicateur_c1_biomasse <- c(10, 20, 30, 40, 50)
  units$indicateur_w3_humidite <- c(5, 10, 15, 20, 25)
  units$random_col <- c(1, 2, 3, 4, 5) # Should NOT be auto-detected

  result <- nemeton::normalize_indicators(units, method = "minmax")

  expect_true("carbon_biomass_norm" %in% names(result))
  expect_true("water_twi_norm" %in% names(result))
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

test_that("normalize_indicators() auto-detects family_index columns", {
  units <- create_test_units(n_features = 5)
  units$family_carbon <- c(10, 20, 30, 40, 50)
  units$family_water <- c(5, 10, 15, 20, 25)

  result <- nemeton::normalize_indicators(units, method = "minmax")

  expect_true("family_carbon_norm" %in% names(result))
  expect_true("family_water_norm" %in% names(result))
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
  expect_equal(result$carbon_biomass_norm[1], 20)
  expect_equal(result$carbon_biomass_norm[5], 60)
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

  expect_true("carbon_biomass_z" %in% names(result))
  expect_false("carbon_biomass_norm" %in% names(result))
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
  expect_true("carbon_biomass_norm" %in% names(result))
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
  expect_true("carbon_biomass_norm" %in% names(result))
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

# =============================================================================
# R/normalization.R — normalize_vector() (internal)
# =============================================================================

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

  # 10 is <= 1/5 of values → 20%
  expect_equal(result[1], 20)
  # 50 is <= 5/5 of values → 100%
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
  # All NA in reference → ref_clean is empty
  result <- nemeton:::normalize_vector(
    x = c(1, 2, 3),
    method = "quantile",
    reference = c(NA_real_, NA_real_)
  )

  expect_true(all(is.na(result)))
})

# =============================================================================
# R/temporal.R — nemeton_temporal()
# =============================================================================

test_that("nemeton_temporal() creates object with two periods", {
  sf1 <- create_test_units(n_features = 5)
  sf1$parcel_id <- paste0("P", 1:5)
  sf1$C1 <- c(10, 20, 30, 40, 50)

  sf2 <- create_test_units(n_features = 5)
  sf2$parcel_id <- paste0("P", 1:5)
  sf2$C1 <- c(15, 25, 35, 45, 55)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  expect_s3_class(temporal, "nemeton_temporal")
  expect_equal(temporal$metadata$n_periods, 2)
  expect_equal(temporal$metadata$n_units, 5)
  expect_equal(temporal$metadata$n_complete, 5)
  expect_equal(length(temporal$periods), 2)
})

test_that("nemeton_temporal() auto-converts year names to dates", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  expect_false(is.null(temporal$metadata$dates))
  expect_equal(temporal$metadata$dates[1], as.Date("2015-01-01"))
  expect_equal(temporal$metadata$dates[2], as.Date("2020-01-01"))
})

test_that("nemeton_temporal() accepts custom labels", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2),
    labels = c("Baseline", "Current")
  )

  expect_equal(temporal$metadata$period_labels, c("Baseline", "Current"))
})

test_that("nemeton_temporal() handles misaligned units", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- c("P1", "P2", "P3")

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- c("P2", "P3", "P4") # P1 missing, P4 added

  # Should warn about misalignment
  temporal <- suppressWarnings(
    nemeton::nemeton_temporal(
      periods = list("2015" = sf1, "2020" = sf2)
    )
  )

  expect_s3_class(temporal, "nemeton_temporal")
  expect_equal(temporal$metadata$n_units, 4) # P1, P2, P3, P4
  expect_equal(temporal$metadata$n_complete, 2) # only P2, P3 in both
})

test_that("nemeton_temporal() errors on empty periods", {
  expect_error(
    nemeton::nemeton_temporal(periods = list()),
    "No periods provided"
  )
})

test_that("nemeton_temporal() errors on non-sf period", {
  sf1 <- create_test_units(n_features = 3)
  df2 <- data.frame(x = 1:3) # Not sf

  expect_error(
    nemeton::nemeton_temporal(
      periods = list("2015" = sf1, "2020" = df2)
    ),
    "All periods must be sf objects"
  )
})

test_that("nemeton_temporal() with explicit dates parameter", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)

  temporal <- nemeton::nemeton_temporal(
    periods = list("period_a" = sf1, "period_b" = sf2),
    dates = c("2015-06-15", "2020-09-30")
  )

  expect_equal(temporal$metadata$dates, as.Date(c("2015-06-15", "2020-09-30")))
})

# =============================================================================
# R/temporal.R — calculate_change_rate()
# =============================================================================

test_that("calculate_change_rate() with absolute type", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(20, 30, 50)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  result <- nemeton::calculate_change_rate(
    temporal,
    indicators = "C1",
    type = "absolute"
  )

  expect_true("C1_rate_abs" %in% names(result))
  expect_false("C1_rate_rel" %in% names(result))
  # ~5-year time diff (via difftime/365.25), absolute changes: ~(20-10)/5, etc.
  expect_equal(result$C1_rate_abs[1], 2, tolerance = 0.01)
  expect_equal(result$C1_rate_abs[2], 2, tolerance = 0.01)
  expect_equal(result$C1_rate_abs[3], 4, tolerance = 0.01)
})

test_that("calculate_change_rate() with relative type", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 50)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(20, 40, 100)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  result <- nemeton::calculate_change_rate(
    temporal,
    indicators = "C1",
    type = "relative"
  )

  expect_true("C1_rate_rel" %in% names(result))
  expect_false("C1_rate_abs" %in% names(result))
  # relative rate = ((end/start) - 1) * 100 / time_diff
  # P1: ((20/10)-1)*100/~5 = ~20
  expect_equal(result$C1_rate_rel[1], 20, tolerance = 0.01)
})

test_that("calculate_change_rate() with both type (default)", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  result <- nemeton::calculate_change_rate(
    temporal,
    indicators = "C1",
    type = "both"
  )

  expect_true("C1_rate_abs" %in% names(result))
  expect_true("C1_rate_rel" %in% names(result))
})

test_that("calculate_change_rate() with explicit dates uses difftime", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(20, 30, 40)

  temporal <- nemeton::nemeton_temporal(
    periods = list("t1" = sf1, "t2" = sf2),
    dates = c("2015-01-01", "2020-01-01")
  )

  result <- nemeton::calculate_change_rate(
    temporal,
    indicators = "C1",
    type = "absolute"
  )

  # time_diff ~4.9986... years (5 * 365 / 365.25)
  time_diff <- as.numeric(difftime(as.Date("2020-01-01"), as.Date("2015-01-01"), units = "days")) / 365.25
  expected_rate_1 <- (20 - 10) / time_diff
  expect_equal(result$C1_rate_abs[1], expected_rate_1, tolerance = 0.01)
})

test_that("calculate_change_rate() without dates parses years from names", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(20, 30, 40)

  # Dates auto-derived from "2015", "2020" via nemeton_temporal
  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  # Should have dates from year names
  expect_false(is.null(temporal$metadata$dates))

  result <- nemeton::calculate_change_rate(
    temporal,
    indicators = "C1",
    type = "absolute"
  )

  expect_true("C1_rate_abs" %in% names(result))
})

test_that("calculate_change_rate() with non-year names and no dates warns", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(20, 30, 40)

  temporal <- nemeton::nemeton_temporal(
    periods = list("baseline" = sf1, "current" = sf2)
  )

  # No dates, names are not years → should warn about time_diff
  expect_warning(
    result <- nemeton::calculate_change_rate(
      temporal,
      indicators = "C1",
      type = "absolute"
    ),
    "Cannot determine time difference"
  )
})

test_that("calculate_change_rate() auto-detects indicators with 'all'", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)
  sf1$W1 <- c(5, 10, 15)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)
  sf2$W1 <- c(8, 13, 18)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  result <- nemeton::calculate_change_rate(
    temporal,
    indicators = "all",
    type = "both"
  )

  # Should detect C1 and W1 (numeric + not in excluded columns)
  expect_true("C1_rate_abs" %in% names(result))
  expect_true("W1_rate_abs" %in% names(result))
  expect_true("C1_rate_rel" %in% names(result))
  expect_true("W1_rate_rel" %in% names(result))
})

test_that("calculate_change_rate() warns on missing indicator", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  expect_warning(
    result <- nemeton::calculate_change_rate(
      temporal,
      indicators = c("C1", "NONEXISTENT"),
      type = "absolute"
    ),
    "not found in both periods"
  )

  expect_true("C1_rate_abs" %in% names(result))
  expect_false("NONEXISTENT_rate_abs" %in% names(result))
})

test_that("calculate_change_rate() errors on non-nemeton_temporal input", {
  expect_error(
    nemeton::calculate_change_rate(list(a = 1, b = 2)),
    "temporal must be a nemeton_temporal object"
  )
})

# =============================================================================
# R/temporal.R — print.nemeton_temporal()
# =============================================================================

test_that("print.nemeton_temporal() displays with dates", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2),
    dates = c("2015-01-01", "2020-01-01")
  )

  output <- capture.output(print(temporal))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("nemeton_temporal", output_str))
  expect_true(grepl("2 periods", output_str))
  expect_true(grepl("3 units", output_str))
  expect_true(grepl("Date range", output_str))
  expect_true(grepl("2015-01-01", output_str))
  expect_true(grepl("2020-01-01", output_str))
})

test_that("print.nemeton_temporal() displays without dates", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)

  temporal <- nemeton::nemeton_temporal(
    periods = list("baseline" = sf1, "current" = sf2)
  )

  output <- capture.output(print(temporal))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("nemeton_temporal", output_str))
  expect_true(grepl("2 periods", output_str))
  expect_false(grepl("Date range", output_str))
})

test_that("print.nemeton_temporal() shows misalignment warning", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- c("P1", "P2", "P3")

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- c("P2", "P3", "P4")

  temporal <- suppressWarnings(
    nemeton::nemeton_temporal(
      periods = list("baseline" = sf1, "current" = sf2)
    )
  )

  output <- capture.output(print(temporal))
  output_str <- paste(output, collapse = "\n")

  # Should display the misalignment warning in print output
  expect_true(grepl("not present in all periods", output_str))
})

# =============================================================================
# R/temporal.R — summary.nemeton_temporal()
# =============================================================================

test_that("summary.nemeton_temporal() outputs period summaries", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2),
    labels = c("Baseline", "Current")
  )

  output <- capture.output(summary(temporal))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Period summaries", output_str))
  expect_true(grepl("Baseline", output_str))
  expect_true(grepl("Current", output_str))
  expect_true(grepl("Indicator ranges", output_str))
})

# =============================================================================
# R/nemeton-class.R — nemeton_units()
# =============================================================================

test_that("nemeton_units() from sf object creates valid nemeton_units", {
  units <- create_test_units(n_features = 5)

  nu <- nemeton::nemeton_units(units)

  expect_s3_class(nu, "nemeton_units")
  expect_s3_class(nu, "sf")
  expect_true("nemeton_id" %in% names(nu))
  expect_equal(nrow(nu), 5)
  expect_equal(length(unique(nu$nemeton_id)), 5)

  meta <- attr(nu, "metadata")
  expect_true("crs" %in% names(meta))
  expect_true("n_units" %in% names(meta))
  expect_true("area_total" %in% names(meta))
  expect_true("created_at" %in% names(meta))
  expect_equal(meta$n_units, 5)
})

test_that("nemeton_units() with id_col uses specified column", {
  units <- create_test_units(n_features = 3)
  units$my_id <- c("alpha", "beta", "gamma")

  nu <- nemeton::nemeton_units(units, id_col = "my_id")

  expect_equal(nu$nemeton_id, c("alpha", "beta", "gamma"))
})

test_that("nemeton_units() with id_col=NULL auto-generates IDs", {
  units <- create_test_units(n_features = 3)

  nu <- nemeton::nemeton_units(units)

  expect_true("nemeton_id" %in% names(nu))
  # Auto-generated IDs follow "unit_001", "unit_002" pattern
  expect_equal(nu$nemeton_id, c("unit_001", "unit_002", "unit_003"))
})

test_that("nemeton_units() errors on duplicate IDs", {
  units <- create_test_units(n_features = 3)
  units$dup_id <- c("A", "A", "B")

  expect_error(
    nemeton::nemeton_units(units, id_col = "dup_id"),
    "unique"
  )
})

test_that("nemeton_units() errors on missing id_col", {
  units <- create_test_units(n_features = 3)

  expect_error(
    nemeton::nemeton_units(units, id_col = "nonexistent"),
    "not found"
  )
})

test_that("nemeton_units() stores metadata correctly", {
  units <- create_test_units(n_features = 3)

  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Test Forest", year = 2024, source = "IGN")
  )

  meta <- attr(nu, "metadata")
  expect_equal(meta$site_name, "Test Forest")
  expect_equal(meta$year, 2024)
  expect_equal(meta$source, "IGN")
})

# =============================================================================
# R/nemeton-class.R — print.nemeton_units()
# =============================================================================

test_that("print.nemeton_units() with site_name and year metadata", {
  units <- create_test_units(n_features = 5)
  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Fontainebleau", year = 2024)
  )

  output <- capture.output(print(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("nemeton_units", output_str))
  expect_true(grepl("Fontainebleau", output_str))
  expect_true(grepl("2024", output_str))
  expect_true(grepl("Units:", output_str))
  expect_true(grepl("5", output_str))
})

test_that("print.nemeton_units() with area_total shows hectares", {
  units <- create_test_units(n_features = 3)
  nu <- nemeton::nemeton_units(units)

  output <- capture.output(print(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Total area", output_str))
  expect_true(grepl("ha", output_str))
})

# =============================================================================
# R/nemeton-class.R — summary.nemeton_units()
# =============================================================================

test_that("summary.nemeton_units() outputs complete summary", {
  units <- create_test_units(n_features = 5)
  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Test", year = 2024, source = "Test Data")
  )

  output <- capture.output(summary(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Nemeton Units Summary", output_str))
  expect_true(grepl("Number of units: 5", output_str))
  expect_true(grepl("Site: Test", output_str))
  expect_true(grepl("Year: 2024", output_str))
  expect_true(grepl("Source: Test Data", output_str))
  expect_true(grepl("Total area", output_str))
  expect_true(grepl("Mean area", output_str))
  expect_true(grepl("Attributes", output_str))
})

test_that("summary.nemeton_units() handles missing metadata fields", {
  units <- create_test_units(n_features = 3)
  nu <- nemeton::nemeton_units(units)

  output <- capture.output(summary(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Not specified", output_str))
})

# =============================================================================
# R/nemeton-class.R — nemeton_layers()
# =============================================================================

test_that("nemeton_layers() with rasters and vectors (validate=FALSE)", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/fake_ndvi.tif", dem = "/tmp/fake_dem.tif"),
    vectors = list(rivers = "/tmp/fake_rivers.gpkg"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 2)
  expect_equal(layers$metadata$n_vectors, 1)
  expect_true("ndvi" %in% names(layers$rasters))
  expect_true("dem" %in% names(layers$rasters))
  expect_true("rivers" %in% names(layers$vectors))
  expect_false(layers$rasters$ndvi$loaded)
})

test_that("nemeton_layers() with only rasters", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/fake.tif"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 1)
  expect_equal(layers$metadata$n_vectors, 0)
  expect_equal(length(layers$vectors), 0)
})

test_that("nemeton_layers() with only vectors", {
  layers <- nemeton::nemeton_layers(
    vectors = list(roads = "/tmp/fake.gpkg"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 0)
  expect_equal(layers$metadata$n_vectors, 1)
  expect_equal(length(layers$rasters), 0)
})

test_that("nemeton_layers() errors when both rasters and vectors are NULL", {
  expect_error(
    nemeton::nemeton_layers(rasters = NULL, vectors = NULL),
    "rasters.*vectors"
  )
})

test_that("nemeton_layers() errors on unnamed rasters list", {
  expect_error(
    nemeton::nemeton_layers(
      rasters = list("/tmp/fake.tif"),
      validate = FALSE
    ),
    "named list"
  )
})

test_that("nemeton_layers() errors on unnamed vectors list", {
  expect_error(
    nemeton::nemeton_layers(
      vectors = list("/tmp/fake.gpkg"),
      validate = FALSE
    ),
    "named list"
  )
})

test_that("nemeton_layers() stores path and loaded status", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test_ndvi.tif"),
    vectors = list(rivers = "/tmp/test_rivers.gpkg"),
    validate = FALSE
  )

  expect_false(layers$rasters$ndvi$loaded)
  expect_null(layers$rasters$ndvi$object)
  expect_false(layers$vectors$rivers$loaded)
  expect_null(layers$vectors$rivers$object)
})

# =============================================================================
# R/nemeton-class.R — print.nemeton_layers()
# =============================================================================

test_that("print.nemeton_layers() shows rasters and vectors", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test_ndvi.tif", dem = "/tmp/test_dem.tif"),
    vectors = list(rivers = "/tmp/test_rivers.gpkg"),
    validate = FALSE
  )

  output <- capture.output(print(layers))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("nemeton_layers", output_str))
  expect_true(grepl("Rasters", output_str))
  expect_true(grepl("ndvi", output_str))
  expect_true(grepl("dem", output_str))
  expect_true(grepl("Vectors", output_str))
  expect_true(grepl("rivers", output_str))
  expect_true(grepl("not loaded", output_str))
})

test_that("print.nemeton_layers() shows (none) for empty sections", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test_ndvi.tif"),
    validate = FALSE
  )

  output <- capture.output(print(layers))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("\\(none\\)", output_str))
})

# =============================================================================
# R/nemeton-class.R — summary.nemeton_layers()
# =============================================================================

test_that("summary.nemeton_layers() outputs basic info", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test.tif", dem = "/tmp/test2.tif"),
    vectors = list(roads = "/tmp/test.gpkg"),
    validate = FALSE
  )

  output <- capture.output(summary(layers))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Nemeton Layers Summary", output_str))
  expect_true(grepl("Rasters: 2", output_str))
  expect_true(grepl("Vectors: 1", output_str))
  expect_true(grepl("Created:", output_str))
})

# =============================================================================
# Additional edge cases
# =============================================================================

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

  expect_true("carbon_biomass_norm" %in% names(result))
  expect_true("water_twi_norm" %in% names(result))
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

test_that("nemeton_temporal() with three periods", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)

  sf3 <- create_test_units(n_features = 3)
  sf3$parcel_id <- paste0("P", 1:3)
  sf3$C1 <- c(20, 30, 40)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2010" = sf1, "2015" = sf2, "2020" = sf3)
  )

  expect_equal(temporal$metadata$n_periods, 3)
  expect_equal(length(temporal$periods), 3)
  expect_equal(temporal$metadata$period_labels, c("2010", "2015", "2020"))
})

test_that("print.nemeton_temporal() lists indicators from first period", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)
  sf1$C1 <- c(10, 20, 30)
  sf1$W1 <- c(5, 10, 15)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)
  sf2$C1 <- c(15, 25, 35)
  sf2$W1 <- c(8, 13, 18)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  output <- capture.output(print(temporal))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Indicators", output_str))
  expect_true(grepl("C1", output_str))
  expect_true(grepl("W1", output_str))
})

test_that("print.nemeton_temporal() returns invisible x", {
  sf1 <- create_test_units(n_features = 3)
  sf1$parcel_id <- paste0("P", 1:3)

  sf2 <- create_test_units(n_features = 3)
  sf2$parcel_id <- paste0("P", 1:3)

  temporal <- nemeton::nemeton_temporal(
    periods = list("2015" = sf1, "2020" = sf2)
  )

  result <- withVisible(capture.output(ret <- print(temporal)))
  expect_identical(ret, temporal)
})

test_that("nemeton_layers() validates=TRUE errors on nonexistent files", {
  expect_error(
    nemeton::nemeton_layers(
      rasters = list(ndvi = "/tmp/definitely_nonexistent_file_42.tif"),
      validate = TRUE
    ),
    "not found"
  )
})

test_that("nemeton_layers() metadata includes created_at and validated", {
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/fake.tif"),
    validate = FALSE
  )

  expect_true(!is.null(layers$metadata$created_at))
  expect_false(layers$metadata$validated)
})
