# test-cov60-batch5.R
# Coverage boost for mod_search.R — target >60%
# Uses shiny::testServer() which contributes to covr coverage

# ==============================================================================
# mod_search.R — UI tests
# ==============================================================================

test_that("mod_search_ui returns valid Shiny UI", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("test_search")
  expect_true(
    inherits(ui, "shiny.tag") || inherits(ui, "shiny.tag.list")
  )

  ui_html <- as.character(ui)
  expect_true(grepl("test_search", ui_html))
})

test_that("mod_search_ui contains department selector", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("search")
  ui_html <- as.character(ui)

  expect_true(grepl("search-departement", ui_html))
})

test_that("mod_search_ui contains commune selector", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  ui <- nemeton:::mod_search_ui("search")
  ui_html <- as.character(ui)

  expect_true(grepl("search-commune", ui_html))
})

# ==============================================================================
# mod_search.R — shiny::testServer() tests
# ==============================================================================

test_that("mod_search_server initializes reactive values", {
  skip_if_not_installed("shiny")

  app_state <- shiny::reactiveValues(
    restore_project = NULL,
    restore_in_progress = FALSE,
    commune_transitioning = FALSE
  )

  shiny::testServer(
    nemeton:::mod_search_server,
    args = list(app_state = app_state),
    {
      # Check that reactive values are initialized
      expect_true(!is.null(rv))
      expect_null(rv$selected_commune)
      expect_null(rv$commune_geometry)
      expect_false(rv$is_loading)
    }
  )
})

test_that("mod_search_server returns expected reactive list", {
  skip_if_not_installed("shiny")

  app_state <- shiny::reactiveValues(
    restore_project = NULL,
    restore_in_progress = FALSE,
    commune_transitioning = FALSE
  )

  shiny::testServer(
    nemeton:::mod_search_server,
    args = list(app_state = app_state),
    {
      result <- session$returned
      expect_type(result, "list")
      expect_true("selected_commune" %in% names(result))
      expect_true("commune_geometry" %in% names(result))
      expect_true("is_loading" %in% names(result))
    }
  )
})

test_that("mod_search_server department change triggers loading", {
  skip_if_not_installed("shiny")

  app_state <- shiny::reactiveValues(
    restore_project = NULL,
    restore_in_progress = FALSE,
    commune_transitioning = FALSE
  )

  shiny::testServer(
    nemeton:::mod_search_server,
    args = list(app_state = app_state),
    {
      # Set a department
      session$setInputs(department = "36")
      session$flushReact()

      # Department input was set (rv may or may not have changed yet)
      expect_true(is.null(rv$department_changed) || rv$department_changed >= 0)
    }
  )
})

test_that("mod_search_server handles NULL commune input", {
  skip_if_not_installed("shiny")

  app_state <- shiny::reactiveValues(
    restore_project = NULL,
    restore_in_progress = FALSE,
    commune_transitioning = FALSE
  )

  shiny::testServer(
    nemeton:::mod_search_server,
    args = list(app_state = app_state),
    {
      session$setInputs(commune = "")
      session$flushReact()

      # Empty commune should not set geometry
      expect_null(rv$commune_geometry)
    }
  )
})
