# test-fordead_mask.R — read_fordead_dieback_mask() (E6.f.5, v0.25.0)
#
# Filesystem-driven: we write categorical GeoTIFF fixtures under
# `<tmp>/zone_<id>/dieback_mask_<run_id>.tif` and verify the function
# resolves the correct file, returns a terra SpatRaster, and preserves
# categorical values + NA.

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
}

make_fake_con <- function() {
  structure(list(), class = c("FakeConnection", "DBIConnection"))
}

# Write a 3x3 categorical GeoTIFF with the requested values, returns
# the file path. CRS arbitrary — the test asserts values + NA, not crs.
.write_mask_fixture <- function(path, values) {
  d <- dirname(path)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  r <- terra::rast(nrows = 3L, ncols = 3L,
                   xmin = 0, xmax = 30, ymin = 0, ymax = 30,
                   crs = "EPSG:2154")
  terra::values(r) <- values
  terra::writeRaster(r, path, filetype = "GTiff", overwrite = TRUE,
                     datatype = "INT2S", NAflag = -1)
  path
}


test_that("returns NULL when cache_dir is NULL", {
  expect_null(read_fordead_dieback_mask(con = make_fake_con(), zone_id = 1L))
})


test_that("returns NULL when cache_dir doesn't exist", {
  expect_null(
    read_fordead_dieback_mask(make_fake_con(), zone_id = 1L,
                              cache_dir = "/no/such/path")
  )
})


test_that("returns NULL when zone directory is empty", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  dir.create(file.path(d, "zone_1"), recursive = TRUE)
  expect_null(
    read_fordead_dieback_mask(make_fake_con(), zone_id = 1L, cache_dir = d)
  )
})


test_that("reads the categorical values 0..4 and preserves NA", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  # 9 pixels covering all 5 classes plus an NA outside the mask.
  vals <- c(0L, 1L, 2L,
            3L, 4L, NA,
            0L, 2L, 3L)
  .write_mask_fixture(file.path(d, "zone_1", "dieback_mask_20260517T120000.tif"),
                      vals)

  r <- read_fordead_dieback_mask(make_fake_con(), zone_id = 1L, cache_dir = d)
  expect_s4_class(r, "SpatRaster")
  v <- as.integer(terra::values(r)[, 1L])
  expect_identical(v[1L], 0L)
  expect_identical(v[2L], 1L)
  expect_identical(v[3L], 2L)
  expect_identical(v[4L], 3L)
  expect_identical(v[5L], 4L)
  expect_true(is.na(v[6L]))
  expect_identical(v[7:9L], c(0L, 2L, 3L))
})


test_that("picks the latest mask file when run_id is NULL", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  zd <- file.path(d, "zone_2")
  .write_mask_fixture(
    file.path(zd, "dieback_mask_20260516T100000.tif"),
    rep(0L, 9L)
  )
  .write_mask_fixture(
    file.path(zd, "dieback_mask_20260517T120000.tif"),
    rep(3L, 9L)
  )

  r <- read_fordead_dieback_mask(make_fake_con(), zone_id = 2L, cache_dir = d)
  v <- as.integer(terra::values(r)[, 1L])
  # Latest fixture has class 3 ("forte") everywhere.
  expect_true(all(v == 3L))
})


test_that("picks the specified run_id when supplied", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  zd <- file.path(d, "zone_3")
  .write_mask_fixture(
    file.path(zd, "dieback_mask_20260516T100000.tif"),
    rep(1L, 9L)
  )
  .write_mask_fixture(
    file.path(zd, "dieback_mask_20260517T120000.tif"),
    rep(2L, 9L)
  )

  r <- read_fordead_dieback_mask(
    make_fake_con(), zone_id = 3L,
    run_id    = "20260516T100000",
    cache_dir = d
  )
  v <- as.integer(terra::values(r)[, 1L])
  expect_true(all(v == 1L))
})


test_that("returns NULL when the explicit run_id does not exist", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  dir.create(file.path(d, "zone_4"), recursive = TRUE)
  expect_null(
    read_fordead_dieback_mask(make_fake_con(), zone_id = 4L,
                              run_id    = "99999999T999999",
                              cache_dir = d)
  )
})


test_that("rejects NA zone_id", {
  expect_error(
    read_fordead_dieback_mask(make_fake_con(), zone_id = NA,
                              cache_dir = "/tmp"),
    "zone_id"
  )
})
