# test-project_layers.R — resolve_project_dem / resolve_project_chm
#
# Filesystem-based unit tests using withr::local_tempdir. No network,
# no real rasters needed — we use 0-byte files when only path-discovery
# matters, and real terra::rast()-able files when `load = TRUE` is
# exercised.

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
}

# Tiny 4x4 valid GeoTIFF for "load = TRUE" tests.
.write_tiny_tif <- function(path) {
  skip_if_no_terra()
  r <- terra::rast(nrows = 4, ncols = 4,
                   xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                   crs = "EPSG:2154", vals = seq_len(16))
  terra::writeRaster(r, path, overwrite = TRUE,
                     gdal = c("TILED=YES", "COMPRESS=DEFLATE"))
  invisible(path)
}


# ---- argument validation ---------------------------------------------

test_that("resolve_project_dem rejects invalid project_path", {
  expect_error(resolve_project_dem(NULL), "must be a single non-empty path")
  expect_error(resolve_project_dem(""), "must be a single non-empty path")
  expect_error(resolve_project_dem(c("a", "b")), "must be a single non-empty path")
  expect_error(resolve_project_dem("/no/such/dir"), "does not exist")
})

test_that("resolve_project_chm rejects invalid project_path", {
  expect_error(resolve_project_chm(NULL), "must be a single non-empty path")
  expect_error(resolve_project_chm("/no/such/dir"), "does not exist")
})


# ---- empty project ---------------------------------------------------

test_that("resolve_project_dem returns NULL when no DEM is present", {
  proj <- withr::local_tempdir()
  expect_null(resolve_project_dem(proj))
  expect_null(resolve_project_dem(proj, load = FALSE))
})

test_that("resolve_project_chm returns NULL when no CHM is present", {
  proj <- withr::local_tempdir()
  expect_null(resolve_project_chm(proj))
})


# ---- single-file conventions -----------------------------------------

test_that("resolve_project_dem finds <project>/dtm.tif (opencanopy)", {
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_length(out, 1L)
  expect_equal(normalizePath(out, mustWork = FALSE),
               normalizePath(file.path(proj, "dtm.tif"), mustWork = FALSE))
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})

test_that("resolve_project_dem finds <project>/mnt.tif (tutorial)", {
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "mnt.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "tutorial MNT")
})

test_that("resolve_project_dem finds <project>/data/dtm.tif", {
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "data"))
  .write_tiny_tif(file.path(proj, "data", "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "data/dtm.tif")
})

test_that("resolve_project_chm finds <project>/chm.tif", {
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "chm.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "single-file CHM")
})


# ---- cache/layers conventions ----------------------------------------

test_that("resolve_project_dem finds cache/layers/lidar_mnt/*.tif", {
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "lidar_mnt"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "lidar_mnt", "tile_001.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "LiDAR HD MNT")
  expect_length(out, 1L)
})

test_that("resolve_project_chm finds cache/layers/chm/*.tif", {
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "chm"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "chm", "T31TFN.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "Open-Canopy CHM")
})


# ---- priority order --------------------------------------------------

test_that("resolve_project_dem prefers LiDAR HD MNT over opencanopy DTM", {
  proj <- withr::local_tempdir()
  # Both present — LiDAR HD wins (it's #1 in the search order).
  dir.create(file.path(proj, "cache", "layers", "lidar_mnt"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "lidar_mnt", "x.tif"))
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "LiDAR HD MNT")
})

test_that("resolve_project_dem falls back from BD ALTI to opencanopy DTM", {
  proj <- withr::local_tempdir()
  # No LiDAR / DEM / BD ALTI / etc. — only opencanopy DTM.
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})


# ---- multi-tile mosaic -----------------------------------------------

test_that("resolve_project_dem returns a VRT when multiple tiles match", {
  skip_if_no_terra()
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "bd_alti"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "bd_alti", "tile_A.tif"))
  .write_tiny_tif(file.path(proj, "cache", "layers", "bd_alti", "tile_B.tif"))

  # load = FALSE returns both paths.
  paths <- resolve_project_dem(proj, load = FALSE)
  expect_length(paths, 2L)

  # load = TRUE returns one SpatRaster (VRT-mosaiced).
  r <- resolve_project_dem(proj)
  expect_s4_class(r, "SpatRaster")
  expect_identical(attr(r, "nemeton_dem_layer"), "IGN BD ALTI")
})


# ---- verbose mode ----------------------------------------------------

test_that("resolve_project_dem logs probed paths when verbose = TRUE", {
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  # Should at minimum emit one "Found … opencanopy DTM" message.
  expect_message(
    resolve_project_dem(proj, load = FALSE, verbose = TRUE),
    "opencanopy DTM"
  )
})

test_that("resolve_project_dem warns when nothing is found and verbose = TRUE", {
  proj <- withr::local_tempdir()
  expect_message(
    resolve_project_dem(proj, verbose = TRUE),
    "No DEM found"
  )
})


# ---- direct files under cache/layers/ (v0.25.5) ----------------------

test_that("resolve_project_dem finds cache/layers/dem.tif (direct file)", {
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "dem.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "cache/layers/dem.tif")
})

test_that("resolve_project_dem finds cache/layers/dtm.tif (direct file)", {
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "cache/layers/dtm.tif")
})

test_that("resolve_project_dem prefers cache/layers/dem.tif over <project>/dtm.tif", {
  # Both present — cache/layers/dem.tif wins (it's higher in the list).
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "dem.tif"))
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "cache/layers/dem.tif")
})

test_that("resolve_project_dem finds <project>/dem.tif at project root", {
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "dem.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "project DEM")
})

test_that("resolve_project_chm finds cache/layers/chm.tif (direct file)", {
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "chm.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "cache/layers/chm.tif")
})


# ---- file matching is case-insensitive (Windows DTM.tif vs dtm.tif) --

test_that("resolve_project_dem matches dtm.tif case-insensitively", {
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "DTM.tif"))  # uppercase
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})
