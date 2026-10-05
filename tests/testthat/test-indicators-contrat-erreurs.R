# Contrat d'erreur des indicateurs (audit 1.0, constat transverse) : les
# erreurs de validation des arguments passent toutes par cli::cli_abort(),
# donc portent la classe `rlang_error` (et non une simpleError de stop()).

test_that("indicator argument errors are rlang errors (cli_abort)", {
  pas_sf <- data.frame(x = 1)
  fns <- c(
    "indicateur_a5_rafraichissement", "indicateur_e1_bois_energie",
    "indicateur_e2_evitement", "indicateur_c1_biomasse",
    "indicateur_c2_ndvi", "indicateur_w1_reseau",
    "indicateur_w2_zones_humides", "indicateur_w3_humidite",
    "indicateur_f1_fertilite", "indicateur_f2_erosion",
    "indicateur_l1_effet_lisiere", "indicateur_l2_morcellement",
    "indicateur_n1_distance", "indicateur_n2_continuite",
    "indicateur_n3_naturalite", "indicateur_p1_volume",
    "indicateur_p2_station", "indicateur_p3_qualite_bois",
    "indicateur_s1_routes", "indicateur_s2_bati", "indicateur_s3_population"
  )
  for (fn in fns) {
    f <- getExportedValue("nemeton", fn)
    expect_error(f(pas_sf), class = "rlang_error", label = fn)
  }
})

test_that("missing-field errors are rlang errors and keep the field name", {
  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)
  )
  expect_error(indicateur_p3_qualite_bois(units), class = "rlang_error")
  expect_error(indicateur_p3_qualite_bois(units), "dbh")
  expect_error(indicateur_e1_bois_energie(units), class = "rlang_error")
  expect_error(compute_indicator("indicateur_inexistant", units, NULL),
               class = "rlang_error")
  expect_error(compute_indicator("indicateur_inexistant", units, NULL),
               "indicateur_inexistant")
})
