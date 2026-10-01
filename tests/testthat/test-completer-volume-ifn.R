# Tests completer_volume_ifn() — supplétif P1 en NDP 0 (spec 040, D8).

.cv_units <- function(p1 = c(120, NA, NA), sp = c("FASY", "FASY", "PIAB")) {
  g <- sf::st_sfc(lapply(seq_along(p1), function(i) {
    x0 <- (i - 1) * 500
    sf::st_polygon(list(cbind(c(x0, x0 + 100, x0 + 100, x0, x0),
                              c(0, 0, 100, 100, 0))))
  }), crs = 2154)
  sf::st_sf(P1 = p1, species = sp, geometry = g)
}

test_that("only NA volumes are completed, measurements are untouched", {
  u <- .cv_units()
  out <- completer_volume_ifn(u)
  expect_equal(out$P1[1], 120)                 # mesure intacte
  expect_false(any(is.na(out$P1[2:3])))        # NA comblés
})

test_that("provenance is recorded row by row", {
  u <- .cv_units()
  out <- completer_volume_ifn(u)
  expect_true("volume_source" %in% names(out))
  expect_identical(out$volume_source[1], "mesure")
  expect_true(all(grepl("^ifn_", out$volume_source[2:3])))
})

test_that("the mesh level used appears in the provenance", {
  u <- .cv_units()
  out <- completer_volume_ifn(u, ser = "C20")
  expect_true(all(out$volume_source[2:3] %in%
                    c("ifn_ser", "ifn_greco", "ifn_national")))
})

test_that("a fully measured column is a no-op but still labelled", {
  u <- .cv_units(p1 = c(100, 200, 300))
  out <- completer_volume_ifn(u)
  expect_equal(out$P1, c(100, 200, 300))
  expect_true(all(out$volume_source == "mesure"))
})

test_that("an unresolvable species stays NA and warns", {
  u <- .cv_units(p1 = c(NA, NA, NA), sp = c("FASY", "ZZZZ", "ZZZZ"))
  expect_warning(out <- completer_volume_ifn(u), "resolves to no IFN")
  expect_false(is.na(out$P1[1]))
  expect_true(all(is.na(out$P1[2:3])))
  expect_true(all(is.na(out$volume_source[2:3])))
})

test_that("mesure=present gives a stand figure, well above maille", {
  u <- .cv_units(p1 = c(NA, NA, NA))
  a <- completer_volume_ifn(u, mesure = "present")
  b <- completer_volume_ifn(u, mesure = "maille")
  expect_true(all(a$P1 > b$P1))
})

test_that("missing columns are reported explicitly", {
  u <- .cv_units(); u$P1 <- NULL
  expect_error(completer_volume_ifn(u), "P1")
  u2 <- .cv_units(); u2$species <- NULL
  expect_error(completer_volume_ifn(u2), "species")
})

test_that("a non-sf input is refused", {
  expect_error(completer_volume_ifn(data.frame(P1 = 1)), "sf object")
})

# --- Mode Fay-Herriot (spec 054 lot 3) ---------------------------------------

test_that("the Fay-Herriot volume table is positive and agrees with the direct", {
  fh <- nemeton:::.ifn_vol_fh_table()
  expect_true(all(c("ser", "espar", "n_plac_presence", "direct", "psi",
                    "psi_source", "estimation", "mse", "rse", "gamma",
                    "nature") %in% names(fh)))
  expect_true(is.character(fh$espar))
  expect_true("09" %in% fh$espar)     # zero non significatif conserve
  f <- fh[fh$nature == "fay_herriot", ]
  expect_gt(nrow(f), 4000)
  # Echelle log : aucun volume negatif (45 en lineaire, spec 054 §7.3).
  expect_true(all(f$estimation > 0))
  # Le direct est exactement vol_ha_present de la spec 040.
  v <- ifn_volume_essence_ser(niveau = "ser")
  m <- merge(fh, v, by = c("ser", "espar"))
  expect_equal(m$direct, m$vol_ha_present, tolerance = 1e-3)
  # Pas de biais d'ensemble : moyenne ponderee a 2 % du direct.
  expect_equal(weighted.mean(f$estimation, f$n_plac_presence),
               weighted.mean(f$direct, f$n_plac_presence), tolerance = 0.02)
})

test_that("fay_herriot keeps a thin SER instead of jumping to the GRECO", {
  # Epicea en B22 : 6 placettes -> la cascade prend la GRECO.
  casc <- ifn_volume_reference("62", ser = "B22")
  expect_equal(casc$niveau_utilise, "greco")
  fh <- ifn_volume_reference("62", ser = "B22", methode = "fay_herriot")
  expect_equal(fh$niveau_utilise, "ser")
  expect_equal(fh$nature, "fay_herriot")
  expect_true(is.finite(fh$rse))
  # Essence absente de la SER : la cascade reste.
  abs61 <- ifn_volume_reference("61", ser = "B22", methode = "fay_herriot")
  expect_equal(abs61$nature, "cascade")
  expect_equal(abs61$vol_ha, ifn_volume_reference("61", ser = "B22")$vol_ha)
  # Sans SER, ou en mesure "maille" : pas de Fay-Herriot.
  expect_true(all(ifn_volume_reference("09", methode = "fay_herriot")$nature == "cascade"))
  expect_error(ifn_volume_reference("09", ser = "B22", mesure = "maille",
                                    methode = "fay_herriot"), "stand-level")
  # Le defaut ne change pas de forme.
  expect_false("nature" %in% names(ifn_volume_reference("09", ser = "B22")))
})

test_that("completer_volume_ifn writes ifn_fh_ser and never overwrites a measure", {
  u <- sf::st_sf(data.frame(P1 = c(250, NA), species = c("FASY", "PIAB")),
                 geometry = sf::st_sfc(sf::st_point(c(0, 0)), sf::st_point(c(1, 1)),
                                       crs = 2154))
  r <- suppressMessages(completer_volume_ifn(u, ser = "B22", methode = "fay_herriot"))
  expect_equal(r$volume_source, c("mesure", "ifn_fh_ser"))
  expect_equal(r$P1[1], 250)
  expect_equal(r$P1[2], ifn_volume_reference("62", ser = "B22", methode = "fay_herriot")$vol_ha)
  r0 <- suppressMessages(completer_volume_ifn(u, ser = "B22"))
  expect_equal(r0$volume_source, c("mesure", "ifn_greco"))
})
