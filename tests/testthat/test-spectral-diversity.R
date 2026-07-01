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

test_that("compute_spectral_diversity validates its reflectance argument", {
  skip_if_not_installed("biodivMapR")
  expect_error(
    compute_spectral_diversity(reflectance = 42),
    "SpatRaster or an existing raster file path")
})

test_that("normalize_indicator scales B4 (Shannon) and L3 (Bray-Curtis)", {
  # B4: high = good, bound [0, log(50)].
  expect_equal(normalize_indicator("indicateur_b4_div_spectrale",
                                    c(0, log(50))), c(0, 100))
  expect_equal(normalize_indicator("B4", log(50)), 100)
  # L3: high = good, provisional [0, 1] scale.
  expect_equal(normalize_indicator("indicateur_l3_het_spectrale",
                                    c(0, 0.5, 1)), c(0, 50, 100))
  expect_equal(normalize_indicator("L3", 1), 100)
})

test_that("B4 and L3 are registered in the indicator config", {
  b <- get_family_config("B")
  l <- get_family_config("L")
  expect_true("B4" %in% b$indicators)
  expect_true("L3" %in% l$indicators)
  expect_true("indicateur_b4_div_spectrale" %in% b$column_names)
  expect_true("indicateur_l3_het_spectrale" %in% l$column_names)
})

test_that("real biodivMapR pipeline smoke (manual, needs Sentinel-2)", {
  skip(paste("Manual smoke test: run compute_spectral_diversity() on a real",
             "Sentinel-2 reflectance scene; verify alpha/beta rasters and",
             "recalibrate normalization bounds (spec 028 D3)."))
})
