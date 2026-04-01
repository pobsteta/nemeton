# test-cov80-batch11.R
# Coverage boost for R/service_compute.R
# Target: normalize_indicator, create_synthetic_ndvi, cancellation,
#         init_compute_state, list_available_indicators, progress state

# ==============================================================================
# list_available_indicators()
# ==============================================================================

test_that("list_available_indicators returns character vector", {
  result <- nemeton:::list_available_indicators()
  expect_type(result, "character")
  expect_true(length(result) > 20)
  expect_true("indicateur_c1_biomasse" %in% result)
  expect_true("indicateur_c2_ndvi" %in% result)
  expect_true("indicateur_w3_humidite" %in% result)
  expect_true("indicateur_s1_routes" %in% result)
  expect_true("indicateur_r1_feu" %in% result)
})

# ==============================================================================
# normalize_indicator()
# ==============================================================================

test_that("normalize_indicator: indicateur_c1_biomasse scales by ref_max 150", {
  result <- nemeton:::normalize_indicator("indicateur_c1_biomasse", c(0, 75, 150, 300))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_w1_reseau scales by ref_max 50", {
  result <- nemeton:::normalize_indicator("indicateur_w1_reseau", c(0, 25, 50, 100))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_w2_zones_humides scales by ref_max 5", {
  result <- nemeton:::normalize_indicator("indicateur_w2_zones_humides", c(0, 2.5, 5, 10))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_w3_humidite special handling", {
  # TWI rescale [2.5, 4.5] -> [0, 100]
  result <- nemeton:::normalize_indicator("indicateur_w3_humidite", c(2.5, 3.5, 4.5, 5.5))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_c2_ndvi special handling", {
  # NDVI 0-1 -> 0-100
  result <- nemeton:::normalize_indicator("indicateur_c2_ndvi", c(0, 0.5, 1.0, 1.5))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_s1_routes inverse handling", {
  # distance: 0m -> 100, 2000m -> 0
  result <- nemeton:::normalize_indicator("indicateur_s1_routes", c(0, 1000, 2000, 3000))
  expect_equal(result, c(100, 50, 0, 0))
})

test_that("normalize_indicator: indicateur_s2_bati inverse handling", {
  result <- nemeton:::normalize_indicator("indicateur_s2_bati", c(0, 500, 2000))
  expect_equal(result, c(100, 75, 0))
})

test_that("normalize_indicator: indicateur_s3_population scales by ref_max 10000", {
  result <- nemeton:::normalize_indicator("indicateur_s3_population", c(0, 5000, 10000, 20000))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_p1_volume scales by ref_max 800", {
  result <- nemeton:::normalize_indicator("indicateur_p1_volume", c(0, 400, 800, 1600))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_e1_bois_energie scales by ref_max 0.3", {
  result <- nemeton:::normalize_indicator("indicateur_e1_bois_energie", c(0, 0.15, 0.3, 0.6))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: indicateur_e2_evitement scales by ref_max 0.75", {
  result <- nemeton:::normalize_indicator("indicateur_e2_evitement", c(0, 0.375, 0.75, 1.5))
  expect_equal(result, c(0, 50, 100, 100))
})

test_that("normalize_indicator: already-normalized indicator just clamps", {
  # biodiversity, air, etc. already return 0-100
  result <- nemeton:::normalize_indicator("indicateur_b1_protection", c(-10, 50, 110))
  expect_equal(result, c(0, 50, 100))
})

test_that("normalize_indicator: unknown indicator just clamps", {
  result <- nemeton:::normalize_indicator("unknown_indicator", c(-5, 50, 105))
  expect_equal(result, c(0, 50, 100))
})

test_that("normalize_indicator: handles NA values", {
  result <- nemeton:::normalize_indicator("indicateur_c1_biomasse", c(NA, 75, NA))
  expect_true(is.na(result[1]))
  expect_equal(result[2], 50)
  expect_true(is.na(result[3]))
})

# ==============================================================================
# create_synthetic_ndvi()
# ==============================================================================

test_that("create_synthetic_ndvi creates valid raster", {
  withr::with_tempdir({
    bbox <- c(2.9, 47.0, 3.1, 47.2)  # WGS84
    cache_file <- file.path(getwd(), "ndvi.tif")

    result <- nemeton:::create_synthetic_ndvi(bbox, cache_file)
    expect_s4_class(result, "SpatRaster")
    expect_true(file.exists(cache_file))

    # Values should be in [0.5, 0.85]
    vals <- terra::values(result)
    expect_true(all(vals >= 0.5 & vals <= 0.85))

    # Check name
    expect_equal(names(result), "ndvi")
  })
})

# ==============================================================================
# Cancellation functions (cancel/is_cancelled/clear_cancel)
# ==============================================================================

test_that("cancellation workflow: cancel, check, clear", {
  local_mocked_bindings(
    get_app_options = function() list(project_dir = file.path(tempdir(), "cancel_test_projects")),
    .package = "nemeton"
  )

  withr::with_tempdir({
    local_mocked_bindings(
      get_project_path = function(id) {
        p <- file.path(getwd(), "test_proj")
        dir.create(file.path(p, "data"), recursive = TRUE, showWarnings = FALSE)
        p
      },
      .package = "nemeton"
    )

    # Initially not cancelled
    expect_false(nemeton:::is_cancelled("test_proj"))

    # Cancel
    nemeton:::cancel_computation("test_proj")
    expect_true(nemeton:::is_cancelled("test_proj"))

    # Clear
    nemeton:::clear_cancel("test_proj")
    expect_false(nemeton:::is_cancelled("test_proj"))
  })
})

test_that("is_cancelled returns FALSE for nonexistent project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  expect_false(nemeton:::is_cancelled("nonexistent"))
})

test_that("cancel_computation handles NULL project path", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  expect_silent(nemeton:::cancel_computation("nonexistent"))
})

test_that("clear_cancel handles NULL project path", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  expect_silent(nemeton:::clear_cancel("nonexistent"))
})

# ==============================================================================
# save_progress_state()
# ==============================================================================

test_that("save_progress_state creates progress JSON", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    state <- list(
      project_id = "test_proj",
      status = "computing",
      phase = "indicators",
      progress = 5,
      progress_max = 20,
      current_task = "indicateur_c1_biomasse",
      indicators_total = 10,
      indicators_completed = 5,
      indicators_skipped = 0L,
      indicators_failed = 0L,
      indicators_status = list(indicateur_c1_biomasse = "completed"),
      errors = list(),
      started_at = Sys.time(),
      completed_at = NULL
    )

    nemeton:::save_progress_state("test_proj", state)

    progress_file <- file.path(proj_path, "data", "progress_state.json")
    expect_true(file.exists(progress_file))

    loaded <- jsonlite::fromJSON(progress_file)
    expect_equal(loaded$project_id, "test_proj")
    expect_equal(loaded$status, "computing")
    expect_equal(loaded$progress, 5)
  })
})

test_that("save_progress_state handles NULL project path", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  expect_silent(nemeton:::save_progress_state("nonexistent", list()))
})

test_that("save_progress_state with explicit project_path", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj2")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    state <- list(
      project_id = "p2",
      status = "done",
      phase = "complete",
      progress = 20,
      progress_max = 20,
      current_task = NULL,
      indicators_total = 10,
      indicators_completed = 10,
      indicators_skipped = 0L,
      indicators_failed = 0L,
      indicators_status = list(),
      errors = list(),
      started_at = Sys.time(),
      completed_at = Sys.time()
    )

    nemeton:::save_progress_state("p2", state, project_path = proj_path)
    expect_true(file.exists(file.path(proj_path, "data", "progress_state.json")))
  })
})

# ==============================================================================
# read_progress_state()
# ==============================================================================

test_that("read_progress_state returns NULL for nonexistent project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  result <- nemeton:::read_progress_state("nonexistent")
  expect_null(result)
})

test_that("read_progress_state returns NULL when no file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "empty_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::read_progress_state("empty_proj")
    expect_null(result)
  })
})

test_that("read_progress_state reads valid JSON", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "valid_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    # Write a progress file
    progress <- list(
      project_id = "valid_proj",
      status = "computing",
      progress = 3,
      progress_max = 10
    )
    jsonlite::write_json(progress, file.path(proj_path, "data", "progress_state.json"),
                         auto_unbox = TRUE)

    result <- nemeton:::read_progress_state("valid_proj")
    expect_type(result, "list")
    expect_equal(result$project_id, "valid_proj")
    expect_equal(result$progress, 3)
  })
})

# ==============================================================================
# get_computation_progress()
# ==============================================================================

test_that("get_computation_progress returns NULL for nonexistent project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  result <- nemeton:::get_computation_progress("nonexistent")
  expect_null(result)
})

# ==============================================================================
# init_compute_state()
# ==============================================================================

test_that("init_compute_state creates state with all indicators", {
  local_mocked_bindings(
    get_computation_progress = function(id) list(computed_indicators = character(0)),
    .package = "nemeton"
  )

  state <- nemeton:::init_compute_state("test_proj", "all")
  expect_type(state, "list")
  expect_equal(state$project_id, "test_proj")
  expect_equal(state$status, "pending")
  expect_true(state$indicators_total > 20)
  expect_false(state$is_resume)
})

test_that("init_compute_state with specific indicators", {
  local_mocked_bindings(
    get_computation_progress = function(id) list(computed_indicators = character(0)),
    .package = "nemeton"
  )

  state <- nemeton:::init_compute_state("test_proj", c("indicateur_c1_biomasse", "indicateur_w3_humidite"))
  expect_equal(state$indicators_total, 2)
  expect_equal(names(state$indicators_status), c("indicateur_c1_biomasse", "indicateur_w3_humidite"))
})

test_that("init_compute_state detects resume", {
  local_mocked_bindings(
    get_computation_progress = function(id) {
      list(computed_indicators = c("indicateur_c1_biomasse"), last_saved_at = "2025-01-01")
    },
    .package = "nemeton"
  )

  state <- nemeton:::init_compute_state("test_proj", c("indicateur_c1_biomasse", "indicateur_w3_humidite"))
  expect_true(state$is_resume)
  expect_equal(state$indicators_completed, 1)
  expect_equal(state$indicators_status[["indicateur_c1_biomasse"]], "completed")
  expect_equal(state$indicators_status[["indicateur_w3_humidite"]], "pending")
})

# ==============================================================================
# save_indicators_incremental()
# ==============================================================================

test_that("save_indicators_incremental returns FALSE for NULL project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )
  result <- nemeton:::save_indicators_incremental("nonexistent", data.frame(), "test")
  expect_false(result)
})

test_that("save_indicators_incremental saves sf data", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "save_test")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    results <- create_test_units(n_features = 3)
    results$indicateur_c1_biomasse <- c(80, 60, 70)

    result <- nemeton:::save_indicators_incremental("save_test", results, "indicateur_c1_biomasse")
    expect_true(result)
    expect_true(file.exists(file.path(proj_path, "data", "indicators.parquet")))
    expect_true(file.exists(file.path(proj_path, "data", "compute_progress.json")))
  })
})

test_that("save_indicators_incremental handles data.frame", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "save_df_test")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    results <- data.frame(
      id = 1:3,
      indicateur_c1_biomasse = c(80, 60, 70),
      geometry_wkt = rep("POINT(0 0)", 3)
    )

    result <- nemeton:::save_indicators_incremental("save_df_test", results, "indicateur_c1_biomasse")
    expect_true(result)
  })
})
