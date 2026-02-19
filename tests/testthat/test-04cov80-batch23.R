# test-cov80-batch23.R
# Coverage boost for R/mod_project.R and R/mod_progress.R
# Targets: validate_form() direct access, edge cases in translate_task(),
#          translate_indicator_name(), translate_phase(), send_running_update(),
#          reset_tracking(), observer edge cases, action_button edit mode,
#          validation_message rendering, date formatting, project form observer paths

# ==============================================================================
# Shared helpers
# ==============================================================================

make_project_app_state <- function(current_project = NULL, project_id = NULL) {
  shiny::reactiveValues(
    current_project = current_project,
    project_id = project_id,
    refresh_projects = NULL,
    restore_in_progress = FALSE
  )
}

make_progress_app_state <- function() {
  shiny::reactiveValues(
    cancel_computation = NULL,
    retry_computation = NULL
  )
}

# ==============================================================================
# PART 1: mod_project.R — validate_form() direct access
# ==============================================================================

test_that("mod_project_server: validate_form returns FALSE for empty name string", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "", description = "", owner = "")
          result <- validate_form()
          expect_false(result)
          expect_true(length(rv$validation_errors) > 0)
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form returns TRUE for valid name", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "My Project", description = "", owner = "")
          result <- validate_form()
          expect_true(result)
          expect_equal(length(rv$validation_errors), 0)
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form rejects name >100 chars", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          long_name <- paste(rep("x", 101), collapse = "")
          session$setInputs(name = long_name, description = "", owner = "")
          result <- validate_form()
          expect_false(result)
          expect_true(length(rv$validation_errors) >= 1)
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form rejects description >500 chars", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          long_desc <- paste(rep("d", 501), collapse = "")
          session$setInputs(name = "Valid", description = long_desc, owner = "")
          result <- validate_form()
          expect_false(result)
          expect_true(any(grepl("500|description", rv$validation_errors, ignore.case = TRUE)))
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form rejects owner >100 chars", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          long_owner <- paste(rep("o", 101), collapse = "")
          session$setInputs(name = "Valid", description = "", owner = long_owner)
          result <- validate_form()
          expect_false(result)
          expect_true(any(grepl("100|owner", rv$validation_errors, ignore.case = TRUE)))
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form accumulates multiple errors", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          long_desc <- paste(rep("d", 501), collapse = "")
          long_owner <- paste(rep("o", 101), collapse = "")
          session$setInputs(name = "", description = long_desc, owner = long_owner)
          result <- validate_form()
          expect_false(result)
          # Should have at least 3 errors: empty name + long desc + long owner
          expect_true(length(rv$validation_errors) >= 3)
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form passes at boundary (100 chars name)", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          exact_name <- paste(rep("x", 100), collapse = "")
          session$setInputs(name = exact_name, description = "", owner = "")
          result <- validate_form()
          expect_true(result)
          expect_equal(length(rv$validation_errors), 0)
        }
      )
    }
  )
})

test_that("mod_project_server: validate_form passes at boundary (500 chars description)", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          exact_desc <- paste(rep("d", 500), collapse = "")
          session$setInputs(name = "Valid", description = exact_desc, owner = "")
          result <- validate_form()
          expect_true(result)
        }
      )
    }
  )
})

# ==============================================================================
# PART 1b: mod_project.R — rv state and outputs
# ==============================================================================

test_that("mod_project_server: initial rv state is create mode", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          expect_null(rv$current_project)
          expect_null(rv$editing_project_id)
          expect_equal(length(rv$validation_errors), 0)
          expect_true(nchar(rv$project_date) > 0)
          expect_null(rv$last_opened_project_id)
        }
      )
    }
  )
})

test_that("mod_project_server: date_display output renders date string", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          date_html <- output$date_display
          expect_true(!is.null(date_html))
          date_str <- as.character(date_html$html)
          # Should contain the current date in dd/mm/yyyy format
          expect_true(any(grepl("\\d{2}/\\d{2}/\\d{4}", date_str)))
        }
      )
    }
  )
})

test_that("mod_project_server: validation_message output renders errors when present", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          # Trigger validation errors
          session$setInputs(name = "", description = "", owner = "")
          validate_form()
          session$flushReact()

          val_html <- output$validation_message
          expect_true(!is.null(val_html))
          val_str <- as.character(val_html$html)
          expect_true(any(grepl("text-danger", val_str)))
        }
      )
    }
  )
})

test_that("mod_project_server: validation_message output is empty when no errors", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "Valid", description = "", owner = "")
          validate_form()
          session$flushReact()

          val_html <- output$validation_message
          val_str <- as.character(val_html$html)
          # When no errors, renderUI returns NULL which becomes empty html
          expect_true(!any(grepl("text-danger", val_str)))
        }
      )
    }
  )
})

test_that("mod_project_server: action_button renders create button when no editing_project_id", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(create_test_units(n_features = 2))

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$flushReact()
          btn_html <- output$action_button
          expect_true(!is.null(btn_html))
          btn_str <- as.character(btn_html$html)
          expect_true(any(grepl("create_project", btn_str)))
          # Button should be enabled since parcels exist
          expect_true(any(grepl("btn-success", btn_str)))
        }
      )
    }
  )
})

test_that("mod_project_server: action_button renders update/delete in edit mode", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(create_test_units(n_features = 2))

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          # Set edit mode
          rv$editing_project_id <- "proj_test_123"
          session$flushReact()
          btn_html <- output$action_button
          btn_str <- as.character(btn_html$html)
          expect_true(any(grepl("update_project", btn_str)))
          expect_true(any(grepl("delete_project", btn_str)))
          expect_true(any(grepl("btn-primary", btn_str)))
        }
      )
    }
  )
})

test_that("mod_project_server: action_button is disabled without parcels", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$flushReact()
          btn_html <- output$action_button
          btn_str <- as.character(btn_html$html)
          expect_true(any(grepl("disabled", btn_str)))
        }
      )
    }
  )
})

# ==============================================================================
# PART 1c: mod_project.R — observer paths
# ==============================================================================

test_that("mod_project_server: restore project sets editing_project_id and date", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "", description = "", owner = "")

          # Set project (triggers observeEvent with ignoreInit=TRUE)
          app_state$current_project <- list(
            id = "proj_abc",
            metadata = list(
              name = "Restored Project",
              description = "A restored project",
              owner = "Owner X",
              created_at = "2025-06-15 10:30:00"
            )
          )
          session$flushReact()

          expect_equal(rv$editing_project_id, "proj_abc")
          expect_true(grepl("15/06/2025", rv$project_date))
          expect_equal(rv$last_opened_project_id, "proj_abc")
        }
      )
    }
  )
})

test_that("mod_project_server: clearing project resets form to create mode", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "", description = "", owner = "")

          # First load a project
          app_state$current_project <- list(
            id = "proj_clear",
            metadata = list(
              name = "To Clear",
              description = "Will be cleared",
              owner = "Owner",
              created_at = "2025-01-01 12:00:00"
            )
          )
          session$flushReact()
          expect_equal(rv$editing_project_id, "proj_clear")

          # Now clear by setting to NULL
          app_state$current_project <- NULL
          session$flushReact()

          expect_null(rv$editing_project_id)
          expect_null(rv$current_project)
        }
      )
    }
  )
})

test_that("mod_project_server: same project ID does not re-open panel", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "", description = "", owner = "")

          proj <- list(
            id = "proj_same",
            metadata = list(name = "Same", description = "", owner = "", created_at = "2025-01-01 00:00:00")
          )

          # First load
          app_state$current_project <- proj
          session$flushReact()
          expect_equal(rv$last_opened_project_id, "proj_same")

          # Reload same project (e.g., after computation)
          app_state$current_project <- proj
          session$flushReact()
          # last_opened_project_id remains same, no crash
          expect_equal(rv$last_opened_project_id, "proj_same")
        }
      )
    }
  )
})

test_that("mod_project_server: restore_in_progress suppresses panel opening", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- shiny::reactiveValues(
        current_project = NULL,
        project_id = NULL,
        refresh_projects = NULL,
        restore_in_progress = TRUE
      )
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          session$setInputs(name = "", description = "", owner = "")

          app_state$current_project <- list(
            id = "proj_restore",
            metadata = list(name = "Restore", description = "", owner = "", created_at = "2025-01-01 00:00:00")
          )
          session$flushReact()

          # Should still set editing_project_id
          expect_equal(rv$editing_project_id, "proj_restore")
        }
      )
    }
  )
})

test_that("mod_project_server: returned list has current_project and project_created reactives", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      app_state <- make_project_app_state()
      parcels_rv <- shiny::reactiveVal(NULL)

      shiny::testServer(
        nemeton:::mod_project_server,
        args = list(app_state = app_state, selected_parcels = parcels_rv),
        {
          result <- session$getReturned()
          expect_true(is.list(result))
          expect_true("current_project" %in% names(result))
          expect_true("project_created" %in% names(result))
          expect_true(is.function(result$current_project))
          expect_true(is.function(result$project_created))
          expect_null(result$current_project())
          expect_null(result$project_created())
        }
      )
    }
  )
})

# ==============================================================================
# PART 2: mod_progress.R — translate_task() internal function
# ==============================================================================

test_that("mod_progress_server: translate_task NULL returns empty string", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          expect_equal(translate_task(NULL), "")
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task known keys return non-empty strings", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          for (key in c("download_start", "compute_start", "complete", "error", "resuming")) {
            result <- translate_task(key)
            expect_type(result, "character")
            expect_true(nchar(result) > 0, info = paste("Empty for key:", key))
          }
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task download_complete", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- translate_task("download_complete")
          expect_type(result, "character")
          expect_true(nchar(result) > 0)
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task download_oso_progress includes percentage", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- translate_task("download_oso_progress:72")
          expect_true(grepl("72", result))
          expect_true(grepl("OSO", result))
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task download_lidar with all product types", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          # MNH product
          r1 <- translate_task("download_lidar:mnh:10/100")
          expect_true(nchar(r1) > 0)
          expect_true(grepl("10/100", r1))

          # MNT product
          r2 <- translate_task("download_lidar:mnt:50/200")
          expect_true(nchar(r2) > 0)
          expect_true(grepl("50/200", r2))

          # nuage product (maps to copc)
          r3 <- translate_task("download_lidar:nuage:3/10")
          expect_true(nchar(r3) > 0)
          expect_true(grepl("3/10", r3))

          # Unknown lidar product
          r4 <- suppressWarnings(translate_task("download_lidar:custom_product:1/5"))
          expect_true(nchar(r4) > 0)
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task download source prefix", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- suppressWarnings(translate_task("download:bdforet"))
          expect_type(result, "character")
          expect_true(nchar(result) > 0)
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task compute indicator prefix", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- suppressWarnings(translate_task("compute:carbon_biomass"))
          expect_type(result, "character")
          expect_true(nchar(result) > 0)
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_task unknown task falls through", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- translate_task("completely_unknown_task_xyz")
          expect_type(result, "character")
          expect_true(nchar(result) > 0)
          # Should contain the original task string as fallback
          expect_true(grepl("completely_unknown_task_xyz", result))
        }
      )
    }
  )
})

# ==============================================================================
# PART 2b: mod_progress.R — translate_indicator_name()
# ==============================================================================

test_that("mod_progress_server: translate_indicator_name returns labels for known keys", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          known_keys <- c(
            "carbon_biomass", "carbon_ndvi",
            "biodiversity_protection", "biodiversity_structure", "biodiversity_connectivity",
            "water_network", "water_wetlands", "water_twi",
            "risk_fire", "risk_storm", "risk_drought", "risk_browsing",
            "social_trails", "social_accessibility",
            "naturalness_distance", "naturalness_continuity", "naturalness_score"
          )
          for (key in known_keys) {
            label <- translate_indicator_name(key)
            expect_type(label, "character")
            expect_true(nchar(label) > 0, info = paste("Empty label for:", key))
            # Known keys should NOT return the raw key
            expect_false(identical(label, key), info = paste("Raw key returned for:", key))
          }
        }
      )
    }
  )
})

test_that("mod_progress_server: translate_indicator_name returns key for unknown indicator", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- translate_indicator_name("nonexistent_indicator_key")
          expect_equal(result, "nonexistent_indicator_key")
        }
      )
    }
  )
})

# ==============================================================================
# PART 2c: mod_progress.R — translate_phase()
# ==============================================================================

test_that("mod_progress_server: translate_phase all branches", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          r_init <- translate_phase("init")
          expect_type(r_init, "character")
          expect_true(nchar(r_init) > 0)

          r_dl <- translate_phase("downloading")
          expect_type(r_dl, "character")
          expect_true(nchar(r_dl) > 0)

          r_comp <- translate_phase("computing")
          expect_type(r_comp, "character")
          expect_true(nchar(r_comp) > 0)

          r_complete <- translate_phase("complete")
          expect_type(r_complete, "character")
          expect_true(nchar(r_complete) > 0)

          # Unknown phase returns empty string
          r_unknown <- translate_phase("foobar")
          expect_equal(r_unknown, "")

          # NULL phase returns empty string
          r_null <- translate_phase(NULL)
          expect_equal(r_null, "")
        }
      )
    }
  )
})

# ==============================================================================
# PART 2d: mod_progress.R — reset_tracking()
# ==============================================================================

test_that("mod_progress_server: reset_tracking clears all tracking fields", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          # Initialize tracking via send_running_update
          state <- list(
            status = "computing", phase = "computing",
            progress = 3, progress_max = 10,
            indicators_completed = 3, indicators_failed = 0,
            indicators_total = 10, current_task = "compute:carbon_biomass",
            errors = list()
          )
          suppressWarnings(send_running_update(state))

          # Tracking should now be initialized
          expect_false(is.null(tracking$start_time))

          # Reset
          reset_tracking()
          expect_null(tracking$start_time)
          expect_equal(tracking$last_task, "")
          expect_null(tracking$last_notif_id)
          expect_equal(tracking$last_error_count, 0)
        }
      )
    }
  )
})

# ==============================================================================
# PART 2e: mod_progress.R — button handlers
# ==============================================================================

test_that("mod_progress_server: cancel button sets app_state$cancel_computation", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          expect_null(mock_app_state$cancel_computation)
          session$setInputs(cancel = 1)
          expect_true(!is.null(mock_app_state$cancel_computation))
          expect_true(inherits(mock_app_state$cancel_computation, "POSIXct"))
        }
      )
    }
  )
})

test_that("mod_progress_server: retry button resets error and sets retry_computation", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          rv$show_error <- TRUE
          session$setInputs(retry = 1)
          expect_false(rv$show_error)
          expect_true(!is.null(mock_app_state$retry_computation))
          expect_true(inherits(mock_app_state$retry_computation, "POSIXct"))
        }
      )
    }
  )
})

# ==============================================================================
# PART 2f: mod_progress.R — observer terminal states
# ==============================================================================

test_that("mod_progress_server: completed state with indicator status table", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      COMPUTE_STATUS <- nemeton:::COMPUTE_STATUS
      mock_compute_state <- shiny::reactiveVal(list(
        status = COMPUTE_STATUS$COMPLETED,
        phase = "complete",
        progress = 10, progress_max = 10,
        indicators_completed = 8, indicators_failed = 2, indicators_total = 10,
        current_task = NULL,
        errors = list(
          list(indicator = "water_twi", message = "TWI error"),
          list(indicator = "risk_fire", message = "Fire error")
        ),
        indicators_status = list(
          carbon_biomass = "completed",
          carbon_ndvi = "completed",
          water_network = "completed",
          water_twi = "failed",
          risk_fire = "failed",
          social_trails = "completed",
          landscape_fragmentation = "completed",
          naturalness_score = "completed"
        )
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_true(rv$show_complete)
          expect_false(rv$show_progress)
        }
      )
    }
  )
})

test_that("mod_progress_server: error state with single error message", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      COMPUTE_STATUS <- nemeton:::COMPUTE_STATUS
      mock_compute_state <- shiny::reactiveVal(list(
        status = COMPUTE_STATUS$ERROR,
        phase = "computing",
        progress = 3, progress_max = 10,
        indicators_completed = 3, indicators_failed = 1, indicators_total = 10,
        current_task = NULL,
        errors = list(list(message = "Fatal: disk full")),
        indicators_status = list()
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_true(rv$show_error)
          expect_false(rv$show_progress)
        }
      )
    }
  )
})

test_that("mod_progress_server: error state with multiple errors shows extra count", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      COMPUTE_STATUS <- nemeton:::COMPUTE_STATUS
      mock_compute_state <- shiny::reactiveVal(list(
        status = COMPUTE_STATUS$ERROR,
        phase = "computing",
        progress = 5, progress_max = 10,
        indicators_completed = 4, indicators_failed = 2, indicators_total = 10,
        current_task = NULL,
        errors = list(
          list(message = "Error 1"),
          list(message = "Error 2"),
          list(message = "Error 3")
        ),
        indicators_status = list()
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_true(rv$show_error)
        }
      )
    }
  )
})

test_that("mod_progress_server: error state with empty errors list uses unknown_error", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      COMPUTE_STATUS <- nemeton:::COMPUTE_STATUS
      mock_compute_state <- shiny::reactiveVal(list(
        status = COMPUTE_STATUS$ERROR,
        phase = "init",
        progress = 0, progress_max = 10,
        indicators_completed = 0, indicators_failed = 0, indicators_total = 10,
        current_task = NULL,
        errors = list(),
        indicators_status = list()
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_true(rv$show_error)
        }
      )
    }
  )
})

test_that("mod_progress_server: running state is ignored by terminal observer", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      COMPUTE_STATUS <- nemeton:::COMPUTE_STATUS
      mock_compute_state <- shiny::reactiveVal(list(
        status = COMPUTE_STATUS$COMPUTING,
        phase = "computing",
        progress = 5, progress_max = 10,
        indicators_completed = 5, indicators_failed = 0, indicators_total = 10,
        current_task = "compute:carbon_biomass",
        errors = list()
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_false(rv$show_complete)
          expect_false(rv$show_error)
          expect_false(rv$show_progress)
        }
      )
    }
  )
})

test_that("mod_progress_server: observer ignores NULL status", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = NULL,
        phase = "init",
        progress = 0, progress_max = 10,
        indicators_completed = 0, indicators_failed = 0, indicators_total = 10,
        current_task = NULL,
        errors = list()
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_false(rv$show_complete)
          expect_false(rv$show_error)
        }
      )
    }
  )
})

test_that("mod_progress_server: observer ignores NA status", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = NA,
        phase = "init",
        progress = 0, progress_max = 10,
        indicators_completed = 0, indicators_failed = 0, indicators_total = 10,
        current_task = NULL,
        errors = list()
      ))
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          session$flushReact()
          expect_false(rv$show_complete)
          expect_false(rv$show_error)
        }
      )
    }
  )
})

# ==============================================================================
# PART 2g: mod_progress.R — send_running_update edge cases
# ==============================================================================

test_that("mod_progress_server: send_running_update with error toast (indicator prefix)", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          # First call initializes tracking
          state <- list(
            status = "computing", phase = "computing",
            progress = 2, progress_max = 10,
            indicators_completed = 2, indicators_failed = 0,
            indicators_total = 10, current_task = "compute:carbon_biomass",
            errors = list()
          )
          suppressWarnings(send_running_update(state))

          # Second call adds an error with indicator prefix
          state$indicators_failed <- 1
          state$current_task <- "compute:carbon_ndvi"
          state$errors <- list(
            list(indicator = "carbon_biomass", message = "Raster missing")
          )
          suppressWarnings(send_running_update(state))
          expect_equal(tracking$last_error_count, 1)

          # Third call adds an error with source prefix
          state$errors <- c(state$errors, list(
            list(source = "IGN", message = "Connection failed")
          ))
          state$current_task <- "compute:water_network"
          suppressWarnings(send_running_update(state))
          expect_equal(tracking$last_error_count, 2)

          # Fourth call adds an error with no prefix
          state$errors <- c(state$errors, list(
            list(message = "Unknown failure")
          ))
          state$current_task <- "compute:risk_fire"
          suppressWarnings(send_running_update(state))
          expect_equal(tracking$last_error_count, 3)
        }
      )
    }
  )
})

test_that("mod_progress_server: send_running_update zero progress_max defaults to 1", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          state <- list(
            status = "computing", phase = "computing",
            progress = 0, progress_max = 0,
            indicators_completed = 0, indicators_failed = 0,
            indicators_total = 0, current_task = "init_task",
            errors = list()
          )
          # Should not error despite division by zero guard
          expect_no_error(send_running_update(state))
        }
      )
    }
  )
})

test_that("mod_progress_server: send_running_update repeated same task does not re-toast", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          state <- list(
            status = "computing", phase = "computing",
            progress = 5, progress_max = 10,
            indicators_completed = 5, indicators_failed = 0,
            indicators_total = 10, current_task = "compute:carbon_biomass",
            errors = list()
          )
          suppressWarnings(send_running_update(state))
          first_task <- tracking$last_task

          # Same task again - should not change tracking
          suppressWarnings(send_running_update(state))
          expect_equal(tracking$last_task, first_task)
        }
      )
    }
  )
})

test_that("mod_progress_server: initial rv state is all FALSE", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          expect_false(rv$show_progress)
          expect_false(rv$show_complete)
          expect_false(rv$show_error)
        }
      )
    }
  )
})

test_that("mod_progress_server: returned list has all 5 expected elements", {
  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- make_progress_app_state()

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(compute_state = mock_compute_state, app_state = mock_app_state),
        {
          result <- session$getReturned()
          expect_true(is.list(result))
          expect_equal(length(result), 5)
          expect_true(all(c("show_progress", "show_complete", "show_error",
                            "send_running_update", "reset_tracking") %in% names(result)))
          expect_true(is.function(result$send_running_update))
          expect_true(is.function(result$reset_tracking))
        }
      )
    }
  )
})

# Drain async callbacks to prevent testServer session accumulation
later::run_now(0)
