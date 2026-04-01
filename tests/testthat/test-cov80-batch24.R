# tests/testthat/test-cov80-batch24.R
# Coverage tests for R/app_config.R and R/run_app.R

# ===========================================================================
# Part 1: R/app_config.R — APP_CONFIG constant
# ===========================================================================

test_that("APP_CONFIG exists and is a list", {

config <- nemeton:::APP_CONFIG
  expect_type(config, "list")
})

test_that("APP_CONFIG has expected top-level keys", {
  config <- nemeton:::APP_CONFIG
  expected_keys <- c(
    "app_name", "app_version", "app_title_fr", "app_title_en",
    "max_parcels", "max_project_name_length", "max_description_length",
    "api_timeout", "wfs_timeout", "computation_timeout",
    "max_retries", "retry_delay",
    "parallel_workers", "cache_format",
    "project_states", "default_crs",
    "llm_provider", "llm_models"
  )
  for (k in expected_keys) {
    expect_true(k %in% names(config), info = paste("Missing key:", k))
  }
})

test_that("APP_CONFIG has correct numeric values", {
  config <- nemeton:::APP_CONFIG
  expect_equal(config$default_crs, 2154L)
  expect_equal(config$max_parcels, 20L)
  expect_equal(config$max_project_name_length, 100L)
  expect_equal(config$max_description_length, 500L)
  expect_equal(config$api_timeout, 30000L)
  expect_equal(config$wfs_timeout, 60000L)
  expect_equal(config$computation_timeout, 600000L)
  expect_equal(config$max_retries, 3L)
  expect_equal(config$retry_delay, 2000L)
})

test_that("APP_CONFIG project_states is a valid character vector", {
  states <- nemeton:::APP_CONFIG$project_states
  expect_type(states, "character")
  expect_true(length(states) >= 5)
  expect_true("draft" %in% states)
  expect_true("completed" %in% states)
  expect_true("error" %in% states)
  expect_true("downloading" %in% states)
  expect_true("computing" %in% states)
})

test_that("APP_CONFIG llm_models contains expected providers", {
  models <- nemeton:::APP_CONFIG$llm_models
  expect_type(models, "list")
  expect_true("anthropic" %in% names(models))
  expect_true("mistral" %in% names(models))
  expect_true("openai" %in% names(models))
  expect_true("google" %in% names(models))
  expect_true("deepseek" %in% names(models))
  expect_true("ollama" %in% names(models))
})

test_that("APP_CONFIG app metadata are strings", {
  config <- nemeton:::APP_CONFIG
  expect_type(config$app_name, "character")
  expect_type(config$app_version, "character")
  expect_type(config$app_title_fr, "character")
  expect_type(config$app_title_en, "character")
  expect_true(nchar(config$app_name) > 0)
  expect_true(nchar(config$app_version) > 0)
})

# ===========================================================================
# Part 1: R/app_config.R — get_app_config()
# ===========================================================================

test_that("get_app_config returns known key max_parcels", {
  result <- nemeton:::get_app_config("max_parcels")
  expect_equal(result, 20L)
})

test_that("get_app_config returns known key default_crs", {
  result <- nemeton:::get_app_config("default_crs")
  expect_equal(result, 2154L)
})

test_that("get_app_config returns known key app_name", {
  result <- nemeton:::get_app_config("app_name")
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

test_that("get_app_config returns default for unknown key", {
  result <- nemeton:::get_app_config("nonexistent_key_xyz", "fallback_value")
  expect_equal(result, "fallback_value")
})

test_that("get_app_config returns NULL when no default for unknown key", {
  result <- nemeton:::get_app_config("nonexistent_key_xyz")
  expect_null(result)
})

test_that("get_app_config returns numeric default for unknown key", {
  result <- nemeton:::get_app_config("no_such_key", 42)
  expect_equal(result, 42)
})

test_that("get_app_config returns project_states correctly", {
  result <- nemeton:::get_app_config("project_states")
  expect_type(result, "character")
  expect_true(length(result) >= 5)
})

# ===========================================================================
# Part 1: R/app_config.R — INDICATOR_FAMILIES constant
# ===========================================================================

test_that("INDICATOR_FAMILIES has 12 families", {
  families <- nemeton:::INDICATOR_FAMILIES
  expect_equal(length(families), 12)
  expect_true(all(c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N") %in% names(families)))
})

test_that("each family has required fields", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    fam <- families[[code]]
    expect_true("code" %in% names(fam), info = paste("Family", code, "missing 'code'"))
    expect_true("name_fr" %in% names(fam), info = paste("Family", code, "missing 'name_fr'"))
    expect_true("name_en" %in% names(fam), info = paste("Family", code, "missing 'name_en'"))
    expect_true("icon" %in% names(fam), info = paste("Family", code, "missing 'icon'"))
    expect_true("color" %in% names(fam), info = paste("Family", code, "missing 'color'"))
    expect_true("indicators" %in% names(fam), info = paste("Family", code, "missing 'indicators'"))
    expect_true("column_names" %in% names(fam), info = paste("Family", code, "missing 'column_names'"))
  }
})

test_that("Carbon family has correct indicators and column_names", {
  c_fam <- nemeton:::INDICATOR_FAMILIES[["C"]]
  expect_equal(c_fam$code, "C")
  expect_equal(c_fam$indicators, c("C1", "C2"))
  expect_equal(c_fam$column_names, c("indicateur_c1_biomasse", "indicateur_c2_ndvi"))
})

test_that("Biodiversity family has 3 indicators", {
  b_fam <- nemeton:::INDICATOR_FAMILIES[["B"]]
  expect_equal(length(b_fam$indicators), 3)
  expect_equal(b_fam$indicators, c("B1", "B2", "B3"))
  expect_equal(b_fam$column_names, c("indicateur_b1_protection", "indicateur_b2_structure", "indicateur_b3_connectivite"))
})

test_that("Risk family has 4 indicators", {
  r_fam <- nemeton:::INDICATOR_FAMILIES[["R"]]
  expect_equal(length(r_fam$indicators), 4)
  expect_equal(r_fam$indicators, c("R1", "R2", "R3", "R4"))
  expect_equal(r_fam$column_names, c("indicateur_r1_feu", "indicateur_r2_tempete", "indicateur_r3_secheresse", "indicateur_r4_abroutissement"))
})

test_that("Water family has 3 indicators", {
  w_fam <- nemeton:::INDICATOR_FAMILIES[["W"]]
  expect_equal(length(w_fam$indicators), 3)
  expect_equal(w_fam$indicators, c("W1", "W2", "W3"))
  expect_equal(w_fam$column_names, c("indicateur_w1_reseau", "indicateur_w2_zones_humides", "indicateur_w3_humidite"))
})

test_that("Naturalness family has 3 indicators", {
  n_fam <- nemeton:::INDICATOR_FAMILIES[["N"]]
  expect_equal(length(n_fam$indicators), 3)
  expect_equal(n_fam$indicators, c("N1", "N2", "N3"))
  expect_equal(n_fam$column_names, c("indicateur_n1_distance", "indicateur_n2_continuite", "indicateur_n3_naturalite"))
})

test_that("each family has indicator_labels for all its indicators", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    fam <- families[[code]]
    expect_true("indicator_labels" %in% names(fam),
                info = paste("Family", code, "missing indicator_labels"))
    for (ind in fam$indicators) {
      expect_true(ind %in% names(fam$indicator_labels),
                  info = paste("Missing label for", ind, "in family", code))
      expect_true("fr" %in% names(fam$indicator_labels[[ind]]),
                  info = paste("Missing 'fr' label for", ind))
      expect_true("en" %in% names(fam$indicator_labels[[ind]]),
                  info = paste("Missing 'en' label for", ind))
    }
  }
})

test_that("each family has indicator_tooltips for all its indicators", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    fam <- families[[code]]
    expect_true("indicator_tooltips" %in% names(fam),
                info = paste("Family", code, "missing indicator_tooltips"))
    for (ind in fam$indicators) {
      expect_true(ind %in% names(fam$indicator_tooltips),
                  info = paste("Missing tooltip for", ind, "in family", code))
      tooltip <- fam$indicator_tooltips[[ind]]
      expect_true("fr" %in% names(tooltip),
                  info = paste("Missing 'fr' tooltip for", ind))
      expect_true("en" %in% names(tooltip),
                  info = paste("Missing 'en' tooltip for", ind))
    }
  }
})

test_that("family colors are valid hex colors", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    color <- families[[code]]$color
    expect_true(grepl("^#[0-9A-Fa-f]{6}$", color),
                info = paste("Invalid color for family", code, ":", color))
  }
})

test_that("indicators and column_names have same length per family", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    fam <- families[[code]]
    expect_equal(length(fam$indicators), length(fam$column_names),
                 info = paste("Mismatch in family", code))
  }
})

# ===========================================================================
# Part 1: R/app_config.R — get_family_codes()
# ===========================================================================

test_that("get_family_codes returns 12 codes", {
  codes <- nemeton:::get_family_codes()
  expect_equal(length(codes), 12)
  expect_true("C" %in% codes)
  expect_true("B" %in% codes)
  expect_true("N" %in% codes)
  expect_true("R" %in% codes)
})

# ===========================================================================
# Part 1: R/app_config.R — get_family_config()
# ===========================================================================

test_that("get_family_config returns config for valid uppercase code", {
  config <- nemeton:::get_family_config("C")
  expect_type(config, "list")
  expect_equal(config$code, "C")
  expect_true("indicators" %in% names(config))
})

test_that("get_family_config handles lowercase code", {
  config <- nemeton:::get_family_config("c")
  expect_type(config, "list")
  expect_equal(config$code, "C")
})

test_that("get_family_config returns NULL for unknown code", {
  config <- nemeton:::get_family_config("Z")
  expect_null(config)
})

test_that("get_family_config returns valid config for each family", {
  codes <- nemeton:::get_family_codes()
  for (code in codes) {
    config <- nemeton:::get_family_config(code)
    expect_true(is.list(config), info = paste("Family", code, "should be a list"))
    expect_equal(config$code, code, info = paste("Family", code))
  }
})

# ===========================================================================
# Part 1: R/app_config.R — get_all_indicator_codes()
# ===========================================================================

test_that("get_all_indicator_codes returns all indicator codes", {
  codes <- nemeton:::get_all_indicator_codes()
  expect_true(length(codes) >= 29)
  expect_true("C1" %in% codes)
  expect_true("C2" %in% codes)
  expect_true("B1" %in% codes)
  expect_true("R4" %in% codes)
  expect_true("N3" %in% codes)
  expect_true("S3" %in% codes)
})

# ===========================================================================
# Part 1: R/app_config.R — get_all_column_names()
# ===========================================================================

test_that("get_all_column_names returns all column names", {
  cols <- nemeton:::get_all_column_names()
  expect_true(length(cols) >= 29)
  expect_true("indicateur_c1_biomasse" %in% cols)
  expect_true("indicateur_c2_ndvi" %in% cols)
  expect_true("indicateur_r4_abroutissement" %in% cols)
  expect_true("indicateur_n3_naturalite" %in% cols)
  expect_true("indicateur_w3_humidite" %in% cols)
})

# ===========================================================================
# Part 1: R/app_config.R — get_column_family_map()
# ===========================================================================

test_that("get_column_family_map maps long-form column names to families", {
  map <- nemeton:::get_column_family_map()
  expect_type(map, "character")
  expect_equal(map[["indicateur_c1_biomasse"]], "C")
  expect_equal(map[["indicateur_c2_ndvi"]], "C")
  expect_equal(map[["indicateur_r1_feu"]], "R")
  expect_equal(map[["indicateur_r2_tempete"]], "R")
  expect_equal(map[["indicateur_n3_naturalite"]], "N")
  expect_equal(map[["indicateur_w1_reseau"]], "W")
  expect_equal(map[["indicateur_l2_fragmentation"]], "L")
})

test_that("get_column_family_map maps short indicator codes to families", {
  map <- nemeton:::get_column_family_map()
  expect_equal(map[["C1"]], "C")
  expect_equal(map[["C2"]], "C")
  expect_equal(map[["B1"]], "B")
  expect_equal(map[["R1"]], "R")
  expect_equal(map[["R4"]], "R")
  expect_equal(map[["N3"]], "N")
  expect_equal(map[["S1"]], "S")
})

test_that("get_column_family_map has entries for all indicators and columns", {
  map <- nemeton:::get_column_family_map()
  all_codes <- nemeton:::get_all_indicator_codes()
  all_cols <- nemeton:::get_all_column_names()
  for (code in all_codes) {
    expect_true(code %in% names(map), info = paste("Missing code:", code))
  }
  for (col in all_cols) {
    expect_true(col %in% names(map), info = paste("Missing column:", col))
  }
})

# ===========================================================================
# Part 1: R/app_config.R — DATA_SOURCES
# ===========================================================================

test_that("DATA_SOURCES exists and is a list", {
  sources <- nemeton:::DATA_SOURCES
  expect_type(sources, "list")
  expect_true(length(sources) > 0)
})

test_that("DATA_SOURCES has rasters, vectors, and point_clouds categories", {
  sources <- nemeton:::DATA_SOURCES
  expect_true("rasters" %in% names(sources))
  expect_true("vectors" %in% names(sources))
  expect_true("point_clouds" %in% names(sources))
})

test_that("DATA_SOURCES rasters has expected entries", {
  rasters <- nemeton:::DATA_SOURCES$rasters
  expect_type(rasters, "list")
  expect_true("ndvi" %in% names(rasters))
  expect_true("dem" %in% names(rasters))
  expect_true("forest_cover" %in% names(rasters))
})

test_that("DATA_SOURCES vectors has expected entries", {
  vectors <- nemeton:::DATA_SOURCES$vectors
  expect_type(vectors, "list")
  expect_true("protected_areas" %in% names(vectors))
  expect_true("indicateur_w1_reseau" %in% names(vectors))
  expect_true("bdforet" %in% names(vectors))
  expect_true("roads" %in% names(vectors))
  expect_true("buildings" %in% names(vectors))
})

test_that("each raster source has name, type, source, required_for", {
  rasters <- nemeton:::DATA_SOURCES$rasters
  for (src_name in names(rasters)) {
    src <- rasters[[src_name]]
    expect_true("name" %in% names(src), info = paste("Raster", src_name, "missing 'name'"))
    expect_true("type" %in% names(src), info = paste("Raster", src_name, "missing 'type'"))
    expect_true("source" %in% names(src), info = paste("Raster", src_name, "missing 'source'"))
    expect_true("required_for" %in% names(src), info = paste("Raster", src_name, "missing 'required_for'"))
    expect_equal(src$type, "raster", info = paste("Raster", src_name, "wrong type"))
  }
})

test_that("each vector source has name, type, source, required_for", {
  vectors <- nemeton:::DATA_SOURCES$vectors
  for (src_name in names(vectors)) {
    src <- vectors[[src_name]]
    expect_true("name" %in% names(src), info = paste("Vector", src_name, "missing 'name'"))
    expect_true("type" %in% names(src), info = paste("Vector", src_name, "missing 'type'"))
    expect_true("source" %in% names(src), info = paste("Vector", src_name, "missing 'source'"))
    expect_true("required_for" %in% names(src), info = paste("Vector", src_name, "missing 'required_for'"))
    expect_equal(src$type, "vector", info = paste("Vector", src_name, "wrong type"))
  }
})

test_that("get_data_source_config returns rasters category", {
  config <- nemeton:::get_data_source_config("rasters")
  expect_type(config, "list")
  expect_true("ndvi" %in% names(config))
  expect_true("dem" %in% names(config))
})

test_that("get_data_source_config returns vectors category", {
  config <- nemeton:::get_data_source_config("vectors")
  expect_type(config, "list")
  expect_true("bdforet" %in% names(config))
  expect_true("roads" %in% names(config))
})

test_that("get_data_source_config returns NULL for unknown source", {
  config <- nemeton:::get_data_source_config("nonexistent_source")
  expect_null(config)
})

# ===========================================================================
# Part 2: R/run_app.R — detect_system_language()
# ===========================================================================

test_that("detect_system_language returns 'fr' for French locale", {
  withr::with_envvar(list(LANG = "fr_FR.UTF-8"), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "fr")
  })
})

test_that("detect_system_language returns 'fr' for plain 'fr' locale", {
  withr::with_envvar(list(LANG = "fr"), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "fr")
  })
})

test_that("detect_system_language returns 'en' for English locale", {
  withr::with_envvar(list(LANG = "en_US.UTF-8"), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "en")
  })
})

test_that("detect_system_language returns 'en' for empty LANG", {
  withr::with_envvar(list(LANG = ""), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "en")
  })
})

test_that("detect_system_language returns 'en' for C locale", {
  withr::with_envvar(list(LANG = "C"), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "en")
  })
})

test_that("detect_system_language returns 'en' for German locale", {
  withr::with_envvar(list(LANG = "de_DE.UTF-8"), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "en")
  })
})

test_that("detect_system_language returns 'fr' for FR_CA locale (case-insensitive)", {
  withr::with_envvar(list(LANG = "FR_CA.UTF-8"), {
    result <- nemeton:::detect_system_language()
    expect_equal(result, "fr")
  })
})

# ===========================================================================
# Part 2: R/run_app.R — get_default_project_dir()
# ===========================================================================

test_that("get_default_project_dir returns a path ending with projects", {
  result <- nemeton:::get_default_project_dir()
  expect_type(result, "character")
  expect_true(grepl("projects$", result))
})

test_that("get_default_project_dir returns a non-empty path", {
  result <- nemeton:::get_default_project_dir()
  expect_true(nchar(result) > 0)
})

# ===========================================================================
# Part 2: R/run_app.R — check_app_dependencies()
# ===========================================================================

test_that("check_app_dependencies succeeds when all packages are installed", {
  expect_invisible(nemeton:::check_app_dependencies())
})

test_that("check_app_dependencies returns NULL invisibly on success", {
  result <- nemeton:::check_app_dependencies()
  expect_null(result)
})

# ===========================================================================
# Part 2: R/run_app.R — get_app_options()
# ===========================================================================

test_that("get_app_options returns list with language and project_dir", {
  result <- nemeton:::get_app_options()
  expect_type(result, "list")
  expect_true("language" %in% names(result))
  expect_true("project_dir" %in% names(result))
})

test_that("get_app_options default language is 'fr'", {
  withr::with_options(list(nemeton.app_options = NULL), {
    result <- nemeton:::get_app_options()
    expect_equal(result$language, "fr")
  })
})

test_that("get_app_options returns custom options when set", {
  custom <- list(language = "en", project_dir = "/tmp/test_nemeton")
  withr::with_options(list(nemeton.app_options = custom), {
    result <- nemeton:::get_app_options()
    expect_equal(result$language, "en")
    expect_equal(result$project_dir, "/tmp/test_nemeton")
  })
})

test_that("get_app_options project_dir ends with projects by default", {
  withr::with_options(list(nemeton.app_options = NULL), {
    result <- nemeton:::get_app_options()
    expect_true(grepl("projects$", result$project_dir))
  })
})
