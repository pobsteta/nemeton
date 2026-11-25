# Masques chenaie et coupes rases du spike RECONFORT.

r_const <- function(val, xmin = 0, xmax = 4) {
  terra::rast(nrows = 2, ncols = 2, xmin = xmin, xmax = xmax, ymin = 0, ymax = 4,
              crs = "EPSG:2154", vals = val)
}

test_that("YYDDD : aller-retour date <-> code", {
  d <- reconfort_coupe_decoder(c(21150, 0, NA, 99366, 1001))
  expect_equal(d$annee, c(2021L, NA, NA, 2099L, 2001L))
  expect_equal(d$jour, c(150L, NA, NA, 366L, 1L))
  expect_equal(d$date[1], as.Date("2021-05-30"))
  dates <- as.Date(c("2021-05-30", "2020-12-31", "2024-02-29", "2000-01-01"))
  expect_equal(reconfort_coupe_decoder(reconfort_coupe_encoder(dates))$date, dates)
  expect_equal(reconfort_coupe_encoder(as.Date("2021-05-30")), 21150)
  expect_error(reconfort_coupe_decoder(21400), "1..366")
  expect_error(reconfort_coupe_decoder(21000 + 0.5), "Invalid")
})

test_that("cas 4 : pixel coupe en 2021 (21150) garde en 2020, retire en 2021 et apres", {
  px <- data.frame(x = 1, y = 1, annee = 2019:2023)
  out <- reconfort_masquer(px, coupes = r_const(21150))
  expect_equal(out$annee, 2019:2020)
  ret <- attr(out, "retires")
  expect_equal(ret$annee, 2021:2023)
  expect_true(all(ret$motif == "coupe_rase"))
})

test_that("un pixel sans coupe (0 ou NA) n'est jamais retire", {
  # grille 2x2 sur [0,4]^2, cellules dans l'ordre : haut-gauche 21150, haut-droite 0,
  # bas-gauche NA, bas-droite 0
  coupes <- r_const(c(21150, 0, NA, 0))
  px <- data.frame(x = c(1, 3, 1, 3), y = c(3, 3, 1, 1), annee = 2022L)
  out <- reconfort_masquer(px, coupes = coupes)
  expect_equal(out$x, c(3, 1, 3))
  expect_equal(out$y, c(3, 1, 1))
})

test_that("hors chenaie : retire (raster et polygones)", {
  px <- data.frame(x = c(1, 3), y = c(3, 3), annee = 2022L)
  # raster : cellule de gauche = chenaie (1), cellule de droite = 0
  ch <- r_const(c(1, 0, 1, 1))
  out <- reconfort_masquer(px, chenaie = ch)
  expect_equal(out$x, 1)
  expect_equal(attr(out, "retires")$motif, "hors_chenaie")

  poly <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(
    cbind(c(0, 2, 2, 0, 0), c(2, 2, 4, 4, 2)))), crs = 2154))
  out2 <- reconfort_masquer(px, chenaie = poly)
  expect_equal(out2$x, 1)
})

test_that("coupes en polygones sf au format SUFOSAT (date_coupe YYDDD)", {
  px <- data.frame(x = 1, y = 1, annee = 2020:2022)
  sq <- function(code) sf::st_polygon(list(cbind(c(0, 2, 2, 0, 0), c(0, 0, 2, 2, 0))))
  poly <- sf::st_sf(date_coupe = c(22010, 21150),
                    geometry = sf::st_sfc(sq(1), sq(2), crs = 2154))
  out <- reconfort_masquer(px, coupes = poly)
  # la plus ancienne coupe compte (2021)
  expect_equal(out$annee, 2020L)
  expect_error(reconfort_masquer(px, coupes = sf::st_sf(a = 1, geometry = poly$geometry[1])),
               "date_coupe")
})

test_that("masques combines et entree invalide", {
  px <- data.frame(x = c(1, 3), y = c(1, 1), annee = 2022L)
  out <- reconfort_masquer(px, chenaie = r_const(c(1, 1, 1, 0)), coupes = r_const(0))
  expect_equal(nrow(out), 1L)
  expect_error(reconfort_masquer(data.frame(a = 1)), "x")
  expect_error(reconfort_masquer(px, chenaie = "oups"), "SpatRaster")
  expect_equal(nrow(reconfort_masquer(px)), 2L)
})
