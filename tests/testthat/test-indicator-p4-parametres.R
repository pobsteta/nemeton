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

# --- M0 : parametres ------------------------------------------------------

test_that("the shipped parameter file is valid, provisional and complete", {
  p <- p4_parametres()
  expect_true(p$provisoire)
  expect_equal(p$plafond_score, 0.06)
  expect_setequal(names(p$aleas), c("incendie", "tempete", "secheresse_sanitaire", "abroutissement"))
  expect_setequal(names(p$vocations), c("production", "mixte", "protection", "accueil", "naturalite"))
  expect_equal(unlist(p$aleas$secheresse_sanitaire$score), c("R3", "R5"))
  expect_length(p$prix$par_essence, 0L) # aucun prix invente
})

test_that("the validator names missing hazards, vocations, fields and bad domains", {
  p <- p4_parametres()
  q <- p; q$vocations$mixte <- NULL
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$aleas$tempete <- NULL
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$aleas$incendie$p_max <- NULL
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$aleas$incendie$p_max <- 1.5
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$aleas$incendie$portee <- "locale"
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$vocations$production$si_ecart_negatif <- "vendre"
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$plafond_score <- 0
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
  q <- p; q$prix$par_essence <- list(douglas = -3)
  expect_error(p4_valider_parametres(q), class = "nemeton_p4_parametres_invalides")
})

test_that("the parameters can be overridden per project", {
  p <- p4_parametres(surcharge = list(plafond_score = 0.05,
                                      vocations = list(production = list(taux_exige = 0.04))))
  expect_equal(p$plafond_score, 0.05)
  expect_equal(p$vocations$production$taux_exige, 0.04)
  expect_equal(p$vocations$mixte$taux_exige, 0.02) # le reste est conserve
  f <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(list(version = 1, provisoire = FALSE), f)
  expect_error(p4_parametres(fichier = f), class = "nemeton_p4_parametres_invalides")
  expect_error(p4_parametres(fichier = "absent.yml"), class = "nemeton_p4_parametres_invalides")
})

