# Tests for temporal visualization functions (US1 - Phase 8)
#
# Temporal plots: time-series trends and heatmaps

# ==============================================================================
# PLOT TEMPORAL TREND (LINE PLOTS)
# ==============================================================================

test_that("plot_temporal_trend creates time-series plot for single indicator", {
  # Setup temporal dataset
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:5, ]
  units_2015$parcel_id <- paste0("P", 1:5)
  units_2015$C1 <- c(50, 60, 55, 65, 70)

  units_2020 <- massif_demo_units[1:5, ]
  units_2020$parcel_id <- paste0("P", 1:5)
  units_2020$C1 <- c(55, 65, 60, 70, 75)

  units_2025 <- massif_demo_units[1:5, ]
  units_2025$parcel_id <- paste0("P", 1:5)
  units_2025$C1 <- c(60, 70, 65, 75, 80)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020, "2025" = units_2025),
    dates = c("2015-01-01", "2020-01-01", "2025-01-01"),
    id_column = "parcel_id"
  )

  # Create plot
  p <- plot_temporal_trend(temporal, indicator = "C1")

  # Test output
  expect_s3_class(p, "ggplot")

  # Check plot has data
  expect_true(!is.null(p$data))
  expect_true(nrow(p$data) > 0)

  # Check plot structure
  expect_true(!is.null(p$layers))
  expect_gt(length(p$layers), 0)
})

test_that("plot_temporal_trend handles multiple indicators with facets", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, 55)
  units_2015$W1 <- c(10, 15, 12)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(55, 65, 60)
  units_2020$W1 <- c(12, 17, 14)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # Plot multiple indicators
  p <- plot_temporal_trend(temporal, indicator = c("C1", "W1"))

  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))

  # Should have faceting for multiple indicators
  expect_true("indicator" %in% names(p$data) || !is.null(p$facet))
})

test_that("plot_temporal_trend supports unit selection", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:10, ]
  units_2015$parcel_id <- paste0("P", 1:10)
  units_2015$C1 <- rnorm(10, 50, 10)

  units_2020 <- massif_demo_units[1:10, ]
  units_2020$parcel_id <- paste0("P", 1:10)
  units_2020$C1 <- rnorm(10, 55, 10)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # Plot only selected units
  p <- plot_temporal_trend(temporal, indicator = "C1", units = c("P1", "P2", "P3"))

  expect_s3_class(p, "ggplot")

  # Data should only have 3 units × 2 periods = 6 rows
  expect_true(nrow(p$data) <= 6)
})

test_that("plot_temporal_trend errors when indicator missing", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2015)
  )

  expect_error(
    plot_temporal_trend(temporal, indicator = "NONEXISTENT"),
    "Indicator.*not found"
  )
})

test_that("plot_temporal_trend validates inputs", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015)
  )

  # Invalid temporal object
  expect_error(
    plot_temporal_trend(list(), indicator = "C1"),
    "must be.*nemeton_temporal"
  )
})

# ==============================================================================
# PLOT TEMPORAL HEATMAP
# ==============================================================================

test_that("plot_temporal_heatmap creates heatmap for single unit", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, 55)
  units_2015$W1 <- c(10, 15, 12)
  units_2015$F1 <- c(30, 40, 35)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(55, 65, 60)
  units_2020$W1 <- c(12, 17, 14)
  units_2020$F1 <- c(35, 45, 40)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # Create heatmap for single unit
  p <- plot_temporal_heatmap(temporal, unit_id = "P1")

  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
  expect_true(nrow(p$data) > 0)
})

test_that("plot_temporal_heatmap supports indicator selection", {
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

  # Plot only C1 and W1
  p <- plot_temporal_heatmap(temporal, unit_id = "P1", indicators = c("C1", "W1"))

  expect_s3_class(p, "ggplot")

  # Data should only have 2 indicators
  unique_indicators <- unique(p$data$indicator)
  expect_length(unique_indicators, 2)
  expect_true(all(c("C1", "W1") %in% unique_indicators))
})

test_that("plot_temporal_heatmap supports normalization", {
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
    id_column = "parcel_id"
  )

  # With normalization
  p_norm <- plot_temporal_heatmap(temporal, unit_id = "P1", normalize = TRUE)

  expect_s3_class(p_norm, "ggplot")

  # Normalized values should be 0-1 or 0-100
  expect_true(all(p_norm$data$value >= 0))
  expect_true(all(p_norm$data$value <= 100))
})

test_that("plot_temporal_heatmap errors when unit not found", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$parcel_id <- paste0("P", 1:2)
  units_2015$C1 <- c(50, 60)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015),
    id_column = "parcel_id"
  )

  expect_error(
    plot_temporal_heatmap(temporal, unit_id = "P999"),
    "Unit.*not found"
  )
})

test_that("plot_temporal_heatmap validates inputs", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:2, ]
  units_2015$C1 <- c(50, 60)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015)
  )

  # Invalid temporal object
  expect_error(
    plot_temporal_heatmap(list(), unit_id = "P1"),
    "must be.*nemeton_temporal"
  )
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("Both temporal plots work together", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:5, ]
  units_2015$parcel_id <- paste0("P", 1:5)
  units_2015$C1 <- rnorm(5, 50, 10)
  units_2015$W1 <- rnorm(5, 15, 5)

  units_2020 <- massif_demo_units[1:5, ]
  units_2020$parcel_id <- paste0("P", 1:5)
  units_2020$C1 <- rnorm(5, 55, 10)
  units_2020$W1 <- rnorm(5, 18, 5)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020),
    id_column = "parcel_id"
  )

  # Create both types of plots
  expect_no_error({
    p_trend <- plot_temporal_trend(temporal, indicator = "C1")
    p_heatmap <- plot_temporal_heatmap(temporal, unit_id = "P1")
  })

  expect_s3_class(p_trend, "ggplot")
  expect_s3_class(p_heatmap, "ggplot")
})

test_that("Temporal visualizations handle three or more periods", {
  data(massif_demo_units)

  units_2015 <- massif_demo_units[1:3, ]
  units_2015$parcel_id <- paste0("P", 1:3)
  units_2015$C1 <- c(50, 60, 55)

  units_2020 <- massif_demo_units[1:3, ]
  units_2020$parcel_id <- paste0("P", 1:3)
  units_2020$C1 <- c(55, 65, 60)

  units_2025 <- massif_demo_units[1:3, ]
  units_2025$parcel_id <- paste0("P", 1:3)
  units_2025$C1 <- c(60, 70, 65)

  units_2030 <- massif_demo_units[1:3, ]
  units_2030$parcel_id <- paste0("P", 1:3)
  units_2030$C1 <- c(65, 75, 70)

  temporal <- nemeton_temporal(
    periods = list("2015" = units_2015, "2020" = units_2020,
                   "2025" = units_2025, "2030" = units_2030),
    id_column = "parcel_id"
  )

  p_trend <- plot_temporal_trend(temporal, indicator = "C1")
  p_heatmap <- plot_temporal_heatmap(temporal, unit_id = "P1")

  expect_s3_class(p_trend, "ggplot")
  expect_s3_class(p_heatmap, "ggplot")

  # Trend should have 3 units × 4 periods = 12 data points
  expect_equal(nrow(p_trend$data), 3 * 4)
})
