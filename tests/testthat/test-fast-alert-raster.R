# test-fast-alert-raster.R — spec 013 (pixel-level FAST alert raster) +
# spec 017 (mono-index, quartile classes, cache-based scene enumeration).

# ---- unit: input validation ------------------------------------------

test_that("read_fast_alert_raster rejects bad zone_id", {
  skip_if_not_installed("terra")
  expect_error(
    read_fast_alert_raster(structure(list(), class = c("FakeConn", "DBIConnection")),
                           c(1L, 2L),
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "single non-NA integer"
  )
})

test_that("read_fast_alert_raster rejects a bad threshold", {
  skip_if_not_installed("terra")
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L, threshold = -0.1,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "in \\(0, 1\\)"
  )
  expect_error(
    read_fast_alert_raster(con, 1L, threshold = 1.5,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "in \\(0, 1\\)"
  )
})

test_that("read_fast_alert_raster rejects a bad index", {
  skip_if_not_installed("terra")
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L, index = "EVI",
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = tempdir()),
    regexp = "should be one of"
  )
})

test_that("read_fast_alert_raster rejects bad date range", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           cache_dir = "/tmp/does-not-exist-xyz123"),
    regexp = "does not exist"
  )
})

test_that("rolling mode rejects bad window_days", {
  skip_if_not_installed("terra")
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  expect_error(
    read_fast_alert_raster(con, 1L,
                           date_from = "2025-01-01", date_to = "2025-12-31",
                           mode = "rolling", window_days = -1,
                           cache_dir = tempdir()),
    regexp = "positive integer"
  )
})


# ---- spec 017: cache enumeration + mono-index ------------------------

test_that(".enumerate_cache_scenes selects by index bands and date window", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  mk <- function(sid, bands) {
    d <- file.path(cache, sid)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    for (b in bands) file.create(file.path(d, paste0(b, ".tif")))
  }
  mk("S2A_MSIL2A_20250115T103041_R108_T31TFM_x", c("B04", "B08"))         # NDVI, in window
  mk("S2A_MSIL2A_20250220T103041_R108_T31TGM_x", c("B08", "B12"))         # NBR only, in window
  mk("S2A_MSIL2A_20240101T103041_R108_T31TFM_x", c("B04", "B08"))         # NDVI, OUT of window
  mk("S2A_MSIL2A_20250301T103041_R108_T31TFM_x", c("B08"))               # incomplete

  ndvi <- nemeton:::.enumerate_cache_scenes(
    cache, "NDVI", as.Date("2025-01-01"), as.Date("2025-12-31"))
  expect_equal(nrow(ndvi), 1L)
  expect_match(ndvi$scene_id, "20250115")
  expect_equal(ndvi$obs_date, as.Date("2025-01-15"))

  nbr <- nemeton:::.enumerate_cache_scenes(
    cache, "NBR", as.Date("2025-01-01"), as.Date("2025-12-31"))
  expect_equal(nrow(nbr), 1L)
  expect_match(nbr$scene_id, "20250220")
})

test_that("read_fast_alert_raster(index=NDVI) needs no B12; index=NBR needs B12", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  # A single scene with only B04 + B08 (NDVI-renderable, NOT NBR).
  sid <- "S2A_MSIL2A_20250530T103041_R108_T31TFM_x"
  d <- file.path(cache, sid); dir.create(d, recursive = TRUE)
  for (b in c("B04", "B08")) {
    val <- if (b == "B04") 0.6 else 0.1   # NDVI = (0.1-0.6)/(0.7) < 0 < 0.4 -> alert
    r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                     ymin = 0, ymax = 100, crs = "EPSG:32631", vals = rep(val, 100))
    terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  rn <- suppressMessages(read_fast_alert_raster(
    con, 1L, index = "NDVI", date_from = "2025-05-01", date_to = "2025-06-01",
    mode = "count", cache_dir = cache, apply_zone_mask = FALSE))
  expect_s4_class(rn, "SpatRaster")
  expect_identical(attr(rn, "index"), "NDVI")

  # NBR needs B12 (absent) -> no usable scene -> NULL.
  rb <- suppressMessages(read_fast_alert_raster(
    con, 1L, index = "NBR", date_from = "2025-05-01", date_to = "2025-06-01",
    mode = "count", cache_dir = cache, apply_zone_mask = FALSE))
  expect_null(rb)
})


# ---- spec 017 D6: content-addressed result cache ---------------------

test_that(".fast_raster_hash is deterministic and input-sensitive", {
  skip_if_not_installed("terra")
  h <- function(...) nemeton:::.fast_raster_hash(...)
  base <- h(c("b", "a"), "NDVI", 0.4, "count", 30L, "2025-01-01", "2025-12-31", NA)
  # scene order does not matter (sorted inside)
  expect_identical(base,
    h(c("a", "b"), "NDVI", 0.4, "count", 30L, "2025-01-01", "2025-12-31", NA))
  # index / threshold / dates / scene-set change the hash
  expect_false(identical(base,
    h(c("a", "b"), "NBR",  0.4, "count", 30L, "2025-01-01", "2025-12-31", NA)))
  expect_false(identical(base,
    h(c("a", "b"), "NDVI", 0.3, "count", 30L, "2025-01-01", "2025-12-31", NA)))
  expect_false(identical(base,
    h(c("a"),      "NDVI", 0.4, "count", 30L, "2025-01-01", "2025-12-31", NA)))
  expect_false(identical(base,
    h(c("a", "b"), "NDVI", 0.4, "count", 30L, "2025-01-01", "2025-12-31", "POLYGON(...)")))
  # window_days is irrelevant in count mode but matters in rolling
  expect_identical(base,
    h(c("a", "b"), "NDVI", 0.4, "count", 99L, "2025-01-01", "2025-12-31", NA))
  expect_false(identical(
    h(c("a"), "NDVI", 0.4, "rolling", 30L, "2025-01-01", "2025-12-31", NA),
    h(c("a"), "NDVI", 0.4, "rolling", 60L, "2025-01-01", "2025-12-31", NA)))
})

# Write a one-scene NDVI-renderable cache (B04 + B08) for the D6 tests.
.write_one_ndvi_scene <- function(cache) {
  sid <- "S2A_MSIL2A_20250530T103041_R108_T31TFM_x"
  d <- file.path(cache, sid); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (b in c("B04", "B08")) {
    val <- if (b == "B04") 0.6 else 0.1   # NDVI < 0 < threshold -> alert
    r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                     ymin = 0, ymax = 100, crs = "EPSG:32631", vals = rep(val, 100))
    terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  invisible(sid)
}

test_that("read_fast_alert_raster persists + serves a content-addressed COG", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_one_ndvi_scene(cache)
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  args <- list(con, 1L, index = "NDVI", date_from = "2025-05-01",
               date_to = "2025-06-01", mode = "count", cache_dir = cache,
               apply_zone_mask = FALSE, result_cache_dir = rcache)

  r1 <- suppressMessages(do.call(read_fast_alert_raster, args))
  zone_dir <- file.path(rcache, "zone_1")
  cogs <- list.files(zone_dir, pattern = "^fast_NDVI_count_.*\\.tif$")
  expect_length(cogs, 1L)               # written on first compute
  expect_null(attr(r1, "cached"))       # first call computed

  r2 <- suppressMessages(do.call(read_fast_alert_raster, args))
  expect_true(isTRUE(attr(r2, "cached")))           # served from cache
  expect_equal(terra::values(r1), terra::values(r2))

  # A parameter change -> different hash -> a second COG (recompute).
  args2 <- args; args2$threshold <- 0.6
  suppressMessages(do.call(read_fast_alert_raster, args2))
  expect_length(list.files(zone_dir, pattern = "^fast_NDVI_count_.*\\.tif$"), 2L)

  # The persisted name is verbose: the key parameters are legible.
  nm <- list.files(zone_dir, pattern = "^fast_NDVI_count_.*\\.tif$")
  expect_true(all(grepl("_thr[0-9.]+_2025-05-01_2025-06-01_w30_[0-9a-f]{8}\\.tif$",
                        nm)))
  expect_true(any(grepl("_thr0\\.60_", nm)))   # the threshold = 0.6 recompute
})


# ---- verbose, deterministic cache filename (.fast_raster_filename) ---

test_that(".fast_raster_filename has the documented verbose format", {
  skip_if_not_installed("terra")
  fn <- nemeton:::.fast_raster_filename(
    "NBR", "count", 0.30, "2025-05-23", "2026-05-23", 30L,
    "fd9ca32a4c778e475955448b4c00c8c6")
  expect_identical(
    fn, "fast_NBR_count_thr0.30_2025-05-23_2026-05-23_w30_fd9ca32a.tif")
})

test_that(".fast_raster_filename is deterministic (same inputs -> same name)", {
  skip_if_not_installed("terra")
  a <- nemeton:::.fast_raster_filename("NDMI", "rolling", 0.30,
                                       "2025-01-01", "2026-01-01", 15L, "8e2a01ffdeadbeef")
  b <- nemeton:::.fast_raster_filename("NDMI", "rolling", 0.30,
                                       "2025-01-01", "2026-01-01", 15L, "8e2a01ffdeadbeef")
  expect_identical(a, b)
  expect_match(a, "^fast_NDMI_rolling_thr0\\.30_2025-01-01_2026-01-01_w15_8e2a01ff\\.tif$")
})

test_that(".fast_raster_filename discriminates threshold / window / hash", {
  skip_if_not_installed("terra")
  base <- list("NBR", "count", 0.30, "2025-05-23", "2026-05-23", 30L, "aaaaaaaa0000")
  fn   <- function(l) do.call(nemeton:::.fast_raster_filename, l)
  thr  <- base; thr[[3]]  <- 0.45
  win  <- base; win[[6]]  <- 15L
  hsh  <- base; hsh[[7]]  <- "bbbbbbbb1111"
  expect_false(identical(fn(base), fn(thr)))   # threshold differs
  expect_false(identical(fn(base), fn(win)))   # window differs
  expect_false(identical(fn(base), fn(hsh)))   # underlying hash differs
})

test_that(".fast_raster_filename normalises index/mode case", {
  skip_if_not_installed("terra")
  expect_match(
    nemeton:::.fast_raster_filename("ndvi", "COUNT", 0.4,
                                    "2025-05-23", "2026-05-23", 30L, "00ff00ff"),
    "^fast_NDVI_count_")
})

test_that("read_fast_alert_raster(cache_result = FALSE) writes nothing", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_one_ndvi_scene(cache)
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  r <- suppressMessages(read_fast_alert_raster(
    con, 1L, index = "NDVI", date_from = "2025-05-01", date_to = "2025-06-01",
    mode = "count", cache_dir = cache, apply_zone_mask = FALSE,
    cache_result = FALSE, result_cache_dir = rcache))
  expect_s4_class(r, "SpatRaster")
  expect_false(dir.exists(file.path(rcache, "zone_1")))
})

test_that("read_fast_alert_raster(parallel = TRUE) matches sequential (spec 017 D4)", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  skip_if_not_installed("furrr")
  skip_if_not_installed("future")
  cache <- withr::local_tempdir()
  .write_one_ndvi_scene(cache)
  con  <- structure(list(), class = c("FakeConn", "DBIConnection"))
  args <- list(con, 1L, index = "NDVI", date_from = "2025-05-01",
               date_to = "2025-06-01", mode = "count", cache_dir = cache,
               apply_zone_mask = FALSE, cache_result = FALSE)

  seq_r <- suppressMessages(do.call(read_fast_alert_raster,
                                    c(args, list(parallel = FALSE))))
  withr::defer(future::plan(future::sequential))
  future::plan(future::sequential)
  par_r <- suppressMessages(do.call(read_fast_alert_raster,
                                    c(args, list(parallel = TRUE))))

  expect_equal(terra::values(par_r), terra::values(seq_r))
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

test_that(".compute_alert_count counts per-pixel dates in alert (mono-index)", {
  skip_if_not_installed("terra")
  # 4x4 pixels, 3 dates. Pixel (1,1) below threshold on dates 1 and 3.
  # Pixel (1,2) below threshold on date 2 only. Others well above.
  layers <- list(
    matrix(c(0.2, 0.6, rep(0.6, 14)), nrow = 4, byrow = TRUE),  # date 1: (1,1)
    matrix(c(0.6, 0.2, rep(0.6, 14)), nrow = 4, byrow = TRUE),  # date 2: (1,2)
    matrix(c(0.2, 0.6, rep(0.6, 14)), nrow = 4, byrow = TRUE)   # date 3: (1,1)
  )
  stk <- make_synthetic_stack(layers,
                              as.Date(c("2025-06-01", "2025-06-10", "2025-06-20")))
  out  <- .compute_alert_count(stk, threshold = 0.4)
  vals <- as.vector(terra::values(out))

  expect_equal(vals[1], 2)  # pixel (1,1): alert dates 1 & 3
  expect_equal(vals[2], 1)  # pixel (1,2): alert date 2
  expect_true(all(vals[-c(1, 2)] == 0))
})

test_that(".compute_alert_count is bounded by the number of dates", {
  skip_if_not_installed("terra")
  stk <- make_synthetic_stack(list(matrix(0, 4, 4), matrix(0, 4, 4)),
                              as.Date(c("2025-06-01", "2025-06-10")))
  out <- .compute_alert_count(stk, threshold = 0.4)
  expect_true(all(terra::values(out) == 2))
})


test_that(".compute_alert_rolling returns deficit magnitude on trailing window", {
  skip_if_not_installed("terra")
  # 3 dates, window = 15 days. Only dates 2 & 3 fall in trailing window.
  layers <- list(
    matrix(0.10, 4, 4),  # date 1 (outside window)
    matrix(0.30, 4, 4),  # date 2 (in window): deficit = 0.40 - 0.30 = 0.10
    matrix(0.30, 4, 4)   # date 3 (in window): deficit = 0.10
  )
  stk <- make_synthetic_stack(layers,
                              as.Date(c("2025-05-01", "2025-06-10", "2025-06-20")))
  out <- .compute_alert_rolling(stk, threshold = 0.40,
                                window_days = 15L, date_to = as.Date("2025-06-20"))
  # mean over window = 0.30, deficit = 0.40 - 0.30 = 0.10
  expect_true(all(abs(terra::values(out) - 0.10) < 1e-9))
})


test_that(".compute_alert_rolling returns NULL when no scene in window", {
  skip_if_not_installed("terra")
  stk <- make_synthetic_stack(list(matrix(0.5, 4, 4)), as.Date("2025-01-01"))
  out <- .compute_alert_rolling(stk, threshold = 0.40,
                                window_days = 15L, date_to = as.Date("2025-12-01"))
  expect_null(out)
})


test_that(".compute_alert_rolling deficit = 0 when the mean is above threshold", {
  skip_if_not_installed("terra")
  stk <- make_synthetic_stack(list(matrix(0.60, 4, 4), matrix(0.60, 4, 4)),
                              as.Date(c("2025-06-10", "2025-06-20")))
  out <- .compute_alert_rolling(stk, threshold = 0.40,
                                window_days = 30L, date_to = as.Date("2025-06-20"))
  expect_true(all(terra::values(out) == 0))
})


# ---- multi-tile AOI coverage (cache-only, no DB) ---------------------

test_that("read_fast_alert_raster covers the full multi-tile AOI (per-tile mosaic)", {
  skip_if_terra_write_broken()
  # spec 010 / v0.52.x regression — an AOI straddling two overlapping
  # MGRS tiles (villards on T31TFM narrow ⊂ T31TGM wide) must render the
  # WHOLE AOI, not just the overlap strip. The per-tile grouping +
  # `mosaic(fun = "max")` already unions the two footprints; this test
  # pins that coverage. Scenes are enumerated from the COG cache (spec
  # 017), so no DB / obs_pixel is involved.
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()

  # Write one scene per tile, sharing the same acquisition date. Both
  # UTM 31N. NDVI/NBR are well above threshold (no alert) — the point is
  # the EXTENT of the mosaic, not the counts.
  write_tile_scene <- function(sid, xmax) {
    d <- file.path(cache, .s2_safe_scene_id(sid))
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    for (b in c("B04", "B08", "B12")) {
      res <- if (b == "B12") 20 else 10
      ncx <- xmax / res
      ncy <- 100 / res
      val <- switch(b, B04 = 0.05, B08 = 0.50, B12 = 0.05)
      r <- terra::rast(nrows = ncy, ncols = ncx,
                       xmin = 0, xmax = xmax, ymin = 0, ymax = 100,
                       crs = "EPSG:32631", vals = rep(val, ncx * ncy))
      terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                         filetype = "GTiff", overwrite = TRUE)
    }
  }
  sid_fm <- "S2A_MSIL2A_20250530T103041_R108_T31TFM_20250530T180000"
  sid_gm <- "S2A_MSIL2A_20250530T103041_R108_T31TGM_20250530T180000"
  write_tile_scene(sid_fm, xmax = 60)    # narrow (overlap strip)
  write_tile_scene(sid_gm, xmax = 120)   # wide (full AOI), FM ⊂ GM

  # spec 017 — scenes are enumerated straight from the cache (the two
  # dirs above), no obs_pixel / DB involved. apply_zone_mask = FALSE so
  # `con` is never touched.
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  r <- suppressMessages(read_fast_alert_raster(
    con, zone_id = 1L, index = "NDVI",
    date_from = "2025-05-01", date_to = "2025-06-01",
    mode = "count", cache_dir = cache,
    apply_zone_mask = FALSE))

  expect_s4_class(r, "SpatRaster")
  expect_equal(sf::st_crs(r)$epsg, 2154L)

  # The mosaic must span the WIDE footprint, not just the narrow strip.
  # Project both native footprints to EPSG:2154 and compare widths.
  to_2154_width <- function(xmax) {
    p <- terra::project(
      terra::rast(xmin = 0, xmax = xmax, ymin = 0, ymax = 100,
                  crs = "EPSG:32631"),
      "EPSG:2154")
    e <- terra::ext(p)
    terra::xmax(e) - terra::xmin(e)
  }
  w_narrow <- to_2154_width(60)
  w_mosaic <- terra::xmax(terra::ext(r)) - terra::xmin(terra::ext(r))
  # Strictly wider than the narrow-only footprint (the old intersection
  # bug would have clamped the mosaic to ~the narrow strip).
  expect_gt(w_mosaic, w_narrow * 1.5)
})


test_that(".mosaic_per_tile snaps mismatched-resolution tiles before mosaic", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  # Regression: per-tile rasters projected to EPSG:2154 independently can come
  # out at marginally different resolutions (NDRE 20 m over T31TFM + T31TGM),
  # and `terra::mosaic()` then aborts with "resolution does not match". The two
  # rasters below reproduce that post-projection state (res 20 vs 20.05, offset
  # extents) — the helper must resample them onto a common grid and mosaic.
  t1 <- terra::rast(xmin = 900000, xmax = 900200,
                    ymin = 6500000, ymax = 6500200,
                    resolution = 20, crs = "EPSG:2154")
  terra::values(t1) <- 1
  t2 <- terra::rast(xmin = 900100, xmax = 900300,
                    ymin = 6500100, ymax = 6500300,
                    resolution = 20.05, crs = "EPSG:2154")
  terra::values(t2) <- 2

  # The naive mosaic (what the old code did) fails on the resolution mismatch.
  expect_error(terra::mosaic(t1, t2, fun = "max"))

  out <- nemeton:::.mosaic_per_tile(list(t1, t2), method = "near")
  expect_s4_class(out, "SpatRaster")
  # Single, consistent resolution (the first tile's) and the union extent.
  expect_equal(terra::res(out), c(20, 20))
  expect_lte(terra::xmin(terra::ext(out)), 900000)
  expect_gte(terra::xmax(terra::ext(out)), 900300)
  # Both tiles' values survive the snap+mosaic (max over the overlap).
  expect_setequal(terra::unique(out)[[1]], c(1, 2))
})


test_that("read_fast_alert_raster: NDRE trend over two MGRS tiles mosaics (no resolution mismatch)", {
  skip_if_terra_write_broken()
  skip_if_not_installed("terra")
  # spec 023 / v0.85.1 regression, end-to-end. NDRE is computed from B05 +
  # B8A, both NATIVE 20 m. When the AOI straddles two MGRS tiles (Mouthe on
  # T31TFM + T31TGM), the trend raster is fitted per-tile, each projected to
  # EPSG:2154 independently, then mosaicked. Pre-fix, terra derived a
  # marginally different output resolution per tile and `terra::mosaic()`
  # aborted with "[mosaic] resolution does not match" (10 m NDVI/NDMI rounded
  # to the same resolution by luck and never reproduced it). This drives the
  # WHOLE compute_fast_alert_mask -> read_fast_alert_raster -> .fast_raster_trend
  # -> .mosaic_per_tile path on a two-tile NDRE cache and pins that it
  # returns a single mosaicked raster instead of aborting. The unit test
  # above covers .mosaic_per_tile() in isolation; this covers the real path.
  cache <- withr::local_tempdir()

  # NDRE = (B8A - B05) / (B8A + B05). Hold B05 = 0.2; decline B8A year over
  # year so NDRE strictly declines (Theil-Sen slope < 0, Mann-Kendall
  # significant) -> the trend raster flags a real decline magnitude. Both
  # bands native 20 m, EPSG:32631. The two tiles get DIFFERENT footprints
  # (FM narrow strip ⊂ GM wide) — the per-tile independent projection to
  # 2154 is exactly what used to drift the resolutions apart.
  write_ndre_scene <- function(tile, date, b8a, xmax) {
    ymd <- format(date, "%Y%m%d")
    sid <- sprintf("S2A_MSIL2A_%sT103041_R108_%s_%sT180000", ymd, tile, ymd)
    d <- file.path(cache, .s2_safe_scene_id(sid))
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    mk <- function(val) terra::rast(xmin = 0, xmax = xmax, ymin = 0, ymax = 200,
                                    resolution = 20, crs = "EPSG:32631",
                                    vals = val)
    terra::writeRaster(mk(0.2), file.path(d, "B05.tif"),
                       filetype = "GTiff", overwrite = TRUE)
    terra::writeRaster(mk(b8a), file.path(d, "B8A.tif"),
                       filetype = "GTiff", overwrite = TRUE)
  }

  yrs         <- 2019:2023                      # 5 years (>= min_years = 4)
  b8a_by_year <- c(0.9, 0.7, 0.5, 0.3, 0.1)     # strict NDRE decline
  for (k in seq_along(yrs)) {
    for (mo in c("07-15", "08-15")) {           # 2 summer obs / year (months 6:9)
      dt <- as.Date(sprintf("%d-%s", yrs[k], mo))
      write_ndre_scene("T31TFM", dt, b8a_by_year[k], xmax = 200)   # narrow
      write_ndre_scene("T31TGM", dt, b8a_by_year[k], xmax = 400)   # wide, FM ⊂ GM
    }
  }

  # apply_zone_mask = FALSE so `con` is never touched (cache-only path).
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  r <- suppressMessages(read_fast_alert_raster(
    con, zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    mode = "trend", months = 6:9, min_years = 4L, min_obs_per_year = 2L,
    alpha = 0.05, cache_dir = cache, apply_zone_mask = FALSE))

  # The whole point: a single mosaicked raster, not an abort.
  expect_s4_class(r, "SpatRaster")
  expect_equal(sf::st_crs(r)$epsg, 2154L)
  expect_equal(terra::nlyr(r), 1L)

  # Coverage spans the WIDE footprint (union of both tiles), not just the
  # narrow strip — the mosaic unioned the two tiles.
  to_2154_width <- function(xmax) {
    p <- terra::project(
      terra::rast(xmin = 0, xmax = xmax, ymin = 0, ymax = 200,
                  crs = "EPSG:32631"),
      "EPSG:2154")
    terra::xmax(terra::ext(p)) - terra::xmin(terra::ext(p))
  }
  w_narrow <- to_2154_width(200)
  w_mosaic <- terra::xmax(terra::ext(r)) - terra::xmin(terra::ext(r))
  expect_gt(w_mosaic, w_narrow * 1.5)

  # The trend ran through the mosaic: decline magnitude is non-negative and
  # at least one pixel flags the (uniform, significant) decline.
  vals <- terra::values(r)[, 1]
  vals <- vals[!is.na(vals)]
  expect_gt(length(vals), 0L)
  expect_true(all(vals >= 0))
  expect_gt(max(vals), 0)
})


# ---- integration: smoke test against the real villards DB ------------

test_that("end-to-end smoke test against villards (count mode)", {
  skip_if_not_installed("terra")
  # Opportunistic — only runs if the cache + DB happen to be on disk.
  cache <- "/home/pascal/.local/share/nemeton/projects/20260520_212017_btfe/cache/layers/sentinel2"
  if (!dir.exists(cache)) testthat::skip("villards cache not present on this machine")
  skip_if_no_timescaledb()

  con <- db_connect(Sys.getenv("NEMETON_DB_URL_TEST",
                               Sys.getenv("NEMETON_DB_URL", "")))
  on.exit(db_disconnect(con))

  # A reachable PostgreSQL that carries TimescaleDB but NOT the nemeton
  # schema (a bare dev DB) makes `skip_if_no_timescaledb()` pass yet the
  # query below abort on the missing table — skip gracefully in that case
  # instead of failing this opportunistic smoke test.
  has_zone <- tryCatch(
    DBI::dbGetQuery(con,
      "SELECT count(*)::int AS n FROM monitoring_zone WHERE id = 1")$n > 0,
    error = function(e) FALSE)
  if (!has_zone) {
    testthat::skip("zone_id=1 not in DB (or schema absent) on this machine")
  }

  r <- read_fast_alert_raster(
    con, zone_id = 1L, index = "NDVI",
    date_from = "2025-05-23", date_to = "2026-05-23",
    mode = "count", cache_dir = cache,
    cache_result = FALSE)

  expect_s4_class(r, "SpatRaster")
  expect_equal(sf::st_crs(r)$epsg, 2154L)
  expect_equal(names(r), "alert_count")
  expect_identical(attr(r, "index"), "NDVI")
  rng <- terra::minmax(r)
  expect_true(rng[1, 1] >= 0)
  expect_true(rng[2, 1] <= 130)  # bounded by the # of NDVI scenes in window
})
