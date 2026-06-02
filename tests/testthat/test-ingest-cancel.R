# test-ingest-cancel.R — cooperative file-based cancellation for the
# Sentinel-2 ingest worker (spec: cancel coopératif FAST/FORDEAD).
#
# The `.make_cancel_checker()` semantics are exercised with plain unit
# tests (no DB). The end-to-end mid-run cancel + partial commit is an
# integration test against TimescaleDB (skipped when no test DB is set).

# ---- unit: .make_cancel_checker() semantics --------------------------

test_that("cancel_path = NULL never touches the filesystem", {
  # Regression guard: the historical (cancel-free) path must perform
  # zero filesystem polls. We spy on the mockable fs wrapper.
  n_calls <- 0L
  testthat::local_mocked_bindings(
    .cancel_flag_exists = function(path) {
      n_calls <<- n_calls + 1L
      FALSE
    }
  )
  chk <- .make_cancel_checker(NULL)
  expect_false(chk())
  expect_false(chk())
  expect_identical(n_calls, 0L)
})

test_that("empty / NA cancel_path is inert", {
  expect_false(.make_cancel_checker("")())
  expect_false(.make_cancel_checker(NA_character_)())
})

test_that("an armed checker flips to TRUE once the flag appears", {
  flag <- withr::local_tempfile(fileext = ".flag")
  chk  <- .make_cancel_checker(flag)
  expect_false(chk())          # not yet
  file.create(flag)
  expect_true(chk())           # flag observed
})

test_that("a flag already present at entry is ignored (stale leftover)", {
  flag <- withr::local_tempfile(fileext = ".flag")
  file.create(flag)            # leftover from a previous run
  expect_warning(chk <- .make_cancel_checker(flag),
                 "already present at entry")
  # Disarmed for the whole run even though the file exists.
  expect_false(chk())
})

test_that("a malformed cancel_path reads as 'no cancel', never errors", {
  # A path under a non-existent directory: file.exists() is silent.
  bad <- file.path(tempfile(), "nope", "cancel.flag")
  chk <- .make_cancel_checker(bad)
  expect_false(chk())
})


# ---- integration: mid-run cancel with partial commit -----------------

test_that("ingest_sentinel2_timeseries cancels mid-run and commits the processed tiles", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Zcancel", pol, placettes)

    # Three scenes; the app will request cancel while tile 2 is being
    # fetched, so the worker stops at the start of tile 3.
    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25", "2025-07-10")),
      cloud = c(5, 8, 3))

    cache <- withr::local_tempdir()
    fake_cache <- function(scene, req_bands, crop_aoi = NULL,
                           cache_dir = NULL, emit = NULL) {
      for (b in req_bands) {
        p <- nemeton:::.s2_band_cache_path(cache_dir, scene$scene_id, b)
        dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
        file.create(p)
      }
      length(req_bands)
    }
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = fake_cache
    )

    flag   <- withr::local_tempfile(fileext = ".flag")
    events <- list()
    cb <- function(ev) {
      events[[length(events) + 1L]] <<- ev
      # `s2:scene` with completed == 1 is the SECOND tile: simulate the
      # user clicking "cancel" while it downloads.
      if (identical(ev$current, "s2:scene") && isTRUE(ev$completed == 1L)) {
        file.create(flag)
      }
    }

    out <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-08-01",
      bands             = "NDVI",
      progress_callback = cb,
      cancel_path       = flag,
      cache_dir         = cache)

    # Summary reflects the cancel and the 2 processed tiles.
    expect_identical(out$status, "cancelled")
    expect_equal(out$n_scenes, 2L)

    # The COG cache holds exactly the first 2 scenes (partial priming).
    scene_dirs <- list.dirs(cache, recursive = FALSE)
    expect_equal(length(scene_dirs), 2L)
    expect_setequal(
      basename(scene_dirs),
      nemeton:::.s2_safe_scene_id(scenes$scene_id[1:2]))

    # A cancellation event was emitted.
    currents <- vapply(events,
                       function(e) if (is.null(e$current)) "" else e$current,
                       character(1))
    expect_true("s2:cancelled" %in% currents)
  })
})

test_that("ingest_sentinel2_timeseries with cancel_path = NULL behaves exactly as before", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Znull", pol, placettes)

    scenes <- fake_scenes(dates = as.Date(c("2025-06-10", "2025-06-25")),
                          cloud = c(5, 8))
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = function(scene, req_bands, ...) length(req_bands))

    out <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-07-01",
      bands = "NDVI", cancel_path = NULL)

    expect_identical(out$status, "success")
    expect_equal(out$n_scenes, 2L)
  })
})

test_that("a stale flag present at entry does not cancel the run", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zstale", pol, placettes)

    scenes <- fake_scenes(dates = as.Date(c("2025-06-10", "2025-06-25")),
                          cloud = c(5, 8))
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = function(scene, req_bands, ...) length(req_bands))

    flag <- withr::local_tempfile(fileext = ".flag")
    file.create(flag)            # leftover, never cleared by the caller

    # The pre-existing flag is ignored (with a warning); the run
    # completes normally.
    expect_warning(
      out <- ingest_sentinel2_timeseries(
        con, zid, "2025-06-01", "2025-07-01",
        bands = "NDVI", cancel_path = flag),
      "already present at entry")
    expect_identical(out$status, "success")
    expect_equal(out$n_scenes, 2L)
  })
})
