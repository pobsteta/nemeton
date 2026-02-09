# Test Suite for Social & Recreational Indicators (Family S)
# S1: Distance to roads, S2: Distance to buildings, S3: Population proximity

# ==============================================================================
# S1: Distance to Roads
# ==============================================================================

test_that("indicator_social_trails (S1) works with DEM + roads", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # Create a small DEM raster (100x100, 25m resolution in Lambert-93)
  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100 # flat terrain

  # Create road lines crossing the area
  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  # Create test units: one near the road, one far from it
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        602000, 6601000,
        602200, 6601000,
        602200, 6601200,
        602000, 6601200,
        602000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_trails(
    units = test_units,
    roads = roads,
    dem = dem
  )

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_type(result$S1, "double")

  # Both should have values (distance in metres)
  expect_true(all(!is.na(result$S1)))
  expect_true(all(result$S1 >= 0))

  # Unit near road should have smaller distance than unit far from road
  expect_true(result$S1[1] < result$S1[2])
})

test_that("indicator_social_trails (S1) returns NA without DEM", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_trails(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_true(is.na(result$S1[1]))
})

test_that("indicator_social_trails (S1) returns NA without roads", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- 50

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_trails(units = test_units, dem = dem)

  expect_true(is.na(result$S1[1]))
})

test_that("indicator_social_trails (S1) returns NA with empty roads (0 rows)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- 50

  # Empty roads sf with 0 rows
  empty_roads <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_trails(units = test_units, roads = empty_roads, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_true(is.na(result$S1[1]))
})

test_that("indicator_social_trails validates input types", {
  expect_error(
    indicator_social_trails(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_social_trails uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_trails(
    units = test_units,
    column_name = "road_distance"
  )

  expect_true("road_distance" %in% names(result))
  expect_false("S1" %in% names(result))
})

test_that("indicator_social_trails resolves roads and DEM from layers", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Mock the layer resolution to return our test data
  layers <- structure(
    list(
      rasters = list(dem = dem),
      vectors = list(roads = roads)
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_trails(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  # Should have a real numeric value (not NA), since layers resolved
  expect_false(is.na(result$S1[1]))
  expect_true(result$S1[1] >= 0)
})

test_that("indicator_social_trails resolves DEM from lidar_mnt fallback in layers", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # layers with lidar_mnt instead of dem
  layers <- structure(
    list(
      rasters = list(lidar_mnt = dem),
      vectors = list(roads = roads)
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_trails(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_false(is.na(result$S1[1]))
})

test_that("indicator_social_trails returns NA when layers has no roads", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- 50

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # layers with DEM but no roads
  layers <- structure(
    list(
      rasters = list(dem = dem),
      vectors = list()
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_trails(units = test_units, layers = layers)

  expect_true(is.na(result$S1[1]))
})

test_that("indicator_social_trails preserves original columns", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    name = c("unit_a", "unit_b"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_trails(units = test_units)

  # Original columns should be preserved
  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, c("unit_a", "unit_b"))
  # And new column added
  expect_true("S1" %in% names(result))
  # Same number of rows

  expect_equal(nrow(result), 2)
})

test_that("indicator_social_trails uses helper test fixtures", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # Use the helper functions from helper-fixtures.R
  test_units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "constant")
  roads <- create_test_vector(type = "lines")

  result <- indicator_social_trails(
    units = test_units,
    roads = roads,
    dem = dem
  )

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_equal(nrow(result), 2)
  # With actual roads and DEM, distances should be computed
  expect_true(all(!is.na(result$S1)))
  expect_true(all(result$S1 >= 0))
})

# ==============================================================================
# S2: Distance to Buildings
# ==============================================================================

test_that("indicator_social_accessibility (S2) works with DEM + buildings", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # Create a small DEM raster
  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  # Create building polygons
  buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create test units: one near building, one far
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        602000, 6601000,
        602200, 6601000,
        602200, 6601200,
        602000, 6601200,
        602000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(
    units = test_units,
    buildings = buildings,
    dem = dem
  )

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_type(result$S2, "double")

  # Both should have values (distance in metres)
  expect_true(all(!is.na(result$S2)))
  expect_true(all(result$S2 >= 0))

  # Unit near building should have smaller distance than unit far from building
  expect_true(result$S2[1] < result$S2[2])
})

test_that("indicator_social_accessibility (S2) returns NA without DEM", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(is.na(result$S2[1]))
})

test_that("indicator_social_accessibility (S2) returns NA without buildings", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- 50

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(units = test_units, dem = dem)

  expect_true(is.na(result$S2[1]))
})

test_that("indicator_social_accessibility (S2) returns NA with empty buildings (0 rows)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- 50

  # Empty buildings sf with 0 rows
  empty_buildings <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(
    units = test_units,
    buildings = empty_buildings,
    dem = dem
  )

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(is.na(result$S2[1]))
})

test_that("indicator_social_accessibility validates input", {
  expect_error(
    indicator_social_accessibility(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_social_accessibility uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(
    units = test_units,
    column_name = "building_distance"
  )

  expect_true("building_distance" %in% names(result))
  expect_false("S2" %in% names(result))
})

test_that("indicator_social_accessibility resolves buildings and DEM from layers", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  layers <- structure(
    list(
      rasters = list(dem = dem),
      vectors = list(buildings = buildings)
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_accessibility(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
  expect_true(result$S2[1] >= 0)
})

test_that("indicator_social_accessibility resolves DEM from lidar_mnt fallback", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # layers with lidar_mnt instead of dem
  layers <- structure(
    list(
      rasters = list(lidar_mnt = dem),
      vectors = list(buildings = buildings)
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_accessibility(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
})

test_that("indicator_social_accessibility returns NA when layers has no buildings", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- 50

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  layers <- structure(
    list(
      rasters = list(dem = dem),
      vectors = list()
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_accessibility(units = test_units, layers = layers)

  expect_true(is.na(result$S2[1]))
})

test_that("indicator_social_accessibility preserves original columns", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    name = c("building_a", "building_b"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(units = test_units)

  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, c("building_a", "building_b"))
  expect_true("S2" %in% names(result))
  expect_equal(nrow(result), 2)
})

# ==============================================================================
# S3: Population Proximity
# ==============================================================================

test_that("indicator_social_proximity (S3) calculates population buffers", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_proximity(
    units = test_units,
    method = "proxy",
    buffer_radii = c(5000, 10000, 20000)
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(result)))
  expect_type(result$S3, "double")
  expect_type(result$S3_5km, "double")
  expect_type(result$S3_10km, "double")
  expect_type(result$S3_20km, "double")

  # Population should increase with buffer size
  expect_true(all(result$S3_10km >= result$S3_5km))
  expect_true(all(result$S3_20km >= result$S3_10km))
})

test_that("indicator_social_proximity validates input", {
  expect_error(
    indicator_social_proximity(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_social_proximity uses buffer_radii parameter", {
  skip_if_not_installed("sf")

  # Use properly sized units with real coordinates
  test_units <- create_test_units(n_features = 1)

  result <- indicator_social_proximity(
    test_units,
    method = "proxy",
    buffer_radii = c(5000, 10000, 20000)
  )

  expect_true("S3_5km" %in% names(result))
  expect_true("S3_10km" %in% names(result))
  expect_true("S3_20km" %in% names(result))
  expect_true("S3" %in% names(result))
})

test_that("indicator_social_proximity uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_proximity(
    test_units,
    method = "proxy",
    column_name = "pop_score"
  )

  expect_true("pop_score" %in% names(result))
})

test_that("indicator_social_proximity S3 equals S3_5km (primary = first buffer)", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(5000, 0, 6000, 0, 6000, 1000, 5000, 1000, 5000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(10000, 0, 11000, 0, 11000, 1000, 10000, 1000, 10000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_proximity(
    test_units,
    method = "proxy",
    buffer_radii = c(5000, 10000, 20000)
  )

  # Primary indicator S3 should equal S3_5km
  expect_equal(result$S3, result$S3_5km)
})

test_that("indicator_social_proximity rejects invalid method", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  expect_error(
    indicator_social_proximity(test_units, method = "invalid_method"),
    "arg"
  )
})

test_that("indicator_social_proximity produces positive population values", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_proximity(
    test_units,
    method = "proxy",
    buffer_radii = c(5000, 10000, 20000)
  )

  # All population values should be positive (area * 100 density > 0)
  expect_true(all(result$S3_5km > 0))
  expect_true(all(result$S3_10km > 0))
  expect_true(all(result$S3_20km > 0))
  expect_true(all(result$S3 > 0))
})

test_that("indicator_social_proximity preserves original columns", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    name = c("forest_a", "forest_b"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(5000, 0, 6000, 0, 6000, 1000, 5000, 1000, 5000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_proximity(test_units, method = "proxy")

  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, c("forest_a", "forest_b"))
  expect_equal(nrow(result), 2)
})

test_that("indicator_social_proximity with custom buffer_radii", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Use different buffer radii
  result <- indicator_social_proximity(
    test_units,
    method = "proxy",
    buffer_radii = c(1000, 2000, 5000)
  )

  # S3_5km, S3_10km, S3_20km columns are always created with those names
  # (hardcoded in the function), but the actual buffers use the provided radii
  expect_true("S3_5km" %in% names(result))
  expect_true("S3_10km" %in% names(result))
  expect_true("S3_20km" %in% names(result))

  # Smaller buffers should give smaller population
  expect_true(result$S3_10km >= result$S3_5km)
  expect_true(result$S3_20km >= result$S3_10km)
})

test_that("indicator_social_proximity accepts method 'insee'", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # 'insee' is a valid method per match.arg; function runs the same proxy logic
  result <- indicator_social_proximity(test_units, method = "insee")

  expect_s3_class(result, "sf")
  expect_true("S3" %in% names(result))
})

test_that("indicator_social_proximity accepts method 'local'", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # 'local' is a valid method per match.arg
  result <- indicator_social_proximity(test_units, method = "local")

  expect_s3_class(result, "sf")
  expect_true("S3" %in% names(result))
})

test_that("indicator_social_proximity with multiple units computes per-unit values", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 5)

  result <- indicator_social_proximity(
    test_units,
    method = "proxy",
    buffer_radii = c(5000, 10000, 20000)
  )

  # Should have one value per unit
  expect_equal(nrow(result), 5)
  expect_equal(length(result$S3), 5)
  expect_equal(length(result$S3_5km), 5)
  expect_equal(length(result$S3_10km), 5)
  expect_equal(length(result$S3_20km), 5)

  # All values should be numeric and non-NA
  expect_true(all(!is.na(result$S3)))
  expect_true(all(!is.na(result$S3_5km)))
})

# ==============================================================================
# Integration
# ==============================================================================

test_that("Social indicators integrate with family system", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # S1 and S2 return NA without DEM/roads/buildings -- that's expected
  result <- test_units |>
    indicator_social_trails() |>
    indicator_social_accessibility() |>
    indicator_social_proximity(method = "proxy")

  # Check all indicators present
  expect_true(all(c("S1", "S2", "S3") %in% names(result)))
})

test_that("Social indicators can be chained on units with existing columns", {
  skip_if_not_installed("sf")

  # Start with units that already have other indicator columns
  test_units <- sf::st_sf(
    id = 1,
    C1 = 50.0,
    B1 = 0.8,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- test_units |>
    indicator_social_trails() |>
    indicator_social_accessibility() |>
    indicator_social_proximity(method = "proxy")

  # Original columns preserved
  expect_true("C1" %in% names(result))
  expect_true("B1" %in% names(result))
  expect_equal(result$C1, 50.0)
  expect_equal(result$B1, 0.8)
  # Social indicators added
  expect_true(all(c("S1", "S2", "S3") %in% names(result)))
})

test_that("indicator_social_trails returns correct number of NA for multi-unit input without DEM", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:5,
    geometry = sf::st_sfc(
      lapply(1:5, function(i) {
        sf::st_polygon(list(matrix(c(
          i * 100, 0,
          i * 100 + 100, 0,
          i * 100 + 100, 100,
          i * 100, 100,
          i * 100, 0
        ), ncol = 2, byrow = TRUE)))
      }),
      crs = 2154
    )
  )

  result <- indicator_social_trails(units = test_units)

  expect_equal(nrow(result), 5)
  expect_equal(sum(is.na(result$S1)), 5)
})

test_that("indicator_social_accessibility returns correct number of NA for multi-unit input without DEM", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:4,
    geometry = sf::st_sfc(
      lapply(1:4, function(i) {
        sf::st_polygon(list(matrix(c(
          i * 100, 0,
          i * 100 + 100, 0,
          i * 100 + 100, 100,
          i * 100, 100,
          i * 100, 0
        ), ncol = 2, byrow = TRUE)))
      }),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(units = test_units)

  expect_equal(nrow(result), 4)
  expect_equal(sum(is.na(result$S2)), 4)
})

test_that("indicator_social_trails rejects NULL input", {
  expect_error(
    indicator_social_trails(NULL),
    "must be an sf object"
  )
})

test_that("indicator_social_accessibility rejects NULL input", {
  expect_error(
    indicator_social_accessibility(NULL),
    "must be an sf object"
  )
})

test_that("indicator_social_proximity rejects NULL input", {
  expect_error(
    indicator_social_proximity(NULL),
    "must be an sf object"
  )
})

test_that("indicator_social_trails rejects character input", {
  expect_error(
    indicator_social_trails("not an sf object"),
    "must be an sf object"
  )
})

test_that("indicator_social_accessibility rejects character input", {
  expect_error(
    indicator_social_accessibility("not an sf object"),
    "must be an sf object"
  )
})

test_that("indicator_social_proximity rejects character input", {
  expect_error(
    indicator_social_proximity("not an sf object"),
    "must be an sf object"
  )
})

test_that("indicator_social_trails directly provided roads override layers", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  direct_roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # When roads are provided directly, layers parameter should be ignored for roads
  layers <- structure(
    list(
      rasters = list(dem = dem),
      vectors = list()  # no roads in layers
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_trails(
    units = test_units,
    roads = direct_roads,
    layers = layers
  )

  expect_false(is.na(result$S1[1]))
  expect_true(result$S1[1] >= 0)
})

test_that("indicator_social_accessibility directly provided buildings override layers", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  direct_buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  layers <- structure(
    list(
      rasters = list(dem = dem),
      vectors = list()  # no buildings in layers
    ),
    class = "nemeton_layers"
  )

  result <- indicator_social_accessibility(
    units = test_units,
    buildings = direct_buildings,
    layers = layers
  )

  expect_false(is.na(result$S2[1]))
  expect_true(result$S2[1] >= 0)
})
