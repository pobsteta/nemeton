# test-fordead-pipeline.R — orchestrator run_fordead_dieback (spec 008 §13)
#
# All Python interaction is mocked. We never touch reticulate or a
# real virtualenv. The fake `fd` module records the call order so we
# can assert on the orchestration contract (6 phases since v0.24.0:
# ingest, stac_assembly, fit, predict, postprocess, persist).

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

# A minimum scenes_df returned by mocked ingest_s2_raw_bands_to_cache.
make_scenes_df <- function() {
  data.frame(
    scene_id  = c("S2A_FAKE_20160601", "S2A_FAKE_20180601"),
    obs_date  = as.Date(c("2016-06-01", "2018-06-01")),
    cloud_pct = c(5, 10),
    source    = c("pc", "pc"),
    stringsAsFactors = FALSE
  )
}

make_cache_dir <- function() {
  d <- tempfile("fordead-test-cache-")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

make_fake_con <- function() {
  structure(list(), class = c("FakeConnection", "DBIConnection"))
}

# Build a fake `fd` module recording the calls to fp$fit / fp$predict.
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
    version       = "2.1.1",
    `__version__` = "2.1.1",
    workflow      = list(FordeadProcess = fp_factory),
    utils         = list(backward_start = function(...) NULL)
  )
  list(fd = fd, env = env)
}

# Common helper mocks. We mock at the package level so the pipeline
# resolves them through the standard local_mocked_bindings mechanism.
.mock_pipeline_helpers <- function(fake_class_raster = NULL,
                                   alerts_sf         = NULL,
                                   fail_postprocess  = FALSE,
                                   ingest_extra_emits = NULL,
                                   ingest_scenes     = NULL,
                                   ingest_throws     = NULL) {
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
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    ingest_s2_raw_bands_to_cache = function(con, zone_id, bands,
                                            start, end, cache_dir,
                                            max_cloud = 20,
                                            progress_callback = NULL) {
      if (!is.null(ingest_throws)) stop(ingest_throws)
      if (!is.null(ingest_extra_emits) && !is.null(progress_callback)) {
        for (e in ingest_extra_emits) progress_callback(e)
      }
      list(scenes_df = ingest_scenes %||% make_scenes_df(),
           n_scenes = 2L, n_bands_fetched = 0L,
           n_bands_cached = 12L, n_scenes_skipped = 0L)
    },
    .fordead_2x_status_to_classes = function(...) fake_class_raster,
    .compute_first_dieback_date    = function(...) NULL,
    .latest_layer_file = function(output_dir, layer) NA_character_,
    .ensure_fordead_python = function(env_name = ".", verbose = FALSE) {
      stop("override per-test via the `fd` return value")
    },
    .fordead_python_version = function(env_name) "2.1.1",
    .postprocess_fordead_rasters = function(rasters, ...) {
      if (isTRUE(fail_postprocess)) {
        stop("simulated postprocess failure")
      }
      if (!is.null(alerts_sf)) return(alerts_sf)
      sf::st_sf(
        data.frame(stringsAsFactors = FALSE),
        geometry = sf::st_sfc(crs = 2154)
      )
    },
    .insert_fordead_alerts = function(con, alerts_sf, zone_id, ...) 0L,
    .write_fordead_model_bundle = function(output_dir, model_dir, ...) {
      dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
      invisible(model_dir)
    }
  )
}

# %||% — null coalesce (rlang-free local copy)
`%||%` <- function(x, y) if (is.null(x)) y else x


# ---- argument validation ---------------------------------------------

test_that("rejects non-DBI con", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = "not-con", zone_id = 1L,
                        cache_dir = make_cache_dir()),
    "DBIConnection"
  )
})

test_that("rejects NA zone_id", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = NA_integer_,
                        cache_dir = make_cache_dir()),
    "zone_id"
  )
})

test_that("rejects multi-value zone_id", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = c(1L, 2L),
                        cache_dir = make_cache_dir()),
    "zone_id"
  )
})

test_that("rejects empty cache_dir", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = 1L,
                        cache_dir = ""),
    "cache_dir"
  )
})

test_that("rejects unknown vegetation_index", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = 1L,
                        cache_dir = make_cache_dir(),
                        vegetation_index = "EVI"),
    "vegetation_index"
  )
})

test_that("rejects threshold_anomaly out of [0.05, 0.50]", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = 1L,
                        cache_dir = make_cache_dir(),
                        threshold_anomaly = 0.0),
    "threshold_anomaly"
  )
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = 1L,
                        cache_dir = make_cache_dir(),
                        threshold_anomaly = 0.6),
    "threshold_anomaly"
  )
})

test_that("rejects non-chronological dates_training", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = 1L,
                        cache_dir = make_cache_dir(),
                        dates_training = c("2018-01-01", "2017-01-01")),
    "dates_training"
  )
})

test_that("rejects dates_monitoring starting before dates_training", {
  skip_if_no_sf()
  expect_error(
    run_fordead_dieback(con = make_fake_con(), zone_id = 1L,
                        cache_dir = make_cache_dir(),
                        dates_training   = c("2018-01-01", "2019-12-31"),
                        dates_monitoring = c("2017-06-01", "2024-01-01")),
    "dates_monitoring"
  )
})


# ---- successful orchestration ----------------------------------------

test_that("runs the 6 phases in order on the success path", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 1L,
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "success")
  expect_equal(fk$env$calls, c("fit", "predict"))
  # fordead_version is read via .fordead_python_version() (mocked in
  # .mock_pipeline_helpers() to the pinned "2.1.1").
  expect_identical(out$fordead_version, "2.1.1")
  expect_null(out$alerts_sf)
  expect_identical(out$zone_id, 1L)
  expect_equal(out$n_scenes, 2L)
  # Persist phase wires the diagnostic bundle dir into the result
  # (spec 008 §14.6 — model_<run_id>/ under zone_<id>/).
  expect_match(out$rasters$model_dir, "model_[0-9]{8}T[0-9]{6}$")
})


# ---- cooperative cancellation ----------------------------------------

test_that("cooperative cancel stops the run after fit, before predict", {
  skip_if_no_reticulate(); skip_if_no_sf()

  flag <- withr::local_tempfile(fileext = ".flag")

  # The fake fit() drops the cancel flag — mimicking the app writing it
  # while the (long) training phase runs. The post-fit checkpoint then
  # aborts the pipeline before predict() is ever called.
  fk  <- make_fake_fordead_2x_module()
  orig_fp_factory <- fk$fd$workflow$FordeadProcess
  fk$fd$workflow$FordeadProcess <- function(...) {
    self <- orig_fp_factory(...)
    base_fit <- self$fit
    self$fit <- function() {
      base_fit()
      file.create(flag)   # cancel requested during training
      invisible(NULL)
    }
    self
  }

  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  events <- list()
  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 1L,
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE,
    cancel_path      = flag,
    progress_callback = function(ev) events[[length(events) + 1L]] <<- ev
  )

  expect_identical(out$status, "cancelled")
  expect_identical(out$phase, "fit")
  # predict() must never have run.
  expect_equal(fk$env$calls, "fit")
  expect_equal(out$n_scenes, 2L)        # scenes_df from the mocked ingest
  expect_equal(out$n_alerts_inserted, 0L)
  # The cancellation event was emitted.
  currents <- vapply(events,
                     function(e) if (is.null(e$current)) "" else e$current,
                     character(1))
  expect_true("fordead:cancelled" %in% currents)
})

test_that("a stale cancel flag at entry is ignored; the FORDEAD run completes", {
  skip_if_no_reticulate(); skip_if_no_sf()

  flag <- withr::local_tempfile(fileext = ".flag")
  file.create(flag)   # leftover the caller forgot to clear

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  expect_warning(
    out <- run_fordead_dieback(
      con              = make_fake_con(),
      zone_id          = 1L,
      cache_dir        = make_cache_dir(),
      dates_training   = c("2016-01-01", "2017-12-31"),
      dates_monitoring = c("2018-01-01", "2018-12-31"),
      verbose          = FALSE,
      cancel_path      = flag),
    "already present at entry")
  expect_identical(out$status, "success")
  expect_equal(fk$env$calls, c("fit", "predict"))
})


test_that("model bundle persist is best-effort: a failure warns, run succeeds", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  # Simulate an unwritable model_dir / missing fit artefact.
  helpers$.write_fordead_model_bundle <- function(...) {
    stop("simulated bundle write failure")
  }
  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  # The failure is surfaced via cli::cli_alert_warning (not an R
  # warning condition — project-wide convention); capture cli output.
  out  <- NULL
  msgs <- cli::cli_fmt(
    out <- run_fordead_dieback(
      con              = make_fake_con(),
      zone_id          = 1L,
      cache_dir        = make_cache_dir(),
      dates_training   = c("2016-01-01", "2017-12-31"),
      dates_monitoring = c("2018-01-01", "2018-12-31"),
      verbose          = TRUE
    ),
    collapse = TRUE
  )
  # AC.14.5 — the run still completes successfully; model_dir is NA;
  # the best-effort failure is reported.
  expect_identical(out$status, "success")
  expect_true(is.na(out$rasters$model_dir))
  expect_match(msgs, "model bundle persist failed")
})


test_that("persist phase writes the categorical dieback mask to mask_cache_dir", {
  skip_if_no_reticulate(); skip_if_no_sf()
  skip_if_not_installed("terra")

  class_r <- terra::rast(nrows = 4, ncols = 4,
                         xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                         crs = "EPSG:2154")
  terra::values(class_r) <- as.integer(c(0, 1, 2, 3,
                                         0, 0, 1, 4,
                                         rep(0, 8)))
  names(class_r) <- "fordead_class"

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers(fake_class_raster = class_r)
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  mask_dir <- tempfile("fordead-mask-")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 7L,
    cache_dir        = make_cache_dir(),
    mask_cache_dir   = mask_dir,
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "success")
  mask_path <- out$rasters$dieback_mask
  expect_false(is.na(mask_path))
  expect_true(file.exists(mask_path))
  # Convention: <mask_cache_dir>/zone_<id>/dieback_mask_<YYYYMMDDTHHMMSS>.tif
  expect_match(mask_path,
               file.path("zone_7",
                         "dieback_mask_[0-9]{8}T[0-9]{6}\\.tif$"))
  # The persisted mask is exactly what read_fordead_dieback_mask() picks up.
  rr <- read_fordead_dieback_mask(con = NULL, zone_id = 7L,
                                  cache_dir = mask_dir)
  expect_s4_class(rr, "SpatRaster")
  vals <- terra::values(rr)
  expect_equal(sort(unique(vals[!is.na(vals)])), c(0, 1, 2, 3, 4))
})

test_that("mask_cache_dir defaults to the 'fordead' sibling of cache_dir", {
  skip_if_no_reticulate(); skip_if_no_sf()
  skip_if_not_installed("terra")

  class_r <- terra::rast(nrows = 2, ncols = 2,
                         xmin = 0, xmax = 20, ymin = 0, ymax = 20,
                         crs = "EPSG:2154")
  terra::values(class_r) <- as.integer(c(0, 1, 2, 0))
  names(class_r) <- "fordead_class"

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers(fake_class_raster = class_r)
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  # cache_dir = <root>/layers/sentinel2 → sibling = <root>/layers/fordead
  root      <- tempfile("proj-")
  cache_dir <- file.path(root, "layers", "sentinel2")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 1L,
    cache_dir        = cache_dir,
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "success")
  expect_true(startsWith(out$rasters$dieback_mask,
                         file.path(root, "layers", "fordead")))
})

test_that("keep_output = TRUE runs FORDEAD inside the project cache", {
  skip_if_no_reticulate(); skip_if_no_sf()
  skip_if_not_installed("terra")

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  mask_dir <- tempfile("fordead-mask-")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 3L,
    cache_dir        = make_cache_dir(),
    mask_cache_dir   = mask_dir,
    keep_output      = TRUE,
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "success")
  # output_dir redirected under <mask_cache_dir>/zone_<id>/run_<ts>/
  expect_match(out$output_dir,
               file.path("zone_3", "run_[0-9]{8}T[0-9]{6}$"))
  expect_true(dir.exists(out$output_dir))
})

test_that("propagates Python errors as status='error' with message", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module(fail_at = "fit")
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 1L,
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "error")
  expect_true(grepl("simulated FORDEAD error in fit", out$message, fixed = TRUE))
  expect_equal(fk$env$calls, "fit")
  expect_identical(out$zone_id, 1L)
})


test_that("aborts when no scene falls in the training window (v0.25.7)", {
  skip_if_no_reticulate(); skip_if_no_sf()

  # Scenes only in 2025-2026, default training window is 2016-2017.
  late_scenes <- data.frame(
    scene_id  = c("S2A_F_20250403", "S2A_F_20260408"),
    obs_date  = as.Date(c("2025-04-03", "2026-04-08")),
    cloud_pct = c(5, 5),
    source    = c("pc", "pc"),
    stringsAsFactors = FALSE
  )
  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers(ingest_scenes = late_scenes)
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 1L,
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2026-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "error")
  expect_true(grepl("training", out$message))
  # fordead's fit() must NOT have been called.
  expect_length(fk$env$calls, 0L)
})


test_that("aborts when no scene falls in the monitoring window (v0.25.7)", {
  skip_if_no_reticulate(); skip_if_no_sf()

  # Scenes only in 2016, default monitoring window starts 2018.
  early_scenes <- data.frame(
    scene_id  = c("S2A_F_20160601", "S2A_F_20161015"),
    obs_date  = as.Date(c("2016-06-01", "2016-10-15")),
    cloud_pct = c(5, 5),
    source    = c("pc", "pc"),
    stringsAsFactors = FALSE
  )
  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers(ingest_scenes = early_scenes)
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 1L,
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2026-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "error")
  expect_true(grepl("monitoring", out$message))
  expect_length(fk$env$calls, 0L)
})


test_that("aborts when ingest returns 0 scenes", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers(ingest_scenes = data.frame(
    scene_id = character(0), obs_date = as.Date(character(0)),
    cloud_pct = numeric(0), source = character(0)
  ))
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con       = make_fake_con(),
    zone_id   = 1L,
    cache_dir = make_cache_dir(),
    verbose   = FALSE
  )

  expect_identical(out$status, "error")
  expect_true(grepl("No Sentinel-2 scene", out$message))
  expect_length(fk$env$calls, 0L)
})


# ---- progress_callback wiring ----------------------------------------

test_that("progress_callback receives ordered fordead:* events for all 6 phases", {
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
    con              = make_fake_con(),
    zone_id          = 1L,
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

  expect_identical(phase_starts[1L], "fordead:start")
  expect_identical(phase_starts[length(phase_starts)], "fordead:complete")
  # 6 phases × 2 events each + start + complete = 14 events
  expect_equal(length(events), 6L * 2L + 2L)

  begin_idx <- phase_starts == "fordead:phase"
  expect_equal(
    phase_names[begin_idx],
    c("ingest", "stac_assembly", "fit", "predict", "postprocess", "persist")
  )

  expect_equal(sum(phase_starts == "fordead:phase"),      6L)
  expect_equal(sum(phase_starts == "fordead:phase_done"), 6L)

  totals <- vapply(events, function(e) e$total %||% NA_integer_, integer(1))
  expect_true(all(totals[!is.na(totals)] == 6L))
})


test_that("ingest phase propagates s2:* events verbatim to the user callback", {
  skip_if_no_reticulate(); skip_if_no_sf()

  events <- list()
  cb <- function(payload) {
    events[[length(events) + 1L]] <<- payload
    invisible(NULL)
  }

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers(ingest_extra_emits = list(
    list(current = "s2:search",     n_plots = 5L),
    list(current = "s2:scene",      completed = 0L, total = 2L,
         scene_id = "X1", band = "B02"),
    list(current = "s2:band_cached", scene_id = "X1", band = "B02"),
    list(current = "s2:complete",   completed = 2L, total = 2L)
  ))
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con      = make_fake_con(),
    zone_id  = 1L,
    cache_dir = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose  = FALSE,
    progress_callback = cb
  )

  expect_identical(out$status, "success")

  s2_events <- vapply(events, function(e) e$current %||% NA_character_,
                       character(1))
  s2_only   <- grepl("^s2:", s2_events)
  expect_true(any(s2_only))
  expect_equal(sum(s2_only), 4L)
  # The four s2:* events should land between fordead:phase(ingest) and
  # fordead:phase_done(ingest) — i.e. inside the ingest window.
  fordead_phase_idx <- which(s2_events == "fordead:phase")
  ingest_begin <- fordead_phase_idx[1L]
  fordead_done_idx <- which(s2_events == "fordead:phase_done")
  ingest_end <- fordead_done_idx[1L]
  expect_true(all(which(s2_only) > ingest_begin & which(s2_only) < ingest_end))
})


test_that("persist phase runs always (con/zone_id required)", {
  skip_if_no_reticulate(); skip_if_no_sf()

  fk <- make_fake_fordead_2x_module()
  helpers <- .mock_pipeline_helpers()
  helpers$.ensure_fordead_python <- function(env_name = "x", verbose = FALSE) fk$fd
  helpers$.postprocess_fordead_rasters <- function(...) {
    sf::st_sf(
      confidence_class = "3-forte",
      geometry = sf::st_sfc(sf::st_point(c(1, 1)), crs = 2154)
    )
  }
  helpers$.insert_fordead_alerts <- function(con, alerts_sf, zone_id, ...) {
    7L
  }

  testthat::local_mocked_bindings(!!!helpers, .package = "nemeton")

  out <- run_fordead_dieback(
    con              = make_fake_con(),
    zone_id          = 42L,
    cache_dir        = make_cache_dir(),
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", "2018-12-31"),
    verbose          = FALSE
  )

  expect_identical(out$status, "success")
  expect_equal(out$n_alerts_inserted, 7L)
  expect_identical(out$zone_id, 42L)
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
    con              = make_fake_con(),
    zone_id          = 1L,
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

  out <- suppressMessages(
    run_fordead_dieback(
      con              = make_fake_con(),
      zone_id          = 1L,
      cache_dir        = make_cache_dir(),
      dates_training   = c("2016-01-01", "2017-12-31"),
      dates_monitoring = c("2018-01-01", "2018-12-31"),
      verbose          = FALSE,
      progress_callback = buggy_cb
    )
  )
  expect_identical(out$status, "success")
})


# ---- FORDEAD_BANDS constant ------------------------------------------

test_that("FORDEAD_BANDS lists the six bands required by CRSWIR + masks", {
  expect_type(FORDEAD_BANDS, "character")
  expect_length(FORDEAD_BANDS, 6L)
  expect_setequal(FORDEAD_BANDS,
                  c("B02", "B04", "B05", "B8A", "B11", "B12"))
})


# ---- empty-result shape ----------------------------------------------

test_that(".empty_fordead_result has the documented shape", {
  res <- nemeton:::.empty_fordead_result(
    output_dir = "/tmp/x", python_env = "env",
    status = "error", duration_sec = 1.5, message = "oops"
  )
  expect_named(
    res,
    c("status", "message", "output_dir", "zone_id", "n_scenes",
      "rasters", "alerts_sf", "n_alerts_inserted", "duration_sec",
      "python_env", "fordead_version"),
    ignore.order = TRUE
  )
  expect_identical(res$status, "error")
  expect_identical(res$message, "oops")
})
