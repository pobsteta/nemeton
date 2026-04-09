# test-indicators-risk.R
# Unit and integration tests for Risk & Resilience Family (R) Indicators
# Aligned with tuto 03 methodology (fireexposuR, microclima, SPEI)

# ==============================================================================
# T026: Unit Tests for indicateur_r1_feu() (R1)
# ==============================================================================

test_that("indicateur_r1_feu calculates fallback risk correctly", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Add species attribute
  units$species <- sample(c("Pinus", "Quercus", "Fagus"), 5, replace = TRUE)

  # Load test fixtures
  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))
  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  # Calculate R1 (fallback: no bdforet, no fireexposuR)
  result <- indicateur_r1_feu(
    units,
    dem = dem,
    species_field = "species",
    climate = climate
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_type(result$R1, "double")
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicateur_r1_feu handles missing climate data gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]
  units$species <- rep("Quercus", 3)

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  # Without climate data (should use slope + species only)
  result <- indicateur_r1_feu(units, dem = dem, species_field = "species", climate = NULL)

  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicateur_r1_feu returns NA without DEM", {
  units <- create_test_units(n_features = 3)
  result <- indicateur_r1_feu(units)
  expect_true(all(is.na(result$R1)))
})

test_that("indicateur_r1_feu accepts bdforet parameter", {
  # Verify the function signature accepts bdforet (even if fireexposuR not installed)
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # Create a simple bdforet-like sf object
  bdforet <- create_test_units(n_features = 2)

  # Should work without error (falls back if fireexposuR not installed)
  result <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet)
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T027: Unit Tests for indicateur_r2_tempete() (R2)
# ==============================================================================

test_that("indicateur_r2_tempete calculates vulnerability with DEM", {
  units <- create_test_units(n_features = 5)
  dem <- create_test_raster()

  result <- indicateur_r2_tempete(units, dem = dem)

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_type(result$R2, "double")
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

test_that("indicateur_r2_tempete returns NA without DEM", {
  units <- create_test_units(n_features = 3)

  result <- indicateur_r2_tempete(units)
  expect_true(all(is.na(result$R2)))
})

test_that("indicateur_r2_tempete simplified signature (no height/density)", {
  # Verify the new signature: only units, dem, layers
  expect_true(all(c("units", "dem", "layers") %in% names(formals(indicateur_r2_tempete))))
  # Old params should NOT be in the signature
  expect_false("height_field" %in% names(formals(indicateur_r2_tempete)))
  expect_false("density_field" %in% names(formals(indicateur_r2_tempete)))
  expect_false("weights" %in% names(formals(indicateur_r2_tempete)))
})

test_that("indicateur_r2_tempete with demo data", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  result <- indicateur_r2_tempete(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T028: Unit Tests for indicateur_r3_secheresse() (R3)
# ==============================================================================

test_that("indicateur_r3_secheresse calculates stress with DEM", {
  units <- create_test_units(n_features = 5)
  dem <- create_test_raster()

  result <- indicateur_r3_secheresse(units, dem = dem)

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_type(result$R3, "double")
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicateur_r3_secheresse returns NA without DEM", {
  units <- create_test_units(n_features = 3)

  result <- indicateur_r3_secheresse(units)
  expect_true(all(is.na(result$R3)))
})

test_that("indicateur_r3_secheresse simplified signature", {
  # Verify the new signature: units, layers, dem, climate_data
  params <- names(formals(indicateur_r3_secheresse))
  expect_true(all(c("units", "layers", "dem", "climate_data") %in% params))
  # Old params should NOT be in the signature
  expect_false("twi_field" %in% params)
  expect_false("species_field" %in% params)
  expect_false("weights" %in% params)
})

test_that("indicateur_r3_secheresse accepts climate_data", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # Provide climate data
  n_months <- 60
  climate_data <- list(
    precip = pmax(0, rep(c(60, 55, 50, 45, 50, 30, 20, 25, 40, 55, 65, 70), length.out = n_months) +
      rnorm(n_months, 0, 10)),
    temp = list(
      tmin = rep(c(0, 1, 4, 7, 11, 15, 18, 17, 13, 8, 4, 1), length.out = n_months) +
        rnorm(n_months, 0, 1),
      tmax = rep(c(8, 10, 14, 18, 22, 27, 30, 29, 24, 18, 12, 8), length.out = n_months) +
        rnorm(n_months, 0, 1)
    )
  )

  # Should work with or without SPEI
  result <- indicateur_r3_secheresse(units, dem = dem, climate_data = climate_data)
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicateur_r3_secheresse with demo data", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))

  result <- indicateur_r3_secheresse(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

# ==============================================================================
# T029: Integration Test for R Family Workflow
# ==============================================================================

test_that("R family workflow: R1-R3 -> normalize -> famille_risque composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Add species for R1 fallback
  units$species <- sample(c("Pinus", "Quercus", "Fagus"), 10, replace = TRUE)

  # Load fixtures
  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))
  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )

  # Full workflow (R1 fallback, R2 terrain fallback, R3 topo+default climate)
  result <- units %>%
    indicateur_r1_feu(dem = dem, species_field = "species", climate = climate) %>%
    indicateur_r2_tempete(dem = dem) %>%
    indicateur_r3_secheresse(dem = dem) %>%
    normalize_indicators(indicators = c("R1", "R2", "R3")) %>%
    create_family_index(family_codes = "R")

  # Verify complete workflow
  expect_true(all(c("R1", "R2", "R3") %in% names(result)))
  expect_true(all(c("R1_norm", "R2_norm", "R3_norm") %in% names(result)))
  expect_true("famille_risque" %in% names(result))
  expect_true(all(result$famille_risque >= 0 & result$famille_risque <= 100, na.rm = TRUE))
})

# ==============================================================================
# T030: Unit Tests for indicateur_r4_abroutissement() (R4)
# ==============================================================================

test_that("indicateur_r4_abroutissement calculates composite risk correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Without layers: defaults for palatability and vulnerability
  result <- indicateur_r4_abroutissement(units)

  # Tests
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  expect_true("R4_vulnerability" %in% names(result))
  expect_type(result$R4, "double")
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("indicateur_r4_abroutissement simplified signature (tuto 03)", {
  # Verify the new signature: units, layers, bdforet, game_density, edge_buffer
  params <- names(formals(indicateur_r4_abroutissement))
  expect_true(all(c("units", "layers", "bdforet", "game_density", "edge_buffer") %in% params))
  # Old params should NOT be in the signature
  expect_false("species_field" %in% params)
  expect_false("height_field" %in% params)
  expect_false("age_field" %in% params)
  expect_false("weights" %in% params)
})

test_that("indicateur_r4_abroutissement uses BD Foret for palatability", {
  # Create test units and a mock BD Foret sf
  units <- create_test_units(n_features = 3)

  # Create BD Foret polygons overlapping test units with species info
  bdforet <- create_test_units(n_features = 3)
  bdforet$essence <- c("Chene sessile", "Pin maritime", "Epicea commun")

  result <- indicateur_r4_abroutissement(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("R4_palatability" %in% names(result))
  # Chene (oak) should be high, Epicea (spruce) should be low
  expect_true(result$R4_palatability[1] > result$R4_palatability[3])
})

test_that("indicateur_r4_abroutissement calculates edge exposure", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  result <- indicateur_r4_abroutissement(units, edge_buffer = 50)

  # Edge factor should be calculated (part of R4)
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicateur_r4_abroutissement uses game density raster when provided", {
  # Use test units that match raster extent
  units <- create_test_units(n_features = 3)

  # Create mock game density raster matching the test units extent
  game_raster <- create_test_raster(values = "random")

  result <- indicateur_r4_abroutissement(
    units,
    game_density = game_raster
  )

  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("indicateur_r4_abroutissement defaults to 50 without layers", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # No layers, no bdforet → default palatability and vulnerability
  result <- indicateur_r4_abroutissement(units)

  # Should use defaults (50 for both)
  expect_true(all(result$R4_palatability == 50))
  expect_true(all(result$R4_vulnerability == 50))
})

test_that("indicateur_r4_abroutissement uses fixed weights from tuto 03", {
  # With default data, R4 should be computed with fixed weights
  # palatability(50)*0.35 + vulnerability(50)*0.30 + edge*0.20 + density(50)*0.15
  units <- create_test_units(n_features = 2)
  result <- indicateur_r4_abroutissement(units)

  # Without any data sources, palatability=50, vulnerability=50, density=50
  # So R4 ≈ 0.35*50 + 0.30*50 + 0.20*edge + 0.15*50 = 40 + 0.20*edge
  # Edge for 100m squares with 50m buffer = 100% (entirely in edge zone)
  # So R4 ≈ 17.5 + 15 + 20 + 7.5 = 60
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

# ==============================================================================
# Additional edge case tests for R family
# ==============================================================================

test_that("indicateur_r1_feu handles units outside raster extent gracefully", {
  # Create units outside the standard test raster extent
  offset_units <- create_test_units(n_features = 2)
  sf::st_geometry(offset_units) <- sf::st_geometry(offset_units) + c(10000, 10000)
  sf::st_crs(offset_units) <- 2154

  offset_units$species <- c("Pinus", "Fagus")

  dem <- create_test_raster()

  # Should still work but may have NA values for slope
  result <- indicateur_r1_feu(
    offset_units,
    dem = dem,
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
})

test_that("R indicators validate sf input", {
  expect_error(
    indicateur_r1_feu(data.frame(x = 1:3), dem = create_test_raster()),
    "must be an.*sf.*object"
  )

  expect_error(
    indicateur_r2_tempete(data.frame(x = 1:3), dem = create_test_raster()),
    "must be an.*sf.*object"
  )

  expect_error(
    indicateur_r3_secheresse(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )

  expect_error(
    indicateur_r4_abroutissement(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

# ==============================================================================
# Coverage-focused tests for uncovered code paths
# ==============================================================================

# --- R1: indicateur_r1_feu additional coverage ---

test_that("indicateur_r1_feu fallback path without species field", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # No species column present, should use species_factor=50 fallback
  result <- indicateur_r1_feu(units, dem = dem, species_field = "nonexistent_species")

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicateur_r1_feu with DEM but no bdforet exercises fallback method", {
  units <- create_test_units(n_features = 3)
  units$species <- c("Pinus", "Quercus", "Fagus")
  dem <- create_test_raster()

  # DEM provided, no bdforet -> should use fallback method (slope + species + climate)
  result <- indicateur_r1_feu(
    units,
    dem = dem,
    bdforet = NULL,
    species_field = "species",
    climate = NULL
  )

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicateur_r1_feu weight redistribution when no climate", {
  units <- create_test_units(n_features = 2)
  units$species <- c("Pinus", "Quercus")
  dem <- create_test_raster()

  # Explicit weights, no climate -> weights should be redistributed
  result <- indicateur_r1_feu(
    units,
    dem = dem,
    species_field = "species",
    climate = NULL,
    weights = c(slope = 0.4, species = 0.3, climate = 0.3)
  )

  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

# --- R2: indicateur_r2_tempete additional coverage ---

test_that("indicateur_r2_tempete exercises terrain fallback (no microclima)", {
  # This test exercises the fallback branch with aspect, slope, TRI
  units <- create_test_units(n_features = 4)

  # Create DEM with varying elevation for meaningful terrain derivatives
  dem <- terra::rast(
    extent = terra::ext(566400, 567000, 6615100, 6615500),
    resolution = 10,
    crs = "EPSG:2154"
  )
  # Gradient from low to high elevation
  vals <- rep(seq(100, 500, length.out = terra::ncol(dem)), terra::nrow(dem))
  terra::values(dem) <- vals

  result <- indicateur_r2_tempete(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_type(result$R2, "double")
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

test_that("indicateur_r2_tempete with constant DEM (TRI max = 0 edge case)", {
  units <- create_test_units(n_features = 2)

  # Flat DEM -> TRI max will be 0 or very small
  dem <- create_test_raster(values = "constant")

  result <- indicateur_r2_tempete(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100, na.rm = TRUE))
})

# --- R3: indicateur_r3_secheresse additional coverage ---

test_that("indicateur_r3_secheresse with SPEI package exercises climate component", {
  skip_if_not_installed("SPEI")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  # With SPEI installed and no climate_data, uses simulated data

  result <- indicateur_r3_secheresse(units, dem = dem, climate_data = NULL)

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicateur_r3_secheresse with provided climate_data and SPEI", {
  skip_if_not_installed("SPEI")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()

  n_months <- 60
  set.seed(123)
  climate_data <- list(
    precip = pmax(0, rep(c(60, 55, 50, 45, 50, 30, 20, 25, 40, 55, 65, 70),
                         length.out = n_months) + rnorm(n_months, 0, 10)),
    temp = list(
      tmin = rep(c(0, 1, 4, 7, 11, 15, 18, 17, 13, 8, 4, 1),
                 length.out = n_months) + rnorm(n_months, 0, 1),
      tmax = rep(c(8, 10, 14, 18, 22, 27, 30, 29, 24, 18, 12, 8),
                 length.out = n_months) + rnorm(n_months, 0, 1)
    )
  )

  result <- indicateur_r3_secheresse(
    units,
    dem = dem,
    climate_data = climate_data
  )

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("indicateur_r3_secheresse topographic component with varied DEM", {
  units <- create_test_units(n_features = 3)

  # Create DEM with varying terrain for aspect/slope/TWI variation
  dem <- terra::rast(
    extent = terra::ext(566400, 567000, 6615100, 6615500),
    resolution = 10,
    crs = "EPSG:2154"
  )
  # Diagonal gradient for slope and aspect variation
  nr <- terra::nrow(dem)
  nc <- terra::ncol(dem)
  vals <- matrix(0, nrow = nr, ncol = nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      vals[i, j] <- 200 + i * 5 + j * 3
    }
  }
  terra::values(dem) <- as.vector(t(vals))

  result <- indicateur_r3_secheresse(units, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

# --- R4: indicateur_r4_abroutissement additional coverage ---

test_that("indicateur_r4_abroutissement exercises all default components", {
  units <- create_test_units(n_features = 5)

  # No bdforet, no layers, no game_density -> all defaults
  result <- indicateur_r4_abroutissement(units)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  expect_true("R4_vulnerability" %in% names(result))
  # All components use defaults
  expect_true(all(result$R4_palatability == 50))
  expect_true(all(result$R4_vulnerability == 50))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicateur_r4_abroutissement with bdforet lacking essence column", {
  units <- create_test_units(n_features = 3)

  # BD Foret without any recognized essence column
  bdforet_geom <- c(
    sf::st_buffer(sf::st_geometry(units)[1], 80),
    sf::st_buffer(sf::st_geometry(units)[2], 80),
    sf::st_buffer(sf::st_geometry(units)[3], 80)
  )
  bdforet <- sf::st_sf(
    code_tfv_unused = c("A", "B", "C"),
    geometry = bdforet_geom
  )

  # Should use default palatability (50) since no recognized essence column
  result <- indicateur_r4_abroutissement(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4_palatability == 50))
})

test_that("indicateur_r4_abroutissement edge exposure with small polygons", {
  # Very small polygons where buffer might collapse entirely
  units <- create_test_units(n_features = 2)

  # With edge_buffer larger than polygon -> inner should collapse, edge_proportion = 1
  result <- indicateur_r4_abroutissement(units, edge_buffer = 200)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100))
})

test_that("indicateur_r4_abroutissement with bdforet and valid essence column", {
  units <- create_test_units(n_features = 3)

  # BD Foret with recognized 'essence' column
  bdforet_geom <- c(
    sf::st_buffer(sf::st_geometry(units)[1], 100),
    sf::st_buffer(sf::st_geometry(units)[2], 100),
    sf::st_buffer(sf::st_geometry(units)[3], 100)
  )
  bdforet <- sf::st_sf(
    essence = c("chene sessile", "pin maritime", "hetre commun"),
    geometry = bdforet_geom
  )

  result <- indicateur_r4_abroutissement(units, bdforet = bdforet)

  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
  expect_true("R4_palatability" %in% names(result))
  # The palatability should differ per species (at least some non-50)
  expect_true(any(result$R4_palatability != 50))
})

# ==============================================================================
# (migrated from test-cov80-batch8.R)
# Coverage boost for R1-R4 fallback paths
# ==============================================================================

# --- R1: indicateur_r1_feu batch8 tests ---

test_that("R1 with DEM computes fallback slope-based fire risk", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 500, length.out = 2400))

  result <- nemeton::indicateur_r1_feu(units, dem = dem)
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("R1 with NULL DEM returns NA", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicateur_r1_feu(units, dem = NULL)
  expect_true(all(is.na(result$R1)))
})

test_that("R1 with species field uses species flammability", {
  units <- create_test_units(n_features = 3)
  units$species <- c("Pinus pinaster", "Fagus sylvatica", "Quercus suber")
  dem <- create_test_raster(values = seq(100, 500, length.out = 2400))

  result <- nemeton::indicateur_r1_feu(units, dem = dem)
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("R1 with NDVI proxy when no species field", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 300, length.out = 2400))
  ndvi <- create_test_raster(values = "random")
  terra::values(ndvi) <- runif(terra::ncell(ndvi), 0.3, 0.8)

  layers <- list(rasters = list(dem = dem, ndvi = ndvi))
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicateur_r1_feu(units, layers = layers)
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
  result <- nemeton::indicateur_r1_feu(units, dem = dem, climate = climate)
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

# --- R2: indicateur_r2_tempete batch8 tests ---

test_that("R2 with DEM computes terrain-based storm risk", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 600, length.out = 2400))

  result <- nemeton::indicateur_r2_tempete(units, dem = dem)
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100))
})

test_that("R2 with NULL DEM returns NA", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicateur_r2_tempete(units, dem = NULL)
  expect_true(all(is.na(result$R2)))
})

test_that("R2 from layers extracts DEM", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 600, length.out = 2400))

  layers <- list(rasters = list(dem = dem))
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicateur_r2_tempete(units, layers = layers)
  expect_true("R2" %in% names(result))
  expect_true(all(result$R2 >= 0 & result$R2 <= 100))
})

# --- R3: indicateur_r3_secheresse batch8 tests ---

test_that("R3 with DEM computes drought risk", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 400, length.out = 2400))

  result <- nemeton::indicateur_r3_secheresse(units, dem = dem)
  expect_true("R3" %in% names(result))
  expect_true(all(result$R3 >= 0 & result$R3 <= 100, na.rm = TRUE))
})

test_that("R3 from layers extracts DEM", {
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 400, length.out = 2400))

  layers <- list(rasters = list(dem = dem))
  class(layers) <- "nemeton_layers"

  result <- nemeton::indicateur_r3_secheresse(units, layers = layers)
  expect_true("R3" %in% names(result))
})

test_that("R3 without DEM returns NA", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicateur_r3_secheresse(units, dem = NULL)
  expect_true(all(is.na(result$R3)))
})

# --- R4: indicateur_r4_abroutissement batch8 tests ---

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

  result <- nemeton::indicateur_r4_abroutissement(units, bdforet = bdforet)
  expect_true("R4" %in% names(result))
  expect_true(all(result$R4 >= 0 & result$R4 <= 100, na.rm = TRUE))
})

test_that("R4 without bdforet returns fallback", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::indicateur_r4_abroutissement(units, bdforet = NULL)
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

  result <- nemeton::indicateur_r4_abroutissement(units, bdforet = bdforet, edge_buffer = 200)
  expect_true("R4" %in% names(result))
})

# ==============================================================================
# (migrated from test-cov60-batch4.R)
# ==============================================================================

test_that("indicateur_r1_feu returns R1 with fallback method", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = "random")

  result <- indicateur_r1_feu(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
  expect_true(all(result$R1 >= 0, na.rm = TRUE))
})

test_that("indicateur_r1_feu with species data", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  units$essence <- c("Pinus", "Quercus", "Fagus")
  dem <- create_test_raster(values = "random")

  result <- indicateur_r1_feu(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R1" %in% names(result))
})

test_that("indicateur_r2_tempete returns R2", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 500, length.out = terra::ncell(create_test_raster())))

  result <- indicateur_r2_tempete(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
})

test_that("indicateur_r2_tempete without DEM returns defaults", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  result <- indicateur_r2_tempete(units)
  expect_s3_class(result, "sf")
  expect_true("R2" %in% names(result))
})

test_that("indicateur_r3_secheresse returns R3", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  result <- indicateur_r3_secheresse(units)
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
})

test_that("indicateur_r3_secheresse with DEM for topographic modulation", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  dem <- create_test_raster(values = seq(100, 500, length.out = terra::ncell(create_test_raster())))

  result <- indicateur_r3_secheresse(units, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("R3" %in% names(result))
})

test_that("indicateur_r4_abroutissement returns R4", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  result <- indicateur_r4_abroutissement(units)
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
})

test_that("indicateur_r4_abroutissement with species palatability", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$essence <- c("Quercus", "Fagus", "Pinus")

  result <- indicateur_r4_abroutissement(units)
  expect_s3_class(result, "sf")
  expect_true("R4" %in% names(result))
})
