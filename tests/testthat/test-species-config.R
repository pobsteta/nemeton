# tests/testthat/test-species-config.R
# Tests pour la configuration des essences par region (ADR-007)

# ---- get_species_config ----

test_that("get_species_config loads BFC config", {
  config <- get_species_config("BFC")
  expect_type(config, "list")
  expect_equal(config$region, "BFC")
  expect_equal(config$n_classes, 11)
  expect_length(config$classes, 11)
})

test_that("get_species_config loads EU fallback", {
  config <- get_species_config("EU")
  expect_equal(config$region, "EU")
  # EU config has 11 classes (updated from 10)
  expect_equal(config$n_classes, length(config$classes))
  expect_true(config$n_classes >= 10)
})

test_that("get_species_config is case-insensitive", {
  config <- get_species_config("bfc")
  expect_equal(config$region, "BFC")
})

test_that("get_species_config falls back to EU for unknown region", {
  config <- suppressWarnings(get_species_config("XX"))
  expect_equal(config$region, "EU")
})

# ---- list_species_regions ----

test_that("list_species_regions returns available regions", {
  regions <- list_species_regions()
  expect_true("BFC" %in% regions)
  expect_true("EU" %in% regions)
})

# ---- list_species_classes ----

test_that("list_species_classes returns 11 classes for BFC", {
  classes <- list_species_classes("BFC", lang = "fr")
  expect_s3_class(classes, "data.frame")
  expect_equal(nrow(classes), 11)
  expect_true("code" %in% names(classes))
  expect_true("label" %in% names(classes))
  expect_true("allometric_key" %in% names(classes))
  expect_true("color" %in% names(classes))
})

test_that("list_species_classes has correct NMT codes", {
  classes <- list_species_classes("BFC")
  expect_true("essence_chenaie" %in% classes$code)
  expect_true("essence_hetraie" %in% classes$code)
  expect_true("essence_pessiere_sapiniere" %in% classes$code)
  expect_true("essence_douglasaie" %in% classes$code)
  expect_true("essence_pinede" %in% classes$code)
  expect_true("essence_mixte" %in% classes$code)
})

test_that("list_species_classes supports English labels", {
  classes <- list_species_classes("BFC", lang = "en")
  expect_true("Oak forest" %in% classes$label)
  expect_true("Beech forest" %in% classes$label)
})

# ---- map_bdforet_essence ----

test_that("map_bdforet_essence maps known essences", {
  expect_equal(map_bdforet_essence("Hêtre", "BFC"), "essence_hetraie")
  expect_equal(map_bdforet_essence("Douglas", "BFC"), "essence_douglasaie")
  expect_equal(map_bdforet_essence("Pin sylvestre", "BFC"), "essence_pinede")
  expect_equal(map_bdforet_essence("Châtaignier", "BFC"), "essence_chataigneraie")
})

test_that("map_bdforet_essence returns mixte for unknown essence", {
  expect_equal(map_bdforet_essence("Inconnu", "BFC"), "essence_mixte")
})

# ---- map_oso_class ----
# Nomenclature OSO commune (OSO_NOMENCLATURE) : 16 = feuillus, 17 = conifères,
# 18 = pelouses, pas de classe mixte. Avant 0.212.2, BFC.json lisait l'ancienne
# (17 feuillus, 18 conifères, 19 mixte).

test_that("map_oso_class maps broadleaf forest (16)", {
  result <- map_oso_class(16, "BFC")
  expect_true("essence_chenaie" %in% result)
  expect_true("essence_hetraie" %in% result)
  expect_false("essence_pinede" %in% result)
})

test_that("map_oso_class maps coniferous forest (17)", {
  result <- map_oso_class(17, "BFC")
  expect_true("essence_pessiere_sapiniere" %in% result)
  expect_true("essence_douglasaie" %in% result)
  expect_false("essence_chenaie" %in% result)
})

test_that("map_oso_class lists the mixed class under both forest codes", {
  expect_true("essence_mixte" %in% map_oso_class(16, "BFC"))
  expect_true("essence_mixte" %in% map_oso_class(17, "BFC"))
})

test_that("map_oso_class returns no species for non-forest codes", {
  expect_identical(map_oso_class(18, "BFC"), character(0))  # pelouses
  expect_identical(map_oso_class(4, "BFC"), character(0))   # routes
  expect_identical(map_oso_class(19, "BFC"), character(0))  # landes
})

test_that("BFC.json OSO codes are the forest codes of OSO_NOMENCLATURE", {
  cfg <- get_species_config("BFC")
  foret <- unname(OSO_CLASSES_FORET)
  expect_setequal(as.integer(names(cfg$oso_mapping)), foret)
  for (cls in cfg$classes) {
    expect_true(all(unlist(cls$oso_classes) %in% foret), info = cls$code)
  }
})

# ---- get_allometric_key ----

test_that("get_allometric_key returns correct keys", {
  expect_equal(get_allometric_key("essence_chenaie", "BFC"), "Quercus")
  expect_equal(get_allometric_key("essence_hetraie", "BFC"), "Fagus")
  expect_equal(get_allometric_key("essence_pinede", "BFC"), "Pinus")
  expect_equal(get_allometric_key("essence_pessiere_sapiniere", "BFC"), "Abies")
  expect_equal(get_allometric_key("essence_mixte", "BFC"), "Generic")
})

test_that("get_allometric_key returns Generic for unknown", {
  expect_equal(get_allometric_key("inconnu", "BFC"), "Generic")
})
