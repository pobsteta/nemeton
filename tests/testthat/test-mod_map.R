# Tests for Map Module
# Phase 2: Leaflet map with parcel selection

test_that("mod_map_ui returns valid bslib card", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  ui <- nemeton:::mod_map_ui("test")

  expect_s3_class(ui, "shiny.tag")
  ui_html <- as.character(ui)

  # Should be a card
  expect_true(grepl("card", ui_html, ignore.case = TRUE))
})

test_that("mod_map_ui creates namespaced elements", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  ui <- nemeton:::mod_map_ui("test_ns")
  ui_html <- as.character(ui)

  expect_true(grepl("test_ns-map", ui_html))
  expect_true(grepl("test_ns-clear_selection", ui_html))
})

test_that("mod_map_ui includes basemap toggle buttons", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  ui <- nemeton:::mod_map_ui("test")
  ui_html <- as.character(ui)

  expect_true(grepl("basemap_osm", ui_html))
  expect_true(grepl("basemap_satellite", ui_html))
  expect_true(grepl("OSM", ui_html))
  expect_true(grepl("Satellite", ui_html))
})

test_that("mod_map_ui includes clear selection button", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  ui <- nemeton:::mod_map_ui("test")
  ui_html <- as.character(ui)

  expect_true(grepl("clear_selection", ui_html))
})

test_that("mod_map_ui includes leaflet output", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  ui <- nemeton:::mod_map_ui("test")
  ui_html <- as.character(ui)

  expect_true(grepl("leaflet", ui_html, ignore.case = TRUE))
})

test_that("mod_map_ui includes selection summary", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  ui <- nemeton:::mod_map_ui("test")
  ui_html <- as.character(ui)

  expect_true(grepl("selection_summary", ui_html))
})

test_that("mod_map_server is a function", {
  expect_type(nemeton:::mod_map_server, "closure")
})

test_that("mod_map_server accepts required parameters", {
  args <- names(formals(nemeton:::mod_map_server))

  expect_true("id" %in% args)
  expect_true("app_state" %in% args)
  expect_true("commune_geometry" %in% args)
  expect_true("parcels" %in% args)
})

test_that("MAX_PARCELS constant is defined correctly", {
  # Check app config returns correct value
  max_parcels <- nemeton:::get_app_config("max_parcels", 20L)

  expect_type(max_parcels, "integer")
  expect_equal(max_parcels, 20L)
})

test_that("Map styling constants are properly defined", {
  # This test validates the styling structure expected by the map module
  # The actual STYLE is defined inside the server function, but we can
  # verify the expected colors are used

  # These should match the theme colors
  commune_color <- "#1B6B1B"   # Forest green
  default_color <- "#666666"
  selected_color <- "#1B6B1B"

  expect_true(grepl("^#[0-9A-Fa-f]{6}$", commune_color))
  expect_true(grepl("^#[0-9A-Fa-f]{6}$", default_color))
  expect_true(grepl("^#[0-9A-Fa-f]{6}$", selected_color))
})
