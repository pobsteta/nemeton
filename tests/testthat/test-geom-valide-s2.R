# test-geom-valide-s2.R — géométrie valide pour GEOS mais rejetée par s2
# (brief nemetonshiny 2026-10-18, RECONFORT Couchey zone 63). Deux arêtes quasi
# colinéaires, à 0,5 mm l'une de l'autre sur 2 km, se croisent une fois
# projetées sur la sphère ; st_make_valid() en L93 ne le voit pas.

# Polygone L93 (Côte-d'Or) : sommet dupliqué + écharde de 0,5 mm le long d'une
# arête de 2 km.
.poly_echarde <- function() {
  d <- 5e-4; L <- 2000
  m <- rbind(c(0, 0), c(L, 0), c(L, d), c(L / 2, d), c(L / 2, d),
             c(L / 4, 2 * d), c(0, 500), c(0, 0))
  m[, 1] <- m[, 1] + 860000
  m[, 2] <- m[, 2] + 6680000
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(m)), crs = 2154))
}

.s2_valide <- function(g) {
  all(s2::s2_is_valid(sf::st_transform(sf::st_geometry(g), 4326)))
}

test_that("le cas de test reproduit le défaut : valide GEOS, invalide s2", {
  g <- .poly_echarde()
  expect_false(.s2_valide(g))
  r <- sf::st_make_valid(g)                           # réparation d'avant
  expect_true(all(sf::st_is_valid(r)))
  expect_false(.s2_valide(r))
})

test_that(".geom_valide_s2 arrondit à 1 cm et rend une géométrie valide pour s2", {
  g <- .poly_echarde()
  r <- nemeton:::.geom_valide_s2(sf::st_geometry(g))
  expect_true(all(sf::st_is_valid(r)))
  expect_true(.s2_valide(r))
  expect_equal(as.numeric(sum(sf::st_area(r))),
               as.numeric(sum(sf::st_area(sf::st_make_valid(g)))),
               tolerance = 1e-4)                      # écharde ~1 m² sur 12,5 ha
  # CRS géographique : st_make_valid() seul, sans arrondi en degrés.
  ll <- sf::st_transform(sf::st_geometry(g), 4326)
  expect_true(all(sf::st_is_valid(nemeton:::.geom_valide_s2(ll))))
})

test_that("reconfort_aoi_tiles résout les tuiles d'une AOI rejetée par s2", {
  tiles <- suppressMessages(reconfort_aoi_tiles(.poly_echarde()))
  expect_true(length(tiles) >= 1L)
  expect_true(all(grepl("^T3[01][A-Z]{3}$", tiles)))
})

test_that("reconfort_aoi_tiles retombe sur une intersection plane en dernier recours", {
  # Réparation sans arrondi : s2 lève encore, la voie plane doit répondre.
  testthat::local_mocked_bindings(
    .geom_valide_s2 = function(geom, precision = 100) sf::st_make_valid(geom),
    .package = "nemeton")
  old <- sf::sf_use_s2()
  tiles <- suppressMessages(reconfort_aoi_tiles(.poly_echarde()))
  expect_true(length(tiles) >= 1L)
  expect_identical(sf::sf_use_s2(), old)              # réglage s2 restauré
})

test_that(".get_zone_aoi répare à la lecture une zone écrite invalide", {
  wkt <- sf::st_as_text(sf::st_geometry(.poly_echarde())[[1L]])
  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) {
      data.frame(id = 63L, zone_wkt = wkt, crs_epsg = 2154L,
                 stringsAsFactors = FALSE)
    },
    .package = "DBI")
  con <- structure(list(), class = c("FakeConnection", "DBIConnection"))
  aoi <- nemeton:::.get_zone_aoi(con, 63L)
  expect_identical(sf::st_crs(aoi)$epsg, 2154L)
  expect_true(all(sf::st_is_valid(aoi)))
  expect_true(.s2_valide(aoi))
})

test_that(".zone_wkt_4326 n'écrit plus de zone invalide pour s2", {
  wkt <- nemeton:::.zone_wkt_4326(.poly_echarde())
  g <- sf::st_as_sfc(wkt, crs = 4326)
  expect_true(all(s2::s2_is_valid(g)))
})
