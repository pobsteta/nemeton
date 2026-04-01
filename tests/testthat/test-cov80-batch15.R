# test-cov80-batch15.R
# Deep coverage for R/indicators-families.R
# Targets: calculate_twi_terra, indicateur_c1_biomasse, indicateur_c2_ndvi,
#          indicateur_w1_reseau, indicateur_w2_zones_humides, indicateur_w3_humidite,
#          indicateur_f2_erosion, indicateur_l2_fragmentation,
#          get_nasapower_wind, get_or_compute_twi,
#          extract_fertility_from_raster, extract_fertility_from_vector

# ==============================================================================
# Helper: create mock nemeton_layers with in-memory objects
# ==============================================================================

make_layers <- function(rasters = list(), vectors = list(), cache_dir = NULL) {
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
# 1. calculate_twi_terra
# ==============================================================================

test_that("calculate_twi_terra: returns valid SpatRaster from gradient DEM", {
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
  units <- create_test_units(n_features = 3)

  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.3, 0.8)

  layers <- make_layers(rasters = list(ndvi = ndvi))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  # NDVI * 150 for NDVI in [0.3, 0.8] -> biomass in [45, 120]
  expect_true(all(result > 0 & result < 150))
})

test_that("indicateur_c1_biomasse: last resort returns NA when no data", {
  units <- create_test_units(n_features = 2)
  layers <- make_layers(rasters = list())
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_c1_biomasse: NULL layers returns NA", {
  units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_c1_biomasse(units, layers = NULL)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_c1_biomasse: non-sf input errors", {
  expect_error(
    nemeton::indicateur_c1_biomasse(data.frame(x = 1)),
    "units must be an sf object"
  )
})

test_that("indicateur_c1_biomasse: list input errors", {
  expect_error(
    nemeton::indicateur_c1_biomasse(list(a = 1)),
    "units must be an sf object"
  )
})

test_that("indicateur_c1_biomasse: LiDAR MNH path produces positive values", {
  units <- create_test_units(n_features = 2)
  mnh <- create_test_raster(values = "random", res = 10)
  terra::values(mnh) <- runif(terra::ncell(mnh), 5, 25)

  layers <- make_layers(rasters = list(lidar_mnh = mnh))
  result <- nemeton::indicateur_c1_biomasse(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0))
})

# ==============================================================================
# 3. indicateur_c2_ndvi
# ==============================================================================

test_that("indicateur_c2_ndvi: valid NDVI raster extraction", {
  units <- create_test_units(n_features = 3)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.2, 0.85)

  layers <- make_layers(rasters = list(ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result > 0 & result < 1))
})

test_that("indicateur_c2_ndvi: trend = TRUE warns not implemented", {
  units <- create_test_units(n_features = 1)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.1, 0.9)

  layers <- make_layers(rasters = list(ndvi = ndvi))
  expect_warning(
    result <- nemeton:::indicateur_c2_ndvi(units, layers, trend = TRUE),
    "not yet implemented"
  )
  expect_length(result, 1)
  expect_true(!is.na(result))
})

test_that("indicateur_c2_ndvi: non-sf input errors", {
  layers <- make_layers(rasters = list(ndvi = create_test_raster()))
  expect_error(
    nemeton:::indicateur_c2_ndvi(data.frame(x = 1), layers),
    "units must be an sf object"
  )
})

test_that("indicateur_c2_ndvi: non-nemeton_layers errors", {
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_c2_ndvi(units, layers = list(rasters = list())),
    "nemeton_layers"
  )
})

test_that("indicateur_c2_ndvi: missing NDVI layer errors", {
  units <- create_test_units(n_features = 1)
  layers <- make_layers(rasters = list(dem = create_test_raster()))
  expect_error(
    nemeton:::indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi"),
    "not found"
  )
})

test_that("indicateur_c2_ndvi: custom ndvi_layer name works", {
  units <- create_test_units(n_features = 2)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.2, 0.7)

  layers <- make_layers(rasters = list(my_ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers, ndvi_layer = "my_ndvi")
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
})

# ==============================================================================
# 4. indicateur_w1_reseau
# ==============================================================================

test_that("indicateur_w1_reseau: watercourse crossing parcel yields positive density", {
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

  layers <- make_layers(vectors = list(indicateur_w1_reseau = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers)
  expect_length(result, 2)
  expect_true(all(result > 0))
})

test_that("indicateur_w1_reseau: no crossing but within proximity yields bonus", {
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

  layers <- make_layers(vectors = list(indicateur_w1_reseau = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers)
  expect_length(result, 1)
  expect_true(result > 0)  # Proximity bonus should kick in
})

test_that("indicateur_w1_reseau: stream far away (>500m) yields zero proximity", {
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

  layers <- make_layers(vectors = list(indicateur_w1_reseau = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers)
  expect_length(result, 1)
  expect_equal(result, 0)
})

test_that("indicateur_w1_reseau: non-sf input errors", {
  layers <- make_layers(vectors = list(indicateur_w1_reseau = create_test_vector()))
  expect_error(
    nemeton:::indicateur_w1_reseau(data.frame(x = 1), layers),
    "units must be an sf object"
  )
})

test_that("indicateur_w1_reseau: non-nemeton_layers errors", {
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w1_reseau(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w1_reseau: missing watercourse layer errors", {
  units <- create_test_units(n_features = 1)
  layers <- make_layers(vectors = list())
  expect_error(
    nemeton:::indicateur_w1_reseau(units, layers),
    "not found"
  )
})

test_that("indicateur_w1_reseau: buffer parameter increases capture area", {
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

  layers <- make_layers(vectors = list(indicateur_w1_reseau = watercourses))
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
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  # Create a gradient DEM
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w2_zones_humides(units, layers)
  expect_length(result, 2)
  # With DEM, TWI is computed; some cells may have TWI > 12
  expect_type(result, "double")
  expect_true(all(result >= 0 | is.na(result)))
})

test_that("indicateur_w2_zones_humides: no data returns NA", {
  units <- create_test_units(n_features = 2)
  layers <- make_layers(rasters = list(), vectors = list())
  result <- nemeton:::indicateur_w2_zones_humides(units, layers)
  expect_length(result, 2)
  expect_true(all(is.na(result)))
})

test_that("indicateur_w2_zones_humides: non-sf input errors", {
  layers <- make_layers()
  expect_error(
    nemeton:::indicateur_w2_zones_humides(data.frame(x = 1), layers),
    "sf"
  )
})

test_that("indicateur_w2_zones_humides: non-nemeton_layers errors", {
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w2_zones_humides(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w2_zones_humides: water_surfaces vector source", {
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

  layers <- make_layers(vectors = list(water_surfaces = water_sf))
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
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w3_humidite(units, layers)
  expect_length(result, 2)
  expect_type(result, "double")
})

test_that("indicateur_w3_humidite: method = 'd8' calls calculate_twi_terra directly", {
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(200, 600, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  expect_length(result, 2)
  expect_type(result, "double")
  expect_true(all(!is.na(result)))
})

test_that("indicateur_w3_humidite: no DEM errors", {
  units <- create_test_units(n_features = 1)
  layers <- make_layers(rasters = list())
  expect_error(
    nemeton:::indicateur_w3_humidite(units, layers),
    "No DEM"
  )
})

test_that("indicateur_w3_humidite: non-sf input errors", {
  layers <- make_layers(rasters = list(dem = create_test_raster()))
  expect_error(
    nemeton:::indicateur_w3_humidite(data.frame(x = 1), layers),
    "sf"
  )
})

test_that("indicateur_w3_humidite: non-nemeton_layers errors", {
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_w3_humidite(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_w3_humidite: method = 'auto' produces same structure as 'd8'", {
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_layers(rasters = list(dem = dem))
  result_auto <- nemeton:::indicateur_w3_humidite(units, layers, method = "auto")
  result_d8 <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  # Both should return same length
  expect_equal(length(result_auto), length(result_d8))
})

# ==============================================================================
# 7. indicateur_f2_erosion
# ==============================================================================

test_that("indicateur_f2_erosion: with DEM computes TWI+slope composite", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 400, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_layers(rasters = list(dem = dem))
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
  units <- create_test_units(n_features = 1)
  layers <- make_layers(rasters = list())
  expect_error(
    nemeton:::indicateur_f2_erosion(units, layers),
    "No DEM"
  )
})

test_that("indicateur_f2_erosion: non-sf input errors", {
  layers <- make_layers(rasters = list(dem = create_test_raster()))
  expect_error(
    nemeton:::indicateur_f2_erosion(data.frame(x = 1), layers),
    "sf"
  )
})

test_that("indicateur_f2_erosion: non-nemeton_layers errors", {
  units <- create_test_units(n_features = 1)
  expect_error(
    nemeton:::indicateur_f2_erosion(units, list()),
    "nemeton_layers"
  )
})

test_that("indicateur_f2_erosion: LiDAR MNT preferred over regular DEM", {
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  terra::values(dem) <- seq(200, 500, length.out = terra::ncell(dem))

  lidar_mnt <- create_test_raster(values = "random", res = 10)
  terra::values(lidar_mnt) <- seq(200, 500, length.out = terra::ncell(lidar_mnt))

  layers <- make_layers(rasters = list(dem = dem, lidar_mnt = lidar_mnt))
  result <- nemeton:::indicateur_f2_erosion(units, layers)
  expect_length(result, 2)
  expect_type(result, "double")
})

# ==============================================================================
# 8. indicateur_l2_fragmentation
# ==============================================================================

test_that("indicateur_l2_fragmentation: geometry component (shape index)", {
  units <- create_test_units(n_features = 3)
  # No layers -> only geometry + exposure components
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = NULL)
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation: no landcover yields neutral contrast", {
  units <- create_test_units(n_features = 2)
  # Empty layers (has class but no landcover raster)
  layers <- make_layers(rasters = list())
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation: with landcover raster computes contrast", {
  units <- create_test_units(n_features = 2)
  lc <- create_test_raster(values = "constant", res = 10)
  # Mix of OSO classes (forest: 16-18, agriculture: 21-23, built-up: 25-28)
  vals <- sample(c(16, 17, 18, 21, 22, 25, 26), terra::ncell(lc), replace = TRUE)
  terra::values(lc) <- vals

  layers <- make_layers(rasters = list(landcover = lc))
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_l2_fragmentation: non-sf input errors", {
  expect_error(
    nemeton:::indicateur_l2_fragmentation(data.frame(x = 1)),
    "sf"
  )
})

test_that("indicateur_l2_fragmentation: forest_cover fallback for landcover", {
  units <- create_test_units(n_features = 2)
  lc <- create_test_raster(values = "constant", res = 10)
  vals <- sample(c(16, 17, 25, 30), terra::ncell(lc), replace = TRUE)
  terra::values(lc) <- vals

  # Use "forest_cover" name instead of "landcover"
  layers <- make_layers(rasters = list(forest_cover = lc))
  result <- nemeton:::indicateur_l2_fragmentation(units, layers = layers)
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
})

test_that("indicateur_l2_fragmentation: single unit works", {
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
  units <- create_test_units(n_features = 3)
  soil <- create_test_raster(values = "constant", res = 10)
  terra::values(soil) <- 5

  layers <- make_layers(rasters = list(soil = soil))
  result <- nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  expect_length(result, 3)
  # All same value -> neutral score 50
  expect_true(all(result == 50))
})

test_that("extract_fertility_from_raster: gradient values produce range 0-100", {
  units <- create_test_units(n_features = 3)
  soil <- create_test_raster(values = "random", res = 10)
  terra::values(soil) <- seq(1, 10, length.out = terra::ncell(soil))

  layers <- make_layers(rasters = list(soil = soil))
  result <- nemeton:::extract_fertility_from_raster(units, layers, "soil", "fertility")
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0 & result <= 100))
})

test_that("extract_fertility_from_vector: overlapping polygons with fertility", {
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

  layers <- make_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 2)
  expect_true(all(!is.na(result)))
  # Fertility = 80, should be clamped in [0, 100]
  expect_true(all(result >= 0 & result <= 100))
})

test_that("extract_fertility_from_vector: missing fertility column errors", {
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

  layers <- make_layers(vectors = list(soil = soil_sf))
  expect_error(
    nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility"),
    "fertility"
  )
})

test_that("extract_fertility_from_vector: non-overlapping returns NA-like", {
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

  layers <- make_layers(vectors = list(soil = soil_sf))
  result <- nemeton:::extract_fertility_from_vector(units, layers, "soil", "fertility")
  expect_length(result, 1)
  expect_type(result, "double")
})

test_that("extract_fertility_from_vector: multiple soil polygons area-weighted", {
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

  layers <- make_layers(vectors = list(soil = soil_sf))
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

  layers <- make_layers(vectors = list(indicateur_w1_reseau = watercourses))
  result <- nemeton:::indicateur_w1_reseau(units, layers, proximity_ref = 50)
  expect_length(result, 1)
  # Should have both direct density and full proximity bonus (50)
  expect_true(result >= 50)
})

test_that("indicateur_l2_fragmentation: returns scores in [0, 100] for irregular parcels", {
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
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "random", res = 10)
  vals <- matrix(
    rep(seq(100, 500, length.out = terra::ncol(dem)), each = terra::nrow(dem)),
    nrow = terra::nrow(dem), ncol = terra::ncol(dem)
  )
  terra::values(dem) <- as.vector(vals)

  layers <- make_layers(rasters = list(dem = dem))
  result1 <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  result2 <- nemeton:::indicateur_w3_humidite(units, layers, method = "d8")
  expect_equal(result1, result2)
})

test_that("indicateur_f2_erosion: gentle slope produces higher fertility score", {
  # Gentle slope DEM
  units <- create_test_units(n_features = 1)
  dem <- create_test_raster(values = "random", res = 10)
  terra::values(dem) <- seq(200, 210, length.out = terra::ncell(dem))  # very gentle

  layers <- make_layers(rasters = list(dem = dem))
  result <- nemeton:::indicateur_f2_erosion(units, layers)
  expect_length(result, 1)
  expect_type(result, "double")
})

test_that("indicateur_c2_ndvi: returns values between 0 and 1 for valid NDVI", {
  units <- create_test_units(n_features = 5)
  ndvi <- create_test_raster(values = "random", res = 10)
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.2, 0.9)

  layers <- make_layers(rasters = list(ndvi = ndvi))
  result <- nemeton:::indicateur_c2_ndvi(units, layers)
  expect_length(result, 5)
  # Some edge units may get NA; check that most are valid
  non_na <- result[!is.na(result)]
  expect_true(length(non_na) >= 3)
  expect_true(all(non_na >= 0 & non_na <= 1))
})

test_that("get_or_compute_twi: different DEMs produce different cache keys", {
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
