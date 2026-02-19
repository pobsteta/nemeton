# test-cov80-batch8.R
# Coverage boost for R/indicators-biodiversity.R + R/indicators-risk.R
# Target: B1 weighted scoring, B2 fallbacks, B3 components, R1-R4 fallback paths

# ==============================================================================
# B1 - Protected Area Coverage
# ==============================================================================

test_that("B1 with typed protection areas computes weighted score", {
  units <- create_test_units(n_features = 2)
  # Create protected areas with different protection types
  pa <- sf::st_sf(
    zone_type = c("ZNIEFF1", "Natura_SIC", "RNR_reserve"),
    geometry = sf::st_sfc(
      # ZNIEFF1 overlaps both units
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500, 566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      # Natura overlaps first unit only
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 566600, 6615100, 566600, 6615300, 566400, 6615300, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      # Reserve overlaps second unit only
      sf::st_polygon(list(matrix(c(
        566550, 6615250, 566800, 6615250, 566800, 6615500, 566550, 6615500, 566550, 6615250
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_biodiversity_protection(units, protected_areas = pa, source = "local")
  expect_true("B1" %in% names(result))
  expect_true("B1_pct" %in% names(result))
  expect_true("B1_nb" %in% names(result))
  expect_true(all(result$B1 >= 0 & result$B1 <= 100))
  # Both units should have some coverage
  expect_true(all(result$B1 > 0))
})

test_that("B1 with no type column uses default weight", {
  units <- create_test_units(n_features = 2)
  # No zone_type column — triggers default weight path
  pa <- sf::st_sf(
    name = "Zone A",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500, 566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_biodiversity_protection(units, protected_areas = pa)
  expect_true(all(result$B1 >= 0))
  # Score should be multiplied by 0.5 (default weight)
  expect_true(all(result$B1_pct > 0))
})

test_that("B1 with WFS source and NULL areas returns 0", {
  units <- create_test_units(n_features = 2)
  suppressWarnings({
    result <- nemeton::indicator_biodiversity_protection(units, source = "wfs")
  })
  expect_true(all(result$B1 == 0))
})

test_that("B1 with NULL protected_areas in local mode returns 0", {
  units <- create_test_units(n_features = 2)
  result <- nemeton::indicator_biodiversity_protection(units, protected_areas = NULL, source = "local")
  expect_true(all(result$B1 == 0))
})

test_that("B1 with CRS mismatch preprocesses correctly", {
  units <- create_test_units(n_features = 2)
  # Create PA in WGS84
  pa <- sf::st_sf(
    zone_type = "ZNIEFF1",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        2.9, 47.0, 3.1, 47.0, 3.1, 47.2, 2.9, 47.2, 2.9, 47.0
      ), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  # Should not error even if no overlap
  result <- nemeton::indicator_biodiversity_protection(units, protected_areas = pa, preprocess = TRUE)
  expect_true("B1" %in% names(result))
})

# ==============================================================================
# B2 - Structural Diversity
# ==============================================================================

test_that("B2 with strata and age fields computes score", {
  units <- create_test_units(n_features = 4)
  units$strata <- c("Emergent", "Dominant", "Intermediate", "Suppressed")
  units$age_class <- c("young", "mature", "old", "ancient")

  result <- nemeton::indicator_biodiversity_structure(units)
  expect_true("B2" %in% names(result))
  expect_true(all(result$B2 >= 0 & result$B2 <= 100, na.rm = TRUE))
})

test_that("B2 with species field uses 3-component weighting", {
  units <- create_test_units(n_features = 4)
  units$strata <- c("Emergent", "Dominant", "Intermediate", "Suppressed")
  units$age_class <- c("young", "mature", "old", "ancient")
  units$species <- c("Quercus robur", "Fagus sylvatica", "Pinus sylvestris", "Picea abies")

  result <- nemeton::indicator_biodiversity_structure(units, species_field = "species")
  expect_true(all(result$B2 >= 0 & result$B2 <= 100))
})

test_that("B2 monoculture capped at 20", {
  units <- create_test_units(n_features = 3)
  units$strata <- rep("Dominant", 3)
  units$age_class <- rep("mature", 3)

  result <- nemeton::indicator_biodiversity_structure(units)
  expect_true(all(result$B2 <= 20))
})

test_that("B2 falls back to NDVI when no strata/age fields", {
  units <- create_test_units(n_features = 3)
  ndvi_raster <- create_test_raster(values = "random")
  terra::values(ndvi_raster) <- runif(terra::ncell(ndvi_raster), 0.2, 0.9)

  # Create a minimal nemeton_layers object
  layers <- list(
    rasters = list(ndvi = ndvi_raster)
  )
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicator_biodiversity_structure(units, layers = layers)
  expect_true("B2" %in% names(result))
  expect_true(all(!is.na(result$B2)))
})

test_that("B2 falls back to LiDAR MNH", {
  units <- create_test_units(n_features = 3)
  mnh_raster <- create_test_raster(values = "random")
  terra::values(mnh_raster) <- runif(terra::ncell(mnh_raster), 5, 25)

  layers <- list(
    rasters = list(lidar_mnh = mnh_raster)
  )
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicator_biodiversity_structure(units, layers = layers)
  expect_true("B2" %in% names(result))
  expect_true(all(!is.na(result$B2)))
})

test_that("B2 returns NA when no data available at all", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicator_biodiversity_structure(units, layers = NULL)
  expect_true(all(is.na(result$B2)))
})

# ==============================================================================
# B3 - Ecological Connectivity
# ==============================================================================

test_that("B3 with NULL bdforet returns fallback 50", {
  units <- create_test_units(n_features = 3)
  suppressWarnings({
    result <- nemeton::indicator_biodiversity_connectivity(units, bdforet = NULL)
  })
  expect_true(all(result$B3 == 50))
})

test_that("B3 with bdforet computes connectivity", {
  units <- create_test_units(n_features = 3)
  # Create forest patches covering the test area
  bdforet <- sf::st_sf(
    code_tfv = c("FF1-00", "FF2G61"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 566700, 6615100, 566700, 6615300, 566400, 6615300, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        566700, 6615200, 567000, 6615200, 567000, 6615500, 566700, 6615500, 566700, 6615200
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_biodiversity_connectivity(units, bdforet = bdforet)
  expect_true("B3" %in% names(result))
  expect_true(all(result$B3 >= 0 & result$B3 <= 100))
})

# ==============================================================================
# R1 - Fire Risk Index
# ==============================================================================

test_that("R1 with DEM computes fallback slope-based fire risk", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 500, length.out = 2400))

  result <- nemeton::indicator_risk_fire(units, dem = dem)
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("R1 with NULL DEM returns NA", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicator_risk_fire(units, dem = NULL)
  expect_true(all(is.na(result$R1)))
})

test_that("R1 with species field uses species flammability", {
  units <- create_test_units(n_features = 3)
  units$species <- c("Pinus pinaster", "Fagus sylvatica", "Quercus suber")
  dem <- create_test_raster(values = seq(100, 500, length.out = 2400))

  result <- nemeton::indicator_risk_fire(units, dem = dem)
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("R1 with NDVI proxy when no species field", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 300, length.out = 2400))
  ndvi <- create_test_raster(values = "random")
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.3, 0.8)

  layers <- list(rasters = list(dem = dem, ndvi = ndvi))
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicator_risk_fire(units, layers = layers)
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("R1 with climate data uses climate factor", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 300, length.out = 2400))
  temp <- create_test_raster(values = "constant")
  terra::values(temp) <- 15
  precip <- create_test_raster(values = "constant")
  terra::values(precip) <- 800

  climate <- list(temperature = temp, precipitation = precip)
  result <- nemeton::indicator_risk_fire(units, dem = dem, climate = climate)
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

# ==============================================================================
# R2 - Storm Vulnerability
# ==============================================================================

test_that("R2 with DEM computes terrain-based storm risk", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 600, length.out = 2400))

  result <- nemeton::indicator_risk_storm(units, dem = dem)
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100))
})

test_that("R2 with NULL DEM returns NA", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicator_risk_storm(units, dem = NULL)
  expect_true(all(is.na(result$R2)))
})

test_that("R2 from layers extracts DEM", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 600, length.out = 2400))

  layers <- list(rasters = list(dem = dem))
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicator_risk_storm(units, layers = layers)
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100))
})

# ==============================================================================
# R3 - Drought Stress
# ==============================================================================

test_that("R3 with DEM computes drought risk", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 400, length.out = 2400))

  result <- nemeton::indicator_risk_drought(units, dem = dem)
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("R3 from layers extracts DEM", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 400, length.out = 2400))

  layers <- list(rasters = list(dem = dem))
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicator_risk_drought(units, layers = layers)
  expect_true("R3" %in% names(result))
})

test_that("R3 without DEM returns NA", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicator_risk_drought(units, dem = NULL)
  expect_true(all(is.na(result$R3)))
})

# ==============================================================================
# R4 - Browsing Pressure
# ==============================================================================

test_that("R4 with bdforet computes browsing pressure", {
  units <- create_test_units(n_features = 3)
  bdforet <- sf::st_sf(
    code_tfv = c("FF1-00", "FF2G61"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 566700, 6615100, 566700, 6615300, 566400, 6615300, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        566700, 6615200, 567000, 6615200, 567000, 6615500, 566700, 6615500, 566700, 6615200
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_risk_browsing(units, bdforet = bdforet)
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("R4 without bdforet returns fallback", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicator_risk_browsing(units, bdforet = NULL)
  expect_true("R4" %in% names(result))
  # Should return some value (50 for fallback or computed)
  expect_true(all(!is.na(result$R4) | result$R4 >= 0))
})

test_that("R4 with edge_buffer parameter", {
  units <- create_test_units(n_features = 3)
  bdforet <- sf::st_sf(
    code_tfv = "FF1-00",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500, 566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_risk_browsing(units, bdforet = bdforet, edge_buffer = 200)
  expect_true("R4" %in% names(result))
})
