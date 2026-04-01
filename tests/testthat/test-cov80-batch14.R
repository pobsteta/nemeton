# test-cov80-batch14.R
# Coverage boost for R/service_compute.R (utility functions) + R/indicators-core.R
# Target: compute_single_indicator, compute_all_indicators, clear_computation_cache,
#         save_indicators, load_indicators, find_url_column, extract_tile_names,
#         list_indicators, compute_indicator, get_computation_progress (with file)

# ==============================================================================
# find_url_column()
# ==============================================================================

test_that("find_url_column: exact match url_telechargement", {
  sf_df <- data.frame(
    id = 1,
    url_telechargement = "http://example.com",
    stringsAsFactors = FALSE
  )
  result <- nemeton:::find_url_column(sf_df)
  expect_equal(result, "url_telechargement")
})

test_that("find_url_column: exact match url", {
  sf_df <- data.frame(id = 1, url = "http://example.com", stringsAsFactors = FALSE)
  result <- nemeton:::find_url_column(sf_df)
  expect_equal(result, "url")
})

test_that("find_url_column: case-insensitive match", {
  sf_df <- data.frame(id = 1, URL_Telechargement = "http://x.com", stringsAsFactors = FALSE)
  result <- nemeton:::find_url_column(sf_df)
  expect_equal(result, "URL_Telechargement")
})

test_that("find_url_column: partial match on 'download'", {
  sf_df <- data.frame(id = 1, my_download_link = "http://x.com", stringsAsFactors = FALSE)
  result <- nemeton:::find_url_column(sf_df)
  expect_equal(result, "my_download_link")
})

test_that("find_url_column: returns NULL when no match", {
  sf_df <- data.frame(id = 1, name = "test", stringsAsFactors = FALSE)
  result <- nemeton:::find_url_column(sf_df)
  expect_null(result)
})

# ==============================================================================
# extract_tile_names()
# ==============================================================================

test_that("extract_tile_names: extracts filenames from URLs", {
  urls <- c(
    "https://data.ign.fr/tiles/tile_A.copc.laz",
    "https://data.ign.fr/tiles/tile_B.copc.laz"
  )
  result <- nemeton:::extract_tile_names(urls, ".copc.laz")
  expect_equal(result, c("tile_A.copc.laz", "tile_B.copc.laz"))
})

test_that("extract_tile_names: generates names when URL lacks extension", {
  urls <- c("https://data.ign.fr/api/123", "https://data.ign.fr/api/456")
  result <- nemeton:::extract_tile_names(urls, ".tif")
  expect_equal(result, c("tile_1.tif", "tile_2.tif"))
})

test_that("extract_tile_names: handles list input (from WFS parsing)", {
  urls <- list("https://data.ign.fr/tile_1.laz", "https://data.ign.fr/tile_2.laz")
  result <- nemeton:::extract_tile_names(urls, ".laz")
  expect_equal(result, c("tile_1.laz", "tile_2.laz"))
})

# ==============================================================================
# get_computation_progress() with existing file
# ==============================================================================

test_that("get_computation_progress: returns list when no progress file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::get_computation_progress("test_proj")
    expect_type(result, "list")
    expect_equal(result$computed_indicators, character(0))
    expect_null(result$last_indicator)
  })
})

test_that("get_computation_progress: reads progress JSON", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    progress <- list(
      computed_indicators = list("indicateur_c1_biomasse", "indicateur_w3_humidite"),
      last_indicator = "indicateur_w3_humidite",
      last_saved_at = "2025-01-01 12:00:00"
    )
    jsonlite::write_json(progress, file.path(proj_path, "data", "compute_progress.json"),
                         auto_unbox = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::get_computation_progress("test_proj")
    expect_type(result, "list")
    expect_equal(result$last_indicator, "indicateur_w3_humidite")
  })
})

test_that("get_computation_progress: handles corrupt JSON", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    writeLines("{ not valid json }", file.path(proj_path, "data", "compute_progress.json"))

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::get_computation_progress("test_proj")
    expect_type(result, "list")
    expect_equal(result$computed_indicators, character(0))
  })
})

# ==============================================================================
# clear_computation_cache()
# ==============================================================================

test_that("clear_computation_cache: removes cache files", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    # Create files to clear
    writeLines("{}", file.path(proj_path, "data", "indicators.parquet"))
    writeLines("{}", file.path(proj_path, "data", "compute_progress.json"))
    writeLines("{}", file.path(proj_path, "data", "progress_state.json"))

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::clear_computation_cache("test_proj")
    expect_true(result)
    expect_false(file.exists(file.path(proj_path, "data", "indicators.parquet")))
    expect_false(file.exists(file.path(proj_path, "data", "compute_progress.json")))
    expect_false(file.exists(file.path(proj_path, "data", "progress_state.json")))
  })
})

test_that("clear_computation_cache: returns FALSE for nonexistent project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  result <- nemeton:::clear_computation_cache("nonexistent")
  expect_false(result)
})

test_that("clear_computation_cache: succeeds when files don't exist", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::clear_computation_cache("test_proj")
    expect_true(result)
  })
})

# ==============================================================================
# compute_single_indicator() — with mocked indicator functions
# ==============================================================================

test_that("compute_single_indicator: dispatches to indicator function", {
  units <- create_test_units(n_features = 3)

  # Create a mock layers object
  layers <- list(
    rasters = list(),
    vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  # Mock the indicator function to return known values
  local_mocked_bindings(
    indicateur_c1_biomasse = function(units, ...) c(80, 60, 70),
    .package = "nemeton"
  )

  result <- nemeton:::compute_single_indicator("indicateur_c1_biomasse", units, layers)
  expect_equal(result, c(80, 60, 70))
})

test_that("compute_single_indicator: handles sf return with column mapping", {
  units <- create_test_units(n_features = 3)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  # Mock indicator that returns sf with R1 column
  mock_result <- units
  mock_result$R1 <- c(45, 55, 65)

  local_mocked_bindings(
    indicateur_r1_feu = function(units, ...) mock_result,
    .package = "nemeton"
  )

  result <- nemeton:::compute_single_indicator("indicateur_r1_feu", units, layers)
  expect_equal(result, c(45, 55, 65))
})

test_that("compute_single_indicator: fallback for unknown indicator", {
  units <- create_test_units(n_features = 3)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  result <- nemeton:::compute_single_indicator("completely_unknown_xyz", units, layers)
  expect_length(result, 3)
  expect_true(all(result >= 0 & result <= 100))
})

# ==============================================================================
# compute_all_indicators() — with mocking
# ==============================================================================

test_that("compute_all_indicators: computes multiple indicators", {
  units <- create_test_units(n_features = 2)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  # Mock compute_single_indicator to return known values
  call_count <- 0L
  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) {
      call_count <<- call_count + 1L
      c(50, 60)
    },
    .package = "nemeton"
  )

  result <- nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    progress_callback = NULL,
    project_id = NULL
  )

  expect_s3_class(result, "sf")
  expect_true("indicateur_c1_biomasse" %in% names(result))
  expect_true("indicateur_w3_humidite" %in% names(result))
  expect_equal(call_count, 2L)
})

test_that("compute_all_indicators: handles indicator failure gracefully", {
  units <- create_test_units(n_features = 2)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) {
      if (indicator == "indicateur_w3_humidite") stop("Test error")
      c(50, 60)
    },
    .package = "nemeton"
  )

  result <- suppressWarnings(nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    progress_callback = NULL,
    project_id = NULL
  ))

  expect_true("indicateur_c1_biomasse" %in% names(result))
  expect_true("indicateur_w3_humidite" %in% names(result))
  expect_equal(result$indicateur_c1_biomasse, c(50, 60))
  expect_true(all(is.na(result$indicateur_w3_humidite)))
})

test_that("compute_all_indicators: calls progress callback", {
  units <- create_test_units(n_features = 2)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) c(50, 60),
    .package = "nemeton"
  )

  callback_calls <- list()
  callback_fn <- function(info) {
    callback_calls[[length(callback_calls) + 1]] <<- info
  }

  nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("indicateur_c1_biomasse"),
    progress_callback = callback_fn,
    project_id = NULL
  )

  # Should get at least initial + per-indicator + final callbacks
  expect_true(length(callback_calls) >= 2)
})

test_that("compute_all_indicators: skips already computed (resume)", {
  units <- create_test_units(n_features = 2)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  call_count <- 0L
  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) {
      call_count <<- call_count + 1L
      c(50, 60)
    },
    load_indicators = function(project_id) {
      df <- sf::st_drop_geometry(units)
      df$indicateur_c1_biomasse <- c(80, 90)  # Already computed
      df
    },
    save_indicators_incremental = function(...) TRUE,
    is_cancelled = function(...) FALSE,
    .package = "nemeton"
  )

  result <- nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
    progress_callback = NULL,
    project_id = "test_proj"
  )

  # Only indicateur_w3_humidite should have been computed
  expect_equal(call_count, 1L)
})

test_that("compute_all_indicators: cancellation stops loop", {
  units <- create_test_units(n_features = 2)

  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0),
    cache_dir = NULL
  )
  class(layers) <- "nemeton_layers"

  call_count <- 0L
  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) {
      call_count <<- call_count + 1L
      c(50, 60)
    },
    load_indicators = function(project_id) NULL,
    save_indicators_incremental = function(...) TRUE,
    is_cancelled = function(project_id) call_count >= 1,  # Cancel after first
    .package = "nemeton"
  )

  result <- nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite", "soil_erosion"),
    progress_callback = NULL,
    project_id = "test_proj"
  )

  expect_true(call_count <= 2)  # Should have stopped early
})

# ==============================================================================
# list_indicators() from indicators-core.R
# ==============================================================================

test_that("list_indicators: returns all indicator names", {
  result <- nemeton::list_indicators()
  expect_type(result, "character")
  expect_true(length(result) > 25)
  expect_true("indicateur_c1_biomasse" %in% result)
  expect_true("indicateur_r1_feu" %in% result)
  expect_true("naturalness_composite" %in% result)
})

test_that("list_indicators: filters by category", {
  biophys <- nemeton::list_indicators(category = "biophysical")
  expect_true("indicateur_c1_biomasse" %in% biophys)
  expect_false("indicateur_r1_feu" %in% biophys)

  risk <- nemeton::list_indicators(category = "risk")
  expect_true("indicateur_r1_feu" %in% risk)
  expect_false("indicateur_c1_biomasse" %in% risk)

  social <- nemeton::list_indicators(category = "social")
  expect_true("indicateur_s1_routes" %in% social)
})

test_that("list_indicators: returns details data.frame", {
  result <- nemeton::list_indicators(return_type = "details")
  expect_true(is.data.frame(result))
  expect_true("name" %in% names(result))
  expect_true("family" %in% names(result))
  expect_true("description" %in% names(result))
  expect_true(nrow(result) > 25)
})

# ==============================================================================
# save_indicators() and load_indicators() (service_compute version)
# ==============================================================================

test_that("save_indicators: saves data.frame as parquet", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      update_project_metadata = function(...) NULL,
      .package = "nemeton"
    )

    # save_indicators (service_project.R version) takes a plain data.frame
    indicators <- data.frame(
      nemeton_id = paste0("u", 1:3),
      indicateur_c1_biomasse = c(80, 60, 70),
      stringsAsFactors = FALSE
    )

    result <- nemeton:::save_indicators("test_proj", indicators)
    expect_true(result)
    expect_true(file.exists(file.path(proj_path, "data", "indicators.parquet")))
  })
})

test_that("save_indicators: converts list to data.frame", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      update_project_metadata = function(...) NULL,
      .package = "nemeton"
    )

    indicators <- list(indicateur_c1_biomasse = c(80, 60), indicateur_w3_humidite = c(3.5, 4.2))

    result <- nemeton:::save_indicators("test_proj", indicators)
    expect_true(result)
  })
})

test_that("load_indicators: returns NULL for nonexistent project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  result <- nemeton:::load_indicators("nonexistent")
  expect_null(result)
})

test_that("load_indicators: returns NULL when no parquet file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::load_indicators("test_proj")
    expect_null(result)
  })
})

test_that("save_indicators + load_indicators round-trip", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      update_project_metadata = function(...) NULL,
      .package = "nemeton"
    )

    indicators <- data.frame(
      nemeton_id = paste0("u", 1:3),
      indicateur_c1_biomasse = c(80, 60, 70),
      stringsAsFactors = FALSE
    )

    nemeton:::save_indicators("test_proj", indicators)
    loaded <- nemeton:::load_indicators("test_proj")

    expect_true(is.data.frame(loaded))
    expect_equal(nrow(loaded), 3)
    expect_true("indicateur_c1_biomasse" %in% names(loaded))
  })
})

# ==============================================================================
# get_global_cache_dir()
# ==============================================================================

test_that("get_global_cache_dir: returns path string", {
  result <- nemeton:::get_global_cache_dir()
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

# ==============================================================================
# compute_indicator() from indicators-core.R
# ==============================================================================

test_that("compute_indicator: dispatches known indicator", {
  units <- create_test_units(n_features = 2)

  # Create a minimal layers object
  layers <- list(
    rasters = list(), vectors = list(),
    metadata = list(n_rasters = 0, n_vectors = 0)
  )
  class(layers) <- "nemeton_layers"

  local_mocked_bindings(
    indicateur_c1_biomasse = function(units, ...) c(100, 200),
    .package = "nemeton"
  )

  result <- nemeton:::compute_indicator("indicateur_c1_biomasse", units, layers)
  expect_equal(result, c(100, 200))
})

test_that("compute_indicator: errors on unknown indicator", {
  units <- create_test_units(n_features = 2)
  layers <- list(rasters = list(), vectors = list(), metadata = list())
  class(layers) <- "nemeton_layers"

  expect_error(
    nemeton:::compute_indicator("totally_nonexistent_indicator", units, layers),
    "Unknown indicator"
  )
})

test_that("compute_indicator: extracts column from sf return (risk indicators)", {
  units <- create_test_units(n_features = 2)

  layers <- list(rasters = list(), vectors = list(), metadata = list())
  class(layers) <- "nemeton_layers"

  mock_result <- units
  mock_result$R1 <- c(30, 40)

  local_mocked_bindings(
    indicateur_r1_feu = function(units, ...) mock_result,
    .package = "nemeton"
  )

  result <- nemeton:::compute_indicator("indicateur_r1_feu", units, layers)
  expect_equal(result, c(30, 40))
})
