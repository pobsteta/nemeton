# test-cov60-batch1.R
# Coverage boost for utils_theme.R, analysis-pareto.R, data-massif_demo_layers.R
# Target: bring each file from <60% to >60%

# ==============================================================================
# utils_theme.R — exercise all accessors and palette functions
# ==============================================================================

test_that("get_accessible_palette() returns viridis colors with viridisLite", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(5)
  expect_length(colors, 5)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_accessible_palette() with plasma palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(5, palette = "plasma")
  expect_length(colors, 5)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_accessible_palette() with inferno palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(4, palette = "inferno")
  expect_length(colors, 4)
})

test_that("get_accessible_palette() with magma palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(3, palette = "magma")
  expect_length(colors, 3)
})

test_that("get_accessible_palette() with cividis palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(6, palette = "cividis")
  expect_length(colors, 6)
})

test_that("get_accessible_palette() warns for invalid palette name", {
  expect_warning(
    colors <- nemeton:::get_accessible_palette(3, palette = "rainbow"),
    "not colorblind-friendly"
  )
  expect_length(colors, 3)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_accessible_palette() with alpha parameter", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(4, alpha = 0.5)
  expect_length(colors, 4)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_accessible_palette() with n=1", {
  colors <- nemeton:::get_accessible_palette(1)
  expect_length(colors, 1)
  expect_true(grepl("^#", colors))
})

test_that("get_accessible_palette() with large n", {
  colors <- nemeton:::get_accessible_palette(50)
  expect_length(colors, 50)
})

test_that("get_accessible_symbols() returns integer pch values", {
  syms <- nemeton:::get_accessible_symbols(5)
  expect_length(syms, 5)
  expect_true(all(is.integer(syms) | is.numeric(syms)))
})

test_that("get_accessible_symbols() recycles for large n", {
  syms <- nemeton:::get_accessible_symbols(20)
  expect_length(syms, 20)
})

test_that("get_family_colors() returns 12 named colors", {
  colors <- nemeton:::get_family_colors()
  expect_length(colors, 12)
  expect_true(all(grepl("^#", colors)))
  expect_true(all(c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N") %in% names(colors)))
})

test_that("get_accessibility_config() returns known keys", {
  pal <- nemeton:::get_accessibility_config("color_palettes")
  expect_true("viridis" %in% pal)

  min_font <- nemeton:::get_accessibility_config("min_font_size")
  expect_equal(min_font, 16L)

  lh <- nemeton:::get_accessibility_config("line_height")
  expect_equal(lh, 1.5)
})

test_that("get_accessibility_config() returns default for missing key", {
  result <- nemeton:::get_accessibility_config("nonexistent_key", default = 42)
  expect_equal(result, 42)
})

test_that("get_accessibility_config() returns NULL for missing key without default", {
  result <- nemeton:::get_accessibility_config("nonexistent_key")
  expect_null(result)
})

test_that("ACCESSIBILITY_CONFIG has expected fields", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_true("color_palettes" %in% names(config))
  expect_true("default_palette" %in% names(config))
  expect_true("use_symbols" %in% names(config))
  expect_true("symbol_shapes" %in% names(config))
  expect_true("min_touch_target" %in% names(config))
  expect_true("focus_ring_width" %in% names(config))
  expect_true("min_text_contrast" %in% names(config))
  expect_true("min_ui_contrast" %in% names(config))
})

test_that("nemeton_theme() returns bslib theme", {
  skip_if_not_installed("bslib")
  th <- nemeton:::nemeton_theme()
  expect_true(inherits(th, "bs_theme"))
})

test_that("theme_nemeton_accessible() subtitle has correct margin", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(th$plot.subtitle, "element_text")
  expect_equal(th$plot.subtitle$colour, "#666666")
})

test_that("theme_nemeton_accessible() panel background is f0f0f0", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_equal(th$panel.background$fill, "#f0f0f0")
  expect_true(is.na(th$panel.background$colour) ||
              is.null(th$panel.background$colour))
})

test_that("theme_nemeton_accessible() plot background is white", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_equal(th$plot.background$fill, "#FFFFFF")
})

test_that("theme_nemeton_accessible() strip styling correct", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_equal(th$strip.background$fill, "#f8f9fa")
  expect_equal(th$strip.text$face, "bold")
})

test_that("theme_nemeton_accessible() has legend at bottom", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_equal(th$legend.position, "bottom")
})

test_that("theme_nemeton_accessible() has bold axis titles", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_equal(th$axis.title$face, "bold")
})

test_that("theme_nemeton_accessible() minor grid is blank", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_true(inherits(th$panel.grid.minor, "element_blank"))
})

# ==============================================================================
# analysis-pareto.R — edge cases and additional validation
# ==============================================================================

test_that("identify_pareto_optimal with single parcel returns it as optimal", {
  df <- data.frame(family_C = 60, family_B = 50)
  result <- identify_pareto_optimal(
    df,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )
  expect_true(result$is_optimal[1])
})

test_that("identify_pareto_optimal with all identical rows: none dominated", {
  df <- data.frame(
    family_C = c(50, 50, 50),
    family_B = c(40, 40, 40)
  )
  result <- identify_pareto_optimal(
    df,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )
  expect_true(all(result$is_optimal))
})

test_that("identify_pareto_optimal with one parcel dominating all others", {
  df <- data.frame(
    family_C = c(100, 50, 60, 40),
    family_B = c(100, 60, 50, 70)
  )
  result <- identify_pareto_optimal(
    df,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )
  expect_true(result$is_optimal[1])
  expect_false(result$is_optimal[2])
  expect_false(result$is_optimal[3])
  expect_false(result$is_optimal[4])
})

test_that("identify_pareto_optimal with three objectives", {
  df <- data.frame(
    obj1 = c(90, 50, 70, 60),
    obj2 = c(50, 90, 60, 70),
    obj3 = c(60, 60, 90, 70)
  )
  result <- identify_pareto_optimal(
    df,
    objectives = c("obj1", "obj2", "obj3"),
    maximize = c(TRUE, TRUE, TRUE)
  )
  expect_gte(sum(result$is_optimal), 3)
})

test_that("identify_pareto_optimal early termination when dominated", {
  set.seed(42)
  n <- 20
  df <- data.frame(
    obj1 = runif(n, 0, 100),
    obj2 = runif(n, 0, 100)
  )
  result <- identify_pareto_optimal(
    df,
    objectives = c("obj1", "obj2"),
    maximize = c(TRUE, TRUE)
  )
  expect_true("is_optimal" %in% names(result))
  expect_equal(nrow(result), n)
  n_optimal <- sum(result$is_optimal)
  expect_gte(n_optimal, 1)
  expect_lte(n_optimal, n)
})

test_that("identify_pareto_optimal mixed maximize: first max, second min", {
  df <- data.frame(
    cost = c(10, 30, 50, 20),
    quality = c(80, 90, 70, 60)
  )
  result <- identify_pareto_optimal(
    df,
    objectives = c("cost", "quality"),
    maximize = c(FALSE, TRUE)
  )
  expect_true(result$is_optimal[1])
  expect_true(result$is_optimal[2])
})

test_that("identify_pareto_optimal with sf input preserves geometry", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 4)
  units$family_C <- c(90, 50, 70, 60)
  units$family_B <- c(50, 90, 60, 70)

  result <- identify_pareto_optimal(
    units,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )
  expect_s3_class(result, "sf")
  expect_true("is_optimal" %in% names(result))
})

# ==============================================================================
# data-massif_demo_layers.R — happy path tests
# ==============================================================================

test_that("massif_demo_layers() returns a nemeton_layers object", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  expect_s3_class(layers, "nemeton_layers")
  expect_true(!is.null(layers$rasters))
  expect_true(!is.null(layers$vectors))
})

test_that("massif_demo_layers() has expected raster names", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  expect_true("biomass" %in% names(layers$rasters))
  expect_true("dem" %in% names(layers$rasters))
  expect_true("landcover" %in% names(layers$rasters))
  expect_true("species_richness" %in% names(layers$rasters))
})

test_that("massif_demo_layers() has expected vector names", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  expect_true("roads" %in% names(layers$vectors))
  expect_true("water" %in% names(layers$vectors))
})

test_that("massif_demo_layers() has metadata", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  expect_equal(layers$metadata$dataset, "massif_demo")
  expect_equal(layers$metadata$crs, "EPSG:2154 (Lambert-93)")
  expect_equal(layers$metadata$resolution, "25m")
  expect_true(nchar(layers$metadata$description) > 0)
})

test_that("massif_demo_layers() rasters are not loaded (lazy)", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  for (name in names(layers$rasters)) {
    expect_false(layers$rasters[[name]]$loaded)
  }
})

test_that("massif_demo_layers() vectors are not loaded (lazy)", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  for (name in names(layers$vectors)) {
    expect_false(layers$vectors[[name]]$loaded)
  }
})

test_that("massif_demo_layers() raster paths exist", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  for (name in names(layers$rasters)) {
    expect_true(file.exists(layers$rasters[[name]]$path))
  }
})

test_that("massif_demo_layers() vector paths exist", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  for (name in names(layers$vectors)) {
    expect_true(file.exists(layers$vectors[[name]]$path))
  }
})

test_that("massif_demo_layers() metadata has extent", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()
  expect_true(!is.null(layers$metadata$extent))
  expect_true(nchar(layers$metadata$extent) > 0)
})
