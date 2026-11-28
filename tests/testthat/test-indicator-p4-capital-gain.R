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

# --- M3 : capital et gain depuis P1, P2 et les prix ------------------------

test_that("capital and gain are computed from P1, P2 and the prices", {
  u <- data.frame(vocation = "production", species = "douglas", P1 = 400, P2 = 12,
                  R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
  p <- p4_parametres(surcharge = list(prix = list(par_essence = list(douglas = 50))))
  r <- suppressMessages(indicateur_p4_rendement_net(u, parametres = p))
  expect_equal(r$p4_rendement_brut, 12 / 400)
  expect_equal(r$P4, 12 / 400 - 0.0154)
})

test_that("without prices P4 is NA with a warning", {
  u <- data.frame(vocation = "production", species = "douglas", P1 = 400, P2 = 12,
                  R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
  expect_warning(r <- suppressMessages(indicateur_p4_rendement_net(u)), class = "nemeton_p4_prix_absent")
  expect_true(is.na(r$P4))
})

test_that("a P2 site index in metres is not read as an increment", {
  u <- data.frame(vocation = "production", species = "douglas", P1 = 400, P2 = 30,
                  p2_status = "indice_station_m",
                  R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
  p <- p4_parametres(surcharge = list(prix = list(par_essence = list(douglas = 50))))
  expect_warning(r <- suppressMessages(indicateur_p4_rendement_net(u, parametres = p)),
                 class = "nemeton_p4_p2_indice")
  expect_true(is.na(r$P4))
})

test_that("the precision flag follows the weakest NDP", {
  u <- .ref_p4()
  expect_true(all(suppressMessages(indicateur_p4_rendement_net(u, ndp = c(3, 3, 4)))$p4_signal_seulement == FALSE))
  r <- suppressMessages(indicateur_p4_rendement_net(u, ndp = c(3, 2, 4)))
  expect_true(all(r$p4_signal_seulement))
  expect_equal(unique(r$p4_ndp), 2)
  u$ndp <- c(3, 3, 3, 1, 3)
  r <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
  expect_equal(r$p4_signal_seulement, c(FALSE, FALSE, FALSE, TRUE, FALSE))
})

test_that("normalize_indicator accepts the short code P4", {
  expect_equal(normalize_indicator("P4", c(-0.02, 0.03, 0.20)), c(0, 50, 100))
})

test_that("P4 is declared as a conditional indicator of family P, high = good", {
  expect_true("P4" %in% indicator_labels()$code)
  expect_true("indicateur_p4_rendement_net" %in% get_all_column_names())
  d <- list_indicators(return_type = "details")
  expect_true(d$conditionnel[d$code == "P4"])
  expect_equal(d$family[d$code == "P4"], "P")
  expect_length(list_indicators(), 45)
  expect_length(list_indicators(conditionnels = FALSE), 31)
  expect_false("indicateur_p4_rendement_net" %in% list_indicators(conditionnels = FALSE))
})

test_that("massif_demo_units: famille_production is strictly unchanged without the P4 sources", {
  skip_if_not_installed("sf")
  data("massif_demo_units", package = "nemeton")
  d <- massif_demo_units
  expect_false(any(c("P4", "P4_norm") %in% names(d)))
  ref <- d$famille_production
  fam <- suppressMessages(suppressWarnings(create_family_index(d)))
  expect_identical(as.numeric(fam$famille_production), as.numeric(ref))
  # P4 sur le jeu sans vocation : conditionnel, ignore, rien ne bouge
  r <- suppressMessages(indicateur_p4_rendement_net(d))
  expect_true(all(is.na(r$P4)))
  fam2 <- suppressMessages(suppressWarnings(create_family_index(r[, setdiff(names(r), c("P4", "P4_norm"))])))
  expect_identical(as.numeric(fam2$famille_production), as.numeric(ref))
  # meme avec la colonne P4 toute NA, le score de famille ne change pas
  fam3 <- suppressMessages(suppressWarnings(create_family_index(r)))
  expect_identical(as.numeric(fam3$famille_production), as.numeric(ref))
})

test_that("the P4 source file has no non-ASCII character", {
  f <- system.file("extdata", "p4_parametres.yml", package = "nemeton")
  skip_if(!nzchar(f))
  expect_false(any(grepl("[^\x01-\x7F]", readLines(f, warn = FALSE), perl = TRUE)))
})
