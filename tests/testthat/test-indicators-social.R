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

# ==============================================================================
# S3: Population Proximity (unchanged)
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

  # S1 and S2 return NA without DEM/roads/buildings — that's expected
  result <- test_units |>
    indicator_social_trails() |>
    indicator_social_accessibility() |>
    indicator_social_proximity(method = "proxy")

  # Check all indicators present
  expect_true(all(c("S1", "S2", "S3") %in% names(result)))
})
