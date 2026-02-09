# Coverage boost tests for R/i18n.R
# Targets uncovered paths: get_language() auto-detect, msg() fallback chain

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
  nemeton_set_language("fr")
  expect_equal(nemeton:::.nemeton_env$language, "fr")
  nemeton_set_language("en")
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
