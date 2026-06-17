# test-extract-trend-series.R — spec 023: zone-level trend trajectory
# (yearly seasonal composite series + Theil-Sen / Mann-Kendall fit) that
# feeds the "when does the decline set in" graph. No DB, no STAC: a small
# synthetic on-disk NDRE cache with a deliberate multi-year decline.

# Fixture: one declining-NDRE cache. B8A fixed, B05 rising each year ->
# NDRE = (B8A - B05) / (B8A + B05) falls monotonically. Two summer scenes
# per year (>= min_obs_per_year) over `years`. Native 20 m, EPSG:32631.
.write_ndre_decline_cache <- function(cache, years = 2017:2024, tile = "T31TFM") {
  for (k in seq_along(years)) {
    y    <- years[k]
    b05  <- 0.05 + (k - 1) * 0.03            # rises -> NDRE falls
    vals <- c(B8A = 0.50, B05 = b05)
    for (mo in c("07", "08")) {
      sid <- sprintf("S2A_MSIL2A_%d%s15T103041_R108_%s_x", y, mo, tile)
      d   <- file.path(cache, sid)
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
  invisible(NULL)
}

.fake_con <- function() structure(list(), class = c("FakeConn", "DBIConnection"))


test_that("extract_trend_series returns a declining, significant NDRE series", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  .write_ndre_decline_cache(cache, years = 2017:2024)

  tr <- suppressMessages(extract_trend_series(
    .fake_con(), zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    cache_dir = cache, apply_zone_mask = FALSE))

  expect_type(tr, "list")
  expect_named(tr, c("series", "fit", "index", "months", "alpha", "min_slope"))
  expect_identical(tr$index, "NDRE")

  # One row per in-season year, ascending, two scenes each.
  expect_identical(tr$series$year, 2017:2024)
  expect_true(all(tr$series$n_scenes == 2L))
  expect_false(anyNA(tr$series$value))
  # NDRE declines monotonically across years (the whole point of the graph).
  expect_true(all(diff(tr$series$value) < 0))

  # Fit: a real, significant decline -> alert == abs(slope).
  expect_false(is.null(tr$fit))
  expect_lt(tr$fit$slope, 0)
  expect_true(tr$fit$significant)
  expect_lt(tr$fit$p_value, 0.05)
  expect_equal(tr$fit$alert, abs(tr$fit$slope))
  expect_identical(tr$fit$n_years, 8L)

  # Fitted line is present for every year and itself declines.
  expect_false(anyNA(tr$series$fitted))
  expect_true(all(diff(tr$series$fitted) < 0))
})


test_that("extract_trend_series fit is NULL below min_years", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  .write_ndre_decline_cache(cache, years = 2017:2019)   # 3 years < min_years 4

  tr <- suppressMessages(extract_trend_series(
    .fake_con(), zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    cache_dir = cache, apply_zone_mask = FALSE))

  expect_identical(tr$series$year, 2017:2019)
  expect_null(tr$fit)
  expect_true(all(is.na(tr$series$fitted)))   # no fit -> no fitted line
})


test_that("extract_trend_series returns NULL with no in-season scene", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  .write_ndre_decline_cache(cache, years = 2017:2024)   # all July/Aug

  # A winter-only window (months 1:2) keeps no scene -> NULL.
  tr <- suppressMessages(extract_trend_series(
    .fake_con(), zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    months = 1:2, cache_dir = cache, apply_zone_mask = FALSE))

  expect_null(tr)
})


test_that("extract_trend_series validates its inputs", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  expect_error(
    extract_trend_series(.fake_con(), zone_id = 1L,
                         date_from = "bad", date_to = "2024-12-31",
                         cache_dir = cache),
    "must parse as Date")
  expect_error(
    extract_trend_series(.fake_con(), zone_id = 1L,
                         date_from = "2017-01-01", date_to = "2024-12-31",
                         cache_dir = "/no/such/dir"),
    "existing path")
  expect_error(
    extract_trend_series(.fake_con(), zone_id = 1L,
                         date_from = "2017-01-01", date_to = "2024-12-31",
                         months = c(0L, 13L), cache_dir = cache),
    "must be integers in 1:12")
})
