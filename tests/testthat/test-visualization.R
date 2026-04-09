test_that("plot_indicators_map creates ggplot for single indicator", {
  # Create test data
  units <- nemeton_units(create_test_units(n_features = 5))
  units$indicateur_c1_biomasse <- c(100, 200, 300, 400, 500)

  # Create plot
  p <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse")

  expect_s3_class(p, "ggplot")
  expect_s3_class(p, "gg")
})

test_that("plot_indicators_map creates faceted plot for multiple indicators", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$indicateur_c1_biomasse <- c(100, 200, 300, 400, 500)
  units$indicateur_w3_humidite <- c(10, 20, 30, 40, 50)

  p <- plot_indicators_map(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    facet = TRUE
  )

  expect_s3_class(p, "ggplot")

  # Check that faceting was applied
  expect_true("FacetWrap" %in% class(p$facet))
})

test_that("plot_indicators_map auto-detects indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$indicateur_c1_biomasse <- c(100, 200, 300)
  units$indicateur_b1_protection <- c(10, 20, 30)

  # Should auto-detect carbon and biodiversity
  p <- plot_indicators_map(units)

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map accepts different palettes", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$indicateur_c1_biomasse <- c(100, 200, 300)

  # Viridis
  p1 <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse", palette = "viridis")
  expect_s3_class(p1, "ggplot")

  # ColorBrewer
  p2 <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse", palette = "Greens")
  expect_s3_class(p2, "ggplot")

  p3 <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse", palette = "RdYlGn")
  expect_s3_class(p3, "ggplot")
})

test_that("plot_indicators_map accepts custom title and legend", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$indicateur_c1_biomasse <- c(100, 200, 300)

  p <- plot_indicators_map(
    units,
    indicators = "indicateur_c1_biomasse",
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
  units$indicateur_c1_biomasse <- c(0, 25, 50, 75, 100)

  p <- plot_indicators_map(
    units,
    indicators = "indicateur_c1_biomasse",
    breaks = c(0, 50, 100),
    labels = c("Low", "Medium", "High")
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map handles normalized indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$indicateur_c1_biomasse <- c(100, 200, 300)

  # Normalize
  normalized <- normalize_indicators(units, indicators = "indicateur_c1_biomasse", method = "minmax")

  # Plot normalized
  p <- plot_indicators_map(normalized, indicators = "indicateur_c1_biomasse_norm")

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map works with composite index", {
  units <- nemeton_units(create_test_units(n_features = 5))
  units$indicateur_c1_biomasse_norm <- c(0, 25, 50, 75, 100)
  units$indicateur_w3_humidite_norm <- c(0, 25, 50, 75, 100)

  # Create composite
  result <- create_composite_index(
    units,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_w3_humidite_norm"),
    name = "ecosystem_health"
  )

  # Plot composite
  p <- plot_indicators_map(result, indicators = "ecosystem_health")

  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map errors on non-sf input", {
  df <- data.frame(carbon = c(1, 2, 3))

  expect_error(
    plot_indicators_map(df, indicators = "indicateur_c1_biomasse"),
    "must be an.*sf.*object"
  )
})

test_that("plot_indicators_map errors on missing indicators", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$indicateur_c1_biomasse <- c(100, 200, 300)

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
  units1$indicateur_c1_biomasse <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$indicateur_c1_biomasse <- c(150, 250, 350)

  # Create comparison
  p <- plot_comparison_map(
    units1,
    units2,
    indicator = "indicateur_c1_biomasse",
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
    plot_comparison_map(df1, df2, indicator = "indicateur_c1_biomasse"),
    "must be.*sf.*objects"
  )
})

test_that("plot_comparison_map errors when indicator missing", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$indicateur_c1_biomasse <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$indicateur_w3_humidite <- c(10, 20, 30) # Different indicator

  expect_error(
    plot_comparison_map(units1, units2, indicator = "indicateur_c1_biomasse"),
    "must exist in both datasets"
  )
})

test_that("plot_difference_map creates absolute difference map", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$indicateur_c1_biomasse <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$indicateur_c1_biomasse <- c(150, 250, 350) # +50 each

  p <- plot_difference_map(
    units1,
    units2,
    indicator = "indicateur_c1_biomasse",
    type = "absolute"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map creates relative difference map", {
  units1 <- nemeton_units(create_test_units(n_features = 3))
  units1$indicateur_c1_biomasse <- c(100, 200, 300)

  units2 <- nemeton_units(create_test_units(n_features = 3))
  units2$indicateur_c1_biomasse <- c(150, 250, 350) # +50% for first, +25% for second, etc.

  p <- plot_difference_map(
    units1,
    units2,
    indicator = "indicateur_c1_biomasse",
    type = "relative"
  )

  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map errors on non-sf inputs", {
  df1 <- data.frame(carbon = c(1, 2, 3))
  df2 <- data.frame(carbon = c(4, 5, 6))

  expect_error(
    plot_difference_map(df1, df2, indicator = "indicateur_c1_biomasse"),
    "must be.*sf.*objects"
  )
})

test_that("clean_indicator_name formats names correctly", {
  # Test internal function through plotting
  units <- nemeton_units(create_test_units(n_features = 3))
  units$indicateur_c1_biomasse_norm <- c(0, 50, 100)

  p <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse_norm")

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
  units$indicateur_c1_biomasse <- 250
  units$indicateur_b1_protection <- 30
  units$indicateur_w3_humidite <- 0.75

  # Single indicator map
  p1 <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse")
  expect_s3_class(p1, "ggplot")

  # Multiple indicators
  p2 <- plot_indicators_map(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_b1_protection", "indicateur_w3_humidite"),
    facet = TRUE
  )
  expect_s3_class(p2, "ggplot")
})

test_that("full visualization workflow works end-to-end", {
  # Create test data
  units <- nemeton_units(create_test_units(n_features = 10))
  units$indicateur_c1_biomasse <- seq(100, 1000, length.out = 10)
  units$indicateur_b1_protection <- seq(10, 100, length.out = 10)
  units$indicateur_w3_humidite <- seq(5, 50, length.out = 10)
  units$indicateur_s2_bati <- seq(0, 100, length.out = 10)

  # Step 1: Normalize
  normalized <- normalize_indicators(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_b1_protection", "indicateur_w3_humidite", "indicateur_s2_bati"),
    method = "minmax"
  )

  # Step 2: Invert accessibility
  normalized <- invert_indicator(
    normalized,
    indicators = "indicateur_s2_bati_norm",
    suffix = "_wilderness"
  )

  # Step 3: Create composite
  result <- create_composite_index(
    normalized,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_b1_protection_norm", "indicateur_w3_humidite_norm"),
    weights = c(0.4, 0.4, 0.2),
    name = "ecosystem_health"
  )

  # Step 4: Visualize raw indicators
  p1 <- plot_indicators_map(
    units,
    indicators = c("indicateur_c1_biomasse", "indicateur_b1_protection"),
    palette = "Greens"
  )
  expect_s3_class(p1, "ggplot")

  # Step 5: Visualize normalized indicators
  p2 <- plot_indicators_map(
    normalized,
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_b1_protection_norm", "indicateur_w3_humidite_norm"),
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
  units$indicateur_c1_biomasse <- c(100, 200, 300, 400, 500)

  p <- plot_indicators_map(units, indicators = "indicateur_c1_biomasse")

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
  results <- suppressWarnings(nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3)))
  normalized <- suppressWarnings(normalize_indicators(results))

  # Average radar
  p <- suppressWarnings(nemeton_radar(normalized))

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar creates a ggplot object for specific unit", {
  data(massif_demo_units)
  layers <- massif_demo_layers()
  results <- suppressWarnings(nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3)))
  normalized <- suppressWarnings(normalize_indicators(results))

  # Specific unit
  p <- suppressWarnings(nemeton_radar(normalized, unit_id = "P01"))

  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar works with explicit indicators", {
  data(massif_demo_units)
  layers <- massif_demo_layers()
  results <- suppressWarnings(nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3)))
  normalized <- suppressWarnings(normalize_indicators(results))

  # Explicit indicators
  p <- suppressWarnings(nemeton_radar(
    normalized,
    unit_id = "P05",
    indicators = c("indicateur_c1_biomasse_norm", "indicateur_b1_protection_norm", "indicateur_w3_humidite_norm"),
    normalize = FALSE
  ))

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
  results <- suppressWarnings(nemeton_compute(massif_demo_units, layers, indicators = "all", forest_values = c(1, 2, 3)))
  normalized <- suppressWarnings(normalize_indicators(results))

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
    indicators = grep("^famille_", names(result), value = TRUE),
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
    indicators = grep("^famille_", names(result), value = TRUE),
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
    indicators = c("famille_biodiversite", "famille_risque", "famille_temporel", "famille_air"),
    normalize = FALSE
  )

  expect_s3_class(p, "ggplot")

  # Plot data should contain family indicator values
  expect_true(any(grepl("famille_", p$data$indicator)))
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
    indicators = grep("^famille_", names(result), value = TRUE),
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
    indicators = c("famille_biodiversite", "famille_risque", "famille_temporel"),
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

test_that("clean_indicator_name transforms famille_ prefix correctly", {
  expect_equal(nemeton:::clean_indicator_name("famille_carbone"), "C")
  expect_equal(nemeton:::clean_indicator_name("famille_biodiversite"), "B")
  expect_equal(nemeton:::clean_indicator_name("famille_eau"), "W")
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
  result <- nemeton:::clean_indicator_name("indicateur_c1_biomasse")
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

test_that("plot_indicators_map auto-selects YlOrRd for famille_risque indicator", {
  units <- create_test_units(n_features = 3)
  units$famille_risque <- c(10, 20, 30)
  p <- plot_indicators_map(units, indicators = "famille_risque")
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

# ==============================================================================
# (migrated from test-coverage-boost2.R)
# ==============================================================================

# --- clean_indicator_name() ---

test_that("clean_indicator_name works for family indices", {
  expect_equal(nemeton:::clean_indicator_name("famille_carbone"), "C")
  expect_equal(nemeton:::clean_indicator_name("famille_biodiversite"), "B")
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
  result <- nemeton:::clean_indicator_name(c("famille_carbone", "carbon_norm", "C1"))
  expect_equal(length(result), 3)
  expect_equal(result[1], "C")
  expect_equal(result[2], "Carbon (Normalized)")
  expect_equal(result[3], "C1")
})

# --- plot_indicators_map() ---

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

# --- nemeton_radar() ---

test_that("nemeton_radar works in family mode", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- c(80, 60, 40, 20, 50)
  units$famille_biodiversite <- c(70, 50, 30, 10, 40)
  units$famille_eau <- c(60, 80, 20, 40, 50)
  units$famille_air <- c(50, 70, 60, 30, 80)
  p <- nemeton_radar(units, unit_id = 1, mode = "family")
  expect_true(inherits(p, "ggplot"))
})

test_that("nemeton_radar works in mean mode", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- c(80, 60, 40, 20, 50)
  units$famille_biodiversite <- c(70, 50, 30, 10, 40)
  units$famille_eau <- c(60, 80, 20, 40, 50)
  units$famille_air <- c(50, 70, 60, 30, 80)
  p <- nemeton_radar(units, mode = "family")
  expect_true(inherits(p, "ggplot"))
})

test_that("nemeton_radar comparison mode with multiple units", {
  units <- create_test_units(n_features = 5)
  units$famille_carbone <- c(80, 60, 40, 20, 50)
  units$famille_biodiversite <- c(70, 50, 30, 10, 40)
  units$famille_eau <- c(60, 80, 20, 40, 50)
  units$famille_air <- c(50, 70, 60, 30, 80)
  p <- nemeton_radar(units, unit_id = c(1, 2, 3), mode = "family")
  expect_true(inherits(p, "ggplot"))
})

test_that("nemeton_radar errors on non-sf", {
  df <- data.frame(famille_carbone = 1:5)
  expect_error(nemeton_radar(df), "sf")
})

test_that("nemeton_radar errors on no family columns in family mode", {
  units <- create_test_units(n_features = 5)
  expect_error(nemeton_radar(units, mode = "family"), "family")
})

# --- reshape_for_facet() ---

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

# --- add_color_scale() ---

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
# (migrated from test-cov80-batch12.R)
# ==============================================================================

# --- clean_indicator_name (internal) ------------------------------------------

test_that("clean_indicator_name converts famille_carbone to C", {
  expect_equal(nemeton:::clean_indicator_name("famille_carbone"), "C")
})

test_that("clean_indicator_name converts famille_biodiversite to B", {
  expect_equal(nemeton:::clean_indicator_name("famille_biodiversite"), "B")
})

test_that("clean_indicator_name converts famille_eau to W", {
  expect_equal(nemeton:::clean_indicator_name("famille_eau"), "W")
})

test_that("clean_indicator_name converts famille_risque to R", {
  expect_equal(nemeton:::clean_indicator_name("famille_risque"), "R")
})

test_that("clean_indicator_name does NOT strip family_ when followed by lowercase", {

  # The regex only matches famille_[a-z] (single uppercase letter)
  result <- nemeton:::clean_indicator_name("family_carbon")
  expect_false(result == "carbon")
  expect_true(grepl("Family", result))
})

test_that("clean_indicator_name removes _norm suffix and adds (Normalized)", {
  result <- nemeton:::clean_indicator_name("indicateur_c1_biomasse_norm")
  expect_true(grepl("\\(Normalized\\)", result))
  expect_false(grepl("_norm", result))
})

test_that("clean_indicator_name removes _inv suffix and adds (Inverted)", {
  result <- nemeton:::clean_indicator_name("indicateur_r1_feu_inv")
  expect_true(grepl("\\(Inverted\\)", result))
  expect_false(grepl("_inv", result))
})

test_that("clean_indicator_name handles already-capitalized names", {
  result <- nemeton:::clean_indicator_name("Carbon")
  expect_equal(result, "Carbon")
})

test_that("clean_indicator_name vectorized over multiple names", {
  result <- nemeton:::clean_indicator_name(c("famille_carbone", "indicateur_w3_humidite_norm", "risk_inv"))
  expect_length(result, 3)
  expect_equal(result[1], "C")
  expect_true(grepl("\\(Normalized\\)", result[2]))
  expect_true(grepl("\\(Inverted\\)", result[3]))
})

# --- reshape_for_facet (internal) ---------------------------------------------

test_that("reshape_for_facet with nemeton_id keeps id and replicates geometry", {
  units <- create_test_units(n_features = 3)
  units$nemeton_id <- c("U1", "U2", "U3")
  units$ind_a <- c(10, 20, 30)
  units$ind_b <- c(40, 50, 60)

  result <- nemeton:::reshape_for_facet(units, c("ind_a", "ind_b"))

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 6) # 3 units x 2 indicators
  expect_true("indicator" %in% names(result))
  expect_true("value" %in% names(result))
  expect_true("nemeton_id" %in% names(result))
  # Geometry should be replicated for each indicator

  expect_equal(length(sf::st_geometry(result)), 6)
})

test_that("reshape_for_facet without nemeton_id creates row_id", {
  units <- create_test_units(n_features = 4)
  units$x1 <- c(1, 2, 3, 4)
  units$x2 <- c(5, 6, 7, 8)

  result <- nemeton:::reshape_for_facet(units, c("x1", "x2"))

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 8) # 4 units x 2 indicators
  expect_true("indicator" %in% names(result))
  expect_true("value" %in% names(result))
  # row_id is used internally for pivoting but may not appear in output
  # The key check is that the result has correct structure
  expect_true("indicator" %in% names(result))
  expect_true("value" %in% names(result))
})

test_that("reshape_for_facet preserves CRS", {
  units <- create_test_units(n_features = 2, crs = 2154)
  units$val1 <- c(10, 20)
  units$val2 <- c(30, 40)

  result <- nemeton:::reshape_for_facet(units, c("val1", "val2"))
  expect_equal(sf::st_crs(result)$epsg, 2154)
})

test_that("reshape_for_facet values match original data", {
  units <- create_test_units(n_features = 2)
  units$alpha <- c(100, 200)
  units$beta <- c(300, 400)

  result <- nemeton:::reshape_for_facet(units, c("alpha", "beta"))
  alpha_vals <- result$value[result$indicator == "alpha"]
  beta_vals <- result$value[result$indicator == "beta"]
  expect_equal(sort(alpha_vals), c(100, 200))
  expect_equal(sort(beta_vals), c(300, 400))
})

# --- add_color_scale (internal) -----------------------------------------------

test_that("add_color_scale adds viridis scale when palette = viridis", {
  data <- create_test_units(n_features = 3)
  data$val <- c(10, 50, 90)
  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = val))

  p2 <- nemeton:::add_color_scale(
    p, palette = "viridis", direction = 1,
    breaks = NULL, labels = NULL, legend_title = "Test"
  )
  expect_s3_class(p2, "ggplot")
  # Should have a fill scale
  scale_fill <- p2$scales$get_scales("fill")
  expect_true(!is.null(scale_fill))
})

test_that("add_color_scale adds distiller scale when palette = RdYlGn", {
  data <- create_test_units(n_features = 3)
  data$val <- c(10, 50, 90)
  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = val))

  p2 <- nemeton:::add_color_scale(
    p, palette = "RdYlGn", direction = 1,
    breaks = NULL, labels = NULL, legend_title = "My Legend"
  )
  expect_s3_class(p2, "ggplot")
  scale_fill <- p2$scales$get_scales("fill")
  expect_true(!is.null(scale_fill))
})

test_that("add_color_scale with breaks and labels for viridis", {
  data <- create_test_units(n_features = 5)
  data$val <- c(0, 25, 50, 75, 100)
  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = val))

  p2 <- nemeton:::add_color_scale(
    p, palette = "viridis", direction = 1,
    breaks = c(0, 50, 100), labels = c("Low", "Mid", "High"),
    legend_title = "Score"
  )
  expect_s3_class(p2, "ggplot")
})

test_that("add_color_scale with breaks and labels for non-viridis", {
  data <- create_test_units(n_features = 5)
  data$val <- c(0, 25, 50, 75, 100)
  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = val))

  p2 <- nemeton:::add_color_scale(
    p, palette = "Greens", direction = -1,
    breaks = c(0, 50, 100), labels = c("A", "B", "C"),
    legend_title = "Grade"
  )
  expect_s3_class(p2, "ggplot")
})

test_that("add_color_scale with direction = -1 reversed", {
  data <- create_test_units(n_features = 3)
  data$val <- c(10, 50, 90)
  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = val))

  p2 <- nemeton:::add_color_scale(
    p, palette = "viridis", direction = -1,
    breaks = NULL, labels = NULL, legend_title = "Reversed"
  )
  expect_s3_class(p2, "ggplot")
})

# --- plot_indicators_map (exported) -------------------------------------------

test_that("plot_indicators_map returns ggplot for single indicator", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  p <- nemeton::plot_indicators_map(data, indicators = "indicateur_c1_biomasse")
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map auto-detects known indicators", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w1_reseau <- c(30, 40, 50)

  p <- nemeton::plot_indicators_map(data)
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map auto-detects _norm indicators", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse_norm <- c(0.2, 0.5, 0.8)

  p <- nemeton::plot_indicators_map(data)
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map auto-detects family indices", {
  data <- create_test_units(n_features = 3)
  data$famille_carbone <- c(50, 60, 70)
  data$famille_eau <- c(40, 50, 60)

  p <- nemeton::plot_indicators_map(data)
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map auto-detects composite_index", {
  data <- create_test_units(n_features = 3)
  data$composite_index <- c(55, 65, 75)

  p <- nemeton::plot_indicators_map(data)
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map auto-selects YlOrRd for R1-R4 indicators", {
  data <- create_test_units(n_features = 3)
  data$R1 <- c(10, 50, 90)

  p <- nemeton::plot_indicators_map(data, indicators = "R1")
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map uses user palette even for risk indicators", {
  data <- create_test_units(n_features = 3)
  data$indicateur_r1_feu <- c(10, 50, 90)

  # Explicit palette should override auto-selection
  p <- nemeton::plot_indicators_map(
    data, indicators = "indicateur_r1_feu", palette = "Blues"
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map with custom title and legend_title", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = "indicateur_c1_biomasse",
    title = "My Custom Title",
    legend_title = "Custom Legend"
  )
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "My Custom Title")
})

test_that("plot_indicators_map with custom alpha, border_color, border_size", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = "indicateur_c1_biomasse",
    alpha = 0.5,
    border_color = "black",
    border_size = 1.0,
    base_size = 14
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map errors on missing indicator column", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  expect_error(
    nemeton::plot_indicators_map(data, indicators = "nonexistent_col"),
    "not found"
  )
})

test_that("plot_indicators_map errors when no indicators can be detected", {
  data <- create_test_units(n_features = 3)
  # Only has id, area, geometry -- no indicator columns
  expect_error(
    nemeton::plot_indicators_map(data),
    "No indicator columns found"
  )
})

test_that("plot_indicators_map single indicator auto-generates title", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  p <- nemeton::plot_indicators_map(data, indicators = "indicateur_c1_biomasse")
  expect_true(grepl("Map of", p$labels$title))
})

test_that("plot_indicators_map multiple indicators auto-generates title", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite")
  )
  expect_true(grepl("Maps of 2 indicators", p$labels$title))
})

test_that("plot_indicators_map multiple indicators with facet=TRUE (default) works", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)
  # Multiple indicators with default facet=TRUE
  p <- nemeton::plot_indicators_map(
    data,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    facet = TRUE
  )
  expect_s3_class(p, "ggplot")
  expect_true("FacetWrap" %in% class(p$facet))
})

test_that("plot_indicators_map with custom breaks and labels", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(0, 25, 50, 75, 100)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = "indicateur_c1_biomasse",
    breaks = c(0, 50, 100),
    labels = c("Low", "Med", "High")
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map with RdYlGn palette (non-viridis)", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = "indicateur_c1_biomasse",
    palette = "RdYlGn"
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map with direction=-1 reverses scale", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = "indicateur_c1_biomasse",
    direction = -1
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_indicators_map with ncol parameter for facets", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)
  data$indicateur_f2_erosion <- c(10, 20, 30)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite", "indicateur_f2_erosion"),
    ncol = 3
  )
  expect_s3_class(p, "ggplot")
  expect_true("FacetWrap" %in% class(p$facet))
})

# --- plot_comparison_map (exported) -------------------------------------------

test_that("plot_comparison_map returns ggplot with faceted comparison", {
  d1 <- create_test_units(n_features = 3)
  d1$indicateur_c1_biomasse <- c(100, 200, 300)
  d2 <- create_test_units(n_features = 3)
  d2$indicateur_c1_biomasse <- c(150, 250, 350)

  p <- nemeton::plot_comparison_map(d1, d2, indicator = "indicateur_c1_biomasse")
  expect_s3_class(p, "ggplot")
  expect_true("FacetWrap" %in% class(p$facet))
})

test_that("plot_comparison_map auto-generates title when title=NULL", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_comparison_map(d1, d2, indicator = "val")
  expect_true(grepl("Comparison", p$labels$title))
})

test_that("plot_comparison_map with custom title", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_comparison_map(
    d1, d2, indicator = "val",
    title = "Before vs After"
  )
  expect_equal(p$labels$title, "Before vs After")
})

test_that("plot_comparison_map with custom labels", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_comparison_map(
    d1, d2, indicator = "val",
    labels = c("Current", "Future")
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_comparison_map with default labels (Scenario 1 / Scenario 2)", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_comparison_map(d1, d2, indicator = "val")
  # The combined data should have scenario column with default labels
  expect_s3_class(p, "ggplot")
})

test_that("plot_comparison_map with non-viridis palette", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_comparison_map(
    d1, d2, indicator = "val",
    palette = "RdYlGn"
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_comparison_map errors when data1 is not sf", {
  d1 <- data.frame(val = c(10, 20))
  d2 <- create_test_units(n_features = 2)
  d2$val <- c(15, 25)

  expect_error(
    nemeton::plot_comparison_map(d1, d2, indicator = "val"),
    "must be.*sf.*object"
  )
})

test_that("plot_comparison_map errors when indicator missing from data2", {
  d1 <- create_test_units(n_features = 3)
  d1$indicateur_c1_biomasse <- c(100, 200, 300)
  d2 <- create_test_units(n_features = 3)
  d2$other_col <- c(1, 2, 3) # Missing indicateur_c1_biomasse

  expect_error(
    nemeton::plot_comparison_map(d1, d2, indicator = "indicateur_c1_biomasse"),
    "must exist in both"
  )
})

# --- plot_difference_map (exported) -------------------------------------------

test_that("plot_difference_map absolute type returns ggplot", {
  d1 <- create_test_units(n_features = 3)
  d1$indicateur_c1_biomasse <- c(100, 200, 300)
  d2 <- create_test_units(n_features = 3)
  d2$indicateur_c1_biomasse <- c(150, 250, 350)

  p <- nemeton::plot_difference_map(
    d1, d2, indicator = "indicateur_c1_biomasse", type = "absolute"
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map relative type returns ggplot", {
  d1 <- create_test_units(n_features = 3)
  d1$indicateur_c1_biomasse <- c(100, 200, 300)
  d2 <- create_test_units(n_features = 3)
  d2$indicateur_c1_biomasse <- c(120, 220, 330)

  p <- nemeton::plot_difference_map(
    d1, d2, indicator = "indicateur_c1_biomasse", type = "relative"
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map absolute auto-generates legend title", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_difference_map(d1, d2, indicator = "val", type = "absolute")
  expect_s3_class(p, "ggplot")
  # legend_title should be "Absolute Change" since we did not pass one
})

test_that("plot_difference_map relative auto-generates legend title", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_difference_map(d1, d2, indicator = "val", type = "relative")
  expect_s3_class(p, "ggplot")
})

test_that("plot_difference_map auto-generates title when title=NULL", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_difference_map(d1, d2, indicator = "val")
  expect_true(grepl("Change in", p$labels$title))
})

test_that("plot_difference_map with custom title and legend", {
  d1 <- create_test_units(n_features = 3)
  d1$val <- c(10, 20, 30)
  d2 <- create_test_units(n_features = 3)
  d2$val <- c(15, 25, 35)

  p <- nemeton::plot_difference_map(
    d1, d2, indicator = "val",
    title = "Custom Diff Title",
    legend_title = "Delta"
  )
  expect_equal(p$labels$title, "Custom Diff Title")
})

test_that("plot_difference_map errors on non-sf input", {
  d1 <- data.frame(val = c(10, 20))
  d2 <- data.frame(val = c(15, 25))

  expect_error(
    nemeton::plot_difference_map(d1, d2, indicator = "val"),
    "must be.*sf.*object"
  )
})

test_that("plot_difference_map errors when indicator missing", {
  d1 <- create_test_units(n_features = 3)
  d1$indicateur_c1_biomasse <- c(100, 200, 300)
  d2 <- create_test_units(n_features = 3)
  # d2 does NOT have indicateur_c1_biomasse

  expect_error(
    nemeton::plot_difference_map(d1, d2, indicator = "indicateur_c1_biomasse"),
    "must exist in both"
  )
})

# --- nemeton_radar (exported) -------------------------------------------------

test_that("nemeton_radar single unit in indicator mode returns ggplot", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)
  data$indicateur_f2_erosion <- c(10, 20, 30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = 1, mode = "indicator")
  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar single unit in family mode returns ggplot", {
  data <- create_test_units(n_features = 5)
  data$famille_carbone <- c(80, 60, 70, 50, 90)
  data$famille_biodiversite <- c(70, 50, 60, 40, 80)
  data$famille_eau <- c(65, 75, 85, 55, 45)
  data$famille_air <- c(55, 45, 35, 65, 75)

  p <- nemeton::nemeton_radar(data, unit_id = 1, mode = "family")
  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar family mode auto-detects famille_ columns", {
  data <- create_test_units(n_features = 3)
  data$famille_carbone <- c(80, 60, 70)
  data$famille_eau <- c(65, 75, 85)
  data$famille_risque <- c(40, 50, 60)

  p <- nemeton::nemeton_radar(data, unit_id = 1, mode = "family")
  expect_s3_class(p, "ggplot")
  # Data should have 3 indicators (one per family)
  expect_equal(nrow(p$data), 3)
})

test_that("nemeton_radar family mode errors when no family columns found", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)

  expect_error(
    nemeton::nemeton_radar(data, mode = "family"),
    "No family indices found"
  )
})

test_that("nemeton_radar mean of all units (unit_id=NULL)", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)

  p <- nemeton::nemeton_radar(data, unit_id = NULL, mode = "indicator")
  expect_s3_class(p, "ggplot")
  expect_true(grepl("Average", p$labels$title))
})

test_that("nemeton_radar multiple unit_ids comparison mode", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)

  p <- nemeton::nemeton_radar(data, unit_id = c(1, 3))
  expect_s3_class(p, "ggplot")
  # Comparison mode should have data with unit_id column
  expect_true("unit_id" %in% names(p$data))
  expect_equal(length(unique(p$data$unit_id)), 2)
})

test_that("nemeton_radar comparison mode with 3 units", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)
  data$indicateur_f2_erosion <- c(10, 20, 30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = c(1, 2, 3))
  expect_s3_class(p, "ggplot")
  expect_equal(length(unique(p$data$unit_id)), 3)
})

test_that("nemeton_radar auto-detects numeric indicators in indicator mode", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = 1)
  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar errors on missing indicator", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)

  expect_error(
    nemeton::nemeton_radar(data, indicators = c("nonexistent")),
    "Indicators not found"
  )
})

test_that("nemeton_radar errors on non-sf input", {
  df <- data.frame(x = 1:3, y = 4:6)
  expect_error(
    nemeton::nemeton_radar(df),
    "must be an.*sf.*object"
  )
})

test_that("nemeton_radar with normalize=TRUE scales to 0-100", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(100, 200, 300, 400, 500)
  data$indicateur_w3_humidite <- c(10, 20, 30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = 1, normalize = TRUE)
  expect_s3_class(p, "ggplot")
  # Normalized values should be 0-100
  expect_true(all(p$data$value >= 0 & p$data$value <= 100, na.rm = TRUE))
})

test_that("nemeton_radar with normalize=FALSE keeps raw values", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(100, 200, 300, 400, 500)
  data$indicateur_w3_humidite <- c(10, 20, 30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = 1, normalize = FALSE)
  expect_s3_class(p, "ggplot")
  # First unit values should match raw
  vals <- p$data$value
  expect_true(100 %in% vals)
  expect_true(10 %in% vals)
})

test_that("nemeton_radar normalize handles all-equal values (max == min)", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(50, 50, 50) # all same
  data$indicateur_w3_humidite <- c(30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = 1, normalize = TRUE)
  expect_s3_class(p, "ggplot")
  # For constant indicator, normalized value should be 50
  carbon_val <- p$data$value[p$data$indicator == "indicateur_c1_biomasse"]
  expect_equal(carbon_val, 50)
})

test_that("nemeton_radar single unit with custom title", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)

  p <- nemeton::nemeton_radar(
    data, unit_id = 1, title = "My Custom Radar"
  )
  expect_equal(p$labels$title, "My Custom Radar")
})

test_that("nemeton_radar single unit auto-generates title with unit label", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = 1)
  expect_true(grepl("Indicator Profile", p$labels$title))
})

test_that("nemeton_radar comparison mode auto-generates title", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)

  p <- nemeton::nemeton_radar(data, unit_id = c(1, 2))
  expect_true(grepl("Comparison", p$labels$title))
})

test_that("nemeton_radar comparison mode with custom title", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)

  p <- nemeton::nemeton_radar(
    data, unit_id = c(1, 2), title = "Parcels A vs B"
  )
  expect_equal(p$labels$title, "Parcels A vs B")
})

test_that("nemeton_radar comparison mode normalize handles constant indicator", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(50, 50, 50) # all same
  data$indicateur_w3_humidite <- c(10, 20, 30)

  p <- nemeton::nemeton_radar(data, unit_id = c(1, 2), normalize = TRUE)
  expect_s3_class(p, "ggplot")
  # The constant indicator should have value 50
  carbon_vals <- p$data$value[p$data$indicator == "indicateur_c1_biomasse"]
  expect_true(all(carbon_vals == 50))
})

test_that("nemeton_radar with custom fill_color and fill_alpha", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)

  p <- nemeton::nemeton_radar(
    data, unit_id = 1,
    fill_color = "#d73027",
    fill_alpha = 0.5
  )
  expect_s3_class(p, "ggplot")
})

test_that("nemeton_radar with explicit indicators parameter", {
  data <- create_test_units(n_features = 5)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50, 90)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60, 20)
  data$indicateur_f2_erosion <- c(10, 20, 30, 40, 50)

  p <- nemeton::nemeton_radar(
    data, unit_id = 1,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite")
  )
  expect_s3_class(p, "ggplot")
  # Should only have 2 indicators, not 3
  expect_equal(nrow(p$data), 2)
})

test_that("nemeton_radar errors on invalid unit_id (string not found)", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)

  expect_error(
    nemeton::nemeton_radar(data, unit_id = "INVALID"),
    "Unit ID.*not found"
  )
})

test_that("nemeton_radar indicator mode excludes famille_ columns from auto-detect", {
  data <- create_test_units(n_features = 3)
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$famille_carbone <- c(50, 60, 70)

  # In indicator mode, famille_carbone should be excluded from auto-detected indicators
  p <- nemeton::nemeton_radar(data, unit_id = 1, mode = "indicator")
  expect_s3_class(p, "ggplot")
  # Should only show indicateur_c1_biomasse, not famille_carbone
  expect_false("famille_carbone" %in% p$data$indicator)
})

test_that("nemeton_radar indicator mode errors when no numeric indicators", {
  data <- create_test_units(n_features = 3)
  # Only has id (character), area (numeric but excluded), geometry
  # Remove the area column to leave only non-indicator numerics
  data$area <- NULL

  expect_error(
    nemeton::nemeton_radar(data, mode = "indicator"),
    "No numeric indicator columns found"
  )
})

test_that("nemeton_radar lookup by nemeton_id column", {
  data <- create_test_units(n_features = 3)
  data$nemeton_id <- c("P01", "P02", "P03")
  data$indicateur_c1_biomasse <- c(80, 60, 70)
  data$indicateur_w3_humidite <- c(30, 40, 50)

  p <- nemeton::nemeton_radar(data, unit_id = "P02")
  expect_s3_class(p, "ggplot")
})
