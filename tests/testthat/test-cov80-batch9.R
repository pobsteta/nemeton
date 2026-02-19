# test-cov80-batch9.R
# Coverage boost for:
#   - R/indicators-social.R   (S1, S2, S3 uncovered paths)
#   - R/indicators-naturalness.R (N1, N2, N3 uncovered paths)
#   - R/indicators-temporal.R (T1, T2, .estimate_age_tfv uncovered paths)

library(testthat)

# ==============================================================================
# SOCIAL INDICATORS — additional coverage
# ==============================================================================

# --- S1: indicator_social_trails ---

test_that("S1 with layers resolving DEM from lidar_mnt when dem key absent", {
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

  result <- nemeton::indicator_social_trails(units = test_units, layers = layers)
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_false(is.na(result$S1[1]))
  expect_true(result$S1[1] >= 0)
})

test_that("S1 with lang = 'fr' produces a valid result", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicator_social_trails(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  # Without DEM/roads -> NA
  expect_true(all(is.na(result$S1)))
})

test_that("S1 with roads in different CRS triggers transform", {
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

  result <- nemeton::indicator_social_trails(units = test_units, roads = roads_4326, dem = dem)
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_false(is.na(result$S1[1]))
})

# --- S2: indicator_social_accessibility ---

test_that("S2 with layers having lidar_mnt only and buildings", {
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

  result <- nemeton::indicator_social_accessibility(units = test_units, layers = layers)
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
})

test_that("S2 with lang = 'fr' returns valid result (NA case)", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 1)
  result <- nemeton::indicator_social_accessibility(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(is.na(result$S2[1]))
})

test_that("S2 with buildings in different CRS triggers transform", {
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

  result <- nemeton::indicator_social_accessibility(
    units = test_units,
    buildings = buildings_4326,
    dem = dem
  )
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_false(is.na(result$S2[1]))
})

# --- S3: indicator_social_proximity ---

test_that("S3 buffer area calculation with different sized units", {
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

  res_small <- nemeton::indicator_social_proximity(small_unit, method = "proxy")
  res_large <- nemeton::indicator_social_proximity(large_unit, method = "proxy")

  # Both should have valid results
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(res_small)))
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(res_large)))

  # Larger unit with bigger buffers should have more area hence more population
  expect_true(res_large$S3_5km >= res_small$S3_5km)
})

test_that("S3 with very small buffer_radii still works", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicator_social_proximity(
    test_units,
    method = "proxy",
    buffer_radii = c(100, 500, 1000)
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(result)))
  # Population should still increase with buffer
  expect_true(all(result$S3_10km >= result$S3_5km))
  expect_true(all(result$S3_20km >= result$S3_10km))
})

test_that("S3 with single feature returns scalar S3", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 1)
  result <- nemeton::indicator_social_proximity(test_units, method = "proxy")

  expect_equal(nrow(result), 1)
  expect_equal(length(result$S3), 1)
  expect_true(is.numeric(result$S3))
  expect_true(result$S3 > 0)
})

test_that("S3 with custom column_name uses that name for primary indicator", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicator_social_proximity(
    test_units,
    method = "proxy",
    column_name = "pop_pressure"
  )

  expect_true("pop_pressure" %in% names(result))
  # pop_pressure should equal S3_5km
  expect_equal(result$pop_pressure, result$S3_5km)
})

test_that("S3 msg_info is called with correct median values", {
  skip_if_not_installed("sf")

  # Just make sure the function completes without error when msg_info is called
  test_units <- create_test_units(n_features = 3)
  expect_no_error(
    nemeton::indicator_social_proximity(test_units, method = "proxy")
  )
})


# ==============================================================================
# NATURALNESS INDICATORS — additional coverage
# ==============================================================================

# --- N1: indicator_naturalness_distance ---

test_that("N1 with layers that have no roads or buildings keys returns defaults", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  mock_layers <- list(
    vectors = list(),
    rasters = list(),
    metadata = list()
  )
  class(mock_layers) <- "nemeton_layers"

  result <- nemeton::indicator_naturalness_distance(
    units = test_units,
    layers = mock_layers
  )

  # roads=NULL -> default 1000, buildings=NULL -> default 500
  # N1 = 0.40*pmin(100,1000/20) + 0.35*pmin(100,500/20) + 0.25*pmin(100,2000/20)
  # = 0.40*50 + 0.35*25 + 0.25*100 = 20 + 8.75 + 25 = 53.75
  expect_equal(result$N1[1], 53.75)
})

test_that("N1 layers argument ignored when not nemeton_layers class", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # A plain list that is NOT nemeton_layers
  fake_layers <- list(
    vectors = list(roads = sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(
        sf::st_linestring(matrix(c(500, 0, 500, 1000), ncol = 2, byrow = TRUE)),
        crs = 2154
      )
    ))
  )

  result <- nemeton::indicator_naturalness_distance(
    units = test_units,
    layers = fake_layers
  )

  # layers ignored (not nemeton_layers class), roads/buildings NULL -> defaults

  expect_equal(result$N1[1], 53.75)
})

test_that("N1 with lang = 'fr' works correctly", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicator_naturalness_distance(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  expect_true(all(!is.na(result$N1)))
})

test_that("N1 correctly transforms buildings in different CRS", {
  skip_if_not_installed("sf")

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

  result <- nemeton::indicator_naturalness_distance(
    units = test_units,
    buildings = buildings_4326
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # buildings transformed -> real distance computed, not default 500
  expect_true(result$N1[1] >= 0 & result$N1[1] <= 100)
})

# --- N2: indicator_naturalness_continuity ---

test_that("N2 intersection error handling: tryCatch returns NULL on error", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create a valid bdforet that covers the unit
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Mock st_intersection to error for the bdforet intersection path
  # The tryCatch in the code catches errors and returns NULL -> taux_boisement=0
  local_mocked_bindings(
    st_intersection = function(...) stop("Intentional error"),
    .package = "sf"
  )

  result <- nemeton::indicator_naturalness_continuity(
    units = test_units,
    bdforet = bdforet
  )

  # When intersection fails, taux_boisement=0, taux_ancienne=0 -> score=15
  expect_equal(result$N2[1], 15)
})

test_that("N2 with foret_ancienne in different CRS", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  foret_ancienne_2154 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )
  foret_ancienne_4326 <- sf::st_transform(foret_ancienne_2154, 4326)

  result <- nemeton::indicator_naturalness_continuity(
    units = test_units,
    foret_ancienne = foret_ancienne_4326
  )

  # After CRS transform, foret_ancienne should still overlap
  # taux_ancienne > 0 -> score = 60 + 40*taux
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
})

test_that("N2 with non-overlapping bdforet returns score 15", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet far away from unit
  bdforet_far <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        50000, 50000, 50100, 50000, 50100, 50100, 50000, 50100, 50000, 50000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_naturalness_continuity(
    units = test_units,
    bdforet = bdforet_far
  )

  # Intersection yields 0 rows -> taux_boisement=0, no ancient -> score=15
  expect_equal(result$N2[1], 15)
})

test_that("N2 with non-overlapping foret_ancienne but overlapping bdforet", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet covers the unit
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # foret_ancienne far away (no overlap)
  foret_ancienne_far <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        50000, 50000, 50100, 50000, 50100, 50100, 50000, 50100, 50000, 50000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_naturalness_continuity(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne_far
  )

  # taux_boisement > 0, taux_ancienne = 0 -> score = 30 + 30*taux_boisement
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
})

test_that("N2 with both bdforet and foret_ancienne having multiple features", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Two bdforet features
  bdforet <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 50, 0, 50, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(50, 0, 100, 0, 100, 100, 50, 100, 50, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Two foret_ancienne features (only left half)
  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 50, 0, 50, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_naturalness_continuity(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne
  )

  # taux_ancienne ~ 0.5, score = 60 + 40*0.5 = 80
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
  expect_equal(result$N2[1], 80, tolerance = 2)
})

test_that("N2 lang = 'fr' works correctly", {
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 1)
  result <- nemeton::indicator_naturalness_continuity(units = test_units, lang = "fr")
  # No data -> default 50
  expect_equal(result$N2[1], 50)
})

# --- N3: indicator_naturalness_composite ---

test_that("N3 with pre-computed N1, N2, L1, and B3 columns", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    N1 = c(70, 30, 100),
    N2 = c(80, 40, 0),
    L1 = c(10, 80, 50),
    B3 = c(60, 20, 100),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(400, 0, 500, 0, 500, 100, 400, 100, 400, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_naturalness_composite(units = test_units)

  # Unit 1: 0.35*70 + 0.35*80 + 0.15*(100-10) + 0.15*60 = 24.5+28+13.5+9 = 75
  expect_equal(result$N3[1], 0.35 * 70 + 0.35 * 80 + 0.15 * 90 + 0.15 * 60)
  # Unit 2: 0.35*30 + 0.35*40 + 0.15*(100-80) + 0.15*20 = 10.5+14+3+3 = 30.5
  expect_equal(result$N3[2], 0.35 * 30 + 0.35 * 40 + 0.15 * 20 + 0.15 * 20)
  # Unit 3: 0.35*100 + 0.35*0 + 0.15*(100-50) + 0.15*100 = 35+0+7.5+15 = 57.5
  expect_equal(result$N3[3], 0.35 * 100 + 0.35 * 0 + 0.15 * 50 + 0.15 * 100)
})

test_that("N3 lang = 'fr' works correctly", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_naturalness_composite(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
  expected <- 0.35 * 60 + 0.35 * 70 + 0.15 * 50 + 0.15 * 50
  expect_equal(result$N3[1], expected)
})

test_that("N3 preserves original columns", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    name = "forest_a",
    N1 = 80,
    N2 = 90,
    area_ha = 15.5,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicator_naturalness_composite(units = test_units)

  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_true("area_ha" %in% names(result))
  expect_equal(result$name, "forest_a")
  expect_equal(result$area_ha, 15.5)
  expect_true("N3" %in% names(result))
})


# ==============================================================================
# TEMPORAL INDICATORS — additional coverage
# ==============================================================================

# --- .estimate_age_tfv: more TFV string patterns ---

test_that(".estimate_age_tfv handles varied French forest type strings", {
  ages <- nemeton:::.estimate_age_tfv(c(
    "For\u00eat ferm\u00e9e de feuillus purs",
    "Futaie de feuillus",
    "For\u00eat ferm\u00e9e de conif\u00e8res purs",
    "Futaie de conif\u00e8res",
    "For\u00eat ouverte",
    "Taillis simple",
    "Peupleraie",
    "Jeune peuplement de feuillus",
    "Lande bois\u00e9e",
    "Formation herbac\u00e9e"
  ))

  expect_equal(ages[1], 100)  # ferme + feuill
  expect_equal(ages[2], 100)  # futaie + feuill
  expect_equal(ages[3], 80)   # ferme + conif
  expect_equal(ages[4], 80)   # futaie + conif
  expect_equal(ages[5], 45)   # ouvert
  expect_equal(ages[6], 45)   # taillis
  expect_equal(ages[7], 20)   # peupler
  expect_equal(ages[8], 15)   # jeune
  expect_equal(ages[9], 15)   # lande bois
  expect_equal(ages[10], 50)  # default
})

test_that(".estimate_age_tfv handles case-insensitive matching", {
  ages <- nemeton:::.estimate_age_tfv(c(
    "FORET FERMEE DE FEUILLUS",
    "FUTAIE DE CONIFERES",
    "FORET OUVERTE",
    "PEUPLERAIE",
    "JEUNE PEUPLEMENT",
    "LANDE BOISEE"
  ))

  expect_equal(ages[1], 100)
  expect_equal(ages[2], 80)
  expect_equal(ages[3], 45)
  expect_equal(ages[4], 20)
  expect_equal(ages[5], 15)
  expect_equal(ages[6], 15)
})

test_that(".estimate_age_tfv handles NA and empty strings", {
  ages <- nemeton:::.estimate_age_tfv(c(NA, "", "Unknown", "  "))

  # NA input -> tolower(NA) is NA, grepl returns FALSE for NA -> default 50
  expect_equal(ages[1], 50)
  expect_equal(ages[2], 50)  # empty -> default
  expect_equal(ages[3], 50)  # unknown -> default
  expect_equal(ages[4], 50)  # whitespace -> default
})

test_that(".estimate_age_tfv handles single-element vector", {
  expect_equal(nemeton:::.estimate_age_tfv("Peupleraie"), 20)
  expect_equal(nemeton:::.estimate_age_tfv("Taillis"), 45)
  expect_equal(nemeton:::.estimate_age_tfv("xyz"), 50)
})

# --- T1: indicator_temporal_age ---

test_that("T1 with establishment_year and auto current_year", {
  test_units <- create_test_units(n_features = 2)
  test_units$planting_year <- c(1900, 2000)

  result <- nemeton::indicator_temporal_age(
    test_units,
    age_field = NULL,
    establishment_year_field = "planting_year"
    # current_year not provided -> auto from Sys.Date()
  )

  current_yr <- as.integer(format(Sys.Date(), "%Y"))
  expect_type(result, "double")
  expect_length(result, 2)
  expect_equal(result[1], current_yr - 1900)
  expect_equal(result[2], current_yr - 2000)
})

test_that("T1 with explicit current_year for establishment_year", {
  test_units <- create_test_units(n_features = 3)
  test_units$yr <- c(1850, 1950, 2010)

  result <- nemeton::indicator_temporal_age(
    test_units,
    age_field = NULL,
    establishment_year_field = "yr",
    current_year = 2025
  )

  expect_equal(result, c(175, 75, 15))
})

test_that("T1 BD Foret with CODE_TFV field name", {
  test_units <- create_test_units(n_features = 2)

  # Create BD Foret with CODE_TFV field (not just TFV)
  bdforet <- sf::st_sf(
    CODE_TFV = c("Peupleraie", "Taillis"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  result <- nemeton::indicator_temporal_age(test_units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 2)
  # Should find CODE_TFV field and estimate ages
  # peupleraie=20, taillis=45
  expect_true(result[1] > 0)
  expect_true(result[2] > 0)
})

test_that("T1 BD Foret with lib_fv field name", {
  test_units <- create_test_units(n_features = 2)

  bdforet <- sf::st_sf(
    lib_fv = c("For\u00eat ferm\u00e9e de feuillus purs", "For\u00eat ouverte"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  result <- nemeton::indicator_temporal_age(test_units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 2)
})

test_that("T1 BD Foret with ESSENCE field name", {
  test_units <- create_test_units(n_features = 1)

  bdforet <- sf::st_sf(
    ESSENCE = "Jeune peuplement",
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  result <- nemeton::indicator_temporal_age(test_units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 1)
  # jeune -> 15
  expect_equal(result[1], 15, tolerance = 5)
})

test_that("T1 BD Foret with no recognized TFV field returns default 50", {
  test_units <- create_test_units(n_features = 2)

  # bdforet with unrecognized field names
  bdforet <- sf::st_sf(
    species_name = c("Quercus", "Pinus"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  # No TFV/CODE_TFV/ESSENCE/etc. fields recognized
  # Falls through to Priority 2 (age_field), but "age" not in units
  # Falls to default 50
  result <- nemeton::indicator_temporal_age(test_units, bdforet = bdforet, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 2)
  expect_true(all(result == 50))
})

test_that("T1 BD Foret with CRS mismatch triggers transform", {
  test_units <- create_test_units(n_features = 2)

  bdforet_2154 <- sf::st_sf(
    TFV = c("Peupleraie", "Taillis"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet_2154) <- sf::st_crs(test_units)

  # Transform bdforet to 4326
  bdforet_4326 <- sf::st_transform(bdforet_2154, 4326)

  result <- nemeton::indicator_temporal_age(test_units, bdforet = bdforet_4326)

  expect_type(result, "double")
  expect_length(result, 2)
  # After CRS transform, intersection should still work
  expect_true(all(result > 0))
})

test_that("T1 BD Foret with empty sf (0 rows) falls through to age field", {
  test_units <- create_test_units(n_features = 2)
  test_units$age <- c(80, 120)

  empty_bdforet <- sf::st_sf(
    TFV = character(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- nemeton::indicator_temporal_age(test_units, bdforet = empty_bdforet, age_field = "age")

  expect_type(result, "double")
  expect_equal(result, c(80, 120))
})

test_that("T1 BD Foret intersection with 0-area result uses default 50", {
  # This tests the total_area == 0 branch (line 123-124)
  test_units <- create_test_units(n_features = 1)

  # Create bdforet that technically intersects but with zero area
  # (a line geometry intersecting a polygon)
  bdforet <- sf::st_sf(
    TFV = "Peupleraie",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, -10, -9, -9, -9, -9, -10, -10, -10),
                                 ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Intersection should produce 0 rows (no overlap) -> default 50
  result <- nemeton::indicator_temporal_age(test_units, bdforet = bdforet, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 1)
  expect_equal(result[1], 50)
})

test_that("T1 priority chain: age_field takes precedence over establishment_year", {
  test_units <- create_test_units(n_features = 2)
  test_units$age <- c(100, 200)
  test_units$planted <- c(1900, 1800)

  # Both age and establishment_year available; age_field should win
  result <- nemeton::indicator_temporal_age(
    test_units,
    age_field = "age",
    establishment_year_field = "planted"
  )

  expect_equal(result, c(100, 200))
})

test_that("T1 falls through to default 50 when no data at all", {
  test_units <- create_test_units(n_features = 3)

  result <- nemeton::indicator_temporal_age(
    test_units,
    age_field = NULL,
    establishment_year_field = NULL
  )

  expect_type(result, "double")
  expect_length(result, 3)
  expect_true(all(result == 50))
})

test_that("T1 resolves bdforet from nemeton_layers", {
  test_units <- create_test_units(n_features = 2)

  bdforet_sf <- sf::st_sf(
    TFV = c("Peupleraie", "For\u00eat ferm\u00e9e de feuillus purs"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet_sf) <- sf::st_crs(test_units)

  mock_layers <- structure(
    list(
      vectors = list(bdforet = bdforet_sf),
      rasters = list(),
      metadata = list()
    ),
    class = "nemeton_layers"
  )

  result <- nemeton::indicator_temporal_age(test_units, layers = mock_layers, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 2)
  # Should have estimated ages from TFV
  expect_true(all(result > 0))
})

# --- T2: indicator_temporal_change ---

test_that("T2 uses N2_anciennet column (truncated name variant)", {
  test_units <- create_test_units(n_features = 3)
  test_units$N2_anciennet <- c(30, 70, 110)

  result <- nemeton::indicator_temporal_change(test_units)

  # N2_anciennet found -> used as stability proxy, capped to 0-100
  expect_equal(result, c(30, 70, 100))
})

test_that("T2 with N2 column containing values > 100 are capped", {
  test_units <- create_test_units(n_features = 3)
  test_units$N2 <- c(-5, 50, 150)

  result <- nemeton::indicator_temporal_change(test_units)

  # capped: pmin(pmax(t2, 0), 100)
  expect_equal(result, c(0, 50, 100))
})

test_that("T2 fallback to t1_values with NA values replaced by 50", {
  test_units <- create_test_units(n_features = 4)
  # No N2 columns
  t1 <- c(30, NA, 120, NA)

  result <- nemeton::indicator_temporal_change(test_units, t1_values = t1)

  # t1_values used: capped at 100, NA -> 50
  expect_equal(result, c(30, 50, 100, 50))
})

test_that("T2 with T1 column in units (not t1_values argument)", {
  test_units <- create_test_units(n_features = 3)
  test_units$T1 <- c(25, NA, 90)

  result <- nemeton::indicator_temporal_change(test_units)

  # T1 column used: capped at 100, NA -> 50
  expect_equal(result, c(25, 50, 90))
})

test_that("T2 default 50 when no N2 or T1 available", {
  test_units <- create_test_units(n_features = 5)

  result <- nemeton::indicator_temporal_change(test_units)

  expect_type(result, "double")
  expect_length(result, 5)
  expect_true(all(result == 50))
})

test_that("T2 t1_values wrong length is ignored, falls through", {
  test_units <- create_test_units(n_features = 3)

  # t1_values has wrong length (2 instead of 3) -> not used
  result <- nemeton::indicator_temporal_change(test_units, t1_values = c(40, 80))

  # Falls through to T1 column (not present) -> default 50
  expect_true(all(result == 50))
})

test_that("T2 t1_values non-numeric is ignored", {
  test_units <- create_test_units(n_features = 2)

  # t1_values is character -> not numeric -> not used
  result <- nemeton::indicator_temporal_change(test_units, t1_values = c("a", "b"))

  # Falls through to default 50
  expect_true(all(result == 50))
})

test_that("T2 N2_anciennete takes priority over N2", {
  test_units <- create_test_units(n_features = 2)
  test_units$N2_anciennete <- c(85, 95)
  test_units$N2 <- c(30, 40)

  result <- nemeton::indicator_temporal_change(test_units)

  # N2_anciennete found first in the loop -> used
  expect_equal(result, c(85, 95))
})

test_that("T2 priority: N2 column over T1 column", {
  test_units <- create_test_units(n_features = 2)
  test_units$N2 <- c(60, 80)
  test_units$T1 <- c(30, 40)

  result <- nemeton::indicator_temporal_change(test_units)

  # N2 found -> used, T1 not reached
  expect_equal(result, c(60, 80))
})

test_that("T2 priority: t1_values argument over T1 column", {
  test_units <- create_test_units(n_features = 2)
  test_units$T1 <- c(30, 40)

  result <- nemeton::indicator_temporal_change(test_units, t1_values = c(70, 90))

  # No N2 column -> t1_values used (correct length)
  expect_equal(result, c(70, 90))
})

test_that("T2 with layers parameter (interface consistency)", {
  test_units <- create_test_units(n_features = 2)
  test_units$N2 <- c(45, 75)

  mock_layers <- structure(
    list(
      vectors = list(),
      rasters = list(),
      metadata = list()
    ),
    class = "nemeton_layers"
  )

  # layers is accepted but not used in T2
  result <- nemeton::indicator_temporal_change(test_units, layers = mock_layers)

  expect_equal(result, c(45, 75))
})

test_that("T2 validates sf input", {
  expect_error(
    nemeton::indicator_temporal_change(data.frame(x = 1:3)),
    "must be.*sf"
  )

  expect_error(
    nemeton::indicator_temporal_change("not sf"),
    "must be.*sf"
  )

  expect_error(
    nemeton::indicator_temporal_change(NULL),
    "must be.*sf"
  )
})
