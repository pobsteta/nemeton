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
