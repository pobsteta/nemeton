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
