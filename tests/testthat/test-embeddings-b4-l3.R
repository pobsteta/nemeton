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

test_that("window entropy: a near-zero temperature gives the hard values 0 and log(2)", {
  # moitie gauche de chaque fenetre de 100 m en cluster 1, moitie droite en 2
  r2 <- .raster_centroides(function(x, y) ifelse((x %% 100) < 50, 1L, 2L))
  r1 <- .raster_centroides(function(x, y) rep(3L, length(x)))
  h2 <- terra::values(nemeton:::.embedding_fenetres(r2, tau = 1e-6)$shannon)[, 1]
  h1 <- terra::values(nemeton:::.embedding_fenetres(r1, tau = 1e-6)$shannon)[, 1]
  expect_equal(unique(round(h2, 9)), log(2))
  expect_equal(unique(round(h1, 9)), 0)
})

test_that("B4 embedding (soft assignment): uniform windows score 0, more clusters score higher", {
  skip_if_not_installed("exactextractr")
  u <- .carre(0, 0, 400)
  # uniformes, en deux points differents de l'espace : 0 tous les deux
  for (k in c(1L, 3L, 20L)) {
    r <- .raster_centroides(function(x, y) rep(k, length(x)))
    expect_equal(suppressMessages(indicateur_b4_div_spectrale(u, embedding = r))$B4,
                 0, tolerance = 1e-9, info = k)
  }
  # deux, puis quatre clusters bien separes (distances au dictionnaire > 0,8)
  C <- aef_clusters()
  d <- as.matrix(stats::dist(C))
  loin <- c(3L, which.max(d[3, ]))
  autres <- order(-pmin(d[loin[1], ], d[loin[2], ]))
  quatre <- c(loin, autres[!autres %in% loin][1:2])
  r2 <- .raster_centroides(function(x, y) ifelse((x %% 100) < 50, loin[1], loin[2]))
  r4 <- .raster_centroides(function(x, y)
    quatre[1L + ((x %/% 50) %% 2) + 2L * ((y %/% 50) %% 2)])
  b2 <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = r2))
  b4 <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = r4))
  expect_gt(b2$B4, 0)
  expect_gt(b4$B4, b2$B4)
  expect_lte(b2$B4, log(2) + 1e-9)
  expect_equal(b2$b4_status, "calculated_embedding")
  expect_equal(b2$b4_methode, "embedding")
})

test_that("the B4 embedding bounds in the code match the corpus file", {
  b <- attr(aef_clusters(), "meta")$bornes_b4
  expect_equal(b$h_min, nemeton:::.B4_EMBEDDING_H_MIN)
  expect_equal(b$h_max, nemeton:::.B4_EMBEDDING_H_MAX)
  expect_equal(b$tau, nemeton:::.EMBEDDING_TAU)
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
  attendu <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = r24))$B4
  res <- suppressMessages(indicateur_b4_div_spectrale(u, embedding = list("2023" = r23, "2024" = r24)))
  expect_equal(res$B4, attendu)
  withr::with_tempdir({
    terra::writeRaster(r24, "aef.tif")
    layers <- nemeton_layers(rasters = list(aef_embedding = "aef.tif"))
    res2 <- suppressMessages(indicateur_b4_div_spectrale(u, layers = layers))
  })
  expect_equal(res2$B4, attendu, tolerance = 1e-6)
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

test_that("normalisation: the embedding mode has its own B4 scale, L3 stays at 0.5", {
  lo <- nemeton:::.B4_EMBEDDING_H_MIN
  hi <- nemeton:::.B4_EMBEDDING_H_MAX
  expect_equal(as.numeric(normalize_indicator("B4", c(lo, (lo + hi) / 2, hi, 0, 4),
                                              statut = "calculated_embedding")),
               c(0, 50, 100, 0, 100))
  expect_equal(as.numeric(normalize_indicator("B4", 2)), 2 / log(10) * 100)
  expect_equal(as.numeric(normalize_indicator("B4", c(0.5, 0.5),
                                              statut = c("calculated", "calculated_embedding"))),
               c(0.5 / log(10) * 100, (0.5 - lo) / (hi - lo) * 100))
  expect_equal(as.numeric(normalize_indicator("L3", 0.25, statut = "calculated_embedding")), 50)
})
