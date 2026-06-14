# Extracted from test-monitoring.R:457

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
