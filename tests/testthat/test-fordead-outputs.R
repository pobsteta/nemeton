# test-fordead-outputs.R — output locators + 2.x→class mapping (spec 008 §12)
#
# .list_layer_files / .latest_layer_file are pure filesystem
# operations and tested without terra. .fordead_2x_status_to_classes
# and .compute_first_dieback_date are skipped when terra is not
# available — they'll get full integration coverage in v0.23.0
# release prep (AC.12.3, test-fordead-integration.R).

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
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
