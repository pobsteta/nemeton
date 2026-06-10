# test-fordead-outputs.R — output locators + 2.x→class mapping (spec 008 §12)
#
# .list_layer_files / .latest_layer_file are pure filesystem
# operations and tested without terra. .fordead_2x_status_to_classes
# and .compute_first_dieback_date are skipped when terra is not
# available — they'll get full integration coverage in v0.23.0
# release prep (AC.12.3, test-fordead-integration.R).

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}


# ---- .list_layer_files / .latest_layer_file --------------------------

.touch_layer_files <- function(out_dir, layer, dates) {
  d <- file.path(out_dir, layer)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (dt in dates) {
    f <- file.path(d, sprintf("fordead_%s_%s.tif", dt, layer))
    file.create(f)
  }
  invisible(d)
}


test_that(".list_layer_files returns empty character on missing dir", {
  d <- withr::local_tempdir()
  expect_identical(
    nemeton:::.list_layer_files(d, "ANOMALY_CONFIRMED"),
    character(0)
  )
})


test_that(".list_layer_files returns paths sorted by embedded date", {
  d <- withr::local_tempdir()
  # Intentionally write in reverse chronological order.
  .touch_layer_files(d, "ANOMALY_CONFIRMED",
                     c("20210315", "20210101", "20210215"))
  files <- nemeton:::.list_layer_files(d, "ANOMALY_CONFIRMED")
  expect_length(files, 3L)
  expect_identical(
    basename(files),
    c("fordead_20210101_ANOMALY_CONFIRMED.tif",
      "fordead_20210215_ANOMALY_CONFIRMED.tif",
      "fordead_20210315_ANOMALY_CONFIRMED.tif")
  )
})


test_that(".list_layer_files ignores files that don't match the convention", {
  d <- withr::local_tempdir()
  .touch_layer_files(d, "ANOMALY_CONFIRMED", "20210101")
  # Files that should NOT be picked up:
  layer_dir <- file.path(d, "ANOMALY_CONFIRMED")
  file.create(file.path(layer_dir, "manual_export.tif"))
  file.create(file.path(layer_dir, "fordead_20210101_SOMETHING_ELSE.tif"))
  file.create(file.path(layer_dir, "README.txt"))

  files <- nemeton:::.list_layer_files(d, "ANOMALY_CONFIRMED")
  expect_length(files, 1L)
  expect_match(basename(files), "fordead_20210101_ANOMALY_CONFIRMED\\.tif")
})


test_that(".latest_layer_file returns NA when no files match", {
  d <- withr::local_tempdir()
  expect_true(is.na(nemeton:::.latest_layer_file(d, "ANOMALY_CONFIRMED")))
})


test_that(".latest_layer_file picks the latest date", {
  d <- withr::local_tempdir()
  .touch_layer_files(d, "ANOMALY_CONFIRMED",
                     c("20200101", "20240315", "20221101"))
  latest <- nemeton:::.latest_layer_file(d, "ANOMALY_CONFIRMED")
  expect_match(basename(latest), "fordead_20240315_ANOMALY_CONFIRMED\\.tif")
})


test_that(".latest_layer_file validates inputs", {
  expect_error(nemeton:::.latest_layer_file("", "X"),       "non-empty")
  expect_error(nemeton:::.latest_layer_file(NULL, "X"),     "non-empty")
  expect_error(nemeton:::.latest_layer_file(".", ""),       "non-empty")
})


# ---- .fordead_2x_status_to_classes -----------------------------------

# Build a small in-memory raster (no GeoTIFF on disk) for one layer.
.write_one_band_tif <- function(out_dir, layer, dt, values, ncol = 3L, nrow = 3L) {
  layer_dir <- file.path(out_dir, layer)
  dir.create(layer_dir, recursive = TRUE, showWarnings = FALSE)
  fp <- file.path(layer_dir, sprintf("fordead_%s_%s.tif", dt, layer))
  r <- terra::rast(nrows = nrow, ncols = ncol,
                   xmin = 0, xmax = 30, ymin = 0, ymax = 30, crs = "EPSG:2154")
  terra::values(r) <- values
  terra::writeRaster(r, fp, filetype = "GTiff", overwrite = TRUE)
  fp
}


test_that(".fordead_2x_status_to_classes returns NULL when ANOMALY_CONFIRMED missing", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  expect_warning(
    out <- nemeton:::.fordead_2x_status_to_classes(d),
    "ANOMALY_CONFIRMED"
  )
  expect_null(out)
})


test_that(".fordead_2x_status_to_classes maps thresholds (no STOP)", {
  skip_if_no_terra()
  d <- withr::local_tempdir()

  # 9 pixels. Mapping rule (spec 008 §12.4 / .fordead_2x_status_to_classes):
  #   STOP=1                -> 4 (sol nu)        — not exercised here
  #   confirmed & cd>=10    -> 3 (forte)
  #   confirmed & cd>=6     -> 2 (moyenne)
  #   confirmed & cd>=3     -> 1 (faible)
  #   else                  -> 0 (sain)
  ac <- c(1L, 1L, 1L,    1L, 1L, 1L,    0L, 1L, 1L)  # last 2 confirmed
  cd <- c(2L, 3L, 5L,    6L, 9L, 10L,  20L, 0L, 14L)
  .write_one_band_tif(d, "ANOMALY_CONFIRMED",      "20210101", ac)
  .write_one_band_tif(d, "CONSECUTIVE_DETECTIONS", "20210101", cd)
  # STOP_CONFIRMED absent — defaults to zero everywhere.

  cls <- nemeton:::.fordead_2x_status_to_classes(d)
  expect_s4_class(cls, "SpatRaster")
  v <- as.integer(terra::values(cls)[, 1L])
  # ac=1 cd=2  -> 0 (cd < 3)
  # ac=1 cd=3  -> 1
  # ac=1 cd=5  -> 1
  # ac=1 cd=6  -> 2
  # ac=1 cd=9  -> 2
  # ac=1 cd=10 -> 3
  # ac=0 cd=20 -> 0 (not confirmed)
  # ac=1 cd=0  -> 0
  # ac=1 cd=14 -> 3
  expect_identical(v, c(0L, 1L, 1L, 2L, 2L, 3L, 0L, 0L, 3L))
})


test_that(".fordead_2x_status_to_classes flags STOP as class 4", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  ac <- c(1L, 1L, 1L)
  cd <- c(5L, 5L, 5L)  # would normally map to class 1
  sc <- c(0L, 1L, 0L)  # second pixel has STOP set -> class 4
  .write_one_band_tif(d, "ANOMALY_CONFIRMED",      "20210101", ac, ncol = 3L, nrow = 1L)
  .write_one_band_tif(d, "CONSECUTIVE_DETECTIONS", "20210101", cd, ncol = 3L, nrow = 1L)
  .write_one_band_tif(d, "STOP_CONFIRMED",         "20210101", sc, ncol = 3L, nrow = 1L)

  cls <- nemeton:::.fordead_2x_status_to_classes(d)
  v   <- as.integer(terra::values(cls)[, 1L])
  expect_identical(v, c(1L, 4L, 1L))
})


test_that(".fordead_2x_status_to_classes treats 255 as NA", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  ac <- c(1L, 255L, 0L)
  cd <- c(5L, 5L, 5L)
  .write_one_band_tif(d, "ANOMALY_CONFIRMED",      "20210101", ac, ncol = 3L, nrow = 1L)
  .write_one_band_tif(d, "CONSECUTIVE_DETECTIONS", "20210101", cd, ncol = 3L, nrow = 1L)

  cls <- nemeton:::.fordead_2x_status_to_classes(d)
  v   <- terra::values(cls)[, 1L]
  expect_equal(v[1L], 1)
  expect_true(is.na(v[2L]))
  expect_equal(v[3L], 0)
})


# ---- .compute_first_dieback_date (placeholder — full coverage in T3) ----

test_that(".compute_first_dieback_date returns NULL when no layer present", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  fake_fd_utils <- list(backward_start = function(...) NULL)
  expect_warning(
    out <- nemeton:::.compute_first_dieback_date(d, fake_fd_utils),
    "ANOMALY_CONFIRMED"
  )
  expect_null(out)
})


# ---- diagnostic bundle (spec 008 §14.3, L1) --------------------------

# Build a synthetic FordeadProcess output dir: a 5-band fit/model.tif,
# `n` dated CRSWIR rasters and their INVALID_PIXEL_MASK counterparts.
# Pixel (1,1) is flagged invalid on the first date so masking can be
# asserted. Returns the output dir path and the dates used.
.make_fake_fordead_src <- function(n = 3L, with_masks = TRUE,
                                   with_model = TRUE) {
  d <- withr::local_tempdir(.local_envir = parent.frame())
  dates <- seq(as.Date("2019-01-01"), by = "30 days", length.out = n)
  tmpl  <- terra::rast(nrows = 4, ncols = 5,
                       xmin = 0, xmax = 50, ymin = 0, ymax = 40,
                       crs = "EPSG:32631")

  if (with_model) {
    dir.create(file.path(d, "fit"), recursive = TRUE, showWarnings = FALSE)
    model <- terra::rast(lapply(1:5, function(i) {
      r <- tmpl; terra::values(r) <- as.numeric(seq_len(20) + i); r
    }))
    names(model) <- paste0("model_", 1:5)
    terra::writeRaster(model, file.path(d, "fit", "model.tif"))
  }

  for (i in seq_len(n)) {
    ds <- format(dates[i], "%Y%m%d")
    cr <- tmpl; terra::values(cr) <- as.numeric(seq_len(20)) / 20
    dd <- file.path(d, "CRSWIR")
    dir.create(dd, showWarnings = FALSE)
    terra::writeRaster(cr,
      file.path(dd, sprintf("fordead_%s_CRSWIR.tif", ds)))
    if (with_masks) {
      mk <- tmpl
      v  <- rep(0L, 20L)
      if (i == 1L) v[1L] <- 1L          # pixel 1 invalid on date 1
      terra::values(mk) <- v
      md <- file.path(d, "INVALID_PIXEL_MASK")
      dir.create(md, showWarnings = FALSE)
      terra::writeRaster(mk,
        file.path(md, sprintf("fordead_%s_INVALID_PIXEL_MASK.tif", ds)))
    }
  }
  list(dir = d, dates = dates)
}


test_that(".build_crswir_masked_stack stacks dated CRSWIR with terra::time()", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 3L)
  st <- nemeton:::.build_crswir_masked_stack(fx$dir)
  expect_s4_class(st, "SpatRaster")
  expect_equal(terra::nlyr(st), 3L)
  expect_equal(as.Date(terra::time(st)), fx$dates)
})


test_that(".build_crswir_masked_stack blanks invalid pixels", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 3L)
  st <- nemeton:::.build_crswir_masked_stack(fx$dir)
  # Pixel 1 is flagged invalid on date 1 only.
  expect_true(is.na(terra::values(st)[1L, 1L]))
  expect_false(is.na(terra::values(st)[1L, 2L]))
})


test_that(".build_crswir_masked_stack warns + returns NULL with no CRSWIR layer", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  expect_warning(
    out <- nemeton:::.build_crswir_masked_stack(d),
    "CRSWIR"
  )
  expect_null(out)
})


test_that(".build_crswir_masked_stack tolerates a missing mask layer", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 2L, with_masks = FALSE)
  st <- nemeton:::.build_crswir_masked_stack(fx$dir)
  expect_s4_class(st, "SpatRaster")
  expect_equal(terra::nlyr(st), 2L)
  # No mask → nothing blanked.
  expect_false(anyNA(terra::values(st)))
})


test_that(".write_fordead_model_bundle writes the 4 artefacts (AC.14.1)", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 3L)
  md <- file.path(withr::local_tempdir(), "model_20190101T120000")
  fa <- terra::rast(nrows = 4, ncols = 5, xmin = 0, xmax = 50,
                    ymin = 0, ymax = 40, crs = "EPSG:32631")
  terra::values(fa) <- as.numeric(seq_len(20)) + 18000

  res <- nemeton:::.write_fordead_model_bundle(
    fx$dir, md, first_anomaly = fa,
    run_meta = list(run_id = "20190101T120000", zone_id = 1L,
                    threshold_anomaly = 0.16), verbose = FALSE)

  expect_identical(res, md)
  expect_true(all(file.exists(file.path(md,
    c("coeff_model.tif", "crswir_stack.tif",
      "first_anomaly.tif", "run_meta.json")))))
  expect_equal(terra::nlyr(terra::rast(file.path(md, "coeff_model.tif"))), 5L)
  expect_equal(terra::nlyr(terra::rast(file.path(md, "crswir_stack.tif"))), 3L)
})


test_that(".write_fordead_model_bundle run_meta.json round-trips", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 2L)
  md <- file.path(withr::local_tempdir(), "model_x")
  meta <- list(run_id = "20190101T120000", zone_id = 4L,
               vegetation_index = "CRSWIR", threshold_anomaly = 0.16,
               dates_training = c("2016-01-01", "2017-12-31"))
  nemeton:::.write_fordead_model_bundle(fx$dir, md, run_meta = meta,
                                        verbose = FALSE)
  back <- jsonlite::read_json(file.path(md, "run_meta.json"),
                              simplifyVector = TRUE)
  expect_identical(back$run_id, "20190101T120000")
  expect_identical(back$zone_id, 4L)
  expect_identical(back$threshold_anomaly, 0.16)
  expect_identical(back$dates_training, c("2016-01-01", "2017-12-31"))
})


test_that(".write_fordead_model_bundle skips first_anomaly.tif when NULL", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 2L)
  md <- file.path(withr::local_tempdir(), "model_noanom")
  nemeton:::.write_fordead_model_bundle(fx$dir, md, first_anomaly = NULL,
                                        verbose = FALSE)
  expect_false(file.exists(file.path(md, "first_anomaly.tif")))
  expect_true(file.exists(file.path(md, "coeff_model.tif")))
})


test_that(".write_fordead_model_bundle aborts when fit/model.tif is missing", {
  skip_if_no_terra()
  fx <- .make_fake_fordead_src(n = 2L, with_model = FALSE)
  md <- file.path(withr::local_tempdir(), "model_nomodel")
  expect_error(
    nemeton:::.write_fordead_model_bundle(fx$dir, md, verbose = FALSE),
    "model.tif"
  )
})
