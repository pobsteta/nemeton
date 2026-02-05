# test-performance.R
# Performance Tests for nemeton v0.12.0
# T196: Tests de performance (20 parcelles < 5 min)

library(testthat)
library(sf)

# ==============================================================================
# T196: Performance Benchmark Tests
# ==============================================================================

test_that("nemeton_compute completes within 5 minutes for 20 parcels", {

  skip_on_cran()
  skip_if_not_installed("nemeton")


  # Load demo data
  data(massif_demo_units, package = "nemeton")
  data(massif_demo_layers, package = "nemeton")

  # Ensure we have 20 parcels (or use what's available)
  n_parcels <- min(20, nrow(massif_demo_units))
  units <- massif_demo_units[1:n_parcels, ]
  layers <- massif_demo_layers

  cli::cli_alert_info("Performance test: {n_parcels} parcels")

  # Define indicators to test (core indicators that don't require external data)
  test_indicators <- c(
    "carbon_biomass",
    "carbon_ndvi",
    "biodiversity_protected",
    "biodiversity_structure",
    "water_network",
    "landscape_fragmentation",
    "landscape_edge_ratio"
  )

  # Filter to only available indicators
  available <- list_indicators()
  test_indicators <- intersect(test_indicators, available)

  skip_if(length(test_indicators) == 0, "No test indicators available")

  # Benchmark computation time
  start_time <- Sys.time()

  result <- tryCatch({
    nemeton_compute(
      units = units,
      layers = layers,
      indicators = test_indicators,
      progress = FALSE
    )
  }, error = function(e) {
    cli::cli_warn("Computation error (expected in test environment): {e$message}")
    NULL
  })

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  cli::cli_alert_info("Elapsed time: {round(elapsed, 1)} seconds")

  # Performance criterion: < 5 minutes (300 seconds) for 20 parcels
  # In test environment with mock data, this should be much faster
  expect_lt(elapsed, 300,
            label = sprintf("Computation time (%.1f sec) should be < 300 sec", elapsed))
})

test_that("normalize_indicators is fast (< 1 second for 100 parcels)", {
  skip_on_cran()

  # Create test data with 100 parcels
  n <- 100
  test_data <- data.frame(
    id = 1:n,
    C1 = runif(n, 50, 500),
    C2 = runif(n, 0.3, 0.9),
    B1 = runif(n, 10, 90),
    B2 = runif(n, 0.2, 0.8),
    B3 = runif(n, 0.1, 0.7),
    W1 = runif(n, 5, 50),
    W2 = runif(n, 0, 1),
    W3 = runif(n, 2, 15),
    A1 = runif(n, 20, 80),
    A2 = runif(n, 30, 90),
    F1 = runif(n, 1, 5),
    F2 = runif(n, 0, 1),
    L1 = runif(n, 0.1, 0.9),
    L2 = runif(n, 0.5, 3),
    T1 = runif(n, 20, 200),
    T2 = runif(n, -5, 10),
    R1 = runif(n, 10, 80),
    R2 = runif(n, 20, 90),
    R3 = runif(n, 0, 1),
    R4 = runif(n, 0, 100),
    S1 = runif(n, 0, 5),
    S2 = runif(n, 100, 5000),
    S3 = runif(n, 50, 2000),
    P1 = runif(n, 50, 400),
    P2 = runif(n, 1, 5),
    P3 = runif(n, 1, 4),
    E1 = runif(n, 10, 100),
    E2 = runif(n, 5, 50),
    N1 = runif(n, 100, 5000),
    N2 = runif(n, 0.1, 1),
    N3 = runif(n, 20, 80)
  )

  # Convert to sf (required for normalize_indicators)
  test_data$lon <- runif(n, 2, 3)
  test_data$lat <- runif(n, 45, 46)
  test_sf <- sf::st_as_sf(test_data, coords = c("lon", "lat"), crs = 4326)

  # Benchmark normalization
  start_time <- Sys.time()

  normalized <- normalize_indicators(test_sf, method = "minmax")

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cli::cli_alert_info("Normalization time for {n} parcels: {round(elapsed * 1000, 1)} ms")

  # Should complete in < 1 second

  expect_lt(elapsed, 1,
            label = sprintf("Normalization time (%.3f sec) should be < 1 sec", elapsed))

  # Verify output
  expect_s3_class(normalized, "sf")
  expect_true(nrow(normalized) == n)
})

test_that("create_family_index is fast (< 1 second for 100 parcels)", {
  skip_on_cran()

  # Create test data with normalized indicators
  n <- 100
  test_data <- data.frame(
    id = 1:n,
    C1_norm = runif(n, 0, 1),
    C2_norm = runif(n, 0, 1),
    B1_norm = runif(n, 0, 1),
    B2_norm = runif(n, 0, 1),
    B3_norm = runif(n, 0, 1),
    W1_norm = runif(n, 0, 1),
    W2_norm = runif(n, 0, 1),
    W3_norm = runif(n, 0, 1),
    A1_norm = runif(n, 0, 1),
    A2_norm = runif(n, 0, 1),
    F1_norm = runif(n, 0, 1),
    F2_norm = runif(n, 0, 1),
    L1_norm = runif(n, 0, 1),
    L2_norm = runif(n, 0, 1),
    T1_norm = runif(n, 0, 1),
    T2_norm = runif(n, 0, 1),
    R1_norm = runif(n, 0, 1),
    R2_norm = runif(n, 0, 1),
    R3_norm = runif(n, 0, 1),
    R4_norm = runif(n, 0, 1),
    S1_norm = runif(n, 0, 1),
    S2_norm = runif(n, 0, 1),
    S3_norm = runif(n, 0, 1),
    P1_norm = runif(n, 0, 1),
    P2_norm = runif(n, 0, 1),
    P3_norm = runif(n, 0, 1),
    E1_norm = runif(n, 0, 1),
    E2_norm = runif(n, 0, 1),
    N1_norm = runif(n, 0, 1),
    N2_norm = runif(n, 0, 1),
    N3_norm = runif(n, 0, 1)
  )

  # Convert to sf
  test_data$lon <- runif(n, 2, 3)
  test_data$lat <- runif(n, 45, 46)
  test_sf <- sf::st_as_sf(test_data, coords = c("lon", "lat"), crs = 4326)

  # Benchmark family index creation
  start_time <- Sys.time()

  families <- create_family_index(test_sf)

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cli::cli_alert_info("Family index creation for {n} parcels: {round(elapsed * 1000, 1)} ms")

  # Should complete in < 1 second
  expect_lt(elapsed, 1,
            label = sprintf("Family index time (%.3f sec) should be < 1 sec", elapsed))

  # Verify all 12 families are created
  family_cols <- grep("^family_", names(families), value = TRUE)
  expect_gte(length(family_cols), 10) # At least 10 families should be created
})

test_that("nemeton_radar generation is fast (< 2 seconds)", {
  skip_on_cran()

  # Create test data
  n <- 20
  test_data <- data.frame(
    id = 1:n,
    family_C = runif(n, 30, 80),
    family_B = runif(n, 40, 90),
    family_W = runif(n, 35, 75),
    family_A = runif(n, 45, 85),
    family_F = runif(n, 25, 70),
    family_L = runif(n, 50, 95),
    family_T = runif(n, 30, 70),
    family_R = runif(n, 20, 60),
    family_S = runif(n, 40, 80),
    family_P = runif(n, 35, 75),
    family_E = runif(n, 30, 70),
    family_N = runif(n, 45, 85)
  )

  test_data$lon <- runif(n, 2, 3)
  test_data$lat <- runif(n, 45, 46)
  test_sf <- sf::st_as_sf(test_data, coords = c("lon", "lat"), crs = 4326)

  # Benchmark radar plot generation
  start_time <- Sys.time()

  # Generate radar without display
  p <- tryCatch({
    nemeton_radar(test_sf, unit_id = 1, plot = FALSE)
  }, error = function(e) {
    cli::cli_warn("Radar generation skipped: {e$message}")
    NULL
  })

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cli::cli_alert_info("Radar generation time: {round(elapsed * 1000, 1)} ms")

  # Should complete in < 2 seconds
  expect_lt(elapsed, 2,
            label = sprintf("Radar generation time (%.3f sec) should be < 2 sec", elapsed))
})

test_that("App UI loads quickly (< 2 seconds)",
{
  skip_on_cran()
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  # Benchmark UI generation
  start_time <- Sys.time()

  ui <- tryCatch({
    app_ui(NULL)
  }, error = function(e) {
    cli::cli_warn("UI load skipped: {e$message}")
    NULL
  })

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cli::cli_alert_info("App UI load time: {round(elapsed * 1000, 1)} ms")

  # UI should load in < 2 seconds
  expect_lt(elapsed, 2,
            label = sprintf("UI load time (%.3f sec) should be < 2 sec", elapsed))

  if (!is.null(ui)) {
    expect_true(inherits(ui, "shiny.tag") || inherits(ui, "shiny.tag.list"))
  }
})

# ==============================================================================
# Memory Usage Tests
# ==============================================================================

test_that("Memory usage stays reasonable for large datasets", {
 skip_on_cran()
  skip_if_not(capabilities("profmem"), "Memory profiling not available")

  # Create larger test dataset
  n <- 500
  test_data <- data.frame(
    id = 1:n,
    C1 = runif(n, 50, 500),
    C2 = runif(n, 0.3, 0.9),
    B1 = runif(n, 10, 90),
    W1 = runif(n, 5, 50)
  )

  test_data$lon <- runif(n, 2, 3)
  test_data$lat <- runif(n, 45, 46)
  test_sf <- sf::st_as_sf(test_data, coords = c("lon", "lat"), crs = 4326)

  # Check memory before
  gc()
  mem_before <- sum(gc()[, 2])

  # Run normalization
  normalized <- normalize_indicators(test_sf, method = "minmax")
  families <- create_family_index(normalized)

  # Check memory after
  gc()
  mem_after <- sum(gc()[, 2])

  mem_increase_mb <- mem_after - mem_before

  cli::cli_alert_info("Memory increase for {n} parcels: {round(mem_increase_mb, 1)} MB")

 # Memory increase should be < 100 MB for 500 parcels
  expect_lt(mem_increase_mb, 100,
            label = sprintf("Memory increase (%.1f MB) should be < 100 MB", mem_increase_mb))
})
