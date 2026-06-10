# Tests for the NDRE index (spec 022) — red-edge index added to the FAST
# subsystem as the early-stress marker that feeds the trend mode. No
# network, no DB: a small synthetic S2 cache with constant band values so
# the index math is exactly predictable.

# Fixture: one scene with B04/B08 at 10 m and B8A/B05 at 20 m, constant
# per band so (B8A - B05)/(B8A + B05) is a known value.
.ndre_fixture <- function(dir, b8a = 0.5, b05 = 0.1, b04 = 0.2, b08 = 0.4) {
  sid <- "S2_NDRE_001"
  sd  <- file.path(dir, sid)
  dir.create(sd, recursive = TRUE, showWarnings = FALSE)
  vals <- list(B04 = b04, B08 = b08, B8A = b8a, B05 = b05)
  for (b in names(vals)) {
    res <- if (b %in% c("B8A", "B05")) 20 else 10
    nc  <- if (b %in% c("B8A", "B05")) 15L else 30L
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


test_that("read_s2_band_raster accepts B05 and B8A", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sc <- .ndre_fixture(cache)
  for (b in c("B05", "B8A")) {
    r <- read_s2_band_raster(cache, sc$scene_id[1], b)
    expect_s4_class(r, "SpatRaster")
    expect_equal(terra::res(r), c(20, 20))
  }
})


test_that("build_index_stack computes NDRE = (B8A - B05)/(B8A + B05)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sc <- .ndre_fixture(cache, b8a = 0.5, b05 = 0.1)   # -> 0.4 / 0.6
  st <- build_index_stack(cache, sc, index = "NDRE")
  expect_s4_class(st, "SpatRaster")
  expect_identical(attr(st, "index"), "NDRE")
  expect_equal(unname(terra::global(st, "mean", na.rm = TRUE)[1, 1]),
               0.4 / 0.6, tolerance = 1e-6)
  # Both source bands are native 20 m, so NDRE stays at 20 m (no resample).
  expect_equal(terra::res(st), c(20, 20))
})


test_that("extract_pixel_timeseries returns an NDRE series", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sc <- .ndre_fixture(cache, b8a = 0.5, b05 = 0.1)
  ts <- extract_pixel_timeseries(cache, sc, c(644150, 5235150),
                                 crs = 2154, indices = "NDRE")
  expect_true("NDRE" %in% ts$index)
  expect_equal(ts$value[ts$index == "NDRE"][1], 0.4 / 0.6, tolerance = 1e-6)
})


test_that("extract_pixel_timeseries(NDRE-only) works without B08 in cache", {
  # Regression (spec 022): the native-CRS reference was hard-coded to
  # rs[["B08"]], which is NULL for an NDRE-only request (only B8A/B05 are
  # loaded) -> terra::crs(NULL) crashed before the NDRE calculation. A
  # cache holding *only* the two red-edge bands must still work.
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sid <- "S2_NDREONLY_001"
  sd  <- file.path(cache, sid)
  dir.create(sd, recursive = TRUE, showWarnings = FALSE)
  for (b in c("B8A", "B05")) {
    val <- if (b == "B8A") 0.5 else 0.1   # NDRE = 0.4 / 0.6
    r <- terra::rast(nrows = 15, ncols = 15,
                     xmin = 644000, xmax = 644300,
                     ymin = 5235000, ymax = 5235300,
                     crs = "EPSG:2154", vals = rep(val, 225))
    terra::writeRaster(r, file.path(sd, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  sc <- data.frame(scene_id = sid, obs_date = as.Date("2026-01-15"),
                   stringsAsFactors = FALSE)
  ts <- extract_pixel_timeseries(cache, sc, c(644150, 5235150),
                                 crs = 2154, indices = "NDRE")
  expect_true("NDRE" %in% ts$index)
  expect_equal(ts$value[ts$index == "NDRE"][1], 0.4 / 0.6, tolerance = 1e-6)
})


test_that(".s2_required_bands maps NDRE to B05 + B8A", {
  expect_setequal(nemeton:::.s2_required_bands("NDRE"), c("B05", "B8A"))
  expect_setequal(nemeton:::.s2_required_bands(c("NDVI", "NDRE")),
                  c("B04", "B08", "B05", "B8A"))
})


test_that("build_index_stack(NDRE) aborts when no scene carries B05/B8A", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  # An NDVI-only cache: B04 + B08 present, no red-edge bands at all.
  sid <- "S2_NDVIONLY_001"
  sd  <- file.path(cache, sid)
  dir.create(sd, recursive = TRUE, showWarnings = FALSE)
  for (b in c("B04", "B08")) {
    r <- terra::rast(nrows = 4, ncols = 4, vals = 1)
    terra::writeRaster(r, file.path(sd, paste0(b, ".tif")), overwrite = TRUE)
  }
  sc <- data.frame(scene_id = sid, obs_date = as.Date("2026-01-15"),
                   stringsAsFactors = FALSE)
  expect_error(build_index_stack(cache, sc, index = "NDRE"),
               "never ingested|No cached scene carries")
  # The same cache still serves NDVI without error (non-regression).
  expect_s4_class(build_index_stack(cache, sc, index = "NDVI"), "SpatRaster")
})


test_that(".assert_cache_has_bands aborts on an empty / missing cache", {
  skip_if_not_installed("withr")
  expect_error(nemeton:::.assert_cache_has_bands(tempfile(), c("B05", "B8A")),
               "cache directory not found")
  empty <- withr::local_tempdir()
  expect_error(nemeton:::.assert_cache_has_bands(empty, c("B05", "B8A")),
               "No cached scene carries")
})


test_that("extract_pixel_timeseries(NDRE) aborts when red-edge never cached", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  sid <- "S2_NDVIONLY_002"
  sd  <- file.path(cache, sid)
  dir.create(sd, recursive = TRUE, showWarnings = FALSE)
  for (b in c("B04", "B08")) {
    r <- terra::rast(nrows = 4, ncols = 4, vals = 1)
    terra::writeRaster(r, file.path(sd, paste0(b, ".tif")), overwrite = TRUE)
  }
  sc <- data.frame(scene_id = sid, obs_date = as.Date("2026-01-15"),
                   stringsAsFactors = FALSE)
  expect_error(
    extract_pixel_timeseries(cache, sc, c(1, 1), crs = 2154,
                             indices = "NDRE"),
    "No cached scene carries|never ingested")
})
