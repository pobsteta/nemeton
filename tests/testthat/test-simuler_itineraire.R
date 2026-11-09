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
