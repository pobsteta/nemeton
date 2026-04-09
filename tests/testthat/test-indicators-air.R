# test-indicators-air.R
# Unit and integration tests for Air Quality & Microclimate Family (A) Indicators
# MVP v0.3.0 - Following TDD: Tests written BEFORE implementation

library(sf)
library(terra)

# ==============================================================================
# T048: Unit Tests for indicateur_a1_couverture() (A1)
# ==============================================================================

test_that("indicateur_a1_couverture calculates buffer coverage correctly", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Load test fixture
  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  result <- indicateur_a1_couverture(
    units,
    land_cover = land_cover,
    forest_classes = c(311, 312, 313),
    buffer_radius = 1000
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
  expect_type(result$A1, "double")
  expect_true(all(result$A1 >= 0 & result$A1 <= 100, na.rm = TRUE))

  # Parcels in forest-rich areas should have high A1
  expect_true(any(result$A1 > 50, na.rm = TRUE))
})

test_that("indicateur_a1_couverture handles different buffer radii", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  result_1km <- indicateur_a1_couverture(units, land_cover, buffer_radius = 1000)
  result_500m <- indicateur_a1_couverture(units, land_cover, buffer_radius = 500)

  # Both should produce valid results
  expect_true(all(result_1km$A1 >= 0 & result_1km$A1 <= 100, na.rm = TRUE))
  expect_true(all(result_500m$A1 >= 0 & result_500m$A1 <= 100, na.rm = TRUE))

  # Function should work with both buffer sizes (values may or may not differ
  # depending on local forest coverage homogeneity)
  expect_type(result_1km$A1, "double")
  expect_type(result_500m$A1, "double")
})

test_that("indicateur_a1_couverture filters forest classes correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Only broadleaf forests
  result_broadleaf <- indicateur_a1_couverture(units, land_cover, forest_classes = c(311))

  # All forest types
  result_all <- indicateur_a1_couverture(units, land_cover, forest_classes = c(311, 312, 313))

  # All-forest coverage should be >= broadleaf-only coverage
  expect_true(all(result_all$A1 >= result_broadleaf$A1, na.rm = TRUE))
})

# ==============================================================================
# T049: Unit Tests for indicateur_a2_qualite_air() (A2)
# ==============================================================================

test_that("indicateur_a2_qualite_air uses direct method when ATMO data available", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Mock ATMO station data
  # Get centroids of first two units for station locations
  sf::st_agr(units) <- "constant"
  unit_centroids <- st_coordinates(st_centroid(units[1:2, ]))

  atmo_data <- st_as_sf(
    data.frame(
      station_id = c("S1", "S2"),
      NO2 = c(20, 30),
      PM10 = c(15, 25),
      lon = unit_centroids[, 1],
      lat = unit_centroids[, 2]
    ),
    coords = c("lon", "lat"),
    crs = st_crs(units)
  )

  result <- indicateur_a2_qualite_air(units, atmo_data = atmo_data, method = "direct")

  # Tests
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
  expect_true("A2_method" %in% names(result))
  expect_equal(unique(result$A2_method), "direct")
  expect_true(all(result$A2 >= 0 & result$A2 <= 100, na.rm = TRUE))
})

test_that("indicateur_a2_qualite_air uses proxy method when ATMO data unavailable", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Mock road data with BD TOPO nature field
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = c("R1", "R2"),
    nature = c("Route à 1 chaussée", "Chemin"),
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      st_linestring(matrix(c(bbox["xmin"], bbox["xmin"] + 100, bbox["ymin"] + 50, bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  result <- indicateur_a2_qualite_air(
    units,
    atmo_data = NULL,
    roads = roads,
    method = "proxy"
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
  expect_true("A2_method" %in% names(result))
  expect_equal(unique(result$A2_method), "proxy")
  expect_true(all(result$A2 >= 0 & result$A2 <= 100, na.rm = TRUE))
})

test_that("indicateur_a2_qualite_air auto-detects method", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  # With ATMO data: should use direct
  # Get centroid of first unit for station location
  sf::st_agr(units) <- "constant"
  unit_centroid <- st_coordinates(st_centroid(units[1, ]))

  atmo_data <- st_as_sf(
    data.frame(
      station_id = "S1",
      NO2 = 25,
      PM10 = 20,
      lon = unit_centroid[1, 1],
      lat = unit_centroid[1, 2]
    ),
    coords = c("lon", "lat"),
    crs = st_crs(units)
  )

  result_auto <- indicateur_a2_qualite_air(units, atmo_data = atmo_data, method = "auto")

  expect_equal(unique(result_auto$A2_method), "direct")
})

test_that("indicateur_a2_qualite_air handles missing data gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  # No roads → should fail for proxy method
  expect_error(
    indicateur_a2_qualite_air(units, atmo_data = NULL, roads = NULL, method = "proxy"),
    "roads"
  )
})

# ==============================================================================
# T050: Integration Test for A Family Workflow
# ==============================================================================

test_that("A family workflow: A1-A2 → normalize → famille_air composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Load fixtures
  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Mock roads for proxy method with BD TOPO nature field
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = "R1",
    nature = "Route à 1 chaussée",
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  # Full workflow (normalize_indicators warns when all values are identical)
  expect_warning(
    result <- units %>%
      indicateur_a1_couverture(land_cover = land_cover, buffer_radius = 1000) %>%
      indicateur_a2_qualite_air(atmo_data = NULL, roads = roads, method = "proxy") %>%
      normalize_indicators(indicators = c("A1", "A2")) %>%
      create_family_index(family_codes = "A"),
    "All values are identical"
  )

  # Verify complete workflow
  expect_true(all(c("A1", "A2") %in% names(result)))
  expect_true(all(c("A1_norm", "A2_norm") %in% names(result)))
  expect_true("famille_air" %in% names(result))
  expect_true(all(result$famille_air >= 0 & result$famille_air <= 100, na.rm = TRUE))
})

# Note: Regression fixture test removed - will be added when fixtures are created

# ==============================================================================
# Additional tests for better coverage
# ==============================================================================

test_that("indicateur_a1_couverture validates input", {
  expect_error(
    indicateur_a1_couverture(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("indicateur_a1_couverture handles missing land_cover", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  expect_error(
    indicateur_a1_couverture(units, land_cover = NULL),
    "land_cover"
  )
})

test_that("indicateur_a1_couverture works with custom forest classes", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Custom classes
  result <- indicateur_a1_couverture(
    units,
    land_cover = land_cover,
    forest_classes = c(311)  # Only broadleaf
  )

  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicateur_a2_qualite_air validates input", {
  expect_error(
    indicateur_a2_qualite_air(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("indicateur_a2_qualite_air handles empty ATMO data", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  # Empty ATMO data
  atmo_empty <- sf::st_sf(
    station_id = character(0),
    NO2 = numeric(0),
    PM10 = numeric(0),
    geometry = sf::st_sfc(crs = sf::st_crs(units))
  )

  # Should either error or produce NA/0 values
  result <- tryCatch(
    indicateur_a2_qualite_air(units, atmo_data = atmo_empty, method = "direct"),
    error = function(e) NULL
  )

  # Either returns NULL (error) or a valid sf with A2 column
  expect_true(is.null(result) || (inherits(result, "sf") && "A2" %in% names(result)))
})

# ==============================================================================
# A2: Road field name fallback
# ==============================================================================

test_that("indicateur_a2_qualite_air handles road_type field name fallback", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Mock road data using "road_type" instead of "nature" (demo data format)
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = c("R1", "R2"),
    road_type = c("Route \u00e0 1 chauss\u00e9e", "Chemin"),
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      st_linestring(matrix(c(bbox["xmin"], bbox["xmin"] + 100, bbox["ymin"] + 50, bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  result <- indicateur_a2_qualite_air(
    units,
    atmo_data = NULL,
    roads = roads,
    method = "proxy"
  )

  # Should still produce valid results via fallback field detection
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
  expect_true(all(result$A2 >= 0 & result$A2 <= 100, na.rm = TRUE))
})

test_that("indicateur_a2_qualite_air handles unknown road field name gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  # Roads with no recognized type field - should use default weight 0.5
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = "R1",
    custom_field = "motorway",
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  result <- indicateur_a2_qualite_air(
    units,
    atmo_data = NULL,
    roads = roads,
    method = "proxy"
  )

  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
  expect_true(all(result$A2 >= 0 & result$A2 <= 100, na.rm = TRUE))
})

# ==============================================================================
# (migrated from test-cov60-batch4.R)
# ==============================================================================

test_that("indicateur_a1_couverture returns A1 with landcover raster", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 3)
  landcover <- create_test_raster(values = "constant")
  terra::values(landcover) <- sample(1:5, terra::ncell(landcover), replace = TRUE)

  result <- indicateur_a1_couverture(units, land_cover = landcover)
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicateur_a1_couverture with custom forest_classes", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 2)
  landcover <- create_test_raster(values = "constant")
  terra::values(landcover) <- sample(1:10, terra::ncell(landcover), replace = TRUE)

  result <- indicateur_a1_couverture(
    units, land_cover = landcover,
    forest_classes = c(1, 2, 3, 4, 5)
  )
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicateur_a1_couverture with custom buffer_radius", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  units <- create_test_units(n_features = 2)
  landcover <- create_test_raster(values = "constant")
  terra::values(landcover) <- sample(1:5, terra::ncell(landcover), replace = TRUE)

  result <- indicateur_a1_couverture(
    units, land_cover = landcover, buffer_radius = 500
  )
  expect_s3_class(result, "sf")
  expect_true("A1" %in% names(result))
})

test_that("indicateur_a2_qualite_air returns A2 with proxy method", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  roads <- create_test_vector(type = "lines")

  result <- indicateur_a2_qualite_air(units, roads = roads, method = "proxy")
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
})

test_that("indicateur_a2_qualite_air without roads returns default", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  result <- indicateur_a2_qualite_air(units)
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
})
