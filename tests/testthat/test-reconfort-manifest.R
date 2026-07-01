# test-reconfort-manifest.R — RECONFORT layer manifest (L6, spec 021)
#   * reconfort_layer_manifest() row selection (available layers only)
#   * masked-preferred / raw-fallback path resolution
#   * rendering hints (palette, reverse, domain, visibility, opacity)
#   * alert vector row driven by alerts_sf / n_alerts
#   * include_range override via terra::minmax (best-effort)
#   * input validation + empty-run shape

# A minimal `run_reconfort_dieback()`-shaped result. Paths are plain
# strings here (the manifest does not read them unless include_range).
fake_result <- function(rasters = list(), alerts_sf = NULL,
                        n_alerts = NULL) {
  list(status = "completed", rasters = rasters,
       alerts_sf = alerts_sf, n_alerts = n_alerts)
}

full_rasters <- function() {
  list(
    final_dir          = "/run/final",
    classif            = "/run/final/Classif_Seed_0.tif",
    classif_masked     = "/run/final/Final_Classif_masked_2024.tif",
    probability        = "/run/final/ProbabilityMap_seed_0.tif",
    probability_masked = "/run/final/Final_Proba_map_masked2024.tif",
    continuous_score   = "/run/final/Final_continuous_score_masked2024.tif"
  )
}

test_that("a full run lists score, classification, probability + no alerts", {
  m <- reconfort_layer_manifest(fake_result(full_rasters()))
  expect_s3_class(m, "data.frame")
  # alerts absent (n_alerts NULL) -> 3 raster rows only
  expect_identical(m$id, c("score", "classification", "probability"))
  expect_identical(m$type, rep("raster", 3L))
  # masked variants preferred
  expect_match(m$path[m$id == "classification"], "Final_Classif_masked")
  expect_match(m$path[m$id == "probability"], "Final_Proba_map_masked")
  # rendering hints for the score
  sc <- m[m$id == "score", ]
  expect_false(sc$categorical)
  expect_identical(sc$palette, "RdYlGn")
  expect_true(sc$reverse)
  expect_equal(c(sc$vmin, sc$vmax), c(1, 100))
  expect_true(sc$default_visible)
  expect_equal(sc$default_opacity, 0.8)
})

test_that("classification falls back to the raw raster when unmasked", {
  r <- full_rasters()
  r$classif_masked <- NA_character_
  m <- reconfort_layer_manifest(fake_result(r))
  expect_match(m$path[m$id == "classification"], "Classif_Seed_0")
  # classification is categorical with no continuous palette/domain
  cl <- m[m$id == "classification", ]
  expect_true(cl$categorical)
  expect_true(is.na(cl$palette))
  expect_true(is.na(cl$vmin) && is.na(cl$vmax))
})

test_that("layers with no available raster are skipped", {
  r <- list(continuous_score = "/run/final/score.tif",
            classif = NA_character_, classif_masked = NA_character_,
            probability = NA_character_, probability_masked = NA_character_)
  m <- reconfort_layer_manifest(fake_result(r))
  expect_identical(m$id, "score")
})

test_that("alert row appears from alerts_sf and carries the feature count", {
  skip_if_not_installed("sf")
  pts <- sf::st_sf(
    id = 1:3,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), sf::st_point(c(1, 1)),
                          sf::st_point(c(2, 2)), crs = 2154))
  m <- reconfort_layer_manifest(fake_result(full_rasters(), alerts_sf = pts))
  al <- m[m$id == "alerts", ]
  expect_identical(nrow(al), 1L)
  expect_identical(al$type, "vector")
  expect_true(is.na(al$path))
  expect_identical(al$n_features, 3L)
  expect_true(al$default_visible)
})

test_that("alert row falls back to the n_alerts scalar without alerts_sf", {
  m <- reconfort_layer_manifest(fake_result(full_rasters(), n_alerts = 7))
  expect_identical(m$n_features[m$id == "alerts"], 7L)
})

test_that("zero alerts produce no alert row", {
  m <- reconfort_layer_manifest(fake_result(full_rasters(), n_alerts = 0))
  expect_false("alerts" %in% m$id)
})

test_that("an empty run yields a zero-row frame with the right columns", {
  m <- reconfort_layer_manifest(fake_result(list()))
  expect_identical(nrow(m), 0L)
  expect_true(all(c("id", "label_key", "type", "path", "palette",
                    "default_opacity", "n_features") %in% names(m)))
})

test_that("a non-RECONFORT result is rejected", {
  expect_error(reconfort_layer_manifest(list(foo = 1)), "run_reconfort_dieback")
  expect_error(reconfort_layer_manifest("nope"), "run_reconfort_dieback")
})

test_that("include_range overrides the nominal domain from the raster", {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()   # runner terra::writeRaster anomaly
  tf <- withr::local_tempfile(fileext = ".tif")
  r <- terra::rast(nrow = 4, ncol = 4, xmin = 0, xmax = 40,
                   ymin = 0, ymax = 40, crs = "EPSG:2154")
  terra::values(r) <- seq(5, 80, length.out = 16)
  terra::writeRaster(r, tf, overwrite = TRUE)
  res <- fake_result(list(continuous_score = tf))
  m <- reconfort_layer_manifest(res, include_range = TRUE)
  expect_equal(m$vmin[m$id == "score"], 5)
  expect_equal(m$vmax[m$id == "score"], 80)
})
