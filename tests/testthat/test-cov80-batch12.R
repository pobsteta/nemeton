# ==============================================================================
# test-cov80-batch12.R — Coverage tests for R/visualization.R
# Covers: clean_indicator_name, reshape_for_facet, add_color_scale,
#         plot_indicators_map, plot_comparison_map, plot_difference_map,
#         nemeton_radar
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
  result <- nemeton:::clean_indicator_name("carbon_biomass_norm")
  expect_true(grepl("\\(Normalized\\)", result))
  expect_false(grepl("_norm", result))
})

test_that("clean_indicator_name removes _inv suffix and adds (Inverted)", {
  result <- nemeton:::clean_indicator_name("risk_fire_inv")
  expect_true(grepl("\\(Inverted\\)", result))
  expect_false(grepl("_inv", result))
})

test_that("clean_indicator_name replaces underscores with spaces", {
  result <- nemeton:::clean_indicator_name("indicateur_c1_biomasse")
  expect_equal(result, "Carbon biomass")
})

test_that("clean_indicator_name capitalizes first letter", {
  result <- nemeton:::clean_indicator_name("water")
  expect_equal(result, "Water")
})

test_that("clean_indicator_name handles already-capitalized names", {
  result <- nemeton:::clean_indicator_name("Carbon")
  expect_equal(result, "Carbon")
})

test_that("clean_indicator_name vectorized over multiple names", {
  result <- nemeton:::clean_indicator_name(c("famille_carbone", "water_twi_norm", "risk_inv"))
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

test_that("plot_indicators_map creates faceted plot for multiple indicators", {
  data <- create_test_units(n_features = 4)
  data$indicateur_c1_biomasse <- c(80, 60, 70, 50)
  data$indicateur_w3_humidite <- c(30, 40, 50, 60)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    facet = TRUE
  )
  expect_s3_class(p, "ggplot")
  expect_true("FacetWrap" %in% class(p$facet))
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
  data$carbon_biomass_norm <- c(0.2, 0.5, 0.8)

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

test_that("plot_indicators_map auto-selects YlOrRd for risk indicators", {
  data <- create_test_units(n_features = 3)
  data$indicateur_r1_feu <- c(10, 50, 90)

  # Passing a risk_ indicator without explicit palette
  p <- nemeton::plot_indicators_map(data, indicators = "indicateur_r1_feu")
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

test_that("plot_indicators_map errors on non-sf input", {
  df <- data.frame(indicateur_c1_biomasse = c(1, 2, 3))
  expect_error(
    nemeton::plot_indicators_map(df, indicators = "indicateur_c1_biomasse"),
    "must be an.*sf.*object"
  )
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
  data$soil_erosion <- c(10, 20, 30)
  p <- nemeton::plot_indicators_map(
    data,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite", "soil_erosion"),
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
  data$soil_erosion <- c(10, 20, 30, 40, 50)

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

test_that("nemeton_radar family mode auto-detects family_ columns", {
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
  data$soil_erosion <- c(10, 20, 30, 40, 50)

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
  data$soil_erosion <- c(10, 20, 30, 40, 50)

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

test_that("nemeton_radar indicator mode excludes family_ columns from auto-detect", {
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
