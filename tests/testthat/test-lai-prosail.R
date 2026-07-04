# test-lai-prosail.R — repli LAI Sentinel-2/PROSAIL (spec 033)
#
# L'inversion réelle (train/apply PROSAIL + scènes S2) n'est pas jouée en CI :
# on teste le chemin `precomputed` pur (réduction temporelle), la SRF, la
# dégradation, le flag NDP et l'injection `pai` dans regen_sensibilite.

.lai_stack <- function(vals) {
  # une couche par date, valeur constante par couche (moyenne = la valeur).
  r <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 4,
                   nlyrs = length(vals), crs = "EPSG:2154")
  for (i in seq_along(vals)) terra::values(r[[i]]) <- rep(vals[i], terra::ncell(r))
  r
}

test_that("precomputed single-layer LAI passes through as `lai`", {
  skip_if_not_installed("terra")
  r <- .lai_stack(3.2)
  out <- lai_sentinel2(precomputed = r)
  expect_true(inherits(out, "SpatRaster"))
  expect_identical(names(out), "lai")
  expect_equal(terra::nlyr(out), 1L)
})

test_that("temporal reducers collapse a multi-date LAI stack", {
  skip_if_not_installed("terra")
  st <- .lai_stack(c(1, 2, 3, 4, 100))     # p90 ~ 4 ; max = 100 ; median = 3
  p90 <- terra::global(lai_sentinel2(precomputed = st, reducer = "p90"), "mean")[[1]]
  mx  <- terra::global(lai_sentinel2(precomputed = st, reducer = "max"), "mean")[[1]]
  med <- terra::global(lai_sentinel2(precomputed = st, reducer = "median"), "mean")[[1]]
  expect_lt(p90, mx)
  expect_equal(mx, 100)
  expect_equal(med, 3)
})

test_that("an unknown reducer errors", {
  skip_if_not_installed("terra")
  expect_error(lai_sentinel2(precomputed = .lai_stack(c(1, 2)), reducer = "zzz"),
               "reducer")
})

test_that("a non-raster precomputed errors", {
  expect_error(lai_sentinel2(precomputed = 42), "SpatRaster")
})

test_that("engine degrades to NULL with no scene (no train)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("prosail")
  # Ni refl ni aoi -> abort interne 'Provide refl' -> tryCatch -> NULL, sans
  # déclencher l'entraînement (coûteux).
  expect_warning(res <- lai_sentinel2(), "returning NULL")
  expect_null(res)
})

test_that("prosail S2 SRF carries the required $sensor field", {
  skip_if_not_installed("prosail")
  srf <- .lai_s2_srf("Sentinel_2A")
  expect_true(is.list(srf))
  expect_identical(srf$sensor, "Sentinel_2A")
  expect_true(all(c("spectral_response", "spectral_bands") %in% names(srf)))
})

test_that("detect_ndp flags lai_ml for a PROSAIL S2 LAI source", {
  df <- data.frame(x = 1)
  attr(df, "lai_source") <- "prosail_s2"
  expect_true("lai_ml" %in% detect_ndp(df)$augmented)
  # Base NDP unchanged (flag is separate).
  expect_false("lai_ml" %in% detect_ndp(data.frame(x = 1))$augmented)
})

test_that("regen_sensibilite accepts a `pai` fallback (no LiDAR required)", {
  skip_if_not_installed("terra")
  # Sans microclimf -> abort paquet ; avec microclimf mais sans mnt/mnh -> abort
  # entrées. Dans les deux cas, fournir `pai` sans `las` NE doit PAS réclamer las.
  u <- sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(5, 0), c(5, 5), c(0, 5), c(0, 0)))),
    crs = 2154))
  lai <- .lai_stack(3)[[1]]
  err <- tryCatch(
    regen_sensibilite(u, mnt = "x", mnh = "y", pai = lai,
                      annees_moy = 2014, annees_canic = 2018),
    error = function(e) conditionMessage(e))
  # L'erreur ne doit PAS être « needs ... las » manquant : `pai` couvre le besoin.
  expect_false(grepl("either .*las.* or .*pai", err) &&
                 grepl("engine path needs", err))
})
