# Tests ifn_production_domaines() — spec 054 lot 5 (estimateur composite).

domaine_ser <- function(code) {
  pl <- nemeton:::.ifn_prod_placettes()
  p <- pl[pl$ser == code & pl$echantillon == "vif", ]
  pts <- sf::st_as_sf(p, coords = c("xl", "yl"), crs = 2154)
  # Disques de 600 m autour des centres de maille (grille de 1 km) : le domaine
  # contient exactement les placettes de la SER, sans celles des voisines.
  sf::st_sf(id = code, geometry = sf::st_union(sf::st_buffer(pts, 600)))
}

test_that("the embedded tables are there and coherent", {
  pl <- nemeton:::.ifn_prod_placettes()
  expect_true(all(c("campagne", "xl", "yl", "ser", "echantillon", "pg", "pv") %in% names(pl)))
  expect_setequal(unique(pl$echantillon), c("vif", "coupe"))
  expect_false(anyNA(pl$xl))
  m <- nemeton:::.ifn_prod_modele()
  expect_setequal(m$attribut, c("pg", "pv"))
  expect_true(all(m$sigma2_v > 0))
})

test_that("a large domain keeps its own plots and lands near its SER", {
  d <- domaine_ser("C30")
  r <- ifn_production_domaines(d, id_col = "id")
  ref <- ifn_production_reference("C30")
  expect_equal(r$nature, "composite")
  expect_gt(r$n_placettes, 300)
  expect_gt(r$poids_direct, 0.5)            # beaucoup de placettes : le direct pese
  expect_equal(r$valeur, ref$valeur, tolerance = 0.15)
  expect_true(r$rse > 0 && r$rse < 10)
  expect_equal(r$ser, "C30:1.00")
  det <- attr(r, "detail")
  expect_equal(nrow(det), 5L)
  expect_true(all(det$gamma >= 0 & det$gamma <= 1))
  expect_equal(det$estimation, det$gamma * det$direct + (1 - det$gamma) * det$ser)
})

test_that("a small domain leans on its SER (generalised variance, not 2-plot psi)", {
  d <- domaine_ser("C30")
  c0 <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(d)))
  ut <- sf::st_sf(id = "ut", geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c0[1, ]), 6000, endCapStyle = "SQUARE"), crs = 2154))
  r <- ifn_production_domaines(ut)
  expect_lt(r$poids_direct, 0.5)
  expect_equal(r$surface_ha, 14400, tolerance = 1e-6)
  expect_true(r$part_bordure >= 0 && r$part_bordure <= 1)
  det <- attr(r, "detail")
  # Aucune campagne ne donne tout le poids a deux placettes.
  expect_true(all(det$gamma[det$n_vif <= 3] < 0.5))
})

test_that("a domain without plots takes its SER, through the outlines", {
  d <- domaine_ser("C30")
  c0 <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(d)))[1, ]
  # 100 m x 100 m : aucune placette, SER fournie par une couche jouet.
  mini <- sf::st_sf(id = "mini", geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c0), 50, endCapStyle = "SQUARE"), crs = 2154))
  couche <- sf::st_sf(codeser = "C30", geometry = sf::st_geometry(d))
  r <- ifn_production_domaines(mini, ser_layer = couche)
  expect_equal(r$n_placettes, 0L)
  expect_equal(r$nature, "ser")
  expect_equal(r$poids_direct, 0)
  s <- ifn_production_ser(ser = "C30", attribut = "pv", groupe = "tous",
                          campagne = as.integer(strsplit(r$campagnes, ",")[[1]]))
  expect_equal(r$valeur, mean(s$estimation))
})

test_that("inputs are validated", {
  expect_error(ifn_production_domaines(data.frame(x = 1)), "sf object")
  d <- domaine_ser("C30")
  expect_error(ifn_production_domaines(d, id_col = "absente"), "absente")
  expect_error(ifn_production_domaines(d, campagnes = 1990), "No campaign")
  expect_equal(ifn_production_domaines(d, attribut = "pg")$attribut, "pg")
})
