# Tests for Tutorial 09 - Sampling Design and TSP
# These tests verify the sampling functions and TSP algorithm

test_that("tutorial 09 Rmd file exists", {
  tutorial_path <- system.file(
    "tutorials", "09-sampling", "09-sampling.Rmd",
    package = "nemeton"
  )

  skip_if(tutorial_path == "", "Tutorial file not found in installed package")
  expect_true(file.exists(tutorial_path))
})

test_that("sample size calculation is correct", {
  # Formula: n = t^2 * CV^2 / E^2
  # With t = 1.96 (95% confidence)

  calculate_sample_size <- function(cv = 20, error = 10, confidence = 0.95, N = NULL) {
    alpha <- 1 - confidence
    t_value <- qnorm(1 - alpha / 2)

    n <- (t_value^2 * cv^2) / error^2

    if (!is.null(N)) {
      n <- n / (1 + (n - 1) / N)
    }

    ceiling(n)
  }

  # Test case 1: CV=20%, E=10%, infinite population
  n1 <- calculate_sample_size(cv = 20, error = 10)
  expect_equal(n1, 16)  # ~15.4 rounded up

  # Test case 2: CV=30%, E=10%
  n2 <- calculate_sample_size(cv = 30, error = 10)
  expect_equal(n2, 35)  # ~34.6 rounded up

  # Test case 3: CV=20%, E=5% (more precision)
  n3 <- calculate_sample_size(cv = 20, error = 5)
  expect_equal(n3, 62)  # ~61.5 rounded up

  # Test with finite population correction
  n4 <- calculate_sample_size(cv = 20, error = 10, N = 100)
  expect_true(n4 < n1)  # Should be smaller
})

test_that("stratified sampling allocation works", {
  # Proportional allocation
  strata_sizes <- c(A = 100, B = 200, C = 50)
  total_n <- 35

  allocate_proportional <- function(strata_sizes, n_total, min_per_stratum = 2) {
    proportions <- strata_sizes / sum(strata_sizes)
    allocation <- round(proportions * n_total)

    # Ensure minimum
    allocation <- pmax(allocation, min_per_stratum)

    # Adjust to match total
    diff <- n_total - sum(allocation)
    if (diff > 0) {
      # Add to largest stratum
      idx <- which.max(strata_sizes)
      allocation[idx] <- allocation[idx] + diff
    } else if (diff < 0) {
      # Remove from largest stratum
      idx <- which.max(allocation)
      allocation[idx] <- allocation[idx] + diff
    }

    allocation
  }

  allocation <- allocate_proportional(strata_sizes, total_n)

  expect_equal(sum(allocation), total_n)
  expect_true(all(allocation >= 2))  # Minimum per stratum
})

test_that("grid candidate generation works", {
  skip_if_not_installed("sf")

  library(sf)

  # Create zone
  zone <- st_polygon(list(matrix(c(
    0, 0,
    1000, 0,
    1000, 1000,
    0, 1000,
    0, 0
  ), ncol = 2, byrow = TRUE)))
  zone_sf <- st_sf(id = 1, geometry = st_sfc(zone, crs = 2154))

  # Generate grid
  grid_step <- 100

  grid <- st_make_grid(zone_sf, cellsize = grid_step, what = "centers")
  grid_in_zone <- grid[st_intersects(grid, zone_sf, sparse = FALSE)[, 1]]

  # Should have ~100 points (10 x 10 grid)
  expect_true(length(grid_in_zone) > 80)
  expect_true(length(grid_in_zone) <= 121)
})

test_that("slope constraint filtering works", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  library(terra)
  library(sf)

  # Create test DEM with varying slope
  dem <- rast(ext(c(0, 100, 0, 100)), resolution = 1, crs = "EPSG:2154")
  # Create a tilted surface
  coords <- crds(dem)
  values(dem) <- coords[, 1] * 0.5  # 50% slope in X direction

  # Calculate slope
  slope <- terrain(dem, "slope", unit = "degrees")

  # Create test points
  pts <- st_as_sf(data.frame(
    x = c(10, 50, 90),
    y = c(50, 50, 50)
  ), coords = c("x", "y"), crs = 2154)

  # Extract slope values
  slope_vals <- extract(slope, vect(pts))

  # All points should have similar slope
  expect_true(all(slope_vals[, 2] > 20))  # Steep slope
})

test_that("forest cover constraint filtering works", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  library(terra)
  library(sf)

  # Create test forest mask
  forest <- rast(ext(c(0, 100, 0, 100)), resolution = 1, crs = "EPSG:2154")
  values(forest) <- 0

  # Add forest area (60x60 in center)
  forest[20:80, 20:80] <- 1

  # Create test points
  pts <- st_as_sf(data.frame(
    id = 1:3,
    x = c(50, 10, 90),  # center (forest), edge (no forest), edge (no forest)
    y = c(50, 10, 90)
  ), coords = c("x", "y"), crs = 2154)

  # Buffer points (15m radius plot)
  pts_buffer <- st_buffer(pts, 15)

  # Calculate forest cover per plot
  # (simplified - just check center point)
  forest_vals <- extract(forest, vect(pts))

  expect_equal(forest_vals[1, 2], 1)  # Center is forest
  expect_equal(forest_vals[2, 2], 0)  # Edge is not forest
})

test_that("distance matrix calculation works", {
  skip_if_not_installed("sf")

  library(sf)

  # Create points
  pts <- st_as_sf(data.frame(
    id = 1:4,
    x = c(0, 100, 0, 100),
    y = c(0, 0, 100, 100)
  ), coords = c("x", "y"), crs = 2154)

  # Calculate distance matrix
  dist_matrix <- st_distance(pts)

  # Check dimensions
  expect_equal(dim(dist_matrix), c(4, 4))

  # Check diagonal is zero
  expect_equal(as.numeric(diag(dist_matrix)), rep(0, 4))

  # Check known distances
  expect_equal(as.numeric(dist_matrix[1, 2]), 100, tolerance = 0.01)  # (0,0) to (100,0)
  expect_equal(as.numeric(dist_matrix[1, 4]), sqrt(2) * 100, tolerance = 0.01)  # diagonal
})

test_that("TSP greedy nearest neighbor works", {
  # Simple nearest neighbor algorithm
  tsp_nearest_neighbor <- function(dist_matrix, start = 1) {
    n <- nrow(dist_matrix)
    visited <- logical(n)
    tour <- integer(n)

    current <- start
    tour[1] <- current
    visited[current] <- TRUE

    for (i in 2:n) {
      # Find nearest unvisited
      distances <- dist_matrix[current, ]
      distances[visited] <- Inf

      next_city <- which.min(distances)
      tour[i] <- next_city
      visited[next_city] <- TRUE
      current <- next_city
    }

    tour
  }

  # Test with simple 4-point case
  dist <- matrix(c(
    0, 1, 2, 3,
    1, 0, 1, 2,
    2, 1, 0, 1,
    3, 2, 1, 0
  ), nrow = 4, byrow = TRUE)

  tour <- tsp_nearest_neighbor(dist, start = 1)

  # Check valid tour

  expect_equal(length(tour), 4)
  expect_equal(sort(tour), 1:4)  # All cities visited
  expect_equal(tour[1], 1)  # Starts at 1
})

test_that("tour length calculation is correct", {
  skip_if_not_installed("sf")

  library(sf)

  # Create simple tour
  pts <- st_as_sf(data.frame(
    id = 1:3,
    x = c(0, 100, 0),
    y = c(0, 0, 100)
  ), coords = c("x", "y"), crs = 2154)

  dist_matrix <- as.numeric(st_distance(pts))
  dim(dist_matrix) <- c(3, 3)

  # Tour: 1 -> 2 -> 3 -> 1
  tour <- c(1, 2, 3)

  total_length <- 0
  for (i in 1:(length(tour) - 1)) {
    total_length <- total_length + dist_matrix[tour[i], tour[i + 1]]
  }
  # Return to start
  total_length <- total_length + dist_matrix[tour[length(tour)], tour[1]]

  # Expected: 100 + sqrt(100^2 + 100^2) + 100 = 100 + 141.4 + 100 = 341.4
  expected <- 100 + sqrt(2) * 100 + 100
  expect_equal(total_length, expected, tolerance = 0.1)
})

test_that("walking time estimation works", {
  # Parameters
  walk_speed_kmh <- 4
  offpath_speed_kmh <- 2
  offpath_penalty <- 2

  # Distance in meters
  distance_on_path <- 1000  # 1 km
  distance_off_path <- 500  # 0.5 km

  # Time calculation
  time_on_path_h <- distance_on_path / 1000 / walk_speed_kmh
  time_off_path_h <- (distance_off_path / 1000 / offpath_speed_kmh) * offpath_penalty

  total_time_h <- time_on_path_h + time_off_path_h
  total_time_min <- total_time_h * 60

  expect_equal(time_on_path_h, 0.25, tolerance = 0.01)  # 15 min
  expect_equal(time_off_path_h, 0.5, tolerance = 0.01)  # 30 min with penalty
  expect_equal(total_time_min, 45, tolerance = 0.1)
})

test_that("replacement plot selection works", {
  skip_if_not_installed("sf")

  library(sf)

  # Main plots
  main_plots <- st_as_sf(data.frame(
    id = 1:5,
    x = c(0, 100, 200, 300, 400),
    y = c(0, 0, 0, 0, 0)
  ), coords = c("x", "y"), crs = 2154)

  # Candidate replacements
  candidates <- st_as_sf(data.frame(
    id = 6:10,
    x = c(50, 150, 250, 350, 450),
    y = c(50, 50, 50, 50, 50)
  ), coords = c("x", "y"), crs = 2154)

  # Find nearest replacement for each main plot
  dist_to_main <- st_distance(candidates, main_plots)

  # For each main plot, find nearest candidate
  nearest_replacement <- apply(dist_to_main, 2, which.min)

  expect_equal(length(nearest_replacement), 5)
  expect_true(all(nearest_replacement %in% 1:5))
})

test_that("config parameters are valid", {
  config <- list(
    plot_radius = 15,
    grid_step = 30,
    min_forest_cover = 0.70,
    max_slope = 45,
    n_main = 40,
    n_replacement = 12,
    min_per_stratum = 2,
    walk_speed_kmh = 4,
    offpath_speed_kmh = 2,
    offpath_penalty = 2,
    crs = 2154,
    seed = 2024
  )

  # Validate ranges
  expect_true(config$plot_radius > 0 && config$plot_radius <= 25)
  expect_true(config$grid_step >= config$plot_radius * 2)  # No overlap
  expect_true(config$min_forest_cover >= 0 && config$min_forest_cover <= 1)
  expect_true(config$max_slope > 0 && config$max_slope <= 90)
  expect_true(config$n_main > 0)
  expect_true(config$n_replacement >= 0)
  expect_true(config$min_per_stratum >= 1)
  expect_true(config$walk_speed_kmh > 0)
  expect_true(config$offpath_penalty >= 1)
})
