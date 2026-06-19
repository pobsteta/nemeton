# test-fordead-layer.R — read_fordead_layer() reads the auxiliary
# FORDEAD model-bundle rasters (Carte FORDEAD display layers).

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  # Garde-fou : certains runners CI ont un terra où writeRaster(crs=EPSG)
  # échoue ("no valid constructor") — même skip que les autres tests fordead.
  skip_if_terra_write_broken()
}

# Build cache_dir/zone_<id>/model_<run_id>/<layer>.tif for the requested
# layers and return the cache_dir.
.make_fake_bundle <- function(zone_id = 1L, run_id = "20190101T120000",
                              layers = c("first_anomaly", "anomaly_index",
                                         "modelled_pixels")) {
  cd <- withr::local_tempdir(.local_envir = parent.frame())
  md <- file.path(cd, sprintf("zone_%d", zone_id),
                  sprintf("model_%s", run_id))
  dir.create(md, recursive = TRUE, showWarnings = FALSE)
  tmpl <- terra::rast(nrows = 4, ncols = 5, xmin = 0, xmax = 50,
                      ymin = 0, ymax = 40, crs = "EPSG:2154")
  for (lyr in layers) {
    r <- tmpl; terra::values(r) <- as.numeric(seq_len(20))
    terra::writeRaster(r, file.path(md, sprintf("%s.tif", lyr)))
  }
  cd
}


test_that("read_fordead_layer reads each recognised layer", {
  skip_if_no_terra()
  cd <- .make_fake_bundle()
  for (lyr in c("first_anomaly", "anomaly_index", "modelled_pixels")) {
    r <- read_fordead_layer(NULL, zone_id = 1L, layer = lyr, cache_dir = cd)
    expect_s4_class(r, "SpatRaster")
    expect_equal(terra::nlyr(r), 1L)
  }
})


test_that("read_fordead_layer returns NULL when the layer file is absent", {
  skip_if_no_terra()
  cd <- .make_fake_bundle(layers = "first_anomaly")  # no anomaly_index
  expect_null(read_fordead_layer(NULL, zone_id = 1L,
                                 layer = "anomaly_index", cache_dir = cd))
})


test_that("read_fordead_layer returns NULL with no bundle / bad cache_dir", {
  skip_if_no_terra()
  expect_null(read_fordead_layer(NULL, 1L, "first_anomaly", cache_dir = NULL))
  expect_null(read_fordead_layer(NULL, 1L, "first_anomaly",
                                 cache_dir = withr::local_tempdir()))
})


test_that("read_fordead_layer rejects an unknown layer", {
  expect_error(
    read_fordead_layer(NULL, 1L, "not_a_layer", cache_dir = "."),
    "layer")
})


test_that("read_fordead_layer rejects a bad zone_id", {
  skip_if_no_terra()
  cd <- .make_fake_bundle()
  expect_error(
    read_fordead_layer(NULL, NA, "first_anomaly", cache_dir = cd),
    "zone_id")
})


test_that("read_fordead_layer picks the latest run when run_id is NULL", {
  skip_if_no_terra()
  cd <- .make_fake_bundle(run_id = "20190101T120000")
  # add a newer bundle with a distinct value
  md2 <- file.path(cd, "zone_1", "model_20200101T120000")
  dir.create(md2, recursive = TRUE, showWarnings = FALSE)
  tmpl <- terra::rast(nrows = 4, ncols = 5, xmin = 0, xmax = 50,
                      ymin = 0, ymax = 40, crs = "EPSG:2154")
  terra::values(tmpl) <- rep(42, 20)
  terra::writeRaster(tmpl, file.path(md2, "first_anomaly.tif"))

  r <- read_fordead_layer(NULL, 1L, "first_anomaly", cache_dir = cd)
  expect_equal(unique(terra::values(r)[, 1]), 42)  # latest run
})
