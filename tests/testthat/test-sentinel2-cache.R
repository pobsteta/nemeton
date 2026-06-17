# test-sentinel2-cache.R — ingest_s2_raw_bands_to_cache (spec 008 §10.2bis)
#
# Pure orchestration: STAC search, per-scene band fetch via the
# cache-aware fetcher. Both .fetch_plots_sf / stac_search_s2 /
# .get_s2_band_raster are mocked so the tests run offline.

skip_if_no_sf <- function() {
  testthat::skip_if_not_installed("sf")
}
skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}

make_fake_con <- function() {
  structure(list(), class = c("FakeConnection", "DBIConnection"))
}

make_fake_plots <- function() {
  pt <- sf::st_sfc(sf::st_point(c(7.75, 48.55)), crs = 4326)
  sf::st_sf(id = 1L, plot_id = "P01", plot_type = NA_character_,
            radius_m = 15, geometry = pt)
}

# spec 012 — make_fake_aoi() returns a small sf POLYGON in EPSG:2154
# centered roughly on make_fake_plots() so unit tests can mock
# `.get_zone_aoi()` without touching the DB.
make_fake_aoi <- function() {
  pol <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 1000000, ymin = 6800000,
      xmax = 1001000, ymax = 6801000), crs = 2154))
  sf::st_sf(geometry = pol, crs = 2154)
}

make_fake_scenes <- function(n = 2) {
  data.frame(
    scene_id  = sprintf("S2A_FAKE_%02d", seq_len(n)),
    obs_date  = as.Date("2020-01-01") + seq_len(n),
    cloud_pct = rep(5, n),
    source    = rep("pc", n),
    href_B02  = paste0("https://example/s2/", seq_len(n), "/B02.tif"),
    href_B04  = paste0("https://example/s2/", seq_len(n), "/B04.tif"),
    href_B05  = paste0("https://example/s2/", seq_len(n), "/B05.tif"),
    href_B8A  = paste0("https://example/s2/", seq_len(n), "/B8A.tif"),
    href_B11  = paste0("https://example/s2/", seq_len(n), "/B11.tif"),
    href_B12  = paste0("https://example/s2/", seq_len(n), "/B12.tif"),
    stringsAsFactors = FALSE
  )
}


# ---- input validation ------------------------------------------------

test_that("rejects empty bands", {
  expect_error(
    ingest_s2_raw_bands_to_cache(con = make_fake_con(), zone_id = 1L,
                                 bands = character(0),
                                 start = "2020-01-01", end = "2020-12-31",
                                 cache_dir = tempfile()),
    "bands"
  )
})


test_that("rejects derived-index codes like NDVI / NBR", {
  expect_error(
    ingest_s2_raw_bands_to_cache(con = make_fake_con(), zone_id = 1L,
                                 bands = c("NDVI", "B04"),
                                 start = "2020-01-01", end = "2020-12-31",
                                 cache_dir = tempfile()),
    "raw Sentinel-2 codes"
  )
})


test_that("rejects empty cache_dir", {
  expect_error(
    ingest_s2_raw_bands_to_cache(con = make_fake_con(), zone_id = 1L,
                                 bands = "B04",
                                 start = "2020-01-01", end = "2020-12-31",
                                 cache_dir = ""),
    "cache_dir"
  )
})


test_that("creates cache_dir when absent", {
  skip_if_no_sf(); skip_if_no_terra()
  d <- file.path(tempfile(), "deep", "tree")
  expect_false(dir.exists(d))

  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) make_fake_plots(),
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) data.frame(),
    .get_s2_band_raster = function(...) NULL,
    .package = "nemeton"
  )

  res <- ingest_s2_raw_bands_to_cache(
    con = make_fake_con(), zone_id = 1L,
    bands = "B04",
    start = "2020-01-01", end = "2020-12-31",
    cache_dir = d
  )
  expect_true(dir.exists(d))
  expect_equal(res$n_scenes, 0L)
})


# ---- happy paths -----------------------------------------------------

test_that("emits s2:* events in order and returns scenes_df", {
  skip_if_no_sf(); skip_if_no_terra()

  fetched <- character(0)
  events <- list()
  cb <- function(payload) {
    events[[length(events) + 1L]] <<- payload
    invisible(NULL)
  }

  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) make_fake_plots(),
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) make_fake_scenes(2L),
    .get_s2_band_raster = function(scene, band, buf_plots, cache_dir, emit) {
      fetched <<- c(fetched, paste(scene$scene_id, band, sep = "/"))
      emit(list(current = "s2:band_fetched", scene_id = scene$scene_id,
                band = band))
      NULL
    },
    .package = "nemeton"
  )

  d <- tempfile("raw-bands-")
  dir.create(d, recursive = TRUE)
  res <- ingest_s2_raw_bands_to_cache(
    con               = make_fake_con(), zone_id = 1L,
    bands             = c("B04", "B12"),
    start             = "2020-01-01",
    end               = "2020-12-31",
    cache_dir         = d,
    progress_callback = cb
  )

  expect_equal(res$n_scenes, 2L)
  expect_equal(nrow(res$scenes_df), 2L)
  expect_equal(res$n_bands_fetched, 4L)  # 2 scenes × 2 bands
  expect_equal(length(fetched), 4L)

  current <- vapply(events, function(e) e$current, character(1))
  expect_identical(current[1L], "s2:search")
  expect_identical(current[2L], "s2:search_done")
  expect_identical(current[length(current)], "s2:complete")
})


test_that("placette-less zone ingests without crashing (spec 017 regression)", {
  skip_if_no_sf(); skip_if_no_terra()
  # Regression: a geometry-only monitoring zone (no placettes) makes
  # `.fetch_plots_sf()` return a 0-row sf with NO `radius_m` column. The old
  # dead-code `sf::st_buffer(plots_proj, dist = plots_proj$radius_m)` then got
  # `dist = NULL` and aborted with
  # "Not compatible with requested type: [type=NULL; target=double]".
  empty_plots <- sf::st_sf(data.frame(),
                           geometry = sf::st_sfc(crs = 4326))   # 0 rows, no radius_m
  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) empty_plots,
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) make_fake_scenes(2L),
    .get_s2_band_raster = function(scene, band, buf_plots, cache_dir, emit) NULL,
    .package = "nemeton"
  )

  d <- tempfile("raw-bands-noplot-")
  dir.create(d, recursive = TRUE)
  res <- expect_no_error(
    ingest_s2_raw_bands_to_cache(
      con       = make_fake_con(), zone_id = 5L,
      bands     = c("B04", "B12"),
      start     = "2020-01-01", end = "2020-12-31",
      cache_dir = d))
  expect_equal(res$n_scenes, 2L)
  expect_equal(nrow(res$scenes_df), 2L)
})


test_that("cached bands are counted but not fetched", {
  skip_if_no_sf(); skip_if_no_terra()

  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) make_fake_plots(),
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) make_fake_scenes(1L),
    .get_s2_band_raster = function(scene, band, buf_plots, cache_dir, emit) {
      emit(list(current = "s2:band_cached", scene_id = scene$scene_id,
                band = band))
      NULL
    },
    .package = "nemeton"
  )

  d <- tempfile("raw-bands-"); dir.create(d)
  res <- ingest_s2_raw_bands_to_cache(
    con = make_fake_con(), zone_id = 1L,
    bands = c("B02", "B04", "B12"),
    start = "2020-01-01", end = "2020-12-31",
    cache_dir = d
  )
  expect_equal(res$n_bands_cached,  3L)
  expect_equal(res$n_bands_fetched, 0L)
})


test_that("scene fetch failure is counted as scene_skipped", {
  skip_if_no_sf(); skip_if_no_terra()

  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) make_fake_plots(),
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) make_fake_scenes(2L),
    .get_s2_band_raster = function(scene, band, buf_plots, cache_dir, emit) {
      if (scene$scene_id == "S2A_FAKE_01" && band == "B04") {
        stop("simulated 503 from PC")
      }
      NULL
    },
    .package = "nemeton"
  )

  d <- tempfile("raw-bands-"); dir.create(d)
  suppressWarnings({
    res <- ingest_s2_raw_bands_to_cache(
      con = make_fake_con(), zone_id = 1L,
      bands = c("B04", "B12"),
      start = "2020-01-01", end = "2020-12-31",
      cache_dir = d
    )
  })

  expect_equal(res$n_scenes_skipped, 1L)
})


test_that("fully cached scenes emit s2:scene_cached and skip the band loop", {
  skip_if_no_sf(); skip_if_no_terra()

  events <- list()
  cb <- function(payload) {
    events[[length(events) + 1L]] <<- payload
    invisible(NULL)
  }

  d <- tempfile("raw-bands-"); dir.create(d, recursive = TRUE)
  # Pre-populate the cache for both scenes × both bands.
  for (sid in c("S2A_FAKE_01", "S2A_FAKE_02")) {
    dir.create(file.path(d, sid), recursive = TRUE)
    for (b in c("B04", "B12")) {
      file.create(file.path(d, sid, paste0(b, ".tif")))
    }
  }

  fetched <- character(0)
  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) make_fake_plots(),
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) make_fake_scenes(2L),
    .get_s2_band_raster = function(scene, band, buf_plots, cache_dir, emit) {
      fetched <<- c(fetched, paste(scene$scene_id, band, sep = "/"))
      NULL
    },
    .package = "nemeton"
  )

  res <- ingest_s2_raw_bands_to_cache(
    con               = make_fake_con(), zone_id = 1L,
    bands             = c("B04", "B12"),
    start             = "2020-01-01",
    end               = "2020-12-31",
    cache_dir         = d,
    progress_callback = cb
  )

  # No fetcher was called — both scenes were fully cached on disk.
  expect_length(fetched, 0L)

  # Cache lookup + 2× scene_cached + complete were emitted, but no
  # s2:scene event for a download path.
  current <- vapply(events, function(e) e$current, character(1))
  expect_true("s2:cache_lookup" %in% current)
  expect_equal(sum(current == "s2:scene_cached"), 2L)
  expect_equal(sum(current == "s2:scene"), 0L)

  # cache_lookup payload has n_cached / n_to_process counters.
  cl <- events[[which(current == "s2:cache_lookup")[1L]]]
  expect_equal(cl$n_cached, 2L)
  expect_equal(cl$n_to_process, 0L)
})


test_that("empty STAC search yields zero-row scenes_df with stable shape", {
  skip_if_no_sf(); skip_if_no_terra()

  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) make_fake_plots(),
    .get_zone_aoi   = function(con, zone_id) make_fake_aoi(),
    stac_search_s2  = function(...) data.frame(),
    .package = "nemeton"
  )

  d <- tempfile("raw-bands-"); dir.create(d)
  res <- ingest_s2_raw_bands_to_cache(
    con = make_fake_con(), zone_id = 1L,
    bands = "B04",
    start = "2020-01-01", end = "2020-12-31",
    cache_dir = d
  )
  expect_equal(res$n_scenes, 0L)
  expect_identical(names(res$scenes_df),
                   c("scene_id", "obs_date", "cloud_pct", "source"))
  expect_equal(nrow(res$scenes_df), 0L)
})


test_that("no plots → empty result + warning", {
  skip_if_no_sf(); skip_if_no_terra()

  testthat::local_mocked_bindings(
    .fetch_plots_sf = function(con, zone_id) {
      sf::st_sf(data.frame(), geometry = sf::st_sfc(crs = 4326))
    },
    .package = "nemeton"
  )

  d <- tempfile("raw-bands-"); dir.create(d)
  expect_warning(
    res <- ingest_s2_raw_bands_to_cache(
      con = make_fake_con(), zone_id = 1L,
      bands = "B04",
      start = "2020-01-01", end = "2020-12-31",
      cache_dir = d
    ),
    "neither.*nor any registered plot"   # spec 017 wording (was "No plots")
  )
  expect_equal(res$n_scenes, 0L)
})
