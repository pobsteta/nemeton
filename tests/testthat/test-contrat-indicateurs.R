# Contrat 1.0 (spec 057 §1) : tout indicateur rend l'objet `units` d'entrée
# (même classe, mêmes lignes, même ordre) augmenté de la colonne de valeur
# nommée par son code court. Les douze indicateurs qui rendaient un vecteur
# nu jusqu'en 0.216 sont vérifiés ici sur leur chemin le moins coûteux.

expect_contrat <- function(res, units, code) {
  expect_s3_class(res, "sf")
  expect_identical(class(res), class(units))
  expect_identical(nrow(res), nrow(units))
  expect_identical(res$id, units$id)
  expect_true(all(setdiff(names(units), code) %in% names(res)))
  expect_true(code %in% names(res))
  expect_type(res[[code]], "double")
  nom <- paste0("indicateur_", tolower(code), "_x")
  expect_identical(extract_indicator_value(res, nom), res[[code]])
}

test_that("les douze indicateurs ex-vecteur rendent units + colonne de valeur", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  ndvi <- create_test_raster(values = "constant")
  ndvi <- ndvi / 100
  dem <- create_test_raster(values = "random")
  lay_vide <- create_test_layers()
  lay <- create_test_layers(rasters = list(ndvi = ndvi, dem = dem))
  sol <- units[, "id"]
  sol$fertility <- c(20, 50, 80)
  lay_sol <- create_test_layers(vectors = list(soil = sol))

  cas <- list(
    C1 = function() indicateur_c1_biomasse(units),
    C2 = function() indicateur_c2_ndvi(units, lay),
    W1 = function() indicateur_w1_reseau(units, lay_vide),
    W2 = function() indicateur_w2_zones_humides(units, lay_vide),
    W3 = function() indicateur_w3_humidite(units, lay, method = "d8"),
    F1 = function() indicateur_f1_fertilite(units, lay_sol),
    F2 = function() indicateur_f2_erosion(units, lay),
    L1 = function() indicateur_l1_effet_lisiere(units),
    L2 = function() indicateur_l2_morcellement(units),
    T1 = function() indicateur_t1_anciennete(units),
    T2 = function() indicateur_t2_changement(transform(units, T1 = age)),
    T3 = function() indicateur_t3_coupes_rases(units)
  )
  for (code in names(cas)) {
    res <- suppressWarnings(suppressMessages(cas[[code]]()))
    expect_contrat(res, units, code)
  }
})

test_that("une colonne de même nom présente en entrée est remplacée", {
  units <- create_test_units(n_features = 2)
  units$T1 <- c(-1, -1)
  units$age <- c(30, 90)
  res <- suppressMessages(indicateur_t1_anciennete(units))
  expect_equal(res$T1, c(30, 90))
})

test_that("zéro unité : objet vide avec la colonne de valeur", {
  units <- create_test_units(n_features = 1)[0, ]
  res <- suppressMessages(indicateur_t3_coupes_rases(units))
  expect_s3_class(res, "sf")
  expect_identical(nrow(res), 0L)
  expect_true("T3" %in% names(res))
})
