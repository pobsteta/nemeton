# test-indicators-air.R
# Unit and integration tests for Air Quality & Microclimate Family (A) Indicators
# MVP v0.3.0 - Following TDD: Tests written BEFORE implementation

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T048: Unit Tests for indicator_air_coverage() (A1)
# ==============================================================================

test_that("indicator_air_coverage calculates buffer coverage correctly", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Load test fixture
  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  result <- indicator_air_coverage(
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

test_that("indicator_air_coverage handles different buffer radii", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  result_1km <- indicator_air_coverage(units, land_cover, buffer_radius = 1000)
  result_500m <- indicator_air_coverage(units, land_cover, buffer_radius = 500)

  # Both should produce valid results
  expect_true(all(result_1km$A1 >= 0 & result_1km$A1 <= 100, na.rm = TRUE))
  expect_true(all(result_500m$A1 >= 0 & result_500m$A1 <= 100, na.rm = TRUE))

  # Values may differ due to different buffer sizes
  expect_false(identical(result_1km$A1, result_500m$A1))
})

test_that("indicator_air_coverage filters forest classes correctly", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Only broadleaf forests
  result_broadleaf <- indicator_air_coverage(units, land_cover, forest_classes = c(311))

  # All forest types
  result_all <- indicator_air_coverage(units, land_cover, forest_classes = c(311, 312, 313))

  # All-forest coverage should be >= broadleaf-only coverage
  expect_true(all(result_all$A1 >= result_broadleaf$A1, na.rm = TRUE))
})

# ==============================================================================
# T049: Unit Tests for indicator_air_quality() (A2)
# ==============================================================================

test_that("indicator_air_quality uses direct method when ATMO data available", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # Mock ATMO station data
  # Get centroids of first two units for station locations
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

  result <- indicator_air_quality(units, atmo_data = atmo_data, method = "direct")

  # Tests
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
  expect_true("A2_method" %in% names(result))
  expect_equal(unique(result$A2_method), "direct")
  expect_true(all(result$A2 >= 0 & result$A2 <= 100, na.rm = TRUE))
})

test_that("indicator_air_quality uses proxy method when ATMO data unavailable", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Mock road and urban data
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = "R1",
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  urban_areas <- st_sf(
    urban_id = "U1",
    geometry = st_sfc(
      st_point(c(mean(c(bbox["xmin"], bbox["xmax"])), mean(c(bbox["ymin"], bbox["ymax"])))),
      crs = st_crs(units)
    )
  )

  result <- indicator_air_quality(
    units,
    atmo_data = NULL,
    roads = roads,
    urban_areas = urban_areas,
    method = "proxy"
  )

  # Tests
  expect_s3_class(result, "sf")
  expect_true("A2" %in% names(result))
  expect_true("A2_method" %in% names(result))
  expect_equal(unique(result$A2_method), "proxy")
  expect_true(all(result$A2 >= 0 & result$A2 <= 100, na.rm = TRUE))

  # Parcels farther from roads/urban should have better air quality
  # (This is a simplification for testing)
})

test_that("indicator_air_quality auto-detects method", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  # With ATMO data: should use direct
  # Get centroid of first unit for station location
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

  result_auto <- indicator_air_quality(units, atmo_data = atmo_data, method = "auto")

  expect_equal(unique(result_auto$A2_method), "direct")
})

test_that("indicator_air_quality handles missing data gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:2, ]

  # No ATMO, no roads, no urban → should fail or use defaults
  expect_error(
    indicator_air_quality(units, atmo_data = NULL, roads = NULL, urban_areas = NULL, method = "proxy"),
    "roads"  # Should error about missing proxy data
  )
})

# ==============================================================================
# T050: Integration Test for A Family Workflow
# ==============================================================================

test_that("A family workflow: A1-A2 → normalize → family_A composite", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Load fixtures
  land_cover <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))

  # Mock roads and urban for proxy method
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = "R1",
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  urban_areas <- st_sf(
    urban_id = "U1",
    geometry = st_sfc(
      st_point(c(mean(c(bbox["xmin"], bbox["xmax"])), mean(c(bbox["ymin"], bbox["ymax"])))),
      crs = st_crs(units)
    )
  )

  # Full workflow
  result <- units %>%
    indicator_air_coverage(land_cover = land_cover, buffer_radius = 1000) %>%
    indicator_air_quality(atmo_data = NULL, roads = roads, urban_areas = urban_areas, method = "proxy") %>%
    normalize_indicators(indicators = c("A1", "A2")) %>%
    create_family_index(family_codes = "A")

  # Verify complete workflow
  expect_true(all(c("A1", "A2") %in% names(result)))
  expect_true(all(c("A1_norm", "A2_norm") %in% names(result)))
  expect_true("family_A" %in% names(result))
  expect_true(all(result$family_A >= 0 & result$family_A <= 100, na.rm = TRUE))
})

# ==============================================================================
# T051: Regression Test Fixture
# ==============================================================================

test_that("A indicators match expected regression fixture", {
  skip("Regression fixture not yet created - will be generated after implementation")

  # This test will be enabled after creating expected_indicators_v030_air.rds
  # with known A1/A2 values
})
