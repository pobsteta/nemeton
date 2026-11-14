# Tests de corriger_finn() et de la correction de croissance (spec 068, D-G
# option 1).

test_that(".itin_corriger scales the diameter increment of survivors only", {
  out <- data.frame(siteID = c(1L, 1L, 2L, 2L), species = c(1L, 2L, 1L, 1L),
                    dbh = c(22, 33, 12, 8), trees = 1)
  attr(out, "dbh_entree") <- c(20, 30, 10, NA)   # la 4e est une recrue
  corr <- list(bornes = c(0, 10, Inf),
               facteurs = matrix(c(0.5, 2, 1, 1.5), 2, 2,
                                 dimnames = list(NULL, c("feuillus", "resineux"))),
               resineux = c(FALSE, TRUE))
  r <- .itin_corriger(out, g0 = c(15, 5), correction = corr)
  # site 1 : classe 2 ; feuillu f = 2, resineux f = 1.5
  expect_equal(r$dbh[1:2], c(20 + 2 * 2, 30 + 1.5 * 3))
  # site 2 : classe 1, feuillu f = 0.5 ; la recrue reste telle quelle
  expect_equal(r$dbh[3:4], c(10 + 0.5 * 2, 8))
  # jamais de diametre qui baisse
  out$dbh[1] <- 19
  expect_equal(.itin_corriger(out, c(15, 5), corr)$dbh[1], 20)
  # sans attribut (pas simule par un faux) : rien ne change
  attr(out, "dbh_entree") <- NULL
  expect_identical(.itin_corriger(out, c(15, 5), corr), out)
})

test_that(".itin_pas_corrige leaves the step alone without a correction", {
  local_mocked_bindings(.itin_un_pas = function(m, coh, env1, sp, n_sp) {
    out <- transform(coh, dbh = dbh + 2)
    attr(out, "dbh_entree") <- coh$dbh
    out
  })
  coh <- data.frame(siteID = 1L, species = 1L, dbh = 20, trees = 3)
  env1 <- data.frame(siteID = 1L)
  expect_equal(.itin_pas_corrige(NULL, coh, env1, 0.1, 1L)$dbh, 22)
  corr <- list(bornes = c(0, Inf), facteurs = matrix(0.5, 1, 2), resineux = FALSE)
  expect_equal(.itin_pas_corrige(NULL, coh, env1, 0.1, 1L, corr)$dbh, 21)
})

test_that("corriger_finn checks its inputs", {
  faux <- structure(list(placettes = "P1", pas_annees = 5), class = "finn_calibration")
  a <- data.frame(placette = "P1", essence = "09", d1 = 20, d2 = 21, poids = 10,
                  statut = "vivant")
  e <- data.frame(placette = "P1", x = 1)
  expect_error(corriger_finn(list(), a, e), "calibrer_finn")
  expect_error(corriger_finn(faux, a, e, bornes = c(0, 10)), "bornes")
  expect_error(corriger_finn(faux, a, e, bornes = c(5, Inf)), "bornes")
  expect_error(corriger_finn(faux, a, e, iterations = 0), "iterations")
  expect_error(corriger_finn(faux, a, e), "used in the calibration")
})

test_that("corriger_finn fits factors that simuler_itineraire and predire_finn apply", {
  skip_on_cran()
  skip_if_not_installed("FINN")
  skip_if_not_installed("data.table")
  skip_if_not(torch::torch_is_installed(), "libtorch not installed")
  a <- arbres_finn_demo(); e <- env_finn_demo()
  cal <- calibrer_finn(a, e, epoques = 2L, min_arbres_essence = 1L)
  a2 <- a; a2$placette <- sub("P", "Q", a2$placette)
  e2 <- e; e2$placette <- sub("P", "Q", e2$placette)
  # placettes coupees ecartees : on retire les coupes du jeu de demo
  a2 <- a2[a2$statut != "coupe", ]
  cal2 <- corriger_finn(cal, a2, e2, bornes = c(0, Inf), n_tirages = 1L,
                        min_placettes = 1L)
  co <- cal2$correction
  expect_equal(dim(co$facteurs), c(1L, 2L))
  expect_true(all(co$facteurs >= 0.25 & co$facteurs <= 4))
  expect_equal(nrow(co$suivi), 2L * 2L)
  expect_equal(length(co$resineux), length(cal$essences))
  expect_null(cal2$conforme)
  p1 <- predire_finn(cal2, a, e, n_tirages = 1L)
  expect_true(all(is.finite(p1$g_predite)))
  s <- simuler_itineraire(cal2, a, e, horizon = 10, n_tirages = 1L)
  s0 <- simuler_itineraire(cal2, a, e, horizon = 10, n_tirages = 1L, correction = FALSE)
  expect_equal(dim(s), dim(s0))
  # une correction forte (x 4 partout) fait croitre G plus vite que sans
  cal3 <- cal2; cal3$correction$facteurs[] <- 4
  set.seed(3); g4 <- simuler_itineraire(cal3, a, e, horizon = 5, n_tirages = 3L)
  set.seed(3); g1 <- simuler_itineraire(cal3, a, e, horizon = 5, n_tirages = 3L,
                                        correction = FALSE)
  m4 <- mean(g4$moyenne[g4$variable == "g" & g4$annee == 5])
  m1 <- mean(g1$moyenne[g1$variable == "g" & g1$annee == 5])
  expect_gt(m4, m1)
})
