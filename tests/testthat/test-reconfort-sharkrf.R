# Lecteur et predicteur SharkRF (mission 095), sur un modele fabrique de 3 arbres
# dont les votes sont ecrits a la main.

# Trois arbres, deux variables, trois classes (1, 2, 3 ; feuilles 0-based) :
#   A : x0 <= 0.5 -> classe 0, sinon classe 2
#   B : x1 <= 0.5 -> classe 1, sinon classe 2
#   C : x0 <= 0.3 -> classe 0, sinon classe 1
ecrire_modele_synth <- function(path = tempfile(fileext = ".txt")) {
  arbre <- function(k, attr, seuil, classes) {
    c(sprintf("%d 3 0 0 0 %d %s 1 2 0 0 0 0 0 0 0 1", k, attr, seuil),
      sprintf("%d 2 %d %d", k, classes[1], classes[2]),
      sprintf("%d 1 0 3 3", k))
  }
  writeLines(c("#RFClassifier with_dictionary", "3 1 2 3 ",
               "22 serialization::archive 18 0 0 3 0 0 1 0",
               arbre(0, 0, "5.0e-01", c(0, 2)),
               arbre(1, 1, "5.0e-01", c(1, 2)),
               arbre(2, 0, "3.0e-01", c(0, 1))), path)
  path
}

test_that("lecteur SharkRF : structure du modele fabrique", {
  m <- reconfort_sharkrf_lire(ecrire_modele_synth())
  expect_s3_class(m, "reconfort_sharkrf")
  expect_equal(m$n_arbres, 3L)
  expect_equal(m$n_vars, 2L)
  expect_equal(m$classes, 1:3)
  expect_equal(length(m$attr), 9L)
  expect_equal(m$racines, c(1L, 4L, 7L))
})

test_that("predicteur SharkRF : votes ecrits a la main, Rust et repli R identiques", {
  m <- reconfort_sharkrf_lire(ecrire_modele_synth())
  x <- rbind(c(0.2, 0.9), c(0.9, 0.1), c(0.4, 0.4), c(NA, 0.1))
  attendu <- rbind(c(2L, 0L, 1L), c(0L, 2L, 1L), c(1L, 2L, 0L), c(-1L, -1L, -1L))
  expect_identical(reconfort_sharkrf_predire(m, x), attendu)
  withr::local_options(nemeton.rust = FALSE)
  expect_identical(reconfort_sharkrf_predire(m, x), attendu)
  # blocs plus petits que le jeu de lignes : meme resultat
  expect_identical(reconfort_sharkrf_predire(m, x, bloc = 1L), attendu)
  # les votes de chaque ligne predictible somment au nombre d'arbres
  expect_true(all(rowSums(attendu[1:3, ]) == m$n_arbres))
})

test_that("predicteur SharkRF : colonnes manquantes refusees", {
  m <- reconfort_sharkrf_lire(ecrire_modele_synth())
  expect_error(reconfort_sharkrf_predire(m, matrix(0.1, 2, 1)), "needs")
})

test_that("lecteur SharkRF : un fichier qui n'est pas un modele donne une erreur de classe", {
  f <- tempfile(); writeLines(c("pas un modele", "x", "y"), f)
  expect_error(reconfort_sharkrf_lire(f), class = "nemeton_sharkrf_format")
  g <- tempfile(); writeLines(readLines(ecrire_modele_synth())[1:5], g)
  expect_error(reconfort_sharkrf_lire(g), class = "nemeton_sharkrf_format")
})

test_that("lecteur SharkRF : cache memoire et cache disque", {
  f <- ecrire_modele_synth()
  d <- withr::local_tempdir()
  m1 <- reconfort_sharkrf_lire(f, cache_dir = d)
  expect_length(list.files(d, pattern = "^sharkrf_v1_.*\\.rds$"), 1L)
  expect_identical(reconfort_sharkrf_lire(f), m1)
  # relecture depuis le disque apres vidage de la memoire
  rm(list = ls(.reconfort_sharkrf_cache), envir = .reconfort_sharkrf_cache)
  m2 <- reconfort_sharkrf_lire(f, cache_dir = d)
  expect_equal(m2$attr, m1$attr)
})

test_that("le vrai modele v3, s'il est en cache, a 1000 arbres et 134 variables", {
  p <- file.path(get_global_cache_dir(), "reconfort_models", "v3", "model_1_seed_0.txt")
  skip_if_not(file.exists(p), "modele v3 absent du cache")
  skip_on_cran()
  m <- reconfort_sharkrf_lire(p, cache_dir = withr::local_tempdir())
  expect_equal(m$n_arbres, 1000L)
  expect_equal(m$n_vars, 134L)
  v <- reconfort_sharkrf_predire(m, matrix(0.8, 1, 134))
  expect_equal(sum(v), 1000L)
})
