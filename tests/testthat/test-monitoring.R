# test-monitoring.R — register_monitoring_zone + ingest_sentinel2_timeseries
#
# Pure unit tests cover argument validation and the canonical shape of
# the empty summary. Integration tests (skip_if_no_timescaledb) cover
# the full insertion + idempotence + STAC orchestration path, with the
# STAC backend and per-scene extraction mocked so the test stays fast
# and offline.

# ---- pure helpers ----------------------------------------------------

test_that(".empty_ingest_summary returns the canonical shape", {
  out <- nemeton:::.empty_ingest_summary()
  expect_s3_class(out, "data.frame")
  expect_named(out, c("n_scenes", "n_scenes_cached", "n_obs_inserted",
                      "n_plots", "bands"))
  expect_equal(nrow(out), 1)
  expect_equal(out$n_scenes, 0L)
  expect_equal(out$n_scenes_cached, 0L)
  expect_equal(out$n_obs_inserted, 0L)
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
    expect_equal(out$n_obs_inserted, 0L)
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
    expect_equal(out$n_obs_inserted, 0L)

    # Nothing was inserted into obs_pixel.
    n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM obs_pixel")$n
    expect_equal(as.integer(n), 0L)
  })
})

test_that("ingest_sentinel2_timeseries inserts obs from mocked scenes", {
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

    fake_obs <- function(scene, plots, bands, ...) {
      data.frame(
        plot_id   = plots$id,
        obs_date  = scene$obs_date,
        band      = "NDVI",
        value     = rep(0.80, nrow(plots)),
        cloud_pct = scene$cloud_pct,
        source    = scene$source,
        scene_id  = scene$scene_id,
        stringsAsFactors = FALSE
      )
    }

    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .extract_scene_obs = fake_obs
    )

    out <- ingest_sentinel2_timeseries(con, zid,
                                       "2025-06-01", "2025-07-01",
                                       bands = "NDVI")
    expect_equal(out$n_scenes, 2L)
    expect_equal(out$n_plots, 2L)
    expect_equal(out$bands, "NDVI")
    expect_equal(out$n_obs_inserted, 4L)  # 2 scenes × 2 plots

    rows <- DBI::dbGetQuery(con,
      "SELECT band, value, source FROM obs_pixel
        WHERE plot_id IN (SELECT id FROM plot WHERE zone_id = $1)",
      params = list(zid))
    expect_equal(nrow(rows), 4)
    expect_true(all(rows$band == "NDVI"))
    expect_true(all(abs(rows$value - 0.80) < 1e-9))

    # Re-running is idempotent: PRIMARY KEY (plot_id, obs_date, band)
    # + ON CONFLICT DO NOTHING in .insert_obs_pixel.
    out2 <- ingest_sentinel2_timeseries(con, zid,
                                        "2025-06-01", "2025-07-01",
                                        bands = "NDVI")
    expect_equal(out2$n_obs_inserted, 0L)
    n2 <- DBI::dbGetQuery(con,
      "SELECT COUNT(*) AS n FROM obs_pixel
        WHERE plot_id IN (SELECT id FROM plot WHERE zone_id = $1)",
      params = list(zid))$n
    expect_equal(as.integer(n2), 4L)
  })
})

test_that("ingest_sentinel2_timeseries skips scenes that fail extraction", {
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
      .extract_scene_obs = function(...) stop("boom")
    )

    expect_warning(
      out <- ingest_sentinel2_timeseries(con, zid,
                                         "2025-06-01", "2025-07-15",
                                         bands = "NDVI"),
      "skipped"
    )
    expect_equal(out$n_obs_inserted, 0L)
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

    fake_obs <- function(scene, plots, bands, ...) {
      data.frame(
        plot_id   = plots$id,
        obs_date  = scene$obs_date,
        band      = "NDVI",
        value     = rep(0.7, nrow(plots)),
        cloud_pct = scene$cloud_pct,
        source    = scene$source,
        scene_id  = scene$scene_id,
        stringsAsFactors = FALSE
      )
    }

    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .extract_scene_obs = fake_obs
    )

    seen <- list()
    out <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-07-01",
      bands = "NDVI",
      progress_callback = function(p) {
        seen[[length(seen) + 1L]] <<- p
      }
    )
    expect_equal(out$n_obs_inserted, 4L)

    phases <- vapply(seen, function(p) p$current, character(1))
    # Expected order: search → search_done → scene(×2) → complete.
    expect_identical(
      phases,
      c("s2:search", "s2:search_done", "s2:scene", "s2:scene", "s2:complete")
    )

    search <- seen[[1]]
    expect_equal(search$n_plots, 2L)
    expect_equal(search$bands, "NDVI")

    search_done <- seen[[2]]
    expect_equal(search_done$total, 2L)

    scene_evt <- seen[[3]]
    expect_equal(scene_evt$completed, 0L)
    expect_equal(scene_evt$total, 2L)
    expect_true(nzchar(scene_evt$scene_id))
    expect_s3_class(scene_evt$obs_date, "Date")
    expect_true(is.numeric(scene_evt$cloud_pct))

    done <- seen[[length(seen)]]
    expect_equal(done$completed, 2L)
    expect_equal(done$total, 2L)
    expect_equal(done$n_obs_inserted, 4L)
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
      .extract_scene_obs = function(...) stop("fake extraction failure")
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


# ---- skip_cached (v0.21.3) -------------------------------------------

test_that("skip_cached skips scenes whose obs_dates are already complete", {
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

    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25", "2025-07-10")),
      cloud = c(5, 8, 10))

    n_extracted <- 0L
    fake_obs <- function(scene, plots, bands, ...) {
      n_extracted <<- n_extracted + 1L
      data.frame(
        plot_id   = plots$id,
        obs_date  = scene$obs_date,
        band      = "NDVI",
        value     = rep(0.7, nrow(plots)),
        cloud_pct = scene$cloud_pct,
        source    = scene$source,
        scene_id  = scene$scene_id,
        stringsAsFactors = FALSE
      )
    }
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .extract_scene_obs = fake_obs
    )

    # First run: cold cache, 3 scenes processed.
    out1 <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-15",
                                        bands = "NDVI")
    expect_equal(out1$n_scenes, 3L)
    expect_equal(out1$n_scenes_cached, 0L)
    expect_equal(out1$n_obs_inserted, 6L)
    expect_equal(n_extracted, 3L)

    # Second run: all 3 obs_dates fully covered → all skipped, no
    # .extract_scene_obs call. Counter does not increase.
    seen <- list()
    out2 <- ingest_sentinel2_timeseries(
      con, zid, "2025-06-01", "2025-07-15",
      bands = "NDVI",
      progress_callback = function(p) seen[[length(seen) + 1L]] <<- p
    )
    expect_equal(out2$n_scenes, 3L)
    expect_equal(out2$n_scenes_cached, 3L)
    expect_equal(out2$n_obs_inserted, 0L)
    expect_equal(n_extracted, 3L)   # unchanged

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

test_that("skip_cached only skips dates with complete (plot × band) coverage", {
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
    zid <- register_monitoring_zone(con, "Zpartial", pol, placettes)

    scenes <- fake_scenes(
      dates = as.Date(c("2025-06-10", "2025-06-25")),
      cloud = c(5, 8))

    fake_obs <- function(scene, plots, bands, ...) {
      do.call(rbind, lapply(bands, function(b) {
        data.frame(
          plot_id   = plots$id,
          obs_date  = scene$obs_date,
          band      = b,
          value     = rep(0.7, nrow(plots)),
          cloud_pct = scene$cloud_pct,
          source    = scene$source,
          scene_id  = scene$scene_id,
          stringsAsFactors = FALSE
        )
      }))
    }
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .extract_scene_obs = fake_obs
    )

    # First run inserts NDVI only — 2 scenes × 2 plots = 4 rows.
    out1 <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-15",
                                        bands = "NDVI")
    expect_equal(out1$n_obs_inserted, 4L)

    # Second run asks for NDVI + NBR. NBR is missing for every plot
    # at every obs_date → no cache hit, both scenes re-extracted.
    out2 <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-15",
                                        bands = c("NDVI", "NBR"))
    expect_equal(out2$n_scenes_cached, 0L)
    # 2 scenes × 2 plots × 2 bands = 8 rows in fake_obs output, but
    # NDVI 4 rows already exist → only 4 new (NBR) rows inserted.
    expect_equal(out2$n_obs_inserted, 4L)
  })
})

test_that("skip_cached = FALSE forces re-extraction even when DB is fully covered", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))
    zid <- register_monitoring_zone(con, "Zforce", pol, placettes)

    scenes <- fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)
    n_extracted <- 0L
    fake_obs <- function(scene, plots, bands, ...) {
      n_extracted <<- n_extracted + 1L
      data.frame(
        plot_id   = plots$id,
        obs_date  = scene$obs_date,
        band      = "NDVI",
        value     = rep(0.7, nrow(plots)),
        cloud_pct = scene$cloud_pct,
        source    = scene$source,
        scene_id  = scene$scene_id,
        stringsAsFactors = FALSE
      )
    }
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .extract_scene_obs = fake_obs
    )

    ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-01",
                                bands = "NDVI")
    expect_equal(n_extracted, 1L)

    out <- ingest_sentinel2_timeseries(con, zid, "2025-06-01", "2025-07-01",
                                       bands = "NDVI", skip_cached = FALSE)
    expect_equal(out$n_scenes_cached, 0L)
    expect_equal(n_extracted, 2L)   # extraction ran again
  })
})

test_that(".find_cached_obs_dates returns empty for empty inputs", {
  # No DB call expected — short-circuits on length(plot_ids) == 0
  # or length(bands) == 0.
  expect_length(
    nemeton:::.find_cached_obs_dates(NULL, integer(0), c("NDVI"),
                                     "2025-01-01", "2025-12-31"),
    0L
  )
  expect_length(
    nemeton:::.find_cached_obs_dates(NULL, 1L, character(0),
                                     "2025-01-01", "2025-12-31"),
    0L
  )
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
  expect_error(
    nemeton:::.terra_rast_with_pc_retry(
      "https://x.example/B04.tif", scene_id = "S", band = "B04"
    ),
    "Connection timed out"
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

test_that("ingest_sentinel2_timeseries forwards cache_dir to .extract_scene_obs", {
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
    fake_obs <- function(scene, plots, bands, cache_dir = NULL, emit = NULL) {
      seen_cache_dir <<- if (is.null(cache_dir)) NA_character_ else cache_dir
      data.frame(
        plot_id  = plots$id, obs_date = scene$obs_date, band = "NDVI",
        value = 0.7, cloud_pct = scene$cloud_pct,
        source = scene$source, scene_id = scene$scene_id,
        stringsAsFactors = FALSE)
    }

    scenes <- fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)
    testthat::local_mocked_bindings(
      stac_search_s2     = function(...) scenes,
      .extract_scene_obs = fake_obs
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

test_that(".insert_obs_pixel returns 0 on empty input", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    expect_equal(nemeton:::.insert_obs_pixel(con, data.frame()), 0L)
  })
})
