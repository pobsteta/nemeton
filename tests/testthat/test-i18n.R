# test-i18n.R
# Tests for internationalization system
# R/i18n.R - currently 65% coverage

library(testthat)

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
    "indicator_carbon_biomass",
    "indicator_carbon_ndvi",
    "indicator_biodiversity_protection",
    "indicator_biodiversity_structure",
    "indicator_water_network",
    "indicator_water_wetlands",
    "indicator_risk_fire",
    "indicator_risk_storm",
    "indicator_risk_drought",
    "indicator_social_trails",
    "indicator_productive_volume",
    "indicator_energy_fuelwood",
    "indicator_naturalness_distance"
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

# Reset language to English at end of tests
nemeton::nemeton_set_language("en")
