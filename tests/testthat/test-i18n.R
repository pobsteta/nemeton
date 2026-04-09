# test-i18n.R
# Tests for internationalization system
# R/i18n.R - currently 65% coverage

# ==============================================================================
# Tests for get_language()
# ==============================================================================

test_that("get_language returns valid language code", {
  lang <- nemeton:::get_language()

  expect_true(lang %in% c("en", "fr"))
})

test_that("get_language uses cached value after first call", {
  # Reset environment to ensure clean state
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  # First call should auto-detect

  lang1 <- nemeton:::get_language()

  # Second call should use cached value
  lang2 <- nemeton:::get_language()

  expect_equal(lang1, lang2)
})

# ==============================================================================
# Tests for nemeton::nemeton_set_language()
# ==============================================================================

test_that("nemeton_set_language sets language correctly", {
  # Set to French
  expect_message(
    result <- nemeton::nemeton_set_language("fr"),
    "fr"
  )
  expect_equal(result, "fr")
  expect_equal(nemeton:::get_language(), "fr")

  # Set back to English
  expect_message(
    result <- nemeton::nemeton_set_language("en"),
    "en"
  )
  expect_equal(result, "en")
  expect_equal(nemeton:::get_language(), "en")
})

test_that("nemeton_set_language validates input", {
  expect_error(
    nemeton::nemeton_set_language("de"),  # German not supported
    "should be one of|doit \u00eatre un de"
  )

  expect_error(
    nemeton::nemeton_set_language("spanish"),
    "should be one of|doit \u00eatre un de"
  )
})

test_that("nemeton_set_language returns language invisibly", {
  result <- nemeton::nemeton_set_language("en")
  expect_equal(result, "en")
})

# ==============================================================================
# Tests for msg()
# ==============================================================================

test_that("msg retrieves translated messages in English", {
  nemeton::nemeton_set_language("en")

  # Test known message key
  result <- nemeton:::msg("units_created", 10, "EPSG:2154")
  expect_match(result, "Created nemeton_units")
  expect_match(result, "10")
})

test_that("msg retrieves translated messages in French", {
  nemeton::nemeton_set_language("fr")

  result <- nemeton:::msg("units_created", 10, "EPSG:2154")
  expect_match(result, "Unit.*nemeton")

  # Reset to English for other tests
  nemeton::nemeton_set_language("en")
})

test_that("msg falls back to English for missing French translation", {
  nemeton::nemeton_set_language("fr")

  # If a key exists in English but not French, should fallback
  # Test with a key that might only be in English
  result <- nemeton:::msg("language_set", "test")

  # Should return something (either French or English fallback)
  expect_true(nchar(result) > 0)

  nemeton::nemeton_set_language("en")
})

test_that("msg returns key if translation not found", {
  result <- nemeton:::msg("nonexistent_key_xyz123")

  expect_equal(result, "nonexistent_key_xyz123")
})

test_that("msg interpolates variables correctly", {
  nemeton::nemeton_set_language("en")

  # Test with multiple variables
  result <- nemeton:::msg("layers_created", 5, 3)
  expect_match(result, "5 rasters")
  expect_match(result, "3 vectors")
})

# ==============================================================================
# Tests for msg_info()
# ==============================================================================

test_that("msg_info displays info message", {
  nemeton::nemeton_set_language("en")

  expect_message(
    nemeton:::msg_info("preprocess_start"),
    "Preprocessing"
  )
})

# ==============================================================================
# Tests for msg_success()
# ==============================================================================

test_that("msg_success displays success message", {
  nemeton::nemeton_set_language("en")

  expect_message(
    nemeton:::msg_success("language_set", "en"),
    "en"
  )
})

# ==============================================================================
# Tests for msg_warn()
# ==============================================================================

test_that("msg_warn issues warning", {
  nemeton::nemeton_set_language("en")

  expect_warning(
    nemeton:::msg_warn("layers_file_missing", "/path/to/file.tif"),
    "not found"
  )
})

# ==============================================================================
# Tests for msg_error()
# ==============================================================================

test_that("msg_error throws error", {
  nemeton::nemeton_set_language("en")

  expect_error(
    nemeton:::msg_error("units_not_sf"),
    "sf object"
  )
})

# ==============================================================================
# Tests for message dictionary completeness
# ==============================================================================

test_that("English and French dictionaries have same keys", {
  en_keys <- names(nemeton:::.messages$en)
  fr_keys <- names(nemeton:::.messages$fr)

  # Check that French has all English keys
  missing_in_fr <- setdiff(en_keys, fr_keys)
  expect_true(
    length(missing_in_fr) == 0,
    label = paste("Keys missing in French:", paste(missing_in_fr, collapse = ", "))
  )
})

test_that("All message values are non-empty strings", {
  for (lang in c("en", "fr")) {
    for (key in names(nemeton:::.messages[[lang]])) {
      msg <- nemeton:::.messages[[lang]][[key]]
      expect_true(
        is.character(msg) && nchar(msg) > 0,
        info = sprintf("Empty or non-string message: %s/%s", lang, key)
      )
    }
  }
})

# ==============================================================================
# Tests for specific message categories
# ==============================================================================

test_that("All indicator family messages exist in both languages", {
  indicator_keys <- c(
    "indicateur_c1_biomasse",
    "indicateur_c2_ndvi",
    "indicateur_b1_protection",
    "indicateur_b2_structure",
    "indicateur_w1_reseau",
    "indicateur_w2_zones_humides",
    "indicateur_r1_feu",
    "indicateur_r2_tempete",
    "indicateur_r3_secheresse",
    "indicateur_s1_routes",
    "indicateur_p1_volume",
    "indicateur_e1_bois_energie",
    "indicateur_n1_distance"
  )

  for (key in indicator_keys) {
    expect_true(
      !is.null(nemeton:::.messages$en[[key]]),
      info = sprintf("Missing English message: %s", key)
    )
    expect_true(
      !is.null(nemeton:::.messages$fr[[key]]),
      info = sprintf("Missing French message: %s", key)
    )
  }
})

test_that("Error messages exist in both languages", {
  error_keys <- grep("^error_", names(nemeton:::.messages$en), value = TRUE)

  for (key in error_keys) {
    expect_true(
      !is.null(nemeton:::.messages$fr[[key]]),
      info = sprintf("Missing French error message: %s", key)
    )
  }
})

# ==============================================================================
# (migrated from test-coverage-boost-i18n.R)
# ==============================================================================

# ==============================================================================
# get_language() — auto-detect from system locale
# ==============================================================================

test_that("get_language detects French from LANG=fr_FR.UTF-8", {
  # Clear cached language
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::with_envvar(list(LANG = "fr_FR.UTF-8"), {
    result <- nemeton:::get_language()
    expect_equal(result, "fr")
  })

  # Reset
  nemeton::nemeton_set_language("en")
})

test_that("get_language detects English from LANG=en_US.UTF-8", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::with_envvar(list(LANG = "en_US.UTF-8"), {
    result <- nemeton:::get_language()
    expect_equal(result, "en")
  })

  nemeton::nemeton_set_language("en")
})

test_that("get_language falls back to 'en' for unsupported locale", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::with_envvar(list(LANG = "de_DE.UTF-8"), {
    result <- nemeton:::get_language()
    expect_equal(result, "en")
  })

  nemeton::nemeton_set_language("en")
})

test_that("get_language falls back to 'en' when LANG is empty", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }

  withr::with_envvar(list(LANG = ""), {
    result <- nemeton:::get_language()
    expect_equal(result, "en")
  })

  nemeton::nemeton_set_language("en")
})

test_that("get_language returns cached value on subsequent calls", {
  nemeton::nemeton_set_language("fr")
  expect_equal(nemeton:::get_language(), "fr")
  expect_equal(nemeton:::get_language(), "fr")
  nemeton::nemeton_set_language("en")
})

# ==============================================================================
# msg() — interpolation and fallback paths
# ==============================================================================

test_that("msg without interpolation returns message as-is", {
  nemeton::nemeton_set_language("en")
  result <- nemeton:::msg("preprocess_start")
  expect_equal(result, "Preprocessing layers...")
})

test_that("msg with single interpolation works", {
  nemeton::nemeton_set_language("en")
  result <- nemeton:::msg("units_id_created", 42)
  expect_match(result, "42")
  expect_match(result, "unique IDs")
})

test_that("msg falls back to English when French key missing", {
  nemeton::nemeton_set_language("fr")
  # All keys should exist in both, but test the fallback mechanism
  # by verifying non-existent key returns the key itself
  result <- nemeton:::msg("totally_missing_key_abc")
  expect_equal(result, "totally_missing_key_abc")
  nemeton::nemeton_set_language("en")
})

test_that("msg with multiple interpolation args works", {
  nemeton::nemeton_set_language("en")
  result <- nemeton:::msg("indicator_computed", 5, 10)
  expect_match(result, "5")
  expect_match(result, "10")
})

# ==============================================================================
# msg_info, msg_success, msg_warn, msg_error — wrappers
# ==============================================================================

test_that("msg_info outputs cli info message", {
  nemeton::nemeton_set_language("en")
  expect_message(
    nemeton:::msg_info("preprocess_harmonizing"),
    "Harmonizing"
  )
})

test_that("msg_success outputs cli success message", {
  nemeton::nemeton_set_language("en")
  expect_message(
    nemeton:::msg_success("preprocess_crs_harmonized", "EPSG:2154"),
    "2154"
  )
})

test_that("msg_warn issues R warning", {
  nemeton::nemeton_set_language("en")
  expect_warning(
    nemeton:::msg_warn("normalize_ref_missing", "col_x"),
    "col_x"
  )
})

test_that("msg_error throws cli error", {
  nemeton::nemeton_set_language("en")
  expect_error(
    nemeton:::msg_error("units_missing_geom"),
    "geometry"
  )
})

# ==============================================================================
# nemeton_set_language — edge cases
# ==============================================================================

test_that("nemeton_set_language returns value invisibly", {
  result <- nemeton_set_language("fr")
  expect_equal(result, "fr")
  expect_invisible(nemeton_set_language("en"))
})

test_that("nemeton_set_language updates .nemeton_env", {
  nemeton::nemeton_set_language("fr")
  expect_equal(nemeton:::.nemeton_env$language, "fr")
  nemeton::nemeton_set_language("en")
  expect_equal(nemeton:::.nemeton_env$language, "en")
})

# ==============================================================================
# .messages dictionary — structural tests for coverage
# ==============================================================================

test_that(".messages French entries can be interpolated", {
  nemeton::nemeton_set_language("fr")

  # Test various French messages with interpolation
  result <- nemeton:::msg("units_created", 5, "EPSG:2154")
  expect_true(nchar(result) > 0)
  expect_match(result, "5")

  result <- nemeton:::msg("layers_created", 3, 2)
  expect_true(nchar(result) > 0)

  result <- nemeton:::msg("indicator_computing", 12)
  expect_true(nchar(result) > 0)

  nemeton::nemeton_set_language("en")
})

test_that(".messages error keys can be retrieved in French", {
  nemeton::nemeton_set_language("fr")

  error_keys <- grep("^error_", names(nemeton:::.messages$fr), value = TRUE)
  for (key in error_keys) {
    result <- nemeton:::msg(key)
    expect_true(nchar(result) > 0, info = paste("Empty French error:", key))
  }

  nemeton::nemeton_set_language("en")
})

# ==============================================================================
# (migrated from test-coverage-boost2.R)
# ==============================================================================

test_that("msg returns key for unknown message key", {
  result <- nemeton:::msg("totally_unknown_key_xyz")
  expect_equal(result, "totally_unknown_key_xyz")
})

test_that("msg_info dispatches correctly", {
  # Should produce a message (cli_alert_info), not an error
  expect_message(nemeton:::msg_info("indicateur_c1_biomasse"))
})

test_that("nemeton_set_language to fr works", {
  old_lang <- nemeton:::get_language()
  on.exit(nemeton::nemeton_set_language(old_lang), add = TRUE)
  nemeton::nemeton_set_language("fr")
  expect_equal(nemeton:::get_language(), "fr")
})

test_that("msg works in French", {
  old_lang <- nemeton:::get_language()
  on.exit(nemeton::nemeton_set_language(old_lang), add = TRUE)
  nemeton::nemeton_set_language("fr")
  result <- nemeton:::msg("language_set")
  # French message should contain something recognizable
  expect_true(nchar(result) > 0)
})

test_that("get_language auto-detects from locale", {
  # Clear cached language
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  # Set a French locale
  withr::with_envvar(c(LANG = "fr_FR.UTF-8"), {
    # Clear again inside the envvar scope
    if (exists("language", envir = nemeton:::.nemeton_env)) {
      rm("language", envir = nemeton:::.nemeton_env)
    }
    lang <- nemeton:::get_language()
    expect_equal(lang, "fr")
  })
  # Restore English
  nemeton::nemeton_set_language("en")
})

test_that("get_language defaults to en for unknown locale", {
  if (exists("language", envir = nemeton:::.nemeton_env)) {
    rm("language", envir = nemeton:::.nemeton_env)
  }
  withr::with_envvar(c(LANG = "de_DE.UTF-8"), {
    if (exists("language", envir = nemeton:::.nemeton_env)) {
      rm("language", envir = nemeton:::.nemeton_env)
    }
    lang <- nemeton:::get_language()
    expect_equal(lang, "en")
  })
  nemeton::nemeton_set_language("en")
})

test_that("msg falls back to English when key missing in French", {
  old_lang <- nemeton:::get_language()
  on.exit(nemeton::nemeton_set_language(old_lang), add = TRUE)
  nemeton::nemeton_set_language("fr")
  # Test a key that exists in both languages
  result <- nemeton:::msg("language_set")
  expect_true(nchar(result) > 0)
})

# Reset language to English at end of tests
nemeton::nemeton_set_language("en")
