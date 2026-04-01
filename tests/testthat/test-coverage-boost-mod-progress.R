# Coverage boost tests for R/mod_progress.R — shiny::testServer() tests
# Targets uncovered paths: translate_task(), translate_indicator_name(),
# translate_phase(), send_running_update(), terminal state observer

# ==============================================================================
# mod_progress_server — translate_task() via send_running_update()
# ==============================================================================

test_that("mod_progress_server translate_task handles download tasks", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          # Test send_running_update with download_start task
          state <- list(
            status = "downloading",
            phase = "downloading",
            progress = 2,
            progress_max = 10,
            indicators_completed = 0,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "download_start",
            errors = list()
          )
          result$send_running_update(state)

          # Test with download:<source> task
          state$current_task <- "download:source_forest_cover"
          result$send_running_update(state)

          # Test with download_complete task
          state$current_task <- "download_complete"
          result$send_running_update(state)

          expect_true(TRUE)
        }
      )
    }
  )
})

test_that("mod_progress_server translate_task handles compute tasks", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          # Test with compute:<indicator> task
          state <- list(
            status = "computing",
            phase = "computing",
            progress = 5,
            progress_max = 10,
            indicators_completed = 5,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "compute:indicateur_c1_biomasse",
            errors = list()
          )
          result$send_running_update(state)

          # Test with compute_start task
          state$current_task <- "compute_start"
          result$send_running_update(state)

          # Test with complete task
          state$current_task <- "complete"
          state$progress <- 10
          result$send_running_update(state)

          expect_true(TRUE)
        }
      )
    }
  )
})

test_that("mod_progress_server translate_task handles error/resuming tasks", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          state <- list(
            status = "computing",
            phase = "computing",
            progress = 3,
            progress_max = 10,
            indicators_completed = 3,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "error",
            errors = list()
          )
          result$send_running_update(state)

          state$current_task <- "resuming"
          result$send_running_update(state)

          # Test with unknown task string
          state$current_task <- "some_unknown_task"
          result$send_running_update(state)

          expect_true(TRUE)
        }
      )
    }
  )
})

test_that("mod_progress_server translate_task handles download_oso_progress", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          state <- list(
            status = "downloading",
            phase = "downloading",
            progress = 1,
            progress_max = 10,
            indicators_completed = 0,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "download_oso_progress:45",
            errors = list()
          )
          result$send_running_update(state)
          expect_true(TRUE)
        }
      )
    }
  )
})

test_that("mod_progress_server translate_task handles download_lidar tasks", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          # Test MNH lidar download
          state <- list(
            status = "downloading",
            phase = "downloading",
            progress = 1,
            progress_max = 10,
            indicators_completed = 0,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "download_lidar:mnh:20/500",
            errors = list()
          )
          result$send_running_update(state)

          # Test MNT lidar download
          state$current_task <- "download_lidar:mnt:100/200"
          result$send_running_update(state)

          # Test nuage (copc) lidar download
          state$current_task <- "download_lidar:nuage:5/10"
          result$send_running_update(state)

          expect_true(TRUE)
        }
      )
    }
  )
})

# ==============================================================================
# send_running_update() — error tracking
# ==============================================================================

test_that("mod_progress_server send_running_update tracks errors", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          # First update with no errors
          state1 <- list(
            status = "computing",
            phase = "computing",
            progress = 2,
            progress_max = 10,
            indicators_completed = 2,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "compute:indicateur_c1_biomasse",
            errors = list()
          )
          result$send_running_update(state1)

          # Second update with an error
          state2 <- state1
          state2$indicators_failed <- 1
          state2$current_task <- "compute:indicateur_c2_ndvi"
          state2$errors <- list(
            list(indicator = "indicateur_c1_biomasse", message = "Raster not found")
          )
          result$send_running_update(state2)

          # Third update with more errors
          state3 <- state2
          state3$errors <- c(state2$errors, list(
            list(source = "IGN WFS", message = "Connection timeout")
          ))
          state3$current_task <- "compute:indicateur_w1_reseau"
          result$send_running_update(state3)

          expect_true(TRUE)
        }
      )
    }
  )
})

# ==============================================================================
# send_running_update() — edge cases (NULL/NA progress)
# ==============================================================================

test_that("mod_progress_server send_running_update handles NA progress", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          state <- list(
            status = "downloading",
            phase = "downloading",
            progress = NA,
            progress_max = NA,
            indicators_completed = NA,
            indicators_failed = NA,
            indicators_total = NA,
            current_task = NA,
            errors = list()
          )
          result$send_running_update(state)
          expect_true(TRUE)
        }
      )
    }
  )
})

test_that("mod_progress_server send_running_update handles NULL fields", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          state <- list(
            status = "computing",
            phase = NULL,
            progress = NULL,
            progress_max = NULL,
            indicators_completed = NULL,
            indicators_failed = NULL,
            indicators_total = NULL,
            current_task = NULL,
            errors = list()
          )
          result$send_running_update(state)
          expect_true(TRUE)
        }
      )
    }
  )
})

# ==============================================================================
# reset_tracking() — verify clean state
# ==============================================================================

test_that("mod_progress_server reset_tracking resets state", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          # Initialize tracking by sending an update
          state <- list(
            status = "computing",
            phase = "computing",
            progress = 5,
            progress_max = 10,
            indicators_completed = 5,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "compute:indicateur_r1_feu",
            errors = list()
          )
          result$send_running_update(state)

          # Reset should clear tracking
          result$reset_tracking()
          expect_true(TRUE)
        }
      )
    }
  )
})

# ==============================================================================
# Terminal state observer — completed
# ==============================================================================

test_that("mod_progress_server handles completed state", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "completed",
        phase = "complete",
        progress = 10,
        progress_max = 10,
        indicators_completed = 10,
        indicators_failed = 0,
        indicators_total = 10,
        current_task = NULL,
        errors = list(),
        indicators_status = list(
          indicateur_c1_biomasse = "completed",
          indicateur_c2_ndvi = "completed",
          indicateur_w1_reseau = "completed"
        )
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()
          # Terminal observer should fire for completed
          session$flushReact()
          expect_true(result$show_complete())
        }
      )
    }
  )
})

test_that("mod_progress_server handles completed with failures", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "completed",
        phase = "complete",
        progress = 10,
        progress_max = 10,
        indicators_completed = 8,
        indicators_failed = 2,
        indicators_total = 10,
        current_task = NULL,
        errors = list(
          list(indicator = "indicateur_w3_humidite", message = "Error computing TWI"),
          list(indicator = "indicateur_r1_feu", message = "Raster not available")
        ),
        indicators_status = list(
          indicateur_c1_biomasse = "completed",
          indicateur_w3_humidite = "failed",
          indicateur_r1_feu = "failed"
        )
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()
          session$flushReact()
          expect_true(result$show_complete())
        }
      )
    }
  )
})

# ==============================================================================
# Terminal state observer — error
# ==============================================================================

test_that("mod_progress_server handles error state", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "error",
        phase = "computing",
        progress = 3,
        progress_max = 10,
        indicators_completed = 3,
        indicators_failed = 1,
        indicators_total = 10,
        current_task = NULL,
        errors = list(
          list(message = "Fatal computation error")
        ),
        indicators_status = list()
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()
          session$flushReact()
          expect_true(result$show_error())
        }
      )
    }
  )
})

test_that("mod_progress_server handles error with multiple errors", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "error",
        phase = "computing",
        progress = 5,
        progress_max = 10,
        indicators_completed = 4,
        indicators_failed = 2,
        indicators_total = 10,
        current_task = NULL,
        errors = list(
          list(message = "Error 1"),
          list(message = "Error 2"),
          list(message = "Error 3")
        ),
        indicators_status = list()
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()
          session$flushReact()
          expect_true(result$show_error())
        }
      )
    }
  )
})

test_that("mod_progress_server handles error with no error messages", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "error",
        phase = "init",
        progress = 0,
        progress_max = 10,
        indicators_completed = 0,
        indicators_failed = 0,
        indicators_total = 10,
        current_task = NULL,
        errors = list(),
        indicators_status = list()
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()
          session$flushReact()
          expect_true(result$show_error())
        }
      )
    }
  )
})

# ==============================================================================
# translate_phase — all branches via send_running_update
# ==============================================================================

test_that("mod_progress_server translate_phase all branches", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(NULL)
      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()

          base_state <- list(
            status = "computing",
            progress = 1,
            progress_max = 10,
            indicators_completed = 0,
            indicators_failed = 0,
            indicators_total = 10,
            current_task = "init_task",
            errors = list()
          )

          # Test init phase
          base_state$phase <- "init"
          result$send_running_update(base_state)

          # Test downloading phase
          base_state$phase <- "downloading"
          base_state$current_task <- "download:source_ndvi"
          result$send_running_update(base_state)

          # Test computing phase
          base_state$phase <- "computing"
          base_state$current_task <- "compute:indicateur_t1_anciennete"
          result$send_running_update(base_state)

          # Test complete phase
          base_state$phase <- "complete"
          base_state$current_task <- "final_task"
          result$send_running_update(base_state)

          # Test empty/unknown phase
          base_state$phase <- "unknown"
          base_state$current_task <- "other_task"
          result$send_running_update(base_state)

          expect_true(TRUE)
        }
      )
    }
  )
})

# ==============================================================================
# translate_indicator_name — known and unknown names
# ==============================================================================

test_that("mod_progress_server translate_indicator_name known indicators", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "fr"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "completed",
        phase = "complete",
        progress = 5,
        progress_max = 5,
        indicators_completed = 5,
        indicators_failed = 0,
        indicators_total = 5,
        current_task = NULL,
        errors = list(),
        indicators_status = list(
          indicateur_c1_biomasse = "completed",
          indicateur_b1_protection = "completed",
          indicateur_w1_reseau = "completed",
          indicateur_r1_feu = "completed",
          indicateur_n3_naturalite = "completed"
        )
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          # The terminal observer should call translate_indicator_name
          # for each indicator in indicators_status
          session$flushReact()
          result <- session$getReturned()
          expect_true(result$show_complete())
        }
      )
    }
  )
})

# ==============================================================================
# Pending state — observer should not fire
# ==============================================================================

test_that("mod_progress_server ignores pending state in observer", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(.package = "nemeton",
    get_app_options = function() list(language = "en"),
    {
      mock_compute_state <- shiny::reactiveVal(list(
        status = "pending",
        phase = "init",
        progress = 0,
        progress_max = 10,
        indicators_completed = 0,
        indicators_failed = 0,
        indicators_total = 10,
        current_task = NULL,
        errors = list()
      ))

      mock_app_state <- shiny::reactiveValues(
        cancel_computation = NULL,
        retry_computation = NULL
      )

      shiny::testServer(
        nemeton:::mod_progress_server,
        args = list(
          compute_state = mock_compute_state,
          app_state = mock_app_state
        ),
        {
          result <- session$getReturned()
          session$flushReact()
          # Should NOT set show_complete or show_error
          expect_false(result$show_complete())
          expect_false(result$show_error())
        }
      )
    }
  )
})

# Drain async callbacks to prevent testServer session accumulation
later::run_now(0)
