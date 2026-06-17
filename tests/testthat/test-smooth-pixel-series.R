# test-smooth-pixel-series.R — spec 026: robust smoothing of the per-pixel
# spectral series (rolling median default, optional loess). Pure data — no
# raster, no DB.

# A long series like extract_pixel_timeseries() returns: obs_date / index /
# value. `mk_series()` builds a clean linear ramp per index with a few cloud
# spikes (sharp isolated drops) the median must absorb.
mk_series <- function(index = "NDVI", n = 40L, start = "2020-01-01",
                      base = 0.7, slope_per_day = 0,
                      spikes = integer(0), spike_val = 0.0) {
  d <- as.Date(start) + seq.int(0L, by = 10L, length.out = n)  # 10-day cadence
  v <- base + slope_per_day * as.numeric(d - d[1L])
  v[spikes] <- spike_val
  data.frame(obs_date = d, index = index, value = v,
             stringsAsFactors = FALSE)
}


test_that("smooth_pixel_series rejects a malformed input", {
  expect_error(smooth_pixel_series(list(a = 1)), "obs_date")
  ts <- mk_series()
  expect_error(smooth_pixel_series(ts, window_days = 0), "positive")
  expect_error(smooth_pixel_series(ts, min_obs = 0L), ">= 1")
})


test_that("rolling median absorbs isolated cloud spikes", {
  # A flat 0.7 series with two sharp drops to 0.0 (clouds). The median over a
  # 45-day window (~4-5 obs) must keep the level near 0.7 at the spikes.
  ts <- mk_series("NDVI", n = 40L, base = 0.7, spikes = c(10L, 25L),
                  spike_val = 0.0)
  sm <- smooth_pixel_series(ts, window_days = 45, method = "rolling_median")

  expect_true("smoothed" %in% names(sm))
  expect_equal(nrow(sm), nrow(ts))
  # At the spikes, the raw value is 0 but the smoothed value stays high.
  expect_equal(sm$value[c(10L, 25L)], c(0.0, 0.0))
  expect_true(all(sm$smoothed[c(10L, 25L)] > 0.6))
  # The smoothed series is far less variable than the raw one.
  expect_lt(stats::sd(sm$smoothed), stats::sd(sm$value))
})


test_that("smooth_pixel_series smooths each index independently", {
  ts <- rbind(
    mk_series("NDVI", base = 0.7, spikes = 5L, spike_val = 0.0),
    mk_series("NBR",  base = 0.4))
  sm <- smooth_pixel_series(ts, window_days = 45)

  expect_setequal(unique(sm$index), c("NDVI", "NBR"))
  # NBR (no spikes, flat 0.4) -> smoothed ~ 0.4 everywhere.
  nbr <- sm[sm$index == "NBR", ]
  expect_true(all(abs(nbr$smoothed - 0.4) < 1e-6))
  # NDVI spike is absorbed.
  ndvi <- sm[sm$index == "NDVI", ]
  expect_gt(ndvi$smoothed[5L], 0.6)
})


test_that("rolling median respects min_obs (NA when too sparse)", {
  # A single observation -> with min_obs = 3 the window never reaches 3 points.
  ts <- mk_series("NDVI", n = 1L)
  sm <- smooth_pixel_series(ts, window_days = 45, min_obs = 3L)
  expect_true(is.na(sm$smoothed))
  # min_obs = 1 -> the lone point smooths to itself.
  sm1 <- smooth_pixel_series(ts, window_days = 45, min_obs = 1L)
  expect_equal(sm1$smoothed, sm1$value)
})


test_that("NA values are ignored, not propagated", {
  ts <- mk_series("NDVI", n = 20L, base = 0.7)
  ts$value[c(3L, 4L, 5L)] <- NA_real_           # a cloudy gap
  sm <- smooth_pixel_series(ts, window_days = 45, min_obs = 2L)
  # The smoothed curve is still defined around the gap (neighbours present).
  expect_false(anyNA(sm$smoothed[8:20]))
  expect_true(all(abs(sm$smoothed[8:20] - 0.7) < 1e-6))
})


test_that("harmonic method is continuous across seasonal gaps", {
  # A seasonal signal (annual sine) sampled only in summer (months 5-9) over
  # 5 years, with cloud spikes -> the local methods leave winter NA, the
  # harmonic fit must return a continuous curve at EVERY date.
  yrs <- 2018:2022
  d   <- do.call(c, lapply(yrs, function(y)
    as.Date(sprintf("%d-%02d-15", y, 5:9))))   # 5 summer dates/year
  t   <- as.numeric(d)
  seasonal <- 0.6 + 0.2 * sin(2 * pi * t / 365.25)
  v   <- seasonal
  v[c(3L, 12L)] <- 0.0                          # two cloud spikes
  ts  <- data.frame(obs_date = d, index = "NDVI", value = v,
                    stringsAsFactors = FALSE)

  sm <- smooth_pixel_series(ts, method = "harmonic", n_harmonics = 2L)
  expect_true("smoothed" %in% names(sm))
  expect_false(anyNA(sm$smoothed))              # continuous, no gaps
  # Tracks the seasonal signal despite the spikes (robust fit).
  expect_gt(stats::cor(sm$smoothed, seasonal), 0.9)
  expect_lt(stats::sd(sm$smoothed), stats::sd(sm$value))
  # Spikes are absorbed (fitted value near the seasonal level, not 0).
  expect_gt(sm$smoothed[3L], 0.4)
})


test_that("harmonic fills NA-value grid rows (app densification pattern)", {
  # The app can get a fully continuous winter curve by appending a regular
  # date grid with value = NA: the harmonic predicts at EVERY row, including
  # the NA ones (fit uses the clear points only).
  yrs  <- 2018:2022
  obs  <- do.call(c, lapply(yrs, function(y)
    as.Date(sprintf("%d-%02d-15", y, 5:9))))            # real summer obs
  grid <- seq(min(obs), max(obs), by = 30L)             # dense regular grid
  t_obs <- as.numeric(obs)
  ts <- rbind(
    data.frame(obs_date = obs,  index = "NDVI",
               value = 0.6 + 0.2 * sin(2 * pi * t_obs / 365.25)),
    data.frame(obs_date = grid, index = "NDVI", value = NA_real_))

  sm <- smooth_pixel_series(ts, method = "harmonic")
  grid_rows <- sm[is.na(sm$value), ]
  # Every synthetic grid date got a modelled value (continuous winter curve).
  expect_false(anyNA(grid_rows$smoothed))
  expect_gt(stats::sd(grid_rows$smoothed), 0)           # it actually varies seasonally
})


test_that("harmonic returns NA when the series is too short / sparse", {
  # Under ~9 months of span -> cannot estimate the annual cycle -> NA.
  d  <- as.Date("2020-06-01") + seq.int(0L, by = 10L, length.out = 8L)
  ts <- data.frame(obs_date = d, index = "NDVI",
                   value = 0.6 + 0.01 * seq_along(d), stringsAsFactors = FALSE)
  sm <- smooth_pixel_series(ts, method = "harmonic")
  expect_true(all(is.na(sm$smoothed)))
})


test_that("smooth_pixel_series validates n_harmonics", {
  ts <- mk_series()
  expect_error(smooth_pixel_series(ts, method = "harmonic", n_harmonics = 0L),
               "1:3")
  expect_error(smooth_pixel_series(ts, method = "harmonic", n_harmonics = 5L),
               "1:3")
})


test_that("loess method returns a smoothed value at every date", {
  skip_if_not_installed("stats")
  ts <- mk_series("NDVI", n = 40L, base = 0.7, slope_per_day = -0.0005,
                  spikes = c(12L, 28L), spike_val = 0.0)
  sm <- smooth_pixel_series(ts, window_days = 60, method = "loess")
  expect_false(anyNA(sm$smoothed))               # predicted at all dates
  # Robust loess keeps the level near the ramp despite the two spikes.
  expect_gt(sm$smoothed[12L], 0.5)
  expect_lt(stats::sd(sm$smoothed), stats::sd(sm$value))
})
