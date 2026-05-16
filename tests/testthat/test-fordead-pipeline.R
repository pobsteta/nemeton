# test-fordead-pipeline.R — orchestrator run_fordead_dieback (spec 008 §12)
#
# All Python interaction is mocked. We never touch reticulate or a
# real virtualenv. The fake `fd` module records the call order so we
# can assert on the orchestration contract (4 phases by default,
# 5 phases when persisting).

skip_if_no_reticulate <- function() {
  testthat::skip_if_not_installed("reticulate")
}

skip_if_no_sf <- function() {
  testthat::skip_if_not_installed("sf")
}

make_aoi <- function(crs = 2154) {
  pol <- sf::st_polygon(list(matrix(
    c(0, 0,  100, 0,  100, 100,  0, 100,  0, 0),
    ncol = 2, byrow = TRUE
  )))
  sf::st_sf(geometry = sf::st_sfc(pol, crs = crs))
}

# A minimum scenes_df. Two scenes, both fall inside the training +
# monitoring windows used by the success-path tests.
make_scenes_df <- function() {
  data.frame(
    scene_id = c("S2A_FAKE_20160601", "S2A_FAKE_20180601"),
    obs_date = as.Date(c("2016-06-01", "2018-06-01")),
    stringsAsFactors = FALSE
  )
}

# A temporary cache_dir — the tests don't actually open the cached
# files (we mock .build_stac_collection_for_aoi) but the path is
# validated upstream by run_fordead_dieback.
make_cache_dir <- function() {
  d <- tempfile("fordead-test-cache-")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# Build a fake `fd` module recording the calls to fp$fit / fp$predict.
# Returns the fake `fd` plus the env that captures call order.
make_fake_fordead_2x_module <- function(fail_at = NULL) {
  env <- new.env(parent = emptyenv())
  env$calls <- character(0)

  fp_factory <- function(collection, output_dir, bbox, geometry, config, ...) {
    self <- new.env(parent = emptyenv())
    self$fit <- function() {
      env$calls <- c(env$calls, "fit")
      if (identical(fail_at, "fit")) stop("simulated FORDEAD error in fit")
      invisible(NULL)
    }
    self$predict <- function() {
      env$calls <- c(env$calls, "predict")
      if (identical(fail_at, "predict")) stop("simulated FORDEAD error in predict")
      invisible(NULL)
    }
    self
  }

  fd <- list(
    version  = "2.1.1",
    `__version__` = "2.1.1",
    workflow = list(FordeadProcess = fp_factory),
    utils    = list(backward_start = function(...) NULL)
  )
  list(fd = fd, env = env)
}

# Mock the helpers that touch Python / sf to keep tests offline and
# decoupled from the real reticulate-bound path. Returns a list of
# bindings ready to be slipped into a `local_mocked_bindings` block.
.mock_pipeline_helpers <- function(fake_class_raster = NULL,
                                   alerts_sf         = NULL,
                                   fail_postprocess  = FALSE) {
  list(
    .build_stac_collection_for_aoi = function(...) {
      list(`__class__` = "ItemCollection", n = 2L)
    },
    .build_fordead_config = function(...) {
      list(`__class__` = "FordeadConfig")
    },
    .aoi_bbox_4326 = function(...) c(0.0, 45.0, 1.0, 46.0),
    .aoi_geometry_reticulate = function(...) {
      list(`__class__` = "shapely.geometry.Polygon")
    },
    .fordead_2x_status_to_classes = function(...) fake_class_raster,
    .compute_first_dieback_date    = function(...) NULL,
    .latest_layer_file = function(output_dir, layer) NA_character_,
    .ensure_fordead_python = function(env_name = ".", verbose = FALSE) {
      stop("override per-test via the `fd` return value")
    },
    .postprocess_fordead_rasters = function(rasters, ...) {
      if (isTRUE(fail_postprocess)) {
        stop("simulated postprocess failure")
      }
      alerts_sf %||% structure(list(), class = "sf")
    }
  )
}

# %||% — null coalesce (rlang-free local copy)
`%||%` <- function(x, y) if (is.null(x)) y else x


# ---- argument validation ---------------------------------------------

test_that("rejects non-sf aoi", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(aoi = "not-sf",
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir()),
    "must be an sf"
  )
})

test_that("rejects aoi in wrong CRS", {
  skip_if_no_sf()
  aoi_4326 <- make_aoi(crs = 4326)
  expect_error(
    run_fordead_dieback(aoi_4326,
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir()),
    "EPSG:2154|Lambert"
  )
})

test_that("rejects unknown vegetation_index", {
  skip_if_no_sf()
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir(),
                        vegetation_index = "EVI"),
    "vegetation_index"
  )
})

test_that("rejects threshold_anomaly out of [0.05, 0.50]", {
  skip_if_no_sf()
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir(),
                        threshold_anomaly = 0.0),
    "threshold_anomaly"
  )
  expect_error(
    run_fordead_dieback(aoi,
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir(),
                        threshold_anomaly = 0.6),
    "threshold_anomaly"
  )
})

test_that("rejects non-chronological dates_training", {
  skip_if_no_sf()
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir(),
                        dates_training = c("2018-01-01", "2017-01-01")),
    "dates_training"
  )
})

test_that("rejects dates_monitoring starting before dates_training", {
  skip_if_no_sf()
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        scenes_df = make_scenes_df(),
                        cache_dir = make_cache_dir(),
                        dates_training   = c("2018-01-01", "2019-12-31"),
                        dates_monitoring = c("2017-06-01", "2024-01-01")),
    "dates_monitoring"
  )
})

test_that("rejects missing scenes_df", {
  skip_if_no_sf()
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi, cache_dir = make_cache_dir()),
    "scenes_df"
  )
})

test_that("rejects non-existent cache_dir", {
  skip_if_no_sf()
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        scenes_df = make_scenes_df(),
                        cache_dir = "/no/such/path"),
    "cache_dir"
  )
})


# ---- successful orchestration ----------------------------------------

test_that("runs the 4 phases in order on the success path", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(
    !!!helpers,
    .package = "nemeton"
  )

  aoi <- make_aoi()
  out <- run_fordead_dieback(
    aoi              = aoi,
    scenes_df        = make_scenes_df(),
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "success")
  expect_equal(fk$env$calls, c("fit", "predict"))
  expect_identical(out$fordead_version, "2.1.1")
  expect_null(out$alerts_sf)  # empty sf returned by mocked postprocess
})


test_that("propagates Python errors as status='error' with message", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module(fail_at = "fit")
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    aoi              = make_aoi(),
    scenes_df        = make_scenes_df(),
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "error")
  expect_true(grepl("simulated FORDEAD error in fit", out$message, fixed = TRUE))
  expect_equal(fk$env$calls, "fit")  # predict never ran
})


# ---- progress_callback wiring ----------------------------------------

test_that("progress_callback receives ordered phase events (no persist)", {
  skip_if_no_reticulate(); skip_if_no_sf()

  events <- list()
  cb <- function(payload) {
    events[[length(events) + 1L]] <<- payload
    invisible(NULL)
  }

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    aoi              = make_aoi(),
    scenes_df        = make_scenes_df(),
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE,
    progress_callback = cb
  )

  expect_identical(out$status, "success")

  phase_starts <- vapply(events, function(e) e$current %||% NA_character_, character(1))
  phase_names  <- vapply(events,
                         function(e) e$phase_name %||% NA_character_,
                         character(1))

  # `fordead:start` first, then alternating phase / phase_done, then complete.
  expect_identical(phase_starts[1L], "fordead:start")
  expect_identical(phase_starts[length(phase_starts)], "fordead:complete")
  # 4 phases × 2 events each + start + complete = 10 events
  expect_equal(length(events), 4L * 2L + 2L)

  # Phase names in `:phase` events, in order:
  begin_idx <- phase_starts == "fordead:phase"
  expect_equal(phase_names[begin_idx],
               c("stac_assembly", "fit", "predict", "postprocess"))

  # Each phase emits one `:phase` and one `:phase_done`.
  expect_equal(sum(phase_starts == "fordead:phase"),      4L)
  expect_equal(sum(phase_starts == "fordead:phase_done"), 4L)

  # `total` is consistent throughout.
  totals <- vapply(events, function(e) e$total %||% NA_integer_, integer(1))
  expect_true(all(totals[!is.na(totals)] == 4L))
})


test_that("progress_callback schedules a 'persist' phase with con/zone_id", {
  skip_if_no_reticulate(); skip_if_no_sf()

  events <- list()
  cb <- function(payload) {
    events[[length(events) + 1L]] <<- payload
    invisible(NULL)
  }

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  helpers$.postprocess_fordead_rasters <- function(...) {
    # Return a non-empty sf POINT so persist actually runs.
    sf::st_sf(
      confidence_class = "3-forte",
      geometry = sf::st_sfc(sf::st_point(c(1, 1)), crs = 2154)
    )
  }
  helpers$.insert_fordead_alerts <- function(con, alerts_sf, zone_id, ...) {
    7L
  }

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  fake_con <- structure(list(), class = c("FakeConnection", "DBIConnection"))
  out <- run_fordead_dieback(
    aoi              = make_aoi(),
    scenes_df        = make_scenes_df(),
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    con              = fake_con,
    zone_id          = 42L,
    verbose          = FALSE,
    progress_callback = cb
  )

  expect_identical(out$status, "success")
  expect_equal(out$n_alerts_inserted, 7L)

  phase_starts <- vapply(events, function(e) e$current %||% NA_character_, character(1))
  phase_names  <- vapply(events,
                         function(e) e$phase_name %||% NA_character_,
                         character(1))
  begin_idx <- phase_starts == "fordead:phase"
  expect_equal(phase_names[begin_idx],
               c("stac_assembly", "fit", "predict", "postprocess", "persist"))

  totals <- vapply(events, function(e) e$total %||% NA_integer_, integer(1))
  expect_true(all(totals[!is.na(totals)] == 5L))
})


test_that("progress_callback receives a 'fordead:error' event on failure", {
  skip_if_no_reticulate(); skip_if_no_sf()

  events <- list()
  cb <- function(payload) {
    events[[length(events) + 1L]] <<- payload
    invisible(NULL)
  }

  fk <- make_fake_fordead_2x_module(fail_at = "predict")
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    aoi              = make_aoi(),
    scenes_df        = make_scenes_df(),
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE,
    progress_callback = cb
  )

  expect_identical(out$status, "error")

  err_event <- Filter(
    function(e) identical(e$current, "fordead:error"),
    events
  )
  expect_length(err_event, 1L)
  expect_identical(err_event[[1L]]$phase_name, "predict")
  expect_true(nzchar(err_event[[1L]]$error_message))
})


test_that("a buggy progress_callback does not abort the pipeline", {
  skip_if_no_reticulate(); skip_if_no_sf()

  buggy_cb <- function(payload) {
    if (identical(payload$current, "fordead:phase") &&
        identical(payload$phase_name, "fit")) {
      stop("intentional callback failure")
    }
  }

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- expect_silent(
    suppressMessages(
      run_fordead_dieback(
        aoi              = make_aoi(),
        scenes_df        = make_scenes_df(),
        cache_dir        = make_cache_dir(),
        dates_training   = c("2016-01-01", "2017-12-31"),
        dates_monitoring = c("2018-01-01", "2018-12-31"),
        verbose          = FALSE,
        progress_callback = buggy_cb
      )
    )
  )
  expect_identical(out$status, "success")
})


# ---- empty-result shape ----------------------------------------------

test_that(".empty_fordead_result has the documented shape", {
  res <- nemeton:::.empty_fordead_result(
    output_dir = "/tmp/x", python_env = "env",
    status = "error", duration_sec = 1.5, message = "oops"
  )
  expect_named(
    res,
    c("status", "message", "output_dir", "rasters", "alerts_sf",
      "n_alerts_inserted", "duration_sec", "python_env", "fordead_version"),
    ignore.order = TRUE
  )
  expect_identical(res$status, "error")
  expect_identical(res$message, "oops")
})
