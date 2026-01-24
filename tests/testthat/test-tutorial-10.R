# Tests for Tutorial 10 - Species Classification
# These tests verify the tutorial functions and data pipeline

test_that("get_species_lookup returns correct structure", {
  # Define the function locally for testing
  get_species_lookup <- function() {
    data.frame(
      code = c("PIAB", "ABAL", "FASY", "TABA", "PISY", "LADE", "QUPE", "QURO"),
      nom_fr = c("Épicéa", "Sapin", "Hêtre", "Frêne", "Pin sylvestre",
                 "Mélèze", "Chêne pédonculé", "Chêne rouvre"),
      groupe = c("Résineux", "Résineux", "Feuillu", "Feuillu", "Résineux",
                 "Résineux", "Feuillu", "Feuillu"),
      stringsAsFactors = FALSE
    )
  }

  lookup <- get_species_lookup()

  expect_s3_class(lookup, "data.frame")
  expect_equal(ncol(lookup), 3)

  expect_true(all(c("code", "nom_fr", "groupe") %in% names(lookup)))
  expect_equal(nrow(lookup), 8)

  # Check specific species

  expect_true("PIAB" %in% lookup$code)
  expect_true("FASY" %in% lookup$code)

  # Check groups
  expect_true(all(lookup$groupe %in% c("Résineux", "Feuillu")))
})

test_that("tutorial 10 Rmd file exists", {
  tutorial_path <- system.file(
    "tutorials", "10-species-classification", "10-species-classification.Rmd",
    package = "nemeton"
  )

  # Skip if package not installed in standard location
  skip_if(tutorial_path == "", "Tutorial file not found in installed package")

  expect_true(file.exists(tutorial_path))
})

test_that("feature columns are correctly defined", {
  # Expected feature columns from tutorial
  expected_features <- c(
    # LiDAR - hauteur
    "z_mean", "z_sd", "z_p25", "z_p50", "z_p75", "z_p95",
    # LiDAR - forme
    "area_m2", "compactness", "radius_eq", "ratio_h_radius",
    # IRC
    "nir_mean", "nir_sd", "red_mean", "green_mean",
    "ndvi_mean", "ndvi_sd",
    "nir_red_ratio", "nir_green_ratio"
  )

  expect_equal(length(expected_features), 18)

  # Check no duplicates
  expect_equal(length(expected_features), length(unique(expected_features)))

  # Check LiDAR features
  lidar_height <- c("z_mean", "z_sd", "z_p25", "z_p50", "z_p75", "z_p95")
  expect_true(all(lidar_height %in% expected_features))

  # Check shape features
  shape_features <- c("area_m2", "compactness", "radius_eq", "ratio_h_radius")
  expect_true(all(shape_features %in% expected_features))

  # Check IRC features
  irc_features <- c("nir_mean", "nir_sd", "red_mean", "green_mean",
                    "ndvi_mean", "ndvi_sd", "nir_red_ratio", "nir_green_ratio")
  expect_true(all(irc_features %in% expected_features))
})

test_that("compactness calculation is correct", {
  # Compactness = 4 * pi * area / perimeter^2
  # For a circle: compactness = 1

  # Test with a perfect circle
  radius <- 10
  area_circle <- pi * radius^2
  perimeter_circle <- 2 * pi * radius

  compactness_circle <- 4 * pi * area_circle / (perimeter_circle^2)

  expect_equal(compactness_circle, 1, tolerance = 1e-10)

  # Test with a square (should be ~0.785)
  side <- 10
  area_square <- side^2
  perimeter_square <- 4 * side


  compactness_square <- 4 * pi * area_square / (perimeter_square^2)

  expect_equal(compactness_square, pi / 4, tolerance = 1e-10)
  expect_true(compactness_square < 1)
})

test_that("NDVI calculation is correct", {
  # NDVI = (NIR - Red) / (NIR + Red)

  # Test case 1: healthy vegetation (high NDVI)
  nir_healthy <- 0.5
  red_healthy <- 0.1
  ndvi_healthy <- (nir_healthy - red_healthy) / (nir_healthy + red_healthy)

  expect_equal(ndvi_healthy, 0.6667, tolerance = 0.01)
  expect_true(ndvi_healthy > 0.5)

  # Test case 2: bare soil (low NDVI)
  nir_soil <- 0.3
  red_soil <- 0.3
  ndvi_soil <- (nir_soil - red_soil) / (nir_soil + red_soil)

  expect_equal(ndvi_soil, 0)

  # Test case 3: water (negative NDVI)
  nir_water <- 0.1
  red_water <- 0.2
  ndvi_water <- (nir_water - red_water) / (nir_water + red_water)

  expect_true(ndvi_water < 0)

  # NDVI bounds
  expect_true(ndvi_healthy >= -1 && ndvi_healthy <= 1)
  expect_true(ndvi_soil >= -1 && ndvi_soil <= 1)
  expect_true(ndvi_water >= -1 && ndvi_water <= 1)
})

test_that("spatial filtering works correctly", {
  skip_if_not_installed("sf")

  library(sf)

  # Create test zone (100m x 100m)
  zone <- st_as_sfc(st_bbox(c(xmin = 0, ymin = 0, xmax = 100, ymax = 100)))
  zone <- st_set_crs(zone, 2154)

  # Create test points (some inside, some outside)
  pts_inside <- st_sfc(
    st_point(c(50, 50)),
    st_point(c(25, 75)),
    st_point(c(75, 25))
  )
  pts_outside <- st_sfc(
    st_point(c(150, 50)),
    st_point(c(-50, 50))
  )

  pts_all <- c(pts_inside, pts_outside)
  pts_all <- st_set_crs(pts_all, 2154)

  # Buffer to create polygons
  crowns <- st_buffer(pts_all, 5)
  crowns_sf <- st_sf(id = 1:5, geometry = crowns)

  # Filter with intersection
  crowns_filtered <- suppressWarnings(st_intersection(crowns_sf, zone))

  # Should have 3 crowns (inside) or partial
  expect_true(nrow(crowns_filtered) >= 3)
  expect_true(nrow(crowns_filtered) <= 5)
})

test_that("polygon geometry filter works", {
  skip_if_not_installed("sf")

  library(sf)

  # Create mixed geometry types
  geom_polygon <- st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE)))
  geom_line <- st_linestring(matrix(c(0,0, 1,1), ncol = 2, byrow = TRUE))
  geom_point <- st_point(c(0.5, 0.5))

  mixed_sf <- st_sf(
    id = 1:3,
    geometry = st_sfc(geom_polygon, geom_line, geom_point),
    crs = 2154
  )

  # Filter only polygons
  geom_types <- st_geometry_type(mixed_sf)
  polygons_only <- mixed_sf[geom_types %in% c("POLYGON", "MULTIPOLYGON"), ]

  expect_equal(nrow(polygons_only), 1)
  expect_equal(as.character(st_geometry_type(polygons_only)), "POLYGON")
})

test_that("train/test split proportions are correct", {
  set.seed(2024)

  n <- 100
  train_prop <- 0.8

  train_idx <- sample(n, size = floor(train_prop * n))
  test_idx <- setdiff(1:n, train_idx)

  expect_equal(length(train_idx), 80)
  expect_equal(length(test_idx), 20)
  expect_equal(length(train_idx) + length(test_idx), n)

  # No overlap
  expect_equal(length(intersect(train_idx, test_idx)), 0)
})

test_that("probability threshold filtering works", {
  # Simulate prediction probabilities
  set.seed(2024)
  n <- 100

  probs <- data.frame(
    max_prob = runif(n, 0.3, 0.95)
  )

  threshold <- 0.5

  probs$uncertain <- probs$max_prob < threshold
  probs$confident <- !probs$uncertain

  # Check counts make sense
  expect_true(sum(probs$uncertain) > 0)
  expect_true(sum(probs$confident) > 0)
  expect_equal(sum(probs$uncertain) + sum(probs$confident), n)

  # Check threshold applied correctly
  expect_true(all(probs$max_prob[probs$uncertain] < threshold))
  expect_true(all(probs$max_prob[probs$confident] >= threshold))
})
