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

test_that("les six defauts neutres sont corriges", {
  # v0.187.0. Chacun rendait une VALEUR FABRIQUEE sans entree — 50 « neutre »
  # pour A2/B3/N2/N3/R4, des distances inventees pour N1 (« default like
  # tuto 04 » : 1000 m aux routes, 500 m au bati). Plus discret qu'un zero :
  # un 50 ressemble a une mesure moyenne credible, quand une colonne de zeros
  # finit par se remarquer. Et il PESAIT dans la moyenne de famille.
  u <- fixture_units()
  for (f in c("indicateur_a2_qualite_air", "indicateur_b3_connectivite",
              "indicateur_n1_distance", "indicateur_n2_continuite",
              "indicateur_n3_naturalite", "indicateur_r4_abroutissement")) {
    r <- suppressWarnings(suppressMessages(do.call(f, list(u))))
    cc <- setdiff(names(r), names(u))
    val <- suppressWarnings(as.numeric(r[[cc[1]]]))
    expect_true(all(is.na(val)), info = f)
  }
})

test_that("N3 ne moyenne pas du mesure avec de l'invente", {
  # Le composite pese quatre composantes. Une seule absente, remplacee par 50,
  # produisait un N3 d'apparence normale — impossible a distinguer en aval d'un
  # composite entierement mesure.
  u <- fixture_units()
  u$N1 <- 60; u$N2 <- 70; u$L1 <- 20          # B3 manque volontairement
  r <- suppressMessages(indicateur_n3_naturalite(u))
  expect_true(all(is.na(r$N3)))

  u$B3 <- 80                                   # les quatre sont la
  r2 <- suppressMessages(indicateur_n3_naturalite(u))
  expect_true(all(!is.na(r2$N3)))
  expect_equal(r2$N3[1], 0.35*60 + 0.35*70 + 0.15*(100-20) + 0.15*80)
})

test_that("plus aucun indicateur ne fabrique de valeur sans entree", {
  # Ce test a d'abord FIGE une dette de sept indicateurs (v0.186.0), puis l'a
  # vue fondre : six corriges en v0.187.0, puis S3 sur decision de Pascal
  # (« S3 ne doit pas fabriquer de fausse valeur »). Il est maintenant vide, et
  # c'est son etat cible.
  #
  # Il reste utile en l'etat : un indicateur qui recommencerait a rendre une
  # valeur sans donnee d'entree — 0, 50 neutre, ou surface deguisee en
  # population — le ferait echouer. La regle admet deux reponses, NA ou une
  # erreur explicite ; elle n'en admet pas une troisieme.
  u <- fixture_units()
  fns <- sort(grep("^indicateur_", getNamespaceExports("nemeton"), value = TRUE))
  skip_if(length(fns) == 0L, "aucun indicateur exporte")

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
  expect_identical(fabrique, character(0),
                   info = paste("valeur fabriquee sans entree :",
                                paste(fabrique, collapse = ", ")))
})

# --- S3 : plus aucune population fabriquee -----------------------------------
# Decision de Pascal (2026-08-25) : « S3 ne doit pas fabriquer de fausse
# valeur. » Jusqu'ici la fonction ne lisait JAMAIS son `population_grid` et
# rendait surface_du_tampon x 100 hab/km2 — un nombre qui variait plausiblement
# avec la taille de l'UGF, donc indiscernable d'une mesure.

test_that("S3 sans grille de population rend NA, pas une surface deguisee", {
  u <- fixture_units(2)
  r <- suppressMessages(indicateur_s3_population(u))
  expect_true(all(is.na(r$S3)))
  # Les trois rayons suivent : un appelant qui lit S3_10km seul ne doit pas y
  # trouver un nombre la ou rien n'a ete mesure.
  expect_true(all(is.na(r$S3_5km)))
  expect_true(all(is.na(r$S3_10km)))
  expect_true(all(is.na(r$S3_20km)))
})

test_that("S3 lit une grille de carreaux et pondere les carreaux a cheval", {
  # Deux carreaux de 1 km, 100 habitants chacun, cote a cote.
  carreau <- function(x0, y0, n) sf::st_sf(
    ind = n,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(x0, y0), c(x0 + 1000, y0), c(x0 + 1000, y0 + 1000),
      c(x0, y0 + 1000), c(x0, y0)))), crs = 2154))
  grille <- rbind(carreau(0, 0, 100), carreau(1000, 0, 100))

  # Une UGF ponctuelle au centre du premier carreau, tampon de 500 m :
  # entierement dans le premier carreau, dont elle couvre pi*500^2 / 1e6 ~ 78,5 %.
  u <- sf::st_sf(id = 1L, geometry = sf::st_sfc(
    sf::st_point(c(500, 500)), crs = 2154))
  r <- suppressMessages(indicateur_s3_population(
    u, population_grid = grille, buffer_radii = c(500, 1000, 2000)))

  # La PONDERATION se lit sur l'effectif : le tampon couvre pi*500^2 / 1e6
  # ~ 78,5 % du carreau, donc ~78 des 100 habitants — pas les 100.
  expect_false(is.na(r$S3_5km[1]))
  expect_gt(r$S3_5km[1], 0)
  expect_lt(r$S3_5km[1], 100)
  expect_equal(r$S3_5km[1], round(100 * pi * 500^2 / 1e6), tolerance = 0.05)

  # S3 lui-meme est une DENSITE (hab/km2), pas un effectif : ~78 habitants sur
  # les 0,785 km2 du tampon, soit ~100 hab/km2 — la densite du carreau, ce qui
  # est le controle le plus parlant.
  expect_equal(as.numeric(r$S3[1]), 100, tolerance = 0.02)

  # Un tampon plus large atteint le second carreau : l'effectif croit.
  expect_gt(r$S3_20km[1], r$S3_5km[1])
})

test_that("S3 nomme la colonne manquante plutot que de deviner", {
  grille <- sf::st_sf(
    habitants = 100,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(1000, 0), c(1000, 1000), c(0, 1000), c(0, 0)))), crs = 2154))
  u <- sf::st_sf(id = 1L, geometry = sf::st_sfc(sf::st_point(c(500, 500)), crs = 2154))
  expect_error(
    suppressMessages(indicateur_s3_population(u, population_grid = grille)),
    "No population column")
  # Nomme explicitement, elle est acceptee.
  r <- suppressMessages(indicateur_s3_population(
    u, population_grid = grille, population_field = "habitants",
    buffer_radii = c(500, 1000, 2000)))
  expect_false(is.na(r$S3[1]))
})
