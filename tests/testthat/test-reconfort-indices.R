# Indices RECONFORT CRswir / CRre : noyau Rust et repli R pur (mission 060).

bandes_aleatoires <- function(n, seed = 7L) {
  withr::local_seed(seed)
  data.frame(B4 = runif(n, 0, 0.3), B5 = runif(n, 0, 0.4), B6 = runif(n, 0, 0.6),
             B8A = runif(n, 0, 0.7), B11 = runif(n, 0, 0.6), B12 = runif(n, 0, 0.5))
}

test_that("les formules amont donnent les valeurs ecrites a la main", {
  withr::local_options(nemeton.rust = FALSE)
  # CRswir : d = 0.4 + 745 * (0.2 - 0.4) / 1325 ; CRswir = 0.3 / d = 1.04331
  # CRre   : d = 0.1 + 39 * (0.4 - 0.1) / 76 ;   CRre = 0.2 / d = 0.78756
  r <- reconfort_indices(data.frame(B4 = 0.1, B5 = 0.2, B6 = 0.4,
                                    B8A = 0.4, B11 = 0.3, B12 = 0.2))
  expect_equal(r$CRswir, 1.04331, tolerance = 1e-5)
  expect_equal(r$CRre, 0.78756, tolerance = 1e-5)
  expect_named(r, c("CRswir", "CRre"))
})

test_that("cas 1 : Rust = repli R (aleatoire, denominateur nul, NA)", {
  skip_if_not(.rust_routine("rust_cr_swir") |> is.null() |> isFALSE(),
              "noyau Rust non compile dans cette installation")
  b <- bandes_aleatoires(5000)
  # denominateur nul sans bandes nulles : B4 + 39 (B6 - B4) / 76 = 0 pour (39, -37)
  b[1, c("B4", "B5", "B6")] <- c(39, 5, -37)
  b[2, c("B8A", "B11", "B12")] <- c(745, 7, -580)
  b[3, ] <- 0
  b[4, "B11"] <- NA
  b[5, "B8A"] <- NA
  b[6, "B6"] <- NA_real_
  b[7, "B12"] <- NaN

  rust <- withr::with_options(list(nemeton.rust = TRUE), reconfort_indices(b))
  repli <- withr::with_options(list(nemeton.rust = FALSE), reconfort_indices(b))
  expect_true(withr::with_options(list(nemeton.rust = TRUE), nemeton_rust_disponible()))
  expect_false(withr::with_options(list(nemeton.rust = FALSE), nemeton_rust_disponible()))
  expect_equal(rust, repli, tolerance = 1e-12)
  expect_identical(is.na(rust$CRswir), is.na(repli$CRswir))
  expect_identical(is.na(rust$CRre), is.na(repli$CRre))
  # denominateur nul remplace par 1 : le resultat est la bande du numerateur
  expect_equal(rust$CRre[1], 5)
  expect_equal(rust$CRswir[2], 7)
  expect_equal(rust$CRswir[3], 0)
  # NA propages
  expect_true(is.na(rust$CRswir[4]) && is.na(rust$CRswir[5]) && is.na(rust$CRswir[7]))
  expect_true(is.na(rust$CRre[6]))
})

test_that("cas 6 : sans Rust (nemeton.rust = FALSE) les sorties sont identiques", {
  b <- bandes_aleatoires(200)
  a <- withr::with_options(list(nemeton.rust = FALSE), reconfort_indices(b))
  d <- withr::with_options(list(nemeton.rust = TRUE), reconfort_indices(b))
  expect_equal(a, d, tolerance = 1e-12)
})

test_that("reconfort_indices accepte matrice, liste et SpatRaster", {
  b <- bandes_aleatoires(6)
  ref <- reconfort_indices(b)
  expect_equal(reconfort_indices(as.matrix(b)), ref)
  expect_equal(reconfort_indices(as.list(b)), ref)
  names(b) <- tolower(names(b))
  expect_equal(reconfort_indices(b), ref)

  r <- terra::rast(nrows = 2, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 2,
                   crs = "EPSG:2154", nlyrs = 6)
  names(r) <- c("B4", "B5", "B6", "B8A", "B11", "B12")
  bb <- bandes_aleatoires(6)
  for (n in names(r)) terra::values(r[[n]]) <- bb[[n]]
  out <- reconfort_indices(r)
  expect_s4_class(out, "SpatRaster")
  expect_named(out, c("CRswir", "CRre"))
  expect_equal(terra::values(out$CRswir, mat = FALSE), reconfort_indices(bb)$CRswir)
})

test_that("reconfort_indices refuse une bande absente ou de longueur differente", {
  expect_error(reconfort_indices(data.frame(B4 = 1, B5 = 1)), "B8A")
  expect_error(reconfort_indices(list(B4 = 1:2, B5 = 1, B6 = 1), indices = "CRre"),
               "same length")
  # un seul indice demande : seules ses bandes sont necessaires
  r <- reconfort_indices(data.frame(B4 = 0.1, B5 = 0.2, B6 = 0.4), indices = "CRre")
  expect_named(r, "CRre")
})
