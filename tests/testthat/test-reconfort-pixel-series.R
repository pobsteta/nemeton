# test-reconfort-pixel-series.R — RECONFORT pixel diagnostic (L5, spec 021)
#   * CRswir / CRre formulas
#   * .build_reconfort_feature_stacks + write/read bundle round-trip
#   * read_reconfort_pixel_series (graceful NULL, attributes)
#   * .locate_reconfort_features_bundle (run_id selection)
#   * .enumerate_reconfort_s2_scenes (best-effort MUSCATE layout)

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}

# Constant-valued EPSG:2154 band raster (5x5, 10 m).
band_raster <- function(value, nrow = 5L, ncol = 5L) {
  skip_if_no_terra()
  r <- terra::rast(nrow = nrow, ncol = ncol,
                   xmin = 700000, xmax = 700000 + ncol * 10,
                   ymin = 6800000, ymax = 6800000 + nrow * 10,
                   crs = "EPSG:2154")
  terra::values(r) <- rep(value, nrow * ncol)
  r
}

# Centre coordinate of the test rasters (EPSG:2154).
.center_xy <- c(700000 + 25, 6800000 + 25)


# ---- formulas --------------------------------------------------------

test_that("CRswir / CRre reproduce the production formulas (spec §4.1)", {
  expect_equal(nemeton:::.reconfort_crswir(0.30, 0.20, 0.25),
               0.20 / (0.30 + (1610 - 865) * (0.25 - 0.30) / (2190 - 865)))
  expect_equal(nemeton:::.reconfort_crre(0.10, 0.18, 0.22),
               0.18 / (0.10 + (704 - 665) * (0.22 - 0.10) / (741 - 665)))
})


# ---- build stacks ----------------------------------------------------

make_scene <- function(date, b4, b5, b6, b8a, b11, b12, scl = NULL) {
  list(obs_date = as.Date(date),
       B04 = band_raster(b4), B05 = band_raster(b5), B06 = band_raster(b6),
       B8A = band_raster(b8a), B11 = band_raster(b11), B12 = band_raster(b12),
       scl = scl)
}

test_that(".build_reconfort_feature_stacks builds dated CRswir/CRre", {
  skip_if_no_terra()
  scenes <- list(
    make_scene("2024-07-01", .10, .18, .22, .30, .20, .25),
    make_scene("2024-06-01", .11, .17, .21, .31, .19, .24))  # out of order
  st <- nemeton:::.build_reconfort_feature_stacks(scenes)
  expect_equal(terra::nlyr(st$crswir), 2L)
  expect_equal(terra::nlyr(st$crre), 2L)
  # dates sorted ascending
  expect_equal(st$dates, as.Date(c("2024-06-01", "2024-07-01")))
  # first layer (2024-06-01) CRswir = formula on that scene's bands
  v <- terra::values(st$crswir[[1]])[1]
  expect_equal(v, nemeton:::.reconfort_crswir(.31, .19, .24), tolerance = 1e-6)
})

test_that(".build_reconfort_feature_stacks on empty input returns NULL", {
  expect_null(nemeton:::.build_reconfort_feature_stacks(list()))
})


# ---- bundle round-trip + reader -------------------------------------

write_test_bundle <- function(cache_dir, zone_id, run_id, scenes,
                              meta = list()) {
  st <- nemeton:::.build_reconfort_feature_stacks(scenes)
  bdir <- file.path(cache_dir, sprintf("zone_%d", zone_id),
                    sprintf("run_%s", run_id))
  nemeton:::.write_reconfort_features_bundle(bdir, st, run_meta = meta)
}

test_that("read_reconfort_pixel_series round-trips the persisted series", {
  skip_if_no_terra()
  cache <- withr::local_tempdir()
  scenes <- list(
    make_scene("2024-06-01", .11, .17, .21, .31, .19, .24),
    make_scene("2024-07-01", .10, .18, .22, .30, .20, .25))
  write_test_bundle(cache, 1L, "20240801T120000", scenes,
                    meta = list(species = "CHE", v_model = "v3", n_classes = 3L,
                                date_from = "2023-01-01", date_to = "2024-12-31"))

  out <- read_reconfort_pixel_series(NULL, zone_id = 1L, xy = .center_xy,
                                     crs = 2154, cache_dir = cache)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 2L)
  expect_equal(out$obs_date, as.Date(c("2024-06-01", "2024-07-01")))
  expect_equal(out$crswir_obs[1],
               nemeton:::.reconfort_crswir(.31, .19, .24), tolerance = 1e-6)
  expect_equal(out$crre_obs[2],
               nemeton:::.reconfort_crre(.10, .18, .22), tolerance = 1e-6)
  expect_equal(attr(out, "species"), "CHE")
  expect_equal(attr(out, "v_model"), "v3")
})

test_that("read_reconfort_pixel_series returns NULL when no bundle", {
  skip_if_no_terra()
  cache <- withr::local_tempdir()
  expect_null(read_reconfort_pixel_series(NULL, 1L, .center_xy, crs = 2154,
                                          cache_dir = cache))
})

test_that("read_reconfort_pixel_series returns NULL for an out-of-extent pixel", {
  skip_if_no_terra()
  cache <- withr::local_tempdir()
  scenes <- list(make_scene("2024-06-01", .11, .17, .21, .31, .19, .24))
  write_test_bundle(cache, 1L, "20240801T120000", scenes)
  out <- read_reconfort_pixel_series(NULL, 1L, c(0, 0), crs = 2154,
                                     cache_dir = cache)
  expect_null(out)
})

test_that("read_reconfort_pixel_series validates xy / zone_id", {
  expect_error(read_reconfort_pixel_series(NULL, NA, .center_xy,
                                           cache_dir = "/tmp/x"), "zone_id")
  expect_error(read_reconfort_pixel_series(NULL, 1L, c(1, NA),
                                           cache_dir = "/tmp/x"), "xy")
  expect_null(read_reconfort_pixel_series(NULL, 1L, .center_xy, cache_dir = ""))
})


# ---- bundle location -------------------------------------------------

test_that(".locate_reconfort_features_bundle picks the latest / explicit run", {
  cache <- withr::local_tempdir()
  z <- file.path(cache, "zone_1")
  dir.create(file.path(z, "run_20240101T000000"), recursive = TRUE)
  dir.create(file.path(z, "run_20240801T000000"), recursive = TRUE)
  expect_match(nemeton:::.locate_reconfort_features_bundle(cache, 1L),
               "run_20240801T000000$")
  expect_match(nemeton:::.locate_reconfort_features_bundle(cache, 1L,
                 run_id = "20240101T000000"), "run_20240101T000000$")
  expect_null(nemeton:::.locate_reconfort_features_bundle(cache, 1L,
                run_id = "nope"))
  expect_null(nemeton:::.locate_reconfort_features_bundle(cache, 99L))
})


# ---- scene enumeration (best-effort MUSCATE layout) ------------------

test_that(".enumerate_reconfort_s2_scenes groups FRE bands by date", {
  root <- withr::local_tempdir()
  tile <- file.path(root, "2024", "T31UDP")
  dir.create(tile, recursive = TRUE)
  # THEIA/MUSCATE FRE naming: single-digit B4/B5/B6, plus B8A/B11/B12.
  for (b in c("B4", "B5", "B6", "B8A", "B11", "B12")) {
    file.create(file.path(tile,
      sprintf("SENTINEL2A_20240615-103000-456_L2A_T31UDP_C_V1-0_FRE_%s.tif", b)))
  }
  # incomplete date (missing B12) -> dropped
  for (b in c("B4", "B5")) {
    file.create(file.path(tile,
      sprintf("SENTINEL2A_20240701-103000-456_L2A_T31UDP_C_V1-0_FRE_%s.tif", b)))
  }
  scenes <- nemeton:::.enumerate_reconfort_s2_scenes(root)
  expect_equal(length(scenes), 1L)
  expect_equal(scenes[[1]]$obs_date, as.Date("2024-06-15"))
  expect_true(all(c("B04", "B11", "B12") %in% names(scenes[[1]])))
})

test_that(".enumerate_reconfort_s2_scenes on a missing root returns empty", {
  expect_equal(length(nemeton:::.enumerate_reconfort_s2_scenes("/no/such/dir")),
               0L)
})


# ---- read_reconfort_alert_mask (Option A, validation sampling) --------

write_class_mask <- function(cache_dir, zone_id, run_id, values) {
  zdir <- file.path(cache_dir, sprintf("zone_%d", zone_id))
  dir.create(zdir, recursive = TRUE, showWarnings = FALSE)
  r <- band_raster(0L)              # 5x5 EPSG:2154
  terra::values(r) <- values
  terra::writeRaster(r, file.path(zdir, sprintf("reconfort_mask_%s.tif", run_id)),
                     overwrite = TRUE)
}

test_that("read_reconfort_alert_mask reads the latest categorical mask", {
  skip_if_no_terra()
  cache <- withr::local_tempdir()
  write_class_mask(cache, 1L, "20240601T000000", rep(1L, 25L))
  write_class_mask(cache, 1L, "20240801T000000",
                   c(rep(1L, 20L), 2L, 2L, 3L, 3L, 3L))   # latest
  r <- read_reconfort_alert_mask(NULL, 1L, cache_dir = cache,
                                 apply_zone_mask = FALSE)
  expect_s4_class(r, "SpatRaster")
  expect_setequal(unique(terra::values(r)[, 1]), c(1L, 2L, 3L))
})

test_that("read_reconfort_alert_mask honours an explicit run_id", {
  skip_if_no_terra()
  cache <- withr::local_tempdir()
  write_class_mask(cache, 1L, "20240601T000000", rep(2L, 25L))
  write_class_mask(cache, 1L, "20240801T000000", rep(3L, 25L))
  r <- read_reconfort_alert_mask(NULL, 1L, run_id = "20240601T000000",
                                 cache_dir = cache, apply_zone_mask = FALSE)
  expect_equal(unique(terra::values(r)[, 1]), 2L)
})

test_that("read_reconfort_alert_mask returns NULL gracefully", {
  skip_if_no_terra()
  cache <- withr::local_tempdir()
  expect_null(read_reconfort_alert_mask(NULL, 1L, cache_dir = cache,
                                        apply_zone_mask = FALSE))   # no zone dir
  expect_null(read_reconfort_alert_mask(NULL, 1L, cache_dir = "",
                                        apply_zone_mask = FALSE))
  write_class_mask(cache, 1L, "20240601T000000", rep(1L, 25L))
  expect_null(read_reconfort_alert_mask(NULL, 1L, run_id = "nope",
                                        cache_dir = cache, apply_zone_mask = FALSE))
  expect_error(read_reconfort_alert_mask(NULL, NA, cache_dir = cache), "zone_id")
})
