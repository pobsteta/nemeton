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
    x = "famille_carbone",
    y = "famille_biodiversite"
  )

  # Should return ggplot object
  expect_s3_class(p, "ggplot")

  # Check layers exist
  expect_gte(length(p$layers), 1)

  # Check axes are correctly mapped
  expect_equal(rlang::as_label(p$mapping$x), "famille_carbone")
  expect_equal(rlang::as_label(p$mapping$y), "famille_biodiversite")

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
    x = "famille_carbone",
    y = "famille_biodiversite",
    color = "famille_production"
  )
  expect_s3_class(p_color, "ggplot")
  expect_equal(rlang::as_label(p_color$mapping$colour), "famille_production")

  # Test with size mapping
  p_size <- plot_tradeoff(
    data,
    x = "famille_carbone",
    y = "famille_biodiversite",
    size = "famille_production"
  )
  expect_s3_class(p_size, "ggplot")
  expect_equal(rlang::as_label(p_size$mapping$size), "famille_production")

  # Test with both color and size
  p_both <- plot_tradeoff(
    data,
    x = "famille_carbone",
    y = "famille_biodiversite",
    color = "famille_production",
    size = "famille_production"
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
    x = "famille_carbone",
    y = "famille_biodiversite",
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
    x = "famille_carbone",
    y = "famille_biodiversite",
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
    plot_tradeoff(data, x = "invalid_x", y = "famille_biodiversite"),
    "Variable.*not found"
  )

  # Test invalid y variable
  expect_error(
    plot_tradeoff(data, x = "famille_carbone", y = "invalid_y"),
    "Variable.*not found"
  )

  # Test invalid color variable
  expect_error(
    plot_tradeoff(data, x = "famille_carbone", y = "famille_biodiversite", color = "invalid_col"),
    "Variable.*not found"
  )

  # Test non-numeric x
  data_bad <- data
  data_bad$famille_carbone <- as.character(data_bad$famille_carbone)
  expect_error(
    plot_tradeoff(data_bad, x = "famille_carbone", y = "famille_biodiversite"),
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
    plot_tradeoff(data, x = "famille_carbone", y = "famille_biodiversite", pareto_frontier = TRUE),
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
    x = "famille_carbone",
    y = "famille_biodiversite",
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
    x = "famille_carbone",
    y = "famille_biodiversite"
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
    x = "famille_carbone",
    y = "famille_biodiversite",
    xlab = "Custom X Label",
    ylab = "Custom Y Label",
    title = "Custom Title"
  )

  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$x, "Custom X Label")
  expect_equal(p$labels$y, "Custom Y Label")
  expect_equal(p$labels$title, "Custom Title")
})

# ==============================================================================
# (migrated from test-coverage-boost2.R)
# ==============================================================================

test_that("plot_tradeoff works with basic sf data", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$famille_carbone <- runif(10, 30, 90)
  units$famille_biodiversite <- runif(10, 40, 85)
  p <- plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff works with data.frame", {
  df <- data.frame(famille_carbone = runif(10), famille_biodiversite = runif(10))
  p <- plot_tradeoff(df, x = "famille_carbone", y = "famille_biodiversite")
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
  units$famille_biodiversite <- 1:5
  expect_error(
    plot_tradeoff(units, x = "nonexistent", y = "famille_biodiversite"),
    regexp = NULL
  )
})

test_that("plot_tradeoff errors on missing y variable", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- 1:5
  expect_error(
    plot_tradeoff(units, x = "famille_carbone", y = "nonexistent"),
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
  units$famille_carbone <- runif(10, 30, 90)
  units$famille_biodiversite <- runif(10, 40, 85)
  units$famille_eau <- runif(10, 20, 70)
  p <- plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite", color = "famille_eau")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on missing color variable", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- 1:5
  units$famille_biodiversite <- 5:1
  expect_error(
    plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite", color = "nonexistent"),
    regexp = NULL
  )
})

test_that("plot_tradeoff with size parameter", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$famille_carbone <- runif(10, 30, 90)
  units$famille_biodiversite <- runif(10, 40, 85)
  units$area_ha <- runif(10, 1, 50)
  p <- plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite", size = "area_ha")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on missing size variable", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- 1:5
  units$famille_biodiversite <- 5:1
  expect_error(
    plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite", size = "nonexistent"),
    regexp = NULL
  )
})

test_that("plot_tradeoff with pareto_frontier", {
  units <- create_test_units(n_features = 10)
  set.seed(42)
  units$famille_carbone <- runif(10, 30, 90)
  units$famille_biodiversite <- runif(10, 40, 85)
  units$is_optimal <- c(TRUE, FALSE, TRUE, FALSE, FALSE,
                        FALSE, FALSE, TRUE, FALSE, FALSE)
  p <- plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite",
                     pareto_frontier = TRUE)
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors when pareto without is_optimal", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- 1:5
  units$famille_biodiversite <- 5:1
  expect_error(
    plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite",
                  pareto_frontier = TRUE),
    regexp = NULL
  )
})

test_that("plot_tradeoff with custom labels", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- c(80, 60, 40, 20, 50)
  units$famille_biodiversite <- c(20, 40, 60, 80, 50)
  units$name <- paste0("Parcel_", 1:5)
  p <- plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite",
                     label = "name",
                     xlab = "Carbon", ylab = "Biodiversity",
                     title = "Test Trade-off")
  expect_true(inherits(p, "ggplot"))
})

test_that("plot_tradeoff errors on missing label variable", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- 1:5
  units$famille_biodiversite <- 5:1
  expect_error(
    plot_tradeoff(units, x = "famille_carbone", y = "famille_biodiversite",
                  label = "nonexistent"),
    regexp = NULL
  )
})
