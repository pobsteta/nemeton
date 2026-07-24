# Gating du flag biophysical_s2 (spec 043 D6, ADR-015).

test_that("les quatre conditions doivent toutes tenir", {
  g <- biophys_gating(n_obs = c(5, 2, 8, 6),
                      pct_masked = c(0.2, 0.1, 0.6, 0.3),
                      oob_frac = c(0.02, 0.01, 0.03, 0.20),
                      area_px = c(40, 30, 100, 40))
  # 1: OK ; 2: n_obs<3 ; 3: pct_masked>0.4 ; 4: oob_frac>0.10
  expect_equal(g, c(TRUE, FALSE, FALSE, FALSE))
})

test_that("chaque seuil rejette isolément", {
  base <- list(n_obs = 5, pct_masked = 0.2, oob_frac = 0.02, area_px = 40)
  ok <- function(mod = list()) {
    a <- modifyList(base, mod)
    biophys_gating(a$n_obs, a$pct_masked, a$oob_frac, a$area_px)
  }
  expect_true(ok())
  expect_false(ok(list(n_obs = 2)))       # < 3
  expect_false(ok(list(pct_masked = 0.5)))# > 0.4
  expect_false(ok(list(oob_frac = 0.2)))  # > 0.10
  expect_false(ok(list(area_px = 10)))    # < 25
})

test_that("fail-closed : toute métrique NA -> FALSE", {
  expect_false(biophys_gating(NA, 0.2, 0.02, 40))
  expect_false(biophys_gating(5, NA, 0.02, 40))
  expect_false(biophys_gating(5, 0.2, NA, 40))
  expect_false(biophys_gating(5, 0.2, 0.02, NA))
})

test_that("les seuils par défaut sont ceux du gating", {
  th <- biophys_gating_thresholds()
  expect_equal(th$n_obs_min, 3L)
  expect_equal(th$pct_masked_max, 0.40)
  expect_equal(th$oob_frac_max, 0.10)
  expect_equal(th$area_px_min, 25L)
})

test_that("les seuils sont surchargeables", {
  th <- biophys_gating_thresholds(); th$n_obs_min <- 6L
  expect_false(biophys_gating(5, 0.2, 0.02, 40, thresholds = th))
  expect_true(biophys_gating(6, 0.2, 0.02, 40, thresholds = th))
})

test_that("longueurs incohérentes et thresholds invalide -> erreur", {
  expect_error(biophys_gating(c(5, 6), 0.2, 0.02, 40), "same length")
  expect_error(biophys_gating(5, 0.2, 0.02, 40, thresholds = list(x = 1)),
               "must contain")
})

test_that("vectorisé sur plusieurs unités", {
  g <- biophys_gating(n_obs = rep(5, 3), pct_masked = rep(0.1, 3),
                      oob_frac = rep(0.01, 3), area_px = c(10, 25, 100))
  expect_equal(g, c(FALSE, TRUE, TRUE))   # area_px : 10<25, 25>=25, 100
})
