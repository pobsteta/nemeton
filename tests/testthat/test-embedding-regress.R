# Spec 064 : embedding_regress(). Embedding synthetique (6 bandes, 250 m)
# et cible lineaire connue : H0 = 20 + 6 A00 - 4 A01 + bruit.

.emb_regress_cas <- function(n = 200, bruit = 0.3, seed = 7) {
  set.seed(seed)
  r <- terra::rast(xmin = 0, xmax = 50000, ymin = 0, ymax = 50000,
                   resolution = 250, nlyrs = 6, crs = "EPSG:2154")
  terra::values(r) <- matrix(stats::rnorm(terra::ncell(r) * 6), ncol = 6)
  names(r) <- sprintf("A%02d", 0:5)
  pts <- sf::st_as_sf(data.frame(x = stats::runif(n, 1000, 49000),
                                 y = stats::runif(n, 1000, 49000)),
                      coords = c("x", "y"), crs = 2154)
  v <- terra::extract(r, terra::vect(pts))
  pts$H0 <- 20 + 6 * v$A00 - 4 * v$A01 + stats::rnorm(n, 0, bruit)
  list(r = r, pts = pts)
}

test_that("ridge recovers a linear target and predicts a raster", {
  skip_if_not_installed("exactextractr")
  cas <- .emb_regress_cas()
  m <- suppressMessages(embedding_regress(cas$pts, cas$r, methode = "ridge",
                                          rayon_m = 10))
  expect_s3_class(m, "embedding_regression")
  expect_equal(m$status, "ok")
  expect_equal(m$methode, "ridge")
  expect_gt(m$cv$r2, 0.9)
  expect_lt(abs(m$cv$biais), 0.3)
  expect_s4_class(m$prediction, "SpatRaster")
  expect_equal(names(m$prediction), "H0")
  expect_equal(attr(m$prediction, "chm_source"), "aef_regression")
  # la prediction en un pixel suit la formule
  cellule <- terra::values(cas$r)[1, ]
  attendu <- 20 + 6 * cellule[1] - 4 * cellule[2]
  expect_equal(unname(terra::values(m$prediction)[1, 1]), unname(attendu), tolerance = 0.3)
  expect_output(print(m), "spatial CV")
})

test_that("folds are made of whole spatial blocks", {
  skip_if_not_installed("exactextractr")
  cas <- .emb_regress_cas()
  m <- suppressMessages(embedding_regress(cas$pts, cas$r, methode = "ridge",
                                          rayon_m = 10, taille_bloc_m = 10000,
                                          predire = FALSE))
  xy <- sf::st_coordinates(cas$pts)
  bloc <- paste(floor(xy[, 1] / 10000), floor(xy[, 2] / 10000))
  plis_par_bloc <- tapply(m$cv$observations$pli, bloc, function(p) length(unique(p)))
  expect_true(all(plis_par_bloc == 1L))
  expect_null(m$prediction)
  expect_true(all(is.finite(m$cv$observations$predit)))
})

test_that("ranger is used when asked and installed", {
  skip_if_not_installed("exactextractr")
  skip_if_not_installed("ranger")
  cas <- .emb_regress_cas()
  m <- suppressMessages(embedding_regress(cas$pts, cas$r, methode = "ranger",
                                          rayon_m = 10, predire = FALSE))
  expect_equal(m$methode, "ranger")
  expect_gt(m$cv$r2, 0.5)
})

test_that("too few plots: no model, status train_too_small", {
  skip_if_not_installed("exactextractr")
  cas <- .emb_regress_cas(n = 20)
  m <- suppressMessages(embedding_regress(cas$pts, cas$r, methode = "ridge",
                                          rayon_m = 10))
  expect_equal(m$status, "train_too_small")
  expect_null(m$prediction)
  expect_null(m$cv)
  expect_equal(m$n_train, 20L)
})

test_that("embedding_regress checks its inputs", {
  cas <- .emb_regress_cas(n = 40)
  expect_error(embedding_regress(data.frame(H0 = 1), cas$r), "sf")
  expect_error(embedding_regress(cas$pts, cas$r, target = "P0"), "not found")
  expect_error(suppressMessages(
    embedding_regress(cas$pts, cas$r, methode = "ridge", rayon_m = 10,
                      taille_bloc_m = 1e6)
  ), "one 1e\\+06 m block|one 1000000 m block")
})

test_that("the ridge GCV shrinks towards the mean when there is no signal", {
  set.seed(3)
  x <- matrix(stats::rnorm(400), 100, 4)
  y <- stats::rnorm(100)
  m <- nemeton:::.ridge_ajuste(x, y)
  expect_lt(max(abs(m$beta)), 0.3)
  expect_equal(length(nemeton:::.ridge_predit(m, x)), 100L)
})
