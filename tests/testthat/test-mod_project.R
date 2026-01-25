# Tests for Project Module
# Phase 3: Project metadata form

test_that("mod_project_ui returns valid Shiny UI", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_project_ui("test")

      expect_s3_class(ui, "shiny.tag")
    }
  )
})

test_that("mod_project_ui creates namespaced inputs", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_project_ui("test_ns")
      ui_html <- as.character(ui)

      # Check for namespaced input IDs
      expect_true(grepl("test_ns-name", ui_html))
      expect_true(grepl("test_ns-description", ui_html))
      expect_true(grepl("test_ns-owner", ui_html))
      expect_true(grepl("test_ns-create", ui_html))
    }
  )
})

test_that("mod_project_ui includes required field marker", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_project_ui("test")
      ui_html <- as.character(ui)

      # Name should have required marker (*)
      expect_true(grepl("text-danger", ui_html))
    }
  )
})

test_that("mod_project_ui includes character limit hints", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_project_ui("test")
      ui_html <- as.character(ui)

      # Should mention character limits
      expect_true(grepl("100", ui_html))
      expect_true(grepl("500", ui_html))
    }
  )
})

test_that("mod_project_server is a function", {
  expect_type(nemeton:::mod_project_server, "closure")
})

test_that("mod_project_server accepts required parameters", {
  args <- names(formals(nemeton:::mod_project_server))

  expect_true("id" %in% args)
  expect_true("app_state" %in% args)
  expect_true("selected_parcels" %in% args)
})

test_that("mod_project_info_ui returns valid UI", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_project_info_ui("test")

      expect_s3_class(ui, "shiny.tag")
    }
  )
})

test_that("mod_project_info_ui is hidden by default", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_project_info_ui("test")
      ui_html <- as.character(ui)

      expect_true(grepl("d-none", ui_html))
    }
  )
})
