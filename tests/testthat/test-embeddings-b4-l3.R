# Spec 064 : B4 / L3 en mode embedding. Embeddings synthetiques construits a
# partir des centroides du dictionnaire : les etiquettes sont connues.

.raster_centroides <- function(etiquettes_fn, xmin = 0, ymin = 0, cote = 400) {
  C <- aef_clusters()
  r <- terra::rast(xmin = xmin, xmax = xmin + cote, ymin = ymin, ymax = ymin + cote,
                   resolution = 10, nlyrs = ncol(C), crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  k <- etiquettes_fn(xy[, 1], xy[, 2])
  terra::values(r) <- C[k, , drop = FALSE]
  names(r) <- colnames(C)
  r
}

.carre <- function(x0, y0, cote) {
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(x0, y0), c(x0 + cote, y0), c(x0 + cote, y0 + cote), c(x0, y0 + cote), c(x0, y0)
  ))), crs = 2154))
}

test_that("aef_clusters ships the fixed 32 x 64 dictionary with its provenance", {
  C <- aef_clusters()
  expect_equal(dim(C), c(32L, 64L))
  expect_equal(colnames(C), sprintf("A%02d", 0:63))
  expect_equal(attr(C, "meta")$k, 32L)
  expect_true(length(attr(C, "meta")$sites$site) >= 10)
  expect_error(aef_clusters("v0"), "No AlphaEarth cluster dictionary")
})

test_that("B4 embedding: one cluster gives 0, two half-half clusters give log(2)", {
  skip_if_not_installed("exactextractr")
  # moitie gauche de chaque fenetre de 100 m en cluster 1, moitie droite en 2
  r <- .raster_centroides(function(x, y) ifelse((x %% 100) < 50, 1L, 2L))
  u <- .carre(0, 0, 400)
  res <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = r))
  expect_equal(res$B4, log(2), tolerance = 1e-6)
  expect_equal(res$b4_status, "calculated_embedding")
  expect_equal(res$b4_methode, "embedding")

  r1 <- .raster_centroides(function(x, y) rep(3L, length(x)))
  res1 <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = r1))
  expect_equal(res1$B4, 0)
})

test_that("B4 embedding is the same for a parcel in two differently framed projects", {
  skip_if_not_installed("exactextractr")
  motif <- function(x, y) 1L + ((x %/% 30) + 2 * (y %/% 20)) %% 7L
  u <- .carre(200, 200, 200)
  a <- .raster_centroides(motif, xmin = 0, ymin = 0, cote = 600)
  b <- .raster_centroides(motif, xmin = 130, ymin = 70, cote = 500)
  ra <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = a))
  rb <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = b))
  expect_equal(ra$B4, rb$B4, tolerance = 1e-9)
  la <- suppressMessages(indicateur_l3_het_spectrale(u, embedding = a))
  lb <- suppressMessages(indicateur_l3_het_spectrale(u, embedding = b))
  expect_equal(la$L3, lb$L3, tolerance = 1e-9)
})

test_that("L3 embedding: uniform unit 0, two pure halves half the centroid gap", {
  skip_if_not_installed("exactextractr")
  C <- aef_clusters()
  u <- .carre(0, 0, 400)
  r <- .raster_centroides(function(x, y) ifelse(x < 200, 1L, 2L))
  res <- suppressMessages(indicateur_l3_het_spectrale(u, embedding = r))
  expect_equal(res$L3, sqrt(sum((C[1, ] - C[2, ])^2)) / 2, tolerance = 1e-6)
  expect_equal(res$l3_status, "calculated_embedding")
  expect_equal(res$l3_methode, "embedding")
  r0 <- .raster_centroides(function(x, y) rep(5L, length(x)))
  expect_equal(suppressMessages(indicateur_l3_het_spectrale(u, embedding = r0))$L3, 0)
})

test_that("embedding mode: too small a unit is NA with skipped_no_coverage", {
  skip_if_not_installed("exactextractr")
  r <- .raster_centroides(function(x, y) rep(1L, length(x)))
  petit <- .carre(110, 110, 30)
  res <- suppressMessages(indicateur_l3_het_spectrale(petit, embedding = r))
  expect_true(is.na(res$L3))
  expect_equal(res$l3_status, "skipped_no_coverage")
})

test_that("embedding mode reads layers$aef_embedding and the latest year of a list", {
  skip_if_not_installed("exactextractr")
  u <- .carre(0, 0, 400)
  r23 <- .raster_centroides(function(x, y) rep(1L, length(x)))
  r24 <- .raster_centroides(function(x, y) ifelse((x %% 100) < 50, 1L, 2L))
  res <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = list("2023" = r23, "2024" = r24)))
  expect_equal(res$B4, log(2), tolerance = 1e-6)
  withr::with_tempdir({
    terra::writeRaster(r24, "aef.tif")
    layers <- nemeton_layers(rasters = list(aef_embedding = "aef.tif"))
    res2 <- suppressMessages(indicateur_b4_div_spectrale(u, layers = layers))
  })
  expect_equal(res2$B4, log(2), tolerance = 1e-6)
})

test_that("without any source B4/L3 keep their status and an NA method", {
  u <- .carre(0, 0, 400)
  b4 <- suppressMessages(indicateur_b4_div_spectrale(u))
  expect_true(is.na(b4$B4))
  expect_equal(b4$b4_status, "skipped_no_spectral")
  expect_true(is.na(b4$b4_methode))
  l3 <- suppressMessages(indicateur_l3_het_spectrale(u))
  expect_equal(l3$l3_status, "skipped_no_spectral")
})

test_that("an embedding of the wrong dimension is refused", {
  r <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100, resolution = 10,
                   nlyrs = 4, crs = "EPSG:2154", vals = 0.5)
  expect_error(indicateur_b4_div_spectrale(.carre(0, 0, 100), embedding = r),
               "cluster dictionary")
})

test_that("normalisation: the embedding mode has its own B4 bound, L3 stays at 0.5", {
  expect_equal(as.numeric(normalize_indicator("B4", log(5), statut = "calculated_embedding")), 100)
  expect_equal(as.numeric(normalize_indicator("B4", log(5))), log(5) / log(10) * 100)
  expect_equal(as.numeric(normalize_indicator("B4", c(log(5), log(5)),
                                              statut = c("calculated", "calculated_embedding"))),
               c(log(5) / log(10) * 100, 100))
  expect_equal(as.numeric(normalize_indicator("L3", 0.25, statut = "calculated_embedding")), 50)
})
