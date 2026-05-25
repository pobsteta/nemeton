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
    con, zone_id = 1L,
    threshold_ndvi = 0.40, threshold_nbr = 0.30,
    date_from = "2025-05-23", date_to = "2026-05-23",
    mode = "count",
    cache_dir = cache, mask_cache_dir = td)

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
