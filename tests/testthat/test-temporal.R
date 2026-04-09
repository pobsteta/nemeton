# Tests for temporal analysis infrastructure (US1 - Phase 3)

test_that("nemeton_temporal creates valid temporal dataset from multiple periods", {
  # Setup: Create synthetic multi-period data
  data(massif_demo_units)

  # Simulate two periods with different indicator values
  units_2015 <- massif_demo_units[1:5, ]
  units_2015$C1 <- c(50, 60, 55, 65, 70)
  units_2015$W1 <- c(10, 15, 12, 18, 20)

  units_2020 <- massif_demo_units[1:5, ]
  units_2020$C1 <- c(55, 65, 60, 70, 75) # Increased carbon
  units_2020$W1 <- c(12, 16, 14, 19, 21) # Increased water

  # Create temporal dataset
  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    labels = c("Baseline", "Current")
  )

  # Test structure
  expect_s3_class(temporal, "nemeton_temporal")
  expect_type(temporal, "list")
  expect_named(temporal, c("periods", "metadata"))

  # Test periods
  expect_length(temporal$periods, 2)
  expect_named(temporal$periods, c("2015", "2020"))
  expect_s3_class(temporal$periods[["2015"]], "sf")
  expect_s3_class(temporal$periods[["2020"]], "sf")

  # Test metadata
  expect_named(temporal$metadata, c("dates", "period_labels", "alignment", "n_periods", "n_units", "n_complete"))
  expect_equal(temporal$metadata$n_periods, 2)
  expect_equal(temporal$metadata$n_units, 5)
  expect_equal(temporal$metadata$period_labels, c("Baseline", "Current"))
})

test_that("nemeton_temporal handles mismatched unit IDs with warning", {
  data(massif_demo_units)

  # Period 1: units 1-5
  units_2015 <- massif_demo_units[1:5, ]
  units_2015$parcel_id <- paste0("P", 1:5)
  units_2015$C1 <- c(50, 60, 55, 65, 70)

  # Period 2: units 2-6 (unit 1 missing, unit 6 added)
  units_2020 <- massif_demo_units[2:6, ]
  units_2020$parcel_id <- paste0("P", 2:6)
  units_2020$C1 <- c(65, 60, 70, 75, 80)

  # Should warn about misalignment
  expect_warning(
    temporal <- nemeton_temporal(
      periods = list("2015" = units_2015, "2020" = units_2020),
      id_column = "parcel_id"
    ),
    "units not present in all periods"
  )

  # Check alignment metadata
  expect_true("alignment" %in% names(temporal$metadata))
  expect_true(is.data.frame(temporal$metadata$alignment))
})

test_that("nemeton_temporal errors on invalid inputs", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$C1 <- c(50, 60, 55)

  # No periods provided
  expect_error(
    nemeton_temporal(periods = list()),
    "No periods provided"
  )

  # Non-sf objects
  expect_error(
    nemeton_temporal(periods = list("2015" = data.frame(x = 1:3))),
    "must be.*sf"
  )

  # Dates mismatch
  expect_error(
    nemeton_temporal(
      periods = list("2015" = units_2015, "2020" = units_2015),
      dates = c("2015-01-01") # Only one date for two periods
    ),
    "dates.*must match.*periods"
  )
})

test_that("calculate_change_rate computes absolute and relative rates", {
  # Create simple temporal dataset
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, 55)
  units_2015$W1 <- c(10, 15, 12)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(60, 70, 65) # +10 over 5 years
  units_2020$W1 <- c(12, 18, 14) # +2/+3/+2 over 5 years

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    id_column = "parcel_id"
  )

  # Calculate change rates
  rates <- calculate_change_rate(
    temporal,
    indicators = c("C1", "W1"),
    type = "both"
  )

  # Test structure
  expect_s3_class(rates, "sf")
  expect_true("C1_rate_abs" %in% names(rates))
  expect_true("C1_rate_rel" %in% names(rates))
  expect_true("W1_rate_abs" %in% names(rates))
  expect_true("W1_rate_rel" %in% names(rates))

  # Test absolute rates (per year)
  expect_equal(rates$C1_rate_abs, c(2, 2, 2), tolerance = 0.01) # (60-50)/5 = 2 tC/ha/year

  # Test relative rates (% per year)
  expect_equal(rates$C1_rate_rel[1], (60 / 50 - 1) * 100 / 5, tolerance = 0.01) # 4% per year
})

test_that("calculate_change_rate handles 'all' indicators", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$parcel_id <- paste0("P", 1:2)
  units_2015$C1 <- c(50, 60)
  units_2015$W1 <- c(10, 15)
  units_2015$F1 <- c(30, 40)

  units_2020 <- massif_demo_units[1:2, ]
  units_2020$parcel_id <- paste0("P", 1:2)
  units_2020$C1 <- c(55, 65)
  units_2020$W1 <- c(12, 17)
  units_2020$F1 <- c(35, 45)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # Calculate all indicators
  rates <- calculate_change_rate(temporal, indicators = "all", type = "absolute")

  # Should have rates for C1, W1, F1
  expect_true("C1_rate_abs" %in% names(rates))
  expect_true("W1_rate_abs" %in% names(rates))
  expect_true("F1_rate_abs" %in% names(rates))
})

test_that("calculate_change_rate errors on invalid period selection", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2015)
  )

  # Invalid period names
  expect_error(
    calculate_change_rate(temporal, period_start = "1999"),
    "Period.*not found"
  )

  expect_error(
    calculate_change_rate(temporal, period_end = "2025"),
    "Period.*not found"
  )
})

test_that("print.nemeton_temporal displays summary information", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:5, ]
  units_2015$C1 <- rnorm(5, 50, 10)

  units_2020 <- massif_demo_units[1:5, ]
  units_2020$C1 <- rnorm(5, 55, 10)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    labels = c("Baseline", "Current")
  )

  # Capture output
  output <- capture.output(print(temporal))

  # Should contain key information
  expect_true(any(grepl("nemeton_temporal", output)))
  expect_true(any(grepl("2 periods", output)))
  expect_true(any(grepl("5 units", output)))
  expect_true(any(grepl("Baseline.*Current", output)))
})

test_that("summary.nemeton_temporal provides detailed statistics", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:10, ]
  units_2015$C1 <- rnorm(10, 50, 10)
  units_2015$W1 <- rnorm(10, 15, 5)

  units_2020 <- massif_demo_units[1:10, ]
  units_2020$C1 <- rnorm(10, 55, 10)
  units_2020$W1 <- rnorm(10, 18, 5)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    labels = c("Baseline", "Current")
  )

  # Capture output
  output <- capture.output(summary(temporal))

  # Should contain summary statistics
  expect_true(any(grepl("Period", output)))
  expect_true(any(grepl("Indicators", output)))
  expect_gt(length(output), 5) # Multiple lines of output
})

test_that("nemeton_temporal preserves geometry and attributes", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$C1 <- c(50, 60, 55)
  units_2015$custom_attr <- c("A", "B", "C")

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$C1 <- c(55, 65, 60)
  units_2020$custom_attr <- c("A", "B", "C")

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020)
  )

  # Check geometry is preserved
  expect_true(all(sf::st_is(temporal$periods[["2015"]], "POLYGON") |
    sf::st_is(temporal$periods[["2015"]], "MULTIPOLYGON")))

  # Check attributes are preserved
  expect_true("custom_attr" %in% names(temporal$periods[["2015"]]))
  expect_true("C1" %in% names(temporal$periods[["2015"]]))
})

test_that("calculate_change_rate handles NA values appropriately", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, NA) # One NA value

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(55, NA, 65) # Different NA position

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  rates <- calculate_change_rate(temporal, indicators = "C1", type = "absolute")

  # First unit: valid change (55-50)/years
  expect_false(is.na(rates$C1_rate_abs[1]))

  # Second unit: NA in 2020, should produce NA rate
  expect_true(is.na(rates$C1_rate_abs[2]))

  # Third unit: NA in 2015, should produce NA rate
  expect_true(is.na(rates$C1_rate_abs[3]))
})

test_that("nemeton_temporal works with single indicator", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  units_2020 <- massif_demo_units[1:2, ]
  units_2020$C1 <- c(55, 65)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020)
  )

  expect_s3_class(temporal, "nemeton_temporal")
  expect_equal(temporal$metadata$n_periods, 2)
})

test_that("calculate_change_rate type parameter works correctly", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$parcel_id <- paste0("P", 1:2)
  units_2015$C1 <- c(50, 60)

  units_2020 <- massif_demo_units[1:2, ]
  units_2020$parcel_id <- paste0("P", 1:2)
  units_2020$C1 <- c(60, 70)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # Absolute only
  rates_abs <- calculate_change_rate(temporal, indicators = "C1", type = "absolute")
  expect_true("C1_rate_abs" %in% names(rates_abs))
  expect_false("C1_rate_rel" %in% names(rates_abs))

  # Relative only
  rates_rel <- calculate_change_rate(temporal, indicators = "C1", type = "relative")
  expect_true("C1_rate_rel" %in% names(rates_rel))
  expect_false("C1_rate_abs" %in% names(rates_rel))

  # Both
  rates_both <- calculate_change_rate(temporal, indicators = "C1", type = "both")
  expect_true("C1_rate_abs" %in% names(rates_both))
  expect_true("C1_rate_rel" %in% names(rates_both))
})

# ==============================================================================
# Coverage expansion: uncovered paths in temporal.R
# ==============================================================================

# --- calculate_change_rate: year parsing from period names (no dates) ---

test_that("calculate_change_rate parses years from period names when no dates", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, 55)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(60, 70, 65)

  # Create without dates - period names are "2015" and "2020" (year format)
  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # The dates should be auto-parsed from names "2015" and "2020"
  # But calculate_change_rate also has a fallback path: when dates exist but
  # are auto-generated, it uses difftime. Let's test the year-parsing path
  # by removing dates from metadata.
  temporal$metadata$dates <- NULL

  rates <- calculate_change_rate(temporal, indicators = "C1", type = "absolute")

  # Time diff = 2020 - 2015 = 5 years
  # Absolute rate for unit 1: (60-50)/5 = 2
  expect_equal(rates$C1_rate_abs[1], 2, tolerance = 0.01)
  expect_equal(rates$C1_rate_abs[2], 2, tolerance = 0.01)
})

test_that("calculate_change_rate warns when period names are not years and no dates", {
  data(massif_demo_units)

  units_a <- massif_demo_units[1:2, ]
  units_a$parcel_id <- paste0("P", 1:2)
  units_a$C1 <- c(50, 60)

  units_b <- massif_demo_units[1:2, ]
  units_b$parcel_id <- paste0("P", 1:2)
  units_b$C1 <- c(60, 70)

  temporal <- nemeton_temporal(
    periods = list("baseline" = units_a, "current" = units_b),
    id_column = "parcel_id"
  )

  # Remove auto-generated dates (period names aren't year-like so dates=NULL)
  temporal$metadata$dates <- NULL

  # Should warn about assuming 1 year
  expect_warning(
    rates <- calculate_change_rate(temporal, indicators = "C1", type = "absolute"),
    "Cannot determine time difference|1 year"
  )

  # With time_diff=1, rate = (60-50)/1 = 10
  expect_equal(rates$C1_rate_abs[1], 10, tolerance = 0.01)
})

# --- calculate_change_rate: relative-only type ---

test_that("calculate_change_rate relative type computes only relative rates", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 100, 200)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(60, 120, 220)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    id_column = "parcel_id"
  )

  rates <- calculate_change_rate(temporal, indicators = "C1", type = "relative")

  # Only relative columns
  expect_true("C1_rate_rel" %in% names(rates))
  expect_false("C1_rate_abs" %in% names(rates))

  # Relative rate for unit 1: ((60/50) - 1) * 100 / time_diff
  time_diff <- as.numeric(difftime(as.Date("2020-01-01"), as.Date("2015-01-01"), units = "days")) / 365.25
  expected_rel <- ((60 / 50) - 1) * 100 / time_diff
  expect_equal(rates$C1_rate_rel[1], expected_rel, tolerance = 0.01)
})

# --- calculate_change_rate: indicator missing in one period ---

test_that("calculate_change_rate warns when indicator missing in one period", {
  data(massif_demo_units)

  # Use minimal columns - drop everything except geometry and parcel_id
  units_2015 <- massif_demo_units[1:2, "geometry"]
  units_2015$parcel_id <- paste0("P", 1:2)
  units_2015$C1 <- c(50, 60)

  units_2020 <- massif_demo_units[1:2, "geometry"]
  units_2020$parcel_id <- paste0("P", 1:2)
  units_2020$C1 <- c(55, 65)
  units_2020$custom_metric <- c(10, 15)  # Only in 2020

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    id_column = "parcel_id"
  )

  # custom_metric is not in 2015, should warn and skip
  expect_warning(
    rates <- calculate_change_rate(temporal, indicators = c("C1", "custom_metric"), type = "absolute"),
    "not found in both periods"
  )

  # C1 should still have rates
  expect_true("C1_rate_abs" %in% names(rates))
  # custom_metric should not have rates (skipped)
  expect_false("custom_metric_rate_abs" %in% names(rates))
})

# --- calculate_change_rate: "all" indicators auto-detect (already partially tested above) ---

test_that("calculate_change_rate 'all' auto-detects common numeric indicators", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$parcel_id <- paste0("P", 1:2)
  units_2015$C1 <- c(50, 60)
  units_2015$W1 <- c(10, 15)

  units_2020 <- massif_demo_units[1:2, ]
  units_2020$parcel_id <- paste0("P", 1:2)
  units_2020$C1 <- c(55, 65)
  units_2020$W1 <- c(12, 17)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    id_column = "parcel_id"
  )

  rates <- calculate_change_rate(temporal, indicators = "all", type = "both")

  # Both C1 and W1 should be auto-detected
  expect_true("C1_rate_abs" %in% names(rates))
  expect_true("C1_rate_rel" %in% names(rates))
  expect_true("W1_rate_abs" %in% names(rates))
  expect_true("W1_rate_rel" %in% names(rates))
})

# --- print.nemeton_temporal: dates and incomplete units ---

test_that("print.nemeton_temporal shows dates when available", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$C1 <- c(50, 60, 70)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$C1 <- c(55, 65, 75)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    dates = c("2015-01-01", "2020-01-01"),
    labels = c("Baseline", "Current")
  )

  output <- capture.output(print(temporal))

  # Should contain date range
  expect_true(any(grepl("Date range", output)))
  expect_true(any(grepl("2015", output)))
  expect_true(any(grepl("2020", output)))
})

test_that("print.nemeton_temporal shows incomplete units warning", {
  data(massif_demo_units)

  # Period 1: units 1-5
  units_2015 <- massif_demo_units[1:5, ]
  units_2015$parcel_id <- paste0("P", 1:5)
  units_2015$C1 <- c(50, 60, 55, 65, 70)

  # Period 2: units 3-7 (partial overlap)
  units_2020 <- massif_demo_units[3:7, ]
  units_2020$parcel_id <- paste0("P", 3:7)
  units_2020$C1 <- c(60, 70, 75, 80, 85)

  expect_warning(
    temporal <- nemeton_temporal(
      periods = list("2015" = units_2015, "2020" = units_2020),
      id_column = "parcel_id"
    ),
    "units not present in all periods"
  )

  output <- capture.output(print(temporal))

  # Should contain warning about incomplete units
  expect_true(any(grepl("not present in all periods|units tracked", output)))
})

test_that("print.nemeton_temporal lists indicators from first period", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$C1 <- c(50, 60, 70)
  units_2015$W1 <- c(10, 15, 20)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$C1 <- c(55, 65, 75)
  units_2020$W1 <- c(12, 17, 22)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020)
  )

  output <- capture.output(print(temporal))

  # Should list indicators
  expect_true(any(grepl("Indicators", output)))
  expect_true(any(grepl("C1", output)))
  expect_true(any(grepl("W1", output)))
})

# --- summary.nemeton_temporal: detailed statistics ---

test_that("summary.nemeton_temporal shows period summaries with indicator ranges", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:5, ]
  units_2015$C1 <- c(50, 60, 55, 65, 70)
  units_2015$W1 <- c(10, 15, 12, 18, 20)

  units_2020 <- massif_demo_units[1:5, ]
  units_2020$C1 <- c(55, 65, 60, 70, 75)
  units_2020$W1 <- c(12, 16, 14, 19, 21)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    labels = c("Baseline", "Current")
  )

  output <- capture.output(summary(temporal))

  # Should contain nemeton_temporal header from print
  expect_true(any(grepl("nemeton_temporal", output)))
  # Should contain period summaries
  expect_true(any(grepl("Period summaries", output)))
  expect_true(any(grepl("Baseline", output)))
  expect_true(any(grepl("Current", output)))
  # Should contain indicator ranges with mean
  expect_true(any(grepl("Indicator ranges", output)))
  expect_true(any(grepl("C1", output)))
  expect_true(any(grepl("W1", output)))
  expect_true(any(grepl("mean", output)))
  # Should contain unit counts per period
  expect_true(any(grepl("Units: 5", output)))
  # Should have multiple lines of output
  expect_gt(length(output), 10)
})

test_that("summary.nemeton_temporal returns invisible object", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$C1 <- c(50, 60, 70)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$C1 <- c(55, 65, 75)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    labels = c("Baseline", "Current")
  )

  result <- capture.output(ret <- summary(temporal))

  # Should return the original object invisibly
  expect_s3_class(ret, "nemeton_temporal")
})

# --- nemeton_temporal: labels default to period names ---

test_that("nemeton_temporal uses period names as default labels", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  units_2020 <- massif_demo_units[1:2, ]
  units_2020$C1 <- c(55, 65)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020)
  )

  expect_equal(temporal$metadata$period_labels, c("2015", "2020"))
})

# --- nemeton_temporal: auto-parse dates from year-like period names ---

test_that("nemeton_temporal auto-parses dates from year-like period names", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  units_2020 <- massif_demo_units[1:2, ]
  units_2020$C1 <- c(55, 65)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020)
    # No dates provided - should auto-parse from "2015", "2020"
  )

  expect_false(is.null(temporal$metadata$dates))
  expect_equal(temporal$metadata$dates, as.Date(c("2015-01-01", "2020-01-01")))
})

# ==============================================================================
# (migrated from test-cov80-batch13.R)
# ==============================================================================

# --- nemeton_temporal() ---

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

# --- calculate_change_rate() ---

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

  # No dates, names are not years -> should warn about time_diff
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

# --- print.nemeton_temporal() ---

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

# --- summary.nemeton_temporal() ---

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

# --- Additional edge cases ---

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
