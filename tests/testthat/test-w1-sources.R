# W1 : les sources comptent dans le bonus de proximité (brief nemetonmcp
# 2026-11-16, Couchey : côte calcaire sans réseau de surface).

.w1s_layers <- function(vectors) {
  structure(list(rasters = list(), vectors = vectors, cache_dir = tempdir(),
                 metadata = list(validated = FALSE)), class = "nemeton_layers")
}
.w1s_carre <- function(x0, y0 = 0, cote = 100) {
  sf::st_polygon(list(rbind(c(x0, y0), c(x0 + cote, y0), c(x0 + cote, y0 + cote),
                            c(x0, y0 + cote), c(x0, y0))))
}
.w1s_units <- function() {
  sf::st_sf(id = 1:3, geometry = sf::st_sfc(.w1s_carre(0), .w1s_carre(1000),
                                            .w1s_carre(3000), crs = 2154))
}
# Un seul tronçon, loin de tout (à > 500 m de chaque UGF).
.w1s_cours <- function() {
  sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_linestring(rbind(c(0, 5000), c(4000, 5000))), crs = 2154))
}
.w1s_points <- function(xy, nature, etat = rep("En service", length(nature))) {
  sf::st_sf(nature = nature, etat_de_l_objet = etat,
            geometry = sf::st_sfc(lapply(xy, sf::st_point), crs = 2154))
}

test_that("without a spring layer W1 is unchanged", {
  l <- .w1s_layers(vectors = list(water_network = .w1s_cours()))
  r <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l))
  expect_equal(r$W1, c(0, 0, 0))
})

test_that("a spring gives the proximity bonus, inside the unit the full bonus", {
  pts <- .w1s_points(list(c(50, 50),      # dans l'UGF 1
                          c(1200, 50)),   # à 100 m de l'UGF 2
                     c("Source", "Résurgence"))
  l <- .w1s_layers(vectors = list(water_network = .w1s_cours(), water_points = pts))
  r <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l))
  expect_equal(r$W1, c(50, (1 - 100 / 500) * 50, 0))
})

test_that("fountains, wash-houses, sinkholes and works not in service are ignored", {
  pts <- .w1s_points(list(c(50, 50), c(60, 50), c(70, 50), c(80, 50)),
                     c("Fontaine", "Lavoir", "Perte", "Source captée"),
                     etat = c("En service", "En service", "En service", "En projet"))
  l <- .w1s_layers(vectors = list(water_network = .w1s_cours(), water_points = pts))
  r <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l))
  expect_equal(r$W1, c(0, 0, 0))
})

test_that("springs never add to the density, and the nearest object wins", {
  # UGF 1 traversée par un cours d'eau : bonus plein + densité, la source ne
  # change rien.
  cours <- sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_linestring(rbind(c(-10, 50), c(110, 50))), crs = 2154))
  pts <- .w1s_points(list(c(20, 20), c(1050, 300)), c("Source", "Source"))
  l0 <- .w1s_layers(vectors = list(water_network = cours))
  l1 <- .w1s_layers(vectors = list(water_network = cours, water_points = pts))
  r0 <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l0))
  r1 <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l1))
  expect_equal(r1$W1[1], r0$W1[1])
  # UGF 2 : source à 200 m (le cours d'eau est à 890 m).
  expect_equal(r1$W1[2], (1 - 200 / 500) * 50)
})

test_that("a spring layer without a nature column is kept as is; a missing network stays NA", {
  pts <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_point(c(3050, 50)), crs = 2154))
  l <- .w1s_layers(vectors = list(water_network = .w1s_cours(), water_points = pts))
  r <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l))
  expect_equal(r$W1, c(0, 0, 50))
  # Sans réseau hydrographique, W1 reste « non mesuré », même avec des sources.
  l2 <- .w1s_layers(vectors = list(water_points = pts))
  r2 <- suppressWarnings(suppressMessages(indicateur_w1_reseau(.w1s_units(), l2)))
  expect_true(all(is.na(r2$W1)))
})

test_that("springs in another CRS are reprojected", {
  pts <- sf::st_transform(.w1s_points(list(c(50, 50)), "Source"), 4326)
  l <- .w1s_layers(vectors = list(water_network = .w1s_cours(), water_points = pts))
  r <- suppressMessages(indicateur_w1_reseau(.w1s_units(), l))
  expect_equal(r$W1[1], 50)
})
