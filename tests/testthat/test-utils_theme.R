# Tests for nemetonApp Theme and Accessibility Configuration
# R/utils_theme.R - Theme and WCAG 2.1 AA accessibility settings

# ==============================================================================
# Tests for ACCESSIBILITY_CONFIG structure
# ==============================================================================

test_that("ACCESSIBILITY_CONFIG has expected keys", {
  config <- nemeton:::ACCESSIBILITY_CONFIG

  expected_keys <- c(
    "color_palettes", "default_palette",
    "use_symbols", "symbol_shapes",
    "min_touch_target",
    "focus_ring_width", "focus_ring_color", "focus_ring_offset",
    "min_text_contrast", "min_ui_contrast",
    "min_font_size", "line_height"
  )

  for (key in expected_keys) {
    expect_true(
      key %in% names(config),
      info = paste("Missing ACCESSIBILITY_CONFIG key:", key)
    )
  }
})

test_that("ACCESSIBILITY_CONFIG color_palettes is a character vector", {
  palettes <- nemeton:::ACCESSIBILITY_CONFIG$color_palettes

  expect_type(palettes, "character")
  expect_true(length(palettes) > 0)
  expect_true("viridis" %in% palettes)
})

test_that("ACCESSIBILITY_CONFIG default_palette is viridis", {
  expect_equal(nemeton:::ACCESSIBILITY_CONFIG$default_palette, "viridis")
})

test_that("All color palettes are colorblind-friendly", {
  config <- nemeton:::ACCESSIBILITY_CONFIG

  # Only viridis family palettes are allowed
  valid_palettes <- c("viridis", "plasma", "inferno", "magma", "cividis")
  expect_true(all(config$color_palettes %in% valid_palettes))
})

test_that("ACCESSIBILITY_CONFIG min_touch_target is 44", {
  expect_equal(nemeton:::ACCESSIBILITY_CONFIG$min_touch_target, 44L)
})

test_that("ACCESSIBILITY_CONFIG use_symbols is TRUE", {
  expect_true(nemeton:::ACCESSIBILITY_CONFIG$use_symbols)
})

test_that("ACCESSIBILITY_CONFIG symbol_shapes has 7 shapes", {
  shapes <- nemeton:::ACCESSIBILITY_CONFIG$symbol_shapes

  expect_type(shapes, "integer")
  expect_length(shapes, 7)
})

test_that("ACCESSIBILITY_CONFIG contrast ratios meet WCAG standards", {
  config <- nemeton:::ACCESSIBILITY_CONFIG

  # WCAG 1.4.3: text contrast >= 4.5:1
  expect_equal(config$min_text_contrast, 4.5)

  # WCAG 1.4.11: UI contrast >= 3.0:1
  expect_equal(config$min_ui_contrast, 3.0)
})

test_that("ACCESSIBILITY_CONFIG focus ring settings are valid", {
  config <- nemeton:::ACCESSIBILITY_CONFIG

  expect_type(config$focus_ring_width, "integer")
  expect_gte(config$focus_ring_width, 3L)
  expect_match(config$focus_ring_color, "^#[0-9A-Fa-f]{6}$")
  expect_type(config$focus_ring_offset, "integer")
})

# ==============================================================================
# Tests for get_accessibility_config()
# ==============================================================================

test_that("get_accessibility_config returns correct values for known keys", {
  expect_equal(nemeton:::get_accessibility_config("min_touch_target"), 44L)
  expect_equal(nemeton:::get_accessibility_config("default_palette"), "viridis")
  expect_true(nemeton:::get_accessibility_config("use_symbols"))
  expect_equal(nemeton:::get_accessibility_config("line_height"), 1.5)
})

test_that("get_accessibility_config returns default for unknown keys", {
  expect_null(nemeton:::get_accessibility_config("nonexistent_key"))
  expect_equal(nemeton:::get_accessibility_config("nonexistent_key", "fallback"), "fallback")
  expect_equal(nemeton:::get_accessibility_config("missing_key", 99), 99)
})

test_that("get_accessibility_config returns NULL default when key missing", {
  result <- nemeton:::get_accessibility_config("this_key_does_not_exist")
  expect_null(result)
})

test_that("get_accessibility_config returns symbol_shapes correctly", {
  shapes <- nemeton:::get_accessibility_config("symbol_shapes")

  expect_type(shapes, "integer")
  expect_length(shapes, 7)
})

test_that("get_accessibility_config returns color_palettes correctly", {
  palettes <- nemeton:::get_accessibility_config("color_palettes")

  expect_type(palettes, "character")
  expect_true("viridis" %in% palettes)
  expect_true("plasma" %in% palettes)
  expect_true("cividis" %in% palettes)
})

# ==============================================================================
# Tests for get_accessible_symbols()
# ==============================================================================

test_that("get_accessible_symbols returns correct length", {
  symbols_3 <- nemeton:::get_accessible_symbols(3)
  symbols_5 <- nemeton:::get_accessible_symbols(5)
  symbols_7 <- nemeton:::get_accessible_symbols(7)

  expect_length(symbols_3, 3)
  expect_length(symbols_5, 5)
  expect_length(symbols_7, 7)
})

test_that("get_accessible_symbols returns integer vector", {
  symbols <- nemeton:::get_accessible_symbols(5)

  expect_type(symbols, "integer")
})

test_that("get_accessible_symbols returns valid pch values", {
  symbols <- nemeton:::get_accessible_symbols(7)

  # All should be valid pch values (0-25 plus special values like 3, 4)
  expect_true(all(symbols %in% 0:25))
})

test_that("get_accessible_symbols recycles when n > 7", {
  symbols_7 <- nemeton:::get_accessible_symbols(7)
  symbols_10 <- nemeton:::get_accessible_symbols(10)

  expect_length(symbols_10, 10)

  # First 7 should match exactly
  expect_equal(symbols_10[1:7], symbols_7)

  # Elements 8-10 should be recycled from elements 1-3
  expect_equal(symbols_10[8], symbols_7[1])
  expect_equal(symbols_10[9], symbols_7[2])
  expect_equal(symbols_10[10], symbols_7[3])
})

test_that("get_accessible_symbols recycles for large n", {
  symbols_14 <- nemeton:::get_accessible_symbols(14)
  symbols_7 <- nemeton:::get_accessible_symbols(7)

  expect_length(symbols_14, 14)

  # Should be two full cycles
  expect_equal(symbols_14[1:7], symbols_7)
  expect_equal(symbols_14[8:14], symbols_7)
})

test_that("get_accessible_symbols returns single symbol for n=1", {
  symbols <- nemeton:::get_accessible_symbols(1)

  expect_length(symbols, 1)
  expect_type(symbols, "integer")
})

# ==============================================================================
# Tests for get_family_colors()
# ==============================================================================

test_that("get_family_colors returns 12 named colors", {
  colors <- nemeton:::get_family_colors()

  expect_type(colors, "character")
  expect_length(colors, 12)
  expect_true(!is.null(names(colors)))
})

test_that("get_family_colors names match family codes", {
  colors <- nemeton:::get_family_colors()
  expected_names <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")

  expect_equal(names(colors), expected_names)
})

test_that("get_family_colors returns hex color values", {
  colors <- nemeton:::get_family_colors()

  for (i in seq_along(colors)) {
    # viridis returns 9-character hex strings (#RRGGBBAA) with alpha channel
    expect_match(
      colors[[i]], "^#[0-9A-Fa-f]{6,8}$",
      info = paste("Invalid hex color for family:", names(colors)[i])
    )
  }
})

test_that("get_family_colors returns unique colors", {
  colors <- nemeton:::get_family_colors()

  expect_equal(length(unique(colors)), 12)
})

# ==============================================================================
# Tests for get_accessible_palette()
# ==============================================================================

test_that("get_accessible_palette returns correct number of colors", {
  skip_if_not_installed("viridisLite")

  colors <- nemeton:::get_accessible_palette(5)
  expect_length(colors, 5)
  expect_type(colors, "character")

  # Check hex format
  expect_true(all(grepl("^#[0-9A-Fa-f]{6,8}$", colors)))
})

test_that("get_accessible_palette uses viridis by default", {
  skip_if_not_installed("viridisLite")

  colors <- nemeton:::get_accessible_palette(3)
  expected <- viridisLite::viridis(3)

  expect_equal(colors, expected)
})

test_that("get_accessible_palette warns for non-colorblind-safe palettes", {
  skip_if_not_installed("viridisLite")

  # Should warn and fall back to viridis
  expect_warning(
    nemeton:::get_accessible_palette(3, palette = "rainbow"),
    "not colorblind-friendly"
  )
})

# ==============================================================================
# Tests for nemeton_theme()
# ==============================================================================

test_that("nemeton_theme returns a bslib theme", {
  skip_if_not_installed("bslib")

  theme <- nemeton:::nemeton_theme()
  expect_s3_class(theme, "bs_theme")
})

# ==============================================================================
# Tests for theme_nemeton_accessible()
# ==============================================================================

test_that("theme_nemeton_accessible returns a ggplot2 theme", {
  skip_if_not_installed("ggplot2")

  theme <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(theme, "theme")
})
