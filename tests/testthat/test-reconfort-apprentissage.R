# Apprentissage RECONFORT (spike) : ranger + validation croisee spatiale par
# blocs, comparaison a la carte amont. Jeux `synth_` uniquement.

synth_modele <- function() {
  pl <- synth_reconfort_placettes()
  et <- reconfort_etiquettes(pl)
  se <- synth_reconfort_serie(pl)
  list(pl = pl, et = et, se = se,
       m = reconfort_entrainer(se, et, k = 4L, taille_bloc = 1000, seed = 11L,
                               num_arbres = 100L))
}

test_that("les jeux d'essai sont marques synthetiques", {
  pl <- synth_reconfort_placettes()
  expect_true(all(pl$synthetic))
  expect_true(all(startsWith(pl$id_unique, "synth_")))
})

test_that("reconfort_entrainer rend modele, confusion, precision et seed", {
  skip_if_not_installed("ranger")
  s <- synth_modele()
  m <- s$m
  expect_s3_class(m, "reconfort_modele")
  expect_s3_class(m$modele, "ranger")
  expect_equal(m$seed, 11L)
  expect_equal(dim(m$confusion), c(3L, 3L))
  expect_equal(sum(m$confusion), nrow(m$plis))
  expect_equal(m$precision, sum(diag(m$confusion)) / sum(m$confusion))
  expect_true(m$precision >= 0 && m$precision <= 1)
  # le signal synthetique (B11 selon la classe) est net : bien au-dessus du hasard (1/3)
  expect_gt(m$precision, 0.6)
  expect_length(m$variables, 72L)
  expect_output(print(m), "Precision globale")
})

test_that("cas 5 : aucun id_unique, aucun bloc, dans l'apprentissage et le test d'un meme pli", {
  skip_if_not_installed("ranger")
  p <- synth_modele()$m$plis
  for (f in unique(p$pli)) {
    test <- p[p$pli == f, ]
    appr <- p[p$pli != f, ]
    expect_length(intersect(test$id_unique, appr$id_unique), 0L)
    expect_length(intersect(test$bloc, appr$bloc), 0L)
  }
  # chaque ligne est predite une fois
  expect_false(anyNA(p$predit))
  expect_equal(nrow(p), nrow(unique(p[c("id_unique", "annee")])))
})

test_that("reproductible : meme seed, memes plis et memes predictions", {
  skip_if_not_installed("ranger")
  pl <- synth_reconfort_placettes()
  et <- reconfort_etiquettes(pl)
  se <- synth_reconfort_serie(pl)
  a <- reconfort_entrainer(se, et, k = 4L, seed = 3L, num_arbres = 50L)
  b <- reconfort_entrainer(se, et, k = 4L, seed = 3L, num_arbres = 50L)
  expect_identical(a$plis, b$plis)
  expect_identical(a$confusion, b$confusion)
})

test_that("trop peu de blocs : erreur ; k reduit : avertissement", {
  skip_if_not_installed("ranger")
  pl <- synth_reconfort_placettes()
  et <- reconfort_etiquettes(pl)
  se <- synth_reconfort_serie(pl)
  expect_error(reconfort_entrainer(se, et, taille_bloc = 1e7), "at least 2 blocks")
  expect_warning(reconfort_entrainer(se, et, k = 50L, num_arbres = 20L), "reduced")
  expect_error(reconfort_entrainer(se, et[names(et) != "x"]), "reconfort_etiquettes")
})

test_that("une placette sans serie est ecartee avec un avertissement", {
  skip_if_not_installed("ranger")
  pl <- synth_reconfort_placettes()
  et <- reconfort_etiquettes(pl)
  se <- synth_reconfort_serie(pl)
  se <- se[se$id_unique != "synth_001", ]
  expect_warning(m <- reconfort_entrainer(se, et, k = 4L, num_arbres = 20L), "dropped")
  expect_false("synth_001" %in% m$plis$id_unique)
})

test_that("reconfort_predire rend une classe par (id, annee)", {
  skip_if_not_installed("ranger")
  s <- synth_modele()
  cib <- data.frame(id_unique = c("synth_001", "synth_002", "absent"), annee = 2022L)
  p <- reconfort_predire(s$m, s$se, cib)
  expect_equal(p$id_unique, cib$id_unique)
  expect_true(all(p$classe[1:2] %in% 1:3))
  expect_true(is.na(p$classe[3]))
  expect_error(reconfort_predire("x", s$se, cib), "reconfort_modele")
})

test_that("reconfort_comparer_amont : accord pixel a pixel et sur placettes de terrain", {
  mk <- function(v) terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 4, ymin = 0,
                                ymax = 4, crs = "EPSG:2154", vals = v)
  carte <- mk(c(1, 2, 3, 1))
  amont <- mk(c(1, 2, 2, NA))
  r <- reconfort_comparer_amont(carte, amont)
  expect_equal(r$n, 3L)
  expect_equal(r$accord, 2 / 3)
  expect_equal(r$confusion["3", "2"], 1L)

  pts <- data.frame(x = c(1, 3, 1), y = c(3, 3, 1), dep_cor = c(1L, 2L, 3L))
  rt <- reconfort_comparer_amont(carte, amont, placettes = pts)
  expect_equal(rt$terrain$n, 3L)
  expect_equal(rt$terrain$accord_carte, 1)             # 1, 2, 3 = terrain
  expect_equal(rt$terrain$accord_amont, 2 / 3)       # 1 et 2 justes, 3 lu 2
})

test_that("reconfort_comparer_amont rase l'amont sur la grille de la carte (fichiers)", {
  dir <- withr::local_tempdir()
  carte <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 4, ymin = 0, ymax = 4,
                       crs = "EPSG:2154", vals = c(1, 2, 3, 1))
  fin <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 4,
                     crs = "EPSG:2154", vals = rep(c(1, 1, 2, 2, 1, 1, 2, 2, 3, 3, 1, 1, 3, 3, 1, 1), 1))
  f1 <- file.path(dir, "synth_carte.tif"); f2 <- file.path(dir, "synth_amont.tif")
  terra::writeRaster(carte, f1); terra::writeRaster(fin, f2)
  r <- reconfort_comparer_amont(f1, f2)
  expect_equal(r$n, 4L)
  expect_gte(r$accord, 0)
  expect_error(reconfort_comparer_amont(1, 2), "SpatRaster")
})
