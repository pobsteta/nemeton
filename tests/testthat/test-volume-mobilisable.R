# Tests volume_mobilisable() — spec 040, jalon « taux saisi ».

# Deux carrés en Lambert-93 : 2 ha et 1 ha, même P1.
.vm_units <- function(p1 = c(100, 100)) {
  carre <- function(x0, cote) {
    sf::st_polygon(list(cbind(
      c(x0, x0 + cote, x0 + cote, x0, x0),
      c(0, 0, cote, cote, 0)
    )))
  }
  # cote 141.42 m -> 2 ha ; cote 100 m -> 1 ha
  g <- sf::st_sfc(carre(0, sqrt(2e4)), carre(1000, 100), crs = 2154)
  sf::st_sf(P1 = p1, geometry = g)
}

test_that("m3_total multiplies the density by the area", {
  u <- .vm_units(c(100, 100))
  out <- volume_mobilisable(u, taux_prelevement = 1, horizon_ans = 1)
  # 100 m3/ha x 1 x 1 an x 2 ha = 200 ; x 1 ha = 100
  expect_equal(out$volume_mobilisable, c(200, 100), tolerance = 1e-6)
})

test_that("m3_ha is independent of the area", {
  u <- .vm_units(c(100, 100))
  out <- volume_mobilisable(u, unite = "m3_ha",
                            taux_prelevement = 1, horizon_ans = 1)
  expect_equal(out$volume_mobilisable, c(100, 100), tolerance = 1e-6)
})

test_that("the two units differ exactly by the area ratio (spec 040 §3)", {
  # Non-régression du piège central : servir m3_total à reseau_desserte()
  # surpondérerait la grande parcelle.
  u <- .vm_units(c(100, 100))
  tot <- volume_mobilisable(u, unite = "m3_total",
                            taux_prelevement = 2, horizon_ans = 5)
  den <- volume_mobilisable(u, unite = "m3_ha",
                            taux_prelevement = 2, horizon_ans = 5)
  expect_equal(den$volume_mobilisable[1], den$volume_mobilisable[2])
  expect_equal(tot$volume_mobilisable[1] / tot$volume_mobilisable[2], 2,
               tolerance = 1e-6)
})

test_that("the rate is a yearly flux: the horizon scales the result", {
  u <- .vm_units(c(50, 50))
  a <- volume_mobilisable(u, unite = "m3_ha", taux_prelevement = 3,
                          horizon_ans = 1)
  b <- volume_mobilisable(u, unite = "m3_ha", taux_prelevement = 3,
                          horizon_ans = 10)
  expect_equal(b$volume_mobilisable, a$volume_mobilisable * 10)
})

test_that("a per-unit rate vector is applied element-wise", {
  u <- .vm_units(c(100, 100))
  out <- volume_mobilisable(u, unite = "m3_ha",
                            taux_prelevement = c(1, 4), horizon_ans = 2)
  expect_equal(out$volume_mobilisable, c(200, 800), tolerance = 1e-6)
})

test_that("a rate vector of the wrong length is rejected", {
  u <- .vm_units()
  expect_error(
    volume_mobilisable(u, taux_prelevement = c(1, 2, 3), horizon_ans = 1),
    "length 1 or 2"
  )
})

test_that("the deferred IFN table errors instead of inventing figures", {
  u <- .vm_units()
  expect_error(volume_mobilisable(u, horizon_ans = 1), "taux_prelevement")
})

test_that("a rate without a horizon is refused", {
  u <- .vm_units()
  expect_error(volume_mobilisable(u, taux_prelevement = 4), "horizon_ans")
})

test_that("a negative or non-numeric rate is refused", {
  u <- .vm_units()
  expect_error(volume_mobilisable(u, taux_prelevement = -1, horizon_ans = 1),
               "non-negative")
  expect_error(volume_mobilisable(u, taux_prelevement = "4", horizon_ans = 1),
               "numeric")
})

test_that("na_policy governs missing P1", {
  u <- .vm_units(c(100, NA))

  expect_warning(
    out <- volume_mobilisable(u, unite = "m3_ha", taux_prelevement = 1,
                              horizon_ans = 1),
    "stays NA"
  )
  expect_true(is.na(out$volume_mobilisable[2]))

  expect_warning(
    z <- volume_mobilisable(u, unite = "m3_ha", taux_prelevement = 1,
                            horizon_ans = 1, na_policy = "zero"),
    "nothing to haul"
  )
  expect_equal(z$volume_mobilisable[2], 0)

  expect_error(
    volume_mobilisable(u, unite = "m3_ha", taux_prelevement = 1,
                       horizon_ans = 1, na_policy = "error"),
    "na_policy"
  )
})

test_that("m3_total refuses a geographic CRS but m3_ha does not need one", {
  u <- sf::st_transform(.vm_units(c(100, 100)), 4326)
  expect_error(
    volume_mobilisable(u, taux_prelevement = 1, horizon_ans = 1),
    "geographic CRS"
  )
  expect_silent(
    volume_mobilisable(u, unite = "m3_ha", taux_prelevement = 1,
                       horizon_ans = 1)
  )
})

test_that("a missing volume column is reported with a pointer to P1", {
  u <- .vm_units()
  u$P1 <- NULL
  expect_error(volume_mobilisable(u, taux_prelevement = 1, horizon_ans = 1),
               "not found")
})

test_that("column_name is honoured and units is returned as sf", {
  u <- .vm_units()
  out <- volume_mobilisable(u, taux_prelevement = 1, horizon_ans = 1,
                            column_name = "vol_desserte")
  expect_s3_class(out, "sf")
  expect_true("vol_desserte" %in% names(out))
})

test_that("a non-sf input is refused", {
  expect_error(volume_mobilisable(data.frame(P1 = 1), taux_prelevement = 1,
                                  horizon_ans = 1),
               "sf object")
})
