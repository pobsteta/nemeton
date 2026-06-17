# test-extract-pixel-trend.R — spec 023: the single-pixel counterpart of the
# FAST trend raster. The clicked-pixel composite series + Theil-Sen /
# Mann-Kendall must match `read_fast_alert_raster(mode = "trend")` at the same
# pixel. No DB, no STAC — a small synthetic, spatially-CONSTANT NDRE cache so
# the trend is uniform across space (every pixel == the one fitted value).

# Spatially-constant NDRE cache: B8A fixed, B05 rising each year so
# NDRE = (B8A - B05)/(B8A + B05) declines. `b05_of(k)` controls the per-year
# B05; the default rises (decline). Two summer scenes/year. EPSG:32631.
.write_pixel_trend_cache <- function(cache, years = 2017:2024,
                                     b05_of = function(k) 0.05 + (k - 1) * 0.03) {
  sids <- character(0)
  for (k in seq_along(years)) {
    y    <- years[k]
    vals <- c(B8A = 0.50, B05 = b05_of(k))
    for (mo in c("07", "08")) {
      sid <- sprintf("S2A_MSIL2A_%d%s15T103041_R108_T31TFM_x", y, mo)
      sids <- c(sids, sid)
      d <- file.path(cache, sid)
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      for (b in names(vals)) {
        r <- terra::rast(nrows = 8, ncols = 8, xmin = 0, xmax = 160,
                         ymin = 0, ymax = 160, crs = "EPSG:32631",
                         vals = rep(vals[[b]], 64))
        terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                           filetype = "GTiff", overwrite = TRUE)
      }
    }
  }
  data.frame(
    scene_id = sids,
    obs_date = as.Date(sprintf("%d-%s-15",
                               rep(years, each = 2L),
                               rep(c("07", "08"), times = length(years)))),
    stringsAsFactors = FALSE)
}

.PT_XY <- c(80, 80)   # inside the 0..160 native extent (EPSG:32631)


test_that("extract_pixel_trend flags a significant NDRE decline", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  scenes <- .write_pixel_trend_cache(cache, years = 2017:2024)

  tr <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE"))

  expect_type(tr, "list")
  expect_identical(tr$index, "NDRE")
  expect_identical(tr$composites$year, 2017:2024)
  expect_false(anyNA(tr$composites$value))
  expect_true(all(diff(tr$composites$value) < 0))   # declining composites
  expect_identical(tr$n_years, 8L)
  expect_true(tr$enough_years)

  expect_lt(tr$theil_sen_slope, 0)
  expect_lt(tr$mann_kendall_p, 0.05)
  expect_true(tr$significant_decline)
  expect_equal(tr$alert_value, abs(tr$theil_sen_slope))
})


test_that("extract_pixel_trend: flat series is not an alert", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  scenes <- .write_pixel_trend_cache(cache, years = 2017:2024,
                                     b05_of = function(k) 0.20)  # constant

  tr <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE"))

  expect_true(tr$enough_years)
  expect_false(tr$significant_decline)
  expect_equal(tr$alert_value, 0)
})


test_that("extract_pixel_trend: min_slope rejects a negligible decline", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  # A tiny but strictly-monotonic decline: B05 creeps up ~0.0005/yr -> NDRE
  # slope ~ -0.001/yr. Mann-Kendall flags it (perfectly monotonic), but it is
  # ecologically negligible — exactly the noise the min_slope gate filters.
  scenes <- .write_pixel_trend_cache(cache, years = 2017:2024,
                                     b05_of = function(k) 0.20 + (k - 1) * 0.0005)

  # Default min_slope (0.005): significant test passes but magnitude too small
  # -> NOT an alert.
  tr <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE"))
  expect_true(tr$enough_years)
  expect_lt(abs(tr$theil_sen_slope), 0.005)   # genuinely tiny slope
  expect_lt(tr$mann_kendall_p, 0.05)          # yet statistically significant
  expect_false(tr$significant_decline)        # min_slope gate rejects it
  expect_equal(tr$alert_value, 0)

  # min_slope = 0 restores the pure significance test -> the decline IS flagged.
  tr0 <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE", min_slope = 0))
  expect_true(tr0$significant_decline)
  expect_gt(tr0$alert_value, 0)
})


test_that("extract_pixel_trend: below min_years -> alert_value NA", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  scenes <- .write_pixel_trend_cache(cache, years = 2017:2019)   # 3 < 4

  tr <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE"))

  expect_identical(tr$n_years, 3L)
  expect_false(tr$enough_years)
  expect_false(tr$significant_decline)
  expect_true(is.na(tr$alert_value))
})


test_that("extract_pixel_trend: NULL when no in-season scene", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  scenes <- .write_pixel_trend_cache(cache, years = 2017:2024)

  tr <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE", months = 1:2))   # winter window -> nothing in season
  expect_null(tr)
})


test_that("extract_pixel_trend == read_fast_alert_raster(trend) at the pixel", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  scenes <- .write_pixel_trend_cache(cache, years = 2017:2024)

  tr <- suppressMessages(extract_pixel_trend(
    cache_dir = cache, scenes_df = scenes, xy = .PT_XY, crs = 32631,
    index = "NDRE"))

  # The raster path: same cache, same trend params, projected to EPSG:2154.
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  rast <- suppressMessages(read_fast_alert_raster(
    con, zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    mode = "trend", cache_dir = cache,
    apply_zone_mask = FALSE, cache_result = FALSE))
  expect_s4_class(rast, "SpatRaster")

  # Extract the raster's pre-quartile value at the same point (reprojected to
  # the raster CRS, EPSG:2154). The cache is spatially constant, so the trend
  # raster is uniform and the value equals the pixel-level alert_value.
  pt <- sf::st_transform(sf::st_sfc(sf::st_point(.PT_XY), crs = 32631),
                         sf::st_crs(rast))
  rv <- terra::extract(rast, terra::vect(pt))[1, 2]

  expect_equal(rv, tr$alert_value, tolerance = 1e-6)
  expect_gt(tr$alert_value, 0)   # this fixture is a real, significant decline
})
