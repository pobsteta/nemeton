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

test_that("build_index_stack(NBR): incomplete scene (no B12) is skipped silently with warning", {
  skip_if_not_installed("terra")
  cache <- withr::local_tempdir()
  scenes <- make_fixture_s2_cache(cache, scenes = 3L, with_b12 = TRUE)
  # Remove B12 from one scene
  unlink(file.path(cache, scenes$scene_id[2], "B12.tif"))

  expect_warning(
    stack <- build_index_stack(cache, scenes, "NBR"),
    "Skipped 1/3 scene"
  )
  expect_equal(terra::nlyr(stack), 2L)
  # And NDVI on the same fixture sees 3 (because B04 + B08 are intact)
  expect_silent(stack_ndvi <- build_index_stack(cache, scenes, "NDVI"))
  expect_equal(terra::nlyr(stack_ndvi), 3L)
})
