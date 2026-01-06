# Test Suite for Trade-off Analysis (T117-T118)

test_that("plot_tradeoff creates valid ggplot object (T117)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Create basic trade-off plot
  p <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B"
  )

  # Should return ggplot object
  expect_s3_class(p, "ggplot")

  # Check layers exist
  expect_gte(length(p$layers), 1)

  # Check axes are correctly mapped
  expect_equal(as.character(p$mapping$x), "family_C")
  expect_equal(as.character(p$mapping$y), "family_B")

  # Check labels
  expect_true(!is.null(p$labels$x))
  expect_true(!is.null(p$labels$y))
})

test_that("plot_tradeoff handles point customization", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Test with color mapping
  p_color <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    color = "family_P"
  )
  expect_s3_class(p_color, "ggplot")
  expect_equal(as.character(p_color$mapping$colour), "family_P")

  # Test with size mapping
  p_size <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    size = "family_P"
  )
  expect_s3_class(p_size, "ggplot")
  expect_equal(as.character(p_size$mapping$size), "family_P")

  # Test with both color and size
  p_both <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    color = "family_P",
    size = "family_P"
  )
  expect_s3_class(p_both, "ggplot")
})

test_that("plot_tradeoff adds Pareto frontier overlay correctly (T118)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Add is_optimal column for Pareto identification
  data$is_optimal <- data$id %in% fixture$expected_pareto_ids

  # Create plot with Pareto frontier
  p <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    pareto_frontier = TRUE
  )

  expect_s3_class(p, "ggplot")

  # Should have multiple layers (points + frontier)
  expect_gte(length(p$layers), 2)

  # Check that Pareto points are highlighted
  # This depends on implementation, but should have different aesthetics
})

test_that("plot_tradeoff handles Pareto optimal highlighting", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Add is_optimal column
  data$is_optimal <- FALSE
  data$is_optimal[fixture$expected_pareto_ids] <- TRUE

  # Plot with pareto_frontier=TRUE
  p <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    pareto_frontier = TRUE
  )

  expect_s3_class(p, "ggplot")

  # Multiple layers for optimal vs non-optimal points
  expect_gte(length(p$layers), 2)
})

test_that("plot_tradeoff parameter validation", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Test invalid x variable
  expect_error(
    plot_tradeoff(data, x = "invalid_x", y = "family_B"),
    "Variable.*not found"
  )

  # Test invalid y variable
  expect_error(
    plot_tradeoff(data, x = "family_C", y = "invalid_y"),
    "Variable.*not found"
  )

  # Test invalid color variable
  expect_error(
    plot_tradeoff(data, x = "family_C", y = "family_B", color = "invalid_col"),
    "Variable.*not found"
  )

  # Test non-numeric x
  data_bad <- data
  data_bad$family_C <- as.character(data_bad$family_C)
  expect_error(
    plot_tradeoff(data_bad, x = "family_C", y = "family_B"),
    "numeric"
  )
})

test_that("plot_tradeoff handles pareto_frontier without is_optimal column", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Try to plot with pareto_frontier=TRUE but no is_optimal column
  # Should either error gracefully or compute it automatically
  expect_error(
    plot_tradeoff(data, x = "family_C", y = "family_B", pareto_frontier = TRUE),
    "is_optimal.*required"
  )
})

test_that("plot_tradeoff adds labels when requested", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggrepel")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Plot with labels
  p <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    label = "name"
  )

  expect_s3_class(p, "ggplot")

  # Should have a text/label layer
  layer_classes <- sapply(p$layers, function(l) class(l$geom)[1])
  expect_true(any(grepl("text|label", tolower(layer_classes), ignore.case = TRUE)))
})

test_that("plot_tradeoff works with regular data.frame (non-sf)", {
  skip_if_not_installed("ggplot2")

  # Load fixture and convert to regular data.frame
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data_df <- as.data.frame(fixture$input_data)
  data_df$geometry <- NULL

  # Should work with regular data.frame
  p <- plot_tradeoff(
    data_df,
    x = "family_C",
    y = "family_B"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_tradeoff handles custom axis labels", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Plot with custom labels
  p <- plot_tradeoff(
    data,
    x = "family_C",
    y = "family_B",
    xlab = "Custom X Label",
    ylab = "Custom Y Label",
    title = "Custom Title"
  )

  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$x, "Custom X Label")
  expect_equal(p$labels$y, "Custom Y Label")
  expect_equal(p$labels$title, "Custom Title")
})
