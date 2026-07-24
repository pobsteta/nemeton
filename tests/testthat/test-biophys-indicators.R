# Chaînage bout-en-bout biophysique_sentinel2() -> indicateurs (spec 042 lot 2).
# Les consommateurs (C2 fapar, A1 fvc) préexistaient (phase Theia s2_biophysical) ;
# ces tests vérifient que le socle v0.166.0 les alimente directement, via la voie
# `precomputed` pure (pas de prosail, pas de réseau).

.biophys_demo <- function(vals = NULL) {
  data(massif_demo_units, envir = environment())
  u <- massif_demo_units
  bb <- sf::st_bbox(u)
  r <- terra::rast(xmin = bb[[1]], xmax = bb[[3]], ymin = bb[[2]], ymax = bb[[4]],
                   nrows = 30, ncols = 30, crs = "EPSG:2154")
  terra::values(r) <- if (is.null(vals)) rep(0.6, terra::ncell(r)) else vals
  list(units = u, refl = r)
}

test_that("biophysique_sentinel2('fvc') alimente directement A1", {
  skip_if_not_installed("terra")
  d <- .biophys_demo()
  fvc <- biophysique_sentinel2("fvc", precomputed = d$refl)
  out <- indicateur_a1_couverture(d$units, fvc = fvc)
  expect_s3_class(out, "sf")
  expect_true("A1" %in% names(out))
  # A1 = FVC(0-1) x 100 ; FVC constant 0.6 -> A1 ~ 60.
  expect_equal(mean(out$A1, na.rm = TRUE), 60, tolerance = 1)
})

test_that("biophysique_sentinel2('fapar') alimente directement C2", {
  skip_if_not_installed("terra")
  d <- .biophys_demo()
  fapar <- biophysique_sentinel2("fapar", precomputed = d$refl)
  lay <- structure(list(rasters = list()), class = "nemeton_layers")
  c2 <- indicateur_c2_ndvi(d$units, lay, fapar = fapar)
  expect_length(c2, nrow(d$units))
  # C2 = moyenne fAPAR par UGF ; fAPAR constant 0.6 -> C2 ~ 0.6.
  expect_equal(mean(c2, na.rm = TRUE), 0.6, tolerance = 0.05)
})

test_that("fAPAR et NDVI sont sur la même échelle 0-1 (drop-in pour C2)", {
  # Le remplacement de proxy n'a de sens que si les échelles coïncident :
  # le NDVI et le fAPAR sont tous deux dans [0,1], donc normalisation aval
  # identique. Garde-fou contre une régression d'échelle.
  skip_if_not_installed("terra")
  d <- .biophys_demo(vals = runif(900, 0.2, 0.9))
  fapar <- biophysique_sentinel2("fapar", precomputed = d$refl)
  v <- terra::values(fapar)
  expect_true(all(v >= 0 & v <= 1, na.rm = TRUE))
})
