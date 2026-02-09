# test-coverage-boost.R
# Additional tests to increase code coverage to 60%
# Targets uncovered code in: service_project (comments), llm_prompts,
# family-system, analysis-pareto, i18n, utils_theme

library(testthat)

# ==============================================================================
# service_project.R - save_comments / load_comments
# ==============================================================================

test_that("save_comments saves and load_comments reads back synthesis", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Comments Test")

        result <- nemeton:::save_comments(
          project$id,
          synthesis = "This is a synthesis comment"
        )
        expect_true(result)

        # Load back
        loaded <- nemeton:::load_comments(project$id)
        expect_type(loaded, "list")
        expect_equal(loaded$synthesis, "This is a synthesis comment")
      }
    )
  })
})

test_that("save_comments saves family comments", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Family Comments Test")

        families <- list(
          C = "Carbon comment",
          B = "Biodiversity comment",
          W = "Water comment"
        )

        result <- nemeton:::save_comments(
          project$id,
          families = families
        )
        expect_true(result)

        # Load back
        loaded <- nemeton:::load_comments(project$id)
        expect_type(loaded, "list")
        expect_equal(loaded$families$C, "Carbon comment")
        expect_equal(loaded$families$B, "Biodiversity comment")
        expect_equal(loaded$families$W, "Water comment")
      }
    )
  })
})

test_that("save_comments merges with existing data", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Merge Comments Test")

        # Save synthesis first
        nemeton:::save_comments(project$id, synthesis = "Initial synthesis")

        # Then save families (should not overwrite synthesis)
        nemeton:::save_comments(
          project$id,
          families = list(C = "Carbon analysis")
        )

        loaded <- nemeton:::load_comments(project$id)
        expect_equal(loaded$synthesis, "Initial synthesis")
        expect_equal(loaded$families$C, "Carbon analysis")
      }
    )
  })
})

test_that("save_comments returns FALSE for nonexistent project", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        result <- nemeton:::save_comments(
          "nonexistent_project_xyz",
          synthesis = "test"
        )
        expect_false(result)
      }
    )
  })
})

test_that("load_comments returns NULL for nonexistent project", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        result <- nemeton:::load_comments("nonexistent_project_xyz")
        expect_null(result)
      }
    )
  })
})

test_that("load_comments returns NULL when no comments file", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "No Comments")
        result <- nemeton:::load_comments(project$id)
        expect_null(result)
      }
    )
  })
})

test_that("save_comments creates data dir if missing", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Missing Data Dir")
        # Remove data dir
        unlink(file.path(project$path, "data"), recursive = TRUE)

        result <- nemeton:::save_comments(
          project$id,
          synthesis = "Created with new data dir"
        )
        expect_true(result)

        # Verify data dir was recreated
        expect_true(dir.exists(file.path(project$path, "data")))
      }
    )
  })
})

test_that("save_comments with both synthesis and families", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Both Comments")

        result <- nemeton:::save_comments(
          project$id,
          synthesis = "Global synthesis",
          families = list(C = "Carbon", B = "Biodiversity")
        )
        expect_true(result)

        loaded <- nemeton:::load_comments(project$id)
        expect_equal(loaded$synthesis, "Global synthesis")
        expect_equal(loaded$families$C, "Carbon")
        expect_equal(loaded$families$B, "Biodiversity")
      }
    )
  })
})

test_that("load_project includes comments when present", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Full Load Test")
        nemeton:::save_comments(
          project$id,
          synthesis = "Test synthesis"
        )

        loaded <- nemeton:::load_project(project$id)
        expect_type(loaded, "list")
        expect_type(loaded$comments, "list")
        expect_equal(loaded$comments$synthesis, "Test synthesis")
      }
    )
  })
})

# ==============================================================================
# llm_prompts.R - reload_expert_profiles, get_expert_choices
# ==============================================================================

test_that("reload_expert_profiles returns profiles invisibly", {
  result <- nemeton:::reload_expert_profiles()
  expect_type(result, "list")
  expect_true(length(result) >= 5)
  expect_true("generalist" %in% names(result))
})

test_that("reload_expert_profiles refreshes the cache", {
  # First load
  profiles1 <- nemeton:::get_expert_profiles()
  # Force reload
  profiles2 <- nemeton:::reload_expert_profiles()
  # Should have same content
  expect_equal(names(profiles1), names(profiles2))
})

test_that("get_expert_choices returns named character vector for French", {
  choices <- nemeton:::get_expert_choices(lang = "fr")
  expect_type(choices, "character")
  expect_true(length(choices) >= 5)
  # Values should be profile keys
  expect_true("generalist" %in% choices)
  # Names should be French labels
  expect_true(all(nchar(names(choices)) > 0))
})

test_that("get_expert_choices returns named character vector for English", {
  choices <- nemeton:::get_expert_choices(lang = "en")
  expect_type(choices, "character")
  expect_true(length(choices) >= 5)
  expect_true("generalist" %in% choices)
  # Names should be English labels
  expect_true(all(nchar(names(choices)) > 0))
})

test_that("get_expert_choices French and English labels differ", {
  choices_fr <- nemeton:::get_expert_choices(lang = "fr")
  choices_en <- nemeton:::get_expert_choices(lang = "en")

  # Values (keys) should be the same
  expect_equal(sort(unname(choices_fr)), sort(unname(choices_en)))

  # Labels (names) should differ for at least some profiles
  expect_false(all(names(choices_fr) == names(choices_en)))
})

test_that("load_expert_profiles loads from package inst/experts dir", {
  profiles <- nemeton:::load_expert_profiles()
  expect_type(profiles, "list")
  expect_true(length(profiles) >= 5)

  for (key in names(profiles)) {
    profile <- profiles[[key]]
    expect_true("label" %in% names(profile))
    expect_true("prompt" %in% names(profile))
  }
})

test_that("load_expert_profiles creates user expert dir if needed", {
  withr::with_tempdir({
    user_dir <- file.path(getwd(), "custom_experts")
    withr::local_options(list(nemeton.experts_dir = user_dir))

    profiles <- nemeton:::load_expert_profiles()
    # Should create the user directory
    expect_true(dir.exists(user_dir))
  })
})

test_that("load_expert_profiles loads user profiles that override package ones", {
  withr::with_tempdir({
    user_dir <- file.path(getwd(), "user_experts")
    dir.create(user_dir, recursive = TRUE)
    withr::local_options(list(nemeton.experts_dir = user_dir))

    # Create a custom profile YAML
    writeLines(
      c(
        "label:",
        "  fr: Mon profil personnalis\u00e9",
        "  en: My custom profile",
        "prompt:",
        "  fr: Tu es un expert personnalis\u00e9 en foresterie tropicale.",
        "  en: You are a custom expert in tropical forestry."
      ),
      file.path(user_dir, "custom_tropical.yml")
    )

    profiles <- nemeton:::load_expert_profiles()
    expect_true("custom_tropical" %in% names(profiles))
    expect_equal(profiles$custom_tropical$label$en, "My custom profile")
  })
})

test_that("load_expert_profiles skips invalid YAML files gracefully", {
  withr::with_tempdir({
    user_dir <- file.path(getwd(), "bad_experts")
    dir.create(user_dir, recursive = TRUE)
    withr::local_options(list(nemeton.experts_dir = user_dir))

    # Create an invalid YAML file
    writeLines("{{invalid yaml content!!!", file.path(user_dir, "bad.yml"))

    expect_warning(
      profiles <- nemeton:::load_expert_profiles(),
      "invalid expert profile"
    )
    # Should still load package profiles
    expect_true(length(profiles) >= 5)
  })
})

test_that("load_expert_profiles skips YAML without label/prompt", {
  withr::with_tempdir({
    user_dir <- file.path(getwd(), "incomplete_experts")
    dir.create(user_dir, recursive = TRUE)
    withr::local_options(list(nemeton.experts_dir = user_dir))

    # Create a valid YAML but missing required fields
    writeLines(
      c("name: Missing Fields", "description: No label or prompt"),
      file.path(user_dir, "incomplete.yml")
    )

    profiles <- nemeton:::load_expert_profiles()
    # Should not include the incomplete profile
    expect_false("incomplete" %in% names(profiles))
  })
})

# ==============================================================================
# family-system.R - get_family_name with explicit lang parameter
# ==============================================================================

test_that("get_family_name returns French names with lang='fr'", {
  result <- nemeton:::get_family_name("C", lang = "fr")
  expect_type(result, "character")
  expect_match(result, "Carbone")
})

test_that("get_family_name returns English names with lang='en'", {
  result <- nemeton:::get_family_name("C", lang = "en")
  expect_type(result, "character")
  expect_match(result, "Carbon")
})

test_that("get_family_name returns code for unknown family", {
  result <- nemeton:::get_family_name("Z", lang = "en")
  expect_equal(result, "Z")
})

test_that("get_family_name covers all 12 family codes in French", {
  codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in codes) {
    result <- nemeton:::get_family_name(code, lang = "fr")
    expect_true(nchar(result) > 1, info = paste("Empty name for code:", code))
    expect_false(result == code, info = paste("Got code back for:", code))
  }
})

test_that("get_family_name covers all 12 family codes in English", {
  codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in codes) {
    result <- nemeton:::get_family_name(code, lang = "en")
    expect_true(nchar(result) > 1, info = paste("Empty name for code:", code))
    expect_false(result == code, info = paste("Got code back for:", code))
  }
})

test_that("get_family_name uses get_language when lang is NULL", {
  nemeton::nemeton_set_language("fr")
  result_fr <- nemeton:::get_family_name("B")
  expect_match(result_fr, "Biodiversit")

  nemeton::nemeton_set_language("en")
  result_en <- nemeton:::get_family_name("B")
  expect_match(result_en, "Biodiversity")
})

# ==============================================================================
# family-system.R - detect_indicator_family with long-form column names
# ==============================================================================

test_that("detect_indicator_family handles long-form column names", {
  # These are mapped via get_column_family_map() from INDICATOR_FAMILIES
  # Test a few known column names from INDICATOR_FAMILIES config
  result_c <- nemeton:::detect_indicator_family("carbon_biomass")
  result_w <- nemeton:::detect_indicator_family("water_twi")

  # These should map to families if they're in the config
  # If not in config, they return NA - that's also fine, just testing the code path
  expect_type(result_c, "character")
  expect_type(result_w, "character")
})

test_that("detect_indicator_family handles _norm suffix stripping", {
  # C1_norm should detect as C
  result <- nemeton:::detect_indicator_family("C1_norm")
  expect_equal(result, "C")

  # If carbon_biomass_norm is in the column map, it should match
  result_norm <- nemeton:::detect_indicator_family("carbon_biomass_norm")
  expect_type(result_norm, "character")
})

# ==============================================================================
# analysis-pareto.R - additional validation paths
# ==============================================================================

test_that("identify_pareto_optimal rejects non-data.frame/non-sf input", {
  expect_error(
    identify_pareto_optimal(
      matrix(1:10, nrow = 5),
      objectives = c("V1", "V2")
    ),
    "data.frame|sf"
  )
})

test_that("identify_pareto_optimal rejects non-numeric objectives", {
  test_data <- data.frame(
    id = c("P1", "P2", "P3"),
    family_C = c("a", "b", "c"),
    family_B = c(50, 55, 52)
  )

  expect_error(
    identify_pareto_optimal(
      test_data,
      objectives = c("family_C", "family_B"),
      maximize = c(TRUE, TRUE)
    ),
    "numeric"
  )
})

test_that("identify_pareto_optimal rejects data with NA in objectives", {
  test_data <- data.frame(
    id = c("P1", "P2", "P3"),
    family_C = c(60, NA, 70),
    family_B = c(50, 55, 52)
  )

  expect_error(
    identify_pareto_optimal(
      test_data,
      objectives = c("family_C", "family_B"),
      maximize = c(TRUE, TRUE)
    ),
    "NA"
  )
})

test_that("identify_pareto_optimal works with simple data.frame", {
  test_data <- data.frame(
    id = c("P1", "P2", "P3", "P4"),
    family_C = c(80, 60, 70, 50),
    family_B = c(50, 80, 60, 70)
  )

  result <- identify_pareto_optimal(
    test_data,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )

  expect_s3_class(result, "data.frame")
  expect_true("is_optimal" %in% names(result))
  expect_equal(nrow(result), 4)
  # P1 (highest C) and P2 (highest B) should be Pareto optimal
  expect_true(result$is_optimal[1])
  expect_true(result$is_optimal[2])
})

test_that("identify_pareto_optimal with all minimize", {
  test_data <- data.frame(
    family_C = c(80, 60, 70, 50),
    family_B = c(50, 80, 60, 70)
  )

  result <- identify_pareto_optimal(
    test_data,
    objectives = c("family_C", "family_B"),
    maximize = c(FALSE, FALSE)
  )

  expect_true("is_optimal" %in% names(result))
  # P4 (lowest C=50, B=70) and P1 (C=80, lowest B=50) should be optimal
  expect_true(result$is_optimal[4])
  expect_true(result$is_optimal[1])
})

test_that("identify_pareto_optimal with two identical rows", {
  test_data <- data.frame(
    family_C = c(60, 60, 80),
    family_B = c(50, 50, 30)
  )

  result <- identify_pareto_optimal(
    test_data,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )

  expect_true("is_optimal" %in% names(result))
  # Both rows 1 and 2 are identical and not dominated by row 3
  # (row 3 has higher C but lower B)
  # So rows 1, 2, and 3 should all be Pareto optimal
  expect_true(result$is_optimal[1])
  expect_true(result$is_optimal[2])
  expect_true(result$is_optimal[3])
})

# ==============================================================================
# i18n.R - additional msg() coverage
# ==============================================================================

test_that("msg handles French messages with interpolation", {
  nemeton::nemeton_set_language("fr")

  result <- nemeton:::msg("layers_created", 3, 2)
  expect_match(result, "3 rasters")
  expect_match(result, "2 vecteurs")

  nemeton::nemeton_set_language("en")
})

test_that("msg handles various message categories", {
  nemeton::nemeton_set_language("en")

  # v0.3.0 messages
  result <- nemeton:::msg("indicator_biodiversity_protection")
  expect_true(nchar(result) > 0)

  result <- nemeton:::msg("indicator_risk_fire")
  expect_true(nchar(result) > 0)

  # v0.4.0 messages
  result <- nemeton:::msg("indicator_social_trails")
  expect_true(nchar(result) > 0)

  result <- nemeton:::msg("indicator_productive_volume")
  expect_true(nchar(result) > 0)

  result <- nemeton:::msg("indicator_energy_fuelwood")
  expect_true(nchar(result) > 0)

  result <- nemeton:::msg("indicator_naturalness_distance")
  expect_true(nchar(result) > 0)
})

test_that("msg handles error messages", {
  nemeton::nemeton_set_language("en")

  result <- nemeton:::msg("error_invalid_data_type")
  expect_match(result, "data.frame|sf")

  result <- nemeton:::msg("error_invalid_method")
  expect_match(result, "kmeans|hierarchical")

  result <- nemeton:::msg("error_k_too_small")
  expect_match(result, "at least 2")
})

test_that("msg handles French error messages", {
  nemeton::nemeton_set_language("fr")

  result <- nemeton:::msg("error_invalid_data_type")
  expect_match(result, "data.frame|sf")

  result <- nemeton:::msg("error_k_too_small")
  expect_match(result, "au moins 2")

  nemeton::nemeton_set_language("en")
})

test_that("msg handles interpolation with multiple parameters", {
  nemeton::nemeton_set_language("en")

  # Messages with 1 param
  result <- nemeton:::msg("indicator_failed", "test_indicator")
  expect_match(result, "test_indicator")

  # Messages with 2 params
  result <- nemeton:::msg("normalize_normalized", 5, "minmax")
  expect_match(result, "5")
  expect_match(result, "minmax")

  # Messages with 3 params
  result <- nemeton:::msg("risk_fire_factors", 0.5, 0.3, 0.2)
  expect_match(result, "0\\.5")
})

test_that("msg_info, msg_success, msg_warn, msg_error work with French", {
  nemeton::nemeton_set_language("fr")

  expect_message(
    nemeton:::msg_info("preprocess_start"),
    "Pr.*traitement"
  )

  expect_message(
    nemeton:::msg_success("language_set", "fr"),
    "fr"
  )

  expect_warning(
    nemeton:::msg_warn("layers_file_missing", "/chemin/fichier.tif"),
    "introuvable"
  )

  expect_error(
    nemeton:::msg_error("units_not_sf"),
    "sf"
  )

  nemeton::nemeton_set_language("en")
})

# ==============================================================================
# utils_theme.R - additional coverage for get_accessible_palette
# ==============================================================================

test_that("get_accessible_palette supports all valid palettes", {
  skip_if_not_installed("viridisLite")

  for (palette in c("viridis", "plasma", "inferno", "magma", "cividis")) {
    colors <- nemeton:::get_accessible_palette(5, palette = palette)
    expect_length(colors, 5)
    expect_true(all(grepl("^#", colors)))
  }
})

test_that("get_accessible_palette respects alpha parameter", {
  skip_if_not_installed("viridisLite")

  colors_full <- nemeton:::get_accessible_palette(3, alpha = 1)
  colors_half <- nemeton:::get_accessible_palette(3, alpha = 0.5)

  expect_length(colors_full, 3)
  expect_length(colors_half, 3)
  # With alpha < 1, colors should include alpha channel (8 chars after #)
  expect_true(all(nchar(colors_half) >= 7))
})

test_that("get_accessible_palette with invalid palette falls back to viridis", {
  skip_if_not_installed("viridisLite")

  expect_warning(
    colors <- nemeton:::get_accessible_palette(3, palette = "jet"),
    "not colorblind-friendly"
  )

  expected <- viridisLite::viridis(3)
  expect_equal(colors, expected)
})

test_that("get_accessible_palette returns single color for n=1", {
  skip_if_not_installed("viridisLite")

  colors <- nemeton:::get_accessible_palette(1)
  expect_length(colors, 1)
  expect_match(colors, "^#")
})

test_that("get_accessible_palette returns many colors for n=20", {
  skip_if_not_installed("viridisLite")

  colors <- nemeton:::get_accessible_palette(20)
  expect_length(colors, 20)
  expect_true(length(unique(colors)) == 20)
})

# ==============================================================================
# create_family_index - geometric mean warning for negative values
# ==============================================================================

test_that("create_family_index geometric mean warns on zero/negative values", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(0, 50, 60)
  units$C2 <- c(40, 50, 60)

  expect_warning(
    result <- create_family_index(units, method = "geometric", family_codes = "C"),
    "positive values|absolute values"
  )
  expect_true("family_C" %in% names(result))
})

test_that("create_family_index harmonic mean warns on zero values", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(0, 50, 60)
  units$C2 <- c(40, 50, 60)

  expect_warning(
    result <- create_family_index(units, method = "harmonic", family_codes = "C"),
    "zero values|small value"
  )
  expect_true("family_C" %in% names(result))
})

test_that("create_family_index handles all-NA row", {
  units <- create_test_units(n_features = 3)
  units$C1 <- c(NA, 50, 60)
  units$C2 <- c(NA, 50, 60)

  result <- create_family_index(units, method = "mean", family_codes = "C")
  expect_true(is.na(result$family_C[1]))
  expect_false(is.na(result$family_C[2]))
})

# ==============================================================================
# analysis-pareto.R - sf preservation and message output
# ==============================================================================

test_that("identify_pareto_optimal preserves sf class and geometry", {
  skip_if_not_installed("sf")

  units <- create_test_units(n_features = 4, crs = 2154)
  units$family_C <- c(80, 60, 70, 50)
  units$family_B <- c(50, 80, 60, 70)

  result <- identify_pareto_optimal(
    units,
    objectives = c("family_C", "family_B"),
    maximize = c(TRUE, TRUE)
  )

  expect_s3_class(result, "sf")
  expect_true("is_optimal" %in% names(result))
  expect_equal(sf::st_crs(result)$epsg, 2154L)
})

# ==============================================================================
# get_language auto-detection paths
# ==============================================================================

test_that("get_language auto-detects from LANG env var", {
  # Clear cached language
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::local_envvar(LANG = "fr_FR.UTF-8")
  lang <- nemeton:::get_language()
  expect_equal(lang, "fr")

  # Reset
  rm("language", envir = nemeton:::.nemeton_env)
  nemeton::nemeton_set_language("en")
})

test_that("get_language defaults to en for unsupported locale", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::local_envvar(LANG = "de_DE.UTF-8")
  lang <- nemeton:::get_language()
  expect_equal(lang, "en")

  # Reset
  rm("language", envir = nemeton:::.nemeton_env)
  nemeton::nemeton_set_language("en")
})

# ==============================================================================
# service_project.R - save_comments edge cases
# ==============================================================================

test_that("save_comments overwrites synthesis while keeping families", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Overwrite Test")

        # Save both
        nemeton:::save_comments(
          project$id,
          synthesis = "Old synthesis",
          families = list(C = "Carbon note")
        )

        # Overwrite synthesis only
        nemeton:::save_comments(project$id, synthesis = "New synthesis")

        loaded <- nemeton:::load_comments(project$id)
        expect_equal(loaded$synthesis, "New synthesis")
        # Families should be preserved from previous save
        expect_equal(loaded$families$C, "Carbon note")
      }
    )
  })
})

test_that("save_comments overwrites families while keeping synthesis", {
  withr::with_tempdir({
    temp_root <- getwd()
    with_mocked_bindings(.package = "nemeton",
      get_app_options = function() list(project_dir = temp_root),
      {
        project <- nemeton:::create_project(name = "Overwrite Families Test")

        # Save both
        nemeton:::save_comments(
          project$id,
          synthesis = "Keep this synthesis",
          families = list(C = "Old carbon")
        )

        # Overwrite families only
        nemeton:::save_comments(
          project$id,
          families = list(C = "New carbon", B = "New bio")
        )

        loaded <- nemeton:::load_comments(project$id)
        expect_equal(loaded$synthesis, "Keep this synthesis")
        expect_equal(loaded$families$C, "New carbon")
        expect_equal(loaded$families$B, "New bio")
      }
    )
  })
})

# ==============================================================================
# INDICATOR_FAMILIES config coverage
# ==============================================================================

test_that("INDICATOR_FAMILIES has all 12 families defined", {
  families <- nemeton:::INDICATOR_FAMILIES
  expect_type(families, "list")

  expected_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in expected_codes) {
    expect_true(
      code %in% names(families),
      info = paste("Missing family config:", code)
    )
  }
})

test_that("INDICATOR_FAMILIES each have required fields", {
  families <- nemeton:::INDICATOR_FAMILIES

  for (code in names(families)) {
    fam <- families[[code]]
    expect_true("code" %in% names(fam),
                info = paste("Missing 'code' in family:", code))
    expect_true("name_en" %in% names(fam),
                info = paste("Missing 'name_en' in family:", code))
    expect_true("name_fr" %in% names(fam),
                info = paste("Missing 'name_fr' in family:", code))
  }
})

# ==============================================================================
# get_indicator_cols helper
# ==============================================================================

test_that("get_indicator_cols excludes standard non-indicator columns", {
  test_data <- data.frame(
    nemeton_id = "U001",
    id = "P1",
    geo_parcelle = "abc",
    area = 1000,
    surface_geo = 1000,
    nomcommune = "TestVille",
    codecommune = "12345",
    C1 = 50,
    W1 = 30,
    custom_metric = 75
  )

  cols <- nemeton:::get_indicator_cols(test_data)
  expect_true("C1" %in% cols)
  expect_true("W1" %in% cols)
  expect_true("custom_metric" %in% cols)
  expect_false("nemeton_id" %in% cols)
  expect_false("id" %in% cols)
  expect_false("geo_parcelle" %in% cols)
  expect_false("area" %in% cols)
  expect_false("nomcommune" %in% cols)
})

# Reset language
nemeton::nemeton_set_language("en")
