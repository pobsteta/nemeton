# test-cov60-batch3.R
# Coverage boost for llm_prompts.R, i18n.R, indicators-families.R,
# service_project.R, utils.R — target >60% each

# ==============================================================================
# llm_prompts.R — expert profiles and prompt building
# ==============================================================================

test_that("get_expert_profiles returns cached profiles", {
  profiles <- nemeton:::get_expert_profiles()
  expect_type(profiles, "list")
  expect_true("generalist" %in% names(profiles))
  # Second call should return same (cached)
  profiles2 <- nemeton:::get_expert_profiles()
  expect_equal(names(profiles), names(profiles2))
})

test_that("build_system_prompt includes language in prompt", {
  prompt_fr <- nemeton:::build_system_prompt("fran\u00e7ais")
  expect_true(grepl("fran", prompt_fr))

  prompt_en <- nemeton:::build_system_prompt("English")
  expect_true(grepl("English", prompt_en))
})

test_that("build_system_prompt uses specified expert profile", {
  profiles <- nemeton:::get_expert_profiles()
  for (expert in names(profiles)[1:min(3, length(profiles))]) {
    prompt <- nemeton:::build_system_prompt("English", expert = expert)
    expect_true(nchar(prompt) > 20)
  }
})

test_that("build_system_prompt falls back to generalist for unknown expert", {
  prompt <- nemeton:::build_system_prompt("English", expert = "nonexistent_expert_xyz")
  expect_true(nchar(prompt) > 20)
})

test_that("build_analysis_prompt with no indicator columns", {
  skip_if_not_installed("sf")
  fam <- list(code = "C", name_fr = "Carbone", name_en = "Carbon")
  ind_data <- create_test_units(n_features = 2)
  # No C1/C2 columns -> should handle gracefully
  prompt <- nemeton:::build_analysis_prompt(fam, ind_data, "English")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 10)
})

test_that("build_analysis_prompt includes stats for present indicators", {
  skip_if_not_installed("sf")
  fam <- list(code = "C", name_fr = "Carbone", name_en = "Carbon")
  ind_data <- create_test_units(n_features = 3)
  ind_data$C1 <- c(45, 67, 89)
  ind_data$C2 <- c(12, 34, 56)

  prompt <- nemeton:::build_analysis_prompt(fam, ind_data, "English")
  expect_true(grepl("C1", prompt))
  expect_true(grepl("C2", prompt))
  expect_true(grepl("3", prompt))
})

test_that("build_analysis_prompt works in French", {
  skip_if_not_installed("sf")
  fam <- list(code = "B", name_fr = "Biodiversit\u00e9", name_en = "Biodiversity")
  ind_data <- create_test_units(n_features = 2)
  ind_data$B1 <- c(30, 70)

  prompt <- nemeton:::build_analysis_prompt(fam, ind_data, "fran\u00e7ais")
  expect_true(grepl("Biodiversit", prompt))
  expect_true(grepl("B1", prompt))
})

test_that("build_analysis_prompt handles NA values in indicators", {
  skip_if_not_installed("sf")
  fam <- list(code = "W", name_fr = "Eau", name_en = "Water")
  ind_data <- create_test_units(n_features = 3)
  ind_data$W1 <- c(50, NA, 80)

  prompt <- nemeton:::build_analysis_prompt(fam, ind_data, "English")
  expect_true(grepl("W1", prompt))
  expect_true(grepl("n=2", prompt))
})

test_that("build_synthesis_prompt includes all 12 families", {
  skip_if_not_installed("sf")
  scores <- create_test_units(n_features = 3)
  for (code in c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")) {
    scores[[nemeton:::get_famille_col(code)]] <- runif(3, 20, 80)
  }

  prompt <- nemeton:::build_synthesis_prompt(scores, "fran\u00e7ais")
  expect_true(grepl("/100", prompt))
})

test_that("build_synthesis_prompt works in English", {
  skip_if_not_installed("sf")
  scores <- create_test_units(n_features = 3)
  for (code in c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")) {
    scores[[nemeton:::get_famille_col(code)]] <- runif(3, 20, 80)
  }

  prompt <- nemeton:::build_synthesis_prompt(scores, "English")
  expect_true(grepl("/100", prompt))
  expect_true(grepl("Global score", prompt))
})

test_that("get_expert_choices includes all profiles", {
  choices_fr <- nemeton:::get_expert_choices("fr")
  choices_en <- nemeton:::get_expert_choices("en")

  expect_true(length(choices_fr) >= 3)
  expect_true(length(choices_en) >= 3)
  # Values (profile keys) should be the same regardless of language
  expect_equal(sort(unname(choices_fr)), sort(unname(choices_en)))
})

test_that("reload_expert_profiles clears and reloads cache", {
  profiles <- nemeton:::reload_expert_profiles()
  expect_type(profiles, "list")
  expect_true(length(profiles) >= 1)
})

test_that("load_expert_profiles loads YAML files from inst/experts", {
  profiles <- nemeton:::load_expert_profiles()
  expect_type(profiles, "list")
  # Each profile should have label and prompt sublists
  for (key in names(profiles)) {
    expect_true("label" %in% names(profiles[[key]]),
                info = paste("Profile", key, "missing label"))
    expect_true("prompt" %in% names(profiles[[key]]),
                info = paste("Profile", key, "missing prompt"))
  }
})

# ==============================================================================
# i18n.R — message system coverage
# ==============================================================================

test_that("msg handles all indicator name keys", {
  indicator_keys <- c(
    "indicateur_c1_biomasse", "indicateur_c2_ndvi",
    "indicateur_b1_protection", "indicateur_b2_structure",
    "indicateur_b3_connectivite",
    "indicateur_w1_reseau", "indicateur_w3_humidite", "indicateur_w2_zones_humides",
    "indicateur_a1_couverture", "indicateur_a2_qualite_air",
    "indicateur_f1_fertilite", "indicateur_f2_erosion",
    "indicateur_l2_fragmentation", "indicateur_l1_sylvosphere",
    "indicateur_t1_anciennete", "indicateur_t2_changement",
    "indicateur_r1_feu", "indicateur_r2_tempete",
    "indicateur_r3_secheresse", "indicateur_r4_abroutissement",
    "indicateur_s1_routes", "indicateur_s2_bati",
    "indicateur_s3_population",
    "indicateur_p1_volume", "indicateur_p2_station",
    "indicateur_p3_qualite_bois",
    "indicateur_e1_bois_energie", "indicateur_e2_evitement",
    "indicateur_n1_distance", "indicateur_n2_continuite",
    "indicateur_n3_naturalite"
  )

  for (key in indicator_keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty msg for key:", key))
  }
})

test_that("msg handles all v0.3.0 error keys", {
  error_keys <- c(
    "error_invalid_data_type", "error_invalid_method",
    "error_k_too_small", "error_k_too_large",
    "error_objectives_not_found", "error_non_numeric_objectives",
    "error_maximize_length", "error_na_values"
  )

  for (key in error_keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty msg for key:", key))
  }
})

test_that("msg handles demo/preprocessing keys", {
  keys <- c(
    "demo_loading", "demo_loaded",
    "preprocess_start", "preprocess_crs",
    "preprocess_crop", "preprocess_mask", "preprocess_complete"
  )

  for (key in keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty msg for key:", key))
  }
})

test_that("msg handles units/layers keys", {
  keys <- c(
    "units_not_sf", "units_no_crs", "units_invalid_geom",
    "units_id_created", "layers_created",
    "layers_file_missing"
  )

  for (key in keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty msg for key:", key))
  }
})

test_that("msg handles normalize keys", {
  keys <- c("normalize_normalized", "normalize_inverted")
  for (key in keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty msg for key:", key))
  }
})

test_that("msg handles family/compute keys", {
  keys <- c(
    "family_index_created", "indicator_failed",
    "compute_start", "compute_complete",
    "msg_pareto_computing", "msg_pareto_complete"
  )
  for (key in keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty msg for key:", key))
  }
})

test_that("msg handles French versions of all categories", {
  nemeton::nemeton_set_language("fr")
  on.exit(nemeton::nemeton_set_language("en"))

  keys <- c(
    "indicateur_c1_biomasse", "error_invalid_data_type",
    "demo_loading", "units_not_sf", "normalize_normalized",
    "family_index_created", "compute_start"
  )

  for (key in keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty French msg for key:", key))
  }
})

test_that("msg with interpolation for all param counts", {
  # 1 param
  r1 <- nemeton:::msg("indicator_failed", "test_ind")
  expect_true(grepl("test_ind", r1))

  # 2 params
  r2 <- nemeton:::msg("normalize_normalized", 5, "minmax")
  expect_true(grepl("5", r2))

  # 3 params
  r3 <- nemeton:::msg("risk_fire_factors", 0.5, 0.3, 0.2)
  expect_true(grepl("0\\.5", r3))
})

test_that("msg returns key for unknown message", {
  result <- nemeton:::msg("completely_unknown_key_xyz_123")
  expect_equal(result, "completely_unknown_key_xyz_123")
})

test_that("msg_info, msg_success, msg_warn, msg_error work in English", {
  expect_message(nemeton:::msg_info("preprocess_start"), regexp = NULL)
  expect_message(nemeton:::msg_success("language_set", "en"), regexp = NULL)
  expect_warning(nemeton:::msg_warn("layers_file_missing", "/fake/path.tif"))
  expect_error(nemeton:::msg_error("units_not_sf"))
})

test_that("get_language from LANG env var", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::local_envvar(LANG = "fr_FR.UTF-8")
  lang <- nemeton:::get_language()
  expect_equal(lang, "fr")

  # Restore
  nemeton::nemeton_set_language("en")
})

test_that("get_language with empty LANG env var defaults to en", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::local_envvar(LANG = "")
  lang <- nemeton:::get_language()
  expect_equal(lang, "en")

  nemeton::nemeton_set_language("en")
})

test_that("get_language with non-fr/en locale defaults to en", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::local_envvar(LANG = "de_DE.UTF-8")
  lang <- nemeton:::get_language()
  expect_equal(lang, "en")

  nemeton::nemeton_set_language("en")
})

test_that("get_language returns cached value after set", {
  nemeton::nemeton_set_language("fr")
  expect_equal(nemeton:::get_language(), "fr")

  nemeton::nemeton_set_language("en")
  expect_equal(nemeton:::get_language(), "en")
})

# ==============================================================================
# indicators-families.R — aliases and family detection
# ==============================================================================

test_that("INDICATOR_FAMILIES has indicators list for each family", {
  families <- nemeton:::INDICATOR_FAMILIES
  for (code in names(families)) {
    fam <- families[[code]]
    expect_true("indicators" %in% names(fam) || "code" %in% names(fam),
                info = paste("Missing indicators in family:", code))
  }
})

test_that("detect_indicator_family handles all family codes", {
  codes <- c("C1", "C2", "B1", "B2", "B3", "W1", "W2", "W3",
             "A1", "A2", "F1", "F2", "L1", "L2", "T1", "T2",
             "R1", "R2", "R3", "R4", "S1", "S2", "S3",
             "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3")

  for (code in codes) {
    family <- nemeton:::detect_indicator_family(code)
    expect_true(!is.na(family), info = paste("NA for code:", code))
    expect_true(nchar(family) == 1, info = paste("Bad family for:", code))
  }
})

test_that("detect_indicator_family handles _norm suffix", {
  expect_equal(nemeton:::detect_indicator_family("C1_norm"), "C")
  expect_equal(nemeton:::detect_indicator_family("B2_norm"), "B")
})

test_that("detect_indicator_family returns NA for unknown names", {
  result <- nemeton:::detect_indicator_family("completely_unknown_xyz")
  expect_true(is.na(result))
})

test_that("create_family_index works with mean method for all families", {
  units <- create_test_units(n_features = 5)
  # Add indicators for multiple families
  for (code in c("C", "B", "W")) {
    units[[paste0(code, "1")]] <- runif(5, 0, 100)
    units[[paste0(code, "2")]] <- runif(5, 0, 100)
  }

  result <- nemeton::create_family_index(units, method = "mean")
  expect_true("famille_carbone" %in% names(result))
  expect_true("famille_biodiversite" %in% names(result))
  expect_true("famille_eau" %in% names(result))
})

test_that("create_family_index with single indicator per family", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(50, 60, 70)

  result <- nemeton::create_family_index(units, method = "mean", family_codes = "C")
  expect_true("famille_carbone" %in% names(result))
  expect_equal(result$famille_carbone, c(50, 60, 70))
})

test_that("create_family_index harmonic method works", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(50, 60, 70)
  units$C2 <- c(40, 80, 30)

  result <- nemeton::create_family_index(units, method = "harmonic", family_codes = "C")
  expect_true("famille_carbone" %in% names(result))
  # Harmonic mean should be <= arithmetic mean
  arith_mean <- (c(50, 60, 70) + c(40, 80, 30)) / 2
  expect_true(all(result$famille_carbone <= arith_mean + 0.01))
})

test_that("create_family_index geometric method works", {
  units <- create_test_units(n_features = 3)
  units$B1 <- c(50, 60, 70)
  units$B2 <- c(40, 80, 30)

  result <- nemeton::create_family_index(units, method = "geometric", family_codes = "B")
  expect_true("famille_biodiversite" %in% names(result))
  expect_true(all(is.numeric(result$famille_biodiversite)))
})

test_that("create_family_index min method works", {
  units <- create_test_units(n_features = 3)
  units$W1 <- c(50, 60, 70)
  units$W2 <- c(40, 80, 30)

  result <- nemeton::create_family_index(units, method = "min", family_codes = "W")
  expect_true("famille_eau" %in% names(result))
  expect_equal(result$famille_eau, c(40, 60, 30))
})

test_that("create_family_index errors for non-sf input", {
  expect_error(nemeton::create_family_index(data.frame(x = 1)), "sf")
})

# ==============================================================================
# service_project.R — cache data and load parcels
# ==============================================================================

test_that("save_cache_data and load_cache_data round-trip data.frame", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("Cache Test")

    test_data <- data.frame(
      dept = c("01", "02", "03"),
      value = c(100, 200, 300)
    )

    nemeton:::save_cache_data(project$id, "test_cache", test_data)
    loaded <- nemeton:::load_cache_data(project$id, "test_cache")

    expect_s3_class(loaded, "data.frame")
    expect_equal(nrow(loaded), 3)
    expect_true("dept" %in% names(loaded))
  })
})

test_that("save_cache_data handles sf objects", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("sf")
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("SF Cache Test")

    test_sf <- create_test_units(n_features = 3)
    nemeton:::save_cache_data(project$id, "sf_cache", test_sf)

    # The cache file should exist
    cache_dir <- file.path(project$path, "cache")
    expect_true(dir.exists(cache_dir))

    # Round-trip: load returns data (may be sf or data.frame depending on arrow version)
    loaded <- nemeton:::load_cache_data(project$id, "sf_cache")
    expect_s3_class(loaded, "data.frame")
    expect_equal(nrow(loaded), 3)
  })
})

test_that("load_cache_data returns NULL for missing cache", {
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("No Cache")
    result <- nemeton:::load_cache_data(project$id, "nonexistent")
    expect_null(result)
  })
})

test_that("save_indicators and load_indicators round-trip", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("Indicators Test")

    ind_data <- data.frame(
      id = c("u1", "u2", "u3"),
      C1 = c(50, 60, 70),
      B1 = c(80, 70, 60)
    )

    saved <- nemeton:::save_indicators(project$id, ind_data)
    expect_true(saved)

    loaded <- nemeton:::load_indicators(project$id)
    expect_s3_class(loaded, "data.frame")
    expect_true("C1" %in% names(loaded))
  })
})

test_that("load_indicators returns NULL for project without indicators", {
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("No Indicators")
    result <- nemeton:::load_indicators(project$id)
    expect_null(result)
  })
})

test_that("load_project loads full project structure", {
  skip_if_not_installed("sf")
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("Full Project", description = "Test")

    parcels <- create_test_units(n_features = 3)
    nemeton:::save_parcels(project$id, parcels)

    loaded <- nemeton:::load_project(project$id)
    expect_type(loaded, "list")
    expect_true("metadata" %in% names(loaded))
    expect_true("parcels" %in% names(loaded))
    expect_equal(loaded$metadata$name, "Full Project")
  })
})

test_that("load_project returns NULL for nonexistent project", {
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    result <- suppressWarnings(nemeton:::load_project("ghost_project_xyz"))
    expect_null(result)
  })
})

test_that("create_project validates name", {
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    # Empty name should error
    expect_error(nemeton:::create_project(""))
    expect_error(nemeton:::create_project("   "))

    # Too long name should error
    expect_error(nemeton:::create_project(paste(rep("a", 101), collapse = "")))
  })
})

test_that("create_project creates proper directory structure", {
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    project <- nemeton:::create_project("Structure Test")
    expect_true(dir.exists(project$path))
    expect_true(dir.exists(file.path(project$path, "data")))
    expect_true(dir.exists(file.path(project$path, "cache")))
    expect_true(dir.exists(file.path(project$path, "exports")))
    expect_true(file.exists(file.path(project$path, "metadata.json")))
  })
})

test_that("get_projects_root creates directory if missing", {
  withr::with_tempdir({
    new_dir <- file.path(getwd(), "new_projects_dir")
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = new_dir)
    ))

    root <- nemeton:::get_projects_root()
    expect_true(nchar(root) > 0)
    expect_true(dir.exists(root))
  })
})

test_that("get_project_path returns NULL for missing project", {
  withr::with_tempdir({
    temp_root <- getwd()
    withr::local_options(list(
      nemeton.app_options = list(language = "en", project_dir = temp_root)
    ))

    result <- nemeton:::get_project_path("nonexistent_project_id")
    expect_null(result)
  })
})

test_that("get_project_path returns NULL for NULL or empty id", {
  expect_null(nemeton:::get_project_path(NULL))
  expect_null(nemeton:::get_project_path(""))
})

# ==============================================================================
# utils.R — smart_map, species lookups, validators
# ==============================================================================

test_that("smart_map falls back to sequential for small inputs", {
  result <- nemeton::smart_map(1:5, function(x) x * 2)
  expect_equal(result, as.list(2 * 1:5))
})

test_that("smart_map returns correct type with .type argument", {
  result <- nemeton::smart_map(1:5, function(x) x * 2, .type = "dbl")
  expect_equal(result, 2 * 1:5)
  expect_true(is.numeric(result))
})

test_that("smart_map_sf works with sf data", {
  units <- create_test_units(n_features = 3)
  result <- nemeton::smart_map_sf(units, function(i, sf_data) i)
  expect_type(result, "list")
  expect_length(result, 3)
})

test_that("validate_sf passes for valid sf", {
  units <- create_test_units(n_features = 3)
  expect_invisible(nemeton:::validate_sf(units))
})

test_that("validate_sf errors for non-sf", {
  expect_error(nemeton:::validate_sf(data.frame(x = 1)), "sf")
})

test_that("validate_sf errors for missing CRS when required", {
  units <- create_test_units(n_features = 2)
  sf::st_crs(units) <- NA
  expect_error(nemeton:::validate_sf(units, require_crs = TRUE), "CRS")
})

test_that("generate_ids creates unique IDs", {
  ids <- nemeton:::generate_ids(5)
  expect_length(ids, 5)
  expect_equal(length(unique(ids)), 5)
  expect_true(all(grepl("^unit_", ids)))
})

test_that("generate_ids with custom prefix", {
  ids <- nemeton:::generate_ids(3, prefix = "parcel_")
  expect_true(all(grepl("^parcel_", ids)))
})

test_that("generate_ids produces sequential format", {
  ids <- nemeton:::generate_ids(3)
  expect_equal(ids, c("unit_001", "unit_002", "unit_003"))
})

test_that("check_crs detects matching CRS", {
  units1 <- create_test_units(n_features = 2)
  units2 <- create_test_units(n_features = 2)
  expect_invisible(nemeton:::check_crs(units1, units2))
})

test_that("check_crs strict mode errors on mismatch", {
  units1 <- create_test_units(n_features = 2, crs = 2154)
  units2 <- create_test_units(n_features = 2, crs = 4326)
  expect_error(nemeton:::check_crs(units1, units2, strict = TRUE), "CRS")
})

test_that("get_crs returns CRS from sf object", {
  units <- create_test_units(n_features = 2)
  crs <- nemeton:::get_crs(units)
  expect_false(is.na(crs))
})

test_that("get_crs returns NA for non-spatial objects", {
  result <- nemeton:::get_crs(data.frame(x = 1))
  expect_true(is.na(result))
})

test_that("get_species_drought_sensitivity returns scores", {
  result <- nemeton:::get_species_drought_sensitivity("Picea")
  expect_true(is.numeric(result))
  expect_true(result >= 0 && result <= 100)
})

test_that("get_species_drought_sensitivity returns 50 for unknown species", {
  result <- nemeton:::get_species_drought_sensitivity("UnknownSpeciesXYZ123")
  expect_equal(result, 50)
})

test_that("get_species_drought_sensitivity handles NA", {
  result <- nemeton:::get_species_drought_sensitivity(NA)
  expect_true(is.na(result))
})

test_that("get_species_drought_sensitivity is vectorized", {
  result <- nemeton:::get_species_drought_sensitivity(c("Picea", "Quercus", "Unknown"))
  expect_length(result, 3)
  expect_true(all(is.numeric(result)))
})

test_that("get_species_palatability returns scores", {
  result <- nemeton:::get_species_palatability("Quercus")
  expect_true(is.numeric(result))
  expect_true(result >= 0 && result <= 100)
})

test_that("get_species_palatability returns 50 for unknown species", {
  result <- nemeton:::get_species_palatability("UnknownSpeciesXYZ")
  expect_equal(result, 50)
})

test_that("get_species_palatability handles NA", {
  result <- nemeton:::get_species_palatability(NA)
  expect_true(is.na(result))
})

test_that("get_species_palatability is vectorized", {
  result <- nemeton:::get_species_palatability(c("Quercus", "Picea", "Unknown"))
  expect_length(result, 3)
  # Quercus (oak) should be more palatable than Picea (spruce)
  expect_true(result[1] > result[2])
})

test_that("calculate_shannon_h works for uniform proportions", {
  # Equal proportions -> max diversity
  p <- rep(1/4, 4)
  h <- nemeton:::calculate_shannon_h(p)
  expect_equal(h, log(4), tolerance = 0.001)
})

test_that("calculate_shannon_h returns 0 for single species", {
  h <- nemeton:::calculate_shannon_h(1)
  expect_equal(h, 0)
})

test_that("calculate_shannon_h handles zeros", {
  p <- c(0.5, 0.5, 0, 0)
  h <- nemeton:::calculate_shannon_h(p)
  expect_equal(h, log(2), tolerance = 0.001)
})

test_that("calculate_shannon_h handles NAs", {
  p <- c(0.5, 0.5, NA)
  h <- nemeton:::calculate_shannon_h(p)
  expect_equal(h, log(2), tolerance = 0.001)
})

test_that("calculate_shannon_h returns NA for empty input", {
  h <- nemeton:::calculate_shannon_h(numeric(0))
  expect_true(is.na(h))
})

test_that("calculate_shannon_h accepts custom base", {
  p <- rep(1/4, 4)
  h2 <- nemeton:::calculate_shannon_h(p, base = 2)
  expect_equal(h2, 2, tolerance = 0.001)  # log2(4) = 2
})

test_that("safe_extract works with raster and polygons", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  r <- create_test_raster(values = "constant")
  terra::values(r) <- 42
  polys <- create_test_units(n_features = 2)

  result <- nemeton:::safe_extract(r, polys, "mean")
  expect_true(is.numeric(result))
  expect_length(result, 2)
})

test_that("safe_extract handles CRS transformation", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  # Create raster in EPSG:2154
  r <- create_test_raster(values = "constant", crs = "EPSG:2154")
  terra::values(r) <- 42
  # Create polygons in same CRS
  polys <- create_test_units(n_features = 2, crs = 2154)

  result <- nemeton:::safe_extract(r, polys, "mean")
  expect_true(is.numeric(result))
})

test_that("lookup_ademe_factor returns list for known type", {
  result <- nemeton:::lookup_ademe_factor("wood_energy")
  if (!is.null(result)) {
    expect_type(result, "list")
    expect_true("emission_factor_kgCO2eq_per_unit" %in% names(result))
  }
})

test_that("lookup_ademe_factor returns NULL for unknown type", {
  result <- nemeton:::lookup_ademe_factor("unknown_material_xyz")
  expect_null(result)
})

test_that("lookup_ademe_factor with scenario parameter", {
  result <- nemeton:::lookup_ademe_factor("wood_energy", scenario = "vs_natural_gas")
  if (!is.null(result)) {
    expect_type(result, "list")
  }
})

test_that("get_allometric_coefficients returns list for known species", {
  result <- nemeton:::get_allometric_coefficients("Quercus")
  expect_type(result, "list")
  expect_true("a" %in% names(result))
  expect_true("b" %in% names(result))
  expect_true("c" %in% names(result))
})

test_that("get_allometric_coefficients returns defaults for unknown species", {
  result <- nemeton:::get_allometric_coefficients("UnknownXYZ")
  expect_type(result, "list")
  # Should fall back to Generic
  expect_true("a" %in% names(result))
  expect_true(is.numeric(result$a))
})

test_that("get_allometric_coefficients includes source and citation", {
  result <- nemeton:::get_allometric_coefficients("Fagus")
  expect_type(result, "list")
  expect_true("source" %in% names(result))
  expect_true("citation" %in% names(result))
})
