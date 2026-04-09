# tests/testthat/test-datasources.R
# Tests pour l'abstraction des sources de donnees par pays (ADR-002)

# ---- get_country_config ----

test_that("get_country_config loads FR config", {
  config <- get_country_config("FR")
  expect_type(config, "list")
  expect_equal(config$country, "FR")
  expect_equal(config$crs_national, 2154)
})

test_that("get_country_config loads EU config", {
  config <- get_country_config("EU")
  expect_equal(config$country, "EU")
  expect_equal(config$crs_national, 3035)
})

test_that("get_country_config is case-insensitive", {
  config <- get_country_config("fr")
  expect_equal(config$country, "FR")
})

test_that("get_country_config falls back to EU for unknown country", {
  config <- suppressWarnings(get_country_config("XX"))
  expect_equal(config$country, "EU")
})

test_that("get_country_config caches results", {
  clear_datasource_cache()
  config1 <- get_country_config("FR")
  config2 <- get_country_config("FR")
  expect_identical(config1, config2)
})

# ---- get_data_source ----

test_that("get_data_source returns layer config", {
  dem <- get_data_source("dem", "FR")
  expect_type(dem, "list")
  expect_equal(dem$service, "ign_wms")
  expect_equal(dem$layer, "ELEVATION.ELEVATIONGRIDCOVERAGE")
})

test_that("get_data_source returns dataset config", {
  oso <- get_data_source("oso", "FR")
  expect_type(oso, "list")
  expect_match(oso$url, "recherche.data.gouv.fr")
})

test_that("get_data_source returns service config", {
  wfs <- get_data_source("ign_wfs", "FR")
  expect_match(wfs$url, "data.geopf.fr")
})

test_that("get_data_source returns NULL for unknown key", {
  result <- get_data_source("nonexistent", "FR")
  expect_null(result)
})

test_that("get_data_source falls back to EU", {
  sentinel <- get_data_source("sentinel2", "FR")
  expect_type(sentinel, "list")
  expect_match(sentinel$stac_url, "copernicus")
})

# ---- get_layer_service ----

test_that("get_layer_service resolves service URL for DEM", {
  info <- get_layer_service("dem", "FR")
  expect_match(info$url, "data.geopf.fr")
  expect_equal(info$layer, "ELEVATION.ELEVATIONGRIDCOVERAGE")
})

test_that("get_layer_service resolves roads", {
  info <- get_layer_service("roads", "FR")
  expect_match(info$url, "data.geopf.fr")
  expect_equal(info$typename, "BDTOPO_V3:troncon_de_route")
})

test_that("get_layer_service returns NULL for unknown layer", {
  expect_null(get_layer_service("nonexistent", "FR"))
})

# ---- get_national_crs ----

test_that("get_national_crs returns 2154 for France", {
  expect_equal(get_national_crs("FR"), 2154L)
})

test_that("get_national_crs returns 3035 for EU fallback", {
  expect_equal(get_national_crs("EU"), 3035L)
})

# ---- list_countries ----

test_that("list_countries returns available country codes", {
  countries <- list_countries()
  expect_true("FR" %in% countries)
  expect_true("EU" %in% countries)
})

# ---- FR.json structure ----

test_that("FR config has all required sections", {
  config <- get_country_config("FR")
  expect_true("services" %in% names(config))
  expect_true("layers" %in% names(config))
  expect_true("datasets" %in% names(config))
  expect_true("communes" %in% names(config))
})

test_that("FR config has all expected layers", {
  config <- get_country_config("FR")
  expected_layers <- c("dem", "ortho_irc", "bdforet", "roads",
                        "water_network", "water_surfaces", "buildings",
                        "protected_areas", "lidar_mnh", "lidar_mnt", "lidar_copc")
  for (layer in expected_layers) {
    expect_true(layer %in% names(config$layers),
                info = paste("Missing layer:", layer))
  }
})

test_that("FR hunting dataset has all species", {
  config <- get_country_config("FR")
  species <- names(config$datasets$hunting$species)
  expect_true("chevreuil" %in% species)
  expect_true("cerf" %in% species)
  expect_true("sanglier" %in% species)
})
