# test-monitoring.R — register_monitoring_zone + ingest_sentinel2_timeseries
#
# Pure unit tests cover argument validation and the canonical shape of
# the empty summary. Integration tests (skip_if_no_timescaledb) cover
# the COG band-cache priming + skip + STAC orchestration path, with the
# STAC backend and per-scene band caching mocked so the test stays fast
# and offline. Since v0.58.0 the pipeline writes no per-plot rows (the
# `obs_pixel` table was dropped) — it only primes the on-disk COG cache.

# ---- pure helpers ----------------------------------------------------

test_that(".empty_ingest_summary returns the canonical shape", {
  out <- nemeton:::.empty_ingest_summary()
  expect_s3_class(out, "data.frame")
  expect_named(out, c("n_scenes", "n_scenes_cached",
                      "n_plots", "bands", "status"))
  expect_equal(nrow(out), 1)
  expect_equal(out$n_scenes, 0L)
  expect_equal(out$n_scenes_cached, 0L)
  expect_equal(out$n_plots, 0L)
  expect_equal(out$bands, "")
})

test_that("register_monitoring_zone rejects non-sf zone_polygon", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RPostgres")
  placettes <- sf::st_sf(
    plot_id  = "P1",
    geometry = sf::st_sfc(sf::st_point(c(4, 47)), crs = 4326))
  expect_error(
    register_monitoring_zone(NULL, "Z", "not-sf", placettes),
    "must be an sf"
  )
})

test_that("register_monitoring_zone rejects placettes without plot_id", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RPostgres")
  pol <- sf::st_as_sfc(
    sf::st_bbox(c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
  bad <- sf::st_sf(
    geometry = sf::st_sfc(sf::st_point(c(4, 47)), crs = 4326))
  expect_error(
    register_monitoring_zone(NULL, "Z", pol, bad),
    "must be an sf object with a"
  )
})


# ---- integration: register_monitoring_zone --------------------------

test_that("register_monitoring_zone inserts zone + plots and returns id", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)

    # Lambert-93 inputs — must be reprojected to WGS84 on insert.
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 700000, ymin = 6500000,
        xmax = 750000, ymax = 6550000),
      crs = 2154))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      type     = c("Base", "Over"),
      geometry = sf::st_sfc(
        sf::st_point(c(710000, 6510000)),
        sf::st_point(c(720000, 6520000)),
        crs = 2154))

    zid <- register_monitoring_zone(con, "TestZone", pol, placettes,
                                    radius_m = 12)
    expect_type(zid, "integer")
    expect_true(zid > 0)

    # Zone row stored as 4326 — WKT longitudes/latitudes, not L93 metres.
    zrow <- DBI::dbGetQuery(con,
      "SELECT name, zone_wkt, crs_epsg FROM monitoring_zone WHERE id = $1",
      params = list(zid))
    expect_equal(zrow$name, "TestZone")
    expect_equal(zrow$crs_epsg, 4326L)
    expect_match(zrow$zone_wkt, "^POLYGON")
    # Round-trip the WKT and check the bbox falls in WGS84 France
    # (lon ~3-4°, lat ~47-48°). If the L93 input had leaked through
    # unprojected, the bbox would be in 6-7-digit metres instead.
    geom <- sf::st_as_sfc(zrow$zone_wkt, crs = 4326)
    bb   <- sf::st_bbox(geom)
    expect_true(bb["xmin"] >= 0   && bb["xmax"] <= 10)
    expect_true(bb["ymin"] >= 40  && bb["ymax"] <= 55)

    # Plot rows present, type and radius copied.
    prows <- DBI::dbGetQuery(con,
      "SELECT plot_id, plot_type, radius_m FROM plot
        WHERE zone_id = $1 ORDER BY plot_id",
      params = list(zid))
    expect_equal(nrow(prows), 2)
    expect_equal(prows$plot_id, c("P01", "P02"))
    expect_equal(prows$plot_type, c("Base", "Over"))
    expect_equal(as.numeric(prows$radius_m), c(12, 12))
  })
})

test_that("register_monitoring_zone keeps plot rows unique within a zone", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

    zid1 <- register_monitoring_zone(con, "Z", pol, placettes)
    zid2 <- register_monitoring_zone(con, "Z", pol, placettes)

    # NB: monitoring_zone has no ON CONFLICT — same name still creates a
    # new zone row. Document the actual behaviour here (the docstring
    # claims (zone_name, plot_id) idempotence; only plot_id is enforced).
    expect_true(zid2 != zid1)

    # Within each zone the plot is unique (UNIQUE(zone_id, plot_id) +
    # ON CONFLICT DO NOTHING).
    n1 <- DBI::dbGetQuery(con,
      "SELECT COUNT(*) AS n FROM plot WHERE zone_id = $1",
      params = list(zid1))$n
    n2 <- DBI::dbGetQuery(con,
      "SELECT COUNT(*) AS n FROM plot WHERE zone_id = $1",
      params = list(zid2))$n
    expect_equal(as.integer(n1), 1L)
    expect_equal(as.integer(n2), 1L)
  })
})


# ---- integration: ingest_sentinel2_timeseries -----------------------

test_that("ingest_sentinel2_timeseries warns when zone has no plots", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    DBI::dbExecute(con,
      "INSERT INTO monitoring_zone (name, zone_wkt) VALUES
       ('Empty', 'POLYGON((4 47,5 47,5 48,4 48,4 47))')")
    zid <- DBI::dbGetQuery(con,
      "SELECT id FROM monitoring_zone WHERE name = 'Empty'")$id

    expect_warning(
      out <- ingest_sentinel2_timeseries(con, zid,
                                         "2025-06-01", "2025-06-30"),
      "No plots registered"
    )
    expect_equal(out$n_scenes, 0L)
    expect_equal(out$n_plots, 0L)
  })
})

test_that("ingest_sentinel2_timeseries returns empty summary when STAC silent", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Z1", pol, placettes)

    testthat::local_mocked_bindings(
      stac_search_s2 = function(...) nemeton:::.empty_scene_tibble()
    )
    out <- ingest_sentinel2_timeseries(con, zid,
                                       "2025-06-01", "2025-06-30")
    expect_equal(out$n_scenes, 0L)
    expect_equal(out$n_scenes_cached, 0L)
  })
})

test_that("ingest_sentinel2_timeseries caches bands from mocked scenes", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Zfake", pol, placettes)

    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25")),
      cloud = c(5, 8))

    # The pipeline no longer writes to the DB; it only primes the COG
    # cache via .cache_scene_bands(). Count how many scenes are cached.
    n_cached <- 0L
    fake_cache <- function(scene, req_bands, ...) {
      n_cached <<- n_cached + 1L
      length(req_bands)
    }

    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = fake_cache
    )

    out <- ingest_sentinel2_timeseries(con, zid,
                                       "2025-06-01", "2025-07-01",
                                       bands = "NDVI")
    expect_equal(out$n_scenes, 2L)
    expect_equal(out$n_plots, 2L)
    expect_equal(out$bands, "NDVI")
    expect_equal(out$n_scenes_cached, 0L)  # nothing on disk yet
    expect_equal(n_cached, 2L)             # both scenes processed
    expect_false("n_obs_inserted" %in% names(out))
  })
})

test_that("ingest_sentinel2_timeseries skips scenes that fail band caching", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zskip", pol, placettes)

    scenes <- fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = function(...) stop("boom")
    )

    expect_warning(
      out <- ingest_sentinel2_timeseries(con, zid,
                                         "2025-06-01", "2025-07-15",
                                         bands = "NDVI"),
      "skipped"
    )
    expect_equal(out$n_scenes, 1L)
  })
})

test_that("ingest_sentinel2_timeseries emits progress callbacks across phases", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Zcb", pol, placettes)

    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25")),
      cloud = c(5, 8))

    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = function(scene, req_bands, ...) length(req_bands)
    )

    seen <- list()
    out <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-07-01",
      bands = "NDVI",
      progress_callback = function(p) {
        seen[[length(seen) + 1L]] <<- p
      }
    )
    expect_equal(out$n_scenes, 2L)

    phases <- vapply(seen, function(p) p$current, character(1))
    # Expected order: search -> search_done -> cache_lookup -> scene(x2)
    # -> complete. (s2:cache_lookup emitted whenever skip_cached = TRUE.)
    expect_identical(
      phases,
      c("s2:search", "s2:search_done", "s2:cache_lookup",
        "s2:scene", "s2:scene", "s2:complete")
    )

    # Locate events by their `current` key rather than by position so
    # the test survives further phase additions.
    first_of <- function(key) seen[[which(phases == key)[1L]]]

    search <- first_of("s2:search")
    expect_equal(search$n_plots, 2L)
    expect_equal(search$bands, "NDVI")

    expect_equal(first_of("s2:search_done")$total, 2L)

    scene_evt <- first_of("s2:scene")
    expect_equal(scene_evt$completed, 0L)
    expect_equal(scene_evt$total, 2L)
    expect_true(nzchar(scene_evt$scene_id))
    expect_s3_class(scene_evt$obs_date, "Date")
    expect_true(is.numeric(scene_evt$cloud_pct))

    done <- seen[[length(seen)]]
    expect_equal(done$completed, 2L)
    expect_equal(done$total, 2L)
    expect_equal(done$n_scenes_cached, 0L)
  })
})

test_that("ingest_sentinel2_timeseries reports skipped scenes via callback", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zcb_skip", pol, placettes)

    scenes <- fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = function(...) stop("fake extraction failure")
    )

    seen <- list()
    expect_warning(
      ingest_sentinel2_timeseries(
        con, zid, "2025-06-01", "2025-07-01",
        bands = "NDVI",
        progress_callback = function(p) {
          seen[[length(seen) + 1L]] <<- p
        }
      ),
      "skipped"
    )

    skipped <- Filter(function(p) identical(p$current, "s2:scene_skipped"), seen)
    expect_length(skipped, 1L)
    expect_match(skipped[[1]]$error_message, "fake extraction failure")
    expect_equal(skipped[[1]]$total, 1L)
  })
})

test_that("ingest_sentinel2_timeseries emits search_done when STAC silent", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zcb_empty", pol, placettes)

    testthat::local_mocked_bindings(
      stac_search_s2 = function(...) nemeton:::.empty_scene_tibble()
    )

    seen <- list()
    out <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-06-30",
      progress_callback = function(p) {
        seen[[length(seen) + 1L]] <<- p
      }
    )
    expect_equal(out$n_scenes, 0L)

    phases <- vapply(seen, function(p) p$current, character(1))
    expect_identical(phases, c("s2:search", "s2:search_done"))
    expect_equal(seen[[2]]$total, 0L)
  })
})


# ---- skip_cached: COG-cache scene skip (v0.58.0) ---------------------
#
# Since v0.58.0 skip_cached operates on the on-disk COG band cache, not
# on obs_pixel (dropped). A scene is skipped when every required band
# COG already exists under cache_dir.

# Mock for .cache_scene_bands that records how many scenes it processed
# and "writes" the required band COGs to the cache (empty placeholder
# files) so a subsequent run finds them and skips the scene.
.make_caching_mock <- function(counter_env) {
  function(scene, req_bands, crop_aoi = NULL, cache_dir = NULL, emit = NULL) {
    counter_env$n <- counter_env$n + 1L
    for (b in req_bands) {
      p <- nemeton:::.s2_band_cache_path(cache_dir, scene$scene_id, b)
      dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
      file.create(p)
    }
    length(req_bands)
  }
}

test_that("skip_cached skips scenes whose band COGs are already cached", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Zcache", pol, placettes)

    cache  <- withr::local_tempdir()
    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25", "2025-07-10")),
      cloud = c(5, 8, 10))

    counter <- new.env(); counter$n <- 0L
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = .make_caching_mock(counter)
    )

    # First run: cold cache, 3 scenes processed and their COGs written.
    out1 <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-15",
                                        bands = "NDVI", cache_dir = cache)
    expect_equal(out1$n_scenes, 3L)
    expect_equal(out1$n_scenes_cached, 0L)
    expect_equal(counter$n, 3L)

    # Second run: every required band COG is on disk → all skipped, no
    # .cache_scene_bands call. Counter does not increase.
    seen <- list()
    out2 <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-07-15",
      bands = "NDVI", cache_dir = cache,
      progress_callback = function(p) seen[[length(seen) + 1L]] <<- p
    )
    expect_equal(out2$n_scenes, 3L)
    expect_equal(out2$n_scenes_cached, 3L)
    expect_equal(counter$n, 3L)   # unchanged

    # Progress payloads: cache_lookup + 3× scene_cached + complete.
    phases <- vapply(seen, function(p) p$current, character(1))
    expect_true("s2:cache_lookup" %in% phases)
    cache_evt <- seen[[which(phases == "s2:cache_lookup")[1]]]
    expect_equal(cache_evt$n_cached, 3L)
    expect_equal(cache_evt$n_to_process, 0L)
    expect_equal(sum(phases == "s2:scene_cached"), 3L)
    expect_equal(sum(phases == "s2:scene"), 0L)
    done <- seen[[length(seen)]]
    expect_identical(done$current, "s2:complete")
    expect_equal(done$n_scenes_cached, 3L)
  })
})

test_that("skip_cached only skips scenes whose every required band is cached", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zpartial", pol, placettes)

    cache  <- withr::local_tempdir()
    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25")),
      cloud = c(5, 8))

    counter <- new.env(); counter$n <- 0L
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = .make_caching_mock(counter)
    )

    # First run caches NDVI bands only (B04, B08).
    ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-15",
                                bands = "NDVI", cache_dir = cache)
    expect_equal(counter$n, 2L)

    # Second run asks for NDVI + NBR. NBR needs B12, which is missing
    # for every scene → no cache hit, both scenes re-processed.
    out2 <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-15",
                                        bands = c("NDVI", "NBR"),
                                        cache_dir = cache)
    expect_equal(out2$n_scenes_cached, 0L)
    expect_equal(counter$n, 4L)   # 2 more scenes processed
  })
})

test_that("skip_cached = FALSE forces a re-fetch even when COGs are cached", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zforce", pol, placettes)

    cache  <- withr::local_tempdir()
    scenes <- fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)

    counter <- new.env(); counter$n <- 0L
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = .make_caching_mock(counter)
    )

    ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-01",
                                bands = "NDVI", cache_dir = cache)
    expect_equal(counter$n, 1L)

    out <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-01",
                                       bands = "NDVI", cache_dir = cache,
                                       skip_cached = FALSE)
    expect_equal(out$n_scenes_cached, 0L)
    expect_equal(counter$n, 2L)   # processed again despite cache hit
  })
})

test_that(".s2_required_bands maps indices to the COG bands they need", {
  expect_setequal(nemeton:::.s2_required_bands("NDVI"), c("B04", "B08"))
  expect_setequal(nemeton:::.s2_required_bands("NBR"),  c("B08", "B12"))
  expect_setequal(nemeton:::.s2_required_bands(c("NDVI", "NBR")),
                  c("B04", "B08", "B12"))
})

test_that(".scene_cogs_cached is FALSE without a cache dir and TRUE once all bands exist", {
  expect_false(nemeton:::.scene_cogs_cached(NULL, "S2_X", c("B04", "B08")))
  expect_false(nemeton:::.scene_cogs_cached("", "S2_X", c("B04", "B08")))
  cache <- withr::local_tempdir()
  expect_false(nemeton:::.scene_cogs_cached(cache, "S2_X", c("B04", "B08")))
  for (b in c("B04", "B08")) {
    p <- nemeton:::.s2_band_cache_path(cache, "S2_X", b)
    dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
    file.create(p)
  }
  expect_true(nemeton:::.scene_cogs_cached(cache, "S2_X", c("B04", "B08")))
  # A missing band keeps the scene un-cached.
  expect_false(nemeton:::.scene_cogs_cached(cache, "S2_X",
                                            c("B04", "B08", "B12")))
})


# ---- S2 COG band cache (v0.21.4) -------------------------------------

test_that(".ext_contains is a strict bbox-containment predicate", {
  outer <- c(0, 100, 0, 100)
  expect_true(nemeton:::.ext_contains(outer, c(10, 90, 10, 90)))
  expect_true(nemeton:::.ext_contains(outer, c(0, 100, 0, 100)))
  expect_false(nemeton:::.ext_contains(outer, c(-1, 50, 10, 50)))
  expect_false(nemeton:::.ext_contains(outer, c(10, 101, 10, 50)))
  expect_false(nemeton:::.ext_contains(outer, c(10, 90, -1, 50)))
  expect_false(nemeton:::.ext_contains(outer, c(10, 90, 10, 101)))
})

test_that(".ext_contains accepts terra::ext SpatExtent objects (S4)", {
  # Regression for v0.21.8 — every cache-hit used to error out with
  # "cannot coerce type 'S4' to vector of type 'double'" because the
  # old implementation did `c(outer[1], …)` on an S4 SpatExtent.
  skip_if_not_installed("terra")
  outer_se <- terra::ext(c(0, 100, 0, 100))
  inner_se <- terra::ext(c(10, 90, 10, 90))
  expect_true(nemeton:::.ext_contains(outer_se, inner_se))
  expect_true(nemeton:::.ext_contains(outer_se, outer_se))
  too_wide <- terra::ext(c(-10, 110, 10, 90))
  expect_false(nemeton:::.ext_contains(outer_se, too_wide))
  too_tall <- terra::ext(c(10, 90, -10, 110))
  expect_false(nemeton:::.ext_contains(outer_se, too_tall))
  # Mixed call (SpatExtent outer, numeric inner) must also work.
  expect_true(nemeton:::.ext_contains(outer_se, c(10, 90, 10, 90)))
  expect_true(nemeton:::.ext_contains(c(0, 100, 0, 100), inner_se))
})

test_that(".ext_contains tolerance argument absorbs sub-pixel jitter (v0.47.3)", {
  # spec « solution A » — at the cache-hit call site we pass
  # `tolerance = max(terra::res(r_cached))` so a sub-pixel mismatch
  # between the cached extent and the AOI does not trigger a
  # spurious CACHE-STALE. Default `tolerance = 0` preserves the
  # strict pre-v0.47.3 behaviour for any other caller.
  outer <- c(0, 100, 0, 100)

  # Default (strict) — pre-v0.47.3 behaviour.
  expect_false(nemeton:::.ext_contains(outer, c(-5, 90, 10, 50)))
  expect_false(nemeton:::.ext_contains(outer, c(10, 105, 10, 50)))

  # With tolerance, sub-pixel overshoot is accepted.
  expect_true(nemeton:::.ext_contains(outer, c(-5, 90, 10, 50),
                                      tolerance = 10))
  expect_true(nemeton:::.ext_contains(outer, c(10, 105, 10, 50),
                                      tolerance = 10))
  expect_true(nemeton:::.ext_contains(outer, c(-10, 110, -10, 110),
                                      tolerance = 10))

  # Beyond tolerance still fails.
  expect_false(nemeton:::.ext_contains(outer, c(-11, 90, 10, 50),
                                       tolerance = 10))
  expect_false(nemeton:::.ext_contains(outer, c(10, 111, 10, 50),
                                       tolerance = 10))

  # Negative tolerance is allowed (= more strict); validate it works
  # symmetrically though we never use it.
  expect_false(nemeton:::.ext_contains(outer, c(0, 100, 0, 100),
                                       tolerance = -1))
})


test_that(".snap_ext_to_grid floors xmin/ymin, ceils xmax/ymax (v0.48.1)", {
  # 10 m grid (S2 B04/B08)
  expect_equal(nemeton:::.snap_ext_to_grid(c(709356.7, 709802.3,
                                             5143468.1, 5145481.9), 10),
               c(709350, 709810, 5143460, 5145490))
  # Already on grid → no change
  expect_equal(nemeton:::.snap_ext_to_grid(c(709360, 709800,
                                             5143470, 5145480), 10),
               c(709360, 709800, 5143470, 5145480))
  # 20 m grid (B12)
  expect_equal(nemeton:::.snap_ext_to_grid(c(709353, 709797,
                                             5143461, 5145477), 20),
               c(709340, 709800, 5143460, 5145480))
})


test_that(".ext_contains_at_grid: identical extents → ok (v0.48.1)", {
  ext <- c(709360, 709800, 5143470, 5145480)
  cont <- nemeton:::.ext_contains_at_grid(ext, ext, res = 10)
  expect_true(cont$ok)
  # Margins all = 1 pixel (the default tolerance)
  expect_equal(cont$delta_m, c(10, 10, 10, 10))
})


test_that(".ext_contains_at_grid: sub-pixel jitter is absorbed (v0.48.1)", {
  # cached on the grid
  cached <- c(709360, 709800, 5143470, 5145480)
  # needed shifted by a tiny amount that still snaps to the SAME grid
  # cells (the floor/ceil rounds to identical values)
  needed <- c(709360.4, 709799.6, 5143470.4, 5145479.6)
  cont   <- nemeton:::.ext_contains_at_grid(cached, needed, res = 10)
  expect_true(cont$ok)
})


test_that(".ext_contains_at_grid: 2-pixel overshoot in xmax → STALE (v0.48.1)", {
  cached <- c(709360, 709800, 5143470, 5145480)
  # needed.xmax = 709825 → snaps to 709830 → outer + tol = 709810
  # → 709830 > 709810 → STALE on xmax
  needed <- c(709360, 709825, 5143470, 5145480)
  cont   <- nemeton:::.ext_contains_at_grid(cached, needed, res = 10)
  expect_false(cont$ok)
  # delta_m on xmax = (709810 - 709830) = -20 → < 0 = overshoot
  expect_lt(cont$delta_m[2], 0)
})


test_that(".s2_tile_ext_memoize caches per-tile native extent (v0.48.3)", {
  skip_if_not_installed("terra")
  # Set up a fake "COG" on disk that terra::rast() can open without
  # network. Mock .pc_ensure_fresh_href to return the local path so
  # the memoization helper exercises the real terra::rast() path.
  tmp <- withr::local_tempfile(fileext = ".tif")
  r <- terra::rast(nrows = 10, ncols = 10,
                   xmin = 700000, xmax = 700100,
                   ymin = 5140000, ymax = 5140100,
                   crs = "EPSG:32631", vals = 1:100)
  terra::writeRaster(r, tmp, filetype = "GTiff", overwrite = TRUE)

  nemeton:::.s2_tile_ext_cache_clear()
  call_count <- 0L
  testthat::local_mocked_bindings(
    .pc_ensure_fresh_href = function(href) {
      call_count <<- call_count + 1L
      tmp
    },
    .package = "nemeton"
  )

  # First call → fetches, populates memo
  e1 <- nemeton:::.s2_tile_ext_memoize("T31TFM",
                                       "https://fake/T31TFM/B04.tif")
  expect_s4_class(e1, "SpatExtent")
  expect_equal(call_count, 1L)

  # Second call same tile → memo hit, no extra .pc_ensure_fresh_href
  e2 <- nemeton:::.s2_tile_ext_memoize("T31TFM",
                                       "https://fake/T31TFM/B08.tif")
  expect_equal(call_count, 1L)  # unchanged
  expect_equal(as.vector(e1), as.vector(e2))

  # Different tile → new fetch
  e3 <- nemeton:::.s2_tile_ext_memoize("T31TGM",
                                       "https://fake/T31TGM/B04.tif")
  expect_equal(call_count, 2L)

  # Clear empties the memo
  nemeton:::.s2_tile_ext_cache_clear()
  e4 <- nemeton:::.s2_tile_ext_memoize("T31TFM",
                                       "https://fake/T31TFM/B04.tif")
  expect_equal(call_count, 3L)
})


test_that(".s2_tile_ext_memoize returns NULL on bad tile_code (v0.48.3)", {
  expect_null(nemeton:::.s2_tile_ext_memoize("", "x"))
  expect_null(nemeton:::.s2_tile_ext_memoize(NA_character_, "x"))
})


test_that(".cache_skip_validation honours the env var (v0.48.1)", {
  withr::with_envvar(c(NEMETON_S2_CACHE_SKIP_VALIDATION = ""), {
    expect_false(nemeton:::.cache_skip_validation())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_SKIP_VALIDATION = "1"), {
    expect_true(nemeton:::.cache_skip_validation())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_SKIP_VALIDATION = "TRUE"), {
    expect_true(nemeton:::.cache_skip_validation())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_SKIP_VALIDATION = "true"), {
    expect_true(nemeton:::.cache_skip_validation())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_SKIP_VALIDATION = "yes"), {
    # Only "TRUE" / "1" trigger ; "yes" stays strict-FALSE.
    expect_false(nemeton:::.cache_skip_validation())
  })
})


test_that(".ext_as_numeric returns (xmin, xmax, ymin, ymax) for both shapes", {
  skip_if_not_installed("terra")
  out_se   <- nemeton:::.ext_as_numeric(terra::ext(c(1, 2, 3, 4)))
  out_num  <- nemeton:::.ext_as_numeric(c(1, 2, 3, 4))
  expect_equal(out_se,  c(1, 2, 3, 4))
  expect_equal(out_num, c(1, 2, 3, 4))
})

test_that(".s2_band_cache_path sanitises scene_id and does NOT create the dir", {
  cache <- withr::local_tempdir()
  out <- nemeton:::.s2_band_cache_path(cache, "S2A:MSIL2A/2024 06 01", "B04")
  expect_type(out, "character")
  expect_match(basename(out), "^B04\\.tif$")
  # No ':', '/' (in the scene_id portion), or space leaks into the path.
  scene_leaf <- basename(dirname(out))
  expect_false(grepl("[ :]", scene_leaf))
  # Critically: the scene dir must NOT exist yet — creation is deferred
  # to writeRaster time so failed fetches don't leave empty dirs.
  expect_false(dir.exists(dirname(out)))

  # NULL / empty cache_dir → NULL output (caching disabled).
  expect_null(nemeton:::.s2_band_cache_path(NULL, "scene", "B04"))
  expect_null(nemeton:::.s2_band_cache_path("", "scene", "B04"))
})

test_that(".get_s2_band_raster: scene dir is NOT created when terra::rast fails", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scene_id <- "S2_TEST_FAIL"

  # Mock terra::rast to throw — simulates a 504 / 403 from VSI.
  testthat::local_mocked_bindings(
    rast = function(x, ...) stop("simulated VSI failure"),
    .package = "terra"
  )

  buf <- sf::st_sf(
    radius_m = 5,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(50, 50)), 5),
                          crs = 2154))
  scene <- data.frame(scene_id = scene_id,
                      href_B04 = "https://example/nope.tif",
                      stringsAsFactors = FALSE)
  events <- list()
  emit_fn <- function(p) events[[length(events) + 1L]] <<- p

  expect_error(
    nemeton:::.get_s2_band_raster(scene, "B04", buf, cache_dir = cache,
                                  emit = emit_fn),
    "simulated VSI failure"
  )
  # No directory should have been created.
  expect_false(dir.exists(file.path(cache, scene_id)))
  # `s2:band_fetch_failed` event was emitted before throwing.
  phases <- vapply(events, function(p) p$current, character(1))
  expect_true("s2:band_fetch_failed" %in% phases)
  failed <- events[[which(phases == "s2:band_fetch_failed")[1]]]
  expect_equal(failed$band, "B04")
  expect_equal(failed$scene_id, scene_id)
  expect_match(failed$error_message, "simulated VSI failure")
})

test_that(".get_s2_band_raster: cache hit reads the COG without HTTP", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scene_id <- "S2_TEST_HIT"

  # Build a synthetic Int16 raster covering the AOI fully.
  r <- terra::rast(nrows = 20, ncols = 20,
                   xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                   crs = "EPSG:2154", vals = seq_len(400))
  terra::values(r) <- as.integer(seq_len(400))
  scene_dir <- file.path(cache, scene_id); dir.create(scene_dir)
  cached <- file.path(scene_dir, "B04.tif")
  terra::writeRaster(r, cached,
                     gdal = c("TILED=YES", "COMPRESS=DEFLATE"),
                     overwrite = TRUE)

  # A single placette in the centre, radius 5 m.
  buf <- sf::st_sf(
    radius_m = 5,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(100, 100)), 5),
                          crs = 2154))

  # href is a bogus URL — should never be opened on a cache hit.
  scene <- data.frame(scene_id = scene_id,
                      href_B04 = "https://nope/should-not-be-read",
                      stringsAsFactors = FALSE)
  events <- list()
  out <- nemeton:::.get_s2_band_raster(
    scene, "B04", buf, cache_dir = cache,
    emit = function(p) events[[length(events) + 1L]] <<- p)
  expect_s4_class(out, "SpatRaster")
  expect_length(events, 1L)
  expect_identical(events[[1]]$current, "s2:band_cached")
  expect_identical(events[[1]]$band, "B04")
})

test_that(".get_s2_band_raster: cache miss fetches, writes, emits 's2:band_fetched'", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scene_id <- "S2_TEST_MISS"

  # Source raster on local disk — stand-in for the VSI URL.
  src <- file.path(withr::local_tempdir(), "src.tif")
  r_src <- terra::rast(nrows = 50, ncols = 50,
                       xmin = 0, xmax = 500, ymin = 0, ymax = 500,
                       crs = "EPSG:2154", vals = seq_len(2500))
  terra::writeRaster(r_src, src, overwrite = TRUE)

  buf <- sf::st_sf(
    radius_m = 10,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(250, 250)), 10),
                          crs = 2154))

  scene <- data.frame(scene_id = scene_id, href_B08 = src,
                      stringsAsFactors = FALSE)
  events <- list()
  out <- nemeton:::.get_s2_band_raster(
    scene, "B08", buf, cache_dir = cache,
    emit = function(p) events[[length(events) + 1L]] <<- p)

  expect_s4_class(out, "SpatRaster")
  cached_path <- file.path(cache, scene_id, "B08.tif")
  expect_true(file.exists(cached_path))
  expect_length(events, 1L)
  expect_identical(events[[1]]$current, "s2:band_fetched")

  # Second call → cache hit on the freshly-written file.
  events2 <- list()
  out2 <- nemeton:::.get_s2_band_raster(
    scene, "B08", buf, cache_dir = cache,
    emit = function(p) events2[[length(events2) + 1L]] <<- p)
  expect_s4_class(out2, "SpatRaster")
  expect_identical(events2[[1]]$current, "s2:band_cached")
})

test_that(".get_s2_band_raster: stale cache (extent too small) is overwritten", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scene_id <- "S2_TEST_STALE"

  # Cache holds a tiny crop covering only (0..50, 0..50).
  r_small <- terra::rast(nrows = 5, ncols = 5,
                         xmin = 0, xmax = 50, ymin = 0, ymax = 50,
                         crs = "EPSG:2154", vals = 1:25)
  scene_dir <- file.path(cache, scene_id); dir.create(scene_dir)
  cached <- file.path(scene_dir, "B12.tif")
  terra::writeRaster(r_small, cached,
                     gdal = c("TILED=YES", "COMPRESS=DEFLATE"),
                     overwrite = TRUE)

  # Source covers (0..500, 0..500). Plot at (400, 400) → far outside cache.
  src <- file.path(withr::local_tempdir(), "src.tif")
  r_src <- terra::rast(nrows = 50, ncols = 50,
                       xmin = 0, xmax = 500, ymin = 0, ymax = 500,
                       crs = "EPSG:2154", vals = seq_len(2500))
  terra::writeRaster(r_src, src, overwrite = TRUE)

  buf <- sf::st_sf(
    radius_m = 10,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(400, 400)), 10),
                          crs = 2154))

  scene <- data.frame(scene_id = scene_id, href_B12 = src,
                      stringsAsFactors = FALSE)
  events <- list()
  out <- nemeton:::.get_s2_band_raster(
    scene, "B12", buf, cache_dir = cache,
    emit = function(p) events[[length(events) + 1L]] <<- p)
  expect_s4_class(out, "SpatRaster")
  # Stale cache → no `s2:band_cached`, miss path runs and rewrites.
  expect_identical(events[[1]]$current, "s2:band_fetched")
  # New cached file now encloses the AOI.
  new_ext <- terra::ext(terra::rast(cached))
  expect_true(new_ext[1] <= 390 && new_ext[2] >= 410)
})

# ---- diagnose_s2_cache + debug log gating (v0.21.7) -----------------

test_that(".s2_cache_debug_enabled honours NEMETON_S2_CACHE_DEBUG", {
  withr::with_envvar(c(NEMETON_S2_CACHE_DEBUG = ""), {
    expect_false(nemeton:::.s2_cache_debug_enabled())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_DEBUG = "FALSE"), {
    expect_false(nemeton:::.s2_cache_debug_enabled())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_DEBUG = "TRUE"), {
    expect_true(nemeton:::.s2_cache_debug_enabled())
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_DEBUG = "1"), {
    expect_true(nemeton:::.s2_cache_debug_enabled())
  })
})

test_that(".s2_cache_log is silent unless NEMETON_S2_CACHE_DEBUG is on", {
  withr::with_envvar(c(NEMETON_S2_CACHE_DEBUG = "FALSE"), {
    expect_silent(nemeton:::.s2_cache_log("anything"))
  })
  withr::with_envvar(c(NEMETON_S2_CACHE_DEBUG = "TRUE"), {
    expect_message(nemeton:::.s2_cache_log("hello"), "s2_cache.*hello")
  })
})

test_that("diagnose_s2_cache reports a missing cache cleanly", {
  out <- diagnose_s2_cache("/nonexistent/path", verbose = FALSE)
  expect_equal(out$n_scenes, 0L)
  expect_equal(out$n_populated, 0L)
  expect_equal(out$n_empty, 0L)
})

test_that("diagnose_s2_cache reports an empty cache cleanly", {
  cache <- withr::local_tempdir()
  out <- diagnose_s2_cache(cache, verbose = FALSE)
  expect_equal(out$n_scenes, 0L)
})

test_that("diagnose_s2_cache distinguishes populated vs empty scene dirs", {
  cache <- withr::local_tempdir()
  # Populated scene
  dir.create(file.path(cache, "S2_OK"))
  writeLines("fake", file.path(cache, "S2_OK", "B04.tif"))
  writeLines("fake", file.path(cache, "S2_OK", "B08.tif"))
  # Empty scene (leftover from v0.21.4)
  dir.create(file.path(cache, "S2_EMPTY"))

  out <- diagnose_s2_cache(cache, verbose = FALSE)
  expect_equal(out$n_scenes, 2L)
  expect_equal(out$n_populated, 1L)
  expect_equal(out$n_empty, 1L)
  expect_true(out$total_bytes > 0)
  expect_equal(basename(out$empty_dirs), "S2_EMPTY")
})

test_that("diagnose_s2_cache prints a cli summary when verbose = TRUE", {
  cache <- withr::local_tempdir()
  dir.create(file.path(cache, "S2_X"))
  writeLines("fake", file.path(cache, "S2_X", "B04.tif"))
  expect_message(diagnose_s2_cache(cache, verbose = TRUE), "S2 cache at")
})


# ---- existing PC retry tests -----------------------------------------

test_that(".terra_rast_with_pc_retry: non-PC error propagates without retry", {
  skip_if_not_installed("terra")
  n_calls <- 0L
  testthat::local_mocked_bindings(
    rast = function(x, ...) { n_calls <<- n_calls + 1L; stop("HTTP 504 timeout") },
    .package = "terra"
  )
  events <- list()
  expect_error(
    nemeton:::.terra_rast_with_pc_retry(
      "https://example/scene/B04.tif",   # NOT a PC blob URL
      emit_fn  = function(p) events[[length(events) + 1L]] <<- p,
      scene_id = "S", band = "B04"
    ),
    "HTTP 504 timeout"
  )
  expect_equal(n_calls, 1L)   # no retry attempted
  phases <- vapply(events, function(p) p$current, character(1))
  expect_true("s2:band_fetch_failed" %in% phases)
  expect_false("s2:pc_token_refreshed" %in% phases)
})

test_that(".terra_rast_with_pc_retry: PC 403 triggers token refresh + retry", {
  skip_if_not_installed("terra")
  pc_href <- "https://sentinel2l2a01.blob.core.windows.net/sentinel2-l2/X.tif?se=expired&sp=r&sig=old"

  # First call: 403. Second call (with re-signed href): success.
  call_log <- list()
  fake_rast_seq <- list(
    function(x, ...) stop("HTTP error code: 403 Forbidden"),
    function(x, ...) { call_log[["second_href"]] <<- x; "FAKE_RASTER" }
  )
  call_idx <- 0L
  testthat::local_mocked_bindings(
    rast = function(x, ...) {
      call_idx <<- call_idx + 1L
      fake_rast_seq[[call_idx]](x, ...)
    },
    .package = "terra"
  )
  # Stub the token fetch so we don't hit the network.
  testthat::local_mocked_bindings(
    .pc_collection_token = function(collection, ...) "se=fresh&sp=r&sig=new",
    .package = "nemeton"
  )
  events <- list()
  out <- nemeton:::.terra_rast_with_pc_retry(
    pc_href,
    emit_fn  = function(p) events[[length(events) + 1L]] <<- p,
    scene_id = "S2_T", band = "B04"
  )
  expect_identical(out, "FAKE_RASTER")
  # The second call must have used the re-signed href, not the original.
  expect_false(grepl("sig=old", call_log$second_href, fixed = TRUE))
  expect_true(grepl("sig=new", call_log$second_href, fixed = TRUE))
  phases <- vapply(events, function(p) p$current, character(1))
  expect_true("s2:pc_token_refreshed" %in% phases)
  expect_false("s2:band_fetch_failed" %in% phases)
})

test_that(".terra_rast_with_pc_retry: 403 that survives refresh emits band_fetch_failed", {
  skip_if_not_installed("terra")
  pc_href <- "https://sentinel2l2a01.blob.core.windows.net/c/X.tif?se=x&sig=old"
  testthat::local_mocked_bindings(
    rast = function(x, ...) stop("HTTP error code: 403 Forbidden"),
    .package = "terra"
  )
  testthat::local_mocked_bindings(
    .pc_collection_token = function(collection, ...) "se=fresh&sig=new",
    .package = "nemeton"
  )
  events <- list()
  expect_warning(
    expect_error(
      nemeton:::.terra_rast_with_pc_retry(
        pc_href,
        emit_fn  = function(p) events[[length(events) + 1L]] <<- p,
        scene_id = "S", band = "B04",
        max_tries = 2L   # bound to keep the test snappy
      ),
      "403 Forbidden"
    ),
    "gave up"
  )
  failed <- Filter(function(p) p$current == "s2:band_fetch_failed", events)
  expect_length(failed, 1L)
  expect_match(failed[[1]]$error_message, "403 Forbidden")
})


# ---- transient network retry (v0.21.9) -------------------------------

test_that("transient error patterns are recognised by the retry classifier", {
  skip_if_not_installed("terra")
  transient_messages <- c(
    "Could not resolve host: x.blob.core.windows.net",
    "Could not connect to x.example.com",
    "Connection timed out",
    "Connection refused",
    "Connection reset by peer",
    "Network unreachable",
    "Network is unreachable",
    "Temporary failure in name resolution",
    "HTTP error: 502 Bad Gateway",
    "HTTP error 504 Gateway Timeout",
    "GDAL error 1: timeout"
  )
  pattern <- paste0(
    "could not resolve host|could not connect|",
    "connection (timed out|reset|refused)|",
    "network (is )?unreachable|temporary failure|",
    "http error.*\\b5\\d{2}\\b|gdal error.*timeout"
  )
  for (msg in transient_messages) {
    expect_true(
      grepl(pattern, msg, ignore.case = TRUE, perl = TRUE),
      info = sprintf("Expected pattern to match: %s", msg)
    )
  }
  # Sanity: hard errors must NOT match.
  for (msg in c("File not found (404)", "Malformed COG", "Permission denied")) {
    expect_false(
      grepl(pattern, msg, ignore.case = TRUE, perl = TRUE),
      info = sprintf("Pattern accidentally matched: %s", msg)
    )
  }
})

test_that(".terra_rast_with_pc_retry: transient DNS error retries on the same URL", {
  skip_if_not_installed("terra")
  call_idx <- 0L
  testthat::local_mocked_bindings(
    rast = function(x, ...) {
      call_idx <<- call_idx + 1L
      if (call_idx < 2L) {
        stop("Could not resolve host: sentinel2l2a01.blob.core.windows.net")
      }
      "FAKE_RASTER"
    },
    .package = "terra"
  )
  events <- list()
  out <- nemeton:::.terra_rast_with_pc_retry(
    "https://sentinel2l2a01.blob.core.windows.net/X.tif?sig=Z",
    emit_fn  = function(p) events[[length(events) + 1L]] <<- p,
    scene_id = "S", band = "B04",
    max_tries = 2L   # second attempt succeeds, first attempt sleeps 2s
  )
  expect_identical(out, "FAKE_RASTER")
  expect_equal(call_idx, 2L)
  retries <- Filter(function(p) p$current == "s2:band_fetch_retry", events)
  expect_length(retries, 1L)
  expect_equal(retries[[1]]$attempt, 1L)
  expect_equal(retries[[1]]$max_tries, 2L)
  expect_match(retries[[1]]$error_message, "Could not resolve host")
})

test_that(".terra_rast_with_pc_retry: persistent transient → gives up after max_tries", {
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    rast = function(x, ...) stop("Could not resolve host: x"),
    .package = "terra"
  )
  events <- list()
  expect_warning(
    expect_error(
      nemeton:::.terra_rast_with_pc_retry(
        "https://x.example/B04.tif",
        emit_fn  = function(p) events[[length(events) + 1L]] <<- p,
        scene_id = "S", band = "B04",
        max_tries = 2L
      ),
      "Could not resolve host"
    ),
    "gave up"
  )
  failed <- Filter(function(p) p$current == "s2:band_fetch_failed", events)
  expect_length(failed, 1L)
})

test_that(".terra_rast_with_pc_retry: NEMETON_S2_MAX_TRIES env var overrides default", {
  skip_if_not_installed("terra")
  withr::local_envvar(NEMETON_S2_MAX_TRIES = "1")
  n_calls <- 0L
  testthat::local_mocked_bindings(
    rast = function(x, ...) { n_calls <<- n_calls + 1L; stop("Connection timed out") },
    .package = "terra"
  )
  # The retry path emits a "gave up" cli_warn before erroring — consume
  # it with expect_warning() so it doesn't leak as an uncaught test
  # warning (the sibling test above already covers the warning text).
  expect_warning(
    expect_error(
      nemeton:::.terra_rast_with_pc_retry(
        "https://x.example/B04.tif", scene_id = "S", band = "B04"
      ),
      "Connection timed out"
    ),
    "gave up"
  )
  # Only one attempt — no retry on Sys.sleep.
  expect_equal(n_calls, 1L)
})

test_that(".get_s2_band_raster: cache_dir = NULL bypasses the cache entirely", {
  skip_if_not_installed("terra")
  src <- file.path(withr::local_tempdir(), "src.tif")
  r_src <- terra::rast(nrows = 10, ncols = 10,
                       xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                       crs = "EPSG:2154", vals = 1:100)
  terra::writeRaster(r_src, src, overwrite = TRUE)
  buf <- sf::st_sf(
    radius_m = 5,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(50, 50)), 5),
                          crs = 2154))
  scene <- data.frame(scene_id = "X", href_B04 = src,
                      stringsAsFactors = FALSE)
  events <- list()
  out <- nemeton:::.get_s2_band_raster(
    scene, "B04", buf, cache_dir = NULL,
    emit = function(p) events[[length(events) + 1L]] <<- p)
  expect_s4_class(out, "SpatRaster")
  expect_length(events, 0L)
})

test_that("ingest_sentinel2_timeseries forwards cache_dir to .cache_scene_bands", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zforward", pol, placettes)

    seen_cache_dir <- NA_character_
    fake_cache <- function(scene, req_bands, crop_aoi = NULL,
                           cache_dir = NULL, emit = NULL) {
      seen_cache_dir <<- if (is.null(cache_dir)) NA_character_ else cache_dir
      length(req_bands)
    }

    scenes <- fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .cache_scene_bands = fake_cache
    )

    cache <- withr::local_tempdir()
    ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-07-01",
      bands = "NDVI", skip_cached = FALSE, cache_dir = cache
    )
    expect_identical(seen_cache_dir, cache)
  })
})


# ---- internal helpers ------------------------------------------------

test_that(".fetch_plots_sf returns empty sf for unknown zone", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    out <- nemeton:::.fetch_plots_sf(con, 99999L)
    expect_s3_class(out, "sf")
    expect_equal(nrow(out), 0)
  })
})

test_that(".fetch_plots_sf round-trips geometry via WKT", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(4.5, 47.5)),
        sf::st_point(c(4.6, 47.6)),
        crs = 4326))
    zid <- register_monitoring_zone(con, "Zgeom", pol, placettes)

    out <- nemeton:::.fetch_plots_sf(con, zid)
    expect_s3_class(out, "sf")
    expect_equal(nrow(out), 2)
    expect_equal(sf::st_crs(out)$epsg, 4326L)
    coords <- sf::st_coordinates(out)
    expect_equal(sort(coords[, "X"]), c(4.5, 4.6))
  })
})

# ---- v0.21.10: materialize closure protects pixel reads --------------

test_that(".terra_rast_with_pc_retry: materialize closure runs once on success", {
  skip_if_not_installed("terra")
  n_rast      <- 0L
  n_material  <- 0L
  testthat::local_mocked_bindings(
    rast = function(x, ...) { n_rast <<- n_rast + 1L; "RAW_RASTER" },
    .package = "terra"
  )
  out <- nemeton:::.terra_rast_with_pc_retry(
    "https://example/scene/B04.tif",
    scene_id    = "S", band = "B04",
    materialize = function(r0) {
      n_material <<- n_material + 1L
      expect_identical(r0, "RAW_RASTER")
      "MATERIALIZED_RASTER"
    }
  )
  expect_identical(out, "MATERIALIZED_RASTER")
  expect_equal(n_rast, 1L)
  expect_equal(n_material, 1L)
})

test_that(".terra_rast_with_pc_retry: materialize failure with PC auth → token refresh + retry", {
  skip_if_not_installed("terra")
  pc_href <- "https://sentinel2l2a01.blob.core.windows.net/c/X.tif?se=expired&sp=r&sig=old"

  call_log <- list()
  testthat::local_mocked_bindings(
    rast = function(x, ...) {
      call_log[[length(call_log) + 1L]] <<- x
      paste0("RAW#", length(call_log))
    },
    .package = "terra"
  )
  testthat::local_mocked_bindings(
    .pc_collection_token = function(collection, ...) "se=fresh&sp=r&sig=new",
    .package = "nemeton"
  )

  # materialize fails the FIRST time with a 403 (simulates SAS expiry
  # surfacing during pixel read), succeeds the second time on the
  # re-signed href.
  mat_calls <- 0L
  materializer <- function(r0) {
    mat_calls <<- mat_calls + 1L
    if (mat_calls == 1L) stop("HTTP error code: 403 Forbidden")
    "MATERIALIZED_OK"
  }

  events <- list()
  out <- nemeton:::.terra_rast_with_pc_retry(
    pc_href,
    emit_fn     = function(p) events[[length(events) + 1L]] <<- p,
    scene_id    = "S2_T", band = "B04",
    materialize = materializer
  )
  expect_identical(out, "MATERIALIZED_OK")
  expect_equal(mat_calls, 2L)
  expect_equal(length(call_log), 2L)
  # Second open used the re-signed href.
  expect_false(grepl("sig=old", call_log[[2]], fixed = TRUE))
  expect_true(grepl("sig=new", call_log[[2]], fixed = TRUE))
  phases <- vapply(events, function(p) p$current, character(1))
  expect_true("s2:pc_token_refreshed" %in% phases)
})

test_that(".terra_rast_with_pc_retry: materialize failure with transient error → backoff retry", {
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    rast = function(x, ...) "RAW",
    .package = "terra"
  )
  mat_calls <- 0L
  materializer <- function(r0) {
    mat_calls <<- mat_calls + 1L
    if (mat_calls < 2L) stop("HTTP error code: 504 Gateway Timeout")
    "OK"
  }
  events <- list()
  # max_tries = 2 → one retry with a 2 s backoff (2^1). Accept the
  # 2 s test cost rather than mocking base::Sys.sleep (which is
  # awkward with local_mocked_bindings on base).
  out <- nemeton:::.terra_rast_with_pc_retry(
    "https://example/scene/B04.tif",     # non-PC href
    emit_fn     = function(p) events[[length(events) + 1L]] <<- p,
    scene_id    = "S", band = "B04",
    max_tries   = 2L,
    materialize = materializer
  )
  expect_identical(out, "OK")
  expect_equal(mat_calls, 2L)
  phases <- vapply(events, function(p) p$current, character(1))
  expect_true("s2:band_fetch_retry" %in% phases)
})

test_that(".get_s2_band_raster: empty scene_dir is removed when writeRaster fails", {
  skip_if_not_installed("terra")
  cache    <- withr::local_tempdir()
  scene_id <- "S2_WRITEFAIL"

  # Source raster on local disk so the FETCH + materialize step
  # succeeds; the failure is injected at writeRaster time only.
  src <- file.path(withr::local_tempdir(), "src.tif")
  r_src <- terra::rast(nrows = 50, ncols = 50,
                       xmin = 0, xmax = 500, ymin = 0, ymax = 500,
                       crs = "EPSG:2154", vals = seq_len(2500))
  terra::writeRaster(r_src, src, overwrite = TRUE)

  buf <- sf::st_sf(
    radius_m = 10,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(250, 250)), 10),
                          crs = 2154))
  scene <- data.frame(scene_id = scene_id, href_B04 = src,
                      stringsAsFactors = FALSE)

  # Mock writeRaster to throw — simulates disk full / permission /
  # GDAL driver issue AFTER pixel materialization has succeeded.
  testthat::local_mocked_bindings(
    writeRaster = function(...) stop("simulated disk failure"),
    .package = "terra"
  )

  expect_warning(
    nemeton:::.get_s2_band_raster(scene, "B04", buf, cache_dir = cache),
    "S2 band cache write failed"
  )
  # The orphan scene_dir created just before writeRaster must be
  # cleaned up so diagnose_s2_cache() doesn't flag it.
  expect_false(dir.exists(file.path(cache, scene_id)))
})

# ---- v0.21.12: writeRaster must declare GTiff filetype ---------------
# Regression test for the bug surfaced during v0.21.10 in-prod
# validation: terra writes the temp file as `<path>/B04.tif.tmp`, and
# recent terra versions refuse to guess the driver from the `.tmp`
# extension ("cannot guess file type from filename"). Every write
# silently failed and the cache stayed empty since v0.21.4. The fix
# passes `filetype = "GTiff"` explicitly. This test asserts the
# argument is present, independent of which terra version is on the
# test runner (so we'd catch a future regression even on a lax
# terra).
test_that(".get_s2_band_raster: writeRaster is called with filetype = 'GTiff'", {
  skip_if_not_installed("terra")
  cache    <- withr::local_tempdir()
  scene_id <- "S2_FILETYPE_TEST"

  src <- file.path(withr::local_tempdir(), "src.tif")
  r_src <- terra::rast(nrows = 50, ncols = 50,
                       xmin = 0, xmax = 500, ymin = 0, ymax = 500,
                       crs = "EPSG:2154", vals = seq_len(2500))
  terra::writeRaster(r_src, src, overwrite = TRUE)

  buf <- sf::st_sf(
    radius_m = 10,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(250, 250)), 10),
                          crs = 2154))
  scene <- data.frame(scene_id = scene_id, href_B04 = src,
                      stringsAsFactors = FALSE)

  # Capture writeRaster's call so we can inspect the `filetype` arg.
  captured_filetype <- NULL
  captured_filename <- NULL
  real_writeRaster <- terra::writeRaster
  testthat::local_mocked_bindings(
    writeRaster = function(x, filename, filetype = NULL, ...) {
      captured_filetype <<- filetype
      captured_filename <<- filename
      # Delegate to the real implementation so the test still
      # validates the file lands on disk.
      real_writeRaster(x, filename, filetype = filetype, ...)
    },
    .package = "terra"
  )

  out <- nemeton:::.get_s2_band_raster(scene, "B04", buf,
                                       cache_dir = cache)
  expect_s4_class(out, "SpatRaster")
  expect_identical(captured_filetype, "GTiff")
  # Tmp filename ends in .tif.tmp — confirming why filetype is needed.
  expect_match(captured_filename, "\\.tif\\.tmp$")
  # Final cached file exists with the right (.tif) extension.
  expect_true(file.exists(file.path(cache, scene_id, "B04.tif")))
})
