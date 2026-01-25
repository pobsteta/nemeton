# Tests for Home Module
# Phase 3: Main home/selection page

test_that("mod_home_ui returns valid Shiny UI", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test")

      expect_s3_class(ui, "shiny.tag")
    }
  )
})

test_that("mod_home_ui includes sidebar", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test")
      ui_html <- as.character(ui)

      # Should have sidebar
      expect_true(grepl("sidebar", ui_html, ignore.case = TRUE))
    }
  )
})

test_that("mod_home_ui includes recent projects section", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test")
      ui_html <- as.character(ui)

      expect_true(grepl("recent_projects", ui_html))
    }
  )
})

test_that("mod_home_ui includes search module", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test")
      ui_html <- as.character(ui)

      # Search module should be included
      expect_true(grepl("test-search", ui_html))
    }
  )
})

test_that("mod_home_ui includes map module", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test")
      ui_html <- as.character(ui)

      # Map module should be included
      expect_true(grepl("test-map", ui_html))
    }
  )
})

test_that("mod_home_ui includes project form module", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test")
      ui_html <- as.character(ui)

      # Project module should be included
      expect_true(grepl("test-project", ui_html))
    }
  )
})

test_that("mod_home_server is a function", {
  expect_type(nemeton:::mod_home_server, "closure")
})

test_that("mod_home_server accepts required parameters", {
  args <- names(formals(nemeton:::mod_home_server))

  expect_true("id" %in% args)
  expect_true("app_state" %in% args)
})
