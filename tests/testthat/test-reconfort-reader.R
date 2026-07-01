# test-reconfort-reader.R — RECONFORT layer reader (L7, spec 021)
#   * read_reconfort_layer() path / manifest-row resolution
#   * apply_zone_mask: pixels outside the UGF polygon -> NA (spec 016 parity)
#   * opt-out apply_zone_mask = FALSE (raw raster)
#   * warn when masking requested but no polygon resolvable
#   * rejection of vector rows / multi-row / missing path

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
}

# A 10x10 EPSG:2154 raster, value = 1 everywhere, 10 m pixels.
make_score_raster <- function(path) {
  skip_if_no_terra()
  skip_if_terra_write_broken()   # runner terra::writeRaster anomaly
  r <- terra::rast(nrow = 10, ncol = 10,
                   xmin = 700000, xmax = 700100,
                   ymin = 6800000, ymax = 6800100,
                   crs = "EPSG:2154")
  terra::values(r) <- 1
  terra::writeRaster(r, path, overwrite = TRUE)
  path
}

# A square sf polygon covering the lower-left quarter of that raster.
quarter_polygon <- function() {
  skip_if_no_terra()
  testthat::skip_if_not_installed("sf")
  bbox <- sf::st_bbox(c(xmin = 700000, ymin = 6800000,
                        xmax = 700050, ymax = 6800050), crs = 2154)
  sf::st_as_sf(sf::st_as_sfc(bbox))
}

test_that("a bare path reads unmasked when apply_zone_mask = FALSE", {
  skip_if_no_terra()
  tf <- withr::local_tempfile(fileext = ".tif")
  make_score_raster(tf)
  r <- read_reconfort_layer(tf, apply_zone_mask = FALSE)
  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::global(r, "notNA")[[1]], 100)  # all 100 pixels kept
})

test_that("mask_polygon restricts the raster to the UGF polygon", {
  skip_if_no_terra()
  testthat::skip_if_not_installed("sf")
  tf <- withr::local_tempfile(fileext = ".tif")
  make_score_raster(tf)
  r <- read_reconfort_layer(tf, mask_polygon = quarter_polygon())
  # only the lower-left quarter (≈ 25 of 100 pixels) survives the mask
  kept <- terra::global(r, "notNA")[[1]]
  expect_gt(kept, 0)
  expect_lt(kept, 100)
})

test_that("a manifest raster row is accepted and resolved to its path", {
  skip_if_no_terra()
  tf <- withr::local_tempfile(fileext = ".tif")
  make_score_raster(tf)
  manifest <- reconfort_layer_manifest(
    list(rasters = list(continuous_score = tf)))
  row <- manifest[manifest$id == "score", ]
  r <- read_reconfort_layer(row, apply_zone_mask = FALSE)
  expect_s4_class(r, "SpatRaster")
})

test_that("a vector (alerts) manifest row is rejected", {
  skip_if_no_terra()
  testthat::skip_if_not_installed("sf")
  tf <- withr::local_tempfile(fileext = ".tif")
  make_score_raster(tf)
  manifest <- reconfort_layer_manifest(
    list(rasters = list(continuous_score = tf), n_alerts = 4))
  vrow <- manifest[manifest$id == "alerts", ]
  expect_error(read_reconfort_layer(vrow), "not a raster")
})

test_that("a multi-row manifest is rejected", {
  skip_if_no_terra()
  tf <- withr::local_tempfile(fileext = ".tif")
  make_score_raster(tf)
  manifest <- reconfort_layer_manifest(
    list(rasters = list(continuous_score = tf, classif = tf)))
  expect_error(read_reconfort_layer(manifest), "single manifest row")
})

test_that("a missing path errors out", {
  expect_error(read_reconfort_layer("/no/such/file.tif"), "not found")
  expect_error(read_reconfort_layer(NA_character_), "no usable raster path")
})

test_that("masking requested without a resolvable polygon warns and falls back", {
  skip_if_no_terra()
  tf <- withr::local_tempfile(fileext = ".tif")
  make_score_raster(tf)
  expect_warning(
    r <- read_reconfort_layer(tf, apply_zone_mask = TRUE),
    "no UGF polygon"
  )
  expect_equal(terra::global(r, "notNA")[[1]], 100)  # unmasked fallback
})
