# Tests de simuler_itineraire() / conformer_finn() (spec 068, etape 3).
# Les regles et la coupe sont en R de base : testees sans FINN. Le passage par
# FINN n'est teste que si FINN et libtorch sont installes.

itin_demo <- function(...) {
  list(code = "demo", statut_source = "source", sources = list("test"),
       regles = utils::modifyList(list(rotation_ans = 10, diametre_exploitabilite_cm = NULL,
                                       surface_terriere_cible_m2ha = NULL,
                                       intensite_prelevement_pct = NULL), list(...)))
}

test_that(".itin_regles accepts no management and checks the itinerary", {
  expect_null(nemeton:::.itin_regles(NULL, 5))
  r <- nemeton:::.itin_regles(itin_demo(surface_terriere_cible_m2ha = 20), 5)
  expect_equal(r$cible, 20)
  expect_equal(r$rotation_ans, 10)
  a_sourcer <- itin_demo(intensite_prelevement_pct = 30)
  a_sourcer$statut_source <- "a_sourcer"
  expect_error(nemeton:::.itin_regles(a_sourcer, 5), "not sourced")
  expect_error(nemeton:::.itin_regles(itin_demo(), 5), "no cutting rule")
  expect_error(nemeton:::.itin_regles(itin_demo(rotation_ans = 7, intensite_prelevement_pct = 30), 5),
               "multiple")
  expect_error(nemeton:::.itin_regles(itin_demo(rotation_ans = NULL, intensite_prelevement_pct = 30), 5),
               "rotation_ans")
  expect_error(nemeton:::.itin_regles(itin_demo(intensite_prelevement_pct = 150), 5), "intensite")
  expect_error(nemeton:::.itin_regles(list(a = 1), 5), "itineraires_catalogue")
})

test_that("the shipped catalogue, not yet sourced, is refused", {
  cat <- itineraires_catalogue()
  expect_error(nemeton:::.itin_regles(cat[[1]], 5), "not sourced")
})

test_that(".itin_couper harvests above the diameter and thins towards the target", {
  coh <- data.frame(siteID = c(1L, 1L, 2L, 2L), species = 1L,
                    dbh = c(30, 70, 30, 30), trees = c(100, 10, 100, 100))
  set.seed(1)
  # exploitabilite : la cohorte de 70 cm disparait
  c1 <- nemeton:::.itin_couper(coh, list(diametre = 60), 2L, 1)
  expect_false(any(c1$dbh >= 60))
  expect_equal(sum(c1$trees), 300)
  # cible : seul le site au-dessus est eclairci, vers la cible
  g <- nemeton:::.itin_etat(coh, 2L, 1)$g
  cible <- mean(g)
  c2 <- nemeton:::.itin_couper(coh, list(cible = cible), 2L, 1)
  g2 <- nemeton:::.itin_etat(c2, 2L, 1)$g
  expect_equal(g2[g < cible], g[g < cible])
  expect_lt(abs(g2[g > cible] - cible), 0.15 * cible)
  # intensite plafonne la part retiree
  c3 <- nemeton:::.itin_couper(coh, list(cible = 0, intensite = 10), 2L, 1)
  expect_gt(sum(c3$trees), 0.8 * sum(coh$trees))
  # tirage binomial : une cohorte d'une tige peut etre coupee
  un <- data.frame(siteID = 1L, species = 1L, dbh = 50, trees = rep(1, 200))
  c4 <- nemeton:::.itin_couper(un, list(intensite = 50), 1L, 1)
  expect_true(nrow(c4) > 50 && nrow(c4) < 150)
})

test_that(".finn_g_observee sums living and recruited trees at the second visit", {
  a <- data.frame(placette = c("A", "A", "A", "B"), poids = 10, d2 = c(20, NA, 10, 30),
                  statut = c("vivant", "mort", "recrute", "coupe"))
  g <- nemeton:::.finn_g_observee(a)
  expect_equal(unname(g["A"]), 10 * pi * (0.1^2 + 0.05^2))
  expect_equal(unname(g["B"]), 0)
})

test_that("simuler_itineraire and conformer_finn check their inputs", {
  faux <- structure(list(placettes = "P1", pas_annees = 5), class = "finn_calibration")
  a <- data.frame(placette = "P1", essence = "09", d1 = 20, d2 = 21, poids = 10,
                  statut = "vivant")
  e <- data.frame(placette = "P1", x = 1)
  expect_error(conformer_finn(list(), a, e), "calibrer_finn")
  expect_error(conformer_finn(faux, a, e, niveau = 1), "niveau")
  expect_error(conformer_finn(faux, a, e), "used in the calibration")
  expect_error(simuler_itineraire(list(), a, e), "calibrer_finn")
  expect_error(simuler_itineraire(faux, a, e, horizon = 12), "multiple")
  expect_error(simuler_itineraire(faux, a, e, itineraire = itineraires_catalogue()[[1]]),
               "not sourced")
})

test_that("simuler_itineraire runs end to end with FINN", {
  skip_on_cran()
  skip_if_not_installed("FINN")
  skip_if_not_installed("data.table")
  skip_if_not(torch::torch_is_installed(), "libtorch not installed")
  a <- arbres_finn_demo(); e <- env_finn_demo()
  cal <- calibrer_finn(a, e, epoques = 2L, min_arbres_essence = 1L)
  expect_equal(cal$placettes, paste0("P", 1:6))
  s <- simuler_itineraire(cal, a, e, horizon = 15, n_tirages = 2L)
  expect_equal(nrow(s), 6 * 4 * 3)
  expect_setequal(unique(s$variable), c("g", "tiges", "g_prelevee"))
  expect_true(all(s$intervalle == "aucun"))
  expect_true(all(s$moyenne[s$variable == "g_prelevee"] == 0))
  # conforme sur d'autres placettes (renommees), puis intervalle elargi
  a2 <- a; a2$placette <- sub("P", "Q", a2$placette)
  e2 <- e; e2$placette <- sub("P", "Q", e2$placette)
  a3 <- do.call(rbind, lapply(1:6, function(i) transform(a2, placette = paste0(placette, "_", i))))
  e3 <- do.call(rbind, lapply(1:6, function(i) transform(e2, placette = paste0(placette, "_", i))))
  cal2 <- conformer_finn(cal, a3, e3, n_tirages = 1L)
  expect_true(cal2$conforme$demi_largeur >= 0)
  it <- itin_demo(rotation_ans = 5, intensite_prelevement_pct = 50)
  s2 <- simuler_itineraire(cal2, a, e, itineraire = it, horizon = 15, n_tirages = 2L)
  g <- s2[s2$variable == "g" & s2$annee > 0, ]
  expect_equal(unique(g$intervalle[g$annee == 5]), "conforme")
  expect_equal(unique(g$intervalle[g$annee == 15]), "conforme_racine")
  expect_true(all(g$bas <= g$moyenne & g$moyenne <= g$haut))
  expect_true(any(s2$moyenne[s2$variable == "g_prelevee"] > 0))
})

# Sans FINN : le pas FINN est remplace par une croissance fixe (+1 cm), pour
# tester la boucle, les coupes et l'intervalle.
calibration_factice <- function(conforme = NULL) {
  structure(list(modele = list(eval = function() invisible(NULL)),
                 essences = c("09", "other"), variables_env = c("tx_ete", "rr_an"),
                 surface_placette = 0.7, pas_annees = 5, placettes = paste0("P", 1:6),
                 conforme = conforme), class = "finn_calibration")
}

test_that("simuler_itineraire loops over steps and applies the cuts (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 1)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo()
  s <- simuler_itineraire(calibration_factice(), a, e, horizon = 20, n_tirages = 2L)
  g <- s[s$variable == "g", ]
  expect_equal(sort(unique(g$annee)), c(0, 5, 10, 15, 20))
  # croissance seule : G augmente a chaque pas, rien n'est preleve
  croit <- tapply(g$moyenne, g$placette, function(v) all(diff(v) > 0))
  expect_true(all(croit))
  expect_true(all(s$moyenne[s$variable == "g_prelevee"] == 0))
  expect_true(all(is.na(g$bas)))

  # coupe rase tous les 10 ans (diametre 0) : tout part a l'annee 10, pas a 20
  it <- itin_demo(diametre_exploitabilite_cm = 0)
  s2 <- simuler_itineraire(calibration_factice(), a, e, itineraire = it, horizon = 20,
                           n_tirages = 1L)
  p <- s2[s2$variable == "g_prelevee", ]
  g2 <- s2[s2$variable == "g", ]
  expect_true(all(p$moyenne[p$annee == 10] > 0))
  expect_true(all(p$moyenne[p$annee %in% c(5, 15, 20)] == 0))
  expect_equal(p$moyenne[p$annee == 10], g2$moyenne[g2$annee == 10])
  expect_true(all(g2$moyenne[g2$annee == 15] == 0))
  expect_equal(unique(s2$itineraire), "demo")

  # intervalle conforme : racine puis lineaire, borne basse a 0
  conf <- list(niveau = 0.9, demi_largeur = 2, n_placettes = 100, pas_annees = 5)
  s3 <- simuler_itineraire(calibration_factice(conf), a, e, horizon = 15, n_tirages = 1L)
  g3 <- s3[s3$variable == "g" & s3$annee > 0, ]
  expect_equal(g3$haut - g3$moyenne, 2 * sqrt(g3$annee / 5))
  expect_true(all(g3$bas >= 0))
  expect_equal(unique(g3$intervalle[g3$annee == 5]), "conforme")
  s4 <- simuler_itineraire(calibration_factice(conf), a, e, horizon = 15, n_tirages = 1L,
                           elargissement = "lineaire")
  g4 <- s4[s4$variable == "g" & s4$annee > 0, ]
  expect_equal(g4$haut - g4$moyenne, 2 * g4$annee / 5)
  expect_equal(unique(g4$intervalle[g4$annee == 15]), "conforme_lineaire")
})

test_that("conformer_finn takes the residual quantile (predire_finn mocked)", {
  pla <- paste0("Q", 1:40)
  a <- data.frame(placette = pla, essence = "09", d1 = 20, d2 = 20, poids = 100,
                  statut = "vivant")
  g_obs <- 100 * pi * 0.1^2
  local_mocked_bindings(predire_finn = function(calibration, arbres, environnement, ...) {
    data.frame(placette = pla, g_predite = g_obs + seq_along(pla) / 10)
  })
  cal <- conformer_finn(calibration_factice(), a, data.frame(placette = pla, x = 1))
  expect_equal(cal$conforme$n_placettes, 40)
  expect_equal(cal$conforme$residus, seq_along(pla) / 10)
  expect_null(cal$conforme$x)
  xy <- data.frame(placette = pla, x = seq_along(pla), y = 0)
  cal2 <- conformer_finn(calibration_factice(), a, data.frame(placette = pla, x = 1),
                         coordonnees = xy)
  expect_equal(cal2$conforme$x, seq_along(pla))
  expect_error(conformer_finn(calibration_factice(), a, data.frame(placette = pla, x = 1),
                              coordonnees = xy[-1, ]), "every plot")
  expect_error(conformer_finn(calibration_factice(), a, data.frame(placette = pla, x = 1),
                              coordonnees = xy[, 1:2]), "lacks")
  expect_equal(cal$conforme$demi_largeur,
               unname(stats::quantile((1:40) / 10, 0.9 * (1 + 1 / 40))))
  expect_error(conformer_finn(calibration_factice(), a[1:10, ], data.frame(placette = pla, x = 1)),
               "at least 30")
})

test_that(".finn_demi_largeur averages residuals over groups of k plots", {
  set.seed(5)
  n <- 300
  conf <- list(niveau = 0.9, demi_largeur = 4, residus = rnorm(n, 0.5, 3),
               x = runif(n, 0, 1e5), y = runif(n, 0, 1e5))
  expect_equal(nemeton:::.finn_demi_largeur(conf, 1L), list(q = 4, groupes = "placette"))
  v <- nemeton:::.finn_demi_largeur(conf, 4L)
  expect_equal(v$groupes, "voisins")
  expect_lt(v$q, quantile(abs(conf$residus), 0.9))
  # sans coordonnees : groupes au hasard, reproductibles, RNG global intact
  conf$x <- conf$y <- NULL
  set.seed(1); avant <- runif(1); set.seed(1)
  h <- nemeton:::.finn_demi_largeur(conf, 4L)
  expect_equal(runif(1), avant)
  expect_equal(h$groupes, "hasard")
  expect_equal(nemeton:::.finn_demi_largeur(conf, 4L)$q, h$q)
  expect_error(nemeton:::.finn_demi_largeur(conf, 20L), "at least 600")
  expect_error(nemeton:::.finn_demi_largeur(list(demi_largeur = 1), 2L), "conformer_finn")
})

test_that("simuler_itineraire aggregates plots into units (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 1)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo()
  set.seed(2)
  conf <- list(niveau = 0.9, demi_largeur = 4, n_placettes = 200, pas_annees = 5,
               residus = rnorm(200), x = runif(200, 0, 1e5), y = runif(200, 0, 1e5))
  u <- data.frame(placette = paste0("P", 1:6), unite = c("U1", "U1", "U1", "U2", "U2", "U3"))
  s <- simuler_itineraire(calibration_factice(conf), a, e, horizon = 10, n_tirages = 1L,
                          unites = u)
  expect_true(all(c("unite", "n_placettes", "groupes_conformes") %in% names(s)))
  expect_false("placette" %in% names(s))
  expect_equal(nrow(s), 3 * 3 * 3)
  g5 <- s[s$variable == "g" & s$annee == 5, ]
  expect_equal(g5$n_placettes[g5$unite == "U1"], 3L)
  expect_equal(g5$groupes_conformes[g5$unite == "U3"], "placette")
  expect_equal(g5$groupes_conformes[g5$unite == "U1"], "voisins")
  # la moyenne de l'unite est celle de ses placettes
  p <- simuler_itineraire(calibration_factice(conf), a, e, horizon = 10, n_tirages = 1L)
  gp <- p[p$variable == "g" & p$annee == 0, ]
  g0 <- s[s$variable == "g" & s$annee == 0, ]
  expect_equal(g0$moyenne[g0$unite == "U2"], mean(gp$moyenne[gp$placette %in% c("P4", "P5")]))
  # demi-largeur d'une unite de 3 placettes : celle des groupes de 3
  h <- g5$haut - g5$moyenne
  expect_equal(h[g5$unite == "U1"], nemeton:::.finn_demi_largeur(conf, 3L)$q)
  expect_equal(h[g5$unite == "U3"], 4)
  expect_error(simuler_itineraire(calibration_factice(conf), a, e, horizon = 10,
                                  unites = u[1:5, ]), "without a unit")
  expect_error(simuler_itineraire(calibration_factice(conf), a, e, horizon = 10,
                                  unites = rbind(u, u[1, ])), "one unit only")
  expect_error(simuler_itineraire(calibration_factice(conf), a, e, unites = u["placette"]),
               "unite")
})

test_that(".itin_tarifs gives an IFN tariff per plot and species, other = dominant", {
  a <- arbres_finn_demo(); e <- env_finn_demo()
  e$ser <- c("C20", "C20", "C20", NA, NA, NA)
  a$d2 <- NA_real_
  prep <- nemeton:::.finn_preparer(a, e, 0.7, essences = c("09", "03", "other"),
                                   observations = FALSE)
  tar <- nemeton:::.itin_tarifs(a, e, prep, c("09", "03", "other"))
  expect_equal(dim(tar$numero), c(6L, 3L))
  ref <- ifn_tarif_schaeffer_reference("09", ser = "C20")
  expect_equal(tar$numero[1, 1], ref$numero[ref$type == ref$type_conseille[1]])
  expect_equal(tar$type[1, 1], ref$type_conseille[1])
  ref_fr <- ifn_tarif_schaeffer_reference("09")
  expect_equal(tar$numero[4, 1], ref_fr$numero[ref_fr$type == ref_fr$type_conseille[1]])
  # "other" : 62 et 51, une tige chacune de meme poids ; la dominante en G
  a0 <- a[a$placette == "P1" & a$essence %in% c("62", "51") & a$statut != "recrute", ]
  dom <- a0$essence[which.max(a0$d1)]
  r_dom <- ifn_tarif_schaeffer_reference(dom, ser = "C20")
  expect_equal(tar$numero[1, 3], r_dom$numero[r_dom$type == r_dom$type_conseille[1]])
  expect_true(all(is.finite(tar$numero)))
})

test_that(".itin_etat computes the merchantable volume, zero below 7.5 cm", {
  tar <- list(numero = matrix(c(10, 12), 1), type = matrix(c("SCHL", "SCHR"), 1))
  coh <- data.frame(siteID = 1L, species = c(1L, 2L, 1L), dbh = c(30, 40, 5),
                    trees = c(7, 7, 100))
  et <- nemeton:::.itin_etat(coh, 2L, 0.7, tar)
  v <- (7 * volume_tarif_schaeffer(10, 30, "SCHL") + 7 * volume_tarif_schaeffer(12, 40, "SCHR")) / 0.7
  expect_equal(et$v, c(v, 0))
  # un tarif manquant donne NA, pas 0
  tar$numero[1, 2] <- NA
  expect_true(is.na(nemeton:::.itin_etat(coh, 2L, 0.7, tar)$v[1]))
})

test_that("simuler_itineraire adds volume and harvested volume (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 1)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo(); e$ser <- "C20"
  it <- itin_demo(diametre_exploitabilite_cm = 0)
  s <- simuler_itineraire(calibration_factice(), a, e, itineraire = it, horizon = 20,
                          n_tirages = 1L, volume = TRUE)
  expect_true(all(c("volume", "volume_preleve") %in% s$variable))
  v <- s[s$variable == "volume", ]; vp <- s[s$variable == "volume_preleve", ]
  expect_true(all(v$moyenne[v$annee == 5] > v$moyenne[v$annee == 0]))
  expect_equal(vp$moyenne[vp$annee == 10], v$moyenne[v$annee == 10])
  expect_true(all(is.na(v$bas)))
  s0 <- simuler_itineraire(calibration_factice(), a, e, horizon = 5, n_tirages = 1L)
  expect_false("volume" %in% s0$variable)
})
