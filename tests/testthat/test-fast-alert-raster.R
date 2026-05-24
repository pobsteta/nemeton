# test-fast-alert-raster.R — spec 013: pixel-level FAST alert raster.

# ---- unit: input validation ------------------------------------------

test_that("read_fast_alert_raster rejects non-DBIConnection", {
  # The DBI check is enforced downstream by read_obs_pixel() whose
  # message is "`con` must be a DBI connection." (space, lowercase c).
  expect_error(
    read_fast_alert_raster("not-a-con", 1L,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "DBI"
  )
})

test_that("read_fast_alert_raster rejects bad zone_id", {
  expect_error(
    read_fast_alert_raster(structure(list(), class = c("FakeConn", "DBIConnection")),
                           c(1L, 2L),
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "single non-NA integer"
  )
})

test_that("read_fast_alert_raster rejects bad thresholds", {
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L,
                           threshold_ndvi = -0.1,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "in \\(0, 1\\)"
  )
  expect_error(
    read_fast_alert_raster(con, 1L,
                           threshold_nbr = 1.5,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "in \\(0, 1\\)"
  )
})

test_that("read_fast_alert_raster rejects bad date range", {
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L,
                           date_from = "2025-12-31", date_to = "2025-01-01",
                           cache_dir = tempdir()),
    regexp = "<= "
  )
  expect_error(
    read_fast_alert_raster(con, 1L,
                           date_from = "not-a-date", date_to = "2025-01-01",
                           cache_dir = tempdir()),
    regexp = "must parse as Date"
  )
})

test_that("read_fast_alert_raster rejects missing cache_dir", {
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = "/tmp/does-not-exist-xyz123"),
    regexp = "does not exist"
  )
})

test_that("rolling mode rejects bad window_days", {
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           mode = "rolling", window_days = -1,
                           cache_dir = tempdir()),
    regexp = "positive integer"
  )
})


# ---- unit: helpers against synthetic stacks --------------------------

make_synthetic_stack <- function(values_per_layer, dates) {
  # values_per_layer: list of length n_dates, each a 4x4 matrix
  # dates: vector of Date, same length
  stopifnot(length(values_per_layer) == length(dates))
  layers <- lapply(values_per_layer, function(m) {
    r <- terra::rast(m, crs = "EPSG:32631")
    terra::ext(r) <- terra::ext(0, 4, 0, 4)
    r
  })
  out <- terra::rast(layers)
  terra::time(out) <- as.Date(dates)
  out
}

test_that(".compute_alert_count counts per-pixel days in alert", {
  # 4x4 pixels, 3 dates. Pixel (1,1) below NDVI threshold on dates 1 and 3.
  # Pixel (1,2) below NBR on date 2 only. Others well above.
  ndvi_layers <- list(
    matrix(c(0.2, 0.6, rep(0.6, 14)), nrow = 4, byrow = TRUE),  # date 1: pixel(1,1) at 0.2
    matrix(0.6, nrow = 4, ncol = 4),                            # date 2: nothing
    matrix(c(0.2, 0.6, rep(0.6, 14)), nrow = 4, byrow = TRUE)   # date 3: pixel(1,1) at 0.2
  )
  nbr_layers <- list(
    matrix(0.5, nrow = 4, ncol = 4),
    matrix(c(0.5, 0.1, rep(0.5, 14)), nrow = 4, byrow = TRUE),  # date 2: pixel(1,2) at 0.1
    matrix(0.5, nrow = 4, ncol = 4)
  )
  dates <- as.Date(c("2025-06-01", "2025-06-10", "2025-06-20"))
  ndvi <- make_synthetic_stack(ndvi_layers, dates)
  nbr  <- make_synthetic_stack(nbr_layers,  dates)

  out <- .compute_alert_count(ndvi, nbr,
                              threshold_ndvi = 0.4, threshold_nbr = 0.3)
  # `terra::values(out)` is an ncell × nlyr matrix; for a single-layer
  # raster, index cells with `[i]` (raster row-major from top-left).
  vals <- as.vector(terra::values(out))

  expect_equal(vals[1], 2)  # cell #1 = pixel (row 1, col 1): NDVI alert dates 1 & 3
  expect_equal(vals[2], 1)  # cell #2 = pixel (row 1, col 2): NBR alert date 2
  rest <- vals[-c(1, 2)]
  expect_true(all(rest == 0))
})

test_that(".compute_alert_count is bounded by the number of layers", {
  # All-zero stack -> every pixel in alert on every date -> max = N_dates.
  ndvi <- make_synthetic_stack(list(matrix(0, 4, 4), matrix(0, 4, 4)),
                               as.Date(c("2025-06-01", "2025-06-10")))
  nbr  <- make_synthetic_stack(list(matrix(0, 4, 4), matrix(0, 4, 4)),
                               as.Date(c("2025-06-01", "2025-06-10")))
  out <- .compute_alert_count(ndvi, nbr, 0.4, 0.3)
  expect_true(all(terra::values(out) == 2))
})


test_that(".compute_alert_rolling returns deficit magnitude on trailing window", {
  # 3 dates, window = 15 days. Only dates 2 & 3 fall in trailing window
  # (date_to = 2025-06-20, win_start = 2025-06-06).
  ndvi_layers <- list(
    matrix(0.10, 4, 4),  # date 1 (outside window): deep alert
    matrix(0.30, 4, 4),  # date 2 (in window): deficit = 0.4 - 0.30 = 0.10
    matrix(0.30, 4, 4)   # date 3 (in window): deficit = 0.4 - 0.30 = 0.10
  )
  nbr_layers <- list(
    matrix(0.40, 4, 4),  # all OK NBR
    matrix(0.40, 4, 4),
    matrix(0.40, 4, 4)
  )
  dates <- as.Date(c("2025-05-01", "2025-06-10", "2025-06-20"))
  ndvi <- make_synthetic_stack(ndvi_layers, dates)
  nbr  <- make_synthetic_stack(nbr_layers,  dates)

  out <- .compute_alert_rolling(ndvi, nbr,
                                threshold_ndvi = 0.40, threshold_nbr = 0.30,
                                window_days = 15L, date_to = as.Date("2025-06-20"))
  vals <- terra::values(out)

  # mean NDVI over window = (0.30 + 0.30)/2 = 0.30, deficit = 0.40 - 0.30 = 0.10
  # mean NBR  over window = 0.40, deficit = 0
  # output = max(0.10, 0) = 0.10
  expect_true(all(abs(vals - 0.10) < 1e-9))
})


test_that(".compute_alert_rolling returns NULL when no scene in window", {
  ndvi <- make_synthetic_stack(list(matrix(0.5, 4, 4)),
                               as.Date("2025-01-01"))
  nbr  <- make_synthetic_stack(list(matrix(0.5, 4, 4)),
                               as.Date("2025-01-01"))
  out <- .compute_alert_rolling(ndvi, nbr,
                                threshold_ndvi = 0.40, threshold_nbr = 0.30,
                                window_days = 15L,
                                date_to = as.Date("2025-12-01"))
  expect_null(out)
})


test_that(".compute_alert_rolling deficit = 0 when all means are above thresholds", {
  ndvi <- make_synthetic_stack(list(matrix(0.60, 4, 4), matrix(0.60, 4, 4)),
                               as.Date(c("2025-06-10", "2025-06-20")))
  nbr  <- make_synthetic_stack(list(matrix(0.50, 4, 4), matrix(0.50, 4, 4)),
                               as.Date(c("2025-06-10", "2025-06-20")))
  out <- .compute_alert_rolling(ndvi, nbr,
                                threshold_ndvi = 0.40, threshold_nbr = 0.30,
                                window_days = 30L, date_to = as.Date("2025-06-20"))
  expect_true(all(terra::values(out) == 0))
})


# ---- integration: smoke test against the real villards DB ------------

test_that("end-to-end smoke test against villards (count mode)", {
  # Opportunistic — only runs if the cache + DB happen to be on disk.
  cache <- "/home/pascal/.local/share/nemeton/projects/20260520_212017_btfe/cache/layers/sentinel2"
  if (!dir.exists(cache)) testthat::skip("villards cache not present on this machine")
  skip_if_no_timescaledb()

  con <- db_connect(Sys.getenv("NEMETON_DB_URL_TEST",
                               Sys.getenv("NEMETON_DB_URL", "")))
  on.exit(db_disconnect(con))

  has_zone <- DBI::dbGetQuery(con,
    "SELECT count(*)::int AS n FROM monitoring_zone WHERE id = 1")$n > 0
  if (!has_zone) testthat::skip("zone_id=1 not in DB on this machine")

  r <- read_fast_alert_raster(
    con, zone_id = 1L,
    threshold_ndvi = 0.40, threshold_nbr = 0.30,
    date_from = "2025-05-23", date_to = "2026-05-23",
    mode = "count", cache_dir = cache)

  expect_s4_class(r, "SpatRaster")
  expect_equal(sf::st_crs(r)$epsg, 2154L)
  expect_equal(names(r), "alert_count")
  rng <- terra::minmax(r)
  expect_true(rng[1, 1] >= 0)
  expect_true(rng[2, 1] <= 60)  # not more than the # of scenes (55 in villards)
})
