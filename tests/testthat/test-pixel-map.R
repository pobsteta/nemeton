# Tests for spec 010 — pixel-map helpers (R/pixel-map.R).
#
# Strategy: a small synthetic S2 cache built locally per test.
# `make_fixture_s2_cache()` writes valid GeoTIFFs to a temp dir using
# the same on-disk layout as `.s2_band_cache_path()` so the readers
# can be exercised without network or DB.

# ---- Fixture helper ----------------------------------------------------

# Write a fixture S2 cache to `dir` with `scenes` distinct scene_ids.
# Each scene gets B04 + B08 at 10 m and (optionally) B12 at 20 m,
# all on the same Lambert-93 footprint (EPSG:2154 is the convention for
# the post-crop intermediate, before terra::resample on B12). The CRS
# we actually use in production is UTM (32631), but for fixtures
# Lambert-93 is fine — the readers don't care about the projection,
# only that the file is a valid GeoTIFF terra can open.
#
# Returns the data.frame(scene_id, obs_date) that callers pass to
# read_s2_band_stack() etc.
make_fixture_s2_cache <- function(dir, scenes = 3L,
                                  with_b12 = TRUE,
                                  start_date = as.Date("2026-01-01"),
                                  fill_value = NULL) {
  scene_ids <- sprintf("S2_FIX_%03d", seq_len(scenes))
  obs_dates <- start_date + seq_len(scenes) * 10L
  for (i in seq_len(scenes)) {
    sid       <- scene_ids[i]
    scene_dir <- file.path(dir, sid)
    dir.create(scene_dir, recursive = TRUE, showWarnings = FALSE)
    for (b in c("B04", "B08", if (with_b12) "B12")) {
      res <- if (b == "B12") 20 else 10
      nc  <- if (b == "B12") 15L else 30L
      vals <- if (is.null(fill_value)) {
        runif(nc * nc, min = 0.05, max = 0.5)
      } else {
        rep(fill_value, nc * nc)
      }
      r <- terra::rast(nrows = nc, ncols = nc,
                       xmin = 644000, xmax = 644000 + nc * res,
                       ymin = 5235000, ymax = 5235000 + nc * res,
                       crs = "EPSG:2154", vals = vals)
      terra::writeRaster(
        r,
        file.path(scene_dir, paste0(b, ".tif")),
        filetype = "GTiff",
        overwrite = TRUE
      )
    }
  }
  data.frame(scene_id = scene_ids, obs_date = obs_dates,
             stringsAsFactors = FALSE)
}

# ---- read_s2_band_raster() --------------------------------------------

test_that("read_s2_band_raster: returns SpatRaster on valid cached file", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 1L)

  r <- read_s2_band_raster(cache, scenes$scene_id[1], "B04")
  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::nlyr(r), 1L)
  expect_equal(dim(r)[1:2], c(30L, 30L))
  expect_equal(terra::res(r), c(10, 10))
})

test_that("read_s2_band_raster: returns NULL when file is absent", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  make_fixture_s2_cache(cache, scenes = 1L)

  # Scene that was never written
  out <- read_s2_band_raster(cache, "S2_NEVER_EXISTED", "B08")
  expect_null(out)

  # Scene exists but B12 wasn't created
  cache2 <- withr::local_tempdir()
  scenes2 <- make_fixture_s2_cache(cache2, scenes = 1L, with_b12 = FALSE)
  expect_null(read_s2_band_raster(cache2, scenes2$scene_id[1], "B12"))
})

test_that("read_s2_band_raster: validates inputs", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()

  # band invalide
  expect_error(read_s2_band_raster(cache, "X", "B99"),
               "should be one of")
  # cache_dir vide
  expect_error(read_s2_band_raster("", "X", "B04"),
               "non-empty character")
  # scene_id vide
  expect_error(read_s2_band_raster(cache, "", "B04"),
               "non-empty character")
  # cache_dir vecteur
  expect_error(read_s2_band_raster(c("a", "b"), "X", "B04"),
               "single non-empty character")
  # scene_id NA
  expect_error(read_s2_band_raster(cache, NA_character_, "B04"),
               "non-empty character")
})

# ---- read_s2_band_stack() ---------------------------------------------

test_that("read_s2_band_stack: stack is ordered by obs_date", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  # Fixture gives us scenes in order; shuffle the input to confirm
  # the function sorts internally.
  scenes <- make_fixture_s2_cache(cache, scenes = 3L)
  shuffled <- scenes[c(3L, 1L, 2L), , drop = FALSE]

  stack <- read_s2_band_stack(cache, shuffled, "B08")
  expect_s4_class(stack, "SpatRaster")
  expect_equal(terra::nlyr(stack), 3L)
  expect_equal(as.Date(terra::time(stack)),
               as.Date(sort(scenes$obs_date)))
  expect_equal(names(stack),
               as.character(sort(scenes$obs_date)))
})

test_that("read_s2_band_stack: missing scenes are skipped with one aggregated warning", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 3L)
  # Remove one scene's B04 file on disk.
  unlink(file.path(cache, scenes$scene_id[2], "B04.tif"))

  expect_warning(
    stack <- read_s2_band_stack(cache, scenes, "B04"),
    "Skipped 1/3 scene"
  )
  expect_s4_class(stack, "SpatRaster")
  expect_equal(terra::nlyr(stack), 2L)
})

test_that("read_s2_band_stack: NULL when every scene is missing", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  # scenes_df pointing at scenes that don't exist on disk
  fake_df <- data.frame(
    scene_id = c("S2_NOPE_1", "S2_NOPE_2"),
    obs_date = as.Date(c("2026-01-10", "2026-01-20")),
    stringsAsFactors = FALSE
  )
  expect_warning(out <- read_s2_band_stack(cache, fake_df, "B04"),
                 "Skipped 2/2")
  expect_null(out)
})

test_that("read_s2_band_stack: terra::time() is correctly set", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 2L)

  stack <- read_s2_band_stack(cache, scenes, "B08")
  # `terra::time()` returns POSIXct or Date depending on terra version.
  # Coerce to Date for the comparison.
  expect_equal(as.Date(terra::time(stack)),
               as.Date(scenes$obs_date))
})

test_that("read_s2_band_stack: validates scenes_df shape", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()

  expect_error(read_s2_band_stack(cache, list(), "B04"),
               "must be a data.frame")
  expect_error(read_s2_band_stack(cache, data.frame(scene_id = "X"), "B04"),
               "missing column")
  expect_error(read_s2_band_stack(cache,
                                  data.frame(scene_id = character(0),
                                             obs_date = as.Date(character(0))),
                                  "B04"),
               "empty")
  expect_error(read_s2_band_stack(cache,
                                  data.frame(scene_id = NA_character_,
                                             obs_date = as.Date("2026-01-01")),
                                  "B04"),
               "NA in")
})

# ---- build_index_stack() ----------------------------------------------

test_that("build_index_stack(NDVI): formula is correct pixel-wise", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  # Fixed values so we can predict the NDVI exactly.
  scene_ids <- c("S2_FIX_NDVI_01")
  sid       <- scene_ids[1]
  scene_dir <- file.path(cache, sid)
  dir.create(scene_dir, recursive = TRUE)
  for (b in c("B04", "B08")) {
    val <- if (b == "B04") 0.10 else 0.40
    r <- terra::rast(nrows = 10, ncols = 10,
                     xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     crs = "EPSG:2154", vals = rep(val, 100))
    terra::writeRaster(r, file.path(scene_dir, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  scenes <- data.frame(scene_id = scene_ids,
                       obs_date = as.Date("2026-03-01"),
                       stringsAsFactors = FALSE)

  stack <- build_index_stack(cache, scenes, "NDVI")
  expect_s4_class(stack, "SpatRaster")
  expect_equal(terra::nlyr(stack), 1L)
  expect_identical(attr(stack, "index"), "NDVI")
  # Expected = (0.4 - 0.1) / (0.4 + 0.1) = 0.6
  vals <- as.numeric(terra::values(stack))
  expect_true(all(abs(vals - 0.6) < 1e-9))
})

test_that("build_index_stack(NBR): result is on 10 m grid (B12 resampled)", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 1L, with_b12 = TRUE)

  stack <- build_index_stack(cache, scenes, "NBR")
  expect_s4_class(stack, "SpatRaster")
  expect_equal(terra::res(stack), c(10, 10))   # 10 m grid (B08), not 20 m
  # Values bounded in [-1, 1] (reflectances are positive, math holds)
  vals <- as.numeric(terra::values(stack))
  expect_true(all(is.na(vals) | (vals >= -1 & vals <= 1)))
})

test_that("build_index_stack: NA in a source band propagates to the index", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  sid <- "S2_FIX_NA"
  scene_dir <- file.path(cache, sid)
  dir.create(scene_dir, recursive = TRUE)
  # B04 has NA at one pixel, B08 is full.
  vals_b04 <- rep(0.10, 100); vals_b04[55] <- NA_real_
  for (b in c("B04", "B08")) {
    v <- if (b == "B04") vals_b04 else rep(0.40, 100)
    r <- terra::rast(nrows = 10, ncols = 10,
                     xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     crs = "EPSG:2154", vals = v)
    terra::writeRaster(r, file.path(scene_dir, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  scenes <- data.frame(scene_id = sid,
                       obs_date = as.Date("2026-03-01"),
                       stringsAsFactors = FALSE)

  stack <- build_index_stack(cache, scenes, "NDVI")
  vals <- as.numeric(terra::values(stack))
  expect_true(is.na(vals[55]))
  expect_equal(sum(is.na(vals)), 1L)
})

test_that("build_index_stack(NBR): incomplete scene (no B12) is skipped, never warns", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 3L, with_b12 = TRUE)
  # Remove B12 from one scene
  unlink(file.path(cache, scenes$scene_id[2], "B12.tif"))

  # v0.52.x — the skip is reported via `rlang::inform` (a message), not
  # a warning, so the Shiny reactive no longer spams the console.
  expect_no_warning(
    stack <- suppressMessages(build_index_stack(cache, scenes, "NBR")))
  expect_equal(terra::nlyr(stack), 2L)
  # And NDVI on the same fixture sees 3 (because B04 + B08 are intact)
  # and emits nothing (no missing scene).
  expect_silent(stack_ndvi <- build_index_stack(cache, scenes, "NDVI"))
  expect_equal(terra::nlyr(stack_ndvi), 3L)
})

test_that("build_index_stack: repeated call with incomplete cache emits no warning (dedupe)", {
  skip_if_not_installed("terra")
  # Regression: the old `cli_warn` fired on every reactive evaluation
  # (~12x per app load → 12 identical console lines for villards).
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 3L, with_b12 = TRUE)
  unlink(file.path(cache, scenes$scene_id[2], "B12.tif"))

  # First call may inform once; it must never warn.
  suppressMessages(build_index_stack(cache, scenes, "NBR"))
  # A repeated call must not raise a warning.
  expect_no_warning(
    suppressMessages(build_index_stack(cache, scenes, "NBR")))
})

# Helper: write a single scene (B04 + B08 only) with an explicit
# extent and constant band values, on the EPSG:2154 10 m grid. Used by
# the v0.52.x union tests below. `crs` lets the multi-CRS test place a
# scene in a different UTM zone.
write_scene_ext <- function(cache, sid, xmin, xmax, ymin, ymax,
                            b04, b08, crs = "EPSG:2154") {
  d <- file.path(cache, sid)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  ncx <- round((xmax - xmin) / 10)
  ncy <- round((ymax - ymin) / 10)
  for (b in c("B04", "B08")) {
    v <- if (b == "B04") b04 else b08
    r <- terra::rast(nrows = ncy, ncols = ncx,
                     xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                     crs = crs, vals = rep(v, ncx * ncy))
    terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
}

test_that("build_index_stack: stacks to the UNION of extents, padding NA (v0.52.x)", {
  skip_if_not_installed("terra")
  # spec 010 / v0.52.x — an AOI straddling two overlapping MGRS tiles
  # yields a WIDE scene (covers the whole AOI) and a NARROW scene
  # (covers only the overlap strip ⊂ WIDE). The old behaviour cropped
  # to the intersection (= the narrow strip), silently dropping half
  # the AOI. We now pad to the union with NA.
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()

  # WIDE: x in [0, 100], NDVI = (0.4-0.1)/(0.4+0.1) = 0.6.
  write_scene_ext(cache, "S2_WIDE",   0, 100, 0, 100, b04 = 0.1, b08 = 0.4)
  # NARROW ⊂ WIDE: x in [0, 50], NDVI = 0 (distinct so we can tell apart).
  write_scene_ext(cache, "S2_NARROW", 0,  50, 0, 100, b04 = 0.2, b08 = 0.2)

  scenes <- data.frame(
    scene_id = c("S2_WIDE", "S2_NARROW"),
    obs_date = as.Date(c("2026-03-01", "2026-03-01")),  # same acquisition
    stringsAsFactors = FALSE)

  stack <- build_index_stack(cache, scenes, "NDVI")
  expect_s4_class(stack, "SpatRaster")
  # Union extent = the WIDE footprint, NOT the narrow intersection.
  e <- terra::ext(stack)
  expect_equal(c(terra::xmin(e), terra::xmax(e),
                 terra::ymin(e), terra::ymax(e)),
               c(0, 100, 0, 100))
  # Both dates/layers are kept.
  expect_equal(terra::nlyr(stack), 2L)
  # The narrow layer is NA-padded over x in [50, 100]: 5 cols x 10 rows
  # = 50 NA cells. The wide layer is fully covered (0 NA).
  nas <- terra::global(stack, fun = "isNA")$isNA
  expect_setequal(nas, c(0, 50))
})

test_that("build_index_stack: independent dates each keep their own layer over the union", {
  skip_if_not_installed("terra")
  # 4 scenes = 2 dates x 2 tiles (each date has a narrow + a wide
  # scene). The per-date mosaic is the app consumer's job; the core
  # builder must return all 4 layers over the union extent with the
  # right dates.
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()

  write_scene_ext(cache, "S2_D1_WIDE",   0, 100, 0, 100, 0.1, 0.4)
  write_scene_ext(cache, "S2_D1_NARROW", 0,  50, 0, 100, 0.2, 0.2)
  write_scene_ext(cache, "S2_D2_WIDE",   0, 100, 0, 100, 0.1, 0.4)
  write_scene_ext(cache, "S2_D2_NARROW", 0,  50, 0, 100, 0.2, 0.2)

  scenes <- data.frame(
    scene_id = c("S2_D1_WIDE", "S2_D1_NARROW", "S2_D2_WIDE", "S2_D2_NARROW"),
    obs_date = as.Date(c("2026-03-01", "2026-03-01",
                         "2026-03-11", "2026-03-11")),
    stringsAsFactors = FALSE)

  stack <- build_index_stack(cache, scenes, "NDVI")
  expect_equal(terra::nlyr(stack), 4L)
  e <- terra::ext(stack)
  expect_equal(c(terra::xmin(e), terra::xmax(e)), c(0, 100))
  expect_equal(sort(unique(as.Date(terra::time(stack)))),
               as.Date(c("2026-03-01", "2026-03-11")))
  # Two narrow layers padded (50 NA each), two wide layers full (0 NA).
  nas <- terra::global(stack, fun = "isNA")$isNA
  expect_equal(sort(nas), c(0, 0, 50, 50))
})

test_that("build_index_stack: layers in different CRS are reprojected then unioned", {
  skip_if_not_installed("terra")
  # Rare multi-zone AOI (two UTM zones at a zone border). The reference
  # layer (first by date) fixes the output CRS; the other is
  # reprojected onto it before the union, so the stack still covers
  # both footprints.
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()

  # Scene 1 in UTM 31N on a realistic France footprint.
  write_scene_ext(cache, "S2_UTM31",
                  700000, 700100, 5200000, 5200100,
                  b04 = 0.1, b08 = 0.4, crs = "EPSG:32631")
  # Scene 2 in UTM 32N — derive a geographically-overlapping extent by
  # projecting scene 1's grid into 32632 (keeps the union small).
  r1 <- terra::rast(nrows = 10, ncols = 10,
                    xmin = 700000, xmax = 700100,
                    ymin = 5200000, ymax = 5200100,
                    crs = "EPSG:32631", vals = rep(0, 100))
  r2 <- terra::project(r1, "EPSG:32632")
  e2 <- terra::ext(r2)
  write_scene_ext(cache, "S2_UTM32",
                  terra::xmin(e2), terra::xmax(e2),
                  terra::ymin(e2), terra::ymax(e2),
                  b04 = 0.2, b08 = 0.2, crs = "EPSG:32632")

  scenes <- data.frame(
    scene_id = c("S2_UTM31", "S2_UTM32"),
    obs_date = as.Date(c("2026-03-01", "2026-03-02")),
    stringsAsFactors = FALSE)

  stack <- suppressMessages(build_index_stack(cache, scenes, "NDVI"))
  expect_s4_class(stack, "SpatRaster")
  expect_equal(terra::nlyr(stack), 2L)
  # Reference CRS = the first layer's CRS (UTM 31N).
  expect_true(terra::same.crs(stack, "EPSG:32631"))
})


test_that("build_index_stack(parallel = TRUE) matches sequential (spec 017 D4)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("furrr")
  skip_if_not_installed("future")
  cache <- withr::local_tempdir()
  sids <- sprintf("S2A_MSIL2A_2025%02d15T103041_R108_T31TFM_x", 1:3)
  for (i in 1:3) {
    d <- file.path(cache, sids[i]); dir.create(d, recursive = TRUE)
    for (b in c("B04", "B08")) {
      val <- if (b == "B04") 0.1 * i else 0.4
      r <- terra::rast(nrows = 8, ncols = 8, xmin = 0, xmax = 80,
                       ymin = 0, ymax = 80, crs = "EPSG:32631", vals = rep(val, 64))
      terra::writeRaster(r, file.path(d, paste0(b, ".tif")),
                         filetype = "GTiff", overwrite = TRUE)
    }
  }
  scenes <- data.frame(scene_id = sids,
                       obs_date = as.Date(sprintf("2025-%02d-15", 1:3)),
                       stringsAsFactors = FALSE)

  seq_stk <- build_index_stack(cache, scenes, "NDVI", parallel = FALSE)
  # A sequential future plan runs furrr in-process, exercising the
  # future_map + terra::wrap()/unwrap() path without a fork dependency.
  withr::defer(future::plan(future::sequential))
  future::plan(future::sequential)
  par_stk <- build_index_stack(cache, scenes, "NDVI", parallel = TRUE)

  expect_equal(terra::nlyr(par_stk), terra::nlyr(seq_stk))
  expect_equal(terra::values(par_stk), terra::values(seq_stk))
  expect_equal(as.Date(terra::time(par_stk)), as.Date(terra::time(seq_stk)))
})


# ---- extract_pixel_timeseries() ---------------------------------------

# Build a single-scene fixture with all bands holding fixed values so
# we can predict NDVI / NBR analytically and verify the CRS transform
# from 4326 → 2154 picks the right pixel.
make_fixture_known_values <- function(dir, scene_id = "S2_FIX_KNOWN",
                                      b04 = 0.10, b08 = 0.40, b12 = 0.20) {
  scene_dir <- file.path(dir, scene_id)
  dir.create(scene_dir, recursive = TRUE)
  for (b in c("B04", "B08", "B12")) {
    v   <- switch(b, B04 = b04, B08 = b08, B12 = b12)
    res <- if (b == "B12") 20 else 10
    nc  <- if (b == "B12") 15L else 30L
    r <- terra::rast(nrows = nc, ncols = nc,
                     xmin = 644000, xmax = 644000 + nc * res,
                     ymin = 5235000, ymax = 5235000 + nc * res,
                     crs = "EPSG:2154", vals = rep(v, nc * nc))
    terra::writeRaster(r, file.path(scene_dir, paste0(b, ".tif")),
                       filetype = "GTiff", overwrite = TRUE)
  }
  invisible(scene_id)
}

test_that("extract_pixel_timeseries: CRS transform 4326 → L93 works on known pixel", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  sid <- make_fixture_known_values(cache, b04 = 0.10, b08 = 0.40, b12 = 0.20)
  scenes <- data.frame(scene_id = sid,
                       obs_date = as.Date("2026-03-01"),
                       stringsAsFactors = FALSE)

  # A point inside the fixture footprint, expressed in 4326. The
  # fixture covers L93 [644000-644300, 5235000-5235300] — a tiny
  # patch in eastern France. Use a point in L93 then transform back
  # to 4326 so we don't hard-code lat/lng that might shift with
  # GDAL/proj updates.
  pt_l93 <- sf::st_sfc(sf::st_point(c(644150, 5235150)), crs = 2154)
  pt_wgs <- sf::st_transform(pt_l93, 4326)
  xy_wgs <- as.numeric(sf::st_coordinates(pt_wgs))

  out <- extract_pixel_timeseries(cache, scenes, xy_wgs,
                                  crs = 4326,
                                  indices = c("NDVI", "NBR"))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 2L)
  expect_setequal(names(out), c("obs_date", "index", "value"))
  ndvi <- out$value[out$index == "NDVI"]
  nbr  <- out$value[out$index == "NBR"]
  # NDVI = (0.40 - 0.10) / (0.40 + 0.10) = 0.6
  # NBR  = (0.40 - 0.20) / (0.40 + 0.20) = 1/3
  expect_equal(ndvi, 0.6, tolerance = 1e-9)
  expect_equal(nbr,  1/3, tolerance = 1e-9)
})

test_that("extract_pixel_timeseries: multi-index output is sorted (obs_date, index)", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 3L, with_b12 = TRUE)
  # Shuffle to ensure the function sorts internally.
  scenes_shuffled <- scenes[c(3L, 1L, 2L), , drop = FALSE]

  # Point in the L93 footprint
  xy <- as.numeric(sf::st_coordinates(
    sf::st_transform(sf::st_sfc(sf::st_point(c(644150, 5235150)), crs = 2154),
                     4326)))

  out <- extract_pixel_timeseries(cache, scenes_shuffled, xy,
                                  indices = c("NDVI", "NBR"))
  expect_equal(nrow(out), 6L)   # 3 scenes × 2 indices
  # Sorted by date first, then alphabetic index ("NBR" < "NDVI")
  expect_equal(out$obs_date,
               rep(sort(scenes$obs_date), each = 2L))
  expect_equal(out$index,
               rep(c("NBR", "NDVI"), times = 3L))
})

test_that("extract_pixel_timeseries: point outside AOI returns NAs", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 2L)

  # A point clearly outside the fixture footprint (Paris area in 4326)
  out <- extract_pixel_timeseries(cache, scenes, c(2.35, 48.85),
                                  crs = 4326,
                                  indices = c("NDVI", "NBR"))
  expect_equal(nrow(out), 4L)
  expect_true(all(is.na(out$value)))
})

test_that("extract_pixel_timeseries: incomplete scene yields NAs at that date, not skipped", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 3L, with_b12 = TRUE)
  # Remove B08 from scene 2 — both NDVI and NBR need B08 → NAs expected.
  unlink(file.path(cache, scenes$scene_id[2], "B08.tif"))

  xy <- as.numeric(sf::st_coordinates(
    sf::st_transform(sf::st_sfc(sf::st_point(c(644150, 5235150)), crs = 2154),
                     4326)))

  out <- extract_pixel_timeseries(cache, scenes, xy,
                                  indices = c("NDVI", "NBR"))
  expect_equal(nrow(out), 6L)
  # The date of the incomplete scene is still in the output …
  expect_true(scenes$obs_date[2] %in% out$obs_date)
  # … but with NA values for both indices on that date.
  rows_missing <- out[out$obs_date == scenes$obs_date[2], , drop = FALSE]
  expect_true(all(is.na(rows_missing$value)))
  # Surrounding dates remain numeric (the random fixture values may
  # or may not be NaN by chance, but mostly numeric).
})

test_that("extract_pixel_timeseries: validates xy", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  make_fixture_known_values(cache)
  scenes <- data.frame(scene_id = "S2_FIX_KNOWN",
                       obs_date = as.Date("2026-03-01"),
                       stringsAsFactors = FALSE)

  expect_error(extract_pixel_timeseries(cache, scenes, c(1.0)),
               "length-2")
  expect_error(extract_pixel_timeseries(cache, scenes, c(1.0, NA)),
               "no NA")
  expect_error(extract_pixel_timeseries(cache, scenes, "lng,lat"),
               "length-2")
})
