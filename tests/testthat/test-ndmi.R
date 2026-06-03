# Tests for the NDMI index (spec 019) — moisture index added to the FAST
# subsystem. No network, no DB: a small synthetic S2 cache with constant
# band values so the index math is exactly predictable.

# Fixture: one scene with B04/B08 at 10 m and B12/B11 at 20 m, constant
# per band so (B08 - B11)/(B08 + B11) is a known value.
.ndmi_fixture <- function(dir, b08 = 0.5, b11 = 0.1, b04 = 0.2, b12 = 0.15) {
  sid <- "S2_NDMI_001"
  sd  <- file.path(dir, sid)
  dir.create(sd, recursive = TRUE, showWarnings = FALSE)
  vals <- list(B04 = b04, B08 = b08, B12 = b12, B11 = b11)
  for (b in names(vals)) {
    res <- if (b %in% c("B12", "B11")) 20 else 10
    nc  <- if (b %in% c("B12", "B11")) 15L else 30L
    r <- terra::rast(nrows = nc, ncols = nc,
                     xmin = 644000, xmax = 644000 + nc * res,
                     ymin = 5235000, ymax = 5235000 + nc * res,
                     crs = "EPSG:2154", vals = rep(vals[[b]], nc * nc))
    terra::writeRaster(r, file.path(sd, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  data.frame(scene_id = sid, obs_date = as.Date("2026-01-15"),
             stringsAsFactors = FALSE)
}


test_that("read_s2_band_raster accepts B11", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sc <- .ndmi_fixture(cache)
  r <- read_s2_band_raster(cache, sc$scene_id[1], "B11")
  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::res(r), c(20, 20))
})


test_that("build_index_stack computes NDMI = (B08 - B11)/(B08 + B11)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sc <- .ndmi_fixture(cache, b08 = 0.5, b11 = 0.1)   # -> 0.4 / 0.6
  st <- build_index_stack(cache, sc, index = "NDMI")
  expect_s4_class(st, "SpatRaster")
  expect_equal(unname(terra::global(st, "mean", na.rm = TRUE)[1, 1]),
               0.4 / 0.6, tolerance = 1e-6)
})


test_that("extract_pixel_timeseries returns an NDMI series", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sc <- .ndmi_fixture(cache, b08 = 0.5, b11 = 0.1)
  ts <- extract_pixel_timeseries(cache, sc, c(644150, 5235150),
                                 crs = 2154, indices = "NDMI")
  expect_true("NDMI" %in% ts$index)
  expect_equal(ts$value[ts$index == "NDMI"][1], 0.4 / 0.6, tolerance = 1e-6)
})


test_that(".s2_required_bands maps NDMI to B08 + B11", {
  expect_setequal(nemeton:::.s2_required_bands("NDMI"), c("B08", "B11"))
  expect_setequal(nemeton:::.s2_required_bands(c("NDVI", "NDMI")),
                  c("B04", "B08", "B11"))
})


test_that(".cache_scene_bands tolerates a missing optional band", {
  # B11 best-effort (spec 019 D3): a scene without the asset must not
  # fail the ingestion of the required bands.
  testthat::local_mocked_bindings(
    .get_s2_band_raster = function(scene, band, ...) {
      if (band == "B11") stop("no asset for B11")
      invisible(NULL)
    },
    .package = "nemeton")
  n <- nemeton:::.cache_scene_bands(
    scene = data.frame(scene_id = "x"), req_bands = c("B08"),
    crop_aoi = "dummy", optional_bands = "B11")
  expect_equal(n, 1L)   # 1 required cached, B11 skipped (not counted)
})


test_that("default FAST index is still NDVI (back-compat)", {
  expect_identical(formals(read_fast_alert_raster)$index,
                   quote(c("NDVI", "NBR", "NDMI")))
  # match.arg() takes the first element -> NDVI remains the default.
  expect_identical(eval(formals(read_fast_alert_raster)$index)[1], "NDVI")
})
