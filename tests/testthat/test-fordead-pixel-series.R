# test-fordead-pixel-series.R — read_fordead_pixel_series() (spec 008
# §14.4, L2). Offline tests use a synthetic diagnostic bundle and mock
# the reticulate-backed harmonic prediction; the parity test (AC.14.2)
# is skipped when the FORDEAD venv is unavailable.

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}
skip_if_no_sf    <- function() testthat::skip_if_not_installed("sf")


# Build a synthetic FORDEAD diagnostic bundle under
# <root>/zone_<id>/model_<run_id>/. The raster is in EPSG:4326 so a
# clicked lon/lat needs no real reprojection. Each CRSWIR band is
# filled uniformly so any in-extent pixel yields the same known
# series; coeff bands likewise. `coeff_na = TRUE` writes an all-NA
# coefficient raster (an unmodelled pixel).
.make_pixel_bundle <- function(root, zone_id = 1L,
                               run_id = "20260101T120000",
                               coeff_na = FALSE,
                               threshold = 0.16) {
  model_dir <- file.path(root, sprintf("zone_%d", zone_id),
                         sprintf("model_%s", run_id))
  dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
  tmpl <- terra::rast(nrows = 4, ncols = 5,
                      xmin = 6.0, xmax = 6.5, ymin = 46.0, ymax = 46.4,
                      crs = "EPSG:4326")

  # coeff_model.tif — 5 bands, band i filled with i/10 (or all NA).
  coeff <- terra::rast(lapply(1:5, function(i) {
    r <- tmpl
    terra::values(r) <- if (coeff_na) NA_real_ else rep(i / 10, 20L)
    r
  }))
  names(coeff) <- paste0("model_", 1:5)
  terra::writeRaster(coeff, file.path(model_dir, "coeff_model.tif"))

  # crswir_stack.tif — 4 dated bands: 0.2, 0.5, 0.9, NA.
  dates <- as.Date(c("2019-01-10", "2019-04-10", "2019-07-10",
                     "2019-10-10"))
  vals  <- c(0.2, 0.5, 0.9, NA_real_)
  crswir <- terra::rast(lapply(seq_along(dates), function(i) {
    r <- tmpl; terra::values(r) <- rep(vals[i], 20L); r
  }))
  names(crswir)       <- format(dates, "%Y-%m-%d")
  terra::time(crswir) <- dates
  terra::writeRaster(crswir, file.path(model_dir, "crswir_stack.tif"))

  # first_anomaly.tif — days since epoch of 2019-04-10.
  fa <- tmpl
  terra::values(fa) <- rep(as.numeric(as.Date("2019-04-10")), 20L)
  terra::writeRaster(fa, file.path(model_dir, "first_anomaly.tif"))

  jsonlite::write_json(
    list(run_id = run_id, zone_id = zone_id,
         vegetation_index = "CRSWIR", threshold_anomaly = threshold),
    file.path(model_dir, "run_meta.json"),
    auto_unbox = TRUE, pretty = TRUE)

  list(model_dir = model_dir, dates = dates, crswir = vals,
       threshold = threshold)
}

# Deterministic stand-in for the reticulate-backed predictor.
.mock_predict_const <- function(value = 0.3) {
  function(coeff, obs_date, ...) rep(value, length(obs_date))
}


# ---- .locate_fordead_model_bundle ------------------------------------

test_that(".locate_fordead_model_bundle returns NULL when nothing exists", {
  d <- withr::local_tempdir()
  expect_null(nemeton:::.locate_fordead_model_bundle(d, 1L))
  expect_null(nemeton:::.locate_fordead_model_bundle(NULL, 1L))
  expect_null(nemeton:::.locate_fordead_model_bundle(
    file.path(d, "missing"), 1L))
})


test_that(".locate_fordead_model_bundle picks the most recent run", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 2L, run_id = "20260101T120000")
  .make_pixel_bundle(d, zone_id = 2L, run_id = "20260315T090000")
  got <- nemeton:::.locate_fordead_model_bundle(d, 2L)
  expect_match(basename(got), "model_20260315T090000")
})


test_that(".locate_fordead_model_bundle honours an explicit run_id", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L, run_id = "20260101T120000")
  .make_pixel_bundle(d, zone_id = 1L, run_id = "20260315T090000")
  got <- nemeton:::.locate_fordead_model_bundle(d, 1L,
                                                run_id = "20260101T120000")
  expect_match(basename(got), "model_20260101T120000")
  expect_null(nemeton:::.locate_fordead_model_bundle(d, 1L,
                                                     run_id = "nope"))
})


# ---- .crswir_stack_dates ---------------------------------------------

test_that(".crswir_stack_dates falls back to layer names", {
  skip_if_no_terra()
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 3)
  names(r) <- c("2020-01-01", "2020-02-01", "2020-03-01")
  expect_identical(nemeton:::.crswir_stack_dates(r),
                   as.Date(c("2020-01-01", "2020-02-01", "2020-03-01")))
})


# ---- read_fordead_pixel_series — NULL / error paths ------------------

test_that("read_fordead_pixel_series returns NULL when no bundle found", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  expect_null(read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2),
                                        cache_dir = d))
  expect_null(read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2),
                                        cache_dir = NULL))
})


test_that("read_fordead_pixel_series rejects bad zone_id / xy", {
  d <- withr::local_tempdir()
  expect_error(read_fordead_pixel_series(NULL, NA, c(6.2, 46.2),
                                         cache_dir = d), "zone_id")
  expect_error(read_fordead_pixel_series(NULL, c(1L, 2L), c(6.2, 46.2),
                                         cache_dir = d), "zone_id")
  expect_error(read_fordead_pixel_series(NULL, 1L, c(6.2, NA),
                                         cache_dir = d), "xy")
  expect_error(read_fordead_pixel_series(NULL, 1L, 6.2, cache_dir = d),
               "xy")
})


test_that("read_fordead_pixel_series returns NULL for an out-of-extent pixel", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L)
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = .mock_predict_const(),
    .package = "nemeton")
  # (0, 0) is far outside the 6.0-6.5 / 46.0-46.4 fixture extent.
  expect_null(read_fordead_pixel_series(NULL, 1L, c(0, 0), cache_dir = d))
})


test_that("read_fordead_pixel_series returns NULL on an unmodelled pixel", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L, coeff_na = TRUE)
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = .mock_predict_const(),
    .package = "nemeton")
  expect_null(read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2),
                                        cache_dir = d))
})


test_that("read_fordead_pixel_series returns NULL when Python is unavailable", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L)
  # Simulate a missing FORDEAD venv: the predictor returns NULL.
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = function(coeff, obs_date, ...) NULL,
    .package = "nemeton")
  expect_null(read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2),
                                        cache_dir = d))
})


# ---- read_fordead_pixel_series — happy path --------------------------

test_that("read_fordead_pixel_series returns the spec'd data.frame schema", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L)
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = .mock_predict_const(0.3),
    .package = "nemeton")

  s <- read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2), cache_dir = d)
  expect_s3_class(s, "data.frame")
  expect_identical(names(s),
                   c("obs_date", "crswir_obs", "crswir_pred",
                     "seuil_haut", "anomalie"))
  expect_equal(nrow(s), 4L)
  expect_s3_class(s$obs_date, "Date")
  expect_true(is.logical(s$anomalie))
  # Ordered by obs_date.
  expect_false(is.unsorted(s$obs_date))
})


test_that("read_fordead_pixel_series computes seuil_haut and anomalie", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L, threshold = 0.16)
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = .mock_predict_const(0.3),
    .package = "nemeton")

  s <- read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2), cache_dir = d)
  # pred 0.3 + threshold 0.16 -> seuil 0.46.
  expect_equal(unique(s$seuil_haut), 0.46)
  # crswir_obs = 0.2, 0.5, 0.9, NA  ->  anomalie = F, T, T, NA.
  expect_identical(s$anomalie, c(FALSE, TRUE, TRUE, NA))
})


test_that("read_fordead_pixel_series carries the spec'd attributes", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L, threshold = 0.16)
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = .mock_predict_const(0.3),
    .package = "nemeton")

  s <- read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2), cache_dir = d)
  expect_equal(attr(s, "threshold_anomaly"), 0.16)
  expect_identical(attr(s, "vegetation_index"), "CRSWIR")
  expect_identical(attr(s, "premiere_detection"), as.Date("2019-04-10"))
  expect_true(is.logical(attr(s, "dans_zone_validite")))
  expect_length(attr(s, "dans_zone_validite"), 1L)
})


test_that("read_fordead_pixel_series selects a bundle by explicit run_id", {
  skip_if_no_terra(); skip_if_no_sf()
  d <- withr::local_tempdir()
  .make_pixel_bundle(d, zone_id = 1L, run_id = "20260101T120000",
                     threshold = 0.10)
  .make_pixel_bundle(d, zone_id = 1L, run_id = "20260315T090000",
                     threshold = 0.40)
  testthat::local_mocked_bindings(
    .fordead_harmonic_predict = .mock_predict_const(0.3),
    .package = "nemeton")

  s_old <- read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2),
                                     run_id = "20260101T120000",
                                     cache_dir = d)
  s_new <- read_fordead_pixel_series(NULL, 1L, c(6.2, 46.2),
                                     cache_dir = d)  # latest
  expect_equal(attr(s_old, "threshold_anomaly"), 0.10)
  expect_equal(attr(s_new, "threshold_anomaly"), 0.40)
})


# ---- AC.14.2 — harmonic-prediction parity with fordead ---------------

test_that(".fordead_harmonic_predict matches fordead.modeling (AC.14.2)", {
  testthat::skip_if_not_installed("reticulate")
  skip_if_not(
    tryCatch({
      reticulate::use_virtualenv(nemeton:::.fordead_default_env(),
                                 required = TRUE)
      reticulate::py_module_available("fordead")
    }, error = function(e) FALSE),
    "FORDEAD virtualenv not available"
  )

  coeff <- c(0.45, 0.02, -0.03, 0.01, -0.015)
  dates <- as.Date(c("2018-03-15", "2019-06-20", "2019-12-01"))
  got <- nemeton:::.fordead_harmonic_predict(coeff, dates)

  # Independent reference straight from fordead.modeling.
  M    <- reticulate::import("fordead.modeling", convert = TRUE)
  days <- as.integer(dates - as.Date("2015-01-01"))
  ref  <- vapply(days, function(d) {
    sum(coeff * as.numeric(M$compute_HarmonicTerms(as.numeric(d))))
  }, numeric(1))

  expect_equal(got, ref, tolerance = 1e-6)
})
