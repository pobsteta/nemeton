# Tests de corriger_finn() et de la correction de croissance (spec 068, D-G
# option 1).

test_that(".itin_corriger scales survivors' growth and recruits' stems", {
  out <- data.frame(siteID = c(1L, 1L, 2L, 2L), species = c(1L, 2L, 1L, 1L),
                    dbh = c(22, 33, 12, 8), trees = c(1, 1, 1, 10))
  attr(out, "dbh_entree") <- c(20, 30, 10, NA)   # la 4e est une recrue
  attr(out, "morts") <- out[0, ]
  corr <- list(grille = c(0, 20),
               croissance = matrix(c(0.5, 2, 1, 1.5), 2, 2,
                                   dimnames = list(NULL, c("feuillus", "resineux"))),
               recrutement = matrix(c(0.5, 0.5, 1, 1), 2, 2),
               resineux = c(FALSE, TRUE))
  r <- .itin_corriger(out, g0 = c(20, 10), correction = corr)
  # site 1 (G 20) : feuillu f = 2, resineux f = 1.5
  expect_equal(r$dbh[1:2], c(20 + 2 * 2, 30 + 1.5 * 3))
  # site 2 (G 10, interpole) : feuillu f = 1.25 ; la recrue garde son diametre
  expect_equal(r$dbh[3:4], c(10 + 1.25 * 2, 8))
  # recrues : 10 tiges x 0.5 = 5, entier
  expect_equal(r$trees[4], 5)
  expect_equal(attr(r, "dbh_entree"), c(20, 30, 10, NA))
  # au-dela de la grille : valeur du bout
  expect_equal(.itin_corriger(out, c(50, 50), corr)$dbh[1], 24)
  # jamais de diametre qui baisse
  out$dbh[1] <- 19
  expect_equal(.itin_corriger(out, c(20, 10), corr)$dbh[1], 20)
  # sans attribut (pas simule par un faux) : rien ne change
  attr(out, "dbh_entree") <- NULL
  expect_identical(.itin_corriger(out, c(20, 10), corr), out)
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
  corr <- list(grille = c(0, 50), croissance = matrix(0.5, 2, 2), resineux = FALSE)
  expect_equal(.itin_pas_corrige(NULL, coh, env1, 0.1, 1L, corr)$dbh, 21)
})

test_that("corriger_finn checks its inputs", {
  faux <- structure(list(placettes = "P1", pas_annees = 5), class = "finn_calibration")
  a <- data.frame(placette = "P1", essence = "09", d1 = 20, d2 = 21, poids = 10,
                  statut = "vivant")
  e <- data.frame(placette = "P1", x = 1)
  expect_error(corriger_finn(list(), a, e), "calibrer_finn")
  expect_error(corriger_finn(faux, a, e, grille = 5), "grille")
  expect_error(corriger_finn(faux, a, e, grille = c(10, 5)), "grille")
  expect_error(corriger_finn(faux, a, e, largeur = 0), "largeur")
  expect_error(corriger_finn(faux, a, e, iterations = 0), "iterations")
  expect_error(corriger_finn(faux, a, e), "used in the calibration")
})

test_that("corriger_finn fits the factors with a stand-in FINN step", {
  # pas FINN factice : +1 cm a chaque cohorte, une recrue feuillue par site.
  # Les observations : +2 cm et deux fois plus de recrues -> facteurs ~ 2.
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) {
      recr <- data.frame(siteID = sort(unique(coh$siteID)), species = 1L,
                         dbh = 8, trees = 1)
      out <- rbind(transform(coh, dbh = dbh + 1), recr)
      attr(out, "dbh_entree") <- c(coh$dbh, rep(NA_real_, nrow(recr)))
      attr(out, "morts") <- coh[0, ]
      out
    }
  )
  n <- 40L
  pla <- sprintf("P%02d", seq_len(n))
  d1 <- rep(15 + seq_len(n) / 2, each = 3) + rep(0:2, n)
  arbres <- rbind(
    data.frame(placette = rep(pla, each = 3), essence = "09", d1 = d1,
               d2 = d1 + 2, poids = 10, statut = "vivant"),
    data.frame(placette = pla, essence = "09", d1 = NA_real_, d2 = 8,
               poids = 20, statut = "recrute"),
    # une placette coupee est ecartee
    data.frame(placette = "PX", essence = "09", d1 = 30, d2 = NA_real_,
               poids = 10, statut = "coupe")
  )
  env <- data.frame(placette = c(pla, "PX"), x = 1)
  calib <- structure(list(essences = c("09", "61"), variables_env = "x",
                          surface_placette = 0.1, placettes = character(),
                          modele = list(eval = function() NULL),
                          conforme = list(demi_largeur = 1)),
                     class = "finn_calibration")
  expect_message(
    r <- corriger_finn(calib, arbres, env, n_tirages = 1L, min_placettes = 5L),
    "conformer_finn"
  )
  co <- r$correction
  expect_null(r$conforme)
  expect_equal(co$n_placettes, n)
  expect_false("PX" %in% co$placettes)
  expect_equal(co$resineux, c(FALSE, TRUE))
  # feuillus : pres de 2 la ou il y a des placettes, tenu au-dela
  expect_equal(unname(co$croissance[, "feuillus"]), rep(2, length(co$grille)),
               tolerance = 0.02)
  expect_equal(unname(co$recrutement[, "feuillus"]), rep(2, length(co$grille)),
               tolerance = 0.02)
  # aucun resineux : facteurs a 1, effectif nul
  expect_true(all(co$croissance[, "resineux"] == 1))
  expect_true(all(co$recrutement[, "resineux"] == 1))
  expect_true(all(co$n_effectif[, "resineux"] == 0))
  expect_equal(.finn_facteur(co$croissance, co$grille, c(1, 100),
                             c("feuillus", "resineux")),
               c(co$croissance[1, "feuillus"], 1), tolerance = 0.02)
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
  cal2 <- corriger_finn(cal, a2, e2, grille = c(0, 20, 40), n_tirages = 1L,
                        min_placettes = 1L)
  co <- cal2$correction
  expect_equal(dim(co$croissance), c(3L, 2L))
  expect_equal(dim(co$recrutement), c(3L, 2L))
  expect_true(all(co$croissance >= 0.25 & co$croissance <= 4))
  expect_equal(length(co$resineux), length(cal$essences))
  # placettes de calibration : refusees sauf demande explicite
  expect_error(corriger_finn(cal, a, e), "placettes_calibration")
  cal_c <- corriger_finn(cal, a[a$statut != "coupe", ], e, placettes_calibration = TRUE,
                         n_tirages = 1L, iterations = 1L, min_placettes = 1L)
  expect_true(all(is.finite(cal_c$correction$croissance)))
  expect_null(cal2$conforme)
  p1 <- predire_finn(cal2, a, e, n_tirages = 1L)
  expect_true(all(is.finite(p1$g_predite)))
  s <- simuler_itineraire(cal2, a, e, horizon = 10, n_tirages = 1L)
  s0 <- simuler_itineraire(cal2, a, e, horizon = 10, n_tirages = 1L, correction = FALSE)
  expect_equal(dim(s), dim(s0))
  # une correction forte (x 4 partout) fait croitre G plus vite que sans
  cal3 <- cal2; cal3$correction$croissance[] <- 4
  set.seed(3); g4 <- simuler_itineraire(cal3, a, e, horizon = 5, n_tirages = 3L)
  set.seed(3); g1 <- simuler_itineraire(cal3, a, e, horizon = 5, n_tirages = 3L,
                                        correction = FALSE)
  m4 <- mean(g4$moyenne[g4$variable == "g" & g4$annee == 5])
  m1 <- mean(g1$moyenne[g1$variable == "g" & g1$annee == 5])
  expect_gt(m4, m1)
})
