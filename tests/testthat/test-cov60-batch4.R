# test-cov60-batch4.R
# Coverage boost for spatial indicator files
# Target: bring each file from <60% to >60%

# ==============================================================================
# indicators-biodiversity.R
# ==============================================================================

test_that("indicator_biodiversity_protection with mock protected areas", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  # Create protected areas overlapping some units
  pa <- sf::st_sf(
    STATUT = c("RN", "PNR"),
    geometry = sf::st_geometry(sf::st_buffer(units[1:2, ], 50))
  )
  sf::st_crs(pa) <- sf::st_crs(units)
  
  result <- indicator_biodiversity_protection(units, protected_areas = pa)
  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
  expect_true(all(result$B1 >= 0, na.rm = TRUE))
})

test_that("indicator_biodiversity_protection without protected areas returns NA", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  result <- indicator_biodiversity_protection(units, protected_areas = NULL)
  expect_s3_class(result, "sf")
  expect_true("B1" %in% names(result))
})

test_that("indicator_biodiversity_protection with protection_types filter", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  pa <- sf::st_sf(
    STATUT = c("RN", "APPB", "PNR"),
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_centroid(sf::st_geometry(units[1, ]))[[1]], 200),
      sf::st_buffer(sf::st_centroid(sf::st_geometry(units[1, ]))[[1]], 150),
      sf::st_buffer(sf::st_centroid(sf::st_geometry(units[2, ]))[[1]], 100),
      crs = sf::st_crs(units)
    )
  )
  
  result <- indicator_biodiversity_protection(
    units, protected_areas = pa, protection_types = c("RN", "APPB")
  )
  expect_s3_class(result, "sf")
})

test_that("indicator_biodiversity_structure returns valid structure index", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 3)
  result <- indicator_biodiversity_structure(units)
  
  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
})

test_that("indicator_biodiversity_structure with strata_field", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$strate <- c("futaie", "taillis", "mixte")
  
  result <- indicator_biodiversity_structure(units, strata_field = "strate")
  expect_s3_class(result, "sf")
  expect_true("B2" %in% names(result))
})

test_that("indicator_biodiversity_connectivity returns B3", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  result <- suppressWarnings(indicator_biodiversity_connectivity(units))
  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
})

test_that("indicator_biodiversity_connectivity with bdforet", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  bdforet <- sf::st_sf(
    TFV = rep("Forêt fermée de feuillus", 5),
    geometry = sf::st_sfc(lapply(1:5, function(i) {
      sf::st_polygon(list(matrix(
        c(566400 + (i-1)*100, 6615100,
          566400 + i*100, 6615100,
          566400 + i*100, 6615200,
          566400 + (i-1)*100, 6615200,
          566400 + (i-1)*100, 6615100),
        ncol = 2, byrow = TRUE
      )))
    }), crs = 2154)
  )
  
  result <- indicator_biodiversity_connectivity(units, bdforet = bdforet)
  expect_s3_class(result, "sf")
  expect_true("B3" %in% names(result))
})

# ==============================================================================
# indicators-risk.R
# ==============================================================================

test_that("indicator_risk_fire returns R1 with fallback method", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = "random")
  
  result <- indicator_risk_fire(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0, na.rm = TRUE))
})

test_that("indicator_risk_fire with species data", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 3)
  units$essence <- c("Pinus", "Quercus", "Fagus")
  dem <- create_test_raster(values = "random")
  
  result <- indicator_risk_fire(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
})

test_that("indicator_risk_storm returns R2", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 500, length.out = terra::ncell(create_test_raster())))
  
  result <- indicator_risk_storm(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
})

test_that("indicator_risk_storm without DEM returns defaults", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  result <- indicator_risk_storm(units)
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
})

test_that("indicator_risk_drought returns R3", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  result <- indicator_risk_drought(units)
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
})

test_that("indicator_risk_drought with DEM for topographic modulation", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 500, length.out = terra::ncell(create_test_raster())))
  
  result <- indicator_risk_drought(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
})

test_that("indicator_risk_browsing returns R4", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  result <- indicator_risk_browsing(units)
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
})

test_that("indicator_risk_browsing with species palatability", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$essence <- c("Quercus", "Fagus", "Pinus")
  
  result <- indicator_risk_browsing(units)
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
})

# ==============================================================================
# indicators-naturalness.R
# ==============================================================================

test_that("indicator_naturalness_distance returns N1", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  roads <- create_test_vector(type = "lines")
  
  result <- indicator_naturalness_distance(units, roads = roads)
  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
})

test_that("indicator_naturalness_distance without roads returns default", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  result <- indicator_naturalness_distance(units)
  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
})

test_that("indicator_naturalness_distance with custom column_name", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  result <- indicator_naturalness_distance(units, column_name = "nat_dist")
  expect_true("nat_dist" %in% names(result))
})

test_that("indicator_naturalness_continuity returns N2", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  result <- indicator_naturalness_continuity(units)
  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
})

test_that("indicator_naturalness_continuity with bdforet", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  bdforet <- sf::st_sf(
    TFV = c("Forêt ancienne", "Forêt récente"),
    geometry = sf::st_geometry(sf::st_buffer(units, 100))
  )
  sf::st_crs(bdforet) <- sf::st_crs(units)
  
  result <- indicator_naturalness_continuity(units, bdforet = bdforet)
  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
})

test_that("indicator_naturalness_composite returns N3", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$N1 <- c(60, 70, 80)
  units$N2 <- c(50, 60, 70)
  
  result <- indicator_naturalness_composite(units)
  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
})

test_that("indicator_naturalness_composite without N1/N2 returns default", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  result <- indicator_naturalness_composite(units)
  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
})

# ==============================================================================
# indicators-air.R
# ==============================================================================

test_that("indicator_air_coverage returns A1 with landcover raster", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 3)
  landcover <- create_test_raster(values = "constant")
  terra::values(landcover) <- sample(1:5, terra::ncell(landcover), replace = TRUE)
  
  result <- indicator_air_coverage(units, land_cover = landcover)
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicator_air_coverage with custom forest_classes", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 2)
  landcover <- create_test_raster(values = "constant")
  terra::values(landcover) <- sample(1:10, terra::ncell(landcover), replace = TRUE)
  
  result <- indicator_air_coverage(
    units, land_cover = landcover,
    forest_classes = c(1, 2, 3, 4, 5)
  )
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicator_air_coverage with custom buffer_radius", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  units <- create_test_units(n_features = 2)
  landcover <- create_test_raster(values = "constant")
  terra::values(landcover) <- sample(1:5, terra::ncell(landcover), replace = TRUE)
  
  result <- indicator_air_coverage(
    units, land_cover = landcover, buffer_radius = 500
  )
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicator_air_quality returns A2 with proxy method", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  roads <- create_test_vector(type = "lines")
  
  result <- indicator_air_quality(units, roads = roads, method = "proxy")
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
})

test_that("indicator_air_quality without roads returns default", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  result <- indicator_air_quality(units)
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
})

# ==============================================================================
# indicators-energy.R
# ==============================================================================

test_that("indicator_energy_fuelwood returns E1", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$volume <- c(100, 200, 300)
  units$essence <- c("Quercus", "Fagus", "Pinus")
  
  result <- indicator_energy_fuelwood(
    units,
    volume_field = "volume",
    species_field = "essence"
  )
  expect_s3_class(result, "sf")
  expect_true("E1" %in% names(result))
})

test_that("indicator_energy_fuelwood errors without volume field", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  expect_error(indicator_energy_fuelwood(units), "Required field missing")
})

test_that("indicator_energy_fuelwood with custom harvest_rate", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  units$volume <- c(100, 200)
  
  result <- indicator_energy_fuelwood(
    units, volume_field = "volume", harvest_rate = 0.5
  )
  expect_s3_class(result, "sf")
  expect_true("E1" %in% names(result))
})

test_that("indicator_energy_avoidance returns E2", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$E1 <- c(50, 100, 150)
  units$volume <- c(100, 200, 300)
  
  result <- indicator_energy_avoidance(
    units,
    fuelwood_field = "E1",
    volume_field = "volume"
  )
  expect_s3_class(result, "sf")
  expect_true("E2" %in% names(result))
})

test_that("indicator_energy_avoidance with default fields", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  
  result <- indicator_energy_avoidance(units)
  expect_s3_class(result, "sf")
  expect_true("E2" %in% names(result))
})

test_that("indicator_energy_avoidance with custom column_name", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  
  result <- indicator_energy_avoidance(units, column_name = "co2_avoided")
  expect_true("co2_avoided" %in% names(result))
})
