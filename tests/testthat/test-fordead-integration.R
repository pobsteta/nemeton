# test-fordead-integration.R — end-to-end FORDEAD 2.x against a real venv
# (spec 008 §13.7 AC.13.1 — v0.24.0)
#
# These tests touch the real nemeton-fordead Python virtualenv. They
# skip cleanly when:
#   * reticulate / sf / terra is not installed
#   * the venv doesn't exist
#   * fordead 2.x is not importable in it
#   * NEMETON_FORDEAD_INTEGRATION is not set to "TRUE"
#
# To exercise the end-to-end path locally:
#   1. Have a populated nemeton DB (NEMETON_DB_URL pointing at it) with
#      a registered monitoring_zone.
#   2. Set NEMETON_FORDEAD_TEST_ZONE_ID to that zone's id.
#   3. Set NEMETON_FORDEAD_TEST_CACHE_DIR to your project cache root.
#   4. Set NEMETON_FORDEAD_INTEGRATION=TRUE.
#   5. Run `devtools::test(filter = "fordead-integration")`.

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

  db_url    <- Sys.getenv("NEMETON_DB_URL",                    "")
  zone_id   <- Sys.getenv("NEMETON_FORDEAD_TEST_ZONE_ID",      "")
  cache_dir <- Sys.getenv("NEMETON_FORDEAD_TEST_CACHE_DIR",    "")

  if (!nzchar(db_url))    testthat::skip("NEMETON_DB_URL not set")
  if (!nzchar(zone_id))   testthat::skip("NEMETON_FORDEAD_TEST_ZONE_ID not set")
  if (!nzchar(cache_dir) || !dir.exists(cache_dir)) {
    testthat::skip("NEMETON_FORDEAD_TEST_CACHE_DIR not set or dir missing")
  }
}


test_that("FORDEAD 2.x pipeline runs end-to-end on a registered zone and emits ANOMALY_CONFIRMED", {
  skip_if_no_fordead_integration()

  con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  zone_id   <- as.integer(Sys.getenv("NEMETON_FORDEAD_TEST_ZONE_ID"))
  cache_dir <- Sys.getenv("NEMETON_FORDEAD_TEST_CACHE_DIR")
  out_dir   <- withr::local_tempdir()

  res <- run_fordead_dieback(
    con              = con,
    zone_id          = zone_id,
    cache_dir        = cache_dir,
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", as.character(Sys.Date())),
    output_dir       = out_dir,
    verbose          = FALSE
  )

  expect_identical(res$status, "success", info = res$message %||% "")
  expect_identical(res$zone_id, zone_id)
  expect_gt(res$n_scenes, 0L)

  ac_files <- nemeton:::.list_layer_files(out_dir, "ANOMALY_CONFIRMED")
  expect_gt(length(ac_files), 0L)
  r <- terra::rast(ac_files[length(ac_files)])
  expect_s4_class(r, "SpatRaster")
  expect_gt(terra::ncell(r), 0L)
})


test_that("FORDEAD 2.x reports a clear error when zone_id is unknown", {
  skip_if_no_fordead_integration()

  con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  cache_dir <- Sys.getenv("NEMETON_FORDEAD_TEST_CACHE_DIR")
  out_dir   <- withr::local_tempdir()

  # Use a deliberately-impossible zone id. The pipeline must surface a
  # typed error via .get_zone_aoi(), never an opaque Python crash.
  res <- run_fordead_dieback(
    con        = con,
    zone_id    = 999999L,
    cache_dir  = cache_dir,
    output_dir = out_dir,
    verbose    = FALSE
  )

  expect_identical(res$status, "error")
  expect_true(grepl("Unknown monitoring zone", res$message))
})


`%||%` <- function(x, y) if (is.null(x)) y else x
