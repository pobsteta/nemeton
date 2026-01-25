# Tests for nemetonApp Internationalization (i18n)
# Phase 1: Translation system

test_that("TRANSLATIONS contains required keys", {
  translations <- nemeton:::TRANSLATIONS

  required_keys <- c(
    "app_title",
    "tab_selection",
    "tab_synthesis",
    "tab_families",
    "compute_button",
    "download_pdf",
    "download_gpkg",
    "help"
  )

  for (key in required_keys) {
    expect_true(
      key %in% names(translations),
      info = paste("Missing translation key:", key)
    )
  }
})

test_that("All translations have both fr and en versions", {
  translations <- nemeton:::TRANSLATIONS

  for (key in names(translations)) {
    translation <- translations[[key]]

    expect_true(
      "fr" %in% names(translation),
      info = paste("Missing French translation for:", key)
    )
    expect_true(
      "en" %in% names(translation),
      info = paste("Missing English translation for:", key)
    )
  }
})

test_that("get_i18n returns a translator object", {
  i18n <- nemeton:::get_i18n("fr")

  expect_s3_class(i18n, "nemeton_i18n")
  expect_equal(i18n$language, "fr")
  expect_type(i18n$t, "closure")
  expect_type(i18n$keys, "closure")
  expect_type(i18n$has, "closure")
})

test_that("get_i18n defaults to valid language", {
  i18n_fr <- nemeton:::get_i18n("fr")
  i18n_en <- nemeton:::get_i18n("en")

  expect_equal(i18n_fr$language, "fr")
  expect_equal(i18n_en$language, "en")
})

test_that("get_i18n rejects invalid language", {
  expect_error(nemeton:::get_i18n("de"))
  expect_error(nemeton:::get_i18n("es"))
})

test_that("Translator t() function returns correct translations", {
  i18n_fr <- nemeton:::get_i18n("fr")
  i18n_en <- nemeton:::get_i18n("en")

  # French
  expect_equal(i18n_fr$t("tab_selection"), "Sélection")
  expect_equal(i18n_fr$t("help"), "Aide")

 # English
  expect_equal(i18n_en$t("tab_selection"), "Selection")
  expect_equal(i18n_en$t("help"), "Help")
})

test_that("Translator t() returns key for missing translations", {
  i18n <- nemeton:::get_i18n("fr")

  # Non-existent key should return the key itself
  expect_warning(
    result <- i18n$t("nonexistent_key"),
    "not found"
  )
  expect_equal(result, "nonexistent_key")
})

test_that("Translator t() supports string interpolation", {
  i18n <- nemeton:::get_i18n("fr")

  # Test with placeholder
  result <- i18n$t("computing_indicator", indicator = "C1")
  expect_true(grepl("C1", result))
})

test_that("Translator keys() returns all keys", {
  i18n <- nemeton:::get_i18n("fr")
  keys <- i18n$keys()

  expect_type(keys, "character")
  expect_true(length(keys) > 50)  # We have many translations
  expect_true("app_title" %in% keys)
})

test_that("Translator has() checks key existence", {
  i18n <- nemeton:::get_i18n("fr")

  expect_true(i18n$has("app_title"))
  expect_true(i18n$has("help"))
  expect_false(i18n$has("nonexistent_key"))
})

test_that("get_available_languages returns fr and en", {
  langs <- nemeton:::get_available_languages()

  expect_equal(langs, c("fr", "en"))
})

test_that("All 12 family names are translated", {
  i18n_fr <- nemeton:::get_i18n("fr")
  i18n_en <- nemeton:::get_i18n("en")

  family_keys <- paste0("family_", c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))

  for (key in family_keys) {
    expect_true(i18n_fr$has(key), info = paste("Missing FR:", key))
    expect_true(i18n_en$has(key), info = paste("Missing EN:", key))

    # Should not be empty
    expect_true(nchar(i18n_fr$t(key)) > 0, info = paste("Empty FR:", key))
    expect_true(nchar(i18n_en$t(key)) > 0, info = paste("Empty EN:", key))
  }
})

test_that("All 12 family descriptions are translated", {
  i18n_fr <- nemeton:::get_i18n("fr")
  i18n_en <- nemeton:::get_i18n("en")

  family_desc_keys <- paste0("family_", c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"), "_desc")

  for (key in family_desc_keys) {
    expect_true(i18n_fr$has(key), info = paste("Missing FR desc:", key))
    expect_true(i18n_en$has(key), info = paste("Missing EN desc:", key))
  }
})

test_that("JSON translation files exist", {
  fr_path <- system.file("app/i18n/fr.json", package = "nemeton")
  en_path <- system.file("app/i18n/en.json", package = "nemeton")

  # Skip if package not installed (during development)
  skip_if(fr_path == "")

  expect_true(file.exists(fr_path))
  expect_true(file.exists(en_path))
})
