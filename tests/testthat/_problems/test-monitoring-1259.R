# Extracted from test-monitoring.R:1259

# prequel ----------------------------------------------------------------------
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

# test -------------------------------------------------------------------------
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
