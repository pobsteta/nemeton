# spec 028 — spectral diversity indicators B4 (alpha) / L3 (beta).
# The biodivMapR pipeline itself needs real Sentinel-2 reflectance and is
# exercised by a manual smoke test (skipped here). These cases cover the
# package-side contract: NA fallback, input validation, aggregation and
# normalization — none of which invoke biodivMapR.

.mini_units_ll <- function(n = 2) {
  polys <- lapply(seq_len(n), function(i) {
    sf::st_polygon(list(rbind(
      c(i, 0), c(i + 1, 0), c(i + 1, 1), c(i, 1), c(i, 0))))
  })
  sf::st_sf(id = seq_len(n),
            geometry = sf::st_sfc(polys, crs = 4326))
}

test_that("B4 / L3 are strictly backward compatible: no data -> NA column", {
  u <- .mini_units_ll()
  b4 <- indicateur_b4_div_spectrale(u)          # no spectral, no reflectance
  l3 <- indicateur_l3_het_spectrale(u)
  expect_true("B4" %in% names(b4))
  expect_true("L3" %in% names(l3))
  expect_true(all(is.na(b4$B4)))
  expect_true(all(is.na(l3$L3)))
  expect_equal(nrow(b4), nrow(u))
})

test_that("B4 / L3 reject non-sf units", {
  expect_error(indicateur_b4_div_spectrale(data.frame(x = 1)), "must be an sf")
  expect_error(indicateur_l3_het_spectrale(list(a = 1)), "must be an sf")
})

test_that("B4 / L3 aggregate a precomputed alpha/beta raster per unit", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  # A synthetic diversity raster with a west/east gradient over the units.
  r <- terra::rast(xmin = 1, xmax = 3, ymin = 0, ymax = 1,
                   resolution = 0.1, crs = "EPSG:4326")
  terra::values(r) <- rep(seq(0, 1, length.out = terra::ncol(r)),
                          each = terra::nrow(r))
  u <- .mini_units_ll(2)

  spectral <- list(alpha = r, beta = r, output_dir = tempdir())
  b4 <- indicateur_b4_div_spectrale(u, spectral = spectral)
  expect_false(anyNA(b4$B4))
  expect_length(b4$B4, 2)
  # West unit (x in [1,2]) has lower gradient values than east (x in [2,3]).
  expect_lt(b4$B4[1], b4$B4[2])

  # A NULL raster in the spectral object -> NA (metric not produced).
  b4_na <- indicateur_b4_div_spectrale(u, spectral = list(alpha = NULL))
  expect_true(all(is.na(b4_na$B4)))
})

test_that("L3 reads a MULTI-BAND beta raster as a dispersion, not a position", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  # biodivMapR's beta diversity is a 3-band raster: the first three PCoA axes
  # of the Bray-Curtis dissimilarity, i.e. ORDINATION COORDINATES centred on
  # zero. Averaging them (what this did before v0.190.0) measures a unit's
  # mean POSITION in that space, which carries no diversity meaning and sits
  # near zero by construction. L3 is the unit's DISPERSION about its own
  # centroid instead.
  r1 <- terra::rast(xmin = 1, xmax = 3, ymin = 0, ymax = 1,
                    resolution = 0.1, crs = "EPSG:4326")
  terra::values(r1) <- rep(seq(0, 1, length.out = terra::ncol(r1)),
                           each = terra::nrow(r1))
  beta3 <- c(r1, r1 * 2, r1 * 3)          # 3-band beta ordination
  names(beta3) <- c("PCO1", "PCO2", "PCO3")
  u <- .mini_units_ll(2)

  l3 <- indicateur_l3_het_spectrale(u, spectral = list(beta = beta3))
  expect_length(l3$L3, 2)
  expect_type(l3$L3, "double")            # scalar per unit, no list-column
  expect_false(anyNA(l3$L3))
  expect_true(all(l3$L3 > 0))
  # Both units span the SAME internal contrast (same gradient slope over the
  # same width), so their dispersion is the same even though their positions
  # in ordination space differ. Under the pre-v0.190.0 band-average the two
  # differed by construction — that difference was the artefact.
  expect_equal(l3$L3[1], l3$L3[2], tolerance = 1e-8)
})

test_that("L3 dispersion: a spectrally uniform unit scores ~0, a contrasted one high", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  band <- terra::rast(xmin = 1, xmax = 3, ymin = 0, ymax = 1,
                      resolution = 0.1, crs = "EPSG:4326")
  # West half constant (a uniform community), east half alternating (maximal
  # contrast). `times =` fills row-major, so this really is a west/east split.
  col_val <- c(rep(0.5, terra::ncol(band) / 2),
               rep(c(0, 1), length.out = terra::ncol(band) / 2))
  terra::values(band) <- rep(col_val, times = terra::nrow(band))
  beta3 <- c(band, band, band)
  names(beta3) <- c("PCO1", "PCO2", "PCO3")

  l3 <- indicateur_l3_het_spectrale(.mini_units_ll(2), spectral = list(beta = beta3))
  expect_equal(l3$L3[1], 0, tolerance = 1e-8)   # uniform -> no turnover
  expect_gt(l3$L3[2], 0.5)                      # contrasted -> high turnover
  expect_gt(l3$L3[2], l3$L3[1])
})

test_that("L3 returns NA rather than a fabricated value below min_windows", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  fine <- terra::rast(xmin = 1, xmax = 3, ymin = 0, ymax = 1,
                      resolution = 0.1, crs = "EPSG:4326")
  terra::values(fine) <- seq_len(terra::ncell(fine)) / terra::ncell(fine)
  beta_fine <- c(fine, fine * 2, fine * 3)
  u <- .mini_units_ll(2)

  # A dispersion around a centroid is degenerate on very few windows: rather
  # than emit a near-zero that reads as "uniform", the unit is NA (the
  # "no invented value" rule, v0.187.0). 100 windows per unit here, so only
  # an absurd threshold triggers it.
  expect_true(all(is.na(
    indicateur_l3_het_spectrale(u, spectral = list(beta = beta_fine),
                                min_windows = 10000L)$L3)))
  expect_false(anyNA(
    indicateur_l3_het_spectrale(u, spectral = list(beta = beta_fine))$L3))

  # The floor is 3 and cannot be lowered: on a raster giving each unit only
  # ONE window, min_windows = 1L still yields NA.
  coarse <- terra::rast(xmin = 1, xmax = 3, ymin = 0, ymax = 1,
                        resolution = 1, crs = "EPSG:4326")
  terra::values(coarse) <- c(0.2, 0.8)
  beta_coarse <- c(coarse, coarse * 2, coarse * 3)
  expect_true(all(is.na(
    indicateur_l3_het_spectrale(u, spectral = list(beta = beta_coarse),
                                min_windows = 1L)$L3)))
})

test_that("L3 falls back to NA when the beta raster was not produced", {
  # Symmetric with the B4 case above: biodivMapR can return an alpha map and
  # no beta one (or the reverse). A missing metric is NA, never a zero.
  l3 <- indicateur_l3_het_spectrale(.mini_units_ll(2),
                                    spectral = list(beta = NULL))
  expect_true(all(is.na(l3$L3)))
})

test_that("B4 / L3 reproject the units onto the raster CRS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  # biodivMapR writes in the scene's UTM CRS (EPSG:32631 on the reference run)
  # while the units arrive in the project CRS. Both aggregators must transform
  # rather than silently miss the raster.
  u <- .mini_units_ll(2)
  u_m <- sf::st_transform(u, 3857)

  r <- terra::rast(xmin = 1, xmax = 3, ymin = 0, ymax = 1,
                   resolution = 0.1, crs = "EPSG:4326")
  terra::values(r) <- seq_len(terra::ncell(r)) / terra::ncell(r)
  beta3 <- c(r, r * 2, r * 3)

  b4 <- indicateur_b4_div_spectrale(u_m, spectral = list(alpha = r))
  l3 <- indicateur_l3_het_spectrale(u_m, spectral = list(beta = beta3))
  expect_false(anyNA(b4$B4))
  expect_false(anyNA(l3$L3))
  # Same numbers as the un-reprojected call: the transform is plumbing, not a
  # change of measurement.
  expect_equal(b4$B4, indicateur_b4_div_spectrale(u, spectral = list(alpha = r))$B4,
               tolerance = 1e-6)
  expect_equal(l3$L3, indicateur_l3_het_spectrale(u, spectral = list(beta = beta3))$L3,
               tolerance = 1e-6)
})

test_that("compute_spectral_diversity validates its reflectance argument", {
  skip_if_not_installed("biodivMapR")
  expect_error(
    compute_spectral_diversity(reflectance = 42),
    "SpatRaster or an existing raster file path")
})

test_that("normalize_indicator scales B4 (Shannon) and L3 (PCoA dispersion)", {
  # B4: high = good, bound [0, log(10)] -- ten effective spectral species
  # per window (spec 028 D3 recalibrated on the reference run, §10).
  expect_equal(normalize_indicator("indicateur_b4_div_spectrale",
                                    c(0, log(10))), c(0, 100))
  expect_equal(normalize_indicator("B4", log(10)), 100)
  # Above the ceiling it clamps rather than overflows: the reference run's
  # best window (H = 2.456, 11.7 effective species) saturates.
  expect_equal(normalize_indicator("B4", 2.456), 100)

  # L3: high = good, bound [0, 0.5] -- the amplitude a 3-axis PCoA of the
  # Bray-Curtis dissimilarity actually reaches.
  expect_equal(normalize_indicator("indicateur_l3_het_spectrale",
                                    c(0, 0.25, 0.5)), c(0, 50, 100))
  expect_equal(normalize_indicator("L3", 1), 100)     # clamped, not 200
})

test_that("the recalibrated scales spread the reference run instead of crushing it", {
  # Anchors measured on the spec 028 §10 reference run (tile T31UFQ, scene
  # S2A_MSIL2A_20170814, 30 UGF). The point of the recalibration is that a
  # typical unit no longer sits pinned to the bottom of the scale.
  b4_typical <- normalize_indicator("B4", 0.7968)     # median UGF Shannon
  b4_best    <- normalize_indicator("B4", 1.5528)     # best UGF
  expect_gt(b4_typical, 30); expect_lt(b4_typical, 40)
  expect_gt(b4_best, 60)
  # Under the provisional log(50) ceiling the same massif spanned 7 to 40.
  expect_gt(b4_best - b4_typical, 25)

  l3_typical <- normalize_indicator("L3", 0.2822)     # median UGF dispersion
  l3_low     <- normalize_indicator("L3", 0.0644)     # least heterogeneous UGF
  expect_gt(l3_typical, 50); expect_lt(l3_typical, 62)
  # The least heterogeneous unit is LOW, not zero: before v0.190.0 more than
  # half the units landed on exactly 0 because the PCoA axes are signed.
  expect_gt(l3_low, 0)
})

test_that("B4 and L3 are registered in the indicator config", {
  b <- get_family_config("B")
  l <- get_family_config("L")
  expect_true("B4" %in% b$indicators)
  expect_true("L3" %in% l$indicators)
  expect_true("indicateur_b4_div_spectrale" %in% b$column_names)
  expect_true("indicateur_l3_het_spectrale" %in% l$column_names)
})

test_that(".find_diversity_raster picks the map, not its dispersion companion", {
  # THE defect the real smoke exposed (spec 028 §10): biodivMapR writes
  # shannon_mean.tiff (17 chars) next to shannon_sd.tiff (15). The old
  # shortest-name tie-break therefore made B4 read the STANDARD DEVIATION of
  # Shannon within the window instead of its mean -- on the reference run
  # every one of the 30 units then scored between 3.5 and 5.4 out of 100.
  d <- withr::local_tempdir()
  for (f in c("shannon_mean.tiff", "shannon_sd.tiff", "beta.tiff")) {
    file.create(file.path(d, f))
  }
  expect_equal(basename(.find_diversity_raster(d, "shannon")),
               "shannon_mean.tiff")
  expect_equal(basename(.find_diversity_raster(d, "beta")), "beta.tiff")
  expect_true(is.na(.find_diversity_raster(d, "simpson")))

  # Other dispersion suffixes are excluded on the same rule.
  d2 <- withr::local_tempdir()
  for (f in c("richness_mean.tif", "richness_cv.tif", "richness_var.tif")) {
    file.create(file.path(d2, f))
  }
  expect_equal(basename(.find_diversity_raster(d2, "richness")),
               "richness_mean.tif")

  # Degenerate case: only a dispersion map exists -> return it rather than
  # NA, so the caller sees a wrong-but-diagnosable raster, not an absence.
  d3 <- withr::local_tempdir()
  file.create(file.path(d3, "shannon_sd.tiff"))
  expect_equal(basename(.find_diversity_raster(d3, "shannon")),
               "shannon_sd.tiff")
})

test_that("real biodivMapR pipeline smoke (manual, needs Sentinel-2)", {
  skip(paste(
    "Manual smoke. The reference run is recorded in spec 028 section 10",
    "(tile T31UFQ, scene S2A_MSIL2A_20170814, 649 windows, 30 UGF,",
    "nbclusters = 50). Re-run compute_spectral_diversity() on a SECOND",
    "massif and compare: the B4 and L3 bounds are single-scene",
    "calibrations and spec 028 D3 stays open until a second scene",
    "confirms or moves them."))
})
