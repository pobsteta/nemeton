# test-regeneration-index.R — composite regeneration potential (spec 027 L3)
#
# Pure in-memory sf with precomputed sub-indicator columns — no microclimf,
# no raster, no network.

.regen_units <- function(A3 = 80, A4 = 60, W4 = 70, R6 = 50,
                         A3_tmax = 26, W4_vpd = 1.5, n = 1L) {
  g <- lapply(seq_len(n), function(i) {
    x <- (i - 1) * 10
    sf::st_polygon(list(rbind(c(x, 0), c(x + 5, 0),
                              c(x + 5, 5), c(x, 5), c(x, 0))))
  })
  sf::st_sf(
    id = seq_len(n),
    A3 = rep(A3, length.out = n), A4 = rep(A4, length.out = n),
    W4 = rep(W4, length.out = n), R6 = rep(R6, length.out = n),
    A3_tmax = rep(A3_tmax, length.out = n),
    W4_vpd = rep(W4_vpd, length.out = n),
    geometry = sf::st_sfc(g, crs = 2154)
  )
}


test_that("generic index is the equiponderated mean of present components", {
  u <- .regen_units(A3 = 80, A4 = 60, W4 = 70, R6 = 50)
  out <- regeneration_index(u)                       # no species -> no penalty
  expect_equal(out$regeneration_potentiel[[1]], 65, tolerance = 1e-6)  # mean(80,60,70,50)
  expect_equal(out$regeneration_essence[[1]], "generique")
})

test_that("class breaks map potential to favorable / marginal / defavorable", {
  expect_equal(
    regeneration_index(.regen_units(A3 = 90, A4 = 90, W4 = 90, R6 = 90))$regeneration_classe[[1]],
    "favorable")
  expect_equal(
    regeneration_index(.regen_units(A3 = 50, A4 = 50, W4 = 50, R6 = 50))$regeneration_classe[[1]],
    "marginal")
  expect_equal(
    regeneration_index(.regen_units(A3 = 10, A4 = 10, W4 = 10, R6 = 10))$regeneration_classe[[1]],
    "defavorable")
})

test_that("custom weights override the equal weighting", {
  u <- .regen_units(A3 = 100, A4 = 0, W4 = 0, R6 = 0)
  out <- regeneration_index(u, weights = c(A3 = 1, A4 = 0, W4 = 0, R6 = 0))
  expect_equal(out$regeneration_potentiel[[1]], 100, tolerance = 1e-6)
})

test_that("missing components are skipped, weights renormalised", {
  u <- .regen_units(A3 = 80, W4 = 60)[, c("id", "A3", "W4", "A3_tmax", "W4_vpd")]
  # only A3, W4 present -> mean(80, 60) = 70
  out <- regeneration_index(u)
  expect_equal(out$regeneration_potentiel[[1]], 70, tolerance = 1e-6)
})

test_that("all components absent -> NA potential + warning", {
  u <- .regen_units()[, c("id")]
  expect_warning(out <- regeneration_index(u), "none of")
  expect_true(is.na(out$regeneration_potentiel[[1]]))
  expect_true(is.na(out$regeneration_classe[[1]]))
})

test_that("species tolerance penalises a hot/dry microsite for a mesophile", {
  # A3_tmax 34°C, VPD 3.0 kPa: well above beech tolerance (28°C / 1.8 kPa).
  u <- .regen_units(A3 = 80, A4 = 80, W4 = 80, R6 = 80,
                    A3_tmax = 34, W4_vpd = 3.0)
  beech <- regeneration_index(u, species = "essence_hetraie")
  oak   <- regeneration_index(u, species = "essence_chene_vert")
  # Same microsite: thermophilic holm oak keeps a higher potential than beech.
  expect_lt(beech$regeneration_potentiel[[1]], oak$regeneration_potentiel[[1]])
  expect_equal(oak$regeneration_essence[[1]], "essence_chene_vert")
})

test_that("within tolerance, species penalty is zero (matches generic)", {
  # Cool, moist microsite: below every species threshold.
  u <- .regen_units(A3 = 80, A4 = 70, W4 = 75, R6 = 65,
                    A3_tmax = 22, W4_vpd = 1.0)
  gen  <- regeneration_index(u)$regeneration_potentiel[[1]]
  hetr <- regeneration_index(u, species = "essence_hetraie")$regeneration_potentiel[[1]]
  expect_equal(gen, hetr, tolerance = 1e-6)
})

test_that("a single-species tolerances override is honoured", {
  u <- .regen_units(A3 = 80, A4 = 80, W4 = 80, R6 = 80,
                    A3_tmax = 40, W4_vpd = 1.0)
  # Custom threshold 30°C, exceeded by 10 -> full thermal penalty -> ~0.
  out <- regeneration_index(u, species = "custom",
                            tolerances = list(tmax_tol_c = 30, vpd_tol_kpa = 5))
  expect_equal(out$regeneration_potentiel[[1]], 0, tolerance = 1e-6)
})

test_that("regeneration_tolerances() ships every species class", {
  tol <- regeneration_tolerances()
  expect_true(all(c("code", "tmax_tol_c", "vpd_tol_kpa") %in% names(tol)))
  expect_setequal(tol$code, list_species_classes()$code)
  expect_true(all(tol$tmax_tol_c > 20 & tol$tmax_tol_c < 45))
})
