# Tests for Tutorial 08 - Coregistration LiDAR/Terrain
# These tests verify the coregistration functions and algorithms

test_that("tutorial 08 Rmd file exists", {
  tutorial_path <- system.file(
    "tutorials", "08-coregistration", "08-coregistration.Rmd",
    package = "nemeton"
  )

  skip_if(tutorial_path == "", "Tutorial file not found in installed package")
  expect_true(file.exists(tutorial_path))
})

test_that("coregistration data files exist", {
  coreg_dir <- system.file("extdata", "coregistration", package = "nemeton")

  skip_if(coreg_dir == "", "Coregistration data not found in package")

  # Check expected files
  expected_files <- c(
    "plotsCoregistration.rda",
    "treesCoregistration.rda",
    "lasCoregistration.rda"
  )

  for (f in expected_files) {
    file_path <- file.path(coreg_dir, f)
    expect_true(file.exists(file_path), info = paste("Missing:", f))
  }
})

test_that("correlation coefficient calculation is correct", {
  # Test Pearson correlation
  x <- c(1, 2, 3, 4, 5)
  y <- c(1.1, 2.0, 2.9, 4.1, 5.0)

  r <- cor(x, y)

  expect_true(r > 0.99)  # Strong positive correlation
  expect_true(r <= 1)

  # Test negative correlation
  y_neg <- c(5, 4, 3, 2, 1)
  r_neg <- cor(x, y_neg)
  expect_true(r_neg < -0.99)

  # Test weak correlation with deterministic values
  # Using values that have low correlation with x = c(1,2,3,4,5)
  y_weak <- c(3, 1, 4, 2, 3)  # Scrambled values with weak correlation
  r_weak <- cor(x, y_weak)
  expect_true(abs(r_weak) < 0.9)  # Weaker correlation
})

test_that("offset search grid is correctly generated", {
  # Generate search grid
  search_range <- 10  # meters
  step <- 1  # meter

  offsets <- expand.grid(
    dx = seq(-search_range, search_range, by = step),
    dy = seq(-search_range, search_range, by = step)
  )

  # Check grid properties
  expect_equal(nrow(offsets), 21 * 21)  # 21 values in each direction
  expect_equal(min(offsets$dx), -search_range)
  expect_equal(max(offsets$dx), search_range)
  expect_equal(min(offsets$dy), -search_range)
  expect_equal(max(offsets$dy), search_range)

  # Check origin is included
  origin <- offsets[offsets$dx == 0 & offsets$dy == 0, ]
  expect_equal(nrow(origin), 1)
})

test_that("tree mask creation from coordinates works", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  library(sf)
  library(terra)

  # Create test tree positions
  trees <- data.frame(
    x = c(50, 60, 70),
    y = c(50, 55, 45),
    dbh = c(30, 40, 25)  # cm
  )

  # Convert to sf
  trees_sf <- st_as_sf(trees, coords = c("x", "y"), crs = 2154)

  # Create raster template
  r <- rast(ext(c(0, 100, 0, 100)), resolution = 1, crs = "EPSG:2154")

  # Rasterize tree positions (simple count)
  trees_vect <- vect(trees_sf)
  tree_mask <- rasterize(trees_vect, r, fun = "count", background = 0)

  expect_s4_class(tree_mask, "SpatRaster")
  expect_equal(sum(values(tree_mask), na.rm = TRUE), 3)  # 3 trees
})

test_that("circular plot geometry is correct", {
  skip_if_not_installed("sf")

  library(sf)

  # Create circular plot
  center <- st_point(c(100, 100))
  radius <- 15  # meters

  circle <- st_buffer(st_sfc(center, crs = 2154), radius)

  # Check area (pi * r^2)
  expected_area <- pi * radius^2
  actual_area <- as.numeric(st_area(circle))

  expect_equal(actual_area, expected_area, tolerance = 0.01)
})

test_that("offset application to coordinates works", {
  skip_if_not_installed("sf")

  library(sf)

  # Original points
  pts <- st_as_sf(data.frame(
    id = 1:3,
    x = c(100, 110, 120),
    y = c(200, 210, 220)
  ), coords = c("x", "y"), crs = 2154)

  # Apply offset
  dx <- 5
  dy <- -3

  coords_orig <- st_coordinates(pts)
  coords_new <- coords_orig
  coords_new[, 1] <- coords_new[, 1] + dx
  coords_new[, 2] <- coords_new[, 2] + dy

  # Verify offset
  expect_equal(as.numeric(coords_new[1, 1]), 105)
  expect_equal(as.numeric(coords_new[1, 2]), 197)
  expect_equal(as.numeric(coords_new[2, 1]), 115)
  expect_equal(as.numeric(coords_new[3, 2]), 217)
})

test_that("best offset selection works", {
  # Simulate correlation surface
  set.seed(42)
  offsets <- expand.grid(
    dx = seq(-5, 5, by = 1),
    dy = seq(-5, 5, by = 1)
  )

  # Create correlation values with peak at (2, -1)
  offsets$correlation <- 0.5 + 0.4 * exp(-((offsets$dx - 2)^2 + (offsets$dy + 1)^2) / 4)

  # Find best offset
  best_idx <- which.max(offsets$correlation)
  best_offset <- offsets[best_idx, ]

  expect_equal(best_offset$dx, 2)
  expect_equal(best_offset$dy, -1)
  expect_true(best_offset$correlation > 0.85)
})

test_that("coregistration quality metrics are computed correctly", {
  # Simulate before/after correlations
  r_before <- 0.45
  r_after <- 0.82

  # Improvement
  improvement <- r_after - r_before
  improvement_pct <- 100 * improvement / abs(r_before)

  expect_equal(improvement, 0.37, tolerance = 0.01)
  expect_true(improvement_pct > 80)

  # Quality classification
  quality <- if (r_after > 0.8) "Excellent" else if (r_after > 0.6) "Bon" else "Faible"
  expect_equal(quality, "Excellent")
})

test_that("distance calculation between points is correct", {
  skip_if_not_installed("sf")

  library(sf)

  # Two points
  p1 <- st_point(c(0, 0))
  p2 <- st_point(c(3, 4))

  dist <- st_distance(st_sfc(p1, crs = 2154), st_sfc(p2, crs = 2154))

  # Distance should be 5 (3-4-5 triangle)
  expect_equal(as.numeric(dist), 5, tolerance = 0.001)
})

test_that("CHM height extraction at point works", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  library(terra)
  library(sf)

  # Create test CHM
  chm <- rast(ext(c(0, 100, 0, 100)), resolution = 1, crs = "EPSG:2154")
  values(chm) <- matrix(rep(1:100, each = 100), nrow = 100, byrow = TRUE)

  # Create point
  pt <- st_sfc(st_point(c(50, 50)), crs = 2154)

  # Extract value
  val <- extract(chm, vect(pt))

  expect_true(!is.na(val[1, 2]))
  expect_equal(val[1, 2], 50, tolerance = 1)  # Middle of raster
})

test_that("plot data structure is correct", {
  # Expected plot data structure
  plot_data <- data.frame(
    plot_id = c("P1", "P2", "P3"),
    x = c(100, 200, 300),
    y = c(100, 200, 300),
    radius = c(15, 15, 15),
    n_trees = c(25, 30, 22)
  )

  expect_true("plot_id" %in% names(plot_data))
  expect_true("x" %in% names(plot_data))
  expect_true("y" %in% names(plot_data))
  expect_true("radius" %in% names(plot_data))

  expect_equal(nrow(plot_data), 3)
  expect_true(all(plot_data$radius > 0))
})

test_that("parallel processing setup is valid", {
  # Check available cores
  n_cores <- parallel::detectCores()

  expect_true(n_cores >= 1)

  # Recommended cores (leave 1 for system)
  recommended <- max(1, n_cores - 1)
  expect_true(recommended >= 1)
  expect_true(recommended <= n_cores)
})
