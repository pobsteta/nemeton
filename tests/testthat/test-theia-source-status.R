# theia_source_status() : nommer la cause au lieu de rendre NULL.
#
# Contexte : le 2026-08-16, deux indicateurs étaient vides pour des raisons
# opposées et avec le même symptôme — aucun signal, un NA. A5 parce que
# `theia_lst` (Thermocity) ne couvre que quelques métropoles, ce qui est correct
# et documenté ; T3 parce que l'entrée `sufosat` déclarait ses champs STAC hors
# de `access`, ce qui était un défaut. L'app ne pouvait pas les distinguer : elle
# ne voyait qu'un `NULL`. Cette fonction rend une clé stable, traduisible en aval.

test_that("an unknown source is named as such, without a network call", {
  st <- theia_source_status("il_n_existe_pas", NULL)
  expect_false(st$available)
  expect_identical(st$reason, "unknown_source")
  expect_identical(st$n_assets, 0L)
  expect_true(is.na(st$collection))
})

test_that("a source without a confirmed collection is named, not queried", {
  # `soilgrids_cec` est une source réelle sans collection STAC : elle ne doit pas
  # déclencher de requête, et surtout pas être confondue avec « pas de données ».
  st <- theia_source_status("soilgrids_cec", NULL)
  expect_false(st$available)
  expect_identical(st$reason, "no_stac_collection")
})

test_that("the reason vocabulary is stable", {
  # Ces clés sont un contrat avec l'aval (clés i18n côté app) : les changer casse
  # l'affichage sans casser un test ailleurs. Elles sont donc verrouillées ici.
  reasons <- c("ok", "unknown_source", "no_stac_collection",
               "no_asset_over_aoi", "no_credentials", "error")
  st <- theia_source_status("il_n_existe_pas", NULL)
  expect_true(st$reason %in% reasons)
  expect_named(st, c("available", "reason", "n_assets", "collection", "detail"))
})

test_that("a STAC query failure is reported as an error, not as absence of data", {
  skip_if_not_installed("sf")
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 900000, ymin = 6500000, xmax = 901000, ymax = 6501000),
    crs = sf::st_crs(2154)))

  # Catalogue injoignable : « je n'ai pas pu demander » n'est pas « il n'y a
  # rien ». C'est la distinction qui manquait à l'app.
  st <- theia_source_status("theia_lst", aoi,
                            stac_api = "https://stac.invalid.example/v1")
  expect_false(st$available)
  expect_identical(st$reason, "error")
  expect_false(is.na(st$detail))
})

test_that("credentials are checked only once data exists", {
  skip_if_not_installed("sf")
  # Sans clés TLD, une source SANS données sur l'emprise doit toujours répondre
  # « pas de données » : c'est l'information utile, la clé n'y changerait rien.
  withr::local_envvar(c(TLD_ACCESS_KEY = "", TLD_SECRET_KEY = ""))
  st <- theia_source_status("il_n_existe_pas", NULL)
  expect_identical(st$reason, "unknown_source")
})

# --- La logique de décision, sans réseau -------------------------------------
#
# `testthat::skip_if_not_installed()` est appelé explicitement : le helper maison
# du même nom (helper-fixtures.R) sonde en plus l'anomalie terra des runners
# GitHub et ferait sauter ces tests, qui ne touchent pourtant aucun raster.

.tss_aoi <- function() {
  sf::st_as_sfc(sf::st_bbox(
    c(xmin = 900000, ymin = 6500000, xmax = 901000, ymax = 6501000),
    crs = sf::st_crs(2154)))
}

test_that("an empty catalogue answer is absence of data, not a failure", {
  testthat::skip_if_not_installed("sf")
  testthat::local_mocked_bindings(stac_search_items = function(...) list())

  st <- theia_source_status("theia_lst", .tss_aoi())
  expect_false(st$available)
  expect_identical(st$reason, "no_asset_over_aoi")
  expect_identical(st$n_assets, 0L)
  expect_identical(st$collection, "thermocity-lst")
  expect_true(is.na(st$detail))
})

test_that("data plus credentials is the only path to available = TRUE", {
  testthat::skip_if_not_installed("sf")
  testthat::local_mocked_bindings(
    stac_search_items = function(...) list(list(id = "a"), list(id = "b")))
  withr::local_envvar(c(TLD_ACCESS_KEY = "k", TLD_SECRET_KEY = "s"))

  st <- theia_source_status("theia_lst", .tss_aoi())
  expect_true(st$available)
  expect_identical(st$reason, "ok")
  expect_identical(st$n_assets, 2L)
})

test_that("data without credentials is reported as a credentials problem", {
  testthat::skip_if_not_installed("sf")
  testthat::local_mocked_bindings(
    stac_search_items = function(...) list(list(id = "a")))
  withr::local_envvar(c(TLD_ACCESS_KEY = "", TLD_SECRET_KEY = ""))

  st <- theia_source_status("theia_lst", .tss_aoi())
  expect_false(st$available)
  expect_identical(st$reason, "no_credentials")
  # Le compte est conservé : « il y a bien des données, c'est la clé qui manque »
  # est une information différente de « il n'y a rien ».
  expect_identical(st$n_assets, 1L)
})

test_that("a half-set credential pair counts as missing", {
  testthat::skip_if_not_installed("sf")
  testthat::local_mocked_bindings(
    stac_search_items = function(...) list(list(id = "a")))
  withr::local_envvar(c(TLD_ACCESS_KEY = "k", TLD_SECRET_KEY = ""))

  expect_identical(theia_source_status("theia_lst", .tss_aoi())$reason,
                   "no_credentials")
})

test_that("a datetime window narrows the query without changing the vocabulary", {
  testthat::skip_if_not_installed("sf")
  seen <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    stac_search_items = function(api, collection, bbox, datetime = NULL, limit = 50L) {
      seen$datetime <- datetime
      seen$limit <- limit
      list()
    })

  st <- theia_source_status("theia_lst", .tss_aoi(),
                            datetime = "2020-01-01/2020-12-31", limit = 5L)
  expect_identical(seen$datetime, "2020-01-01/2020-12-31")
  expect_identical(seen$limit, 5L)
  expect_identical(st$reason, "no_asset_over_aoi")
})

# --- Vérification contre le catalogue réel (réseau) --------------------------

test_that("theia_lst reports urban-only coverage against the live catalogue", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not_installed("sf")

  # Ardennes (projet Fordead) : hors couverture Thermocity.
  rural <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 840999, ymin = 6901000, xmax = 845999, ymax = 6905000),
    crs = sf::st_crs(2154)))
  st <- theia_source_status("theia_lst", rural)
  expect_false(st$available)
  expect_identical(st$reason, "no_asset_over_aoi")
  expect_identical(st$collection, "thermocity-lst")
})

test_that("sufosat resolves against the live catalogue", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not_installed("sf")

  # Couverture nationale : n'importe quelle emprise métropolitaine doit trouver
  # le produit. Un `no_stac_collection` ici signalerait le retour du défaut de
  # schéma corrigé en v0.173.1.
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 1009220, ymin = 6843784, xmax = 1013174, ymax = 6847447),
    crs = sf::st_crs(2154)))
  st <- theia_source_status("sufosat", aoi)
  expect_identical(st$collection, "sufosat")
  expect_gt(st$n_assets, 0L)
  # `available` dépend des clés TLD de l'environnement : sans elles, la cause
  # doit être « pas de clés », jamais « pas de données ».
  expect_true(st$reason %in% c("ok", "no_credentials"))
})
