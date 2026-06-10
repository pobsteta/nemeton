# test-alert-mask.R — spec 014 A1: fordead_alert_mask()

make_fake_alert_raster <- function() {
  # 4x4 categorical raster, EPSG:2154
  m <- matrix(c(
    0, 0, 1, 1,
    0, 2, 3, 4,
    0, 2, 3, 4,
    0, 0, 1, 2
  ), nrow = 4, byrow = TRUE)
  r <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 40, 0, 40)
  r
}


test_that("fordead_alert_mask rejects non-SpatRaster", {
  skip_if_not_installed("terra")
  expect_error(fordead_alert_mask(matrix(1, 4, 4)),
               regexp = "SpatRaster")
})

test_that("fordead_alert_mask rejects multi-layer raster", {
  skip_if_not_installed("terra")
  r1 <- make_fake_alert_raster()
  multi <- terra::rast(list(r1, r1))
  expect_error(fordead_alert_mask(multi),
               regexp = "exactly one layer")
})

test_that("fordead_alert_mask rejects bad classes / buffer_m", {
  skip_if_not_installed("terra")
  r <- make_fake_alert_raster()
  expect_error(fordead_alert_mask(r, classes = NA),
               regexp = "non-empty")
  expect_error(fordead_alert_mask(r, classes = integer(0)),
               regexp = "non-empty")
  expect_error(fordead_alert_mask(r, buffer_m = -5),
               regexp = "non-negative")
})

test_that("fordead_alert_mask keeps class values, NA elsewhere", {
  skip_if_not_installed("terra")
  r <- make_fake_alert_raster()
  out <- fordead_alert_mask(r, classes = c(3L, 4L), buffer_m = 0)

  expect_s4_class(out, "SpatRaster")
  expect_equal(names(out), "alert_priority")

  vals <- as.vector(terra::values(out))
  expect_true(all(vals[!is.na(vals)] %in% c(3L, 4L)))
  # The fake raster has 2 cells of class 3 and 2 cells of class 4.
  expect_equal(sum(!is.na(vals)), 4L)
})

test_that("fordead_alert_mask returns all-NA when no cell matches classes", {
  skip_if_not_installed("terra")
  r <- make_fake_alert_raster()
  out <- fordead_alert_mask(r, classes = c(99L), buffer_m = 0)
  vals <- as.vector(terra::values(out))
  expect_true(all(is.na(vals)))
})

test_that("fordead_alert_mask buffer dilates alert cells", {
  skip_if_not_installed("terra")
  # A single alert cell at (row=1, col=1), buffer should add 8 neighbours.
  m <- matrix(0, 4, 4)
  m[1, 1] <- 3L
  r <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 40, 0, 40)  # 10m pixels

  unbuf <- fordead_alert_mask(r, classes = 3L, buffer_m = 0)
  buf   <- fordead_alert_mask(r, classes = 3L, buffer_m = 15)

  # Unbuffered: exactly 1 non-NA cell (the original).
  expect_equal(sum(!is.na(terra::values(unbuf))), 1L)
  # Buffered: more cells than unbuffered.
  expect_true(sum(!is.na(terra::values(buf))) > 1L)
  # The original cell keeps its class value (3); buffer cells get
  # min(classes) = 3 too (only one class), so all non-NA values are 3.
  bv <- as.vector(terra::values(buf))
  expect_true(all(bv[!is.na(bv)] == 3L))
})
