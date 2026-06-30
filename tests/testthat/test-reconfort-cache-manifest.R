# test-reconfort-cache-manifest.R — cache-side RECONFORT layer manifest (L6)
#   * discovers persisted display rasters without the in-memory result
#   * run_id = NULL picks the most recent run
#   * classification always; score/probability when present; stacks excluded
#   * empty / missing cache -> zero-row frame
#   * schema byte-identical to reconfort_layer_manifest(result)

skip_if_no_terra <- function() testthat::skip_if_not_installed("terra")

write_tif <- function(path, val = 1) {
  r <- terra::rast(nrow = 4, ncol = 4, xmin = 700000, xmax = 700040,
                   ymin = 6800000, ymax = 6800040, crs = "EPSG:2154")
  terra::values(r) <- val
  terra::writeRaster(r, path, overwrite = TRUE)
  path
}

# Lay out a zone cache like run_reconfort_dieback()'s persist phase.
setup_cache <- function(dir, zone_id = 5, run_id = "20260630T101010",
                        with_score = FALSE) {
  zdir <- file.path(dir, sprintf("zone_%s", zone_id))
  dir.create(zdir, recursive = TRUE, showWarnings = FALSE)
  write_tif(file.path(zdir, sprintf("reconfort_mask_%s.tif", run_id)))
  if (with_score) {
    write_tif(file.path(zdir, sprintf("reconfort_score_%s.tif", run_id)), 50)
    write_tif(file.path(zdir, sprintf("reconfort_proba_%s.tif", run_id)), 500)
  }
  # CRswir / CRre stacks in run_<id>/ — must NOT appear in the manifest.
  rdir <- file.path(zdir, sprintf("run_%s", run_id))
  dir.create(rdir, showWarnings = FALSE)
  write_tif(file.path(rdir, "crswir_stack.tif"))
  write_tif(file.path(rdir, "crre_stack.tif"))
  invisible(zdir)
}

test_that("a cache with only the mask yields a 1-row classification manifest", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  setup_cache(d, zone_id = 5, run_id = "20260630T101010", with_score = FALSE)
  m <- reconfort_cache_manifest(d, zone_id = 5)
  expect_s3_class(m, "data.frame")
  expect_identical(m$id, "classification")
  expect_identical(m$type, "raster")
  expect_true(m$categorical)
  expect_match(m$path, "reconfort_mask_20260630T101010\\.tif$")
})

test_that("run_id = NULL picks the most recent run", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  setup_cache(d, 5, "20260629T090000")
  setup_cache(d, 5, "20260630T101010")
  m <- reconfort_cache_manifest(d, 5)
  expect_match(m$path[m$id == "classification"], "20260630T101010")
})

test_that("score + probability give 3 raster rows; stacks excluded", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  setup_cache(d, 5, "20260630T101010", with_score = TRUE)
  m <- reconfort_cache_manifest(d, 5)
  expect_setequal(m$id, c("score", "classification", "probability"))
  expect_identical(nrow(m), 3L)
  expect_false(any(grepl("crswir|crre|stack", m$path)))
})

test_that("include_range fills the real domain of the score raster", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  setup_cache(d, 5, "20260630T101010", with_score = TRUE)  # score value 50
  m <- reconfort_cache_manifest(d, 5, include_range = TRUE)
  expect_equal(m$vmin[m$id == "score"], 50)
  expect_equal(m$vmax[m$id == "score"], 50)
})

test_that("missing cache / zone / run yields a zero-row frame", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  expect_identical(nrow(reconfort_cache_manifest(d, 5)), 0L)
  expect_identical(nrow(reconfort_cache_manifest("/no/such/dir", 5)), 0L)
  dir.create(file.path(d, "zone_5"))            # present but empty
  expect_identical(nrow(reconfort_cache_manifest(d, 5)), 0L)
})

test_that("fallback path <cache_dir>/reconfort/zone_<id> is honoured", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  setup_cache(file.path(d, "reconfort"), 5, "20260630T101010")
  m <- reconfort_cache_manifest(d, 5)
  expect_identical(m$id, "classification")
})

test_that("schema is identical to reconfort_layer_manifest(result)", {
  skip_if_no_terra()
  d <- withr::local_tempdir()
  setup_cache(d, 5, "20260630T101010", with_score = TRUE)
  cache_m <- reconfort_cache_manifest(d, 5)
  z <- file.path(d, "zone_5")
  res <- list(rasters = list(
    continuous_score   = file.path(z, "reconfort_score_20260630T101010.tif"),
    classif_masked     = file.path(z, "reconfort_mask_20260630T101010.tif"),
    probability_masked = file.path(z, "reconfort_proba_20260630T101010.tif")))
  mem_m <- reconfort_layer_manifest(res)
  expect_identical(names(cache_m), names(mem_m))
  expect_identical(vapply(cache_m, class, ""), vapply(mem_m, class, ""))
  expect_identical(cache_m$id, mem_m$id)
})
