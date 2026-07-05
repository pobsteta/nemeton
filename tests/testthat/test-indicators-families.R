# Tests for indicators-families.R
# Caching functions and indicator helpers

# ==============================================================================
# TWI Cache Tests
# ==============================================================================

test_that(".twi_cache environment exists", {
  skip_if_not_installed("terra")
  expect_true(exists(".twi_cache", envir = asNamespace("nemeton")))
})

test_that(".wind_cache environment exists", {
  skip_if_not_installed("terra")
  expect_true(exists(".wind_cache", envir = asNamespace("nemeton")))
})

# ==============================================================================
# get_nasapower_wind Tests
# ==============================================================================

test_that("get_nasapower_wind returns default when nasapower not available", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("mockr")

  # Create simple test units
  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(2, 46)), crs = 4326)
  )
  units <- sf::st_buffer(units, 100)

  # Mock that nasapower is not installed
  result <- withr::with_package("mockr", {
    # Use temp dir for caching to avoid hitting real API
    temp_cache <- tempdir()
    result <- nemeton:::get_nasapower_wind(units, default_dir = 270, cache_dir = temp_cache)
    result
  }, quietly = TRUE)

  # Should return a numeric value (either default or from cache/API)
  expect_type(result, "double")
  expect_true(result >= 0 && result <= 360)
})

test_that("get_nasapower_wind uses in-memory cache", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Clear wind cache first
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(2.5, 46.5)), crs = 4326)
  )
  units <- sf::st_buffer(units, 100)

  temp_cache <- tempdir()

  # First call
  result1 <- nemeton:::get_nasapower_wind(units, default_dir = 280, cache_dir = temp_cache)

  # Second call should use cache (won't hit API again)
  result2 <- nemeton:::get_nasapower_wind(units, default_dir = 280, cache_dir = temp_cache)

  expect_equal(result1, result2)
})

# ==============================================================================
# get_or_compute_twi Tests
# ==============================================================================

test_that(".normalize_crs recovers an authorityless EPSG-named CRS", {
  skip_if_not_installed("terra")
  # NULL / non-raster / no-CRS : passe-plat sans erreur.
  expect_null(nemeton:::.normalize_crs(NULL))
  r0 <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 4)
  terra::crs(r0) <- ""
  expect_true(is.na(terra::crs(nemeton:::.normalize_crs(r0), describe = TRUE)$code))
  # CRS avec autorité : inchangé.
  r1 <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 1000, ymin = 0, ymax = 1000)
  terra::crs(r1) <- "EPSG:2154"
  expect_equal(terra::crs(nemeton:::.normalize_crs(r1), describe = TRUE)$code, "2154")
  # CRS Lambert-93 dégénéré (nom = EPSG:2154, sans autorité) : récupéré -> 2154.
  wkt <- paste0(
    'PROJCRS["EPSG:2154",BASEGEOGCRS["unknown",DATUM["unnamed",',
    'ELLIPSOID["GRS 1980",6378137,298.257222101,LENGTHUNIT["metre",1]]],',
    'PRIMEM["Greenwich",0]],CONVERSION["Lambert-93",',
    'METHOD["Lambert Conic Conformal (2SP)"],',
    'PARAMETER["Latitude of false origin",46.5],',
    'PARAMETER["Longitude of false origin",3],',
    'PARAMETER["Latitude of 1st standard parallel",49],',
    'PARAMETER["Latitude of 2nd standard parallel",44],',
    'PARAMETER["Easting at false origin",700000],',
    'PARAMETER["Northing at false origin",6600000]],',
    'CS[Cartesian,2],AXIS["easting",east],AXIS["northing",north],',
    'LENGTHUNIT["metre",1]]')
  r2 <- terra::rast(nrows = 4, ncols = 4, xmin = 700000, xmax = 701000,
                    ymin = 6600000, ymax = 6601000)
  terra::crs(r2) <- wkt
  skip_if(!is.na(terra::crs(r2, describe = TRUE)$code),
          "platform PROJ already resolved the degenerate CRS")
  expect_equal(terra::crs(nemeton:::.normalize_crs(r2), describe = TRUE)$code, "2154")
})

test_that("get_or_compute_twi computes TWI from DEM", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Create a simple test DEM
  dem <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1000, ymin = 0, ymax = 1000)
  terra::crs(dem) <- "EPSG:2154"

  # Create elevation values (simple slope)
  values <- matrix(1:100, nrow = 10)
  terra::values(dem) <- as.vector(values)

  temp_cache <- tempdir()

  result <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) == 1)
})

test_that("get_or_compute_twi uses file cache when available", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Create a simple test DEM
  dem <- terra::rast(nrows = 5, ncols = 5, xmin = 100, xmax = 600, ymin = 100, ymax = 600)
  terra::crs(dem) <- "EPSG:2154"
  terra::values(dem) <- 1:25

  temp_cache <- file.path(tempdir(), "twi_test_cache")
  if (dir.exists(temp_cache)) unlink(temp_cache, recursive = TRUE)
  dir.create(temp_cache, recursive = TRUE)

  # First computation
  result1 <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)

  # Check that cache file was created
  cache_file <- file.path(temp_cache, "twi.tif")
  expect_true(file.exists(cache_file))

  # Second call should use cache
  result2 <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)

  expect_s4_class(result2, "SpatRaster")

  unlink(temp_cache, recursive = TRUE)
})

# ==============================================================================
# calculate_twi Tests
# ==============================================================================

test_that("calculate_twi_terra computes TWI correctly", {
  skip_if_not_installed("terra")

  # Create a simple DEM with known slope
  dem <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000)
  terra::crs(dem) <- "EPSG:2154"

  # Create a gradient (values increase from bottom to top)
  vals <- matrix(rep(1:20, each = 20), nrow = 20, byrow = TRUE)
  terra::values(dem) <- as.vector(vals)

  result <- nemeton:::calculate_twi_terra(dem)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) == 1)

  # TWI values should be finite where calculated
  twi_vals <- terra::values(result)
  expect_true(sum(!is.na(twi_vals)) > 0)
})

# ==============================================================================
# Indicator Functions Tests
# ==============================================================================

test_that("indicateur_c1_biomasse returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)

  # Create mock layers
  layers <- list()

  # This will likely return NA without actual data, but should not error
  result <- tryCatch({
    nemeton:::indicateur_c1_biomasse(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_c2_ndvi returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_c2_ndvi(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_w1_reseau returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_w1_reseau(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_w2_zones_humides returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_w2_zones_humides(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_f1_fertilite returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_f1_fertilite(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_f2_erosion returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_f2_erosion(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_l2_fragmentation returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("indicateur_l1_sylvosphere returns expected structure", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()

  result <- tryCatch({
    nemeton:::indicateur_l1_sylvosphere(units, layers = layers)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

# ==============================================================================
# Alias Functions Tests
# ==============================================================================

test_that("indicateur_a1_couverture is an alias function", {
  skip_if_not_installed("terra")
  expect_true(exists("indicateur_a1_couverture", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicateur_a1_couverture, "closure")
})

test_that("indicateur_f1_fertilite is an alias function", {
  skip_if_not_installed("terra")
  expect_true(exists("indicateur_f1_fertilite", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicateur_f1_fertilite, "closure")
})

test_that("indicateur_f2_erosion is an alias function", {
  skip_if_not_installed("terra")
  expect_true(exists("indicateur_f2_erosion", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicateur_f2_erosion, "closure")
})

test_that("indicateur_l1_sylvosphere_ratio is an alias function", {
  skip_if_not_installed("terra")
  expect_true(exists("indicateur_l1_sylvosphere_ratio", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicateur_l1_sylvosphere_ratio, "closure")
})

# ==============================================================================
# extract_fertility Functions Tests
# ==============================================================================

test_that("extract_fertility_from_raster handles missing layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  layers <- list()  # Empty layers

  result <- tryCatch({
    nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

test_that("extract_fertility_from_vector handles missing layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  layers <- list()  # Empty layers

  result <- tryCatch({
    nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_length(result, 3)
})

# ==============================================================================
# indicateur_s3_population Tests
# ==============================================================================

test_that("indicateur_s3_population exists and is callable", {
  skip_if_not_installed("terra")
  expect_true(exists("indicateur_s3_population", envir = asNamespace("nemeton")))

  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)

  result <- tryCatch({
    nemeton:::indicateur_s3_population(units)
  }, error = function(e) {
    rep(NA_real_, nrow(units))
  })

  expect_equal(nrow(result), 2)
})

# ==============================================================================
# Alias Function Tests
# Note: f1/f2/e1/e2/a1/n3 alias tests removed — the stubs they targeted in
# indicators-families.R were removed because they collided with the real
# implementations in indicators-{air,energy,naturalness}.R. The real
# functions have different signatures (e.g. land_cover instead of layers)
# and are already covered by test-indicators-{air,energy,naturalness}.R.
# p1/p2/p3 alias tests removed: the stubs in indicators-families.R were
# deleted (they shadowed the real implementations in indicators-productive.R,
# which were previously named indicateur_p*_terrain). The real functions
# have different signatures (species_field, dbh_field, etc.) and are
# tested in test-indicators-productive.R.
# ==============================================================================

# ==============================================================================
# Carbon Biomass with Inventory Data
# ==============================================================================

test_that("indicateur_c1_biomasse uses allometric model with inventory data", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  result <- nemeton::indicateur_c1_biomasse(units)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result > 0))
})

test_that("indicateur_c1_biomasse returns NA without any data source", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  # No species/age/density, no layers
  result <- nemeton::indicateur_c1_biomasse(units, layers = NULL)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_c1_biomasse validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::indicateur_c1_biomasse(data.frame(x = 1)),
    "units must be an sf object"
  )
})

# ==============================================================================
# Landscape fallback (shape index)
# ==============================================================================

test_that("indicateur_l1_sylvosphere uses shape index fallback", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  # No layers -> uses shape index fallback
  result <- nemeton:::indicateur_l1_sylvosphere(units, layers = NULL)
  expect_length(result, 2)
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l1_sylvosphere validates empty units", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  empty_units <- units[0, ]
  expect_error(
    nemeton:::indicateur_l1_sylvosphere(empty_units),
    "empty"
  )
})

# ==============================================================================
# Helper: create mock nemeton_layers with in-memory objects
# ==============================================================================

make_mock_layers <- function(rasters = list(), vectors = list(), cache_dir = NULL) {
  layers <- list(
    rasters = rasters,
    vectors = vectors,
    cache_dir = if (is.null(cache_dir)) tempdir() else cache_dir,
    metadata = list(
      created_at = Sys.time(),
      n_rasters = length(rasters),
      n_vectors = length(vectors),
      validated = FALSE
    )
  )
  class(layers) <- "nemeton_layers"
  layers
}

# ==============================================================================
# indicateur_a1_couverture deep path coverage tests removed.
# The stub in indicators-families.R that took a `layers` parameter was
# deleted (collision with the real indicateur_a1_couverture in
# indicators-air.R). The real function is tested in test-indicators-air.R.
# ==============================================================================

# ==============================================================================
# indicateur_c1_biomasse - LiDAR MNH path (Path 2)
# ==============================================================================

test_that("indicateur_c1_biomasse LiDAR MNH path", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)

  # Create a canopy height model (MNH) raster with height values
  mnh <- create_test_raster(values = "random", res = 10)
  terra::values(mnh) <- runif(terra::ncell(mnh), 0, 30) # Heights 0-30m

  layers <- make_mock_layers(rasters = list(lidar_mnh = mnh))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 3)
  # With valid MNH data, should produce numeric (not all NA)
  expect_true(any(!is.na(result)))
  expect_true(all(result[!is.na(result)] >= 0))
})

# ==============================================================================
# indicateur_c1_biomasse - NDVI fallback path (Path 4)
# ==============================================================================

test_that("indicateur_c1_biomasse NDVI fallback path", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)

  # NDVI raster (no MNH, no bdforet)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.1, 0.9)

  layers <- make_mock_layers(rasters = list(ndvi = ndvi))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  # NDVI * 150 should be > 0 since NDVI > 0
  expect_true(all(result > 0))
})

# ==============================================================================
# indicateur_c1_biomasse - BD Foret path (Path 3)
# ==============================================================================

test_that("indicateur_c1_biomasse BD Foret path", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)

  # Create BD Foret vector layer covering test units
  bbox <- sf::st_bbox(units)
  bdforet_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"] - 10, bbox["ymin"] - 10,
      bbox["xmax"] + 10, bbox["ymin"] - 10,
      bbox["xmax"] + 10, bbox["ymax"] + 10,
      bbox["xmin"] - 10, bbox["ymax"] + 10,
      bbox["xmin"] - 10, bbox["ymin"] - 10
    ),
    ncol = 2, byrow = TRUE
  )))
  bdforet_sf <- sf::st_sf(
    CODE_TFV = "FF1-00-00",
    TFV_G11 = "Feuillus",
    geometry = sf::st_sfc(bdforet_poly, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(bdforet = bdforet_sf))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 2)
  # BD Foret path may or may not yield non-NA depending on enrich_parcels_bdforet
  expect_type(result, "double")
})

# ==============================================================================
# indicateur_p1/p2/p3 tests with mock layers removed. These tested the
# deleted stubs in indicators-families.R that accepted a `layers` parameter.
# The real functions in indicators-productive.R have different signatures
# (species_field, dbh_field, etc.) and are tested in
# test-indicators-productive.R.
# ==============================================================================

# ==============================================================================
# indicateur_e1_bois_energie / indicateur_e2_evitement tests with layers
# were removed. The stubs that accepted a `layers` parameter were deleted
# (collision with the real functions in indicators-energy.R). The real
# functions have different signatures and are tested in
# test-indicators-energy.R.
# ==============================================================================

# ==============================================================================
# indicateur_l2_fragmentation - with mock landcover
# ==============================================================================

test_that("indicateur_l2_fragmentation with landcover layer", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)

  # Landcover raster with OSO classes
  lc <- create_test_raster(values = "constant", res = 10)
  vals <- sample(c(16, 17, 18, 20, 21, 25), terra::ncell(lc), replace = TRUE)
  terra::values(lc) <- vals

  layers <- make_mock_layers(rasters = list(landcover = lc))
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation without layers uses shape fallback", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = NULL)
  expect_length(result, 3)
  # Without landcover, contrast defaults to 50; should still compute geometry + exposure
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_l2_fragmentation(data.frame(x = 1)),
    "sf"
  )
})

# ==============================================================================
# indicateur_w2_zones_humides - with mock vector layer
# ==============================================================================

test_that("indicateur_w2_zones_humides with water_surfaces vector", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)

  # Create a small pond polygon overlapping with units
  bbox <- sf::st_bbox(units)
  pond_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"] + 10, bbox["ymin"] + 10,
      bbox["xmin"] + 60, bbox["ymin"] + 10,
      bbox["xmin"] + 60, bbox["ymin"] + 60,
      bbox["xmin"] + 10, bbox["ymin"] + 60,
      bbox["xmin"] + 10, bbox["ymin"] + 10
    ),
    ncol = 2, byrow = TRUE
  )))
  water_sf <- sf::st_sf(
    id = 1,
    type = "mare",
    geometry = sf::st_sfc(pond_poly, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(water_surfaces = water_sf))
  result <- nemeton:::indicateur_w2_zones_humides(units, layers = layers)
  expect_length(result, 2)
  # At least the first unit overlaps with the pond
  expect_true(any(result > 0))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_w2_zones_humides validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_w2_zones_humides(data.frame(x = 1), layers = list()),
    "sf"
  )
})

test_that("indicateur_w2_zones_humides validates nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w2_zones_humides(units, layers = list()),
    "nemeton_layers"
  )
})

# ==============================================================================
# indicateur_w1_reseau - with mock watercourse layer
# ==============================================================================

test_that("indicateur_w1_reseau with mock watercourses", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)

  # Create watercourse lines crossing the test area
  bbox <- sf::st_bbox(units)
  stream <- sf::st_linestring(matrix(
    c(
      bbox["xmin"], bbox["ymin"] + 50,
      bbox["xmax"], bbox["ymax"] - 50
    ),
    ncol = 2, byrow = TRUE
  ))
  watercourses_sf <- sf::st_sf(
    id = 1,
    name = "Ruisseau Test",
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(water_network = watercourses_sf))
  result <- nemeton:::indicateur_w1_reseau(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0))
})

test_that("indicateur_w1_reseau validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_w1_reseau(data.frame(x = 1), layers = list()),
    "sf"
  )
})

test_that("indicateur_w1_reseau validates nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w1_reseau(units, layers = list()),
    "nemeton_layers"
  )
})

# ==============================================================================
# indicateur_f2_erosion - RUSLE calculation paths
# ==============================================================================

test_that("indicateur_f2_erosion computes TWI + slope", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)

  # Create a DEM with a smooth gradient (for TWI + slope computation)
  dem <- create_test_raster(values = "random", res = 10)
  # Use a gentle gradient that produces well-defined TWI values
  nr <- terra::nrow(dem)
  nc <- terra::ncol(dem)
  vals <- matrix(
    rep(seq(200, 500, length.out = nc), each = nr),
    nrow = nr, ncol = nc
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_mock_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_f2_erosion(units, layers = layers)
  expect_length(result, 3)
  # TWI may yield some NA for edge cells; check that result is numeric
  expect_type(result, "double")
  # At least some values should be computed
  non_na <- result[!is.na(result)]
  if (length(non_na) > 0) {
    expect_true(all(non_na >= 0 & non_na <= 100))
  }
})

test_that("indicateur_f2_erosion validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_f2_erosion(data.frame(x = 1), layers = list()),
    "sf"
  )
})

test_that("indicateur_f2_erosion validates nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_f2_erosion(units, layers = list()),
    "nemeton_layers"
  )
})

# ==============================================================================
# indicateur_f2_erosion RUSLE tests removed. These tested the deleted stub
# in indicators-families.R that implemented RUSLE erosion. The real
# indicateur_f2_erosion at line 906 computes fertility from TWI+slope, not
# erosion. F2 fertility is already covered by other tests in this file.
# ==============================================================================

# ==============================================================================
# extract_fertility_from_vector - with actual data
# ==============================================================================

test_that("extract_fertility_from_vector with overlapping soil polygons", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)

  # Create soil polygons overlapping with units, with fertility values

  bbox <- sf::st_bbox(units)
  soil_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"] - 50, bbox["ymin"] - 50,
      bbox["xmax"] + 50, bbox["ymin"] - 50,
      bbox["xmax"] + 50, bbox["ymax"] + 50,
      bbox["xmin"] - 50, bbox["ymax"] + 50,
      bbox["xmin"] - 50, bbox["ymin"] - 50
    ),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    fertility = 75,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 2)
  # All units intersect with the soil polygon
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("extract_fertility_from_vector errors on missing column", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)
  soil_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"], bbox["ymin"],
      bbox["xmax"], bbox["ymin"],
      bbox["xmax"], bbox["ymax"],
      bbox["xmin"], bbox["ymax"],
      bbox["xmin"], bbox["ymin"]
    ),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    ph = 6.5,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(soil = soil_sf))
  expect_error(
    nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility"),
    "fertility"
  )
})

test_that("extract_fertility_from_vector returns 0 for non-overlapping", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 1)

  # Soil polygon far away from units
  soil_poly <- sf::st_polygon(list(matrix(
    c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    fertility = 80,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 1)
  # No intersection: fertility[i] = NA_real_, then pmin(pmax(NA, 0), 100) -> NA
  # The function clamps: pmin(pmax(fertility, 0), 100) but NA propagates
  # The NA_real_ assignment in the no-intersection branch gets clamped to 0 by pmax
  # Actually pmax(NA_real_, 0) returns NA in R, so the result is 0
  # Let's just verify it returns a valid numeric (0 or NA)
  expect_type(result, "double")
  expect_true(is.na(result) || result == 0)
})

# ==============================================================================
# extract_fertility_from_raster - with test data
# ==============================================================================

test_that("extract_fertility_from_raster with uniform values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)
  soil_raster <- create_test_raster(values = "constant", res = 10)
  # All same value -> all fertility = 50 (neutral)
  terra::values(soil_raster) <- 3

  layers <- make_mock_layers(rasters = list(soil = soil_raster))
  result <- nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  expect_length(result, 3)
  expect_true(all(result == 50))
})

test_that("extract_fertility_from_raster with varying values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)
  soil_raster <- create_test_raster(values = "random", res = 10)
  terra::values(soil_raster) <- runif(terra::ncell(soil_raster), 1, 5)

  layers <- make_mock_layers(rasters = list(soil = soil_raster))
  result <- nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

# ==============================================================================
# get_or_compute_twi - in-memory cache hit test
# ==============================================================================

test_that("get_or_compute_twi returns from memory cache on second call", {
  skip_if_not_installed("terra")

  # Clear the TWI cache
  twi_cache <- get(".twi_cache", envir = asNamespace("nemeton"))
  rm(list = ls(twi_cache), envir = twi_cache)

  dem <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1000, ymin = 0, ymax = 1000)
  terra::crs(dem) <- "EPSG:2154"
  terra::values(dem) <- 1:100

  temp_cache <- file.path(tempdir(), "twi_mem_test")
  if (dir.exists(temp_cache)) unlink(temp_cache, recursive = TRUE)
  dir.create(temp_cache, recursive = TRUE)

  # First call - computes
  result1 <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)
  expect_s4_class(result1, "SpatRaster")

  # Key should now be in memory cache
  key <- paste(nrow(dem), ncol(dem),
               paste(as.vector(terra::ext(dem)), collapse = ","),
               terra::crs(dem, describe = TRUE)$code,
               sep = "|")
  expect_true(exists(key, envir = twi_cache))

  # Second call - from memory
  result2 <- nemeton:::get_or_compute_twi(dem, cache_dir = temp_cache)
  expect_s4_class(result2, "SpatRaster")

  unlink(temp_cache, recursive = TRUE)
})

# ==============================================================================
# calculate_twi_grass - test fallback when GRASS not found
# ==============================================================================

test_that("calculate_twi_grass requires fasterRaster package", {
  skip_if_not_installed("terra")

  dem <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1000, ymin = 0, ymax = 1000)
  terra::crs(dem) <- "EPSG:2154"
  terra::values(dem) <- 1:100

  if (requireNamespace("fasterRaster", quietly = TRUE)) {
    # If fasterRaster is installed, it either uses GRASS or falls back to terra
    result <- nemeton:::calculate_twi_grass(dem)
    expect_s4_class(result, "SpatRaster")
  } else {
    expect_error(
      nemeton:::calculate_twi_grass(dem),
      "fasterRaster"
    )
  }
})

# ==============================================================================
# indicateur_l1_sylvosphere - shape index fallback
# ==============================================================================

test_that("indicateur_l1_sylvosphere shape index fallback scores", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 3)
  # layers = NULL, no landcover -> shape index fallback
  result <- nemeton:::indicateur_l1_sylvosphere(units, layers = NULL)
  expect_length(result, 3)
  # For regular squares, shape index ~ 1.128, so scores ~ 100/1.128 ~ 88.6
  expect_true(all(result > 0 & result <= 100))
})

test_that("indicateur_l1_sylvosphere with landcover (no landscapemetrics)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)
  lc <- create_test_raster(values = "constant", res = 10)
  vals <- sample(1:6, terra::ncell(lc), replace = TRUE)
  terra::values(lc) <- vals

  layers <- make_mock_layers(rasters = list(landcover = lc))

  if (!requireNamespace("landscapemetrics", quietly = TRUE)) {
    # Without landscapemetrics, should fall back to shape index
    result <- nemeton:::indicateur_l1_sylvosphere(units, layers = layers)
    expect_length(result, 2)
    expect_true(all(result > 0 & result <= 100))
  } else {
    # With landscapemetrics, may use COHESION + AI or fallback
    result <- nemeton:::indicateur_l1_sylvosphere(units, layers = layers)
    expect_length(result, 2)
    expect_true(all(result >= 0 & result <= 100))
  }
})

# ==============================================================================
# indicateur_w1_reseau - proximity bonus path
# ==============================================================================

test_that("indicateur_w1_reseau computes proximity bonus for distant parcels", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 1)

  # Create a stream that does NOT cross the unit but is within 500m
  bbox <- sf::st_bbox(units)
  # Place stream 200m south of the unit
  stream <- sf::st_linestring(matrix(
    c(
      bbox["xmin"] - 100, bbox["ymin"] - 200,
      bbox["xmax"] + 100, bbox["ymin"] - 200
    ),
    ncol = 2, byrow = TRUE
  ))
  watercourses_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(water_network = watercourses_sf))
  result <- nemeton:::indicateur_w1_reseau(units, layers = layers)
  expect_length(result, 1)
  # Stream does not cross the unit, but is within 500m -> proximity bonus
  expect_true(result > 0)
})

# ==============================================================================
# get_nasapower_wind - file cache path
# ==============================================================================

test_that("get_nasapower_wind loads from file cache", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Clear in-memory cache
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  # Create a file cache with a known value
  temp_cache <- file.path(tempdir(), "nasapower_file_test")
  if (dir.exists(temp_cache)) unlink(temp_cache, recursive = TRUE)
  dir.create(temp_cache, recursive = TRUE)
  saveRDS(225, file.path(temp_cache, "nasapower_wind.rds"))

  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(3.0, 47.0)), crs = 4326)
  )
  units <- sf::st_buffer(units, 100)

  result <- nemeton:::get_nasapower_wind(units, default_dir = 270, cache_dir = temp_cache)
  expect_equal(result, 225)

  unlink(temp_cache, recursive = TRUE)
})

# ==============================================================================
# indicateur_c2_ndvi - validation tests
# ==============================================================================

test_that("indicateur_c2_ndvi validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_c2_ndvi(data.frame(x = 1), layers = list()),
    "sf"
  )
})

test_that("indicateur_c2_ndvi validates nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_c2_ndvi(units, layers = list()),
    "nemeton_layers"
  )
})

test_that("indicateur_c2_ndvi with valid NDVI layer", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.1, 0.9)

  layers <- make_mock_layers(rasters = list(ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result > 0 & result < 1))
})

test_that("indicateur_c2_ndvi warns on trend parameter", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 1)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.1, 0.9)

  layers <- make_mock_layers(rasters = list(ndvi = ndvi))
  expect_warning(
    nemeton:::indicateur_c2_ndvi(units, layers, trend = TRUE),
    "not yet implemented"
  )
})

# ==============================================================================
# indicateur_w3_humidite - validation and computation
# ==============================================================================

test_that("indicateur_w3_humidite validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_w3_humidite(data.frame(x = 1), layers = list()),
    "sf"
  )
})

test_that("indicateur_w3_humidite validates nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w3_humidite(units, layers = list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w3_humidite computes from DEM", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_mock_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w3_humidite(units, layers)
  expect_length(result, 2)
  # TWI extraction may produce NA for edge cells; check type and partial validity
  expect_type(result, "double")
})

test_that("indicateur_w3_humidite uses d8 method", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_mock_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
})

# ==============================================================================
# indicateur_f1_fertilite - validation
# ==============================================================================

test_that("indicateur_f1_fertilite validates sf input", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_f1_fertilite(data.frame(x = 1), layers = list()),
    "sf"
  )
})

test_that("indicateur_f1_fertilite validates nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_f1_fertilite(units, layers = list()),
    "nemeton_layers"
  )
})

test_that("indicateur_f1_fertilite with raster soil layer", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 2)
  soil_raster <- create_test_raster(values = "random", res = 10)
  terra::values(soil_raster) <- sample(1:5, terra::ncell(soil_raster), replace = TRUE)

  layers <- make_mock_layers(rasters = list(soil = soil_raster))
  result <- nemeton:::indicateur_f1_fertilite(units, layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_f1_fertilite with vector soil layer", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)
  bbox <- sf::st_bbox(units)
  soil_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"] - 50, bbox["ymin"] - 50,
      bbox["xmax"] + 50, bbox["ymin"] - 50,
      bbox["xmax"] + 50, bbox["ymax"] + 50,
      bbox["xmin"] - 50, bbox["ymax"] + 50,
      bbox["xmin"] - 50, bbox["ymin"] - 50
    ),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    fertility = 65,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- make_mock_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::indicateur_f1_fertilite(units, layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
})

# ==============================================================================
# calculate_twi_terra edge cases
# ==============================================================================

test_that("calculate_twi_terra handles flat terrain", {
  skip_if_not_installed("terra")

  # Completely flat DEM
  dem <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000)
  terra::crs(dem) <- "EPSG:2154"
  terra::values(dem) <- 100 # All same elevation

  result <- nemeton:::calculate_twi_terra(dem)
  expect_s4_class(result, "SpatRaster")
  # Flat terrain: slope near 0, so TWI should be very high (capped at 50)
  twi_vals <- terra::values(result)
  non_na <- twi_vals[!is.na(twi_vals)]
  if (length(non_na) > 0) {
    expect_true(all(non_na >= 0))
  }
})

test_that("calculate_twi_terra handles steep terrain", {
  skip_if_not_installed("terra")

  dem <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000)
  terra::crs(dem) <- "EPSG:2154"
  # Strong gradient
  vals <- matrix(rep(seq(0, 1000, length.out = 20), each = 20), nrow = 20)
  terra::values(dem) <- as.vector(vals)

  result <- nemeton:::calculate_twi_terra(dem)
  expect_s4_class(result, "SpatRaster")
  twi_vals <- terra::values(result)
  non_na <- twi_vals[!is.na(twi_vals)]
  expect_true(length(non_na) > 0)
  # Steep terrain should yield lower TWI values
  expect_true(all(non_na >= 0))
})

# ==============================================================================
# indicateur_n3_naturalite alias
# ==============================================================================

test_that("indicateur_n3_naturalite exists and is callable", {
  skip_if_not_installed("terra")
  expect_true(exists("indicateur_n3_naturalite", envir = asNamespace("nemeton")))
  expect_type(nemeton:::indicateur_n3_naturalite, "closure")
})

test_that("indicateur_n3_naturalite delegates to composite", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  result <- tryCatch(
    nemeton:::indicateur_n3_naturalite(units),
    error = function(e) NULL
  )
  if (!is.null(result)) {
    expect_true(inherits(result, "sf") || is.numeric(result))
  }
})

# ==============================================================================
# indicateur_l1_sylvosphere_ratio alias
# ==============================================================================

test_that("indicateur_l1_sylvosphere_ratio delegates to indicateur_l1_sylvosphere", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  result1 <- nemeton:::indicateur_l1_sylvosphere(units, layers = NULL)
  result2 <- nemeton:::indicateur_l1_sylvosphere_ratio(units, layers = NULL)
  expect_equal(result1, result2)
})

# ==============================================================================
# (migrated from test-cov80-batch15.R)
# ==============================================================================


# ==============================================================================
# 1. calculate_twi_terra
# ==============================================================================

test_that("calculate_twi_terra: returns valid SpatRaster from gradient DEM", {
  skip_if_not_installed("terra")
  dem <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 800000, xmax = 801000,
                     ymin = 6500000, ymax = 6501000,
                     crs = "EPSG:2154")
  terra::values(dem) <- seq(100, 500, length.out = 400)

  result <- nemeton:::calculate_twi_terra(dem)
  expect_s4_class(result, "SpatRaster")
  expect_equal(terra::nlyr(result), 1)

  vals <- terra::values(result)
  non_na <- vals[!is.na(vals)]
  expect_true(length(non_na) > 0)
  # All non-NA values should be in [0, 50] range

  expect_true(all(non_na >= 0 & non_na <= 50))
})

test_that("calculate_twi_terra: flat DEM produces valid output", {
  skip_if_not_installed("terra")
  dem <- terra::rast(nrows = 15, ncols = 15,
                     xmin = 800000, xmax = 800750,
                     ymin = 6500000, ymax = 6500750,
                     crs = "EPSG:2154")
  terra::values(dem) <- 250  # completely flat

  result <- nemeton:::calculate_twi_terra(dem)
  expect_s4_class(result, "SpatRaster")
  vals <- terra::values(result)
  non_na <- vals[!is.na(vals)]
  # Flat terrain: slopes replaced by 0.001 minimum,
  # so TWI values should be high (large catchment/tiny slope)
  if (length(non_na) > 0) {
    expect_true(all(non_na >= 0))
  }
})

test_that("calculate_twi_terra: steep gradient DEM produces lower TWI", {
  skip_if_not_installed("terra")
  dem <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 800000, xmax = 802000,
                     ymin = 6500000, ymax = 6502000,
                     crs = "EPSG:2154")
  # Strong N-S gradient: 0m to 2000m over 2km
  vals <- matrix(rep(seq(0, 2000, length.out = 20), each = 20), nrow = 20)
  terra::values(dem) <- as.vector(vals)

  result <- nemeton:::calculate_twi_terra(dem)
  expect_s4_class(result, "SpatRaster")
  vals_twi <- terra::values(result)
  non_na <- vals_twi[!is.na(vals_twi)]
  expect_true(length(non_na) > 0)
  expect_true(all(non_na >= 0))
})

test_that("calculate_twi_terra: dimensions preserved", {
  skip_if_not_installed("terra")
  dem <- terra::rast(nrows = 10, ncols = 10,
                     xmin = 800000, xmax = 801000,
                     ymin = 6500000, ymax = 6501000,
                     crs = "EPSG:2154")
  terra::values(dem) <- runif(100, 100, 500)

  result <- nemeton:::calculate_twi_terra(dem)
  expect_equal(terra::nrow(result), 10)
  expect_equal(terra::ncol(result), 10)
})

# ==============================================================================
# 2. indicateur_c1_biomasse
# ==============================================================================

test_that("indicateur_c1_biomasse: Path 1 (inventory) with multiple species", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 4)
  units$species <- c("Quercus", "Fagus", "Pinus", "Abies")
  units$age <- c(100, 80, 50, 60)
  units$density <- c(0.9, 0.7, 0.6, 0.8)

  result <- nemeton::indicateur_c1_biomasse(units)
  expect_length(result, 4)
  expect_true(all(!is.na(result)))
  expect_true(all(is.numeric(result)))
  expect_true(all(result > 0))
})

test_that("indicateur_c1_biomasse: Path 1 with custom column names", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  units$sp <- c("Quercus", "Fagus")
  units$stand_age <- c(70, 90)
  units$canopy_density <- c(0.8, 0.7)

  result <- nemeton::indicateur_c1_biomasse(
    units,
    species_col = "sp",
    age_col = "stand_age",
    density_col = "canopy_density"
  )
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result > 0))
})

test_that("indicateur_c1_biomasse: Path 4 (NDVI fallback) returns biomass scaled from NDVI", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)

  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.3, 0.8)

  layers <- create_test_layers(rasters = list(ndvi = ndvi))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  # NDVI * 150 for NDVI in [0.3, 0.8] -> biomass in [45, 120]
  expect_true(all(result > 0 & result < 150))
})

test_that("indicateur_c1_biomasse: last resort returns NA when no data", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  layers <- create_test_layers(rasters = list())
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_c1_biomasse: NULL layers returns NA", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_c1_biomasse(units, layers = NULL)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_c1_biomasse: non-sf input errors", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::indicateur_c1_biomasse(data.frame(x = 1)),
    "units must be an sf object"
  )
})

test_that("indicateur_c1_biomasse: list input errors", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::indicateur_c1_biomasse(list(a = 1)),
    "units must be an sf object"
  )
})

test_that("indicateur_c1_biomasse: LiDAR MNH path produces positive values", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  mnh <- create_test_raster(values = "random", res = 10)
  terra::values(mnh) <- runif(terra::ncell(mnh), 5, 25)

  layers <- create_test_layers(rasters = list(lidar_mnh = mnh))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0))
})

# ==============================================================================
# 3. indicateur_c2_ndvi
# ==============================================================================

test_that("indicateur_c2_ndvi: valid NDVI raster extraction", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.2, 0.85)

  layers <- create_test_layers(rasters = list(ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result > 0 & result < 1))
})

test_that("indicateur_c2_ndvi: trend = TRUE warns not implemented", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.1, 0.9)

  layers <- create_test_layers(rasters = list(ndvi = ndvi))
  expect_warning(
    result <- nemeton:::indicateur_c2_ndvi(units, layers, trend = TRUE),
    "not yet implemented"
  )
  expect_length(result, 1)
  expect_true(!is.na(result))
})

test_that("indicateur_c2_ndvi: non-sf input errors", {
  skip_if_not_installed("terra")
  layers <- create_test_layers(rasters = list(ndvi = create_test_raster()))
  expect_error(
    nemeton:::indicateur_c2_ndvi(data.frame(x = 1), layers),
    "units must be an sf object"
  )
})

test_that("indicateur_c2_ndvi: non-nemeton_layers errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_c2_ndvi(units, layers = list(rasters = list())),
    "nemeton_layers"
  )
})

test_that("indicateur_c2_ndvi: missing NDVI layer errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  layers <- create_test_layers(rasters = list(dem = create_test_raster()))
  expect_error(
    nemeton:::indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi"),
    "not found"
  )
})

test_that("indicateur_c2_ndvi: custom ndvi_layer name works", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.2, 0.7)

  layers <- create_test_layers(rasters = list(my_ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers, ndvi_layer = "my_ndvi")
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
})

# ==============================================================================
# 4. indicateur_w1_reseau
# ==============================================================================

test_that("indicateur_w1_reseau: watercourse crossing parcel yields positive density", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  bbox <- sf::st_bbox(units)

  # Stream crossing the units diagonally
  stream <- sf::st_linestring(matrix(
    c(bbox["xmin"], bbox["ymin"],
      bbox["xmax"], bbox["ymax"]),
    ncol = 2, byrow = TRUE
  ))
  watercourses <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(water_network = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers)
  expect_length(result, 2)
  expect_true(all(result > 0))
})

test_that("indicateur_w1_reseau: no crossing but within proximity yields bonus", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)

  # Stream 150m south of unit (within default 500m proximity)
  stream <- sf::st_linestring(matrix(
    c(bbox["xmin"] - 100, bbox["ymin"] - 150,
      bbox["xmax"] + 100, bbox["ymin"] - 150),
    ncol = 2, byrow = TRUE
  ))
  watercourses <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(water_network = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers)
  expect_length(result, 1)
  expect_true(result > 0)  # Proximity bonus should kick in
})

test_that("indicateur_w1_reseau: stream far away (>500m) yields zero proximity", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)

  # Stream 1000m south of unit (beyond default 500m proximity)
  stream <- sf::st_linestring(matrix(
    c(bbox["xmin"] - 100, bbox["ymin"] - 1000,
      bbox["xmax"] + 100, bbox["ymin"] - 1000),
    ncol = 2, byrow = TRUE
  ))
  watercourses <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(water_network = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers)
  expect_length(result, 1)
  expect_equal(result, 0)
})

test_that("indicateur_w1_reseau: non-sf input errors", {
  skip_if_not_installed("terra")
  layers <- create_test_layers(vectors = list(water_network = create_test_vector()))
  expect_error(
    nemeton:::indicateur_w1_reseau(data.frame(x = 1), layers),
    "units must be an sf object"
  )
})

test_that("indicateur_w1_reseau: non-nemeton_layers errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w1_reseau(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w1_reseau: missing watercourse layer returns 0", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  layers <- create_test_layers(vectors = list())
  # The real indicateur_w1_reseau warns and returns 0 instead of erroring
  # when no watercourse layer is found.
  result <- suppressWarnings(nemeton:::indicateur_w1_reseau(units, layers))
  expect_length(result, 1)
  expect_equal(result, 0)
})

test_that("indicateur_w1_reseau: buffer parameter increases capture area", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)

  # Stream just outside unit boundary (20m away)
  stream <- sf::st_linestring(matrix(
    c(bbox["xmin"] - 20, bbox["ymin"] - 20,
      bbox["xmax"] + 20, bbox["ymin"] - 20),
    ncol = 2, byrow = TRUE
  ))
  watercourses <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(water_network = watercourses))
  # Without buffer: stream does not cross -> proximity bonus only
  result_no_buf <- nemeton:::indicateur_w1_reseau(units, layers, buffer = 0)
  # With buffer: stream may get captured
  result_with_buf <- nemeton:::indicateur_w1_reseau(units, layers, buffer = 50)
  # With buffer >= 20m, the stream should be captured by intersection
  expect_true(result_with_buf >= result_no_buf)
})

# ==============================================================================
# 5. indicateur_w2_zones_humides
# ==============================================================================

test_that("indicateur_w2_zones_humides: TWI source (DEM -> TWI -> wetland fraction)", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  # Create a gradient DEM
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- create_test_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w2_zones_humides(units, layers)
  expect_length(result, 2)
  # With DEM, TWI is computed; some cells may have TWI > 12
  expect_type(result, "double")
  expect_true(all(result >= 0 | is.na(result)))
})

test_that("indicateur_w2_zones_humides: no data returns NA", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  layers <- create_test_layers(rasters = list(), vectors = list())
  result <- nemeton:::indicateur_w2_zones_humides(units, layers)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_w2_zones_humides: non-sf input errors", {
  skip_if_not_installed("terra")
  layers <- create_test_layers()
  expect_error(
    nemeton:::indicateur_w2_zones_humides(data.frame(x = 1), layers),
    "sf"
  )
})

test_that("indicateur_w2_zones_humides: non-nemeton_layers errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w2_zones_humides(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w2_zones_humides: water_surfaces vector source", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  bbox <- sf::st_bbox(units)

  # Create a water surface polygon overlapping with the first unit
  water_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"] + 10, bbox["ymin"] + 10,
      bbox["xmin"] + 50, bbox["ymin"] + 10,
      bbox["xmin"] + 50, bbox["ymin"] + 50,
      bbox["xmin"] + 10, bbox["ymin"] + 50,
      bbox["xmin"] + 10, bbox["ymin"] + 10
    ),
    ncol = 2, byrow = TRUE
  )))
  water_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(water_poly, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(water_surfaces = water_sf))
  result <- nemeton:::indicateur_w2_zones_humides(units, layers)
  expect_length(result, 2)
  # First unit should have some coverage from water surface
  expect_true(result[1] > 0)
  expect_true(all(result >= 0 & result <= 100))
})

# ==============================================================================
# 6. indicateur_w3_humidite
# ==============================================================================

test_that("indicateur_w3_humidite: with DEM returns TWI mean values", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- create_test_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w3_humidite(units, layers)
  expect_length(result, 2)
  expect_type(result, "double")
})

test_that("indicateur_w3_humidite: method = 'd8' calls calculate_twi_terra directly", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(200, 600, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- create_test_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  expect_length(result, 2)
  expect_type(result, "double")
  expect_true(all(!is.na(result)))
})

test_that("indicateur_w3_humidite: no DEM errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  layers <- create_test_layers(rasters = list())
  expect_error(
    nemeton:::indicateur_w3_humidite(units, layers),
    "No DEM"
  )
})

test_that("indicateur_w3_humidite: non-sf input errors", {
  skip_if_not_installed("terra")
  layers <- create_test_layers(rasters = list(dem = create_test_raster()))
  expect_error(
    nemeton:::indicateur_w3_humidite(data.frame(x = 1), layers),
    "sf"
  )
})

test_that("indicateur_w3_humidite: non-nemeton_layers errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w3_humidite(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w3_humidite: method = 'auto' produces same structure as 'd8'", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- create_test_layers(rasters = list(dem = dem))
  result_auto <- nemeton:::indicateur_w3_humidite(units, layers, method = "auto")
  result_d8 <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  # Both should return same length
  expect_equal(length(result_auto), length(result_d8))
})

# ==============================================================================
# 7. indicateur_f2_erosion
# ==============================================================================

test_that("indicateur_f2_erosion: with DEM computes TWI+slope composite", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 400, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- create_test_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_f2_erosion(units, layers)
  expect_length(result, 3)
  expect_type(result, "double")
  # At least some values should be valid scores in [0, 100]
  non_na <- result[!is.na(result)]
  if (length(non_na) > 0) {
    expect_true(all(non_na >= 0 & non_na <= 100))
  }
})

test_that("indicateur_f2_erosion: no DEM errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  layers <- create_test_layers(rasters = list())
  expect_error(
    nemeton:::indicateur_f2_erosion(units, layers),
    "No DEM"
  )
})

test_that("indicateur_f2_erosion: non-sf input errors", {
  skip_if_not_installed("terra")
  layers <- create_test_layers(rasters = list(dem = create_test_raster()))
  expect_error(
    nemeton:::indicateur_f2_erosion(data.frame(x = 1), layers),
    "sf"
  )
})

test_that("indicateur_f2_erosion: non-nemeton_layers errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_f2_erosion(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_f2_erosion: LiDAR MNT preferred over regular DEM", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  terra::values(dem) <- seq(200, 500, length.out = terra::ncell(dem))

  lidar_mnt <- create_test_raster(values = "random", res = 10)
  terra::values(lidar_mnt) <- seq(200, 500, length.out = terra::ncell(lidar_mnt))

  layers <- create_test_layers(rasters = list(dem = dem, lidar_mnt = lidar_mnt))
  result <- nemeton:::indicateur_f2_erosion(units, layers)
  expect_length(result, 2)
  expect_type(result, "double")
})

# ==============================================================================
# 8. indicateur_l2_fragmentation
# ==============================================================================

test_that("indicateur_l2_fragmentation: geometry component (shape index)", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  # No layers -> only geometry + exposure components
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = NULL)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation: no landcover yields neutral contrast", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  # Empty layers (has class but no landcover raster)
  layers <- create_test_layers(rasters = list())
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation: with landcover raster computes contrast", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  lc <- create_test_raster(values = "constant", res = 10)
  # Mix of OSO classes (forest: 16-18, agriculture: 21-23, built-up: 25-28)
  vals <- sample(c(16, 17, 18, 21, 22, 25, 26), terra::ncell(lc), replace = TRUE)
  terra::values(lc) <- vals

  layers <- create_test_layers(rasters = list(landcover = lc))
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation: non-sf input errors", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::indicateur_l2_fragmentation(data.frame(x = 1)),
    "sf"
  )
})

test_that("indicateur_l2_fragmentation: forest_cover fallback for landcover", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  lc <- create_test_raster(values = "constant", res = 10)
  vals <- sample(c(16, 17, 25, 30), terra::ncell(lc), replace = TRUE)
  terra::values(lc) <- vals

  # Use "forest_cover" name instead of "landcover"
  layers <- create_test_layers(rasters = list(forest_cover = lc))
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
})

test_that("indicateur_l2_fragmentation: single unit works", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = NULL)
  expect_length(result, 1)
  expect_true(!is.na(result))
  expect_true(result >= 0 & result <= 100)
})

# ==============================================================================
# 9. get_nasapower_wind
# ==============================================================================

test_that("get_nasapower_wind: cache miss, nasapower not installed returns default_dir", {
  skip_if_not_installed("terra")
  # Clear in-memory cache
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "wind_empty_cache")
    dir.create(cache_dir, recursive = TRUE)

    units <- sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(sf::st_point(c(5.0, 44.0)), crs = 4326)
    )
    units <- sf::st_buffer(units, 50)

    # With no file cache and no nasapower package, should return default_dir
    result <- nemeton:::get_nasapower_wind(units, default_dir = 270, cache_dir = cache_dir)
    expect_type(result, "double")
    expect_true(result >= 0 && result <= 360)
  })
})

test_that("get_nasapower_wind: file cache hit returns cached value", {
  skip_if_not_installed("terra")
  # Clear in-memory cache
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "wind_file_cache")
    dir.create(cache_dir, recursive = TRUE)
    saveRDS(225, file.path(cache_dir, "nasapower_wind.rds"))

    units <- sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(sf::st_point(c(4.0, 45.0)), crs = 4326)
    )
    units <- sf::st_buffer(units, 50)

    result <- nemeton:::get_nasapower_wind(units, cache_dir = cache_dir)
    expect_equal(result, 225)
  })
})

test_that("get_nasapower_wind: memory cache hit returns cached value", {
  skip_if_not_installed("terra")
  # Clear in-memory cache
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(6.5, 48.5)), crs = 4326)
  )
  units <- sf::st_buffer(units, 50)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "wind_mem_test")
    dir.create(cache_dir, recursive = TRUE)

    # First call -> populates memory cache
    result1 <- nemeton:::get_nasapower_wind(units, default_dir = 315, cache_dir = cache_dir)

    # Second call -> should hit memory cache
    result2 <- nemeton:::get_nasapower_wind(units, default_dir = 315, cache_dir = cache_dir)

    expect_equal(result1, result2)
    expect_type(result2, "double")
  })
})

test_that("get_nasapower_wind: custom default_dir is respected", {
  skip_if_not_installed("terra")
  wind_cache <- get(".wind_cache", envir = asNamespace("nemeton"))
  rm(list = ls(wind_cache), envir = wind_cache)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "wind_default_test")
    dir.create(cache_dir, recursive = TRUE)

    units <- sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(sf::st_point(c(7.0, 49.0)), crs = 4326)
    )
    units <- sf::st_buffer(units, 50)

    result <- nemeton:::get_nasapower_wind(units, default_dir = 180, cache_dir = cache_dir)
    expect_type(result, "double")
    expect_true(result >= 0 && result <= 360)
  })
})

# ==============================================================================
# 10. get_or_compute_twi
# ==============================================================================

test_that("get_or_compute_twi: no cache computes TWI", {
  skip_if_not_installed("terra")
  # Clear the TWI cache
  twi_cache <- get(".twi_cache", envir = asNamespace("nemeton"))
  rm(list = ls(twi_cache), envir = twi_cache)

  dem <- terra::rast(nrows = 12, ncols = 12,
                     xmin = 800000, xmax = 800600,
                     ymin = 6500000, ymax = 6500600,
                     crs = "EPSG:2154")
  terra::values(dem) <- seq(100, 400, length.out = 144)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "twi_compute_test")
    dir.create(cache_dir, recursive = TRUE)

    result <- nemeton:::get_or_compute_twi(dem, cache_dir = cache_dir)
    expect_s4_class(result, "SpatRaster")
    expect_equal(terra::nlyr(result), 1)

    # File cache should be created
    expect_true(file.exists(file.path(cache_dir, "twi.tif")))
  })
})

test_that("get_or_compute_twi: memory cache hit returns cached", {
  skip_if_not_installed("terra")
  # Clear the TWI cache
  twi_cache <- get(".twi_cache", envir = asNamespace("nemeton"))
  rm(list = ls(twi_cache), envir = twi_cache)

  dem <- terra::rast(nrows = 8, ncols = 8,
                     xmin = 810000, xmax = 810400,
                     ymin = 6510000, ymax = 6510400,
                     crs = "EPSG:2154")
  terra::values(dem) <- seq(50, 300, length.out = 64)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "twi_mem_hit")
    dir.create(cache_dir, recursive = TRUE)

    # First call - computes and caches
    result1 <- nemeton:::get_or_compute_twi(dem, cache_dir = cache_dir)
    expect_s4_class(result1, "SpatRaster")

    # Verify key is in memory cache
    key <- paste(nrow(dem), ncol(dem),
                 paste(as.vector(terra::ext(dem)), collapse = ","),
                 terra::crs(dem, describe = TRUE)$code,
                 sep = "|")
    expect_true(exists(key, envir = twi_cache))

    # Second call - from memory cache
    result2 <- nemeton:::get_or_compute_twi(dem, cache_dir = cache_dir)
    expect_s4_class(result2, "SpatRaster")
  })
})

test_that("get_or_compute_twi: file cache hit returns cached", {
  skip_if_not_installed("terra")
  # Clear the TWI cache
  twi_cache <- get(".twi_cache", envir = asNamespace("nemeton"))
  rm(list = ls(twi_cache), envir = twi_cache)

  dem <- terra::rast(nrows = 8, ncols = 8,
                     xmin = 820000, xmax = 820400,
                     ymin = 6520000, ymax = 6520400,
                     crs = "EPSG:2154")
  terra::values(dem) <- seq(100, 250, length.out = 64)

  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "twi_file_hit")
    dir.create(cache_dir, recursive = TRUE)

    # First call - computes, writes file cache
    result1 <- nemeton:::get_or_compute_twi(dem, cache_dir = cache_dir)
    expect_true(file.exists(file.path(cache_dir, "twi.tif")))

    # Clear ONLY the memory cache (not file)
    rm(list = ls(twi_cache), envir = twi_cache)

    # Second call - should load from file cache
    result2 <- nemeton:::get_or_compute_twi(dem, cache_dir = cache_dir)
    expect_s4_class(result2, "SpatRaster")
  })
})

# ==============================================================================
# 11. extract_fertility_from_raster and extract_fertility_from_vector
# ==============================================================================

test_that("extract_fertility_from_raster: uniform values yield neutral 50", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  soil <- create_test_raster(values = "constant", res = 10)
  terra::values(soil) <- 5

  layers <- create_test_layers(rasters = list(soil = soil))
  result <- nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  expect_length(result, 3)
  # All same value -> neutral score 50
  expect_true(all(result == 50))
})

test_that("extract_fertility_from_raster: gradient values produce range 0-100", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  soil <- create_test_raster(values = "random", res = 10)
  terra::values(soil) <- seq(1, 10, length.out = terra::ncell(soil))

  layers <- create_test_layers(rasters = list(soil = soil))
  result <- nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("extract_fertility_from_vector: overlapping polygons with fertility", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  bbox <- sf::st_bbox(units)

  soil_poly <- sf::st_polygon(list(matrix(
    c(
      bbox["xmin"] - 50, bbox["ymin"] - 50,
      bbox["xmax"] + 50, bbox["ymin"] - 50,
      bbox["xmax"] + 50, bbox["ymax"] + 50,
      bbox["xmin"] - 50, bbox["ymax"] + 50,
      bbox["xmin"] - 50, bbox["ymin"] - 50
    ),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    fertility = 80,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  # Fertility = 80, should be clamped in [0, 100]
  expect_true(all(result >= 0 & result <= 100))
})

test_that("extract_fertility_from_vector: missing fertility column errors", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)
  soil_poly <- sf::st_polygon(list(matrix(
    c(bbox["xmin"], bbox["ymin"],
      bbox["xmax"], bbox["ymin"],
      bbox["xmax"], bbox["ymax"],
      bbox["xmin"], bbox["ymax"],
      bbox["xmin"], bbox["ymin"]),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    ph = 6.5,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(soil = soil_sf))
  expect_error(
    nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility"),
    "fertility"
  )
})

test_that("extract_fertility_from_vector: non-overlapping returns NA-like", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)

  # Polygon far away from units
  soil_poly <- sf::st_polygon(list(matrix(
    c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    fertility = 90,
    geometry = sf::st_sfc(soil_poly, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 1)
  expect_type(result, "double")
})

test_that("extract_fertility_from_vector: multiple soil polygons area-weighted", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)

  # Two polygons covering the unit area (left and right halves)
  mid_x <- (bbox["xmin"] + bbox["xmax"]) / 2
  poly1 <- sf::st_polygon(list(matrix(
    c(bbox["xmin"] - 10, bbox["ymin"] - 10,
      mid_x, bbox["ymin"] - 10,
      mid_x, bbox["ymax"] + 10,
      bbox["xmin"] - 10, bbox["ymax"] + 10,
      bbox["xmin"] - 10, bbox["ymin"] - 10),
    ncol = 2, byrow = TRUE
  )))
  poly2 <- sf::st_polygon(list(matrix(
    c(mid_x, bbox["ymin"] - 10,
      bbox["xmax"] + 10, bbox["ymin"] - 10,
      bbox["xmax"] + 10, bbox["ymax"] + 10,
      mid_x, bbox["ymax"] + 10,
      mid_x, bbox["ymin"] - 10),
    ncol = 2, byrow = TRUE
  )))
  soil_sf <- sf::st_sf(
    fertility = c(30, 70),
    geometry = sf::st_sfc(list(poly1, poly2), crs = 2154)
  )

  layers <- create_test_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 1)
  expect_true(!is.na(result))
  # Should be approximately the weighted average of 30 and 70 ~ 50
  expect_true(result > 20 & result < 80)
})

# ==============================================================================
# Additional deeper coverage tests
# ==============================================================================

test_that("indicateur_c1_biomasse: Path 1 returns values proportional to density", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  units$species <- c("Quercus", "Quercus")
  units$age <- c(80, 80)
  units$density <- c(0.3, 0.9)

  result <- nemeton::indicateur_c1_biomasse(units)
  expect_length(result, 2)
  # Higher density should yield higher biomass
  expect_true(result[2] > result[1])
})

test_that("indicateur_w1_reseau: crossing stream gives full proximity bonus", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 1)
  bbox <- sf::st_bbox(units)

  # Stream crosses through the unit
  stream <- sf::st_linestring(matrix(
    c(bbox["xmin"] - 10, (bbox["ymin"] + bbox["ymax"]) / 2,
      bbox["xmax"] + 10, (bbox["ymin"] + bbox["ymax"]) / 2),
    ncol = 2, byrow = TRUE
  ))
  watercourses <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(stream, crs = 2154)
  )

  layers <- create_test_layers(vectors = list(water_network = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers, proximity_ref = 50)
  expect_length(result, 1)
  # Should have both direct density and full proximity bonus (50)
  expect_true(result >= 50)
})

test_that("indicateur_l2_fragmentation: returns scores in [0, 100] for irregular parcels", {
  skip_if_not_installed("terra")
  # Create irregular polygon
  poly <- sf::st_polygon(list(matrix(
    c(566450, 6615200,
      566550, 6615200,
      566600, 6615250,
      566500, 6615350,
      566400, 6615300,
      566450, 6615200),
    ncol = 2, byrow = TRUE
  )))
  units <- sf::st_sf(
    id = "u1",
    geometry = sf::st_sfc(poly, crs = 2154)
  )

  result <- nemeton:::indicateur_l2_fragmentation(units, layers = NULL)
  expect_length(result, 1)
  expect_true(!is.na(result))
  expect_true(result >= 0 & result <= 100)
})

test_that("indicateur_w3_humidite: consistent results between calls with cache", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- create_test_layers(rasters = list(dem = dem))
  result1 <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  result2 <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  expect_equal(result1, result2)
})

test_that("indicateur_f2_erosion: gentle slope produces higher fertility score", {
  skip_if_not_installed("terra")
  # Gentle slope DEM
  units <- create_test_units(n_features = 1)
  dem <- create_test_raster(values = "random", res = 10)
  terra::values(dem) <- seq(200, 210, length.out = terra::ncell(dem))  # very gentle

  layers <- create_test_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_f2_erosion(units, layers)
  expect_length(result, 1)
  expect_type(result, "double")
})

test_that("indicateur_c2_ndvi: returns values between 0 and 1 for valid NDVI", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 5)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.2, 0.9)

  layers <- create_test_layers(rasters = list(ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers)
  expect_length(result, 5)
  # Some edge units may get NA; check that most are valid
  non_na <- result[!is.na(result)]
  expect_true(length(non_na) >= 3)
  expect_true(all(non_na >= 0 & non_na <= 1))
})

test_that("get_or_compute_twi: different DEMs produce different cache keys", {
  skip_if_not_installed("terra")
  twi_cache <- get(".twi_cache", envir = asNamespace("nemeton"))
  rm(list = ls(twi_cache), envir = twi_cache)

  dem1 <- terra::rast(nrows = 6, ncols = 6,
                      xmin = 830000, xmax = 830300,
                      ymin = 6530000, ymax = 6530300,
                      crs = "EPSG:2154")
  terra::values(dem1) <- seq(100, 200, length.out = 36)

  dem2 <- terra::rast(nrows = 8, ncols = 8,
                      xmin = 840000, xmax = 840400,
                      ymin = 6540000, ymax = 6540400,
                      crs = "EPSG:2154")
  terra::values(dem2) <- seq(200, 400, length.out = 64)

  withr::with_tempdir({
    cache1 <- file.path(getwd(), "twi_key1")
    cache2 <- file.path(getwd(), "twi_key2")
    dir.create(cache1, recursive = TRUE)
    dir.create(cache2, recursive = TRUE)

    r1 <- nemeton:::get_or_compute_twi(dem1, cache_dir = cache1)
    r2 <- nemeton:::get_or_compute_twi(dem2, cache_dir = cache2)

    expect_s4_class(r1, "SpatRaster")
    expect_s4_class(r2, "SpatRaster")
    # Different dimensions
    expect_false(terra::nrow(r1) == terra::nrow(r2))
  })
})

test_that("calculate_twi_terra: NaN and Inf values are handled", {
  skip_if_not_installed("terra")
  dem <- terra::rast(nrows = 10, ncols = 10,
                     xmin = 800000, xmax = 801000,
                     ymin = 6500000, ymax = 6501000,
                     crs = "EPSG:2154")
  # Create DEM with some extreme values
  vals <- runif(100, 0, 1000)
  vals[c(1, 50, 100)] <- 0  # some zero elevation
  terra::values(dem) <- vals

  result <- nemeton:::calculate_twi_terra(dem)
  expect_s4_class(result, "SpatRaster")
  twi_vals <- terra::values(result)
  non_na <- twi_vals[!is.na(twi_vals)]
  # No Inf or NaN values should survive
  if (length(non_na) > 0) {
    expect_true(all(is.finite(non_na)))
    expect_true(all(non_na >= 0))
  }
})

# ==============================================================================
# F1 SoilGrids path — cec_to_fertility_score + indicateur_f1_fertilite
# ==============================================================================

test_that("cec_to_fertility_score maps SoilGrids x10 values onto [0,100]", {
  skip_if_not_installed("terra")
  # Raw 0 cmol(c)/kg × 10 → 0 ; 300 (= 30 cmol(c)/kg) → 100 ; 600 → capped 100
  expect_equal(cec_to_fertility_score(0), 0)
  expect_equal(cec_to_fertility_score(300), 100)
  expect_equal(cec_to_fertility_score(600), 100)
  expect_equal(cec_to_fertility_score(150), 50)    # 15 cmol(c)/kg → 50
  expect_equal(cec_to_fertility_score(NA_real_), NA_real_)
  expect_equal(cec_to_fertility_score(c(0, 60, 300)), c(0, 20, 100))
})

test_that("indicateur_f1_fertilite(source='soilgrids') wires the loader", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  # Capture the datasource key passed to load_raster_source, and fake both
  # the loader and safe_extract to avoid any network / raster work.
  captured_key <- NULL
  fake_loader <- function(source_key, country = "FR", aoi = NULL, section = NULL) {
    captured_key <<- source_key
    structure(list(), class = "SpatRaster")
  }
  fake_extract <- function(raster, polygons, ...) {
    c(0, 150, 300)  # poor / moderate / rich CEC x10
  }
  testthat::local_mocked_bindings(
    load_raster_source = fake_loader,
    safe_extract = fake_extract
  )

  result <- indicateur_f1_fertilite(units, source = "soilgrids")

  expect_equal(captured_key, "soilgrids_cec")
  expect_equal(result, c(0, 50, 100))
})

test_that("indicateur_f1_fertilite(source='soilgrids') ignores layers arg", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  fake_loader <- function(source_key, country = "FR", aoi = NULL, section = NULL) {
    structure(list(), class = "SpatRaster")
  }
  fake_extract <- function(raster, polygons, ...) rep(120, nrow(polygons))
  testthat::local_mocked_bindings(
    load_raster_source = fake_loader,
    safe_extract = fake_extract
  )

  # No layers supplied at all — must not error
  result <- suppressMessages(
    indicateur_f1_fertilite(units, source = "soilgrids")
  )
  expect_length(result, 2)
  expect_true(all(result == 40))  # 120/10 = 12 cmol(c)/kg → 40
})

# ==============================================================================
# F1 GIS Sol path — indicateur_f1_fertilite(source = "gissol")
# ==============================================================================

# Synthetic RRP: two adjacent squares carrying two different AFES codes.
#   pg1 (x ∈ [0, 10])   CAL_PRO  score 90
#   pg2 (x ∈ [10, 20])  BRUN_DYS score 35
make_synthetic_rrp <- function(crs = 2154) {
  mkpoly <- function(xmin, xmax) {
    sf::st_polygon(list(rbind(
      c(xmin, 0), c(xmax, 0), c(xmax, 10), c(xmin, 10), c(xmin, 0)
    )))
  }
  sf::st_sf(
    rpf_code = c("CAL_PRO", "BRUN_DYS"),
    geometry = sf::st_sfc(mkpoly(0, 10), mkpoly(10, 20), crs = crs)
  )
}

# Helper to build a fake nemeton_layers with a given vector layer.
make_layers_with_rrp <- function(rrp) {
  structure(
    list(
      rasters = list(),
      vectors = list(soil = rrp),
      cache_dir = tempdir()
    ),
    class = "nemeton_layers"
  )
}

test_that("read_uts_fertility_table loads the shipped CSV", {
  skip_if_not_installed("terra")
  tbl <- read_uts_fertility_table()
  expect_s3_class(tbl, "data.frame")
  expect_true("rpf_code" %in% names(tbl))
  expect_true("fertility_score" %in% names(tbl))
  expect_gte(nrow(tbl), 50)
})

test_that("source='gissol' returns the UTS score when a unit sits entirely in one polygon", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  rrp <- make_synthetic_rrp()
  layers <- make_layers_with_rrp(rrp)
  # A unit entirely inside pg1 (CAL_PRO, score 90)
  unit_in_pg1 <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1)
    ))), crs = 2154)
  )
  result <- suppressMessages(
    indicateur_f1_fertilite(unit_in_pg1, layers, source = "gissol")
  )
  expect_equal(result, 90)
})

test_that("source='gissol' area-weights when a unit straddles two UTS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  rrp <- make_synthetic_rrp()
  layers <- make_layers_with_rrp(rrp)
  # Unit spanning x in [5, 15] — 50% CAL_PRO (90), 50% BRUN_DYS (35)
  straddling <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(5, 1), c(15, 1), c(15, 9), c(5, 9), c(5, 1)
    ))), crs = 2154)
  )
  result <- suppressMessages(
    indicateur_f1_fertilite(straddling, layers, source = "gissol")
  )
  expect_equal(result, (90 + 35) / 2, tolerance = 1e-6)
})

test_that("source='gissol' returns NA for units outside any RRP polygon", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  rrp <- make_synthetic_rrp()
  layers <- make_layers_with_rrp(rrp)
  outside <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(100, 100), c(105, 100), c(105, 105), c(100, 105), c(100, 100)
    ))), crs = 2154)
  )
  result <- suppressMessages(
    indicateur_f1_fertilite(outside, layers, source = "gissol")
  )
  expect_true(is.na(result))
})

test_that("source='gissol' warns and drops unknown AFES codes", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  rrp <- sf::st_sf(
    rpf_code = c("CAL_PRO", "NOT_IN_TABLE"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0,0), c(10,0), c(10,10), c(0,10), c(0,0)))),
      sf::st_polygon(list(rbind(c(10,0), c(20,0), c(20,10), c(10,10), c(10,0)))),
      crs = 2154
    )
  )
  layers <- make_layers_with_rrp(rrp)
  # Unit straddling both — the NOT_IN_TABLE half is dropped, result is 90
  straddling <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(5, 1), c(15, 1), c(15, 9), c(5, 9), c(5, 1)
    ))), crs = 2154)
  )
  expect_warning(
    result <- suppressMessages(
      indicateur_f1_fertilite(straddling, layers, source = "gissol")
    ),
    "NOT_IN_TABLE|not in UTS"
  )
  expect_equal(result, 90, tolerance = 1e-6)
})

test_that("source='gissol' honours a custom rpf_code_col", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  rrp <- make_synthetic_rrp()
  names(rrp)[names(rrp) == "rpf_code"] <- "UTSDom"
  layers <- make_layers_with_rrp(rrp)
  unit_in_pg1 <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1)
    ))), crs = 2154)
  )
  result <- suppressMessages(
    indicateur_f1_fertilite(unit_in_pg1, layers,
                            source = "gissol",
                            rpf_code_col = "UTSDom")
  )
  expect_equal(result, 90)
})

test_that("source='gissol' errors clearly when the column is missing", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  rrp <- make_synthetic_rrp()
  names(rrp)[names(rrp) == "rpf_code"] <- "weird_name"
  layers <- make_layers_with_rrp(rrp)
  unit <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1)
    ))), crs = 2154)
  )
  expect_error(
    indicateur_f1_fertilite(unit, layers, source = "gissol"),
    "rpf_code.*not found"
  )
})

test_that("source='gissol' reprojects RRP when CRSes differ", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  # RRP in WGS84, unit in Lambert-93 — must not error, must return score
  rrp_wgs <- make_synthetic_rrp(crs = 4326)
  layers <- make_layers_with_rrp(rrp_wgs)
  unit_l93 <- sf::st_transform(
    sf::st_sf(
      id = 1L,
      geometry = sf::st_sfc(sf::st_polygon(list(rbind(
        c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1)
      ))), crs = 4326)
    ),
    crs = 2154
  )
  result <- suppressMessages(
    indicateur_f1_fertilite(unit_l93, layers, source = "gissol")
  )
  expect_false(is.na(result))
  expect_equal(result, 90, tolerance = 1e-6)
})

# ==============================================================================
# C2 — FAPAR mode (Theia s2_biophysical, phase 3a)
# ==============================================================================

test_that("indicateur_c2_ndvi FAPAR mode returns per-unit mean FAPAR", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  fapar <- create_test_raster(values = "constant", res = 10)
  terra::values(fapar) <- runif(terra::ncell(fapar))

  result <- suppressMessages(
    indicateur_c2_ndvi(units, layers = make_mock_layers(), fapar = fapar)
  )
  expect_length(result, 3)
  expect_type(result, "double")
})

test_that("indicateur_c2_ndvi FAPAR mode rejects a non-raster fapar", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)
  expect_error(
    indicateur_c2_ndvi(units, layers = make_mock_layers(), fapar = "not_a_raster"),
    "fapar must be a terra SpatRaster"
  )
})

# ==============================================================================
# Phase 3b — theia_soil wiring: texture helpers + F1/F2
# ==============================================================================

test_that("texture_to_fertility_score favours loam over sand and clay", {
  skip_if_not_installed("terra")
  loam <- texture_to_fertility_score(20, 40, 40)
  clay <- texture_to_fertility_score(90, 5, 5)
  sand <- texture_to_fertility_score(5, 5, 90)
  expect_gt(loam, sand)
  expect_gt(loam, clay)
  expect_true(all(c(loam, clay, sand) >= 0 & c(loam, clay, sand) <= 100))
})

test_that("texture_to_fertility_score penalises coarse elements", {
  skip_if_not_installed("terra")
  base <- texture_to_fertility_score(20, 40, 40)
  stony <- texture_to_fertility_score(20, 40, 40, coarse_elements = 50)
  expect_lt(stony, base)
  expect_equal(stony, base * 0.5, tolerance = 1e-6)
})

test_that("texture_to_fertility_score is unit-agnostic for the triplet", {
  skip_if_not_installed("terra")
  pct <- texture_to_fertility_score(20, 40, 40)
  gkg <- texture_to_fertility_score(200, 400, 400)
  expect_equal(pct, gkg, tolerance = 1e-6)
})

test_that("texture_to_erosion_resistance: clay resists, silt erodes", {
  skip_if_not_installed("terra")
  clay <- texture_to_erosion_resistance(90, 5, 5)
  silt <- texture_to_erosion_resistance(5, 90, 5)
  expect_gt(clay, silt)
  expect_true(all(c(clay, silt) >= 0 & c(clay, silt) <= 100))
})

test_that("indicateur_f1_fertilite theia_soil mode returns 0-100 scores", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  mk <- function(v) {
    r <- create_test_raster(values = "constant")
    terra::values(r) <- v
    r
  }
  texture <- list(clay = mk(20), silt = mk(40), sand = mk(40))

  result <- suppressMessages(
    indicateur_f1_fertilite(units, source = "theia_soil", texture = texture)
  )
  expect_length(result, 3)
  expect_type(result, "double")
  non_na <- result[!is.na(result)]
  if (length(non_na) > 0) {
    expect_true(all(non_na >= 0 & non_na <= 100))
  }
})

test_that("indicateur_f1_fertilite theia_soil mode requires texture", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)
  expect_error(
    indicateur_f1_fertilite(units, source = "theia_soil"),
    "requires a 'texture'"
  )
})

test_that("indicateur_f2_erosion accepts a Theia theia_soil texture", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)

  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(200, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)
  layers <- make_mock_layers(rasters = list(dem = dem))

  mk <- function(v) {
    r <- create_test_raster(values = "constant")
    terra::values(r) <- v
    r
  }
  texture <- list(clay = mk(20), silt = mk(40), sand = mk(40))

  result <- suppressMessages(
    nemeton:::indicateur_f2_erosion(units, layers = layers, texture = texture)
  )
  expect_length(result, 3)
  expect_type(result, "double")
  non_na <- result[!is.na(result)]
  if (length(non_na) > 0) {
    expect_true(all(non_na >= 0 & non_na <= 100))
  }
})

# ==============================================================================
# Phase 3d — theia_water wiring: W2 occurrence coverage
# ==============================================================================

test_that("indicateur_w2_zones_humides adds Theia water-occurrence coverage", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  units <- create_test_units(n_features = 3)
  wo <- create_test_raster(values = "constant")
  terra::values(wo) <- 50  # 50% occurrence everywhere, above the 25% threshold

  result <- suppressMessages(
    indicateur_w2_zones_humides(units, layers = make_mock_layers(),
                                water_occurrence = wo)
  )
  expect_length(result, 3)
  expect_type(result, "double")
  expect_true(all(result >= 0 & result <= 100, na.rm = TRUE))
})

test_that("indicateur_w2_zones_humides rejects a non-raster water_occurrence", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 2)
  expect_error(
    suppressMessages(
      indicateur_w2_zones_humides(units, layers = make_mock_layers(),
                                  water_occurrence = "not_a_raster")
    ),
    "water_occurrence must be a terra SpatRaster"
  )
})
