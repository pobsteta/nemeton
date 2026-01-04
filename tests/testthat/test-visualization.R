test_that("plot_indicators_map creates ggplot for single indicator", {
  # Create test data
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon <- c(100, 200, 300, 400, 500)

  # Create plot
  p <- plot_indicators_map(units, indicators = "carbon")

  expect_s3_class(p, "ggplot")
  expect_s3_class(p, "gg")
})

test_that("plot_indicators_map creates faceted plot for multiple indicators", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon <- c(100, 200, 300, 400, 500)
  units$water <- c(10, 20, 30, 40, 50)

  p <- plot_indicators_map(
    units,
    indicators = c("carbon", "water"),
    facet = TRUE
  )

  expect_s3_class(p, "ggplot")

  # Check that faceting was applied
  expect_true("FacetWrap" %in% class(p$facet))
})

test_that("plot_indicators_map auto-detects indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon <- c(100, 200, 300)
  units$biodiversity <- c(10, 20, 30)

  # Should auto-detect carbon and biodiversity
  p <- plot_indicators_map(units)

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map accepts different palettes", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon <- c(100, 200, 300)

  # Viridis
  p1 <- plot_indicators_map(units, indicators = "carbon", palette = "viridis")
  expect_s3_class(p1, "ggplot")

  # ColorBrewer
  p2 <- plot_indicators_map(units, indicators = "carbon", palette = "Greens")
  expect_s3_class(p2, "ggplot")

  p3 <- plot_indicators_map(units, indicators = "carbon", palette = "RdYlGn")
  expect_s3_class(p3, "ggplot")
})

test_that("plot_indicators_map accepts custom title and legend", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon <- c(100, 200, 300)

  p <- plot_indicators_map(
    units,
    indicators = "carbon",
    title = "Custom Title",
    legend_title = "Custom Legend"
  )

  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "Custom Title")
  # Legend title is set in scale, check that scale exists
  expect_true(length(p$scales$scales) > 0)
})

test_that("plot_indicators_map accepts custom breaks and labels", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon <- c(0, 25, 50, 75, 100)

  p <- plot_indicators_map(
    units,
    indicators = "carbon",
    breaks = c(0, 50, 100),
    labels = c("Low", "Medium", "High")
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map handles normalized indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon <- c(100, 200, 300)

  # Normalize
  normalized <- normalize_indicators(units, indicators = "carbon", method = "minmax")

  # Plot normalized
  p <- plot_indicators_map(normalized, indicators = "carbon_norm")

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map works with composite index", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon_norm <- c(0, 25, 50, 75, 100)
  units$water_norm <- c(0, 25, 50, 75, 100)

  # Create composite
  result <- create_composite_index(
    units,
    indicators = c("carbon_norm", "water_norm"),
    name = "ecosystem_health"
  )

  # Plot composite
  p <- plot_indicators_map(result, indicators = "ecosystem_health")

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map errors on non-sf input", {
  df <- data.frame(carbon = c(1, 2, 3))

  expect_error(
    plot_indicators_map(df, indicators = "carbon"),
    "must be an.*sf.*object"
  )
})

test_that("plot_indicators_map errors on missing indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon <- c(100, 200, 300)

  expect_error(
    plot_indicators_map(units, indicators = "missing_column"),
    "not found"
  )
})

test_that("plot_indicators_map errors when no indicators found", {
  units <- nemeton_units(create_test_units(n_features = 3))
  # No indicator columns

  expect_error(
    plot_indicators_map(units),
    "No indicator columns found"
  )
})

test_that("plot_comparison_map creates side-by-side comparison", {
  # Create two datasets
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$carbon <- c(150, 250, 350)

  # Create comparison
  p <- plot_comparison_map(
    units1,
    units2,
    indicator = "carbon",
    labels = c("Current", "Future")
  )

  expect_s3_class(p, "ggplot")

  # Check faceting
  expect_true("FacetWrap" %in% class(p$facet))
})

test_that("plot_comparison_map errors on non-sf inputs", {
  df1 <- data.frame(carbon = c(1, 2, 3))
  df2 <- data.frame(carbon = c(4, 5, 6))

  expect_error(
    plot_comparison_map(df1, df2, indicator = "carbon"),
    "must be.*sf.*objects"
  )
})

test_that("plot_comparison_map errors when indicator missing", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$water <- c(10, 20, 30)  # Different indicator

  expect_error(
    plot_comparison_map(units1, units2, indicator = "carbon"),
    "must exist in both datasets"
  )
})

test_that("plot_difference_map creates absolute difference map", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$carbon <- c(150, 250, 350)  # +50 each

  p <- plot_difference_map(
    units1,
    units2,
    indicator = "carbon",
    type = "absolute"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map creates relative difference map", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$carbon <- c(150, 250, 350)  # +50% for first, +25% for second, etc.

  p <- plot_difference_map(
    units1,
    units2,
    indicator = "carbon",
    type = "relative"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map errors on non-sf inputs", {
  df1 <- data.frame(carbon = c(1, 2, 3))
  df2 <- data.frame(carbon = c(4, 5, 6))

  expect_error(
    plot_difference_map(df1, df2, indicator = "carbon"),
    "must be.*sf.*objects"
  )
})

test_that("clean_indicator_name formats names correctly", {
  # Test internal function through plotting
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_norm <- c(0, 50, 100)

  p <- plot_indicators_map(units, indicators = "carbon_norm")

  # Check that plot was created successfully
  # The cleaning happens in the scale name, which is in p$scales
  expect_s3_class(p, "ggplot")
  expect_true(length(p$scales$scales) > 0)
})

test_that("visualization works with real cadastral data", {
  skip_if_not_installed("here")

  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(cadastral_path)

  # Add some indicator values
  units$carbon <- 250
  units$biodiversity <- 30
  units$water <- 0.75

  # Single indicator map
  p1 <- plot_indicators_map(units, indicators = "carbon")
  expect_s3_class(p1, "ggplot")

  # Multiple indicators
  p2 <- plot_indicators_map(
    units,
    indicators = c("carbon", "biodiversity", "water"),
    facet = TRUE
  )
  expect_s3_class(p2, "ggplot")
})

test_that("full visualization workflow works end-to-end", {
  # Create test data
  units <- nemeton_units(create_test_units(n_features = 10))
  units$carbon <- seq(100, 1000, length.out = 10)
  units$biodiversity <- seq(10, 100, length.out = 10)
  units$water <- seq(5, 50, length.out = 10)
  units$accessibility <- seq(0, 100, length.out = 10)

  # Step 1: Normalize
  normalized <- normalize_indicators(
    units,
    indicators = c("carbon", "biodiversity", "water", "accessibility"),
    method = "minmax"
  )

  # Step 2: Invert accessibility
  normalized <- invert_indicator(
    normalized,
    indicators = "accessibility_norm",
    suffix = "_wilderness"
  )

  # Step 3: Create composite
  result <- create_composite_index(
    normalized,
    indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
    weights = c(0.4, 0.4, 0.2),
    name = "ecosystem_health"
  )

  # Step 4: Visualize raw indicators
  p1 <- plot_indicators_map(
    units,
    indicators = c("carbon", "biodiversity"),
    palette = "Greens"
  )
  expect_s3_class(p1, "ggplot")

  # Step 5: Visualize normalized indicators
  p2 <- plot_indicators_map(
    normalized,
    indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
    palette = "viridis",
    facet = TRUE,
    ncol = 3
  )
  expect_s3_class(p2, "ggplot")

  # Step 6: Visualize composite index
  p3 <- plot_indicators_map(
    result,
    indicators = "ecosystem_health",
    palette = "RdYlGn",
    title = "Ecosystem Health Index"
  )
  expect_s3_class(p3, "ggplot")

  # All should be ggplot objects ready for display or saving
  expect_s3_class(p1, "ggplot")
  expect_s3_class(p2, "ggplot")
  expect_s3_class(p3, "ggplot")
})

test_that("plots can be saved to file", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon <- c(100, 200, 300, 400, 500)

  p <- plot_indicators_map(units, indicators = "carbon")

  # Test that ggsave works (but don't actually save in tests)
  temp_file <- tempfile(fileext = ".png")

  expect_silent({
    ggplot2::ggsave(temp_file, p, width = 8, height = 6, dpi = 150)
  })

  expect_true(file.exists(temp_file))

  # Clean up
  unlink(temp_file)
})
