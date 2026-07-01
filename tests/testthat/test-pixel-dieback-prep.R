# prepare_pixel_dieback_series() — derived layers for the app's 4-panel
# pixel-dieback plotly (Part A of the pixel-dieback brief). Pure data
# transform: no plotting, no Shiny.

# A two-season synthetic series with a KNOWN summer CRswir trough and a
# KNOWN summer CRre peak per year, plus a long winter gap.
make_series <- function() {
  d <- as.Date("2023-01-01") + seq(0, 730, by = 15)  # ~15-day revisit, 2 y
  doy <- as.integer(format(d, "%j"))
  yr  <- as.integer(format(d, "%Y"))
  # CRswir dips in summer (min), CRre rises in summer (max).
  crswir <- 0.85 - 0.25 * exp(-((doy - 200) / 40)^2)
  crre   <- 0.45 + 0.20 * exp(-((doy - 200) / 40)^2)
  # Depress 2024 a touch (dieback drift) so the two years differ.
  crswir[yr == 2024L] <- crswir[yr == 2024L] - 0.05
  data.frame(obs_date = d, crswir_obs = crswir, crre_obs = crre,
             stringsAsFactors = FALSE)
}

test_that("returns the documented list structure", {
  p <- prepare_pixel_dieback_series(make_series())
  expect_type(p, "list")
  expect_named(p, c("grid_swir", "grid_re", "obs_swir", "obs_re",
                    "trough_swir", "peak_re", "state", "centroids", "gaps"),
               ignore.order = TRUE)
  expect_true(all(c("date", "val", "year", "doy") %in% names(p$grid_swir)))
  expect_true(all(c("year", "date", "val") %in% names(p$trough_swir)))
  expect_true(all(c("year", "val_sw", "val_re") %in% names(p$centroids)))
})

test_that("gap-fill puts the grid on a regular step and covers the range", {
  df <- make_series()
  p  <- prepare_pixel_dieback_series(df, grid_step = 10L, smooth = "none")
  g  <- p$grid_swir
  # Regular 10-day spacing.
  expect_true(all(as.integer(diff(g$date)) == 10L))
  # Spans from the first to (within a step of) the last observation.
  expect_equal(min(g$date), min(df$obs_date))
  expect_lte(as.integer(max(df$obs_date) - max(g$date)), 10L)
})

test_that("summer extrema are picked on real obs and land in the summer window", {
  p <- prepare_pixel_dieback_series(make_series(), smooth = "none")
  # One trough + one peak per calendar year (2023, 2024).
  expect_setequal(p$trough_swir$year, c(2023L, 2024L))
  expect_setequal(p$peak_re$year,     c(2023L, 2024L))
  # Extrema fall inside the default summer window (DOY 152..273).
  tr_doy <- as.integer(format(p$trough_swir$date, "%j"))
  pk_doy <- as.integer(format(p$peak_re$date,     "%j"))
  expect_true(all(tr_doy >= 152 & tr_doy <= 273))
  expect_true(all(pk_doy >= 152 & pk_doy <= 273))
  # The 2024 trough is deeper (dieback drift baked into the fixture).
  tr <- p$trough_swir[order(p$trough_swir$year), ]
  expect_lt(tr$val[tr$year == 2024L], tr$val[tr$year == 2023L])
})

test_that("light smoothing barely moves the extremum vs raw", {
  df  <- make_series()
  raw <- prepare_pixel_dieback_series(df, smooth = "none")
  lis <- prepare_pixel_dieback_series(df, smooth = "light")
  # Trough dates within one grid step of each other (Savitzky-Golay light).
  m <- merge(raw$trough_swir, lis$trough_swir, by = "year",
             suffixes = c("_raw", "_lis"))
  expect_true(all(abs(as.integer(m$date_raw - m$date_lis)) <= 15L))
})

test_that("a summer window that excludes the dip drops the trough there", {
  # Winter-only window: no summer observation qualifies.
  p <- prepare_pixel_dieback_series(make_series(), summer = c(1L, 60L))
  # The CRswir minimum is in summer, so a Jan-Feb window yields extrema
  # that are NOT the true summer dip (different DOY range).
  expect_true(all(as.integer(format(p$trough_swir$date, "%j")) <= 60L))
})

test_that("long winter gaps are flagged, short ones are not", {
  df <- make_series()
  # Punch a 90-day hole (drop rows) in winter 2023-2024.
  hole <- df$obs_date >= as.Date("2023-11-15") & df$obs_date <= as.Date("2024-02-15")
  df2  <- df[!hole, ]
  g <- prepare_pixel_dieback_series(df2, gap_flag_days = 45L)$gaps
  expect_gte(nrow(g), 1L)
  expect_true(any(as.integer(g$to - g$from) > 45L))
  # With a huge threshold, nothing is flagged.
  g0 <- prepare_pixel_dieback_series(df2, gap_flag_days = 400L)$gaps
  expect_equal(nrow(g0), 0L)
})

test_that("attributes from the input series are carried over", {
  df <- make_series()
  attr(df, "species") <- "CHE"
  attr(df, "v_model") <- "v3"
  attr(df, "dans_zone_validite") <- TRUE
  p <- prepare_pixel_dieback_series(df)
  expect_identical(attr(p, "species"), "CHE")
  expect_identical(attr(p, "v_model"), "v3")
  expect_true(attr(p, "dans_zone_validite"))
})

test_that("degenerate inputs never error", {
  # All-NA indices -> empty grids/extrema, no error.
  df_na <- data.frame(obs_date = as.Date("2023-01-01") + 0:9,
                      crswir_obs = NA_real_, crre_obs = NA_real_)
  p <- prepare_pixel_dieback_series(df_na)
  expect_equal(nrow(p$grid_swir), 0L)
  expect_equal(nrow(p$trough_swir), 0L)
  expect_equal(nrow(p$centroids), 0L)

  # Single observation -> too few points to gridify, still no error.
  df1 <- data.frame(obs_date = as.Date("2023-07-01"),
                    crswir_obs = 0.6, crre_obs = 0.5)
  p1 <- prepare_pixel_dieback_series(df1)
  expect_equal(nrow(p1$grid_swir), 0L)
  expect_s3_class(p1$gaps, "data.frame")
})

test_that("input validation rejects malformed args", {
  df <- make_series()
  expect_error(prepare_pixel_dieback_series(list(a = 1)), "must be a data.frame")
  expect_error(prepare_pixel_dieback_series(df, grid_step = 0L), "positive integer")
  expect_error(prepare_pixel_dieback_series(df, summer = c(300L, 100L)), "increasing DOY")
  expect_error(prepare_pixel_dieback_series(df, gap_flag_days = -1L), "positive integer")
})
