# Acquisition du carroyage INSEE Filosofi (spec 050) — aucun acces reseau :
# les tests portent sur la resolution de cache, les garde-fous et la forme du
# retour, jamais sur le telechargement.

test_that("une aoi invalide rend NULL, pas une erreur", {
  expect_warning(r <- load_insee_population_source(42), "sf/sfc")
  expect_null(r)
})

test_that("un millesime non cable rend NULL plutot que de deviner", {
  u <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154))
  expect_warning(r <- load_insee_population_source(u, millesime = 2019), "2021")
  expect_null(r)
})

test_that("le cache est partage par machine et porte le millesime", {
  # Le fichier ne change qu'une fois par an et pese 52 Mo : un projet qui
  # recalcule ne doit rien re-telecharger, et deux millesimes doivent pouvoir
  # cohabiter.
  d1 <- nemeton:::.insee_cache_dir(millesime = 2021, maille = "1km")
  d2 <- nemeton:::.insee_cache_dir(millesime = 2019, maille = "1km")
  d3 <- nemeton:::.insee_cache_dir(millesime = 2021, maille = "200m")
  expect_false(identical(d1, d2))
  expect_false(identical(d1, d3))
  expect_match(d1, "filosofi2021_1km$")
  # Pas de chemin de projet dans le cache : c'est le sens de « par machine ».
  expect_no_match(d1, "projects")

  # `cache_dir` reste surchargeable (CI, disque separe).
  expect_match(nemeton:::.insee_cache_dir("/tmp/x"), "^/tmp/x/")
})

test_that("source injoignable : NULL et un avertissement, jamais un repli", {
  # C'est la regle de la v0.187.0 : une valeur fabriquee est pire qu'une
  # absence. Le telechargement est mocke en echec.
  u <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(900000, 6700000)), crs = 2154))
  testthat::local_mocked_bindings(.insee_telecharger = function(...) FALSE)
  expect_warning(
    r <- load_insee_population_source(u, cache_dir = withr::local_tempdir()),
    "unavailable")
  expect_null(r)
})

test_that("les deux mailles pointent des fichiers distincts", {
  cfg <- nemeton:::.INSEE_FILOSOFI
  expect_named(cfg, c("1km", "200m"))
  expect_false(identical(cfg[["1km"]]$url, cfg[["200m"]]$url))
  # Chaque maille a son propre drapeau d'imputation.
  expect_identical(cfg[["1km"]]$flag, "i_est_1km")
  expect_identical(cfg[["200m"]]$flag, "i_est_200m")
  # Metropole, Martinique, Reunion : la source ne couvre pas le reste.
  expect_named(cfg[["1km"]]$couches, c("FR", "MTQ", "REU"))
})

test_that("S3 rend une DENSITE, comparable entre massifs", {
  # Le point de conception de la spec 050. Un effectif brut ne se compare pas :
  # le tampon grandit avec l'UGF, si bien qu'un grand massif rural totalise
  # plus d'habitants qu'un petit bois periurbain — l'inverse de la « pression
  # sociale ». Et la normalisation historique saturait a 10 000 habitants,
  # quand Couchey en compte 46 110 dans 5 km.
  carreau <- function(x0, y0, n) sf::st_sf(
    ind = n,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(x0, y0), c(x0 + 1000, y0), c(x0 + 1000, y0 + 1000),
      c(x0, y0 + 1000), c(x0, y0)))), crs = 2154))
  # Grille 2D HOMOGENE (5 x 5 carreaux a 200 hab). Un ruban de carreaux ne
  # conviendrait pas : le grand tampon deborderait dans le vide et diluerait la
  # densite, ce qui testerait la forme de la fixture, pas la propriete.
  grille <- do.call(rbind, unlist(lapply(0:4, function(i)
    lapply(0:4, function(j) carreau(i * 1000, j * 1000, 200))), recursive = FALSE))

  petite <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(2500, 2500)), crs = 2154))
  grande <- sf::st_sf(geometry = sf::st_sfc(sf::st_buffer(
    sf::st_point(c(2500, 2500)), 800), crs = 2154))

  r_p <- suppressMessages(indicateur_s3_population(
    petite, population_grid = grille, buffer_radii = c(1000, 2000, 3000)))
  r_g <- suppressMessages(indicateur_s3_population(
    grande, population_grid = grille, buffer_radii = c(1000, 2000, 3000)))

  # L'UGF large capte plus d'habitants — l'effectif suit la taille.
  expect_gt(r_g$S3_5km, r_p$S3_5km)
  # Mais la DENSITE, elle, reste du meme ordre : c'est le meme voisinage.
  expect_equal(as.numeric(r_g$S3), as.numeric(r_p$S3), tolerance = 0.25)
  expect_true("S3_densite" %in% names(r_p))
})

test_that("l'echelle de normalisation discrimine le domaine forestier", {
  # Log, parce que la densite couvre trois ordres de grandeur en France :
  # ~5 hab/km2 dans un massif alpin isole, 40-80 en rural, 300-1000 en
  # periurbain. Une echelle lineaire ecraserait tout le domaine forestier dans
  # les premiers points.
  n <- function(d) as.numeric(normalize_indicator("indicateur_s3_population", d))
  expect_lt(n(5), n(50))
  expect_lt(n(50), n(100))
  expect_lt(n(100), n(300))
  # Deux massifs ruraux distincts ne doivent PAS rendre le meme score.
  expect_gt(n(80) - n(20), 10)
  # Et le haut sature volontairement : au-dela de 1000 hab/km2, l'ecart cesse
  # d'etre informatif pour une foret.
  expect_equal(n(1000), 100)
  expect_equal(n(3000), 100)
  expect_equal(n(0), 0)
})
