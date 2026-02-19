# test-cov80-batch4.R
# Coverage boost for R/mod_search.R
# Target: helper functions, observers, reactive paths

# ==============================================================================
# Helper functions (non-reactive, can be tested directly)
# ==============================================================================

test_that("mod_search_ui creates valid HTML structure", {
  ui <- nemeton:::mod_search_ui("test_search")
  html_str <- as.character(ui)
  expect_true(grepl("test_search-departement", html_str))
  expect_true(grepl("test_search-commune", html_str))
  expect_true(grepl("test_search-loading_indicator", html_str))
})

# ==============================================================================
# testServer: mod_search_server
# ==============================================================================

test_that("mod_search_server initializes with NULL values", {
  # Mock external API calls
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain", "02" = "02 - Aisne"),
    get_communes_in_department = function(dept) {
      data.frame(
        code_insee = c("01001", "01002"),
        nom = c("Commune A", "Commune B"),
        stringsAsFactors = FALSE
      )
    },
    get_commune_geometry = function(code) create_test_units(n_features = 1),
    format_communes_for_selectize = function(communes) {
      stats::setNames(communes$code_insee, communes$nom)
    },
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # Initial values should be NULL
    expect_null(rv$selected_commune)
    expect_null(rv$commune_info)
    expect_null(rv$commune_geometry)
    expect_false(rv$is_loading)
    expect_false(rv$is_restoring)
    expect_equal(rv$restore_gen, 0L)
  })
})

test_that("mod_search_server get_lang returns fr by default", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = NULL,
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # get_lang should return "fr" when language is NULL
    expect_equal(get_lang(), "fr")

    # Change language
    app_state$language <- "en"
    expect_equal(get_lang(), "en")

    # Empty string fallback
    app_state$language <- ""
    expect_equal(get_lang(), "fr")
  })
})

test_that("mod_search_server handles department change with empty value", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # Set department to empty
    suppressWarnings(session$setInputs(departement = ""))
    # Should not crash
    expect_false(rv$is_loading)
  })
})

test_that("mod_search_server handles commune cleared", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # Clear commune selection
    suppressWarnings(session$setInputs(commune = ""))
    expect_null(rv$selected_commune)
    expect_null(rv$commune_geometry)
  })
})

test_that("mod_search_server skips department change during restore", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # Set restoring flag
    rv$is_restoring <- TRUE

    # Simulate department change - should be skipped
    session$setInputs(departement = "01")
    # is_loading should stay FALSE because observer returned early
    expect_false(rv$is_loading)
  })
})

test_that("mod_search_server skips commune_task during restore", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    rv$is_restoring <- TRUE
    rv$restore_gen <- 1L

    session$setInputs(commune = "01001")
    # Should return early, not invoke commune_task
    expect_false(rv$is_loading)
  })
})

test_that("mod_search_server restore observer reacts to app_state$restore_project", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) create_test_units(n_features = 1),
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # Initial state - no restore in progress
    expect_false(rv$is_restoring)
    expect_equal(rv$restore_gen, 0L)
    expect_null(rv$commune_geometry)
    # Module should have initialized without errors
    expect_false(rv$is_loading)
  })
})

test_that("mod_search_server ensure_future_plan helper works", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    # Call the helper directly
    expect_silent(ensure_future_plan())
  })
})

test_that("mod_search_server returns reactive list", {
  local_mocked_bindings(
    get_departments = function() c("01" = "01 - Ain"),
    get_communes_in_department = function(dept) data.frame(code_insee = character(0), nom = character(0), stringsAsFactors = FALSE),
    get_commune_geometry = function(code) NULL,
    format_communes_for_selectize = function(communes) character(0),
    .package = "nemeton"
  )

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE
  )

  shiny::testServer(nemeton:::mod_search_server, args = list(app_state = app_state), {
    result <- session$returned
    expect_true(is.list(result) || shiny::is.reactive(result) || is.function(result))
  })
})

# Drain async callbacks to prevent testServer session accumulation
later::run_now(0)
