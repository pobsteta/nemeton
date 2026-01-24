# Tests for Tutorial 01 - Data Acquisition
# These tests verify the tutorial functions and data structures

test_that("tutorial 01 Rmd file exists", {
  tutorial_path <- system.file(
    "tutorials", "01-acquisition", "01-acquisition.Rmd",
    package = "nemeton"
  )

  skip_if(tutorial_path == "", "Tutorial file not found in installed package")
  expect_true(file.exists(tutorial_path))
})

test_that("zone d'etude can be created from coordinates", {
  skip_if_not_installed("sf")

  library(sf)

  # Test zone creation from center point

  center_x <- 899500
  center_y <- 6447500
  buffer_m <- 500

  center_point <- st_as_sf(
    data.frame(x = center_x, y = center_y),
    coords = c("x", "y"),
    crs = 2154
  )

  zone <- st_buffer(center_point, buffer_m)

  expect_s3_class(zone, "sf")
  expect_equal(st_crs(zone)$epsg, 2154)

  # Check area (should be ~pi * r^2)
  area_ha <- as.numeric(st_area(zone)) / 10000
  expected_area <- pi * (buffer_m / 100)^2  # ~78.5 ha
  expect_equal(area_ha, expected_area, tolerance = 0.1)
})

test_that("CRS Lambert 93 (EPSG:2154) is valid", {
  skip_if_not_installed("sf")

  library(sf)

  # Create a point in Lambert 93
  pt <- st_sfc(st_point(c(899500, 6447500)), crs = 2154)

  expect_equal(st_crs(pt)$epsg, 2154)

  # Check it's a valid projected CRS (units in meters)
  crs_info <- st_crs(pt)
  expect_true(grepl("Lambert", crs_info$input, ignore.case = TRUE) ||
              crs_info$epsg == 2154)
})

test_that("bbox calculation is correct", {
  skip_if_not_installed("sf")

  library(sf)

  # Create a simple polygon
  coords <- matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE)
  poly <- st_polygon(list(coords))
  poly_sf <- st_sf(id = 1, geometry = st_sfc(poly, crs = 2154))

  bbox <- st_bbox(poly_sf)

  expect_equal(as.numeric(bbox["xmin"]), 0)
  expect_equal(as.numeric(bbox["ymin"]), 0)
  expect_equal(as.numeric(bbox["xmax"]), 100)
  expect_equal(as.numeric(bbox["ymax"]), 100)
})

test_that("network timeout configuration is valid", {
  # Test timeout values from tutorial
  NETWORK_TIMEOUT <- 300

  expect_true(NETWORK_TIMEOUT > 0)
  expect_true(NETWORK_TIMEOUT <= 600)  # Max 10 minutes

  # Test setting options
  old_timeout <- getOption("timeout")
  options(timeout = NETWORK_TIMEOUT)
  expect_equal(getOption("timeout"), NETWORK_TIMEOUT)
  options(timeout = old_timeout)
})

test_that("data directory creation works", {
  # Test with temporary directory
  temp_dir <- file.path(tempdir(), "nemeton_test", "tutorial_data")

  # Clean up first
  if (dir.exists(temp_dir)) unlink(temp_dir, recursive = TRUE)

  # Create directory
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

  expect_true(dir.exists(temp_dir))

  # Clean up
  unlink(dirname(temp_dir), recursive = TRUE)
})

test_that("GeoPackage layer reading simulation works", {
  skip_if_not_installed("sf")

  library(sf)

  # Simulate creating a multi-layer GeoPackage structure
  temp_gpkg <- tempfile(fileext = ".gpkg")

  # Create test data
  zone <- st_sf(
    id = 1,
    name = "test_zone",
    geometry = st_sfc(
      st_polygon(list(matrix(c(0,0, 100,0, 100,100, 0,100, 0,0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Write to GeoPackage
  st_write(zone, temp_gpkg, layer = "zone_etude", quiet = TRUE, delete_dsn = TRUE)

  # Read back
  zone_read <- st_read(temp_gpkg, layer = "zone_etude", quiet = TRUE)

  expect_s3_class(zone_read, "sf")
  expect_equal(nrow(zone_read), 1)
  expect_equal(st_crs(zone_read)$epsg, 2154)

  # Clean up
  unlink(temp_gpkg)
})

test_that("coordinate transformation works", {
  skip_if_not_installed("sf")

  library(sf)

  # Create point in WGS84
  pt_wgs84 <- st_sfc(st_point(c(5.7, 45.2)), crs = 4326)

  # Transform to Lambert 93
  pt_lambert <- st_transform(pt_wgs84, 2154)

  expect_equal(st_crs(pt_lambert)$epsg, 2154)

  # Coordinates should be in meters (large numbers)
  coords <- st_coordinates(pt_lambert)
  expect_true(coords[1] > 100000)  # X in meters
  expect_true(coords[2] > 1000000) # Y in meters
})

test_that("area calculation is in correct units", {
  skip_if_not_installed("sf")

  library(sf)

  # Create 100m x 100m square in Lambert 93
  square <- st_polygon(list(matrix(c(
    0, 0,
    100, 0,
    100, 100,
    0, 100,
    0, 0
  ), ncol = 2, byrow = TRUE)))

  square_sf <- st_sf(id = 1, geometry = st_sfc(square, crs = 2154))

  area_m2 <- as.numeric(st_area(square_sf))
  area_ha <- area_m2 / 10000

  expect_equal(area_m2, 10000, tolerance = 0.01)
  expect_equal(area_ha, 1, tolerance = 0.01)
})

test_that("raster extent matching works", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  library(terra)
  library(sf)

  # Create a zone
  zone <- st_sf(
    id = 1,
    geometry = st_sfc(
      st_polygon(list(matrix(c(0,0, 100,0, 100,100, 0,100, 0,0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create a raster covering the zone
  r <- rast(ext(c(0, 100, 0, 100)), resolution = 10, crs = "EPSG:2154")
  values(r) <- runif(ncell(r))

  # Check extent matches
  r_ext <- ext(r)
  zone_bbox <- st_bbox(zone)

  expect_equal(r_ext$xmin, zone_bbox["xmin"], tolerance = 0.01)
  expect_equal(r_ext$xmax, zone_bbox["xmax"], tolerance = 0.01)
  expect_equal(r_ext$ymin, zone_bbox["ymin"], tolerance = 0.01)
  expect_equal(r_ext$ymax, zone_bbox["ymax"], tolerance = 0.01)
})
