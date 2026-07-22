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
