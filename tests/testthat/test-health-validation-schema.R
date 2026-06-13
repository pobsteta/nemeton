test_that("schema returns the documented set of editable fields", {
  schema <- get_health_validation_schema()
  expect_type(schema, "list")
  names <- vapply(schema, `[[`, character(1), "name")
  expect_true(all(c(
    "plot_id", "alert_id", "confidence_class",
    "stade_deperissement", "cause", "taux_couvert",
    "essence_dominante", "commentaires", "photo_houppier",
    "obs_date", "obs_by"
  ) %in% names))
})

test_that("stade_deperissement is required and uses the DSF vocabulary", {
  schema <- get_health_validation_schema()
  stade <- Filter(function(f) f$name == "stade_deperissement", schema)[[1]]
  expect_true(stade$required)
  expect_equal(stade$widget, "value_map")
  expect_equal(stade$qgis_widget, "ValueMap")
  expect_setequal(stade$domain, HEALTH_VALIDATION_STADES)
})

test_that("cause uses the suggested vocabulary as a value_map", {
  schema <- get_health_validation_schema()
  cause <- Filter(function(f) f$name == "cause", schema)[[1]]
  expect_equal(cause$widget, "value_map")
  expect_setequal(cause$domain, HEALTH_VALIDATION_CAUSES)
})

test_that("taux_couvert is a percentage with [0, 100] bounds", {
  schema <- get_health_validation_schema()
  tc <- Filter(function(f) f$name == "taux_couvert", schema)[[1]]
  expect_equal(tc$type, "double")
  expect_equal(tc$widget, "range")
  expect_equal(tc$min, 0)
  expect_equal(tc$max, 100)
})

test_that("essence_dominante is populated from list_species_classes", {
  schema <- get_health_validation_schema(region = "BFC", lang = "fr")
  ess <- Filter(function(f) f$name == "essence_dominante", schema)[[1]]
  expect_equal(ess$widget, "value_map")
  expect_true(length(ess$domain) > 0L)
})

test_that("essence_dominante falls back to text when species config is missing", {
  testthat::local_mocked_bindings(
    list_species_classes = function(...) stop("no config"),
    .package = "nemeton"
  )
  expect_warning(
    schema <- get_health_validation_schema(region = "ZZ"),
    "Species config"
  )
  ess <- Filter(function(f) f$name == "essence_dominante", schema)[[1]]
  expect_equal(ess$widget, "text")
  expect_null(ess$domain)
})

test_that("photo_houppier maps to ExternalResource (QField photo widget)", {
  schema <- get_health_validation_schema()
  ph <- Filter(function(f) f$name == "photo_houppier", schema)[[1]]
  expect_equal(ph$qgis_widget, "ExternalResource")
})

test_that("obs_date is datetime and obs_by is text", {
  schema <- get_health_validation_schema()
  d <- Filter(function(f) f$name == "obs_date", schema)[[1]]
  expect_equal(d$type, "datetime")
  expect_equal(d$qgis_widget, "DateTime")
  b <- Filter(function(f) f$name == "obs_by", schema)[[1]]
  expect_equal(b$type, "character")
  expect_equal(b$widget, "text")
})

test_that("HEALTH_VALIDATION_STADES exposes the 7 DSF codes", {
  expect_length(HEALTH_VALIDATION_STADES, 7)
  expect_true("sain" %in% HEALTH_VALIDATION_STADES)
  expect_true("coupe_rase" %in% HEALTH_VALIDATION_STADES)
})

test_that("stade-to-status mapping reflects the spec", {
  expect_equal(nemeton:::.health_stade_to_status("sain")$status,
               "false_positive")
  expect_equal(nemeton:::.health_stade_to_status("sain")$cause,
               "sain_terrain")

  expect_equal(nemeton:::.health_stade_to_status("scolyte_rouge")$status,
               "confirmed")
  expect_equal(nemeton:::.health_stade_to_status("scolyte_rouge")$cause,
               "scolyte_terrain")

  # Coupe_rase: depends on confidence_class
  expect_equal(nemeton:::.health_stade_to_status("coupe_rase", "4-sol-nu")$status,
               "confirmed")
  expect_equal(nemeton:::.health_stade_to_status("coupe_rase", "3-forte")$status,
               "confirmed")
  expect_equal(nemeton:::.health_stade_to_status("coupe_rase", "1-faible")$status,
               "false_positive")
  expect_equal(nemeton:::.health_stade_to_status("coupe_rase", "2-moyenne")$status,
               "false_positive")

  # Empty / missing → no decision
  expect_true(is.na(nemeton:::.health_stade_to_status(NA)$status))
  expect_true(is.na(nemeton:::.health_stade_to_status("")$status))
})


# ---- RECONFORT (broadleaf) method, spec 021 G4 -----------------------

test_that("get_health_validation_schema(method='reconfort') uses feuillus vocab", {
  schema <- get_health_validation_schema(method = "reconfort")
  stade <- Filter(function(f) f$name == "stade_deperissement", schema)[[1]]
  cause <- Filter(function(f) f$name == "cause", schema)[[1]]
  expect_setequal(stade$domain, HEALTH_VALIDATION_STADES_FEUILLUS)
  expect_setequal(cause$domain, HEALTH_VALIDATION_CAUSES_FEUILLUS)
  cc <- Filter(function(f) f$name == "confidence_class", schema)[[1]]
  expect_match(cc$label, "RECONFORT")
})

test_that("default method stays FORDEAD (backward compatible)", {
  schema <- get_health_validation_schema()
  stade <- Filter(function(f) f$name == "stade_deperissement", schema)[[1]]
  expect_setequal(stade$domain, HEALTH_VALIDATION_STADES)
})

test_that("HEALTH_VALIDATION_STADES_FEUILLUS covers the DSF symptom axes", {
  expect_true(all(c("sain", "defoliation", "mortalite_branches",
                    "descente_cime", "mort") %in%
                  HEALTH_VALIDATION_STADES_FEUILLUS))
  expect_false("scolyte_vert" %in% HEALTH_VALIDATION_STADES_FEUILLUS)
  expect_false("scolyte" %in% HEALTH_VALIDATION_CAUSES_FEUILLUS)
})

test_that(".health_stade_to_status routes coupe_rase by method", {
  # RECONFORT: a clearcut is a false positive of dieback whatever the class
  expect_equal(nemeton:::.health_stade_to_status("coupe_rase",
                 "3-tres-deperissant", method = "reconfort")$status,
               "false_positive")
  # FORDEAD high-confidence clearcut stays confirmed (unchanged)
  expect_equal(nemeton:::.health_stade_to_status("coupe_rase",
                 "3-forte", method = "fordead")$status, "confirmed")
  # broadleaf dieback stages confirm
  expect_equal(nemeton:::.health_stade_to_status("descente_cime", NA,
                 method = "reconfort")$status, "confirmed")
  expect_equal(nemeton:::.health_stade_to_status("sain", NA,
                 method = "reconfort")$status, "false_positive")
})
