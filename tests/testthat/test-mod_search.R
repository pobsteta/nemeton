# Tests for Search Module
# Phase 2: Commune search UI module

test_that("mod_search_ui returns valid Shiny UI", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("test")

  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_search_ui creates namespaced inputs", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("test_ns")
  ui_html <- as.character(ui)

  # Check for namespaced input IDs
  expect_true(grepl("test_ns-departement", ui_html))
  expect_true(grepl("test_ns-commune", ui_html))
})

test_that("mod_search_ui includes department selector", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("test")
  ui_html <- as.character(ui)

  expect_true(grepl("departement", ui_html))
  expect_true(grepl("select", ui_html, ignore.case = TRUE))
})

test_that("mod_search_ui includes commune autocomplete", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("test")
  ui_html <- as.character(ui)

  expect_true(grepl("commune", ui_html))
  expect_true(grepl("selectize", ui_html, ignore.case = TRUE))
})


test_that("mod_search_server is a function", {
  expect_type(nemeton:::mod_search_server, "closure")
})

test_that("mod_search_server accepts required parameters", {
  # Check function signature
  args <- names(formals(nemeton:::mod_search_server))

  expect_true("id" %in% args)
  expect_true("app_state" %in% args)
})
