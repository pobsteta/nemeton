# test-load-foret-ancienne.R — acquisition forêt ancienne état-major (spec 031)
#
# La récupération WFS réelle (happign) n'est pas jouée en CI : get_wfs est mocké.
# On teste la validation d'entrées, le clip/finalisation, la 0-ligne et la
# dégradation NULL.

.fa_aoi <- function() {
  sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1000, 0), c(1000, 1000),
                              c(0, 1000), c(0, 0)))), crs = 2154))
}

test_that("non-sf aoi degrades to NULL", {
  expect_warning(res <- load_foret_ancienne_source(list(1)), "sf/sfc")
  expect_null(res)
})

test_that("aoi without a CRS degrades to NULL", {
  aoi <- sf::st_sfc(sf::st_point(c(0, 0)))   # crs = NA
  expect_warning(res <- load_foret_ancienne_source(aoi), "no CRS")
  expect_null(res)
})

test_that("a WFS forest layer is clipped to the AOI and flagged", {
  skip_if_not_installed("happign")
  # Forêt état-major débordant l'AOI (0..1500) -> doit être clippée à 0..1000.
  forest <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(-200, -200), c(1500, -200), c(1500, 1500),
                              c(-200, 1500), c(-200, -200)))), crs = 2154))
  forest$theme <- "EM9.1"
  testthat::local_mocked_bindings(
    get_wfs = function(x, layer, ...) forest, .package = "happign")

  out <- load_foret_ancienne_source(.fa_aoi(), crs = 2154)
  expect_s3_class(out, "sf")
  expect_true("foret_ancienne" %in% names(out))
  expect_true(all(out$foret_ancienne))
  # Clippé : aire <= aire AOI (1e6 m²), pas l'aire du polygone forêt (1.7^2 e6).
  expect_lte(as.numeric(sum(sf::st_area(out))), 1e6 + 1)
  expect_equal(sf::st_crs(out)$epsg, 2154L)
})

test_that("target crs is honoured", {
  skip_if_not_installed("happign")
  forest <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1000, 0), c(1000, 1000),
                              c(0, 1000), c(0, 0)))), crs = 2154))
  testthat::local_mocked_bindings(
    get_wfs = function(x, layer, ...) forest, .package = "happign")
  out <- load_foret_ancienne_source(.fa_aoi(), crs = 4326)
  expect_equal(sf::st_crs(out)$epsg, 4326L)
})

test_that("no ~1850 forest returns a 0-row sf (not NULL)", {
  skip_if_not_installed("happign")
  empty <- sf::st_sf(theme = character(0), geometry = sf::st_sfc(crs = 2154))
  testthat::local_mocked_bindings(
    get_wfs = function(x, layer, ...) empty, .package = "happign")
  out <- load_foret_ancienne_source(.fa_aoi())
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 0L)
  expect_true("foret_ancienne" %in% names(out))
})

test_that("a WFS error degrades to NULL", {
  skip_if_not_installed("happign")
  testthat::local_mocked_bindings(
    get_wfs = function(x, layer, ...) stop("network down"), .package = "happign")
  expect_warning(res <- load_foret_ancienne_source(.fa_aoi()), "WFS fetch failed")
  expect_null(res)
})

test_that("output feeds indicateur_n2_continuite without signature change", {
  skip_if_not_installed("happign")
  forest <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(600, 0), c(600, 600),
                              c(0, 600), c(0, 0)))), crs = 2154))
  testthat::local_mocked_bindings(
    get_wfs = function(x, layer, ...) forest, .package = "happign")
  fa <- load_foret_ancienne_source(.fa_aoi())
  units <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(500, 0), c(500, 500),
                              c(0, 500), c(0, 0)))), crs = 2154))
  units$nemeton_id <- 1
  expect_no_error(indicateur_n2_continuite(units, foret_ancienne = fa))
})
