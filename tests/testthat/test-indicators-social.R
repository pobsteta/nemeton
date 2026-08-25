# Test Suite for Social & Recreational Indicators (Family S)
# S1: Distance to roads, S2: Distance to buildings, S3: Population proximity

# ==============================================================================
# S1: Distance to Roads
# ==============================================================================

test_that("indicateur_s1_routes (S1) works with DEM + roads", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(
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

test_that("indicateur_s1_routes (S1) returns NA without DEM", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s1_routes(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_true(is.na(result$S1[1]))
})

test_that("indicateur_s1_routes (S1) returns NA without roads", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units, dem = dem)

  expect_true(is.na(result$S1[1]))
})

test_that("indicateur_s1_routes (S1) returns NA with empty roads (0 rows)", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units, roads = empty_roads, dem = dem)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_true(is.na(result$S1[1]))
})

test_that("indicateur_s1_routes validates input types", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s1_routes(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_s1_routes uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s1_routes(
    units = test_units,
    column_name = "road_distance"
  )

  expect_true("road_distance" %in% names(result))
  expect_false("S1" %in% names(result))
})

test_that("indicateur_s1_routes resolves roads and DEM from layers", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  # Should have a real numeric value (not NA), since layers resolved
  expect_false(is.na(result$S1[1]))
  expect_true(result$S1[1] >= 0)
})

test_that("indicateur_s1_routes resolves DEM from lidar_mnt fallback in layers", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_false(is.na(result$S1[1]))
})

test_that("indicateur_s1_routes returns NA when layers has no roads", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units, layers = layers)

  expect_true(is.na(result$S1[1]))
})

test_that("indicateur_s1_routes preserves original columns", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units)

  # Original columns should be preserved
  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, c("unit_a", "unit_b"))
  # And new column added
  expect_true("S1" %in% names(result))
  # Same number of rows

  expect_equal(nrow(result), 2)
})

test_that("indicateur_s1_routes uses helper test fixtures", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # Use the helper functions from helper-fixtures.R
  test_units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "constant")
  roads <- create_test_vector(type = "lines")

  result <- indicateur_s1_routes(
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

test_that("indicateur_s2_bati (S2) works with DEM + buildings", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(
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

test_that("indicateur_s2_bati (S2) returns NA without DEM", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s2_bati(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(is.na(result$S2[1]))
})

test_that("indicateur_s2_bati (S2) returns NA without buildings", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(units = test_units, dem = dem)

  expect_true(is.na(result$S2[1]))
})

test_that("indicateur_s2_bati (S2) returns NA with empty buildings (0 rows)", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(
    units = test_units,
    buildings = empty_buildings,
    dem = dem
  )

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(is.na(result$S2[1]))
})

test_that("indicateur_s2_bati validates input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s2_bati(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_s2_bati uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s2_bati(
    units = test_units,
    column_name = "building_distance"
  )

  expect_true("building_distance" %in% names(result))
  expect_false("S2" %in% names(result))
})

test_that("indicateur_s2_bati resolves buildings and DEM from layers", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
  expect_true(result$S2[1] >= 0)
})

test_that("indicateur_s2_bati resolves DEM from lidar_mnt fallback", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(units = test_units, layers = layers)

  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
})

test_that("indicateur_s2_bati returns NA when layers has no buildings", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(units = test_units, layers = layers)

  expect_true(is.na(result$S2[1]))
})

test_that("indicateur_s2_bati preserves original columns", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(units = test_units)

  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, c("building_a", "building_b"))
  expect_true("S2" %in% names(result))
  expect_equal(nrow(result), 2)
})

# ==============================================================================
# S3: Population Proximity
# ==============================================================================

test_that("indicateur_s3_population (S3) calculates population buffers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s3_population(
    units = test_units,
    buffer_radii = c(5000, 10000, 20000)
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(result)))
  expect_type(result$S3, "double")
  expect_type(result$S3_5km, "double")
  expect_type(result$S3_10km, "double")
  expect_type(result$S3_20km, "double")

  # v0.187.0 : sans grille, les trois rayons valent NA. La croissance de la
  # population avec le rayon reste verifiee — sur une vraie grille — dans
  # `test-zero-ou-na.R`, ou elle a un sens.
  expect_true(all(is.na(result$S3_5km)))
  expect_true(all(is.na(result$S3_10km)))
  expect_true(all(is.na(result$S3_20km)))
})

test_that("indicateur_s3_population validates input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s3_population(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_s3_population uses buffer_radii parameter", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Use properly sized units with real coordinates
  test_units <- create_test_units(n_features = 1)

  result <- indicateur_s3_population(
    test_units,
    buffer_radii = c(5000, 10000, 20000)
  )

  expect_true("S3_5km" %in% names(result))
  expect_true("S3_10km" %in% names(result))
  expect_true("S3_20km" %in% names(result))
  expect_true("S3" %in% names(result))
})

test_that("indicateur_s3_population uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s3_population(
    test_units,
    column_name = "pop_score"
  )

  expect_true("pop_score" %in% names(result))
})

test_that("indicateur_s3_population S3 equals S3_5km (primary = first buffer)", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s3_population(
    test_units,
    buffer_radii = c(5000, 10000, 20000)
  )

  # Primary indicator S3 should equal S3_5km
  expect_equal(result$S3, result$S3_5km)
})

test_that("indicateur_s3_population rejects invalid method", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  expect_error(
    indicateur_s3_population(test_units, method = "invalid_method"),
    "arg"
  )
})

test_that("indicateur_s3_population produces positive population values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_s3_population(
    test_units,
    buffer_radii = c(5000, 10000, 20000)
  )

  # « area * 100 density > 0 » : le commentaire disait lui-meme que la valeur
  # venait d'une surface, pas d'une population. Sans grille, c'est NA.
  expect_true(all(is.na(result$S3_5km)))
  expect_true(all(is.na(result$S3_10km)))
  expect_true(all(is.na(result$S3_20km)))
  expect_true(all(is.na(result$S3)))
})

test_that("indicateur_s3_population preserves original columns", {
  skip_if_not_installed("terra")
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

  result <- suppressMessages(indicateur_s3_population(test_units))

  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_equal(result$name, c("forest_a", "forest_b"))
  expect_equal(nrow(result), 2)
})

test_that("indicateur_s3_population with custom buffer_radii", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Use different buffer radii
  result <- indicateur_s3_population(
    test_units,
    buffer_radii = c(1000, 2000, 5000)
  )

  # S3_5km, S3_10km, S3_20km columns are always created with those names
  # (hardcoded in the function), but the actual buffers use the provided radii
  expect_true("S3_5km" %in% names(result))
  expect_true("S3_10km" %in% names(result))
  expect_true("S3_20km" %in% names(result))

  # Sans grille : NA. La monotonie est verifiee sur une vraie grille ailleurs.
  expect_true(is.na(result$S3_5km))
  expect_true(is.na(result$S3_10km))
  expect_true(is.na(result$S3_20km))
})

test_that("indicateur_s3_population accepts method 'insee'", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # 'insee' is a valid method per match.arg; function runs the same proxy logic
  result <- indicateur_s3_population(test_units, method = "insee")

  expect_s3_class(result, "sf")
  expect_true("S3" %in% names(result))
})

test_that("indicateur_s3_population accepts method 'local'", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # 'local' is a valid method per match.arg
  result <- indicateur_s3_population(test_units, method = "local")

  expect_s3_class(result, "sf")
  expect_true("S3" %in% names(result))
})

test_that("indicateur_s3_population with multiple units computes per-unit values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 5)

  result <- indicateur_s3_population(
    test_units,
    buffer_radii = c(5000, 10000, 20000)
  )

  # Should have one value per unit
  expect_equal(nrow(result), 5)
  expect_equal(length(result$S3), 5)
  expect_equal(length(result$S3_5km), 5)
  expect_equal(length(result$S3_10km), 5)
  expect_equal(length(result$S3_20km), 5)

  # v0.187.0 : sans grille de population, NA. Le test garde son objet — la
  # fonction traite bien un lot de 5 et rend les quatre colonnes.
  expect_true(all(is.na(result$S3)))
  expect_true(all(is.na(result$S3_5km)))
})

# ==============================================================================
# Integration
# ==============================================================================

test_that("Social indicators integrate with family system", {
  skip_if_not_installed("terra")
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
    indicateur_s1_routes() |>
    indicateur_s2_bati() |>
    indicateur_s3_population()

  # Check all indicators present
  expect_true(all(c("S1", "S2", "S3") %in% names(result)))
})

test_that("Social indicators can be chained on units with existing columns", {
  skip_if_not_installed("terra")
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
    indicateur_s1_routes() |>
    indicateur_s2_bati() |>
    indicateur_s3_population()

  # Original columns preserved
  expect_true("C1" %in% names(result))
  expect_true("B1" %in% names(result))
  expect_equal(result$C1, 50.0)
  expect_equal(result$B1, 0.8)
  # Social indicators added
  expect_true(all(c("S1", "S2", "S3") %in% names(result)))
})

test_that("indicateur_s1_routes returns correct number of NA for multi-unit input without DEM", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(units = test_units)

  expect_equal(nrow(result), 5)
  expect_equal(sum(is.na(result$S1)), 5)
})

test_that("indicateur_s2_bati returns correct number of NA for multi-unit input without DEM", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(units = test_units)

  expect_equal(nrow(result), 4)
  expect_equal(sum(is.na(result$S2)), 4)
})

test_that("indicateur_s1_routes rejects NULL input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s1_routes(NULL),
    "must be an sf object"
  )
})

test_that("indicateur_s2_bati rejects NULL input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s2_bati(NULL),
    "must be an sf object"
  )
})

test_that("indicateur_s3_population rejects NULL input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s3_population(NULL),
    "must be an sf object"
  )
})

test_that("indicateur_s1_routes rejects character input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s1_routes("not an sf object"),
    "must be an sf object"
  )
})

test_that("indicateur_s2_bati rejects character input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s2_bati("not an sf object"),
    "must be an sf object"
  )
})

test_that("indicateur_s3_population rejects character input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_s3_population("not an sf object"),
    "must be an sf object"
  )
})

test_that("indicateur_s1_routes directly provided roads override layers", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s1_routes(
    units = test_units,
    roads = direct_roads,
    layers = layers
  )

  expect_false(is.na(result$S1[1]))
  expect_true(result$S1[1] >= 0)
})

test_that("indicateur_s2_bati directly provided buildings override layers", {
  skip_if_not_installed("terra")
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

  result <- indicateur_s2_bati(
    units = test_units,
    buildings = direct_buildings,
    layers = layers
  )

  expect_false(is.na(result$S2[1]))
  expect_true(result$S2[1] >= 0)
})

# ==============================================================================
# (migrated from test-cov80-batch9.R)
# ==============================================================================

# --- S1: indicateur_s1_routes ---

test_that("S1 with layers resolving DEM from lidar_mnt when dem key absent", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  # DEM raster

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

  # layers has lidar_mnt but NOT dem
  layers <- structure(
    list(
      rasters = list(lidar_mnt = dem),
      vectors = list(roads = roads)
    ),
    class = "nemeton_layers"
  )

  result <- nemeton::indicateur_s1_routes(units = test_units, layers = layers)
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_false(is.na(result$S1[1]))
  expect_true(result$S1[1] >= 0)
})

test_that("S1 with lang = 'fr' produces a valid result", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_s1_routes(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  # Without DEM/roads -> NA
  expect_true(all(is.na(result$S1)))
})

test_that("S1 with roads in different CRS triggers transform", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  # Roads in WGS84 (CRS 4326)
  roads_2154 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )
  roads_4326 <- sf::st_transform(roads_2154, 4326)

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

  result <- nemeton::indicateur_s1_routes(units = test_units, roads = roads_4326, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_false(is.na(result$S1[1]))
})

# --- S2: indicateur_s2_bati ---

test_that("S2 with layers having lidar_mnt only and buildings", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

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

  # layers with lidar_mnt instead of dem; buildings present
  layers <- structure(
    list(
      rasters = list(lidar_mnt = dem),
      vectors = list(buildings = buildings)
    ),
    class = "nemeton_layers"
  )

  result <- nemeton::indicateur_s2_bati(units = test_units, layers = layers)
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
})

test_that("S2 with lang = 'fr' returns valid result (NA case)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 1)
  result <- nemeton::indicateur_s2_bati(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(is.na(result$S2[1]))
})

test_that("S2 with buildings in different CRS triggers transform", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  dem <- terra::rast(
    xmin = 600000, xmax = 602500, ymin = 6600000, ymax = 6602500,
    resolution = 25, crs = "EPSG:2154"
  )
  terra::values(dem) <- 100

  buildings_2154 <- sf::st_sf(
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
  buildings_4326 <- sf::st_transform(buildings_2154, 4326)

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

  result <- nemeton::indicateur_s2_bati(
    units = test_units,
    buildings = buildings_4326,
    dem = dem
  )
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
})

# --- S3: indicateur_s3_population ---

test_that("S3 buffer area calculation with different sized units", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Small unit: 10m x 10m
  small_unit <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 10, 0, 10, 10, 0, 10, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Large unit: 5000m x 5000m
  large_unit <- sf::st_sf(
    id = 2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 5000, 0, 5000, 5000, 0, 5000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  res_small <- suppressMessages(nemeton::indicateur_s3_population(small_unit))
  res_large <- suppressMessages(nemeton::indicateur_s3_population(large_unit))

  # Both should have valid results
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(res_small)))
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(res_large)))

  # « more area hence more population » : le raisonnement du chemin fabrique,
  # ou la population etait une surface. Sans grille, les deux valent NA.
  expect_true(is.na(res_large$S3_5km))
  expect_true(is.na(res_small$S3_5km))
})

test_that("S3 with very small buffer_radii still works", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_s3_population(
    test_units,
    buffer_radii = c(100, 500, 1000)
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(result)))
  # Sans grille : NA, quel que soit le rayon. La monotonie est verifiee sur une
  # vraie grille dans `test-zero-ou-na.R`.
  expect_true(all(is.na(result$S3_10km)))
  expect_true(all(is.na(result$S3_20km)))
})

test_that("S3 with single feature returns scalar S3", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 1)
  result <- suppressMessages(nemeton::indicateur_s3_population(test_units))

  # L'objet du test est la FORME du retour sur une unite unique, pas la valeur.
  expect_equal(nrow(result), 1)
  expect_equal(length(result$S3), 1)
  expect_true(is.numeric(result$S3))   # NA_real_ reste numerique
  expect_true(is.na(result$S3))
})

test_that("S3 with custom column_name uses that name for primary indicator", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_s3_population(
    test_units,
    column_name = "pop_pressure"
  )

  expect_true("pop_pressure" %in% names(result))
  # pop_pressure should equal S3_5km
  expect_equal(result$pop_pressure, result$S3_5km)
})

test_that("S3 msg_info is called with correct median values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Just make sure the function completes without error when msg_info is called
  test_units <- create_test_units(n_features = 3)
  expect_no_error(
    suppressMessages(nemeton::indicateur_s3_population(test_units))
  )
})

# ==============================================================================
# CRS LiDAR HD dégénéré : S1/S2 doivent normaliser le DEM (régression v0.138.2)
# ==============================================================================

test_that("S1/S2 recover a degenerate authorityless DEM CRS (no all-NA)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")

  # DEM Lambert-93 « dégénéré » : nom = EPSG:2154 mais sans autorité rattachée,
  # comme les GeoTIFF LiDAR HD IGN (cf. .normalize_crs, indicators-families.R).
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
  dem <- terra::rast(xmin = 700000, xmax = 702500,
                     ymin = 6600000, ymax = 6602500, resolution = 25)
  terra::crs(dem) <- wkt
  skip_if(!is.na(terra::crs(dem, describe = TRUE)$code),
          "platform PROJ already resolved the degenerate CRS")
  terra::values(dem) <- 100

  roads <- sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_linestring(matrix(c(701000, 6600000, 701000, 6602500),
                             ncol = 2, byrow = TRUE)), crs = 2154))
  buildings <- sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_polygon(list(matrix(c(
      701000, 6601000, 701100, 6601000, 701100, 6601100,
      701000, 6601100, 701000, 6601000), ncol = 2, byrow = TRUE))), crs = 2154))
  units <- sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_polygon(list(matrix(c(
      700900, 6601000, 701100, 6601000, 701100, 6601200,
      700900, 6601200, 700900, 6601000), ncol = 2, byrow = TRUE))), crs = 2154))

  # Sans .normalize_crs, terra::crs(dem) est irrésolu -> st_transform/rasterize
  # échouent -> S1/S2 tombaient en NA. Avec le fix : valeur numérique finie.
  s1 <- indicateur_s1_routes(units = units, roads = roads, dem = dem)
  expect_false(all(is.na(s1$S1)))

  s2 <- indicateur_s2_bati(units = units, buildings = buildings, dem = dem)
  expect_false(all(is.na(s2$S2)))
})
