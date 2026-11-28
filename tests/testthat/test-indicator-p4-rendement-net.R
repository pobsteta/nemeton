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

# --- M1 : jeu de reference du sect. 10 ----------------------------------------

test_that("P4 reproduces the reference forest of spec 072 section 10", {
  r <- suppressMessages(indicateur_p4_rendement_net(.ref_p4()))
  attendu <- list(
    p4_rendement_brut = c(5.357, 3.667, 3.455, 2.000, 1.250),
    p4_perte_incendie = c(0.24, 0.12, 0.20, 0.04, 0.12),
    p4_perte_tempete = c(0.60, 0.25, 0.70, 0.30, 0.40),
    p4_perte_secheresse_sanitaire = c(0.66, 0.36, 0.96, 0.48, 0.60),
    p4_perte_abroutissement = c(0.04, 0.10, 0.03, 0.08, 0.06),
    p4_pertes_attendues = c(1.54, 0.83, 1.89, 0.90, 1.18),
    P4 = c(3.817, 2.837, 1.565, 1.100, 0.070),
    p4_ecart = c(0.817, -0.163, -1.435, 0.100, 0.070)
  )
  for (cl in names(attendu)) {
    expect_true(all(abs(r[[cl]] * 100 - attendu[[cl]]) <= 0.005), info = cl)
  }
  expect_true(all(abs(r$P4 * 100 - attendu$P4) <= 0.005))
  expect_equal(r$P4_norm, c(64, 47, 26, 18, 1))
  expect_equal(r$p4_decision, c("capitaliser", "equilibre", "recolter", "equilibre", "equilibre"))
  expect_equal(r$p4_alea_dominant, c("secheresse_sanitaire", "secheresse_sanitaire",
                                     "secheresse_sanitaire", "secheresse_sanitaire",
                                     "secheresse_sanitaire"))
  expect_equal(r$p4_taux_exige, c(.03, .03, .03, .01, 0))
  # rendement geometrique : 3,505 ; 2,757 ; 1,131 ; 1,015 ; -0,062
  expect_true(all(abs(r$p4_rendement_geometrique * 100 - c(3.505, 2.757, 1.131, 1.015, -0.062)) <= 0.005))
  expect_true(all(r$p4_rendement_geometrique <= r$P4 + 0.0005))
  expect_true(all(r$p4_signal_seulement)) # NDP inconnu : signal seulement
})

test_that("P4 returns NA with a status when its sources are absent", {
  u <- .ref_p4()[, c("ugf", "R1_norm")]
  r <- indicateur_p4_rendement_net(u)
  expect_true(all(is.na(r$P4)))
  expect_equal(unique(r$p4_status), "skipped_no_p4_source")
  u <- .ref_p4(); u$capital <- NULL; u$gain_valeur <- NULL
  expect_equal(unique(indicateur_p4_rendement_net(u)$p4_status), "skipped_no_p4_source")
})

test_that("perte_saisie replaces the computed losses", {
  u <- .ref_p4(); u$perte_saisie <- c(0.01, NA, NA, NA, NA)
  r <- suppressMessages(indicateur_p4_rendement_net(u))
  expect_equal(r$p4_pertes_attendues[1], 0.01)
  expect_true(all(is.na(r[1, paste0("p4_perte_", c("incendie", "tempete", "secheresse_sanitaire", "abroutissement"))])))
  expect_equal(r$P4[1], 750 / 14000 - 0.01)
  expect_true(is.na(r$p4_rendement_geometrique[1]))
  expect_equal(r$P4[2:5] * 100, c(2.837, 1.565, 1.100, 0.070)[c(1, 2, 3, 4)] * c(1, 1, 1, 1), tolerance = 0.002)
})

test_that("a null or missing capital gives NA and a warning, not an error", {
  u <- .ref_p4(); u$capital[2] <- 0; u$capital[3] <- NA
  expect_warning(r <- suppressMessages(indicateur_p4_rendement_net(u)), class = "nemeton_p4_capital_invalide")
  expect_true(all(is.na(r$P4[2:3])))
  expect_false(anyNA(r$P4[c(1, 4, 5)]))
})

test_that("an unknown vocation is an explicit error", {
  u <- .ref_p4(); u$vocation[1] <- "chasse"
  expect_error(indicateur_p4_rendement_net(u), class = "nemeton_p4_vocation_inconnue")
})

test_that("a missing normalised R score gives NA and a warning", {
  u <- .ref_p4(); u$R2_norm[2] <- NA
  expect_warning(r <- suppressMessages(indicateur_p4_rendement_net(u)), class = "nemeton_p4_score_manquant")
  expect_true(is.na(r$P4[2]))
  u <- .ref_p4(); u$R4_norm <- NULL
  expect_warning(r <- suppressMessages(indicateur_p4_rendement_net(u)), class = "nemeton_p4_score_manquant")
  expect_true(all(is.na(r$P4)))
})

test_that("R5 present: the health hazard reads min(R3_norm, R5_norm)", {
  u <- .ref_p4(); u$R5_norm <- c(10, NA, 90, 60, 50)
  r <- suppressMessages(indicateur_p4_rendement_net(u))
  # UGF 1 : min(45, 10) = 10 -> 0.03 * 0.9 * 0.4 ; UGF 2 : R5 NA -> R3 seul
  expect_equal(r$p4_perte_secheresse_sanitaire[1], 0.03 * (1 - 0.10) * 0.40)
  expect_equal(r$p4_perte_secheresse_sanitaire[2], 0.03 * (1 - 0.70) * 0.40)
  expect_equal(r$p4_perte_secheresse_sanitaire[3], 0.03 * (1 - 0.20) * 0.40)
})

test_that("the raw R column without its _norm is refused", {
  u <- .ref_p4(); names(u)[names(u) == "R1_norm"] <- "R1"
  expect_error(indicateur_p4_rendement_net(u), class = "nemeton_p4_colonne_brute")
})

test_that("P4_norm is bounded at 0 and 100 by a dedicated rule", {
  expect_equal(normalize_indicator("indicateur_p4_rendement_net", c(-0.02, 0, 0.03, 0.06, 0.20)), c(0, 0, 50, 100, 100))
  expect_equal(normalize_indicator("indicateur_p4_rendement_net", 0.0382), 64)
})

