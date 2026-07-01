# test-prewarm-fast-alerts.R — spec 018: opt-in pre-computation of the
# usual FAST alert maps at the end of `ingest_sentinel2_timeseries()`.
# Since spec 023 the prewarm covers EIGHT combos: NDVI/NBR/NDMI ×
# count/rolling (spec 019) plus NDMI/NDRE × trend (spec 023, chronic
# broadleaf decline).
#
# The pre-warm helper `.prewarm_fast_alerts()` is exercised directly with
# on-disk COG fixtures (no DB, no STAC) — same pattern as the D6 result
# cache tests in test-fast-alert-raster.R. The wiring into the full
# ingestion (placement, flag forwarding) is checked with mocked internals.

# ---- fixtures --------------------------------------------------------

# A single scene carrying B04+B08+B12+B11 -> renderable for NDVI/NBR/NDMI
# count & rolling (no red-edge, so NDRE trend is unrenderable here).
# NDVI = (B08-B04)/(B08+B04), NBR = (B08-B12)/(B08+B12),
# NDMI = (B08-B11)/(B08+B11); the values are chosen so each index sits
# clearly below its default threshold (alert). B11 is native 20 m.
.write_ndvi_nbr_scene <- function(cache, date = "20250530") {
  skip_if_terra_write_broken()   # runner terra::writeRaster anomaly
  sid <- sprintf("S2A_MSIL2A_%sT103041_R108_T31TFM_x", date)
  d <- file.path(cache, sid)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  vals <- c(B04 = 0.6, B08 = 0.1, B12 = 0.6, B11 = 0.6)  # all 3 < threshold
  for (b in names(vals)) {
    r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                     ymin = 0, ymax = 100, crs = "EPSG:32631",
                     vals = rep(vals[[b]], 100))
    terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  invisible(sid)
}

# A multi-year summer cache carrying ALL six bands (B04+B08+B12+B11 for
# NDVI/NBR/NDMI, B05+B8A for NDRE) over `years`, 2 summer scenes/year, so
# the full set of EIGHT prewarm combos renders: the count/rolling trio
# only needs >= 1 scene, while NDMI/NDRE trend need >= min_years (4) valid
# years. B08/B8A are fixed and B11/B05 rise each year so NDMI/NDRE decline
# (a genuine trend signal); B04/B12 are fixed.
.write_eight_combo_cache <- function(cache, years = 2019:2023) {
  skip_if_terra_write_broken()   # runner terra::writeRaster anomaly
  for (k in seq_along(years)) {
    y    <- years[k]
    rise <- 0.05 + (k - 1) * 0.05            # B11 / B05 climb -> NDMI/NDRE fall
    vals <- c(B04 = 0.6, B08 = 0.5, B12 = 0.6,
              B11 = rise, B05 = rise, B8A = 0.5)
    for (mo in c("07", "08")) {
      sid <- sprintf("S2A_MSIL2A_%d%s15T103041_R108_T31TFM_x", y, mo)
      d   <- file.path(cache, sid)
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      for (b in names(vals)) {
        r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                         ymin = 0, ymax = 100, crs = "EPSG:32631",
                         vals = rep(vals[[b]], 100))
        terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                           filetype = "GTiff", overwrite = TRUE)
      }
    }
  }
  invisible(NULL)
}

# NDVI-renderable only (B04+B08, no B12) -> NBR has no usable scene.
.write_ndvi_only_scene <- function(cache, date = "20250530") {
  skip_if_terra_write_broken()   # runner terra::writeRaster anomaly
  sid <- sprintf("S2A_MSIL2A_%sT103041_R108_T31TFM_x", date)
  d <- file.path(cache, sid)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (b in c("B04", "B08")) {
    val <- if (b == "B04") 0.6 else 0.1
    r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                     ymin = 0, ymax = 100, crs = "EPSG:32631",
                     vals = rep(val, 100))
    terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  invisible(sid)
}

.never_cancel <- function() FALSE
.noop_emit    <- function(payload) invisible(NULL)


# ---- .prewarm_fast_alerts(): the eight combinations ------------------

test_that(".prewarm_fast_alerts precomputes the 8 combinations", {
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_eight_combo_cache(cache, years = 2019:2023)   # 5 declining years
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  events <- list()
  emit <- function(p) events[[length(events) + 1L]] <<- p

  # `date_to` lands in summer (Aug) so the 30-day rolling window catches the
  # last cached scene (Aug 15) — a December `date_to` would leave rolling
  # empty and soft-skip the three rolling combos.
  suppressMessages(
    nemeton:::.prewarm_fast_alerts(
      con, zone_id = 1L,
      date_from = "2019-01-01", date_to = "2023-08-31",
      cache_dir = cache, result_cache_dir = rcache,
      emit = emit, cancelled = .never_cancel))

  # Eight content-addressed COGs: NDVI/NBR/NDMI × count/rolling (spec 019)
  # + NDMI/NDRE × trend (spec 023).
  cogs <- list.files(file.path(rcache, "zone_1"), pattern = "\\.tif$")
  expect_length(cogs, 8L)
  expect_true(all(c(
    # Back-compat — the six count/rolling COGs keep their exact names.
    any(grepl("^fast_NDVI_count_",   cogs)),
    any(grepl("^fast_NDVI_rolling_", cogs)),
    any(grepl("^fast_NBR_count_",    cogs)),
    any(grepl("^fast_NBR_rolling_",  cogs)),
    any(grepl("^fast_NDMI_count_",   cogs)),
    any(grepl("^fast_NDMI_rolling_", cogs)),
    # spec 023 — the two trend COGs (NDMI default + NDRE alt).
    any(grepl("^fast_NDMI_trend_",   cogs)),
    any(grepl("^fast_NDRE_trend_",   cogs)))))

  # Every combination emitted a start + a _done heartbeat, none _failed.
  currents <- vapply(events, function(e) e$current %||% "", character(1))
  expect_setequal(
    currents,
    c("fast_prewarm:NDVI_count",   "fast_prewarm:NDVI_count_done",
      "fast_prewarm:NDVI_rolling", "fast_prewarm:NDVI_rolling_done",
      "fast_prewarm:NBR_count",    "fast_prewarm:NBR_count_done",
      "fast_prewarm:NBR_rolling",  "fast_prewarm:NBR_rolling_done",
      "fast_prewarm:NDMI_count",   "fast_prewarm:NDMI_count_done",
      "fast_prewarm:NDMI_rolling", "fast_prewarm:NDMI_rolling_done",
      "fast_prewarm:NDMI_trend",   "fast_prewarm:NDMI_trend_done",
      "fast_prewarm:NDRE_trend",   "fast_prewarm:NDRE_trend_done"))
  expect_false(any(grepl("_failed$", currents)))
})


# ---- red-edge absent: trend is soft-skipped, no error ----------------

test_that(".prewarm_fast_alerts skips NDRE trend when red-edge is absent", {
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  # Multi-year B04+B08+B12+B11 (NDMI trend renders) but NO B05/B8A -> the
  # NDRE trend warm has no usable scene and must skip best-effort.
  for (k in seq_along(2019:2023)) {
    y    <- (2019:2023)[k]
    rise <- 0.05 + (k - 1) * 0.05
    vals <- c(B04 = 0.6, B08 = 0.5, B12 = 0.6, B11 = rise)
    for (mo in c("07", "08")) {
      sid <- sprintf("S2A_MSIL2A_%d%s15T103041_R108_T31TFM_x", y, mo)
      d   <- file.path(cache, sid)
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      for (b in names(vals)) {
        r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                         ymin = 0, ymax = 100, crs = "EPSG:32631",
                         vals = rep(vals[[b]], 100))
        terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                           filetype = "GTiff", overwrite = TRUE)
      }
    }
  }
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  events <- list()
  emit <- function(p) events[[length(events) + 1L]] <<- p

  # NDRE trend (no B05/B8A) warns and is skipped — never aborts.
  expect_warning(
    suppressMessages(
      nemeton:::.prewarm_fast_alerts(
        con, zone_id = 1L,
        date_from = "2019-01-01", date_to = "2023-08-31",
        cache_dir = cache, result_cache_dir = rcache,
        emit = emit, cancelled = .never_cancel)),
    "FAST prewarm NDRE/trend")

  currents <- vapply(events, function(e) e$current %||% "", character(1))
  # NDMI trend still rendered; NDRE trend skipped without a COG.
  expect_true("fast_prewarm:NDMI_trend_done"   %in% currents)
  expect_true("fast_prewarm:NDRE_trend_failed" %in% currents)
  cogs <- list.files(file.path(rcache, "zone_1"), pattern = "\\.tif$")
  expect_false(any(grepl("^fast_NDRE_", cogs)))
  expect_true(any(grepl("^fast_NDMI_trend_", cogs)))
})


# ---- partial failure: continue on a missing band ---------------------

test_that(".prewarm_fast_alerts continues on a per-combination failure", {
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_ndvi_only_scene(cache)          # no B12 -> NBR unrenderable
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  events <- list()
  emit <- function(p) events[[length(events) + 1L]] <<- p

  # Only NDVI has usable bands. NBR (no B12) and NDMI (no B11) skip both
  # count & rolling; the two trend combos (NDMI, NDRE) skip too — six
  # warnings in all, none aborting. NDVI still renders.
  expect_warning(
    suppressMessages(
      nemeton:::.prewarm_fast_alerts(
        con, zone_id = 1L,
        date_from = "2025-05-01", date_to = "2025-06-01",
        cache_dir = cache, result_cache_dir = rcache,
        emit = emit, cancelled = .never_cancel)),
    "FAST prewarm")

  # Only the two NDVI maps were written; NBR / NDMI / trend skipped.
  cogs <- list.files(file.path(rcache, "zone_1"), pattern = "\\.tif$")
  expect_length(cogs, 2L)
  expect_true(all(grepl("^fast_NDVI_", cogs)))

  currents <- vapply(events, function(e) e$current %||% "", character(1))
  expect_true("fast_prewarm:NDVI_count_done"     %in% currents)
  expect_true("fast_prewarm:NDVI_rolling_done"   %in% currents)
  expect_true("fast_prewarm:NBR_count_failed"    %in% currents)
  expect_true("fast_prewarm:NBR_rolling_failed"  %in% currents)
  expect_true("fast_prewarm:NDMI_count_failed"   %in% currents)
  expect_true("fast_prewarm:NDMI_rolling_failed" %in% currents)
  expect_true("fast_prewarm:NDMI_trend_failed"   %in% currents)
  expect_true("fast_prewarm:NDRE_trend_failed"   %in% currents)
})


# ---- cooperative cancel between combinations -------------------------

test_that(".prewarm_fast_alerts stops cleanly when cancellation fires", {
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_ndvi_nbr_scene(cache)
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  # Cancel after the first combination has been processed: the checker
  # returns FALSE once (lets combo 1 run), then TRUE forever.
  calls <- 0L
  cancelled <- function() { calls <<- calls + 1L; calls > 1L }

  suppressMessages(
    nemeton:::.prewarm_fast_alerts(
      con, zone_id = 1L,
      date_from = "2025-05-01", date_to = "2025-06-01",
      cache_dir = cache, result_cache_dir = rcache,
      emit = .noop_emit, cancelled = cancelled))

  # Exactly the first combination (NDVI_count) was computed; the rest
  # were skipped by the cancel. The single written COG stays valid.
  cogs <- list.files(file.path(rcache, "zone_1"), pattern = "\\.tif$")
  expect_length(cogs, 1L)
  expect_match(cogs, "^fast_NDVI_count_")
})

test_that(".prewarm_fast_alerts does nothing when cancelled at entry", {
  skip_if_not_installed("terra")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  .write_ndvi_nbr_scene(cache)
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))

  nemeton:::.prewarm_fast_alerts(
    con, zone_id = 1L,
    date_from = "2025-05-01", date_to = "2025-06-01",
    cache_dir = cache, result_cache_dir = rcache,
    emit = .noop_emit, cancelled = function() TRUE)

  expect_false(dir.exists(file.path(rcache, "zone_1")))
})


# ---- input validation on the public entry point ---------------------

test_that("prewarm_alerts = TRUE requires cache_dir and a result cache dir", {
  skip_if_not_installed("terra")
  con <- structure(list(), class = c("FakeConn", "DBIConnection"))
  # No cache_dir.
  expect_error(
    ingest_sentinel2_timeseries(con, 1L, "2025-01-01", "2025-12-31",
                                prewarm_alerts = TRUE),
    "requires a non-empty.*cache_dir")
  # cache_dir but no result cache dir.
  expect_error(
    ingest_sentinel2_timeseries(con, 1L, "2025-01-01", "2025-12-31",
                                cache_dir = withr::local_tempdir(),
                                prewarm_alerts = TRUE),
    "prewarm_mask_cache_dir")
})


# ---- wiring into the full ingestion (mocked internals) ---------------

# Drive ingest_sentinel2_timeseries() to its success path without a DB or
# the network, with `.prewarm_fast_alerts` stubbed to record its call. We
# only assert WHETHER and WITH WHAT the pre-warm is invoked — the helper's
# own behaviour is covered by the unit tests above.
.with_mocked_ingest <- function(code) {
  plots <- sf::st_sf(
    id = 1L, plot_id = "P01", plot_type = "circle", radius_m = 10,
    geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
  aoi <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(
    c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326)))
  # Since v0.58.0 the ingest writes nothing to the DB — it only primes
  # the COG band cache via `.cache_scene_bands()`. Stub that to a no-op
  # so the loop completes without touching the network.
  testthat::local_mocked_bindings(
    .fetch_plots_sf    = function(con, zone_id) plots,
    .get_zone_aoi      = function(con, zone_id) aoi,
    stac_search_s2     = function(...) fake_scenes(
      dates = as.Date("2025-05-30"), cloud = 5),
    .cache_scene_bands = function(...) invisible(NULL)
  )
  force(code)
}

test_that("prewarm_alerts = FALSE (default) never calls the pre-warm", {
  skip_if_not_installed("sf")
  cache <- withr::local_tempdir()
  called <- FALSE
  testthat::local_mocked_bindings(
    .prewarm_fast_alerts = function(...) { called <<- TRUE; invisible(NULL) })
  .with_mocked_ingest({
    out <- suppressMessages(ingest_sentinel2_timeseries(
      structure(list(), class = c("FakeConn", "DBIConnection")),
      1L, "2025-05-01", "2025-06-01",
      bands = "NDVI", cache_dir = cache))   # prewarm_alerts defaults FALSE
    expect_identical(out$status, "success")
  })
  expect_false(called)
})

test_that("prewarm_alerts = TRUE forwards cache dirs + window to the pre-warm", {
  skip_if_not_installed("sf")
  cache  <- withr::local_tempdir()
  rcache <- withr::local_tempdir()
  seen <- NULL
  testthat::local_mocked_bindings(
    .prewarm_fast_alerts = function(con, zone_id, date_from, date_to,
                                    cache_dir, result_cache_dir,
                                    emit, cancelled) {
      seen <<- list(zone_id = zone_id, cache_dir = cache_dir,
                    result_cache_dir = result_cache_dir,
                    date_from = date_from, date_to = date_to)
      invisible(NULL)
    })
  .with_mocked_ingest({
    suppressMessages(ingest_sentinel2_timeseries(
      structure(list(), class = c("FakeConn", "DBIConnection")),
      1L, "2025-05-01", "2025-06-01",
      bands = "NDVI", cache_dir = cache,
      prewarm_alerts = TRUE, prewarm_mask_cache_dir = rcache))
  })
  expect_false(is.null(seen))
  expect_identical(seen$zone_id, 1L)
  expect_identical(seen$cache_dir, cache)
  expect_identical(seen$result_cache_dir, rcache)
})
