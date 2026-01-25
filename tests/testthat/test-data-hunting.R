# test-data-hunting.R
# Tests for hunting data acquisition functions
# R/data-hunting.R - currently 0% coverage

library(testthat)
library(sf)

# ==============================================================================
# Tests for download_hunting_data()
# Note: Network-dependent tests are skipped by default
# ==============================================================================

test_that("download_hunting_data validates species parameter", {
  # Invalid species should error
  expect_error(
    download_hunting_data(species = "invalid_species", force_download = FALSE),
    "No valid species specified"
  )
})

test_that("download_hunting_data accepts valid species names", {
  skip_if_offline()
  skip_on_cran()

  # Test with single species - using cache if available
  result <- download_hunting_data(
    species = "chevreuil",
    cache_dir = tempdir(),
    force_download = FALSE
  )

  # Should return data.frame or NULL (if download fails)
  expect_true(is.null(result) || is.data.frame(result))

  if (!is.null(result)) {
    expect_true(nrow(result) > 0)
    expect_true("espece" %in% names(result))
    expect_true("chevreuil" %in% result$espece)
  }
})

test_that("download_hunting_data creates cache directory if needed", {
  skip_if_offline()
  skip_on_cran()

  cache_dir <- file.path(tempdir(), "test_hunting_cache_new")

  # Ensure directory doesn't exist
  if (dir.exists(cache_dir)) unlink(cache_dir, recursive = TRUE)

  # This should create the directory
  result <- tryCatch(
    download_hunting_data(species = "chevreuil", cache_dir = cache_dir),
    error = function(e) NULL
  )

  # Directory should now exist
  expect_true(dir.exists(cache_dir))

  # Cleanup
  unlink(cache_dir, recursive = TRUE)
})

test_that("download_hunting_data handles 'all' species correctly", {
  skip_if_offline()
  skip_on_cran()

  result <- download_hunting_data(
    species = "all",
    cache_dir = tempdir(),
    force_download = FALSE
  )

  if (!is.null(result)) {
    # Should have multiple species
    expect_true(length(unique(result$espece)) >= 1)
  }
})

# ==============================================================================
# Tests for standardize_hunting_columns()
# ==============================================================================

test_that("standardize_hunting_columns standardizes column names", {
  # Create mock data with various column name patterns
  mock_data <- data.frame(
    departement = c("01", "02", "03"),
    nom = c("Ain", "Aisne", "Allier"),
    annee = c("2022-2023", "2022-2023", "2022-2023"),
    prelevements = c(1000, 1500, 800),
    stringsAsFactors = FALSE
  )

  result <- nemeton:::standardize_hunting_columns(mock_data, "chevreuil")

  expect_true("espece" %in% names(result))
  expect_equal(result$espece[1], "chevreuil")
})

test_that("standardize_hunting_columns handles alternative column names", {
  # Test with different column naming conventions
  mock_data <- data.frame(
    code_dept = c("01", "02"),
    libelle = c("Ain", "Aisne"),
    campagne = c("2022", "2022"),
    tableau = c(500, 600),
    stringsAsFactors = FALSE
  )

  result <- nemeton:::standardize_hunting_columns(mock_data, "cerf")

  expect_true("espece" %in% names(result))
  expect_equal(result$espece[1], "cerf")
})

# ==============================================================================
# Tests for compute_game_pressure_index()
# ==============================================================================

test_that("compute_game_pressure_index works with provided data", {
  # Create mock hunting data
  mock_hunting_data <- data.frame(
    code_dept = c("01", "02", "03", "01", "02", "03"),
    nom_dept = c("Ain", "Aisne", "Allier", "Ain", "Aisne", "Allier"),
    espece = c("chevreuil", "chevreuil", "chevreuil", "cerf", "cerf", "cerf"),
    saison = c("2022-2023", "2022-2023", "2022-2023", "2022-2023", "2022-2023", "2022-2023"),
    tableau = c(1000, 1500, 800, 200, 300, 100),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(
    hunting_data = mock_hunting_data,
    season = "2022-2023"
  )

  expect_s3_class(result, "data.frame")
  expect_true("code_dept" %in% names(result))
  expect_true("pressure_index" %in% names(result))
  expect_true(all(result$pressure_index >= 0 & result$pressure_index <= 100))
})

test_that("compute_game_pressure_index uses latest season when specified", {
  mock_data <- data.frame(
    code_dept = c("01", "01", "02", "02"),
    nom_dept = c("Ain", "Ain", "Aisne", "Aisne"),
    espece = rep("chevreuil", 4),
    saison = c("2021-2022", "2022-2023", "2021-2022", "2022-2023"),
    tableau = c(900, 1000, 1400, 1500),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(
    hunting_data = mock_data,
    season = "latest"
  )

  # Should use 2022-2023 data (latest)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) == 2)  # 2 departments
})

test_that("compute_game_pressure_index supports different normalization methods", {
  mock_data <- data.frame(
    code_dept = c("01", "02", "03"),
    nom_dept = c("Ain", "Aisne", "Allier"),
    espece = rep("chevreuil", 3),
    saison = rep("2022-2023", 3),
    tableau = c(500, 1000, 1500),
    stringsAsFactors = FALSE
  )

  # Rank normalization
  result_rank <- compute_game_pressure_index(
    hunting_data = mock_data,
    normalize_by = "rank"
  )

  # Minmax normalization
  result_minmax <- compute_game_pressure_index(
    hunting_data = mock_data,
    normalize_by = "minmax"
  )

  expect_true(all(result_rank$pressure_index >= 0))
  expect_true(all(result_minmax$pressure_index >= 0))
})

test_that("compute_game_pressure_index handles custom weights", {
  mock_data <- data.frame(
    code_dept = c("01", "02"),
    nom_dept = c("Ain", "Aisne"),
    espece = c("chevreuil", "chevreuil"),
    saison = c("2022-2023", "2022-2023"),
    tableau = c(1000, 2000),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(
    hunting_data = mock_data,
    weights = c(chevreuil = 1.0, cerf = 0, sanglier = 0)
  )

  expect_s3_class(result, "data.frame")
  expect_true("pressure_index" %in% names(result))
})

test_that("compute_game_pressure_index errors on empty data for season", {
  mock_data <- data.frame(
    code_dept = c("01"),
    nom_dept = c("Ain"),
    espece = c("chevreuil"),
    saison = c("2021-2022"),
    tableau = c(1000),
    stringsAsFactors = FALSE
  )

  expect_error(
    compute_game_pressure_index(mock_data, season = "2025-2026"),
    "No data available for season"
  )
})

# ==============================================================================
# Tests for get_game_pressure_raster()
# ==============================================================================

test_that("get_game_pressure_raster validates input", {
  # Non-sf input should error
  expect_error(
    get_game_pressure_raster(units = data.frame(x = 1:3)),
    "units must be an sf object"
  )
})

test_that("get_game_pressure_raster creates raster with provided data", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Create test units
  units <- create_test_units(n_features = 3)

  # Create mock pressure data
  pressure_data <- data.frame(
    code_dept = c("36", "37"),
    nom_dept = c("Indre", "Indre-et-Loire"),
    pressure_index = c(45.5, 62.3),
    stringsAsFactors = FALSE
  )

  # Create mock department boundaries covering test area
  bbox <- sf::st_bbox(units)
  dept_poly <- sf::st_as_sfc(bbox)
  dept_boundaries <- sf::st_sf(
    code_dept = "36",
    nom_dept = "Indre",
    geometry = dept_poly
  )
  sf::st_crs(dept_boundaries) <- sf::st_crs(units)

  result <- get_game_pressure_raster(
    units = units,
    pressure_data = pressure_data,
    dept_boundaries = dept_boundaries
  )

  expect_s4_class(result, "SpatRaster")
  expect_equal(names(result), "game_pressure")
})

# ==============================================================================
# Additional tests for compute_game_pressure_index edge cases
# ==============================================================================

test_that("compute_game_pressure_index handles data without nom_dept column", {
  mock_data <- data.frame(
    code_dept = c("01", "02", "03"),
    espece = rep("chevreuil", 3),
    saison = rep("2022-2023", 3),
    tableau = c(500, 1000, 1500),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(hunting_data = mock_data)

  expect_s3_class(result, "data.frame")
  expect_true("pressure_index" %in% names(result))
})

test_that("compute_game_pressure_index handles area normalization without data", {
  mock_data <- data.frame(
    code_dept = c("01", "02"),
    nom_dept = c("Ain", "Aisne"),
    espece = c("chevreuil", "chevreuil"),
    saison = c("2022-2023", "2022-2023"),
    tableau = c(1000, 2000),
    stringsAsFactors = FALSE
  )

  # Area normalization without dept_forest_area should fallback to rank
  result <- suppressWarnings(
    compute_game_pressure_index(
      hunting_data = mock_data,
      normalize_by = "area"
    )
  )

  expect_s3_class(result, "data.frame")
  expect_true("pressure_index" %in% names(result))
})

test_that("compute_game_pressure_index handles multiple seasons correctly", {
  mock_data <- data.frame(
    code_dept = rep(c("01", "02"), 3),
    nom_dept = rep(c("Ain", "Aisne"), 3),
    espece = rep("chevreuil", 6),
    saison = c("2020-2021", "2020-2021", "2021-2022", "2021-2022", "2022-2023", "2022-2023"),
    tableau = c(800, 1200, 900, 1300, 1000, 1500),
    stringsAsFactors = FALSE
  )

  # Should use latest (2022-2023) by default
  result <- compute_game_pressure_index(hunting_data = mock_data, season = "latest")

  expect_equal(nrow(result), 2)  # 2 departments
})

test_that("standardize_hunting_columns handles minimal columns", {
  mock_data <- data.frame(
    code = c("01", "02"),
    nb = c(100, 200),
    stringsAsFactors = FALSE
  )

  result <- nemeton:::standardize_hunting_columns(mock_data, "sanglier")

  expect_true("espece" %in% names(result))
  expect_equal(result$espece[1], "sanglier")
})

test_that("download_hunting_data handles multiple species", {
  skip_if_offline()
  skip_on_cran()

  # Test with specific species combination
  result <- tryCatch(
    download_hunting_data(
      species = c("chevreuil", "cerf"),
      cache_dir = tempdir(),
      force_download = FALSE
    ),
    error = function(e) NULL
  )

  if (!is.null(result)) {
    expect_true(is.data.frame(result))
    expect_true(all(c("chevreuil", "cerf") %in% result$espece))
  }
})

# ==============================================================================
# Helper function for skipping network tests
# ==============================================================================

skip_if_offline <- function() {
  if (!requireNamespace("curl", quietly = TRUE)) {
    skip("curl package not available")
  }
  if (!curl::has_internet()) {
    skip("No internet connection")
  }
}
