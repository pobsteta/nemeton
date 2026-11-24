# Étude FAST contre décoloration (mission 045) : fonctions pures de
# data-raw/etude_fast_decoloration/fonctions.R, données synthétiques, sans réseau.

charger_etude <- function() {
  f <- testthat::test_path("..", "..", "data-raw", "etude_fast_decoloration", "fonctions.R")
  skip_if_not(file.exists(f), "data-raw absent (paquet installé)")
  e <- new.env(); sys.source(f, envir = e); e
}

test_that("cas 0 : les cohortes avant 2021 sont biaisées, pas comparées", {
  e <- charger_etude()
  expect_false(e$cohorte_sans_biais(2018))
  expect_false(e$cohorte_sans_biais(2020))
  expect_true(e$cohorte_sans_biais(2021))
  # pixel coupé en 2019 : 2 années valides (2017-2018) -> pas d'anomalie
  expect_false(e$pixel_comparable(2019))
  expect_false(e$pixel_comparable(2021))
  expect_true(e$pixel_comparable(2022))
  expect_true(e$pixel_comparable(NA))
})

test_that("cas 1 : la censure limite les horizons couverts", {
  e <- charger_etude()
  ti <- e$mois_indice(2022)
  der <- e$mois_indice(2025, 8)            # 34 mois de suivi
  tc <- c(ti + 10, ti + 30, NA, NA, NA, NA)
  co <- e$cohorte_pixels(tc, ti, der)
  expect_equal(unique(co$censure), 34)
  r <- e$km_risque(co$delai, co$evenement)
  expect_false(anyNA(r[1:2]))              # 12, 24 mois couverts
  expect_true(all(is.na(r[3:4])))          # 36, 48 mois non couverts
  expect_equal(r[1], 1 / 6)
  # une coupe au-delà de la dernière coupe connue n'est pas un événement
  co2 <- e$cohorte_pixels(ti + 40, ti, der)
  expect_false(co2$evenement)
})

test_that("cas 2 : un pixel déjà coupé est exclu de l'année de l'indice", {
  e <- charger_etude()
  ti <- e$mois_indice(2021)
  co <- e$cohorte_pixels(c(ti - 5, ti, ti + 5, NA), ti, e$mois_indice(2025, 8))
  expect_equal(co$garde, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("cas 3 et 4 : non applicable et manquant ne sont pas « normal »", {
  e <- charger_etude()
  s <- e$etat_pixel(c(0, 1, NA, 0), n_images = c(3, 2, 2, 0),
                    applicable = c(TRUE, TRUE, TRUE, TRUE))
  expect_equal(s, c("0", "1", "manquant", "manquant"))
  z <- e$etat_pixel(c(0, 0), applicable = c(FALSE, FALSE))
  expect_equal(z, c("non_applicable", "non_applicable"))
  expect_false("0" %in% z)
})

test_that("cas 5 : le passage à 20 m conserve la surface alertée à 1 % près", {
  skip_if_not_installed("terra")
  e <- charger_etude()
  r10 <- terra::rast(nrows = 200, ncols = 200, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000)
  v <- matrix(0, 200, 200); v[21:80, 41:120] <- 1; v[101:140, 11:70] <- 1   # blocs alignés
  terra::values(r10) <- as.vector(t(v))
  r20 <- terra::rast(nrows = 100, ncols = 100, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000)
  a <- e$fast_vers_20m(r10, r20, alerte = TRUE)
  s10 <- sum(terra::values(r10)) * 100
  s20 <- sum(terra::values(a), na.rm = TRUE) * 400
  expect_lt(abs(s20 - s10) / s10, 0.01)
  sc <- e$fast_vers_20m(r10, r20, alerte = FALSE)
  expect_equal(sum(terra::values(sc)) * 400, s10, tolerance = 0.01)
})

test_that("cas 6 : même graine, mêmes zones ; autre graine, autre tirage", {
  e <- charger_etude()
  set.seed(1)
  g <- rep(c("chene", "hetre", "sapin_epicea", "douglas", "melange"), each = 40)
  cm <- data.frame(commune = sprintf("C%03d", seq_along(g)), groupe = g,
                   taux_touche = runif(length(g)))
  z1 <- e$tirer_zones(cm, graine = 45L)
  z2 <- e$tirer_zones(cm[sample(nrow(cm)), ], graine = 45L)   # ordre d'entrée mélangé
  expect_identical(z1, z2)
  expect_equal(nrow(z1), 4 * 3 + 2)
  expect_equal(sum(z1$strate == "melange"), 2)
  expect_false(identical(z1$commune, e$tirer_zones(cm, graine = 7L)$commune))
  # les « très touchées » le sont plus que les « peu touchées »
  expect_gt(min(z1$taux_touche[z1$strate == "tres_touchee"]),
            max(z1$taux_touche[z1$strate == "peu_touchee"]))
})

test_that("vérité 20 m : au moins 2 sous-pixels sur 4", {
  e <- charger_etude()
  t4 <- rbind(c(100, NA, NA, NA), c(100, 104, NA, NA), c(NA, NA, NA, NA), c(90, 95, 99, NA))
  expect_equal(e$coupe_20m(t4), c(NA, 104, NA, 95))
})

test_that("Kaplan-Meier pondéré, AUC, précision à surface égale", {
  e <- charger_etude()
  # sans censure, KM = proportion cumulée
  d <- c(5, 10, 30, 48, 48, 48, 48, 48); ev <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)
  expect_equal(e$km_risque(d, ev)[c(1, 2, 3, 4)], c(2 / 8, 2 / 8, 3 / 8, 3 / 8))
  # le poids déplace le risque
  expect_gt(e$km_risque(d, ev, poids = c(10, rep(1, 7)))[1], 2 / 8)
  expect_equal(e$auc_rang(c(1, 2, 3, 4), c(0, 0, 1, 1)), 1)
  expect_equal(e$auc_rang(c(1, 1, 1, 1), c(0, 1, 0, 1)), 0.5)
  pr <- e$precision_rappel(c(.9, .8, .1, .2, .3), c(1, 0, 0, 0, 1), k = 0.4)
  expect_equal(unname(pr[c("precision", "rappel")]), c(0.5, 0.5))
  expect_equal(e$lift(0.05, 0.01), 5)
})

test_that("intervalle par zone plus large qu'un tirage par pixel de zones corrélées", {
  e <- charger_etude()
  set.seed(3)
  df <- do.call(rbind, lapply(1:8, function(z) data.frame(zone = z, y = rbinom(500, 1, c(.02, .2)[1 + z %% 2]))))
  st <- function(d) mean(d$y)
  ic <- e$ic_par_zone(df, st, B = 200L)
  px <- replicate(200, mean(sample(df$y, replace = TRUE)))
  expect_gt(unname(ic["haut"] - ic["bas"]), diff(stats::quantile(px, c(.025, .975))))
  expect_identical(ic, e$ic_par_zone(df, st, B = 200L))
})

test_that("reprise : une étape déjà faite n'est pas recalculée", {
  e <- charger_etude()
  d <- withr::local_tempdir()
  n <- 0L
  f <- function() { n <<- n + 1L; 42 }
  expect_equal(e$etape_cache(d, "Z1", "verite", f), 42)
  expect_equal(e$etape_cache(d, "Z1", "verite", f), 42)
  expect_equal(n, 1L)
  expect_true(file.exists(file.path(d, "durees.csv")))
})
