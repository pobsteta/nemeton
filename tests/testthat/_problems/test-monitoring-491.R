# Extracted from test-monitoring.R:491

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
