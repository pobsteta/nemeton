# test-fast-trend.R — spec 023 (FAST `mode = "trend"`): multi-year
# monotonic decline via Theil-Sen + Mann-Kendall. No network, no DB:
# synthetic COG caches / stacks with predictable values.

# ---- maths helpers ----------------------------------------------------

test_that(".theil_sen recovers a known slope and ignores tied x", {
  expect_equal(nemeton:::.theil_sen(1:5, 2 * (1:5) + 3), 2, tolerance = 1e-9)
  expect_equal(nemeton:::.theil_sen(1:5, -0.5 * (1:5)), -0.5, tolerance = 1e-9)
  # Robust to a single outlier (median of pairwise slopes).
  y <- c(1, 2, 3, 100, 5)
  expect_equal(nemeton:::.theil_sen(1:5, y), 1, tolerance = 1e-9)
  # < 2 points or all-tied x -> NA.
  expect_true(is.na(nemeton:::.theil_sen(1, 1)))
  expect_true(is.na(nemeton:::.theil_sen(c(2, 2, 2), c(1, 2, 3))))
})


test_that(".mann_kendall flags a monotonic decline and clears flat / short", {
  mk <- function(y) nemeton:::.mann_kendall(y)
  dec <- mk(c(0.9, 0.7, 0.5, 0.3, 0.1))      # strictly decreasing, n = 5
  expect_lt(dec$S, 0)
  expect_lt(dec$p, 0.05)
  expect_equal(dec$tau, -1, tolerance = 1e-9)

  inc <- mk(c(1, 2, 3, 4, 5))
  expect_gt(inc$S, 0)
  expect_lt(inc$p, 0.05)

  # Flat series: zero variance -> p undefined (NA), never a false positive.
  flat <- mk(rep(0.5, 5))
  expect_true(is.na(flat$p))

  # n < 3 -> undefined.
  expect_true(is.na(mk(c(1, 2))$p))
})


# ---- .fast_raster_trend on a synthetic yearly stack -------------------

# Build a stack of 4x4 layers with `terra::time()` set. `cell_series` is a
# named list mapping a cell index (1..16) to its value on every layer;
# unlisted cells are constant 0.5. `dates` gives one Date per layer.
.trend_stack <- function(dates, cell_values) {
  n <- length(dates)
  layers <- lapply(seq_len(n), function(i) {
    m <- matrix(0.5, 4, 4)
    for (cell in names(cell_values)) {
      m[as.integer(cell)] <- cell_values[[cell]][i]
    }
    r <- terra::rast(m, crs = "EPSG:32631")
    terra::ext(r) <- terra::ext(0, 4, 0, 4)
    r
  })
  out <- terra::rast(layers)
  terra::time(out) <- as.Date(dates)
  out
}


test_that(".fast_raster_trend: decline > 0, flat = 0, short = NA", {
  skip_if_not_installed("terra")
  # 5 years, 2 summer obs each (months 7 & 8). min_years = 4.
  yrs   <- 2019:2023
  dates <- as.Date(unlist(lapply(yrs, function(y)
    c(sprintf("%d-07-15", y), sprintf("%d-08-15", y)))))

  # Cell 1: strict decline (both obs equal within a year).
  dec_vals <- rep(c(0.9, 0.7, 0.5, 0.3, 0.1), each = 2)
  # Cell 2: flat 0.5 (the matrix default) -> leave unset.
  # Cell 3: data only in 2019 (2 obs), NA afterwards -> 1 valid year.
  short_vals <- c(0.8, 0.8, rep(NA_real_, 8))

  stk <- .trend_stack(dates, list("1" = dec_vals, "3" = short_vals))

  out <- nemeton:::.fast_raster_trend(
    stk, months = 6:9, min_years = 4L, min_obs_per_year = 2L, alpha = 0.05)
  expect_s4_class(out, "SpatRaster")
  v <- terra::values(out)[, 1]

  expect_gt(v[1], 0)                 # significant decline -> magnitude
  expect_equal(v[1], 0.2, tolerance = 1e-6)  # ~0.2 index units / year
  expect_equal(v[2], 0)              # flat -> no alert
  expect_true(is.na(v[3]))           # < min_years valid -> NA
})


test_that(".fast_raster_trend: noisy non-monotonic series is not flagged", {
  skip_if_not_installed("terra")
  yrs   <- 2019:2024
  dates <- as.Date(unlist(lapply(yrs, function(y)
    c(sprintf("%d-07-15", y), sprintf("%d-08-15", y)))))
  set.seed(1)
  noise <- rep(0.5 + stats::runif(length(yrs), -0.02, 0.02), each = 2)
  stk <- .trend_stack(dates, list("1" = noise))
  out <- nemeton:::.fast_raster_trend(
    stk, months = 6:9, min_years = 4L, min_obs_per_year = 2L, alpha = 0.05)
  expect_equal(terra::values(out)[1, 1], 0)
})


test_that(".fast_raster_trend: a year below min_obs_per_year is dropped", {
  skip_if_not_installed("terra")
  # Decline across 4 years, but 2023 has a single obs -> that year drops,
  # leaving 3 valid years < min_years = 4 -> NA.
  dates <- as.Date(c("2020-07-15", "2020-08-15",
                     "2021-07-15", "2021-08-15",
                     "2022-07-15", "2022-08-15",
                     "2023-07-15"))                 # 2023: lone obs
  vals <- c(0.9, 0.9, 0.7, 0.7, 0.5, 0.5, 0.3)
  stk  <- .trend_stack(dates, list("1" = vals))
  out  <- nemeton:::.fast_raster_trend(
    stk, months = 6:9, min_years = 4L, min_obs_per_year = 2L, alpha = 0.05)
  expect_true(is.na(terra::values(out)[1, 1]))
})


test_that(".fast_raster_trend: out-of-season scenes are excluded", {
  skip_if_not_installed("terra")
  # All scenes in winter (months 1-2), summer window 6:9 -> nothing in
  # season -> NULL.
  dates <- as.Date(c("2020-01-15", "2021-01-15", "2022-01-15", "2023-01-15"))
  stk <- .trend_stack(dates, list("1" = c(0.9, 0.7, 0.5, 0.3)))
  expect_null(nemeton:::.fast_raster_trend(
    stk, months = 6:9, min_years = 4L, min_obs_per_year = 2L, alpha = 0.05))
})


# ---- read_fast_alert_raster + compute_fast_alert_mask (mode=trend) ----

# Write a synthetic NDMI cache: 2 summer scenes per year for `years`, with
# B08 fixed and B11 rising each year so NDMI = (B08-B11)/(B08+B11) falls.
.write_trend_ndmi_cache <- function(cache, years, b08 = 0.5,
                                    b11_start = 0.05, b11_step = 0.05) {
  for (k in seq_along(years)) {
    y   <- years[k]
    b11 <- b11_start + (k - 1) * b11_step
    for (mo in c("07", "08")) {
      sid <- sprintf("S2A_MSIL2A_%d%s15T103421_N0510_R108_T31TFM_%d%s15T140012",
                     y, mo, y, mo)
      sd <- file.path(cache, sid)
      dir.create(sd, recursive = TRUE, showWarnings = FALSE)
      for (b in c("B08", "B11")) {
        val <- if (b == "B08") b08 else b11
        r <- terra::rast(nrows = 8, ncols = 8,
                         xmin = 644000, xmax = 644160,
                         ymin = 5235000, ymax = 5235160,
                         crs = "EPSG:32631", vals = rep(val, 64))
        terra::writeRaster(r, file.path(sd, paste0(b, ".tif")),
                           filetype = "GTiff", overwrite = TRUE)
      }
    }
  }
}


test_that("read_fast_alert_raster(mode='trend') returns a cached EPSG:2154 raster", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_trend_ndmi_cache(cache, years = 2019:2023)   # 5 declining years
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  r <- suppressMessages(read_fast_alert_raster(
    con, 1L, index = "NDMI", mode = "trend",
    date_from = "2019-01-01", date_to = "2023-12-31",
    cache_dir = cache, apply_zone_mask = FALSE,
    result_cache_dir = rcache))

  expect_s4_class(r, "SpatRaster")
  expect_equal(sf::st_crs(r)$epsg, 2154L)
  expect_identical(names(r), "alert_trend")
  expect_identical(attr(r, "mode"), "trend")
  rng <- terra::minmax(r)
  expect_true(rng[1, 1] >= 0)                # continuous, non-negative

  # Persisted under a trend-named COG, served from cache on revisit.
  cogs <- list.files(file.path(rcache, "zone_1"),
                     pattern = "^fast_NDMI_trend_.*\\.tif$")
  expect_length(cogs, 1L)
  r2 <- suppressMessages(read_fast_alert_raster(
    con, 1L, index = "NDMI", mode = "trend",
    date_from = "2019-01-01", date_to = "2023-12-31",
    cache_dir = cache, apply_zone_mask = FALSE, result_cache_dir = rcache))
  expect_true(isTRUE(attr(r2, "cached")))
})


test_that("compute_fast_alert_mask(mode='trend') writes a 0-4 mask unchanged", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache <- withr::local_tempdir()
  mcache <- withr::local_tempdir()
  .write_trend_ndmi_cache(cache, years = 2019:2024)   # 6 declining years
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  out_path <- suppressMessages(compute_fast_alert_mask(
    con, 1L, index = "NDMI", mode = "trend",
    date_from = "2019-01-01", date_to = "2024-12-31",
    cache_dir = cache, mask_cache_dir = mcache, apply_zone_mask = FALSE))

  expect_true(file.exists(out_path))
  mask <- terra::rast(out_path)
  vals <- terra::values(mask, mat = FALSE)
  vals <- vals[!is.na(vals)]
  expect_true(all(vals %in% 0:4))           # the shared 0-4 scale
})


test_that("trend default index is NDMI (mode-dependent default)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("withr")
  cache  <- withr::local_tempdir()
  .write_trend_ndmi_cache(cache, years = 2019:2023)
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  # `index` omitted + mode = trend -> NDMI is picked (the cache has B08/B11
  # but no B04, so an NDVI default would find no scene and return NULL).
  r <- suppressMessages(read_fast_alert_raster(
    con, 1L, mode = "trend",
    date_from = "2019-01-01", date_to = "2023-12-31",
    cache_dir = cache, apply_zone_mask = FALSE, cache_result = FALSE))
  expect_s4_class(r, "SpatRaster")
  expect_identical(attr(r, "index"), "NDMI")
})


# ---- trend parameter validation + cache keying -----------------------

test_that("trend mode validates alpha / months / min_years", {
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  base <- list(con, 1L, mode = "trend",
               date_from = "2019-01-01", date_to = "2023-12-31",
               cache_dir = tempdir(), apply_zone_mask = FALSE)
  expect_error(do.call(read_fast_alert_raster, c(base, list(alpha = 0))),
               "in \\(0, 1\\)")
  expect_error(do.call(read_fast_alert_raster, c(base, list(alpha = 1.2))),
               "in \\(0, 1\\)")
  expect_error(do.call(read_fast_alert_raster, c(base, list(months = c(0, 13)))),
               "1:12")
  expect_error(do.call(read_fast_alert_raster, c(base, list(min_years = 1))),
               ">= 2")
})


test_that(".fast_raster_hash keys trend on alpha / months / min_years", {
  h <- function(...) nemeton:::.fast_raster_hash(...)
  base <- h(c("a"), "NDMI", NULL, "trend", 30L, "2019-01-01", "2023-12-31", NA,
            alpha = 0.05, months = 6:9, min_years = 4L, min_obs_per_year = 2L)
  expect_false(identical(base,
    h(c("a"), "NDMI", NULL, "trend", 30L, "2019-01-01", "2023-12-31", NA,
      alpha = 0.10, months = 6:9, min_years = 4L, min_obs_per_year = 2L)))
  expect_false(identical(base,
    h(c("a"), "NDMI", NULL, "trend", 30L, "2019-01-01", "2023-12-31", NA,
      alpha = 0.05, months = 7:8, min_years = 4L, min_obs_per_year = 2L)))
  expect_false(identical(base,
    h(c("a"), "NDMI", NULL, "trend", 30L, "2019-01-01", "2023-12-31", NA,
      alpha = 0.05, months = 6:9, min_years = 5L, min_obs_per_year = 2L)))
  # Threshold is irrelevant in trend mode (dropped from the hash).
  expect_identical(base,
    h(c("a"), "NDMI", 0.99, "trend", 30L, "2019-01-01", "2023-12-31", NA,
      alpha = 0.05, months = 6:9, min_years = 4L, min_obs_per_year = 2L))
})


test_that(".fast_raster_filename emits a trend-specific name", {
  fn <- nemeton:::.fast_raster_filename(
    "NDMI", "trend", NULL, "2019-01-01", "2023-12-31", 30L,
    "deadbeefcafef00d", alpha = 0.05, months = 6:9, min_years = 4L)
  expect_match(fn,
    "^fast_NDMI_trend_a0\\.050_m6789_y4_2019-01-01_2023-12-31_deadbeef\\.tif$")
})


test_that("count / rolling hash is unchanged by the new trend args (back-compat)", {
  h <- function(...) nemeton:::.fast_raster_hash(...)
  # 8-positional-arg call (pre-spec-023 signature) still works and matches
  # the same call made today — trend args are appended only for trend.
  old <- h(c("a", "b"), "NDVI", 0.4, "count", 30L, "2025-01-01", "2025-12-31", NA)
  new <- h(c("a", "b"), "NDVI", 0.4, "count", 30L, "2025-01-01", "2025-12-31", NA,
           alpha = 0.05, months = 6:9, min_years = 4L, min_obs_per_year = 2L)
  expect_identical(old, new)
})
