# test-zone-mask.R — spec 016 v0.49.0
# Tests for .apply_zone_mask() and the new apply_zone_mask /
# mask_polygon arguments on the reader/computer exports.

test_that(".apply_zone_mask is a no-op when zone_polygon is NULL", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 4, ncols = 4,
                   xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                   crs = "EPSG:2154", vals = 1:16)
  out <- nemeton:::.apply_zone_mask(r, NULL)
  expect_true(terra::compareGeom(out, r, stopOnError = FALSE))
  expect_equal(as.numeric(terra::values(out)), 1:16)
})


test_that(".apply_zone_mask is a no-op when raster is not a SpatRaster", {
  expect_equal(nemeton:::.apply_zone_mask(42, NULL), 42)
  expect_equal(nemeton:::.apply_zone_mask("not a raster",
                                          sf::st_sfc(sf::st_point(c(0,0)),
                                                     crs = 4326)),
               "not a raster")
})


test_that(".apply_zone_mask sets NA outside the polygon", {
  skip_if_not_installed("terra")
  # 4x4 raster, cells 1..16. Polygon covers only the upper-left 2x2.
  r <- terra::rast(nrows = 4, ncols = 4,
                   xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                   crs = "EPSG:2154", vals = 1:16)
  # Square 20m × 20m in the upper-left of the raster.
  # terra::rast() values fill row-by-row from top → row 1 = NW
  # So upper-left 2x2 covers y in [20, 40], x in [0, 20].
  poly <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(0, 20), c(20, 20), c(20, 40), c(0, 40), c(0, 20)
    ))),
    crs = 2154)

  out <- nemeton:::.apply_zone_mask(r, poly)
  vals <- as.numeric(terra::values(out))
  # 4 cells should be non-NA (1, 2, 5, 6), the rest NA.
  expect_equal(sum(!is.na(vals)), 4L)
  expect_setequal(vals[!is.na(vals)], c(1, 2, 5, 6))
})


test_that(".apply_zone_mask reprojects the polygon to the raster CRS", {
  skip_if_not_installed("terra")
  # Build a raster in a known place (Jura, near villards) so we
  # can reason about CRS reprojection.
  r <- terra::rast(nrows = 10, ncols = 10,
                   xmin = 905000, xmax = 915000,
                   ymin = 6590000, ymax = 6600000,
                   crs = "EPSG:2154", vals = 1:100)
  # Polygon in EPSG:4326 covering all of France (rough bbox). After
  # reprojection to 2154, it must contain the Jura raster.
  poly_wgs <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(-5, 41), c(10, 41), c(10, 52), c(-5, 52), c(-5, 41)
    ))),
    crs = 4326)
  out <- nemeton:::.apply_zone_mask(r, poly_wgs)
  # Polygon reprojected should fully cover the Jura raster.
  vals <- as.numeric(terra::values(out))
  expect_true(all(!is.na(vals)))
})


test_that("read_fast_alert_raster(apply_zone_mask = FALSE) skips mask", {
  # Smoke test against villards if local cache + DB present.
  cache <- "/home/pascal/.local/share/nemeton/projects/20260520_212017_btfe/cache/layers/sentinel2"
  if (!dir.exists(cache)) testthat::skip("villards cache not present")
  skip_if_no_timescaledb()

  con <- db_connect(Sys.getenv("NEMETON_DB_URL_TEST",
                               Sys.getenv("NEMETON_DB_URL", "")))
  on.exit(db_disconnect(con))

  has_zone <- DBI::dbGetQuery(con,
    "SELECT count(*)::int AS n FROM monitoring_zone WHERE id = 1")$n > 0
  if (!has_zone) testthat::skip("zone_id=1 not in DB")

  # With mask (default)
  r_masked <- read_fast_alert_raster(
    con, zone_id = 1L,
    date_from = "2025-05-23", date_to = "2026-05-23",
    mode = "count", cache_dir = cache,
    apply_zone_mask = TRUE)

  # Without mask
  r_full <- read_fast_alert_raster(
    con, zone_id = 1L,
    date_from = "2025-05-23", date_to = "2026-05-23",
    mode = "count", cache_dir = cache,
    apply_zone_mask = FALSE)

  expect_s4_class(r_masked, "SpatRaster")
  expect_s4_class(r_full,   "SpatRaster")
  # Same extent (mask doesn't change bbox). terra::ext is S4 so use
  # the xmin/xmax/ymin/ymax accessors instead of as.numeric().
  expect_equal(terra::xmin(r_masked), terra::xmin(r_full))
  expect_equal(terra::xmax(r_masked), terra::xmax(r_full))
  expect_equal(terra::ymin(r_masked), terra::ymin(r_full))
  expect_equal(terra::ymax(r_masked), terra::ymax(r_full))
  # But masked has more NA cells than the un-masked one (villards is
  # ~30 % of its bbox, so ~70 % of pixels should turn NA).
  n_na_masked <- sum(is.na(terra::values(r_masked)))
  n_na_full   <- sum(is.na(terra::values(r_full)))
  expect_gt(n_na_masked, n_na_full)
})
