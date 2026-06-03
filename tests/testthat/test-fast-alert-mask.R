# test-fast-alert-mask.R — spec 014 A4: compute_fast_alert_mask() +
# read_fast_alert_mask(). Mostly read-side tests; the writer is
# covered by the smoke test against villards.

# ---- unit: read_fast_alert_mask --------------------------------------

test_that("read_fast_alert_mask returns NULL when cache_dir is missing", {
  expect_null(read_fast_alert_mask(NULL, 1L, cache_dir = NULL))
  expect_null(read_fast_alert_mask(NULL, 1L, cache_dir = ""))
  expect_null(read_fast_alert_mask(NULL, 1L,
                                   cache_dir = "/tmp/does-not-exist-xyz"))
})

test_that("read_fast_alert_mask returns NULL when zone dir is missing", {
  td <- withr::local_tempdir()
  expect_null(read_fast_alert_mask(NULL, 1L, cache_dir = td))
})

test_that("read_fast_alert_mask rejects bad zone_id", {
  expect_error(read_fast_alert_mask(NULL, c(1L, 2L), cache_dir = tempdir()),
               regexp = "single non-NA integer")
})

test_that("read_fast_alert_mask returns the most recent file by default", {
  td <- withr::local_tempdir()
  zone_dir <- file.path(td, "zone_1")
  dir.create(zone_dir, recursive = TRUE)

  # Write 3 fake masks with chronological timestamps.
  r <- terra::rast(matrix(c(0, 1, 2, 3), 2, 2), crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 20, 0, 20)
  for (ts in c("20260101T100000", "20260102T100000", "20260103T100000")) {
    terra::writeRaster(r, file.path(zone_dir, sprintf("fast_alert_%s.tif", ts)),
                       overwrite = TRUE, filetype = "GTiff")
  }

  # Default (no run_id) returns the latest.
  out <- read_fast_alert_mask(NULL, 1L, cache_dir = td)
  expect_s4_class(out, "SpatRaster")
  expect_match(terra::sources(out), "20260103T100000")

  # Explicit run_id targets a specific file.
  out2 <- read_fast_alert_mask(NULL, 1L,
                               run_id = "20260101T100000", cache_dir = td)
  expect_s4_class(out2, "SpatRaster")
  expect_match(terra::sources(out2), "20260101T100000")

  # Unknown run_id returns NULL.
  expect_null(read_fast_alert_mask(NULL, 1L,
                                   run_id = "nope", cache_dir = td))
})

test_that("read_fast_alert_mask returns NULL when no matching file", {
  td <- withr::local_tempdir()
  zone_dir <- file.path(td, "zone_1")
  dir.create(zone_dir, recursive = TRUE)
  # An unrelated TIF that doesn't match the prefix.
  r <- terra::rast(matrix(0, 2, 2), crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 20, 0, 20)
  terra::writeRaster(r, file.path(zone_dir, "some_other.tif"),
                     overwrite = TRUE, filetype = "GTiff")

  expect_null(read_fast_alert_mask(NULL, 1L, cache_dir = td))
})


# ---- unit: compute_fast_alert_mask input validation ------------------

test_that("compute_fast_alert_mask validates inputs", {
  fake_con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    compute_fast_alert_mask(fake_con, c(1L, 2L),
                            date_from = "2025-01-01", date_to = "2025-12-31",
                            cache_dir = tempdir()),
    regexp = "single non-NA integer"
  )
  expect_error(
    compute_fast_alert_mask(fake_con, 1L,
                            date_from = "2025-01-01", date_to = "2025-12-31",
                            cache_dir = tempdir(),
                            breaks = c(1, 2, 3)),
    regexp = "length 5"
  )
})


# ---- spec 017: quartile discretisation -------------------------------

test_that(".fast_alert_quartile_breaks: quartiles of strictly-positive pixels", {
  skip_if_not_installed("terra")
  r  <- terra::rast(nrows = 1, ncols = 8, vals = c(0, 0, 1, 2, 3, 4, 5, 6))
  br <- nemeton:::.fast_alert_quartile_breaks(r)
  expect_length(br, 5L)
  expect_equal(br[1], 0)
  expect_identical(br[5], Inf)
  expect_equal(br[2:4],
               as.numeric(stats::quantile(1:6, c(.25, .5, .75), names = FALSE)))
})

test_that(".fast_alert_quartile_breaks: all-zero raster maps to class 0", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 1, ncols = 4, vals = c(0, 0, 0, 0))
  expect_equal(nemeton:::.fast_alert_quartile_breaks(r), c(0, 1, 2, 3, Inf))
})

test_that(".fast_alert_quartile_breaks: NA ignored, tied quantiles tolerated", {
  skip_if_not_installed("terra")
  r  <- terra::rast(nrows = 1, ncols = 5, vals = c(NA, 0, 1, 1, 1))
  expect_equal(nemeton:::.fast_alert_quartile_breaks(r), c(0, 1, 1, 1, Inf))
})

test_that("0-4 classify tolerates tied quartile breaks (degenerate)", {
  skip_if_not_installed("terra")
  r  <- terra::rast(nrows = 1, ncols = 5, vals = c(0, 1, 1, 1, 2))
  br <- c(0, 1, 1, 1, Inf)
  rcl <- matrix(c(-Inf, br[1], 0, br[1], br[2], 1, br[2], br[3], 2,
                  br[3], br[4], 3, br[4], br[5], 4), ncol = 3, byrow = TRUE)
  m <- terra::classify(r, rcl, include.lowest = TRUE, right = TRUE)
  vals <- as.vector(terra::values(m))
  expect_true(all(vals %in% 0:4))
  expect_equal(vals[1], 0)    # value 0 -> class 0
  expect_equal(vals[5], 4)    # value 2 (> 1) -> class 4
})


# ---- integration: end-to-end compute + read --------------------------

test_that("compute_fast_alert_mask + read round-trip on villards", {
  cache <- "/home/pascal/.local/share/nemeton/projects/20260520_212017_btfe/cache/layers/sentinel2"
  if (!dir.exists(cache)) testthat::skip("villards cache not present on this machine")
  skip_if_no_timescaledb()

  con <- db_connect(Sys.getenv("NEMETON_DB_URL_TEST",
                               Sys.getenv("NEMETON_DB_URL", "")))
  on.exit(db_disconnect(con))

  has_zone <- DBI::dbGetQuery(con,
    "SELECT count(*)::int AS n FROM monitoring_zone WHERE id = 1")$n > 0
  if (!has_zone) testthat::skip("zone_id=1 not in DB on this machine")

  td <- withr::local_tempdir()
  out_path <- compute_fast_alert_mask(
    con, zone_id = 1L, index = "NDVI",
    date_from = "2025-05-23", date_to = "2026-05-23",
    mode = "count",
    cache_dir = cache, mask_cache_dir = td, cache_result = FALSE)

  expect_true(!is.null(out_path) && !is.na(out_path))
  expect_true(file.exists(out_path))

  # Read it back via the strict mirror.
  m <- read_fast_alert_mask(con, zone_id = 1L, cache_dir = td)
  expect_s4_class(m, "SpatRaster")
  expect_equal(sf::st_crs(m)$epsg, 2154L)
  vals <- as.vector(terra::values(m))
  vals <- vals[!is.na(vals)]
  expect_true(all(vals %in% 0:4))
})


# ---- mask cache GC (.fast_alert_mask_gc) -----------------------------

# Create `n` mask files with strictly increasing mtimes so LRU ordering
# is deterministic; return their paths oldest-first.
.write_dummy_masks <- function(dir, n, prefix = "fast_alert_") {
  paths <- file.path(dir, sprintf("%s2026010%dT0000%02d.tif", prefix,
                                   (seq_len(n) %% 9) + 1L, seq_len(n)))
  base <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  for (k in seq_len(n)) {
    writeLines("x", paths[k])
    Sys.setFileTime(paths[k], base + k)   # k seconds apart -> stable order
  }
  paths
}

test_that(".fast_alert_mask_gc keeps the newest `keep` masks (LRU)", {
  d <- withr::local_tempdir()
  .write_dummy_masks(d, 25L)
  nemeton:::.fast_alert_mask_gc(d, keep = 20L)
  left <- list.files(d, pattern = "^fast_alert_.*\\.tif$")
  expect_length(left, 20L)
  # the 5 oldest (k = 1..5) were removed; the newest survive
  expect_false(any(grepl("T000001\\.tif$", left)))
  expect_true(any(grepl("T000025\\.tif$", left)))
})

test_that(".fast_alert_mask_gc is a no-op at or under `keep`", {
  d <- withr::local_tempdir()
  .write_dummy_masks(d, 10L)
  nemeton:::.fast_alert_mask_gc(d, keep = 20L)
  expect_length(list.files(d, pattern = "^fast_alert_.*\\.tif$"), 10L)
})

test_that(".fast_alert_mask_gc never touches continuous COGs (shared dir)", {
  # validation-sampling case: masks (`fast_alert_*`) and continuous
  # (`fast_<INDEX>_*`) live in the same `fast_sampling/zone_<id>` dir.
  d <- withr::local_tempdir()
  .write_dummy_masks(d, 25L)                 # 25 masks
  cont <- file.path(d, c("fast_NBR_count_thr0.30_2025-05-23_2026-05-23_w30_aaaaaaaa.tif",
                         "fast_NDMI_rolling_thr0.30_2025-05-23_2026-05-23_w30_bbbbbbbb.tif"))
  for (p in cont) writeLines("x", p)
  nemeton:::.fast_alert_mask_gc(d, keep = 20L)
  expect_length(list.files(d, pattern = "^fast_alert_.*\\.tif$"), 20L)  # masks trimmed
  expect_true(all(file.exists(cont)))                                   # continuous untouched
})

test_that(".fast_raster_gc never touches 0-4 masks (shared dir)", {
  skip_if_not_installed("withr")
  d <- withr::local_tempdir()
  # 22 continuous COGs + 3 masks in the same dir.
  cont <- file.path(d, sprintf("fast_NDVI_count_thr0.40_2025-05-23_2026-05-23_w30_%08x.tif",
                               seq_len(22)))
  for (p in cont) writeLines("x", p)
  masks <- .write_dummy_masks(d, 3L)
  nemeton:::.fast_raster_gc(d, keep = 20L)
  expect_length(list.files(d, pattern = "^fast_NDVI_.*\\.tif$"), 20L)   # continuous trimmed
  expect_true(all(file.exists(masks)))                                  # masks untouched
})
