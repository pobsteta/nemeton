# Tests de T4, vitalite dynamique (spec 068). Les analogues et les residus
# embarques sont remplaces par de petites tables ; FORMS-T par un raster
# synthetique en cm.

ana_t4 <- function() {
  # 40 placettes de hetre en C20 a 20 m, accroissement simule 1 m (3 tirages)
  data.frame(placette = paste0("p", 1:40), ser = "C20", essence = "09", g0 = 30,
             h_dom = rep(c(18, 20, 22, 24), 10), a1 = 0.9, a2 = 1, a3 = 1.1,
             stringsAsFactors = FALSE)
}
res_t4 <- function() {
  # residus symetriques autour de 0
  data.frame(placette = paste0("p", 1:40), essence = "09", h_dom = 20,
             observe = 1, simule = 1, residu = seq(-1, 1, length.out = 40),
             stringsAsFactors = FALSE)
}

# Unites carrees de 200 m et serie FORMS-T 2019-2024 : hauteur de depart h0
# (m) et pente (m/an) par unite ; `chute` fait tomber la derniere annee.
forms_t4 <- function(h0, pente, chute = rep(FALSE, length(h0))) {
  n <- length(h0)
  r <- terra::rast(nrows = 20, ncols = 20 * n, xmin = 800000, xmax = 800000 + 200 * n,
                   ymin = 6600000, ymax = 6600200, crs = "EPSG:2154")
  col <- (seq_len(terra::ncell(r)) - 1L) %% (20 * n)
  u <- col %/% 20 + 1L
  couches <- lapply(2019:2024, function(a) {
    h <- h0[u] + pente[u] * (a - 2019)
    if (a == 2024) h[chute[u]] <- h[chute[u]] - 6
    terra::setValues(r, round(100 * h))
  })
  f <- terra::rast(couches)
  names(f) <- 2019:2024
  units <- sf::st_sf(id = seq_len(n), geometry = sf::st_sfc(lapply(seq_len(n), function(i) {
    x0 <- 800000 + 200 * (i - 1)
    sf::st_polygon(list(rbind(c(x0, 6600000), c(x0 + 200, 6600000), c(x0 + 200, 6600200),
                              c(x0, 6600200), c(x0, 6600000))))
  }), crs = 2154))
  list(units = units, forms = f)
}

test_that("T4 is NA with a status without FORMS-T", {
  skip_if_not_installed("sf")
  d <- forms_t4(20, 0.2)
  r <- suppressMessages(indicateur_t4_vitalite(d$units, essence = "09"))
  expect_true(is.na(r$T4))
  expect_equal(r$t4_status, "skipped_no_forms_t")
  expect_true(all(c("t4_accroissement_obs", "t4_accroissement_att", "t4_h_dom",
                    "t4_n_analogues") %in% names(r)))
})

test_that("T4 ranks the observed increment in the reference distribution", {
  skip_if_not_installed("exactextractr")
  local_mocked_bindings(.t4_analogues = ana_t4, .t4_residus = res_t4)
  # 0,2 m/an = 1 m en 5 ans (attendu) ; 0 (deficit) ; 0,5 (vigoureux)
  d <- forms_t4(c(20, 20, 20), c(0.2, 0, 0.5))
  r <- suppressMessages(indicateur_t4_vitalite(d$units, d$forms, essence = "09", ser = "C20"))
  expect_equal(r$t4_status, rep("calculated", 3))
  expect_equal(r$t4_accroissement_obs, c(1, 0, 2.5), tolerance = 0.02)
  expect_equal(r$t4_h_dom, rep(20, 3), tolerance = 0.01)
  expect_equal(r$t4_n_analogues, rep(30L, 3))   # 18, 20 et 22 m : |h - 20| <= 2
  expect_equal(r$t4_accroissement_att, rep(1, 3), tolerance = 0.05)
  expect_equal(r$T4[1], 50, tolerance = 2)
  expect_lt(r$T4[2], 5)
  expect_equal(r$T4[3], 100)
  expect_true(all(r$T4 >= 0 & r$T4 <= 100))
})

test_that("T4 is not scored after a cut, a fall or without species or analogues", {
  skip_if_not_installed("exactextractr")
  local_mocked_bindings(.t4_analogues = ana_t4, .t4_residus = res_t4)
  d <- forms_t4(c(20, 20, 20, 20, 35), rep(0.2, 5), chute = c(FALSE, TRUE, FALSE, FALSE, FALSE))
  d$units$T3 <- c(0, 0, 12, 0, 0)
  r <- suppressMessages(indicateur_t4_vitalite(
    d$units, d$forms, essence = c("09", "09", "09", NA, "09"), ser = "C20"))
  expect_equal(r$t4_status, c("calculated", "skipped_drop", "skipped_cut",
                              "skipped_no_essence", "skipped_no_analogues"))
  expect_true(all(is.na(r$T4[-1])))
  # coupes explicites l'emportent sur T3
  r2 <- suppressMessages(indicateur_t4_vitalite(d$units[1, ], d$forms, essence = "09",
                                                coupes = TRUE))
  expect_equal(r2$t4_status, "skipped_cut")
})

test_that("T4 reads species and SER columns and an own-inventory expectation", {
  skip_if_not_installed("exactextractr")
  local_mocked_bindings(.t4_analogues = ana_t4, .t4_residus = res_t4)
  d <- forms_t4(c(20, 30), c(0.2, 0.2))
  d$units$essence <- c("09", "zz")
  d$units$ser <- "C20"
  r <- suppressMessages(indicateur_t4_vitalite(d$units, d$forms))
  expect_equal(r$t4_status, c("calculated", "skipped_no_analogues"))
  # avec un inventaire simule pour l'unite 2, plus besoin d'analogues
  att <- data.frame(unite = 2, accroissement = c(0.9, 1, 1.1))
  r <- suppressMessages(indicateur_t4_vitalite(d$units, d$forms, attendu = att))
  expect_equal(r$t4_status, c("calculated", "calculated"))
  expect_true(is.na(r$t4_n_analogues[2]))
  expect_equal(r$T4[2], 50, tolerance = 2)
})

test_that("indicateur_t4_vitalite checks its inputs", {
  skip_if_not_installed("exactextractr")
  d <- forms_t4(c(20, 20), c(0.2, 0.2))
  expect_error(indicateur_t4_vitalite(d$units, d$forms, essence = c("09", "09", "09")),
               "one value per unit")
  expect_error(indicateur_t4_vitalite(d$units, d$forms, essence = "09", coupes = TRUE),
               "coupes")
  expect_error(indicateur_t4_vitalite(d$units, d$forms, essence = "09",
                                      attendu = data.frame(u = 1)), "attendu")
  f <- d$forms; names(f) <- letters[1:6]
  expect_error(suppressMessages(indicateur_t4_vitalite(d$units, f, essence = "09")),
               "named by year")
  expect_error(suppressMessages(indicateur_t4_vitalite(d$units, d$forms[[1:2]], essence = "09")),
               "three years")
})

test_that("analogues and residuals widen their window when too few", {
  a <- ana_t4()
  expect_equal(nrow(.t4_choisir_analogues(a, "09", "C20", 20, 2, 30)), 30L)
  # autre SER : toutes SER
  expect_equal(nrow(.t4_choisir_analogues(a, "09", "B52", 20, 2, 30)), 30L)
  # fenetre trop etroite : doublee (21 +/- 1,5 : 20 et 22 m, 20 placettes ;
  # 21 +/- 3 : les 40)
  expect_equal(nrow(.t4_choisir_analogues(a, "09", NA, 21, 1.5, 30)), 40L)
  expect_null(.t4_choisir_analogues(a, "09", "C20", 40, 2, 30))
  expect_null(.t4_choisir_analogues(a, "09", "C20", NA, 2, 30))

  r <- rbind(res_t4(), transform(res_t4(), essence = "03", h_dom = 30, residu = 5))
  expect_equal(.t4_choisir_residus(r, "09", 20, 2, 30), res_t4()$residu)
  # aucune placette de l'essence a cette hauteur : toutes essences a +/- 2 tol
  expect_equal(unique(.t4_choisir_residus(r, "62", 29, 2, 30)), 5)
  # rien a proximite : tous les residus
  expect_length(.t4_choisir_residus(r, "62", 50, 2, 30), 80L)
})

test_that("the embedded T4 tables are consistent", {
  a <- .t4_analogues()
  r <- .t4_residus()
  expect_true(all(c("placette", "ser", "essence", "g0", "h_dom", "a1") %in% names(a)))
  expect_gt(nrow(a), 3000)
  expect_true(all(r$placette %in% a$placette))
  expect_equal(r$residu, round(r$observe - r$simule, 3), tolerance = 0.002)
})
