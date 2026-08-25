# « 0 » et « vide » ne disent pas la meme chose — brief
# `briefs/vers-nemeton/2026-08-25-indicateurs-zero-ou-na.md`.
#
# La regle : si un calcul est fait, l'indicateur rend 0 ; s'il n'y a pas de
# calcul, il rend NA. Ce n'est pas cosmetique — `create_family_index()` moyenne
# avec `na.rm = TRUE`, donc un 0 fabrique PESE sur le score de famille quand un
# NA honnete s'en ecarte. Deux UGF dans la meme situation physique ne doivent
# pas peser differemment selon l'ecriture qu'un indicateur a choisie.

fixture_units <- function(n = 3) {
  data(massif_demo_units, package = "nemeton", envir = environment())
  u <- massif_demo_units[seq_len(n), ]
  u[, intersect(names(u), c(attr(u, "sf_column"), "id", "nom", "surface_ha"))]
}

# --- B1 : aires protegees ----------------------------------------------------

test_that("B1 sans donnee d'aires protegees rend NA, pas 0", {
  u <- fixture_units()
  r <- suppressMessages(indicateur_b1_protection(u))
  expect_true(all(is.na(r$B1)))
  expect_false(any(r$B1 == 0, na.rm = TRUE))
})

test_that("B1 en source WFS indisponible rend NA, et n'invente pas un jeu vide", {
  # Le defaut d'origine : faute d'implementation INPN, la branche fabriquait un
  # `sf` a zero ligne, que la suite lisait comme « interroge, rien trouve ».
  u <- fixture_units()
  r <- suppressWarnings(suppressMessages(
    indicateur_b1_protection(u, source = "wfs")))
  expect_true(all(is.na(r$B1)))
})

test_that("B1 avec un jeu VIDE fourni rend 0 — la, c'est une mesure", {
  u <- fixture_units()
  vide <- sf::st_sf(zone_id = character(0),
                    geometry = sf::st_sfc(crs = sf::st_crs(u)))
  r <- suppressMessages(indicateur_b1_protection(u, protected_areas = vide))
  expect_true(all(!is.na(r$B1)))
  expect_true(all(r$B1 == 0))
})

# --- E2 : evitement carbone --------------------------------------------------

test_that("E2 sans E1 rend NA, colonnes de detail comprises", {
  u <- fixture_units()
  r <- suppressMessages(indicateur_e2_evitement(u))
  expect_true(all(is.na(r$E2)))
  # Un appelant qui lit E2_energy seule ne doit pas y voir « 0 evite ».
  expect_true(all(is.na(r$E2_energy)))
  expect_true(all(is.na(r$E2_material)))
})

test_that("E2 avec un E1 nul rend 0 — rien a bruler, rien d'evite", {
  u <- fixture_units(); u$E1 <- 0
  r <- suppressMessages(indicateur_e2_evitement(u))
  expect_true(all(!is.na(r$E2)))
  expect_true(all(r$E2 == 0))
})

test_that("E2 melange les deux ecritures selon la disponibilite, par unite", {
  u <- fixture_units(3); u$E1 <- c(10, NA, 0)
  r <- suppressMessages(indicateur_e2_evitement(u))
  expect_gt(r$E2[1], 0)          # calcul fait, resultat positif
  expect_true(is.na(r$E2[2]))    # entree absente -> aucune mesure
  expect_equal(r$E2[3], 0)       # calcul fait, resultat nul
})

# --- Le garde-fou generique --------------------------------------------------

test_that("aucun indicateur ne fabrique un ZERO sans donnee d'entree", {
  # Balayage : chaque indicateur exporte, appele sans ses entrees. La regle
  # admet DEUX reponses — NA (rien a mesurer, on le dit) ou une erreur (l'entree
  # est obligatoire, on le dit aussi). Elle en interdit une : un zero, qui se
  # lit comme une mesure et pese dans la moyenne de famille.
  u <- fixture_units()
  fns <- sort(grep("^indicateur_", getNamespaceExports("nemeton"), value = TRUE))
  skip_if(length(fns) == 0L, "aucun indicateur exporte")

  fautifs <- character(0)
  for (f in fns) {
    r <- tryCatch(suppressWarnings(suppressMessages(do.call(f, list(u)))),
                  error = function(e) NULL)
    if (is.null(r)) next                       # erreur explicite : conforme
    cc <- setdiff(names(r), names(u))
    if (!length(cc)) next
    val <- suppressWarnings(as.numeric(r[[cc[1]]]))
    if (all(!is.na(val)) && all(val == 0)) fautifs <- c(fautifs, f)
  }
  expect_identical(fautifs, character(0),
                   info = paste("zero fabrique sans entree :",
                                paste(fautifs, collapse = ", ")))
})

test_that("la dette des DEFAUTS NEUTRES est figee, et ne s'etend pas", {
  # Trouve en balayant pour B1/E2 : sept indicateurs ne rendent pas 0 sans
  # entree, mais une VALEUR FABRIQUEE — `units$A2 <- rep(50, nrow(units))`
  # faute de donnee atmo, `dist_routes <- rep(1000, ...)` et
  # `dist_batiments <- rep(500, ...)` « default like tuto 04 » pour N1.
  #
  # C'est la meme faute que le zero de B1, en plus discrete : un 50 ressemble a
  # une mesure moyenne credible, quand une colonne de zeros finit par se
  # remarquer. La corriger touche a la valeur de sept indicateurs sur des
  # projets existants — c'est un arbitrage, pas un correctif, et il n'a pas
  # encore ete rendu.
  #
  # Ce test ne masque donc rien : il FIGE la liste. Un huitieme indicateur qui
  # s'y ajouterait le ferait echouer ; un des sept qui serait corrige aussi,
  # et c'est voulu — la liste doit se vider, jamais s'allonger en silence.
  connus <- c("indicateur_a2_qualite_air", "indicateur_b3_connectivite",
              "indicateur_n1_distance", "indicateur_n2_continuite",
              "indicateur_n3_naturalite", "indicateur_r4_abroutissement",
              "indicateur_s3_population")
  u <- fixture_units()
  fns <- sort(grep("^indicateur_", getNamespaceExports("nemeton"), value = TRUE))

  fabrique <- character(0)
  for (f in fns) {
    r <- tryCatch(suppressWarnings(suppressMessages(do.call(f, list(u)))),
                  error = function(e) NULL)
    if (is.null(r)) next
    cc <- setdiff(names(r), names(u))
    if (!length(cc)) next
    val <- suppressWarnings(as.numeric(r[[cc[1]]]))
    if (all(!is.na(val))) fabrique <- c(fabrique, f)
  }
  expect_setequal(fabrique, connus)
})
