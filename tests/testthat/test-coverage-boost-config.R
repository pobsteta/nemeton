# Coverage boost tests for R/app_config.R
# Targets: get_app_config(), get_family_codes(), get_family_config(),
# get_all_indicator_codes(), get_all_column_names(), get_column_family_map(),
# get_data_source_config()

# ==============================================================================
# get_app_config() — additional coverage
# ==============================================================================

test_that("get_app_config returns correct values for all keys", {
  expect_equal(nemeton:::get_app_config("app_name"), "N\u00e9m\u00e9ton")
  expect_equal(nemeton:::get_app_config("max_parcels"), 20L)
  expect_equal(nemeton:::get_app_config("default_crs"), 2154L)
  expect_equal(nemeton:::get_app_config("max_retries"), 3L)
  expect_equal(nemeton:::get_app_config("cache_format"), "parquet")
  expect_equal(nemeton:::get_app_config("llm_provider"), "mistral")
})

test_that("get_app_config returns default for unknown key", {
  expect_null(nemeton:::get_app_config("nonexistent"))
  expect_equal(nemeton:::get_app_config("nonexistent", 42), 42)
  expect_equal(nemeton:::get_app_config("missing", "fallback"), "fallback")
})

test_that("get_app_config returns timeout values", {
  expect_equal(nemeton:::get_app_config("api_timeout"), 30000L)
  expect_equal(nemeton:::get_app_config("wfs_timeout"), 60000L)
  expect_equal(nemeton:::get_app_config("computation_timeout"), 600000L)
})

test_that("get_app_config returns project_states vector", {
  states <- nemeton:::get_app_config("project_states")
  expect_type(states, "character")
  expect_true("draft" %in% states)
  expect_true("completed" %in% states)
  expect_true("error" %in% states)
})

test_that("get_app_config returns LLM models list", {
  models <- nemeton:::get_app_config("llm_models")
  expect_type(models, "list")
  expect_true("anthropic" %in% names(models))
  expect_true("mistral" %in% names(models))
  expect_true("openai" %in% names(models))
  expect_true("google" %in% names(models))
})

# ==============================================================================
# get_family_codes()
# ==============================================================================

test_that("get_family_codes returns all 12 family codes", {
  codes <- nemeton:::get_family_codes()
  expect_length(codes, 12)
  expect_equal(codes, c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))
})

# ==============================================================================
# get_family_config()
# ==============================================================================

test_that("get_family_config returns valid config for each family", {
  for (code in c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")) {
    config <- nemeton:::get_family_config(code)
    expect_false(is.null(config), info = paste("NULL config for family:", code))
    expect_equal(config$code, code)
    expect_true(!is.null(config$name_fr), info = paste("Missing name_fr:", code))
    expect_true(!is.null(config$name_en), info = paste("Missing name_en:", code))
    expect_true(!is.null(config$icon), info = paste("Missing icon:", code))
    expect_true(!is.null(config$indicators), info = paste("Missing indicators:", code))
    expect_true(!is.null(config$column_names), info = paste("Missing column_names:", code))
  }
})

test_that("get_family_config returns NULL for unknown family", {
  expect_null(nemeton:::get_family_config("Z"))
  expect_null(nemeton:::get_family_config("X"))
})

test_that("get_family_config is case-insensitive", {
  expect_equal(
    nemeton:::get_family_config("c")$code,
    nemeton:::get_family_config("C")$code
  )
})

test_that("get_family_config indicator_labels contain both languages", {
  config <- nemeton:::get_family_config("C")
  for (ind in names(config$indicator_labels)) {
    expect_true(!is.null(config$indicator_labels[[ind]]$fr),
                info = paste("Missing fr label for", ind))
    expect_true(!is.null(config$indicator_labels[[ind]]$en),
                info = paste("Missing en label for", ind))
  }
})

test_that("get_family_config indicator_tooltips contain both languages", {
  config <- nemeton:::get_family_config("B")
  for (ind in names(config$indicator_tooltips)) {
    expect_true(!is.null(config$indicator_tooltips[[ind]]$fr),
                info = paste("Missing fr tooltip for", ind))
    expect_true(!is.null(config$indicator_tooltips[[ind]]$en),
                info = paste("Missing en tooltip for", ind))
  }
})

# ==============================================================================
# get_all_indicator_codes()
# ==============================================================================

test_that("get_all_indicator_codes returns all indicator codes", {
  codes <- nemeton:::get_all_indicator_codes()
  expect_type(codes, "character")
  expect_true(length(codes) >= 28)  # at least 28 indicators across 12 families
  expect_true("C1" %in% codes)
  expect_true("B1" %in% codes)
  expect_true("N3" %in% codes)
  expect_true("R4" %in% codes)
})

# ==============================================================================
# get_all_column_names()
# ==============================================================================

test_that("get_all_column_names returns long-form column names", {
  cols <- nemeton:::get_all_column_names()
  expect_type(cols, "character")
  expect_true("carbon_biomass" %in% cols)
  expect_true("carbon_ndvi" %in% cols)
  expect_true("biodiversity_protection" %in% cols)
  expect_true("water_network" %in% cols)
  expect_true("naturalness_score" %in% cols)
})

# ==============================================================================
# get_column_family_map()
# ==============================================================================

test_that("get_column_family_map maps columns to families", {
  mapping <- nemeton:::get_column_family_map()
  expect_type(mapping, "character")

  # Long-form names
  expect_equal(mapping[["carbon_biomass"]], "C")
  expect_equal(mapping[["biodiversity_protection"]], "B")
  expect_equal(mapping[["water_network"]], "W")
  expect_equal(mapping[["naturalness_score"]], "N")

  # Short codes
  expect_equal(mapping[["C1"]], "C")
  expect_equal(mapping[["B2"]], "B")
  expect_equal(mapping[["R4"]], "R")
})

test_that("get_column_family_map includes all indicators", {
  mapping <- nemeton:::get_column_family_map()
  all_cols <- nemeton:::get_all_column_names()
  all_codes <- nemeton:::get_all_indicator_codes()

  for (col in all_cols) {
    expect_true(col %in% names(mapping), info = paste("Missing column:", col))
  }
  for (code in all_codes) {
    expect_true(code %in% names(mapping), info = paste("Missing code:", code))
  }
})

# ==============================================================================
# DATA_SOURCES — check if accessible
# ==============================================================================

test_that("DATA_SOURCES exists and is a list", {
  skip_if_not(exists("DATA_SOURCES", envir = asNamespace("nemeton")),
              "DATA_SOURCES not in namespace")
  ds <- nemeton:::DATA_SOURCES
  expect_type(ds, "list")
})

# ==============================================================================
# INDICATOR_FAMILIES structure
# ==============================================================================

test_that("INDICATOR_FAMILIES has 12 families", {
  families <- nemeton:::INDICATOR_FAMILIES
  expect_length(families, 12)
})

test_that("Each family has unique color", {
  families <- nemeton:::INDICATOR_FAMILIES
  colors <- vapply(families, function(f) f$color, character(1))
  expect_equal(length(unique(colors)), 12)
})

test_that("Indicator counts match column_names counts per family", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    fam <- families[[code]]
    expect_equal(
      length(fam$indicators),
      length(fam$column_names),
      info = paste("Mismatch in family", code)
    )
  }
})
