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
  expect_named(out, c("n_scenes", "n_obs_inserted", "n_plots", "bands"))
  expect_equal(nrow(out), 1)
  expect_equal(out$n_scenes, 0L)
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

    fake_obs <- function(scene, plots, bands) {
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

    fake_obs <- function(scene, plots, bands) {
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
