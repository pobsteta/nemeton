# test-aoi-alignment.R — spec 012: FAST and FORDEAD share the same
# AOI (the zone polygon, i.e. UGF envelope), so the on-disk S2 cache
# is reusable across both pipelines.

# ---- unit: .get_zone_aoi() ------------------------------------------

test_that(".get_zone_aoi rejects non-DBIConnection", {
  expect_error(.get_zone_aoi("not-a-con", 1L),
               regexp = "DBIConnection")
})

test_that(".get_zone_aoi rejects bad zone_id when con is OK", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    expect_error(.get_zone_aoi(con, c(1L, 2L)),
                 regexp = "scalar non-NA")
    expect_error(.get_zone_aoi(con, NA_integer_),
                 regexp = "scalar non-NA")
  })
})


# ---- integration: zone AOI round-trips -------------------------------

test_that(".get_zone_aoi returns the registered polygon in EPSG:2154", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)

    # UGF envelope: a ~10 km x 10 km square in Jura (EPSG:2154).
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 900000, ymin = 6600000,
        xmax = 910000, ymax = 6610000),
      crs = 2154))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(901000, 6601000)),  # tight cluster, NW corner
        sf::st_point(c(901500, 6601500)),
        crs = 2154))

    zid <- register_monitoring_zone(con, "ZAoi", pol, placettes,
                                    project_uuid = "spec012-test")

    aoi <- .get_zone_aoi(con, zid)
    expect_s3_class(aoi, "sf")
    expect_equal(sf::st_crs(aoi)$epsg, 2154L)

    # Bbox should be the UGF envelope, not the per-plot cluster.
    bb_aoi   <- sf::st_bbox(aoi)
    bb_plots <- sf::st_bbox(placettes)
    expect_true((bb_aoi["xmax"] - bb_aoi["xmin"]) >
                (bb_plots["xmax"] - bb_plots["xmin"]))
    expect_true((bb_aoi["ymax"] - bb_aoi["ymin"]) >
                (bb_plots["ymax"] - bb_plots["ymin"]))
  })
})


test_that(".get_zone_aoi raises on unknown zone_id", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    expect_error(.get_zone_aoi(con, 999L),
                 regexp = "Unknown monitoring zone")
  })
})


# ---- integration: FAST uses zone AOI for STAC bbox -------------------

test_that("ingest_sentinel2_timeseries uses zone AOI for the STAC bbox", {
  # spec 012 §3.2 acceptance criterion: the bbox passed to
  # stac_search_s2() comes from monitoring_zone.zone_wkt (the UGF
  # envelope), not from the per-plot bbox.
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)

    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 900000, ymin = 6600000,
        xmax = 910000, ymax = 6610000),
      crs = 2154))
    placettes <- sf::st_sf(
      plot_id  = c("P01", "P02"),
      geometry = sf::st_sfc(
        sf::st_point(c(901000, 6601000)),
        sf::st_point(c(901500, 6601500)),
        crs = 2154))
    zid <- register_monitoring_zone(con, "Z", pol, placettes,
                                    project_uuid = "spec012-fast")

    captured_bbox <- NULL
    testthat::local_mocked_bindings(
      stac_search_s2 = function(bbox, start, end, ...) {
        captured_bbox <<- bbox
        fake_scenes(dates = as.Date("2025-06-10"), cloud = 5)
      },
      .extract_scene_obs = function(scene, plots, bands, crop_aoi = NULL,
                                    cache_dir = NULL, emit = NULL) {
        # Empty data.frame (shape `do.call(rbind, list(NDVI))` yields).
        data.frame(
          plot_id   = character(0),
          obs_date  = as.Date(character(0)),
          band      = character(0),
          value     = numeric(0),
          cloud_pct = numeric(0),
          source    = character(0),
          scene_id  = character(0),
          stringsAsFactors = FALSE
        )
      }
    )

    suppressWarnings(
      ingest_sentinel2_timeseries(
        con, zone_id = zid,
        start = "2025-06-01", end = "2025-06-30",
        bands = "NDVI", skip_cached = FALSE)
    )

    expect_false(is.null(captured_bbox))
    bb_used  <- sf::st_bbox(captured_bbox)
    # Reproject the zone polygon to 4326 (STAC convention) and check
    # the bbox passed matches it, not the per-plot cluster.
    bb_zone  <- sf::st_bbox(sf::st_transform(
      sf::st_sf(geometry = pol, crs = 2154), 4326))
    bb_plots <- sf::st_bbox(sf::st_transform(placettes, 4326))
    expect_equal(as.numeric(bb_used), as.numeric(bb_zone),
                 tolerance = 1e-6)
    expect_true(as.numeric(bb_used["xmax"]) - as.numeric(bb_used["xmin"]) >
                as.numeric(bb_plots["xmax"]) - as.numeric(bb_plots["xmin"]))
  })
})


test_that("ingest_s2_raw_bands_to_cache (FORDEAD ingest) uses zone AOI too", {
  # Same assertion as FAST but on the FORDEAD-facing ingest. Both
  # must share the AOI to share the cache.
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)

    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 900000, ymin = 6600000,
        xmax = 910000, ymax = 6610000),
      crs = 2154))
    placettes <- sf::st_sf(
      plot_id  = c("P01"),
      geometry = sf::st_sfc(
        sf::st_point(c(901000, 6601000)),
        crs = 2154))
    zid <- register_monitoring_zone(con, "Z", pol, placettes,
                                    project_uuid = "spec012-fordead")

    captured_bbox <- NULL
    testthat::local_mocked_bindings(
      stac_search_s2 = function(bbox, start, end, ...) {
        captured_bbox <<- bbox
        # Empty scenes so we don't try to fetch anything.
        data.frame(scene_id = character(0), obs_date = as.Date(character(0)),
                   cloud_pct = numeric(0),
                   href_B04 = character(0), href_B08 = character(0),
                   href_B12 = character(0), source = character(0),
                   stringsAsFactors = FALSE)
      }
    )

    suppressWarnings(
      ingest_s2_raw_bands_to_cache(
        con, zone_id = zid,
        bands = c("B04", "B08"),
        start = "2025-06-01", end = "2025-06-30",
        cache_dir = withr::local_tempdir())
    )

    expect_false(is.null(captured_bbox))
    bb_used <- sf::st_bbox(captured_bbox)
    bb_zone <- sf::st_bbox(sf::st_transform(
      sf::st_sf(geometry = pol, crs = 2154), 4326))
    expect_equal(as.numeric(bb_used), as.numeric(bb_zone),
                 tolerance = 1e-6)
  })
})


test_that("FAST falls back to per-plot bbox when zone_wkt is empty", {
  # spec 012 §3.3 — defensive fallback. Reaches via a synthetic zone
  # whose zone_wkt was overwritten to empty; we expect a warn + the
  # legacy bbox.
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 900000, ymin = 6600000,
        xmax = 910000, ymax = 6610000),
      crs = 2154))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(
        sf::st_point(c(901000, 6601000)),
        crs = 2154))
    zid <- register_monitoring_zone(con, "ZBroken", pol, placettes,
                                    project_uuid = "spec012-fallback")
    # Corrupt the row: empty WKT so .get_zone_aoi() fails on parse.
    DBI::dbExecute(con,
      "UPDATE monitoring_zone SET zone_wkt = $1 WHERE id = $2",
      params = list("", zid))

    captured_bbox <- NULL
    testthat::local_mocked_bindings(
      stac_search_s2 = function(bbox, start, end, ...) {
        captured_bbox <<- bbox
        data.frame(scene_id = character(0), obs_date = as.Date(character(0)),
                   cloud_pct = numeric(0),
                   href_B04 = character(0), href_B08 = character(0),
                   href_B12 = character(0), source = character(0),
                   stringsAsFactors = FALSE)
      }
    )

    expect_warning(
      ingest_sentinel2_timeseries(
        con, zone_id = zid,
        start = "2025-06-01", end = "2025-06-30",
        bands = "NDVI", skip_cached = FALSE),
      regexp = "falling back to per-plot bbox"
    )
    expect_false(is.null(captured_bbox))
  })
})
