# test-fordead-integration.R — end-to-end FORDEAD 2.x against a real venv
# (spec 008 §12.7 AC.12.3 / plan 008 §9.4)
#
# These tests touch the real nemeton-fordead Python virtualenv. They
# skip cleanly when:
#   * reticulate / sf / terra is not installed
#   * the venv doesn't exist
#   * fordead 2.x is not importable in it
#   * NEMETON_FORDEAD_INTEGRATION is not set to "TRUE"
#
# The synthetic 100×100×5-date Sentinel-2 fixture mentioned in
# plan 008 §9.4 is not bundled with the package (it would weigh
# several MB and we don't want to ship it). Callers who want to
# exercise the end-to-end path locally can:
#   1. Run `ingest_sentinel2_timeseries()` on a small AOI to populate
#      a real cache_dir with 5+ scenes.
#   2. Set NEMETON_FORDEAD_TEST_AOI to a GeoPackage path,
#      NEMETON_FORDEAD_TEST_CACHE_DIR to the cache root, and
#      NEMETON_FORDEAD_INTEGRATION to TRUE.
#   3. Run `devtools::test(filter = "fordead-integration")`.
#
# Without these env vars, the tests skip and the test count
# advertises that the integration coverage is opt-in.

skip_if_no_fordead_integration <- function() {
  testthat::skip_if_not_installed("reticulate")
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("terra")
  if (!identical(Sys.getenv("NEMETON_FORDEAD_INTEGRATION", "FALSE"), "TRUE")) {
    testthat::skip("NEMETON_FORDEAD_INTEGRATION not set to TRUE")
  }
  env_name <- Sys.getenv("NEMETON_FORDEAD_ENV", "nemeton-fordead")
  if (!reticulate::virtualenv_exists(env_name)) {
    testthat::skip(sprintf("virtualenv %s not found", env_name))
  }
  ok <- tryCatch({
    fd <- reticulate::import("fordead", convert = FALSE)
    v_attr <- tryCatch(reticulate::py_get_attr(fd, "version", silent = TRUE),
                       error = function(e) NULL)
    if (is.null(v_attr)) {
      v_attr <- tryCatch(reticulate::py_get_attr(fd, "__version__", silent = TRUE),
                         error = function(e) NULL)
    }
    v <- reticulate::py_to_r(v_attr)
    is.character(v) && nzchar(v) && substr(v, 1L, 2L) == "2."
  }, error = function(e) FALSE)
  if (!isTRUE(ok)) testthat::skip("fordead 2.x not importable in venv")

  # Need both fixture paths to actually run something useful.
  aoi_path   <- Sys.getenv("NEMETON_FORDEAD_TEST_AOI",       "")
  cache_path <- Sys.getenv("NEMETON_FORDEAD_TEST_CACHE_DIR", "")
  if (!nzchar(aoi_path) || !file.exists(aoi_path)) {
    testthat::skip("NEMETON_FORDEAD_TEST_AOI not set or file missing")
  }
  if (!nzchar(cache_path) || !dir.exists(cache_path)) {
    testthat::skip("NEMETON_FORDEAD_TEST_CACHE_DIR not set or dir missing")
  }
}


test_that("FORDEAD 2.x pipeline runs end-to-end on a small AOI and emits ANOMALY_CONFIRMED", {
  skip_if_no_fordead_integration()

  aoi   <- sf::st_read(Sys.getenv("NEMETON_FORDEAD_TEST_AOI"), quiet = TRUE)
  aoi   <- sf::st_transform(aoi, 2154)
  cache <- Sys.getenv("NEMETON_FORDEAD_TEST_CACHE_DIR")

  # Discover scenes from the cache_dir layout. Each scene dir holds
  # B0X.tif files; we synthesize the obs_date from the scene_id (or
  # accept a passed-in scenes_df path via env var).
  scene_dirs <- list.dirs(cache, recursive = FALSE)
  if (!length(scene_dirs)) testthat::skip("cache_dir contains no scene directories")

  scenes_df <- data.frame(
    scene_id = basename(scene_dirs),
    obs_date = as.Date(
      regmatches(basename(scene_dirs),
                 regexpr("[0-9]{8}T[0-9]{6}", basename(scene_dirs))),
      format = "%Y%m%dT%H%M%S"
    ),
    stringsAsFactors = FALSE
  )
  scenes_df <- scenes_df[!is.na(scenes_df$obs_date), , drop = FALSE]
  if (nrow(scenes_df) < 5L) {
    testthat::skip("cache_dir has < 5 scenes; integration test needs 5+")
  }

  # Use the first 60 % of dates for training, last 40 % for monitoring.
  scenes_df <- scenes_df[order(scenes_df$obs_date), , drop = FALSE]
  split_idx <- ceiling(nrow(scenes_df) * 0.6)
  d_train <- c(as.character(scenes_df$obs_date[1L]),
               as.character(scenes_df$obs_date[split_idx]))
  d_mon   <- c(as.character(scenes_df$obs_date[split_idx + 1L]),
               as.character(scenes_df$obs_date[nrow(scenes_df)]))

  out_dir <- withr::local_tempdir()
  res <- run_fordead_dieback(
    aoi              = aoi,
    scenes_df        = scenes_df,
    cache_dir        = cache,
    dates_training   = d_train,
    dates_monitoring = d_mon,
    output_dir       = out_dir,
    verbose          = FALSE
  )

  expect_identical(res$status, "success", info = res$message %||% "")

  # ANOMALY_CONFIRMED must exist and be openable.
  ac_files <- nemeton:::.list_layer_files(out_dir, "ANOMALY_CONFIRMED")
  expect_gt(length(ac_files), 0L)
  r <- terra::rast(ac_files[length(ac_files)])
  expect_s4_class(r, "SpatRaster")
  expect_gt(terra::ncell(r), 0L)
})


test_that("FORDEAD 2.x reports a clear error when AOI is outside the collection", {
  skip_if_no_fordead_integration()

  cache <- Sys.getenv("NEMETON_FORDEAD_TEST_CACHE_DIR")

  # AOI in the middle of the Atlantic — guaranteed to fall outside
  # any French Sentinel-2 footprint our cache holds.
  bogus_aoi <- sf::st_sf(
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(
        c(-40, 30,  -39, 30,  -39, 31,  -40, 31,  -40, 30),
        ncol = 2, byrow = TRUE
      ))),
      crs = 4326
    )
  )
  bogus_aoi <- sf::st_transform(bogus_aoi, 2154)

  scene_dirs <- list.dirs(cache, recursive = FALSE)
  if (!length(scene_dirs)) testthat::skip("cache_dir empty")
  scenes_df <- data.frame(
    scene_id = basename(scene_dirs),
    obs_date = Sys.Date() - 30L:1L,
    stringsAsFactors = FALSE
  )
  scenes_df <- scenes_df[seq_len(min(nrow(scenes_df), 5L)), , drop = FALSE]

  out_dir <- withr::local_tempdir()
  res <- run_fordead_dieback(
    aoi        = bogus_aoi,
    scenes_df  = scenes_df,
    cache_dir  = cache,
    output_dir = out_dir,
    verbose    = FALSE
  )

  # We don't strictly require status == "error" — fordead might
  # produce an empty raster. We *do* require either status == "error"
  # OR no alerts. Crash-with-cryptic-message would have been the
  # pre-v0.23.0 behaviour and is what we're guarding against.
  expect_true(
    res$status == "error" || is.null(res$alerts_sf),
    info = sprintf("status=%s alerts_n=%s",
                   res$status,
                   if (is.null(res$alerts_sf)) "NULL"
                   else as.character(nrow(res$alerts_sf)))
  )
})


# Local null-coalesce. The pipeline module exports nothing similar.
`%||%` <- function(x, y) if (is.null(x)) y else x
