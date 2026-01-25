# Tests for nemetonApp Theme and Accessibility
# Phase 1: Theme configuration and WCAG compliance

test_that("nemeton_theme returns a bslib theme", {
  skip_if_not_installed("bslib")

  theme <- nemeton:::nemeton_theme()
  expect_s3_class(theme, "bs_theme")
})

test_that("ACCESSIBILITY_CONFIG contains required keys", {
  config <- nemeton:::ACCESSIBILITY_CONFIG

  required_keys <- c(
    "color_palettes",
    "default_palette",
    "use_symbols",
    "symbol_shapes",
    "min_touch_target",
    "focus_ring_width",
    "focus_ring_color",
    "min_text_contrast",
    "min_ui_contrast"
  )

  for (key in required_keys) {
    expect_true(
      key %in% names(config),
      info = paste("Missing accessibility config key:", key)
    )
  }
})

test_that("Default palette is viridis", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_equal(config$default_palette, "viridis")
})

test_that("All color palettes are colorblind-friendly", {
  config <- nemeton:::ACCESSIBILITY_CONFIG

  # Only viridis family palettes are allowed
  valid_palettes <- c("viridis", "plasma", "inferno", "magma", "cividis")
  expect_true(all(config$color_palettes %in% valid_palettes))
})

test_that("Minimum touch target is WCAG compliant (44px)", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_equal(config$min_touch_target, 44L)
})

test_that("Focus ring width is at least 3px", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_gte(config$focus_ring_width, 3L)
})

test_that("Text contrast ratio meets WCAG AA (4.5:1)", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_gte(config$min_text_contrast, 4.5)
})

test_that("UI contrast ratio meets WCAG AA (3:1)", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_gte(config$min_ui_contrast, 3.0)
})

test_that("get_accessible_palette returns correct number of colors", {
  skip_if_not_installed("viridisLite")

  get_palette <- nemeton:::get_accessible_palette

  colors <- get_palette(5)
  expect_length(colors, 5)
  expect_type(colors, "character")

  # Check hex format
  expect_true(all(grepl("^#[0-9A-Fa-f]{6,8}$", colors)))
})

test_that("get_accessible_palette uses viridis by default", {
  skip_if_not_installed("viridisLite")

  get_palette <- nemeton:::get_accessible_palette

  # Default should be viridis
  colors <- get_palette(3)
  expected <- viridisLite::viridis(3)

  expect_equal(colors, expected)
})

test_that("get_accessible_palette warns for non-colorblind-safe palettes", {
  skip_if_not_installed("viridisLite")

  get_palette <- nemeton:::get_accessible_palette

  # Should warn and fall back to viridis
  expect_warning(
    get_palette(3, palette = "rainbow"),
    "not colorblind-friendly"
  )
})

test_that("get_accessible_symbols returns correct number of symbols", {
  get_symbols <- nemeton:::get_accessible_symbols

  symbols <- get_symbols(5)
  expect_length(symbols, 5)
  expect_type(symbols, "integer")

  # All should be valid pch values
  expect_true(all(symbols %in% 0:25))
})

test_that("get_family_colors returns 12 named colors", {
  colors <- nemeton:::get_family_colors()

  expect_length(colors, 12)
  expect_equal(
    names(colors),
    c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )

  # All should be hex colors
  expect_true(all(grepl("^#[0-9A-Fa-f]{6,8}$", colors)))
})

test_that("theme_nemeton_accessible returns a ggplot2 theme", {
  skip_if_not_installed("ggplot2")

  theme <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(theme, "theme")
})
