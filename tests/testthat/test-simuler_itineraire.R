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
  expect_error(nemeton:::.itin_regles(cat$bfc_taillis_sous_futaie, 5), "not sourced")
})

test_that("the sourced beech uneven-aged entry gives the engine its rules", {
  r <- nemeton:::.itin_regles(itineraires_catalogue()$bfc_hetre_futaie_irreguliere, 5)
  expect_equal(r[c("rotation_ans", "diametre", "cible", "intensite")],
               list(rotation_ans = 10, diametre = 60, cible = 16.5, intensite = 25))
  # G 25 m2/ha : ramene vers 16,5 mais plafonne a 25 % -> ~18,75 (fig. 2 : 19,8)
  n <- round(25 / (pi * 0.15^2))  # tiges de 30 cm pour 25 m2/ha
  coh <- data.frame(siteID = 1L, species = 1L, dbh = 30, trees = rep(1, n))
  set.seed(2)
  g1 <- nemeton:::.itin_etat(nemeton:::.itin_couper(coh, r, 1L, 1), 1L, 1)$g
  expect_equal(g1 / nemeton:::.itin_etat(coh, 1L, 1)$g, 0.75, tolerance = 0.05)
})

test_that("a thinning norm by mean diameter sets the target per plot (D-10)", {
  norme <- list(dg_cm = list(20, 40), g_m2ha = list(15, 20))
  r <- nemeton:::.itin_regles(itin_demo(norme_g_selon_dg = norme), 5)
  expect_equal(r$norme, list(dg = c(20, 40), g = c(15, 20)))
  expect_error(nemeton:::.itin_regles(itin_demo(norme_g_selon_dg = norme,
                                                surface_terriere_cible_m2ha = 18), 5), "both")
  expect_error(nemeton:::.itin_regles(itin_demo(norme_g_selon_dg = list(dg_cm = list(40, 20),
                                                                          g_m2ha = list(15, 20))), 5),
               "malformed")
  # Dg 10 cm : sous la table, pas d'eclaircie ; 30 cm : 17,5 ; 60 cm : 20
  tiges <- c(1000, 300, 100)
  dg <- c(10, 30, 60)
  g <- tiges * pi * (dg / 200)^2
  expect_equal(nemeton:::.itin_cible_norme(r$norme, g, tiges), c(Inf, 17.5, 20))
  # coupe : le site a Dg 30 cm et G 30 m2/ha est ramene vers 17,5
  n30 <- round(30 / (pi * 0.15^2))
  coh <- data.frame(siteID = 1L, species = 1L, dbh = 30, trees = rep(1, n30))
  set.seed(3)
  g1 <- nemeton:::.itin_etat(nemeton:::.itin_couper(coh, r, 1L, 1), 1L, 1)$g
  expect_equal(g1, 17.5, tolerance = 0.1)
  # l'entree du chene sessile passe le controle du moteur
  ch <- nemeton:::.itin_regles(itineraires_catalogue()$bfc_chene_sessile_futaie_reguliere, 5)
  expect_equal(ch$diametre, 75)
  expect_equal(range(ch$norme$g), c(14.7, 20.2))
  # l'epicea (SFFC 2012) : Dg 30 cm et G 40 m2/ha ramenes vers la norme,
  # interpolee entre 29,4 cm (28,0) et 38,2 cm (31,3)
  ep <- nemeton:::.itin_regles(itineraires_catalogue()$bfc_epicea_futaie_reguliere, 5)
  expect_equal(ep$diametre, 55)
  n40 <- round(40 / (pi * 0.15^2))
  coh <- data.frame(siteID = 1L, species = 1L, dbh = 30, trees = rep(1, n40))
  set.seed(4)
  g2 <- nemeton:::.itin_etat(nemeton:::.itin_couper(coh, ep, 1L, 1), 1L, 1)$g
  cible <- stats::approx(c(29.4, 38.2), c(28.0, 31.3), xout = 30)$y
  expect_equal(g2, cible, tolerance = 0.1)
})

test_that("every sourced entry of the shipped catalogue is accepted by the engine", {
  cat <- itineraires_catalogue()
  sources <- Filter(function(it) identical(it$statut_source, "source"), cat)
  expect_gte(length(sources), 10L)
  for (it in sources) {
    r <- nemeton:::.itin_regles(it, 5)
    if (isTRUE(it$regles$aucune_coupe)) {
      expect_null(r, label = it$code)
    } else {
      expect_equal(r$rotation_ans %% 5, 0, label = it$code)
    }
  }
  # aucune_coupe exclut toute autre regle
  lib <- itineraires_catalogue()$bfc_libre_evolution
  lib$regles$rotation_ans <- 10
  expect_error(nemeton:::.itin_regles(lib, 5), "aucune_coupe")
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

test_that("rapport_g_tiges sets the nature of the thinning (from below / above)", {
  norme <- list(dg_cm = list(10, 60), g_m2ha = list(20, 20))
  r <- nemeton:::.itin_regles(itin_demo(norme_g_selon_dg = norme, rapport_g_tiges = 0.8), 5)
  expect_equal(r$rapport, 0.8)
  expect_error(nemeton:::.itin_regles(itin_demo(norme_g_selon_dg = norme, rapport_g_tiges = 0), 5),
               "rapport_g_tiges")
  expect_error(nemeton:::.itin_regles(itin_demo(diametre_exploitabilite_cm = 60,
                                                rapport_g_tiges = 0.8), 5),
               "without a thinning rule")
  # solveur : part de G exacte, rapport atteint dans les deux sens
  set.seed(1)
  n <- rpois(30, 20) + 1
  g <- pi * (runif(30, 8, 60) / 200)^2
  for (rap in c(0.7, 0.92, 1.2)) {
    q <- nemeton:::.itin_probas_rapport(n, g, 0.25, rap)
    pg <- sum(n * g * q) / sum(n * g)
    expect_equal(pg, 0.25, tolerance = 1e-6)
    expect_equal(pg / (sum(n * q) / sum(n)), rap, tolerance = 1e-4)
  }
  # une seule grosseur : le rapport ne peut que valoir 1, la part de G tient
  q <- nemeton:::.itin_probas_rapport(c(5, 5), c(0.1, 0.1), 0.3, 0.8)
  expect_equal(q, c(0.3, 0.3), tolerance = 1e-6)
  # coupe : a part de G egale, le rapport 0,6 enleve plus de tiges que 1
  coh <- data.frame(siteID = 1L, species = 1L, dbh = rep(c(15, 30, 45), each = 200),
                    trees = 1)
  g0 <- nemeton:::.itin_etat(coh, 1L, 1)
  set.seed(5)
  bas <- nemeton:::.itin_couper(coh, list(cible = 0.7 * g0$g, rapport = 0.6), 1L, 1)
  set.seed(5)
  prop <- nemeton:::.itin_couper(coh, list(cible = 0.7 * g0$g), 1L, 1)
  expect_equal(nemeton:::.itin_etat(bas, 1L, 1)$g, 0.7 * g0$g, tolerance = 0.06)
  expect_lt(nrow(bas), nrow(prop))
  # les entrees du hetre regulier et des resineux portent leur rapport
  cat <- itineraires_catalogue()
  expect_equal(nemeton:::.itin_regles(cat$bfc_hetre_futaie_reguliere, 5)$rapport, 0.92)
  for (code in c("bfc_epicea_futaie_reguliere", "bfc_sapin_futaie_reguliere",
                 "bfc_douglas_futaie_reguliere")) {
    expect_equal(nemeton:::.itin_regles(cat[[code]], 5)$rapport, 0.83, label = code)
  }
  expect_null(nemeton:::.itin_regles(cat$bfc_chene_sessile_futaie_reguliere, 5)$rapport)
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
  expect_error(simuler_itineraire(faux, a, e, itineraire = itineraires_catalogue()$bfc_taillis_sous_futaie),
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
  # bois mort depuis la mortalite FINN, et coupe rase (placettes videes :
  # FINN renumerotait les sites et echouait)
  e$ser <- "C20"
  rase <- itin_demo(rotation_ans = 5, diametre_exploitabilite_cm = 0)
  s3 <- simuler_itineraire(cal, a, e, itineraire = rase, horizon = 15, n_tirages = 2L,
                           biodiversite = TRUE)
  expect_true(all(c("volume_mort", "bois_mort", "tiges_tgb") %in% s3$variable))
  expect_true(all(s3$moyenne[s3$variable %in% c("volume_mort", "bois_mort")] >= 0))
  expect_true(all(s3$moyenne[s3$variable == "g" & s3$annee == 10] >= 0))
})

test_that(".itin_un_pas counts the trees dead in the step per cohort (FINN)", {
  skip_on_cran()
  skip_if_not_installed("FINN")
  skip_if_not_installed("data.table")
  skip_if_not(torch::torch_is_installed(), "libtorch not installed")
  a <- arbres_finn_demo(); e <- env_finn_demo()
  cal <- calibrer_finn(a, e, epoques = 2L, min_arbres_essence = 1L)
  prep <- .finn_preparer(transform(a, d2 = NA_real_), e, cal$surface_placette,
                         essences = cal$essences, variables_env = cal$variables_env,
                         observations = FALSE)
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  coh <- prep$init[, c("siteID", "species", "dbh", "trees")]
  coh$trees <- round(coh$trees)
  cal$modele$eval()
  apres <- .itin_un_pas(cal$modele, coh, env1, cal$surface_placette, length(cal$essences))
  morts <- attr(apres, "morts")
  expect_true(all(morts$trees > 0))
  # les morts viennent des cohortes d'entree, au diametre d'entree
  expect_true(all(paste(morts$siteID, morts$species, morts$dbh) %in%
                    paste(coh$siteID, coh$species, coh$dbh)))
  expect_true(sum(morts$trees) <= sum(coh$trees))
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

test_that("simuler_itineraire holds the stands under the density ceiling (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 3)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo()
  cal <- calibration_factice()
  libre <- simuler_itineraire(cal, a, e, horizon = 30, n_tirages = 1L)
  # plafond bas pour toutes les essences : G plafonne, sans prelevement compte
  dm <- data.frame(essence = "toutes", rdi_max = 100)
  plaf <- simuler_itineraire(cal, a, e, horizon = 30, n_tirages = 1L, densite_max = dm)
  gl <- libre$moyenne[libre$variable == "g" & libre$annee == 30]
  gp <- plaf$moyenne[plaf$variable == "g" & plaf$annee == 30]
  expect_true(all(gp < gl))
  expect_true(all(plaf$moyenne[plaf$variable == "g_prelevee"] == 0))
  # plafond hors d'atteinte : trajectoire inchangee
  haut <- simuler_itineraire(cal, a, e, horizon = 30, n_tirages = 1L,
                             densite_max = data.frame(essence = "toutes", rdi_max = 1e9))
  expect_equal(haut$moyenne, libre$moyenne)
  expect_error(simuler_itineraire(cal, a, e, horizon = 30, n_tirages = 1L,
                                  densite_max = data.frame(essence = "03", rdi_max = 100)),
               "toutes")
})

test_that("conformer_finn takes the residual quantile (predire_finn mocked)", {
  pla <- paste0("Q", 1:40)
  a <- data.frame(placette = pla, essence = "09", d1 = 20, d2 = 20, poids = 100,
                  statut = "vivant")
  g_obs <- 100 * pi * 0.1^2
  local_mocked_bindings(
    predire_finn = function(calibration, arbres, environnement, ...) {
      data.frame(placette = pla, g_predite = g_obs + seq_along(pla) / 10)
    },
    # mortalite : placettes rendues dans l'ordre inverse, rematchees
    .finn_mortalite = function(calibration, arbres, environnement, ...) {
      p <- rev(unique(as.character(arbres$placette)))
      data.frame(placette = p, mort_observee = 1, mort_attendue = match(p, pla) / 100)
    }
  )
  cal <- conformer_finn(calibration_factice(), a, data.frame(placette = pla, x = 1))
  expect_equal(cal$conforme$n_placettes, 40)
  expect_equal(cal$conforme$residus, seq_along(pla) / 10)
  expect_null(cal$conforme$x)
  expect_equal(cal$conforme$mortalite$residus, 1 - seq_along(pla) / 100)
  expect_equal(cal$conforme$mortalite$n_placettes, 40)
  sans <- conformer_finn(calibration_factice(), a, data.frame(placette = pla, x = 1),
                         mortalite = FALSE)
  expect_null(sans$conforme$mortalite)
  # placette coupee : residu de mortalite NA
  ac <- rbind(a, data.frame(placette = "Q3", essence = "09", d1 = 30, d2 = NA, poids = 5,
                            statut = "coupe"))
  cc <- conformer_finn(calibration_factice(), ac, data.frame(placette = pla, x = 1))
  expect_true(is.na(cc$conforme$mortalite$residus[3]))
  expect_equal(cc$conforme$mortalite$n_placettes, 39)
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

test_that(".itin_tarifs gives the infradensity of each plot x species, other = tariff species", {
  a <- arbres_finn_demo(); e <- env_finn_demo(); e$ser <- "C20"
  a$d2 <- NA_real_
  prep <- nemeton:::.finn_preparer(a, e, 0.7, essences = c("09", "03", "other"),
                                   observations = FALSE)
  tar <- nemeton:::.itin_tarifs(a, e, prep, c("09", "03", "other"))
  expect_equal(dim(tar$rho), c(6L, 3L))
  expect_equal(tar$rho[1, 1], infradensite_espar("09")$infradensite_g_cm3)
  expect_equal(tar$rho[1, 2], infradensite_espar("03")$infradensite_g_cm3)
  a0 <- a[a$placette == "P1" & a$essence %in% c("62", "51") & a$statut != "recrute", ]
  dom <- a0$essence[which.max(a0$d1)]
  expect_equal(tar$rho[1, 3], infradensite_espar(dom)$infradensite_g_cm3)
})

test_that(".itin_etat computes the dry stem mass, zero below 7.5 cm", {
  tar <- list(numero = matrix(c(10, 12), 1), type = matrix(c("SCHL", "SCHR"), 1),
              rho = matrix(c(0.5, 0.4), 1))
  coh <- data.frame(siteID = 1L, species = c(1L, 2L, 1L), dbh = c(30, 40, 5),
                    trees = c(7, 7, 100))
  et <- nemeton:::.itin_etat(coh, 2L, 0.7, tar)
  m <- (7 * volume_tarif_schaeffer(10, 30, "SCHL") * 0.5 +
          7 * volume_tarif_schaeffer(12, 40, "SCHR") * 0.4) / 0.7
  expect_equal(et$c, c(m, 0))
})

test_that("simuler_itineraire adds carbon and harvested carbon (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 1)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo(); e$ser <- "C20"
  it <- itin_demo(diametre_exploitabilite_cm = 0)
  # carbone seul : le tarif est calcule, le volume n'est pas rendu
  s <- simuler_itineraire(calibration_factice(), a, e, itineraire = it, horizon = 20,
                          n_tirages = 1L, carbone = TRUE)
  expect_true(all(c("carbone", "carbone_preleve") %in% s$variable))
  expect_false("volume" %in% s$variable)
  cb <- s[s$variable == "carbone", ]; cp <- s[s$variable == "carbone_preleve", ]
  expect_true(all(cb$moyenne[cb$annee == 5] > cb$moyenne[cb$annee == 0]))
  expect_equal(cp$moyenne[cp$annee == 10], cb$moyenne[cb$annee == 10])
  # proportionnel a bef x fraction_carbone
  s2 <- simuler_itineraire(calibration_factice(), a, e, itineraire = it, horizon = 20,
                           n_tirages = 1L, carbone = TRUE, bef = 2.6, fraction_carbone = 0.25)
  c2 <- s2[s2$variable == "carbone", ]
  expect_equal(c2$moyenne, cb$moyenne)
  # carbone / volume = infradensite x 1,30 x 0,50, entre bois leger et lourd
  sv <- simuler_itineraire(calibration_factice(), a, e, horizon = 5, n_tirages = 1L,
                           volume = TRUE, carbone = TRUE)
  v0 <- sv$moyenne[sv$variable == "volume" & sv$annee == 0]
  c0 <- sv$moyenne[sv$variable == "carbone" & sv$annee == 0]
  r <- c0[v0 > 0] / v0[v0 > 0] / (1.30 * 0.50)
  expect_true(all(r > 0.3 & r < 0.8))
})

test_that("parametres_filiere_bois gives the sourced wood-chain parameters", {
  p <- parametres_filiere_bois()
  expect_setequal(names(p), c("taux_bo", "part_bi", "rendement", "demi_vie",
                              "substitution_materiau", "substitution_energie"))
  expect_setequal(unique(p$taux_bo$groupe), c("chenes", "hetre", "sapin", "epicea", "douglas",
                                              "autres_resineux", "autres_feuillus"))
  # petits bois : aucune part de bois d'oeuvre (qualite 3 par convention IFN)
  expect_true(all(p$taux_bo$taux_bo[p$taux_bo$d_min == 7.5] == 0))
  expect_true(all(p$taux_bo$taux_bo >= 0 & p$taux_bo$taux_bo <= 1))
  expect_equal(p$demi_vie[["bo"]], 20)
  expect_equal(p$substitution_materiau, 1.6)
  expect_equal(p$substitution_energie, 0.916)
  expect_identical(.filiere_verifier(p)$part_bi, p$part_bi)
  p$part_bi <- c(feuillus = 2, resineux = 0.5)
  expect_error(.filiere_verifier(p), "part_bi")
  p <- parametres_filiere_bois(); p$demi_vie[["bi"]] <- 0
  expect_error(.filiere_verifier(p), "demi_vie")
  p <- parametres_filiere_bois(); p$taux_bo <- NULL
  expect_error(.filiere_verifier(p), "taux_bo")
})

test_that(".filiere_taux reads the sawlog share by group and diameter", {
  t <- .filiere_verifier(parametres_filiere_bois())$taux_bo
  g <- .filiere_groupe(c("03", "02", "09", "61", "62", "64", "52", "17C"))
  expect_equal(g, c("chenes", "chenes", "hetre", "sapin", "epicea", "douglas",
                    "autres_resineux", "autres_feuillus"))
  ch <- t[t$groupe == "chenes", ]
  x <- .filiere_taux(t, rep("chenes", 4), c(5, 15, 25, 100), rep(FALSE, 4))
  expect_equal(x, c(0, 0, ch$taux_bo[ch$d_min == 22.5], ch$taux_bo[ch$d_min == 62.5]))
  # groupe absent de la table : repli feuillus / resineux
  x2 <- .filiere_taux(t, c("inconnu", "inconnu"), c(40, 40), c(TRUE, FALSE))
  ar <- t[t$groupe == "autres_resineux" & t$d_min == 32.5, "taux_bo"]
  af <- t[t$groupe == "autres_feuillus" & t$d_min == 32.5, "taux_bo"]
  expect_equal(x2, c(ar, af))
})

test_that("simuler_itineraire follows the harvested carbon and the substitution (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 1)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo(); e$ser <- "C20"
  it <- itin_demo(diametre_exploitabilite_cm = 0)
  expect_error(simuler_itineraire(calibration_factice(), a, e, itineraire = it, horizon = 20,
                                  n_tirages = 1L, produits = TRUE), "carbone = TRUE")
  sim <- function(...) simuler_itineraire(calibration_factice(), a, e, horizon = 20,
                                          n_tirages = 1L, volume = TRUE, carbone = TRUE,
                                          produits = TRUE, ...)
  val <- function(s, v, an) s$moyenne[s$variable == v & s$annee == an]
  # sans gestion : rien hors foret, carbone_total = carbone
  s0 <- sim()
  expect_true(all(s0$moyenne[s0$variable %in% c("carbone_produits", "substitution",
                                                "volume_preleve_bo")] == 0))
  expect_equal(s0$moyenne[s0$variable == "carbone_total"], s0$moyenne[s0$variable == "carbone"])
  # coupe rase a 10 ans : stock de produits, puis decroissance entre les deux
  # demi-vies (5 et 20 ans) ; borne : 85 % de la tige au plus
  s <- sim(itineraire = it)
  cp10 <- val(s, "carbone_produits", 10)
  expect_true(all(cp10 > 0))
  expect_true(all(val(s, "carbone_produits", 5) == 0))
  expect_true(all(cp10 <= 0.85 * val(s, "carbone_preleve", 10) / 1.30 + 1e-9))
  r <- val(s, "carbone_produits", 15) / cp10
  expect_true(all(r > 0.5 - 1e-9 & r < 2^(-5 / 20) + 1e-9))
  expect_true(all(val(s, "substitution", 10) > 0))
  expect_true(all(val(s, "substitution", c(5, 15, 20)) == 0))
  expect_equal(val(s, "carbone_total", 15), val(s, "carbone", 15) + val(s, "carbone_produits", 15))
  # tout en bois d'oeuvre, rendement 1, sans decroissance : la tige entiere
  # entre en produits, la substitution est 1,6 x volume preleve
  f <- parametres_filiere_bois()
  f$taux_bo$taux_bo <- 1; f$rendement[["bo"]] <- 1; f$demi_vie[] <- 1e9
  s1 <- sim(itineraire = it, filiere = f)
  expect_equal(val(s1, "carbone_produits", 10), val(s1, "carbone_preleve", 10) / 1.30)
  expect_equal(val(s1, "substitution", 10), 1.6 * val(s1, "volume_preleve", 10))
  expect_equal(val(s1, "volume_preleve_bo", 10), val(s1, "volume_preleve", 10))
  # tout en energie : pas de produits, substitution = 0,916 x masse seche
  f$taux_bo$taux_bo <- 0; f$part_bi[] <- 0
  s2 <- sim(itineraire = it, filiere = f)
  expect_true(all(val(s2, "carbone_produits", 10) == 0))
  expect_equal(val(s2, "substitution", 10), 0.916 * val(s2, "carbone_preleve", 10) / (1.30 * 0.5))
})

test_that("simuler_itineraire follows the deadwood and the very large trees (FINN mocked)", {
  # un pas factice : +1 cm, et un quart des tiges de chaque cohorte meurt
  pas <- function(m, coh, env1, sp, n_sp) {
    morts <- transform(coh, trees = floor(trees / 4))
    out <- transform(coh, dbh = dbh + 1, trees = trees - floor(trees / 4))
    out <- out[out$trees > 0, , drop = FALSE]
    attr(out, "morts") <- morts[morts$trees > 0, , drop = FALSE]
    out
  }
  local_mocked_bindings(.finn_verifier_installation = function() invisible(TRUE),
                        .itin_un_pas = pas)
  a <- arbres_finn_demo(); e <- env_finn_demo(); e$ser <- "C20"
  cal <- calibration_factice()
  s <- simuler_itineraire(cal, a, e, horizon = 20, n_tirages = 1L, biodiversite = TRUE,
                          decomposition = c(feuillus = 0.1, resineux = 0.1))
  expect_false("volume" %in% s$variable)
  vm <- s[s$variable == "volume_mort", ]; bm <- s[s$variable == "bois_mort", ]
  expect_true(all(vm$moyenne[vm$annee == 0] == 0))
  expect_true(all(vm$moyenne[vm$annee == 5] > 0))
  # stock : decroissance du premier ordre puis entrees du pas
  for (t in c(10, 15, 20)) {
    expect_equal(bm$moyenne[bm$annee == t],
                 bm$moyenne[bm$annee == t - 5] * exp(-0.1 * 5) + vm$moyenne[vm$annee == t])
  }
  # sans decomposition, le stock est le cumul des entrees
  s0 <- simuler_itineraire(cal, a, e, horizon = 20, n_tirages = 1L, biodiversite = TRUE,
                           decomposition = c(feuillus = 0, resineux = 0))
  v0 <- s0[s0$variable == "volume_mort", ]; b0 <- s0[s0$variable == "bois_mort", ]
  expect_equal(b0$moyenne[b0$annee == 20],
               as.numeric(tapply(v0$moyenne, v0$placette, sum)[b0$placette[b0$annee == 20]]))
  # tres gros bois : les tiges a partir du seuil
  st <- simuler_itineraire(cal, a, e, horizon = 5, n_tirages = 1L, biodiversite = TRUE,
                           seuil_tgb = 1)
  expect_equal(st$moyenne[st$variable == "tiges_tgb"], st$moyenne[st$variable == "tiges"])
  sh <- simuler_itineraire(cal, a, e, horizon = 5, n_tirages = 1L, biodiversite = TRUE,
                           seuil_tgb = 500)
  expect_true(all(sh$moyenne[sh$variable == "tiges_tgb"] == 0))
  expect_error(simuler_itineraire(cal, a, e, biodiversite = TRUE, seuil_tgb = -1), "seuil_tgb")
  expect_error(simuler_itineraire(cal, a, e, biodiversite = TRUE,
                                  decomposition = c(feuillus = 0.1)), "decomposition")
})

test_that("simuler_itineraire counts the self-thinning as deadwood, not the cuts (FINN mocked)", {
  local_mocked_bindings(
    .finn_verifier_installation = function() invisible(TRUE),
    .itin_un_pas = function(m, coh, env1, sp, n_sp) transform(coh, dbh = dbh + 3)
  )
  a <- arbres_finn_demo(); e <- env_finn_demo(); e$ser <- "C20"
  cal <- calibration_factice()
  # croissance seule, sans mortalite : pas de bois mort
  libre <- simuler_itineraire(cal, a, e, horizon = 20, n_tirages = 1L, biodiversite = TRUE)
  expect_true(all(libre$moyenne[libre$variable %in% c("volume_mort", "bois_mort")] == 0))
  # une coupe rase n'est pas du bois mort
  rase <- simuler_itineraire(cal, a, e, itineraire = itin_demo(diametre_exploitabilite_cm = 0),
                             horizon = 20, n_tirages = 1L, biodiversite = TRUE)
  expect_true(all(rase$moyenne[rase$variable == "bois_mort"] == 0))
  # l'auto-eclaircie sous plafond l'est
  plaf <- simuler_itineraire(cal, a, e, horizon = 20, n_tirages = 1L, biodiversite = TRUE,
                             densite_max = data.frame(essence = "toutes", rdi_max = 100))
  expect_true(any(plaf$moyenne[plaf$variable == "volume_mort"] > 0))
  expect_true(any(plaf$moyenne[plaf$variable == "bois_mort"] > 0))
})

test_that(".itin_un_pas runs FINN by packets of sites and renumbers them back", {
  vus <- list()
  local_mocked_bindings(.itin_un_pas_bloc = function(m, coh, env1, sp, n_sp) {
    vus[[length(vus) + 1L]] <<- env1$siteID
    stopifnot(all(coh$siteID %in% env1$siteID))
    out <- transform(coh, dbh = dbh + 1)
    attr(out, "morts") <- coh[1, , drop = FALSE]
    out
  })
  env1 <- data.frame(siteID = 1:5, tx_ete = 25, year = 0L)
  coh <- data.frame(siteID = c(1L, 2L, 3L, 4L, 5L, 5L), species = 1L,
                    dbh = c(10, 20, 30, 40, 50, 60), trees = 1)
  r <- .itin_un_pas(NULL, coh, env1, 0.1, 1L, paquet = 2L)
  # trois appels, sites renumerotes 1..n dans chacun
  expect_equal(vus, list(1:2, 1:2, 1L))
  expect_equal(r$siteID, coh$siteID)
  expect_equal(r$dbh, coh$dbh + 1)
  expect_equal(attr(r, "morts")$siteID, c(1L, 3L, 5L))
  # sous le seuil : un seul appel, sites intacts
  vus <- list()
  .itin_un_pas(NULL, coh, env1, 0.1, 1L)
  expect_equal(vus, list(1:5))
})
