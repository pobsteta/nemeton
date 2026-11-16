# Couche vide (le WFS a repondu, 0 objet) = mesure ; couche NULL = NA.
# Brief nemetonshiny 2026-11-15 « S1 et S2 : une couche routes ou bati vide
# est une mesure » (since 2026.11.32).

unite_test <- function() {
  sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0),
                                 ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )
}

couche_vide <- function() {
  sf::st_sf(id = integer(0), geometry = sf::st_sfc(crs = 2154))
}

test_that("S1/S2: an empty layer gives max_dist even without a DEM", {
  u <- unite_test()
  s1 <- suppressMessages(indicateur_s1_routes(u, roads = couche_vide(),
                                              max_dist = 1500))
  s2 <- suppressMessages(indicateur_s2_bati(u, buildings = couche_vide()))
  expect_equal(s1$S1, 1500)
  expect_equal(s2$S2, 2000)
})

test_that("S1/S2: a missing (NULL) layer stays NA", {
  skip_if_not_installed("terra")
  u <- unite_test()
  dem <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     resolution = 10, crs = "EPSG:2154")
  terra::values(dem) <- 50
  s1 <- suppressMessages(indicateur_s1_routes(u, roads = NULL, dem = dem))
  s2 <- suppressMessages(indicateur_s2_bati(u, buildings = NULL, dem = dem))
  expect_true(is.na(s1$S1))
  expect_true(is.na(s2$S2))
})

test_that("S1: an empty layer is no longer reported as unavailable", {
  expect_message(indicateur_s1_routes(unite_test(), roads = couche_vide()),
                 "empty")
})

test_that("N1: empty layers score 100, NULL layers stay NA", {
  u <- unite_test()
  vide <- suppressMessages(indicateur_n1_distance(u, roads = couche_vide(),
                                                  buildings = couche_vide()))
  expect_equal(vide$N1, 100)
  absent <- suppressMessages(indicateur_n1_distance(u, roads = NULL,
                                                    buildings = couche_vide()))
  expect_true(is.na(absent$N1))
})

test_that("A2 (proxy): an empty roads layer scores 100, without error", {
  u <- unite_test()
  vide <- sf::st_sf(nature = character(0), geometry = sf::st_sfc(crs = 2154))
  r <- suppressMessages(indicateur_a2_qualite_air(u, roads = vide))
  expect_equal(r$A2, 100)
})
