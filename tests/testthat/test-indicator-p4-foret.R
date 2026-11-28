# Spec 072 : P4, rendement net du risque (jalons M0 a M3)

.ref_p4 <- function() {
  data.frame(
    ugf = 1:5,
    vocation = c("production", "production", "production", "protection", "naturalite"),
    surface_ha = c(12, 18, 6, 3, 5),
    capital = c(14000, 9000, 11000, 4000, 12000),
    gain_valeur = c(750, 330, 380, 80, 150),
    R1_norm = c(70, 85, 75, 95, 85),
    R2_norm = c(40, 75, 30, 70, 60),
    R3_norm = c(45, 70, 20, 60, 50),
    R4_norm = c(80, 50, 85, 60, 70),
    B = c(35, 65, 30, 80, 90),
    N = c(25, 55, 20, 70, 92),
    stringsAsFactors = FALSE
  )
}
tol <- 5e-5 # 0,005 point, en proportion

# --- M2 : synthese, ruine, Pareto ------------------------------------------

test_that("the forest summary matches the reference", {
  r <- suppressMessages(indicateur_p4_rendement_net(.ref_p4()))
  s <- p4_synthese_foret(r)
  expect_equal(s$capital_total_eur, 468000)
  expect_equal(s$rendement_net_foret * 100, 2.610, tolerance = 0.005 / 2.61)
  expect_equal(s$part_capital_ecart_negatif * 100, 14.10, tolerance = 0.005 / 14.1)
  expect_equal(s$pertes_attendues_eur_an, 5995.2, tolerance = 1e-6)
  expect_equal(s$alea_dominant_foret, "secheresse_sanitaire")
})

test_that("the ruin risk table matches the reference", {
  r <- suppressMessages(indicateur_p4_rendement_net(.ref_p4()))
  z <- p4_ruine_foret(r)
  a <- z$aleas
  expect_equal(z$gain_net_eur_an, 12214.8, tolerance = 1e-8)
  expect_equal(a$alea, c("incendie", "tempete", "secheresse_sanitaire", "abroutissement"))
  expect_equal(a$perte_sinistre_eur, c(40320, 107550, 91440, 8100))
  expect_equal(a$portee, c("localisee", "systemique", "systemique", "localisee"))
  expect_true(all(abs(a$part_capital * 100 - c(8.62, 22.98, 19.54, 1.73)) <= 0.005))
  expect_true(all(abs(a$annees_gain_net - c(3.30, 8.80, 7.49, 0.66)) <= 0.005))
  expect_true(all(abs(a$probabilite_horizon * 100 - c(18.2, 33.2, 45.6, 33.2)) <= 0.05))
  expect_equal(a$premiere_ugf, c("1", "1", "1", "2"))
  expect_true(all(abs(a$part_premiere_ugf * 100 - c(50.0, 46.9, 40.4, 55.0)) <= 0.05))
  expect_true(all(abs(a$nombre_effectif - c(2.92, 3.19, 3.58, 2.67)) <= 0.005))
  # seule la tempete depasse le plafond ; l'UGF 1 (capitaliser) est concentrante
  expect_equal(a$exposition_depassee, c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(z$ugf_concentrantes, "1")
  expect_equal(r$p4_decision[1], "capitaliser")
})

test_that("systemic hazards sum and localised hazards take the maximum", {
  r <- suppressMessages(indicateur_p4_rendement_net(.ref_p4()))
  p <- p4_parametres(surcharge = list(aleas = list(
    tempete = list(portee = "localisee"), incendie = list(portee = "systemique"))))
  a <- p4_ruine_foret(r, parametres = p)$aleas
  expect_equal(a$perte_sinistre_eur[a$alea == "tempete"], 50400)
  expect_equal(a$perte_sinistre_eur[a$alea == "incendie"], 80640)
})

test_that("Pareto on P4, B and N dominates only UGF 3", {
  r <- suppressMessages(indicateur_p4_rendement_net(.ref_p4()))
  q <- suppressMessages(p4_pareto(r, c("B", "N")))
  expect_equal(q$p4_pareto_statut, c("non_domine", "non_domine", "domine", "non_domine", "non_domine"))
  expect_s3_class(attr(q, "prix_implicite"), "data.frame")
  # entree = P4 brut, jamais P4_norm
  r$P4_norm <- rev(r$P4_norm)
  expect_equal(suppressMessages(p4_pareto(r, c("B", "N")))$p4_pareto_statut[3], "domine")
  expect_error(p4_pareto(r, c("B", "N", "B", "N")), class = "nemeton_p4_trop_d_axes")
  # front rendement-risque : perte de sinistre minimisee
  f <- suppressMessages(p4_pareto(r, perte_sinistre = c(5, 4, 9, 1, 3)))
  expect_equal(f$p4_pareto_statut[3], "domine")
})

test_that("axis selection falls back below the minimum sample or without FactoMineR", {
  r <- suppressMessages(indicateur_p4_rendement_net(.ref_p4()))
  r$famille_production <- 1:5; r$famille_risque <- 5:1; r$famille_energie <- c(2, 1, 4, 3, 5)
  expect_warning(s <- p4_selectionner_axes(r), class = "nemeton_p4_repli_axes")
  expect_equal(s$methode, "repli_vocation")
  expect_equal(s$axes, c("famille_production", "famille_risque", "famille_energie"))
  expect_warning(s <- p4_selectionner_axes(r, axe_impose = "famille_energie", vocation = "naturalite"),
                 class = "nemeton_p4_repli_axes")
  expect_equal(s$axes[1], "famille_energie")
  # dependance absente
  big <- r[rep(1:5, 8), ]
  big$famille_production <- big$famille_production + rnorm(40)
  testthat::local_mocked_bindings(.p4_a_factominer = function() FALSE)
  expect_warning(s <- p4_selectionner_axes(big), class = "nemeton_p4_repli_axes")
  expect_equal(s$methode, "repli_vocation")
})

test_that("axis selection runs a PCA with enough units", {
  skip_if_not_installed("FactoMineR")
  set.seed(1)
  n <- 40
  d <- data.frame(P4 = runif(n, 0, 0.05), vocation = "production")
  for (f in c("carbone", "biodiversite", "eau", "air", "risque", "production")) {
    d[[paste0("famille_", f)]] <- runif(n, 0, 100)
  }
  d$famille_eau <- 100 - d$famille_carbone * 0.9 + rnorm(n, 0, 5)
  s <- p4_selectionner_axes(d)
  expect_equal(s$methode, "acp")
  expect_length(s$axes, 3L)
  expect_true(all(s$axes %in% grep("^famille_", names(d), value = TRUE)))
  s2 <- p4_selectionner_axes(d, axe_impose = "famille_air")
  expect_true("famille_air" %in% s2$axes)
})

