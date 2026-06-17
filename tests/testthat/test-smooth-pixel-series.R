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
