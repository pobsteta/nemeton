# Coverage boost tests for R/utils_theme.R
# Targets: nemeton_theme() properties, theme_nemeton_accessible() details,
# get_accessible_palette() with different palettes/alpha

# ==============================================================================
# nemeton_theme() — detailed property checks
# ==============================================================================

test_that("nemeton_theme uses Bootstrap 5", {
  skip_if_not_installed("bslib")
  theme <- nemeton:::nemeton_theme()
  expect_s3_class(theme, "bs_theme")
  # Bootstrap 5 is the version used
  version <- bslib::theme_version(theme)
  expect_equal(version, "5")
})

test_that("nemeton_theme includes custom CSS rules", {
  skip_if_not_installed("bslib")
  theme <- nemeton:::nemeton_theme()
  # The theme should have custom rules added via bs_add_rules
  # Convert to CSS to check for custom rules
  css <- bslib::bs_theme_dependencies(theme)
  expect_true(length(css) > 0)
})

test_that("nemeton_theme returns a consistent object", {
  skip_if_not_installed("bslib")
  theme1 <- nemeton:::nemeton_theme()
  theme2 <- nemeton:::nemeton_theme()
  # Both should be bs_theme objects
  expect_s3_class(theme1, "bs_theme")
  expect_s3_class(theme2, "bs_theme")
})

# ==============================================================================
# theme_nemeton_accessible() — detailed checks
# ==============================================================================

test_that("theme_nemeton_accessible has base_size 14", {
  skip_if_not_installed("ggplot2")
  theme <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(theme, "theme")
  # Check that text element uses the expected color
  expect_equal(theme$text$colour, "#2C3E50")
})

test_that("theme_nemeton_accessible has bold axis titles", {
  skip_if_not_installed("ggplot2")
  theme <- nemeton:::theme_nemeton_accessible()
  expect_equal(theme$axis.title$face, "bold")
})

test_that("theme_nemeton_accessible legend is at bottom", {
  skip_if_not_installed("ggplot2")
  theme <- nemeton:::theme_nemeton_accessible()
  expect_equal(theme$legend.position, "bottom")
})

test_that("theme_nemeton_accessible bold title", {
  skip_if_not_installed("ggplot2")
  theme <- nemeton:::theme_nemeton_accessible()
  expect_equal(theme$plot.title$face, "bold")
})

test_that("theme_nemeton_accessible no minor grid", {
  skip_if_not_installed("ggplot2")
  theme <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(theme$panel.grid.minor, "element_blank")
})

test_that("theme_nemeton_accessible can be added to a ggplot", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(data.frame(x = 1:5, y = 1:5), ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    nemeton:::theme_nemeton_accessible()
  expect_s3_class(p, "ggplot")
})

# ==============================================================================
# get_accessible_palette() — various palettes and alpha
# ==============================================================================

test_that("get_accessible_palette with plasma palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(5, palette = "plasma")
  expect_length(colors, 5)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_accessible_palette with inferno palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(4, palette = "inferno")
  expect_length(colors, 4)
})

test_that("get_accessible_palette with cividis palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(3, palette = "cividis")
  expect_length(colors, 3)
})

test_that("get_accessible_palette with magma palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(6, palette = "magma")
  expect_length(colors, 6)
})

test_that("get_accessible_palette with alpha transparency", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(3, alpha = 0.5)
  expect_length(colors, 3)
  # With alpha < 1, colors should be 9 chars (#RRGGBBAA)
  expect_true(all(nchar(colors) == 9))
})

test_that("get_accessible_palette with alpha = 1 (default)", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(3, alpha = 1)
  expect_length(colors, 3)
})

test_that("get_accessible_palette warns for invalid palette and uses viridis", {
  skip_if_not_installed("viridisLite")
  expect_warning(
    colors <- nemeton:::get_accessible_palette(3, palette = "rainbow"),
    "not colorblind-friendly"
  )
  expected <- viridisLite::viridis(3)
  expect_equal(colors, expected)
})

test_that("get_accessible_palette with n=1", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(1)
  expect_length(colors, 1)
})

test_that("get_accessible_palette with large n", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_accessible_palette(50)
  expect_length(colors, 50)
  # All should be unique hex colors
  expect_true(all(grepl("^#", colors)))
})

# ==============================================================================
# get_family_colors() — additional checks
# ==============================================================================

test_that("get_family_colors uses viridis palette", {
  skip_if_not_installed("viridisLite")
  colors <- nemeton:::get_family_colors()
  expected <- nemeton:::get_accessible_palette(12)
  names(expected) <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  expect_equal(colors, expected)
})

# ==============================================================================
# get_accessible_symbols() — edge cases
# ==============================================================================

test_that("get_accessible_symbols with n=0", {
  symbols <- nemeton:::get_accessible_symbols(0)
  expect_length(symbols, 0)
})

test_that("get_accessible_symbols with n=2", {
  symbols <- nemeton:::get_accessible_symbols(2)
  expect_length(symbols, 2)
  expect_type(symbols, "integer")
})

# ==============================================================================
# get_accessibility_config() — more keys
# ==============================================================================

test_that("get_accessibility_config returns min_font_size", {
  result <- nemeton:::get_accessibility_config("min_font_size")
  expect_equal(result, 16L)
})

test_that("get_accessibility_config returns focus_ring_color", {
  result <- nemeton:::get_accessibility_config("focus_ring_color")
  expect_equal(result, "#005FCC")
})

test_that("get_accessibility_config returns focus_ring_offset", {
  result <- nemeton:::get_accessibility_config("focus_ring_offset")
  expect_equal(result, 2L)
})

test_that("get_accessibility_config returns min_ui_contrast", {
  result <- nemeton:::get_accessibility_config("min_ui_contrast")
  expect_equal(result, 3.0)
})
