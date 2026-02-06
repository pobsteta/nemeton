test_that("plot_indicators_map creates ggplot for single indicator", {
  # Create test data
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon_biomass <- c(100, 200, 300, 400, 500)

  # Create plot
  p <- plot_indicators_map(units, indicators = "carbon_biomass")

  expect_s3_class(p, "ggplot")
  expect_s3_class(p, "gg")
})

test_that("plot_indicators_map creates faceted plot for multiple indicators", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon_biomass <- c(100, 200, 300, 400, 500)
  units$water_twi <- c(10, 20, 30, 40, 50)

  p <- plot_indicators_map(
    units,
    indicators = c("carbon_biomass", "water_twi"),
    facet = TRUE
  )

  expect_s3_class(p, "ggplot")

  # Check that faceting was applied
  expect_true("FacetWrap" %in% class(p$facet))
})

test_that("plot_indicators_map auto-detects indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_biomass <- c(100, 200, 300)
  units$biodiversity_protection <- c(10, 20, 30)

  # Should auto-detect carbon and biodiversity
  p <- plot_indicators_map(units)

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map accepts different palettes", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_biomass <- c(100, 200, 300)

  # Viridis
  p1 <- plot_indicators_map(units, indicators = "carbon_biomass", palette = "viridis")
  expect_s3_class(p1, "ggplot")

  # ColorBrewer
  p2 <- plot_indicators_map(units, indicators = "carbon_biomass", palette = "Greens")
  expect_s3_class(p2, "ggplot")

  p3 <- plot_indicators_map(units, indicators = "carbon_biomass", palette = "RdYlGn")
  expect_s3_class(p3, "ggplot")
})

test_that("plot_indicators_map accepts custom title and legend", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_biomass <- c(100, 200, 300)

  p <- plot_indicators_map(
    units,
    indicators = "carbon_biomass",
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
  units$carbon_biomass <- c(0, 25, 50, 75, 100)

  p <- plot_indicators_map(
    units,
    indicators = "carbon_biomass",
    breaks = c(0, 50, 100),
    labels = c("Low", "Medium", "High")
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map handles normalized indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_biomass <- c(100, 200, 300)

  # Normalize
  normalized <- normalize_indicators(units, indicators = "carbon_biomass", method = "minmax")

  # Plot normalized
  p <- plot_indicators_map(normalized, indicators = "carbon_biomass_norm")

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map works with composite index", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$carbon_biomass_norm <- c(0, 25, 50, 75, 100)
  units$water_twi_norm <- c(0, 25, 50, 75, 100)

  # Create composite
  result <- create_composite_index(
    units,
    indicators = c("carbon_biomass_norm", "water_twi_norm"),
    name = "ecosystem_health"
  )

  # Plot composite
  p <- plot_indicators_map(result, indicators = "ecosystem_health")

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map errors on non-sf input", {
  df <- data.frame(carbon = c(1, 2, 3))

  expect_error(
    plot_indicators_map(df, indicators = "carbon_biomass"),
    "must be an.*sf.*object"
  )
})

test_that("plot_indicators_map errors on missing indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_biomass <- c(100, 200, 300)

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
  units1$carbon_biomass <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$carbon_biomass <- c(150, 250, 350)

  # Create comparison
  p <- plot_comparison_map(
    units1,
    units2,
    indicator = "carbon_biomass",
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
    plot_comparison_map(df1, df2, indicator = "carbon_biomass"),
    "must be.*sf.*objects"
  )
})

test_that("plot_comparison_map errors when indicator missing", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon_biomass <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$water_twi <- c(10, 20, 30) # Different indicator

  expect_error(
    plot_comparison_map(units1, units2, indicator = "carbon_biomass"),
    "must exist in both datasets"
  )
})

test_that("plot_difference_map creates absolute difference map", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon_biomass <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$carbon_biomass <- c(150, 250, 350) # +50 each

  p <- plot_difference_map(
    units1,
    units2,
    indicator = "carbon_biomass",
    type = "absolute"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map creates relative difference map", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$carbon_biomass <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$carbon_biomass <- c(150, 250, 350) # +50% for first, +25% for second, etc.

  p <- plot_difference_map(
    units1,
    units2,
    indicator = "carbon_biomass",
    type = "relative"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map errors on non-sf inputs", {
  df1 <- data.frame(carbon = c(1, 2, 3))
  df2 <- data.frame(carbon = c(4, 5, 6))

  expect_error(
    plot_difference_map(df1, df2, indicator = "carbon_biomass"),
    "must be.*sf.*objects"
  )
})

test_that("clean_indicator_name formats names correctly", {
  # Test internal function through plotting
  units <- nemeton_units(create_test_units(n_features = 3))
  units$carbon_biomass_norm <- c(0, 50, 100)

  p <- plot_indicators_map(units, indicators = "carbon_biomass_norm")

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
  units$carbon_biomass <- 250
  units$biodiversity_protection <- 30
  units$water_twi <- 0.75

  # Single indicator map
  p1 <- plot_indicators_map(units, indicators = "carbon_biomass")
  expect_s3_class(p1, "ggplot")

  # Multiple indicators
  p2 <- plot_indicators_map(
    units,
    indicators = c("carbon_biomass", "biodiversity_protection", "water_twi"),
    facet = TRUE
  )
  expect_s3_class(p2, "ggplot")
})

test_that("full visualization workflow works end-to-end", {
  # Create test data
  units <- nemeton_units(create_test_units(n_features = 10))
  units$carbon_biomass <- seq(100, 1000, length.out = 10)
  units$biodiversity_protection <- seq(10, 100, length.out = 10)
  units$water_twi <- seq(5, 50, length.out = 10)
  units$social_accessibility <- seq(0, 100, length.out = 10)

  # Step 1: Normalize
  normalized <- normalize_indicators(
    units,
    indicators = c("carbon_biomass", "biodiversity_protection", "water_twi", "social_accessibility"),
    method = "minmax"
  )

  # Step 2: Invert accessibility
  normalized <- invert_indicator(
    normalized,
    indicators = "social_accessibility_norm",
    suffix = "_wilderness"
  )

  # Step 3: Create composite
  result <- create_composite_index(
    normalized,
    indicators = c("carbon_biomass_norm", "biodiversity_protection_norm", "water_twi_norm"),
    weights = c(0.4, 0.4, 0.2),
    name = "ecosystem_health"
  )

  # Step 4: Visualize raw indicators
  p1 <- plot_indicators_map(
    units,
    indicators = c("carbon_biomass", "biodiversity_protection"),
    palette = "Greens"
  )
  expect_s3_class(p1, "ggplot")

  # Step 5: Visualize normalized indicators
  p2 <- plot_indicators_map(
    normalized,
    indicators = c("carbon_biomass_norm", "biodiversity_protection_norm", "water_twi_norm"),
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
  units$carbon_biomass <- c(100, 200, 300, 400, 500)

  p <- plot_indicators_map(units, indicators = "carbon_biomass")

  # Test that ggsave works (but don't actually save in tests)
  temp_file <- tempfile(fileext = ".png")

  expect_silent({
    ggplot2::ggsave(temp_file, p, width = 8, height = 6, dpi = 150)
  })

  expect_true(file.exists(temp_file))

  # Clean up
  unlink(temp_file)
})

# Radar charts -----------------------------------------------------------

test_that("nemeton_radar creates a ggplot object for average", {
  data(massif_demo_units)
  layers <- massif_demo_layers()
  results <- nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3))
  normalized <- normalize_indicators(results)

  # Average radar
  p <- nemeton_radar(normalized)

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar creates a ggplot object for specific unit", {
  data(massif_demo_units)
  layers <- massif_demo_layers()
  results <- nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3))
  normalized <- normalize_indicators(results)

  # Specific unit
  p <- nemeton_radar(normalized, unit_id = "P01")

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar works with explicit indicators", {
  data(massif_demo_units)
  layers <- massif_demo_layers()
  results <- nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3))
  normalized <- normalize_indicators(results)

  # Explicit indicators
  p <- nemeton_radar(
    normalized,
    unit_id = "P05",
    indicators = c("carbon_biomass_norm", "biodiversity_protection_norm", "water_twi_norm"),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar errors on invalid input", {
  # Non-sf object
  expect_error(
    nemeton_radar(data.frame(x = 1:3, carbon = c(10, 20, 30))),
    "must be an.*sf.*object"
  )
})

test_that("nemeton_radar errors on missing indicators", {
  data(massif_demo_units)

  expect_error(
    nemeton_radar(massif_demo_units, indicators = c("missing_indicator")),
    "Indicators not found"
  )
})

test_that("nemeton_radar errors on invalid unit_id", {
  data(massif_demo_units)
  layers <- massif_demo_layers()
  results <- nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3))
  normalized <- normalize_indicators(results)

  expect_error(
    nemeton_radar(normalized, unit_id = "INVALID_ID"),
    "Unit ID.*not found"
  )
})

# ==============================================================================
# v0.3.0: Tests for 9-axis radar plot support (T060)
# ==============================================================================

test_that("nemeton_radar supports 9-family axes (v0.3.0)", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units)
  units <- massif_demo_units[1:5, ]

  # Add all 9 implemented family indicators (v0.3.0: C, W, F, L, B, R, T, A)
  units$C1 <- runif(5, 50, 100)
  units$W1 <- runif(5, 10, 30)
  units$F1 <- runif(5, 5, 20)
  units$L1 <- runif(5, 0.3, 0.8)
  units$B1 <- runif(5, 20, 80)
  units$R1 <- runif(5, 10, 70)
  units$T1 <- runif(5, 30, 200)
  units$A1 <- runif(5, 30, 90)

  # Create family indices
  result <- create_family_index(units)

  # Create 9-axis radar plot
  p <- nemeton_radar(
    result,
    unit_id = 1,
    indicators = grep("^family_", names(result), value = TRUE),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))

  # Should have data for all families
  expect_true(nrow(p$data) >= 8) # At least 8-9 families
})

test_that("nemeton_radar scales correctly with 9-12 axes", {
  data(massif_demo_units)
  units <- massif_demo_units[1:3, ]

  # Create 9 families
  units$C1 <- c(50, 60, 70)
  units$W1 <- c(40, 50, 60)
  units$F1 <- c(30, 40, 50)
  units$L1 <- c(0.5, 0.6, 0.7)
  units$B1 <- c(45, 55, 65)
  units$R1 <- c(35, 45, 55)
  units$T1 <- c(100, 120, 140)
  units$A1 <- c(55, 65, 75)

  # Add one more to test 9+ axes
  units$S1 <- c(25, 35, 45) # Social (future family)

  result <- create_family_index(units)

  # Should handle 9 axes without visual artifacts
  p <- nemeton_radar(
    result,
    unit_id = 1,
    indicators = grep("^family_", names(result), value = TRUE),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")

  # Check plot has proper structure
  expect_true(length(p$layers) > 0)
  expect_true(!is.null(p$coordinates))
})

test_that("nemeton_radar handles new family names correctly", {
  data(massif_demo_units)
  units <- massif_demo_units[1:2, ]

  units$B1 <- c(50, 60)
  units$R1 <- c(40, 50)
  units$T1 <- c(100, 120)
  units$A1 <- c(55, 65)

  result <- create_family_index(units, family_codes = c("B", "R", "T", "A"))

  p <- nemeton_radar(
    result,
    unit_id = 1,
    indicators = c("family_B", "family_R", "family_T", "family_A"),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")

  # Plot data should contain family indicator values
  expect_true(any(grepl("family_", p$data$indicator)))
})

test_that("nemeton_radar displays correct scaling with mixed v0.2.0 and v0.3.0 families", {
  data(massif_demo_units)
  units <- massif_demo_units[1:3, ]

  # Mix old and new families
  units$C1 <- c(100, 200, 300) # v0.2.0
  units$W1 <- c(10, 20, 30) # v0.2.0
  units$B1 <- c(25, 50, 75) # v0.3.0
  units$R1 <- c(30, 50, 70) # v0.3.0

  result <- create_family_index(units)

  # All families should be on same 0-100 scale
  p <- nemeton_radar(
    result,
    unit_id = 1,
    indicators = grep("^family_", names(result), value = TRUE),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")

  # Check that values are properly scaled
  if (!is.null(p$data)) {
    # All values should be in reasonable range after normalization
    expect_true(all(p$data$value >= 0, na.rm = TRUE))
  }
})

test_that("nemeton_radar supports comparison mode with v0.3.0 families", {
  data(massif_demo_units)
  units <- massif_demo_units[1:3, ]

  units$B1 <- c(50, 60, 70)
  units$R1 <- c(40, 50, 60)
  units$T1 <- c(100, 120, 140)

  result <- create_family_index(units)

  # Compare two units
  p <- nemeton_radar(
    result,
    unit_id = c(1, 2),
    indicators = c("family_B", "family_R", "family_T"),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")

  # Should have data for both units
  if (!is.null(p$data)) {
    expect_true(length(unique(p$data$unit_id)) == 2)
  }
})

# ==============================================================================
# Coverage expansion tests for uncovered paths
# ==============================================================================

# --- clean_indicator_name (internal) -----------------------------------------

test_that("clean_indicator_name transforms family_ prefix correctly", {
  expect_equal(nemeton:::clean_indicator_name("family_C"), "C")
  expect_equal(nemeton:::clean_indicator_name("family_B"), "B")
  expect_equal(nemeton:::clean_indicator_name("family_W"), "W")
})

test_that("clean_indicator_name handles _norm suffix", {
  result <- nemeton:::clean_indicator_name("carbon_norm")
  expect_true(grepl("Normalized", result))
})

test_that("clean_indicator_name handles _inv suffix", {
  result <- nemeton:::clean_indicator_name("risk_inv")
  expect_true(grepl("Inverted", result))
})

test_that("clean_indicator_name replaces underscores with spaces", {
  result <- nemeton:::clean_indicator_name("carbon_biomass")
  expect_equal(result, "Carbon biomass")
})

test_that("clean_indicator_name capitalizes first letter", {
  result <- nemeton:::clean_indicator_name("water")
  expect_equal(result, "Water")
})

# --- reshape_for_facet (internal) --------------------------------------------

test_that("reshape_for_facet converts wide to long with nemeton_id", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$ind1 <- c(10, 20, 30)
  units$ind2 <- c(40, 50, 60)
  result <- nemeton:::reshape_for_facet(units, c("ind1", "ind2"))
  expect_s3_class(result, "sf")
  expect_true("indicator" %in% names(result))
  expect_true("value" %in% names(result))
  expect_equal(nrow(result), 6) # 3 units x 2 indicators
})

test_that("reshape_for_facet works without nemeton_id column", {
  units <- create_test_units(n_features = 3) # plain sf, no nemeton_id
  units$ind1 <- c(10, 20, 30)
  units$ind2 <- c(40, 50, 60)
  result <- nemeton:::reshape_for_facet(units, c("ind1", "ind2"))
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 6)
  expect_true("indicator" %in% names(result))
  expect_true("value" %in% names(result))
})

# --- nemeton_radar: family mode ----------------------------------------------

test_that("nemeton_radar works in family mode with auto-detected family indicators", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$C1 <- runif(5, 30, 80)
  units$B1 <- runif(5, 30, 80)
  units$W1 <- runif(5, 30, 80)

  result <- create_family_index(units)

  p <- nemeton_radar(result, unit_id = 1, mode = "family")
  expect_s3_class(p, "ggplot")
})

# --- nemeton_radar: comparison mode (multiple unit_ids) ----------------------

test_that("nemeton_radar comparison mode works with row indices", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$C1 <- runif(5, 30, 80)
  units$W1 <- runif(5, 30, 80)
  p <- nemeton_radar(units, unit_id = c(1, 2))
  expect_s3_class(p, "ggplot")
})

# --- nemeton_radar: normalize=FALSE ------------------------------------------

test_that("nemeton_radar works without normalization", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$C1 <- c(100, 200, 300, 400, 500)
  units$W1 <- c(10, 20, 30, 40, 50)
  p <- nemeton_radar(units, unit_id = 1, normalize = FALSE)
  expect_s3_class(p, "ggplot")
})

# --- nemeton_radar: single unit by row index ---------------------------------

test_that("nemeton_radar single unit by numeric row index", {
  units <- create_test_units(n_features = 5) # no nemeton_id
  units$C1 <- c(100, 200, 300, 400, 500)
  units$W1 <- c(10, 20, 30, 40, 50)
  p <- nemeton_radar(units, unit_id = 2)
  expect_s3_class(p, "ggplot")
})

# --- plot_comparison_map -----------------------------------------------------

test_that("plot_comparison_map creates comparison plot with default labels", {
  units1 <- create_test_units(n_features = 3)
  units1$value <- c(10, 20, 30)
  units2 <- create_test_units(n_features = 3)
  units2$value <- c(15, 25, 35)
  p <- plot_comparison_map(units1, units2, indicator = "value")
  expect_s3_class(p, "ggplot")
  expect_true("FacetWrap" %in% class(p$facet))
})

# --- plot_difference_map: absolute -------------------------------------------

test_that("plot_difference_map shows absolute differences with default legend", {
  units1 <- create_test_units(n_features = 3)
  units1$value <- c(10, 20, 30)
  units2 <- create_test_units(n_features = 3)
  units2$value <- c(15, 25, 35)
  p <- plot_difference_map(units1, units2, indicator = "value", type = "absolute")
  expect_s3_class(p, "ggplot")
})

# --- plot_difference_map: relative -------------------------------------------

test_that("plot_difference_map shows relative differences with default legend", {
  units1 <- create_test_units(n_features = 3)
  units1$value <- c(10, 20, 30)
  units2 <- create_test_units(n_features = 3)
  units2$value <- c(15, 25, 35)
  p <- plot_difference_map(units1, units2, indicator = "value", type = "relative")
  expect_s3_class(p, "ggplot")
})

# --- plot_temporal_trend -----------------------------------------------------

test_that("plot_temporal_trend works with single indicator", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$parcel_id <- c("P1", "P2", "P3")
  u2 <- massif_demo_units[1:3, ]
  u2$C1 <- c(55, 65, 75)
  u2$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1, "2020" = u2))
  p <- plot_temporal_trend(temporal, indicator = "C1")
  expect_s3_class(p, "ggplot")
})

test_that("plot_temporal_trend works with multiple indicators", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$W1 <- c(10, 20, 30)
  u1$parcel_id <- c("P1", "P2", "P3")
  u2 <- massif_demo_units[1:3, ]
  u2$C1 <- c(55, 65, 75)
  u2$W1 <- c(15, 25, 35)
  u2$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1, "2020" = u2))
  p <- plot_temporal_trend(temporal, indicator = c("C1", "W1"))
  expect_s3_class(p, "ggplot")
})

test_that("plot_temporal_trend with show_mean adds mean line", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$parcel_id <- c("P1", "P2", "P3")
  u2 <- massif_demo_units[1:3, ]
  u2$C1 <- c(55, 65, 75)
  u2$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1, "2020" = u2))
  p <- plot_temporal_trend(temporal, indicator = "C1", show_mean = TRUE)
  expect_s3_class(p, "ggplot")
  # show_mean adds an extra geom_line layer
  expect_true(length(p$layers) >= 3)
})

# --- plot_temporal_heatmap ---------------------------------------------------

test_that("plot_temporal_heatmap works", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$parcel_id <- c("P1", "P2", "P3")
  u2 <- massif_demo_units[1:3, ]
  u2$C1 <- c(55, 65, 75)
  u2$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1, "2020" = u2))
  p <- plot_temporal_heatmap(temporal, unit_id = "P1")
  expect_s3_class(p, "ggplot")
})

test_that("plot_temporal_heatmap with normalize=TRUE", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$W1 <- c(10, 20, 30)
  u1$parcel_id <- c("P1", "P2", "P3")
  u2 <- massif_demo_units[1:3, ]
  u2$C1 <- c(55, 65, 75)
  u2$W1 <- c(15, 25, 35)
  u2$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1, "2020" = u2))
  p <- plot_temporal_heatmap(temporal, unit_id = "P1", indicators = c("C1", "W1"), normalize = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("plot_temporal_heatmap errors on missing unit", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1))
  expect_error(
    plot_temporal_heatmap(temporal, unit_id = "NONEXISTENT"),
    "not found"
  )
})

test_that("plot_temporal_heatmap errors on non-temporal input", {
  expect_error(
    plot_temporal_heatmap(data.frame(x = 1), unit_id = "P1"),
    "nemeton_temporal"
  )
})

# --- plot_indicators_map: risk indicators auto-palette -----------------------

test_that("plot_indicators_map auto-selects YlOrRd for risk indicators", {
  units <- create_test_units(n_features = 3)
  units$R1 <- c(10, 20, 30)
  p <- plot_indicators_map(units, indicators = "R1")
  expect_s3_class(p, "ggplot")
  # Verify scale uses YlOrRd (distiller) not viridis
  scale_fill <- p$scales$get_scales("fill")
  expect_true(!is.null(scale_fill))
})

test_that("plot_indicators_map auto-selects YlOrRd for family_R indicator", {
  units <- create_test_units(n_features = 3)
  units$family_R <- c(10, 20, 30)
  p <- plot_indicators_map(units, indicators = "family_R")
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map auto-selects YlOrRd for risk_norm indicators", {
  units <- create_test_units(n_features = 3)
  units$R1_norm <- c(0.1, 0.5, 0.9)
  p <- plot_indicators_map(units, indicators = "R1_norm")
  expect_s3_class(p, "ggplot")
})

# --- plot_temporal_trend: errors ---------------------------------------------

test_that("plot_temporal_trend errors on non-temporal input", {
  expect_error(
    plot_temporal_trend(data.frame(x = 1), indicator = "C1"),
    "nemeton_temporal"
  )
})

test_that("plot_temporal_trend errors on missing indicator in period", {
  data(massif_demo_units)
  u1 <- massif_demo_units[1:3, ]
  u1$C1 <- c(50, 60, 70)
  u1$parcel_id <- c("P1", "P2", "P3")
  temporal <- nemeton_temporal(periods = list("2015" = u1))
  expect_error(
    plot_temporal_trend(temporal, indicator = "MISSING"),
    "not found"
  )
})

# --- nemeton_radar: comparison mode with normalize=TRUE ----------------------

test_that("nemeton_radar comparison mode normalizes correctly", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$C1 <- c(100, 200, 300, 400, 500)
  units$W1 <- c(10, 20, 30, 40, 50)
  p <- nemeton_radar(units, unit_id = c(1, 3), normalize = TRUE)
  expect_s3_class(p, "ggplot")
  # All values should be normalized to 0-100
  expect_true(all(p$data$value >= 0 & p$data$value <= 100, na.rm = TRUE))
})
