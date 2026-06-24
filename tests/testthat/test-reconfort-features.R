# test-reconfort-features.R — CRswir/CRre feature stacks (bundle persist).

skip_if_no_terra_features <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}

mk_band <- function(res, seed) {
  r <- terra::rast(xmin = 0, xmax = 80, ymin = 0, ymax = 80,
                   resolution = res, crs = "EPSG:2154")
  set.seed(seed); terra::values(r) <- runif(terra::ncell(r)) * 1000 + seed
  r
}

test_that(".build_reconfort_feature_stacks aligns mixed-resolution FRE bands", {
  skip_if_no_terra_features()
  # B04 is 10 m, the red-edge / SWIR bands are 20 m — terra cannot combine
  # different dimensions, so the builder must resample to a common grid
  # (regression: 'number of rows and/or columns' in the persist phase).
  scene <- list(
    obs_date = as.Date("2025-06-09"),
    B04 = mk_band(10, 1), B05 = mk_band(20, 2), B06 = mk_band(20, 3),
    B8A = mk_band(20, 4), B11 = mk_band(20, 5), B12 = mk_band(20, 6),
    scl = NULL)
  st <- nemeton:::.build_reconfort_feature_stacks(list(scene))
  expect_s4_class(st$crswir, "SpatRaster")
  expect_s4_class(st$crre, "SpatRaster")
  # both indices on B04's 10 m grid (8x8 over the 80 m extent)
  expect_equal(dim(st$crswir)[1:2], c(8L, 8L))
  expect_equal(dim(st$crre)[1:2], c(8L, 8L))
  expect_equal(terra::nlyr(st$crswir), 1L)
})

test_that(".build_reconfort_feature_stacks stamps one band per date", {
  skip_if_no_terra_features()
  scenes <- lapply(1:3, function(k) list(
    obs_date = as.Date("2025-06-01") + k,
    B04 = mk_band(10, k), B05 = mk_band(20, k + 10), B06 = mk_band(20, k + 20),
    B8A = mk_band(20, k + 30), B11 = mk_band(20, k + 40),
    B12 = mk_band(20, k + 50), scl = NULL))
  st <- nemeton:::.build_reconfort_feature_stacks(scenes)
  expect_equal(terra::nlyr(st$crswir), 3L)
  expect_equal(terra::nlyr(st$crre), 3L)
})
