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

# ---- chm_opencanopy (spec 005 phase 1) ----

test_that("FR config exposes chm_opencanopy dataset", {
  chm <- get_data_source("chm_opencanopy", "FR")
  expect_type(chm, "list")
  expect_equal(chm$type, "raster_local")
  expect_equal(chm$format, "COG")
  expect_equal(chm$required_crs, "EPSG:2154")
  expect_equal(chm$unit, "m")
})

test_that("chm_opencanopy has plausible value_range", {
  chm <- get_data_source("chm_opencanopy", "FR")
  expect_length(chm$value_range, 2)
  expect_true(chm$value_range[[1]] >= 0)
  expect_true(chm$value_range[[2]] <= 60)
  expect_true(chm$value_range[[2]] > chm$value_range[[1]])
})

test_that("chm_opencanopy declares provenance and license", {
  chm <- get_data_source("chm_opencanopy", "FR")
  expect_equal(chm$provenance$package, "opencanopy")
  expect_true(nzchar(chm$provenance$version_min))
  expect_true(all(c("bd_ortho", "open_canopy", "derived") %in%
                    names(chm$license)))
})

# ---- forms_t (FORMS-T Theia time-series) ----

test_that("FR config exposes forms_t dataset", {
  forms <- get_data_source("forms_t", "FR")
  expect_type(forms, "list")
  expect_equal(forms$type, "raster_local")
  expect_equal(forms$format, "COG")
  expect_equal(forms$native_crs, "EPSG:2154")
  expect_equal(forms$augmented, "height_ml")
  expect_equal(forms$ndp_level, 0)
})

test_that("forms_t declares the three products with units", {
  forms <- get_data_source("forms_t", "FR")
  expect_true(all(c("height", "volume", "biomass") %in%
                    names(forms$products)))
  expect_equal(forms$products$height$unit, "cm")
  expect_equal(forms$products$height$resolution_m, 10)
  expect_equal(forms$products$volume$unit, "m3/ha")
  expect_equal(forms$products$volume$resolution_m, 30)
  expect_equal(forms$products$biomass$unit, "Mg/ha")
  expect_equal(forms$products$biomass$resolution_m, 30)
})

test_that("forms_t products have plausible value ranges", {
  forms <- get_data_source("forms_t", "FR")
  for (p in c("height", "volume", "biomass")) {
    rng <- forms$products[[p]]$value_range
    expect_length(rng, 2)
    expect_true(rng[[1]] >= 0)
    expect_true(rng[[2]] > rng[[1]])
  }
})

test_that("forms_t documents the C1/P1/P2/B2 wiring and provenance", {
  forms <- get_data_source("forms_t", "FR")
  expect_true(all(c("C1", "P1", "P2", "B2") %in%
                    names(forms$consumed_by)))
  expect_match(forms$provenance$reference, "essd-15-4927-2023")
  expect_true(nzchar(forms$access$stac_catalog))
})

# ---- Theia sources phase 1a (s2_biophysical / theia_soil / theia_snow) ----

test_that("FR config exposes s2_biophysical with LAI/FAPAR/FVC", {
  bio <- get_data_source("s2_biophysical", "FR")
  expect_type(bio, "list")
  expect_equal(bio$type, "raster_local")
  expect_equal(bio$ndp_level, 0)
  expect_true(all(c("lai", "fapar", "fvc") %in% names(bio$products)))
  expect_equal(bio$products$fapar$unit, "fraction")
  expect_equal(bio$products$fvc$value_range[[2]], 1)
  expect_true(all(c("C2", "A1", "B2") %in% names(bio$consumed_by)))
})

test_that("FR config exposes theia_soil with texture fractions", {
  soil <- get_data_source("theia_soil", "FR")
  expect_type(soil, "list")
  expect_equal(soil$type, "raster_local")
  expect_equal(soil$native_crs, "EPSG:2154")
  expect_true(all(c("clay", "silt", "sand", "coarse_elements") %in%
                    names(soil$products)))
  expect_true(all(c("F1", "F2") %in% names(soil$consumed_by)))
})

test_that("FR config exposes theia_snow with cover and phenology", {
  snow <- get_data_source("theia_snow", "FR")
  expect_type(snow, "list")
  expect_equal(snow$type, "raster_local")
  expect_equal(snow$ndp_level, 0)
  expect_true(all(c("snow_cover", "snow_cover_duration") %in%
                    names(snow$products)))
  expect_equal(snow$products$snow_cover$resolution_m, 20)
  expect_true("R3" %in% names(snow$consumed_by))
  expect_match(snow$access$reference, "essd-11-493-2019")
})

test_that("Theia phase-1a sources all declare provenance", {
  for (key in c("s2_biophysical", "theia_soil", "theia_snow")) {
    src <- get_data_source(key, "FR")
    expect_true(!is.null(src$provenance),
                info = paste("missing provenance:", key))
    expect_true(nzchar(src$provenance$producer),
                info = paste("empty producer:", key))
  }
})

# ---- Theia sources phase 1b ----

test_that("FR config exposes theia_water with mask and occurrence", {
  water <- get_data_source("theia_water", "FR")
  expect_type(water, "list")
  expect_equal(water$type, "raster_local")
  expect_true(all(c("water_mask", "water_occurrence") %in%
                    names(water$products)))
  expect_true(all(c("W1", "W2") %in% names(water$consumed_by)))
})

test_that("FR config exposes theia_soil_moisture with both variants", {
  sm <- get_data_source("theia_soil_moisture", "FR")
  expect_type(sm, "list")
  expect_true(all(c("soil_moisture_smos", "soil_moisture_s1") %in%
                    names(sm$products)))
  expect_equal(sm$products$soil_moisture_smos$unit, "m3/m3")
  expect_true(all(c("W3", "R3", "F1") %in% names(sm$consumed_by)))
})

test_that("FR config exposes s2_l2a_muscate with bands", {
  s2 <- get_data_source("s2_l2a_muscate", "FR")
  expect_type(s2, "list")
  expect_equal(s2$type, "raster_local")
  expect_true("B8A" %in% unlist(s2$products$surface_reflectance$bands))
  expect_true(all(c("C2", "T2", "R5") %in% names(s2$consumed_by)))
})

test_that("FR config exposes theia_species tagged species_ml", {
  sp <- get_data_source("theia_species", "FR")
  expect_type(sp, "list")
  expect_equal(sp$augmented, "species_ml")
  expect_true("dominant_species" %in% names(sp$products))
  expect_true(all(c("B1", "B2", "P", "C") %in% names(sp$consumed_by)))
})

test_that("FR config exposes theia_lst for the A2 indicator", {
  lst <- get_data_source("theia_lst", "FR")
  expect_type(lst, "list")
  expect_equal(lst$products$land_surface_temperature$unit, "degC")
  expect_true("A2" %in% names(lst$consumed_by))
})

test_that("FR config exposes formspot with its THEIA STAC collection", {
  fs <- get_data_source("formspot", "FR")
  expect_type(fs, "list")
  expect_equal(fs$type, "raster_local")
  expect_match(fs$access$preprint, "2512.17021")
  expect_equal(fs$access$stac_collection, "FORMSpoT")
  expect_match(fs$access$stac_catalog, "theia.data-terra.org")
  expect_true(all(c("C", "P", "T", "R") %in% names(fs$consumed_by)))
})

test_that("all Theia phase-1b sources are raster_local at NDP 0", {
  for (key in c("theia_water", "theia_soil_moisture", "s2_l2a_muscate",
                "theia_species", "theia_lst", "formspot")) {
    src <- get_data_source(key, "FR")
    expect_equal(src$type, "raster_local",
                 info = paste("wrong type:", key))
    expect_equal(src$ndp_level, 0, info = paste("wrong ndp:", key))
    expect_true(!is.null(src$provenance),
                info = paste("missing provenance:", key))
  }
})

# ---- load_raster_source ----

test_that("load_raster_source errors on unknown key", {
  expect_error(
    load_raster_source("does_not_exist", "FR"),
    "Unknown datasource"
  )
})

test_that("load_raster_source rejects non-raster types", {
  # "dem" is declared as a service layer, not a raster_{remote,local}
  expect_error(
    load_raster_source("dem", "FR", section = "layers"),
    "load_raster_source"
  )
})

test_that("load_raster_source errors when raster_local has no path", {
  # chm_opencanopy is produced dynamically by the opencanopy package
  # and carries no path — the loader must refuse rather than guess.
  expect_error(
    load_raster_source("chm_opencanopy", "FR"),
    "no.*path|produced dynamically"
  )
})

test_that("load_raster_source prepends /vsicurl/ for raster_remote", {
  # Avoid hitting ISRIC in tests: intercept terra::rast and capture
  # the source string the loader hands to GDAL.
  captured <- NULL
  fake_rast <- function(x, ...) {
    captured <<- x
    structure(list(), class = "SpatRaster")
  }
  testthat::local_mocked_bindings(rast = fake_rast, .package = "terra")

  out <- load_raster_source("soilgrids_cec", "FR")
  expect_s3_class(out, "SpatRaster")
  expect_true(startsWith(captured, "/vsicurl/"))
  expect_true(grepl("soilgrids", captured, fixed = TRUE))
})

test_that("load_raster_source rejects bad aoi argument", {
  fake_rast <- function(x, ...) structure(list(), class = "SpatRaster")
  testthat::local_mocked_bindings(rast = fake_rast, .package = "terra")
  expect_error(
    load_raster_source("soilgrids_cec", "FR", aoi = "not_an_sf"),
    "aoi.*sf"
  )
})

# ---- load_raster_source: explicit path (Theia sources, phase 2) ----

test_that("load_raster_source loads a path-less raster_local via path", {
  # Theia sources (forms_t, theia_soil, ...) are raster_local with no
  # declared path: the caller supplies a locally downloaded file.
  captured <- NULL
  fake_rast <- function(x, ...) {
    captured <<- x
    structure(list(), class = "SpatRaster")
  }
  testthat::local_mocked_bindings(rast = fake_rast, .package = "terra")

  tmp <- withr::local_tempfile(fileext = ".tif")
  file.create(tmp)

  out <- load_raster_source("forms_t", "FR", path = tmp)
  expect_s3_class(out, "SpatRaster")
  expect_identical(captured, tmp)
})

test_that("load_raster_source errors when explicit path is missing", {
  expect_error(
    load_raster_source("forms_t", "FR", path = "/no/such/file_xyz.tif"),
    "does not exist"
  )
})

test_that("load_raster_source still refuses path-less raster_local with no path arg", {
  expect_error(
    load_raster_source("theia_soil", "FR"),
    "no.*path"
  )
})

# ---- get_datasource_product ----

test_that("get_datasource_product returns a sub-product", {
  h <- get_datasource_product("forms_t", "height", "FR")
  expect_type(h, "list")
  expect_equal(h$unit, "cm")
  expect_equal(h$resolution_m, 10)
})

test_that("get_datasource_product errors on unknown product", {
  expect_error(
    get_datasource_product("forms_t", "nonexistent", "FR"),
    "no product"
  )
})

test_that("get_datasource_product errors on a source with no products", {
  expect_error(
    get_datasource_product("soilgrids_cec", "anything", "FR"),
    "no .*products"
  )
})

test_that("get_datasource_product errors on unknown datasource", {
  expect_error(
    get_datasource_product("does_not_exist", "height", "FR"),
    "Unknown datasource"
  )
})
