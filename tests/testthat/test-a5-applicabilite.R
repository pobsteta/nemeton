# a5_applicabilite() : dire AVANT calcul si A5 s'applique, et à quelle échelle.
#
# Pendant de r5_applicabilite() pour la famille A, avec une différence de nature
# assumée : pour R5 les deux conditions se décident sur les parcelles seules
# (essence, géographie) ; pour A5 la couverture ne se connaît qu'à la maille de
# la SCÈNE — une requête STAC répond sur des emprises, pas sur des pixels. Une
# UGF à 20 km d'une métropole couverte peut tomber dans la bbox d'une scène
# ECOSTRESS sans porter un seul pixel valide. D'où un verdict à deux niveaux.

skip_if_not_installed("sf")

.a5_units <- function(n = 3, x0 = 0, y0 = 0) {
  geom <- sf::st_sfc(lapply(seq_len(n), function(i) {
    sf::st_polygon(list(matrix(c(
      x0 + (i - 1) * 300, y0, x0 + (i - 1) * 300 + 100, y0,
      x0 + (i - 1) * 300 + 100, y0 + 100, x0 + (i - 1) * 300, y0 + 100,
      x0 + (i - 1) * 300, y0), ncol = 2, byrow = TRUE)))
  }), crs = 2154)
  sf::st_sf(id = seq_len(n), geometry = geom)
}

# Raster LST couvrant les `n_covered` premières unités seulement.
.a5_lst <- function(xmax = 2000, value = 305) {
  r <- terra::rast(xmin = -600, xmax = xmax, ymin = -600, ymax = 700,
                   resolution = 20, crs = "EPSG:2154")
  terra::values(r) <- value
  r
}

# --- Niveau emprise : une requête catalogue, aucun téléchargement ------------

test_that("no LST scene over the extent is reported as no_coverage", {
  testthat::local_mocked_bindings(
    theia_source_status = function(...) {
      list(available = FALSE, reason = "no_asset_over_aoi", n_assets = 0L,
           collection = "thermocity-lst", detail = NA_character_)
    })
  a <- a5_applicabilite(.a5_units())
  expect_identical(a$status, "no_coverage")
  expect_equal(a$n_eligible, 0L)
  expect_equal(a$n_assets, 0L)
  # Verdict d'emprise : pas de détail par unité, et c'est assumé.
  expect_null(a$per_unit)
})

test_that("coverage without a raster is an extent-level verdict, not a promise", {
  testthat::local_mocked_bindings(
    theia_source_status = function(...) {
      list(available = TRUE, reason = "ok", n_assets = 8L,
           collection = "thermocity-lst", detail = NA_character_)
    })
  a <- a5_applicabilite(.a5_units(n = 4))
  expect_identical(a$status, "eligible")
  expect_equal(a$n_assets, 8L)
  # Toutes les unités sont comptées éligibles faute de mieux : c'est l'emprise
  # qui est couverte, la vérification par pixel demande le raster.
  expect_equal(a$n_eligible, 4L)
  expect_null(a$per_unit)
})

test_that("missing credentials are not confused with missing data", {
  testthat::local_mocked_bindings(
    theia_source_status = function(...) {
      list(available = FALSE, reason = "no_credentials", n_assets = 3L,
           collection = "thermocity-lst", detail = NA_character_)
    })
  a <- a5_applicabilite(.a5_units())
  expect_identical(a$status, "no_credentials")
  # Le compte de scènes est conservé : il y a bien des données.
  expect_equal(a$n_assets, 3L)
})

test_that("a catalogue failure surfaces as error", {
  testthat::local_mocked_bindings(
    theia_source_status = function(...) {
      list(available = FALSE, reason = "error", n_assets = 0L,
           collection = "thermocity-lst", detail = "boom")
    })
  expect_identical(a5_applicabilite(.a5_units())$status, "error")
})

# --- Niveau unité : le raster est là, on regarde les pixels ------------------

test_that("with a raster, every unit is checked for pixels AND for its ring", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  a <- a5_applicabilite(.a5_units(n = 3), lst = .a5_lst())
  expect_identical(a$status, "eligible")
  expect_equal(a$n_eligible, 3L)
  expect_true(all(a$per_unit$has_lst))
  expect_true(all(a$per_unit$has_reference))
  # Aucune requête catalogue n'a été faite : le raster suffit.
  expect_true(is.na(a$n_assets))
})

test_that("partial coverage is named, not rounded to eligible or to nothing", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # Raster tronqué à x = 400 : seule la première unité (0..100) est couverte,
  # les deux autres (300..400 et 600..700) sortent de l'emprise.
  a <- a5_applicabilite(.a5_units(n = 3), lst = .a5_lst(xmax = 150))

  expect_identical(a$status, "eligible_partial")
  expect_equal(a$n_eligible, 1L)
  expect_identical(a$per_unit$eligible, c(TRUE, FALSE, FALSE))
})

test_that("pixels on the unit but none in its ring is a reference problem", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # Raster réduit à l'emprise exacte de l'unité : l'unité a des pixels,
  # l'anneau de référence n'en a aucun. L'indicateur rendrait
  # `skipped_no_reference` — le pré-contrôle doit dire la même chose.
  u <- .a5_units(n = 1)
  r <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- 305

  a <- a5_applicabilite(u, lst = r)
  expect_identical(a$status, "no_reference")
  expect_true(a$per_unit$has_lst)
  expect_false(a$per_unit$has_reference)
})

test_that("the LST nodata sentinel does not pass for data", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # -32768 est la sentinelle des produits LST : des pixels présents mais tous
  # à nodata ne rendent pas l'unité calculable.
  a <- a5_applicabilite(.a5_units(n = 2), lst = .a5_lst(value = -32768))
  expect_identical(a$status, "no_coverage")
  expect_equal(a$n_eligible, 0L)
})

test_that("empty units and the status vocabulary", {
  a <- a5_applicabilite(.a5_units(n = 0))
  expect_identical(a$status, "no_coverage")
  expect_equal(a$n_units, 0L)

  statuses <- c("eligible", "eligible_partial", "no_coverage", "no_reference",
                "no_credentials", "error")
  expect_true(a$status %in% statuses)
  expect_named(a, c("status", "n_units", "n_eligible", "n_assets", "per_unit"))
})
