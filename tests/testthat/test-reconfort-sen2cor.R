# Pile de caracteristiques v3 et grille de dates (mission 095), series fabriquees.

obs_synth <- function(b8a = c(0.4, 0.6), jours = c(0, 40)) {
  n <- length(jours)
  list(B4 = matrix(0.05, 1, n), B5 = matrix(0.08, 1, n), B6 = matrix(0.2, 1, n),
       B8A = matrix(b8a, 1), B11 = matrix(0.25, 1, n), B12 = matrix(0.15, 1, n))
}
cr_swir_ref <- function(b8a, b11 = 0.25, b12 = 0.15) {
  b11 / (b8a + (1610 - 865) * (b12 - b8a) / (2190 - 865))
}
cr_re_ref <- 0.08 / (0.05 + (704 - 665) * (0.2 - 0.05) / (741 - 665))

test_that("la grille v3 compte 67 dates, au pas de 10 jours depuis le 1er janvier N-1", {
  d <- .reconfort_dates_grille(2025L, "v3")
  expect_length(d, 67L)
  expect_equal(d[[1]], as.Date("2024-01-01"))
  expect_equal(d[[67]], as.Date("2025-10-22"))
  expect_true(all(diff(d) == 10))
  expect_length(.reconfort_dates_grille(2025L, "v3_early_may"), 52L)
})

test_that("pile v3 : 134 colonnes dans l'ordre CRswir puis CRre", {
  dg <- .reconfort_dates_grille(2025L)
  d0 <- dg[1]
  X <- reconfort_caracteristiques_v3(obs_synth(), d0 + c(0, 660), dg)
  expect_equal(dim(X), c(1L, 134L))
  expect_equal(colnames(X)[c(1, 67, 68, 134)], c("CRswir_1", "CRswir_67", "CRre_1", "CRre_67"))
  expect_equal(unname(X[1, "CRswir_1"]), cr_swir_ref(0.4))
  expect_equal(unname(X[1, "CRswir_67"]), cr_swir_ref(0.4 + 0.2 * 660 / 660))
  expect_equal(unname(X[1, "CRre_30"]), cr_re_ref)
})

test_that("interpolation lineaire des bandes AVANT l'indice, bords constants ou NA", {
  d0 <- as.Date("2024-01-01")
  dg <- d0 + seq(0, 50, by = 10)            # grille de 6 dates
  o <- obs_synth(jours = c(10, 40))          # obs aux jours 10 et 40
  X <- reconfort_caracteristiques_v3(o, d0 + c(10, 40), dg)
  # jour 20 : B8A interpole a 0.4 + (0.6 - 0.4) * 10/30 puis indice
  expect_equal(unname(X[1, "CRswir_3"]), cr_swir_ref(0.4 + 0.2 * 10 / 30))
  # bords constants : jour 0 = premiere observation, jour 50 = derniere
  expect_equal(unname(X[1, "CRswir_1"]), cr_swir_ref(0.4))
  expect_equal(unname(X[1, "CRswir_6"]), cr_swir_ref(0.6))
  # bord "na"
  Xn <- reconfort_caracteristiques_v3(o, d0 + c(10, 40), dg, bord = "na")
  expect_true(is.na(Xn[1, "CRswir_1"]) && is.na(Xn[1, "CRre_6"]))
  expect_equal(unname(Xn[1, "CRswir_3"]), unname(X[1, "CRswir_3"]))
})

test_that("observation invalide ignoree, trop peu d'observations = NA, ordre des dates libre", {
  d0 <- as.Date("2024-01-01")
  dg <- d0 + seq(0, 40, by = 10)
  o <- obs_synth(b8a = c(0.4, 9, 0.6), jours = c(0, 20, 40))
  o$B11[1, 2] <- NA                          # la scene du milieu est invalide
  X <- reconfort_caracteristiques_v3(o, d0 + c(0, 20, 40), dg)
  expect_equal(unname(X[1, "CRswir_3"]), cr_swir_ref(0.5))   # 9 ignore
  # dates dans le desordre : meme resultat
  Xd <- reconfort_caracteristiques_v3(lapply(o, function(m) m[, c(3, 1, 2), drop = FALSE]),
                                      d0 + c(40, 0, 20), dg)
  expect_equal(Xd, X)
  # une seule observation valide : pixel non predictible
  o1 <- obs_synth(); o1$B4[1, 2] <- NA
  expect_true(all(is.na(reconfort_caracteristiques_v3(o1, d0 + c(0, 40), dg))))
})

test_that("plusieurs pixels : chacun interpole avec ses propres observations valides", {
  d0 <- as.Date("2024-01-01")
  dg <- d0 + seq(0, 40, by = 10)
  o <- list(B4 = matrix(0.05, 2, 3), B5 = matrix(0.08, 2, 3), B6 = matrix(0.2, 2, 3),
            B8A = rbind(c(0.4, 0.5, 0.6), c(0.4, 0.5, 0.6)),
            B11 = matrix(0.25, 2, 3), B12 = matrix(0.15, 2, 3))
  o$B8A[2, 2] <- NA                          # pixel 2 : observation du milieu perdue
  X <- reconfort_caracteristiques_v3(o, d0 + c(0, 20, 40), dg)
  expect_equal(unname(X[1, "CRswir_2"]), cr_swir_ref(0.45))
  expect_equal(unname(X[2, "CRswir_2"]), cr_swir_ref(0.45))   # 0.4..0.6 sur 40 jours : meme droite
  expect_equal(unname(X[2, "CRswir_3"]), cr_swir_ref(0.5))
})

test_that("correction 'biais' retire les biais de la 092, jamais par defaut", {
  d0 <- as.Date("2024-01-01")
  dg <- d0 + seq(0, 40, by = 10)
  o <- obs_synth()
  X0 <- reconfort_caracteristiques_v3(o, d0 + c(0, 40), dg)
  Xb <- reconfort_caracteristiques_v3(o, d0 + c(0, 40), dg, correction = "biais")
  expect_equal(unname(X0[1, 1] - Xb[1, 1]), 0.011215741943559105)
  expect_equal(unname(X0[1, 6] - Xb[1, 6]), 0.025805809194198708)
})

test_that("ecriture des sorties : memes noms que la voie IOTA2, tags 'non valide'", {
  skip_if_not_installed("terra")
  g <- terra::rast(nrows = 2, ncols = 3, xmin = 0, xmax = 30, ymin = 0, ymax = 20, crs = "EPSG:2154")
  votes <- rbind(c(1000L, 0L, 0L), c(0L, 0L, 1000L), c(0L, 600L, 400L),
                 c(0L, 0L, 0L), c(500L, 500L, 0L), c(0L, 0L, 0L))
  d <- withr::local_tempdir()
  out <- .reconfort_sen2cor_ecrire(votes, g, NULL, 2025L, d)
  expect_setequal(basename(unlist(out[-1])), c(
    "Classif_Seed_0.tif", "Final_Classif_masked_2025.tif", "ProbabilityMap_seed_0.tif",
    "Final_Proba_map_masked2025.tif", "Final_continuous_score_masked2025.tif"))
  cl <- terra::values(terra::rast(out$classif), mat = FALSE)
  expect_equal(cl, c(1, 3, 2, 0, 1, 0))             # argmax, 0 = non predit
  pr <- terra::values(terra::rast(out$probability), mat = TRUE)
  expect_equal(unname(rowSums(pr)), c(1000, 1000, 1000, 0, 1000, 0))
  sc <- terra::values(terra::rast(out$continuous_score), mat = FALSE)
  expect_equal(sc[1:2], c(1, 100))                   # (1001 - 1000)/30 -> borne a 1 ; (1001 + 2000)/30 = 100
  expect_equal(sc[c(4, 6)], c(0, 0))
  tg <- terra::metags(terra::rast(out$classif_masked))
  # terra >= 1.8 rend un data.frame (name, value) ; avant, un vecteur nomme.
  if (is.data.frame(tg)) tg <- stats::setNames(tg$value, tg$name)
  expect_identical(unname(tg[["SOURCE_REFLECTANCES"]]), "sen2cor")
  expect_identical(unname(tg[["VALIDEE"]]), "FALSE")
})

test_that("repli : la voie suivante apres 'archive' est Sen2Cor, apres 'fenetre' rien (089)", {
  expect_identical(.reconfort_voie_suivante("archive"), "sen2cor")
  expect_true(is.na(.reconfort_voie_suivante("sen2cor")))
  # Mission 089 : le repli THEIA -> GEODES est branche.
  expect_identical(.reconfort_voie_suivante("fenetre"), "archive")
  testthat::local_mocked_bindings(.reconfort_repli_fenetre_archive = function() FALSE)
  expect_true(is.na(.reconfort_voie_suivante("fenetre")))
})

test_that("etiquettes de classe ecrites depuis les classes du modele, cache S2 par defaut", {
  skip_if_not_installed("terra")
  g <- terra::rast(nrows = 1, ncols = 2, xmin = 0, xmax = 20, ymin = 0, ymax = 10, crs = "EPSG:2154")
  d <- withr::local_tempdir()
  out <- .reconfort_sen2cor_ecrire(rbind(c(900L, 100L), c(100L, 900L)), g, NULL, 2025L, d,
                                   classes = c(5L, 9L))
  expect_equal(terra::values(terra::rast(out$classif), mat = FALSE), c(5, 9))
  p <- withr::local_tempdir()
  expect_identical(basename(.reconfort_s2_cache_defaut(p)), "s2_bands")
  dir.create(file.path(p, "layers", "sentinel2"), recursive = TRUE)
  expect_identical(basename(.reconfort_s2_cache_defaut(p)), "sentinel2")
  proj <- file.path(withr::local_tempdir(), "cache"); dir.create(proj)
  expect_identical(.reconfort_s2_cache_defaut(proj), file.path(proj, "layers", "sentinel2"))
})
